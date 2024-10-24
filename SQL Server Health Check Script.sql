-- Database Information
SELECT 
    a.database_id,
    a.name,
    a.create_date,
    b.name AS owner_name,
    a.user_access_desc,
    a.state_desc,
    a.compatibility_level,
    a.recovery_model_desc,
    SUM((c.size * 8) / 1024) AS DBSizeInMB
FROM 
    sys.databases a 
INNER JOIN 
    sys.server_principals b ON a.owner_sid = b.sid 
INNER JOIN 
    sys.master_files c ON a.database_id = c.database_id
WHERE 
    a.database_id > 5
GROUP BY 
    a.database_id, a.name, a.create_date, b.name, a.user_access_desc, a.state_desc, 
    a.compatibility_level, a.recovery_model_desc;

-- Server and Instance Status
DECLARE 
    @DatabaseServerInformation NVARCHAR(MAX),
    @Hostname VARCHAR(50) = (SELECT CONVERT(VARCHAR(50), @@SERVERNAME)),
    @Version VARCHAR(MAX) = (SELECT CONVERT(VARCHAR(MAX), @@VERSION)),
    @Edition VARCHAR(50) = (SELECT CONVERT(VARCHAR(50), SERVERPROPERTY('edition'))),
    @IsClusteredInstance VARCHAR(50) = 
        (SELECT CASE SERVERPROPERTY('IsClustered') 
            WHEN 1 THEN 'Clustered Instance' 
            WHEN 0 THEN 'Non Clustered instance' 
            ELSE 'null' 
         END),
    @IsInstanceinSingleUserMode VARCHAR(50) = 
        (SELECT CASE SERVERPROPERTY('IsSingleUser') 
            WHEN 1 THEN 'Single user' 
            WHEN 0 THEN 'Multi user' 
            ELSE 'null' 
         END);

-- Output the Value
SELECT 
    @Hostname AS Hostname,
    @Version AS Version,
    @Edition AS Edition,
    @IsClusteredInstance AS IsClusteredInstance,
    @IsInstanceinSingleUserMode AS IsInstanceinSingleUserMode;

-- Disk Status
SELECT DISTINCT 
    volumes.logical_volume_name AS LogicalName,
    volumes.volume_mount_point AS Drive,
    CONVERT(INT, volumes.available_bytes / 1024 / 1024 / 1024) AS FreeSpace,
    CONVERT(INT, volumes.total_bytes / 1024 / 1024 / 1024) AS TotalSpace,
    CONVERT(INT, volumes.total_bytes / 1024 / 1024 / 1024) - CONVERT(INT, volumes.available_bytes / 1024 / 1024 / 1024) AS OccupiedSpace
FROM 
    sys.master_files mf
CROSS APPLY 
    sys.dm_os_volume_stats(mf.database_id, mf.FILE_ID) volumes;

-- Database Backup Info
CREATE TABLE #BackupInformation (
    DatabaseName VARCHAR(200), 
    BackupType VARCHAR(50), 
    BackupStartDate DATETIME, 
    BackupFinishDate DATETIME, 
    Username VARCHAR(200), 
    BackupSize NUMERIC(10, 2), 
    BackupUser VARCHAR(250)
);

WITH backup_information AS (
    SELECT
        database_name,
        backup_type = CASE type
            WHEN 'D' THEN 'Full backup'
            WHEN 'I' THEN 'Differential backup'
            WHEN 'L' THEN 'Log backup'
            ELSE 'Other or copy only backup'
        END,
        backup_start_date,
        backup_finish_date,
        user_name,
        server_name,
        compressed_backup_size,
        rownum = ROW_NUMBER() OVER (PARTITION BY database_name, type ORDER BY backup_finish_date DESC)
    FROM 
        msdb.dbo.backupset
)
INSERT INTO #BackupInformation
SELECT
    database_name AS DatabaseName,
    backup_type AS BackupType,
    backup_start_date AS BackupStartDate,
    backup_finish_date AS BackupFinishDate,
    server_name AS ServerName,
    CONVERT(VARCHAR, CONVERT(NUMERIC(10, 2), compressed_backup_size / 1024 / 1024)) AS BackupSizeInMB,
    user_name AS BackupUser
FROM 
    backup_information
WHERE 
    rownum = 1
ORDER BY 
    database_name;

SELECT * FROM #BackupInformation;

-- SQL Job Status
CREATE TABLE #JobInformation (
    Servername VARCHAR(100), 
    CategoryName VARCHAR(100), 
    JobName VARCHAR(500),
    OwnerID VARCHAR(250), 
    Enabled VARCHAR(5), 
    NextRunDate DATETIME, 
    LastRunDate DATETIME, 
    Status VARCHAR(50)
);

INSERT INTO #JobInformation (Servername, CategoryName, JobName, OwnerID, Enabled, NextRunDate, LastRunDate, Status)
SELECT 
    CONVERT(VARCHAR, SERVERPROPERTY('Servername')) AS ServerName,
    categories.NAME AS CategoryName,
    sqljobs.name,
    SUSER_SNAME(sqljobs.owner_sid) AS OwnerID,
    CASE sqljobs.enabled WHEN 1 THEN 'Yes' ELSE 'No' END AS Enabled,
    CASE job_schedule.next_run_date
        WHEN 0 THEN CONVERT(DATETIME, '1900-01-01')
        ELSE CONVERT(DATETIME, CONVERT(CHAR(8), job_schedule.next_run_date, 112) 
            + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), job_schedule.next_run_time), 6), 5, 0, ':'), 3, 0, ':'))
    END AS NextScheduledRunDate,
    lastrunjobhistory.LastRunDate,
    ISNULL(lastrunjobhistory.run_status_desc, 'Unknown') AS run_status_desc
FROM 
    msdb.dbo.sysjobs AS sqljobs
LEFT JOIN 
    msdb.dbo.sysjobschedules AS job_schedule ON sqljobs.job_id = job_schedule.job_id
LEFT JOIN 
    msdb.dbo.sysschedules AS schedule ON job_schedule.schedule_id = schedule.schedule_id
INNER JOIN 
    msdb.dbo.syscategories AS categories ON sqljobs.category_id = categories.category_id
LEFT OUTER JOIN (
    SELECT 
        Jobhistory.job_id
    FROM 
        msdb.dbo.sysjobhistory AS Jobhistory
    WHERE 
        Jobhistory.step_id = 0
    GROUP BY 
        Jobhistory.job_id
) AS jobhistory ON jobhistory.job_id = sqljobs.job_id  
LEFT OUTER JOIN (
    SELECT 
        sysjobhist.job_id,
        CASE sysjobhist.run_date
            WHEN 0 THEN CONVERT(DATETIME, '1900-01-01')
            ELSE CONVERT(DATETIME, CONVERT(CHAR(8), sysjobhist.run_date, 112) 
                + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), sysjobhist.run_time), 6), 5, 0, ':'), 3, 0, ':'))
        END AS LastRunDate,
        sysjobhist.run_status,
        CASE sysjobhist.run_status
            WHEN 0 THEN 'Failed'
            WHEN 1 THEN 'Succeeded'
            WHEN 2 THEN 'Retry'
            WHEN 3 THEN 'Canceled'
            WHEN 4 THEN 'In Progress'
            ELSE 'Unknown'
        END AS run_status_desc,
        sysjobhist.retries_attempted,
        sysjobhist.step_id,
        sysjobhist.step_name,
        sysjobhist.run_duration AS RunTimeInSeconds,
        sysjobhist.message,
        ROW_NUMBER() OVER (PARTITION BY sysjobhist.job_id ORDER BY CASE sysjobhist.run_date
            WHEN 0 THEN CONVERT(DATETIME, '1900-01-01')
            ELSE CONVERT(DATETIME, CONVERT(CHAR(8), sysjobhist.run_date, 112) 
                + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), sysjobhist.run_time), 6), 5, 0, ':'), 3, 0, ':'))
        END DESC) AS RowOrder
    FROM 
        msdb.dbo.sysjobhistory AS sysjobhist
    WHERE 
        sysjobhist.step_id = 0  
) AS lastrunjobhistory ON lastrunjobhistory.job_id = sqljobs.job_id  
    AND lastrunjobhistory.RowOrder = 1;

SELECT * FROM #JobInformation;

-- Monitor and Optimize SQL Database Server
SELECT 
    @@VERSION AS ServerVersion,
    STRING_AGG(schema_name, ', ') AS Databases,
    STRING_AGG(CONCAT(schema_name, ': ', ROUND(SUM((data_length + index_length) / 1024 / 1024), 2), ' MB'), ', ') AS DatabaseSizes,
    (SELECT ROUND((cntr_value / 1024), 2) FROM sys.dm_os_performance_counters WHERE counter_name = 'Total Server Memory (KB)') AS TotalServerMemory_MB,
    (SELECT ROUND((cntr_value / 1024), 2) FROM sys.dm_os_performance_counters WHERE counter_name = 'Target Server Memory (KB)') AS TargetServerMemory_MB,
    (SELECT cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'Processor Time' AND object_name = 'Processor' AND instance_name = '_Total') AS CPU_Usage_Percentage,
    (SELECT STRING_AGG(CONCAT(t1.session_id, ': ', t2.text), '; ') 
     FROM sys.dm_exec_requests t1 CROSS APPLY sys.dm_exec_sql_text(t1.sql_handle) AS t2 
     WHERE t1.status = 'running') AS LongRunningQueries,
    (SELECT STRING_AGG(CONCAT(t1.request_session_id, ' (Blocked by: ', t1.blocking_session
