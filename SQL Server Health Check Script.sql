-- Database Info
SELECT 
    db.database_id,
    db.name AS DatabaseName,
    db.create_date AS CreationDate,
    sp.name AS OwnerName,
    db.user_access_desc AS UserAccess,
    db.state_desc AS State,
    db.compatibility_level AS CompatibilityLevel,
    db.recovery_model_desc AS RecoveryModel,
    SUM((mf.size * 8) / 1024) AS DBSizeInMB
FROM 
    sys.databases db
INNER JOIN 
    sys.server_principals sp ON db.owner_sid = sp.sid
INNER JOIN 
    sys.master_files mf ON db.database_id = mf.database_id
WHERE 
    db.database_id > 5
GROUP BY 
    db.database_id, db.name, db.create_date, sp.name, 
    db.user_access_desc, db.state_desc, 
    db.compatibility_level, db.recovery_model_desc;

-- Server and Instance Status
DECLARE 
    @DatabaseServerInformation NVARCHAR(MAX),
    @Hostname VARCHAR(50) = CONVERT(VARCHAR(50), @@SERVERNAME),
    @Version VARCHAR(MAX) = CONVERT(VARCHAR(MAX), @@VERSION),
    @Edition VARCHAR(50) = CONVERT(VARCHAR(50), SERVERPROPERTY('edition')),
    @IsClusteredInstance VARCHAR(50) = 
        CASE SERVERPROPERTY('IsClustered')
            WHEN 1 THEN 'Clustered Instance'
            WHEN 0 THEN 'Non-Clustered Instance'
            ELSE 'Unknown'
        END,
    @IsInstanceinSingleUserMode VARCHAR(50) = 
        CASE SERVERPROPERTY('IsSingleUser')
            WHEN 1 THEN 'Single User'
            WHEN 0 THEN 'Multi User'
            ELSE 'Unknown'
        END;

-- Output the Value
SELECT 
    @Hostname AS Hostname,
    @Version AS Version,
    @Edition AS Edition,
    @IsClusteredInstance AS IsClusteredInstance,
    @IsInstanceinSingleUserMode AS IsInstanceinSingleUserMode;

-- Disk Status
SELECT DISTINCT 
    vs.logical_volume_name AS LogicalName,
    vs.volume_mount_point AS Drive,
    CONVERT(INT, vs.available_bytes / 1024 / 1024 / 1024) AS FreeSpaceGB,
    CONVERT(INT, vs.total_bytes / 1024 / 1024 / 1024) AS TotalSpaceGB,
    CONVERT(INT, (vs.total_bytes - vs.available_bytes) / 1024 / 1024 / 1024) AS OccupiedSpaceGB
FROM 
    sys.master_files mf
CROSS APPLY 
    sys.dm_os_volume_stats(mf.database_id, mf.FILE_ID) vs;

-- Database Backup Info
CREATE TABLE #BackupInformation (
    DatabaseName VARCHAR(200), 
    BackupType VARCHAR(50), 
    BackupStartDate DATETIME, 
    BackupFinishDate DATETIME, 
    BackupSizeInMB NUMERIC(10, 2), 
    BackupUser VARCHAR(250)
);

WITH backup_info AS (
    SELECT
        database_name,
        CASE type
            WHEN 'D' THEN 'Full backup'
            WHEN 'I' THEN 'Differential backup'
            WHEN 'L' THEN 'Log backup'
            ELSE 'Other or copy-only backup'
        END AS backup_type,
        backup_start_date,
        backup_finish_date,
        CONVERT(NUMERIC(10, 2), compressed_backup_size / 1024 / 1024) AS BackupSizeInMB,
        user_name AS BackupUser,
        ROW_NUMBER() OVER (PARTITION BY database_name, type ORDER BY backup_finish_date DESC) AS rownum
    FROM 
        msdb.dbo.backupset
)
INSERT INTO #BackupInformation
SELECT
    database_name,
    backup_type,
    backup_start_date,
    backup_finish_date,
    BackupSizeInMB,
    BackupUser
FROM 
    backup_info
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
    Enabled VARCHAR(3), 
    NextRunDate DATETIME, 
    LastRunDate DATETIME, 
    Status VARCHAR(50)
);

INSERT INTO #JobInformation (Servername, CategoryName, JobName, OwnerID, Enabled, NextRunDate, LastRunDate, Status)
SELECT 
    CONVERT(VARCHAR, SERVERPROPERTY('Servername')) AS Servername,
    cat.NAME AS CategoryName,
    job.name AS JobName,
    SUSER_SNAME(job.owner_sid) AS OwnerID,
    CASE job.enabled WHEN 1 THEN 'Yes' ELSE 'No' END AS Enabled,
    CASE js.next_run_date
        WHEN 0 THEN CONVERT(DATETIME, '1900-01-01')
        ELSE CONVERT(DATETIME, CONVERT(CHAR(8), js.next_run_date, 112) 
            + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), js.next_run_time), 6), 5, 0, ':'), 3, 0, ':'))
    END AS NextRunDate,
    ljs.LastRunDate,
    ISNULL(ljs.run_status_desc, 'Unknown') AS Status
FROM 
    msdb.dbo.sysjobs AS job
LEFT JOIN 
    msdb.dbo.sysjobschedules AS js ON job.job_id = js.job_id
LEFT JOIN 
    msdb.dbo.syscategories AS cat ON job.category_id = cat.category_id
LEFT OUTER JOIN (
    SELECT 
        jh.job_id,
        MAX(CASE jh.run_date
            WHEN 0 THEN CONVERT(DATETIME, '1900-01-01')
            ELSE CONVERT(DATETIME, CONVERT(CHAR(8), jh.run_date, 112) 
                + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), jh.run_time), 6), 5, 0, ':'), 3, 0, ':'))
        END) AS LastRunDate,
        MAX(jh.run_status) AS run_status,
        MAX(CASE jh.run_status
            WHEN 0 THEN 'Failed'
            WHEN 1 THEN 'Succeeded'
            WHEN 2 THEN 'Retry'
            WHEN 3 THEN 'Canceled'
            WHEN 4 THEN 'In Progress'
            ELSE 'Unknown'
        END) AS run_status_desc
    FROM 
        msdb.dbo.sysjobhistory AS jh
    WHERE 
        jh.step_id = 0  
    GROUP BY 
        jh.job_id
) AS ljs ON ljs.job_id = job.job_id;

SELECT * FROM #JobInformation;

-- Monitor and Optimize SQL Database Server
SELECT 
    @@VERSION AS ServerVersion,
    STRING_AGG(db.name, ', ') AS Databases,
    STRING_AGG(CONCAT(db.name, ': ', ROUND(SUM((mf.size * 8) / 1024 / 1024), 2), ' MB'), ', ') AS DatabaseSizes,
    (SELECT ROUND((pc.cntr_value / 1024), 2) 
     FROM sys.dm_os_performance_counters pc 
     WHERE pc.counter_name = 'Total Server Memory (KB)') AS TotalServerMemory_MB,
    (SELECT ROUND((pc.cntr_value / 1024), 2) 
     FROM sys.dm_os_performance_counters pc 
     WHERE pc.counter_name = 'Target Server Memory (KB)') AS TargetServerMemory_MB,
    (SELECT pc.cntr_value 
     FROM sys.dm_os_performance_counters pc 
     WHERE pc.counter_name = 'Processor Time' 
       AND pc.object_name = 'Processor' 
       AND pc.instance_name = '_Total') AS CPU_Usage_Percentage,
    (SELECT STRING_AGG(CONCAT(r.session_id, ': ', t.text), '; ') 
     FROM sys.dm_exec_requests r 
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t 
     WHERE r.status = 'running') AS LongRunningQueries
FROM 
    sys.databases db
JOIN 
    sys.master_files mf ON db.database_id = mf.database_id
GROUP BY 
    db.name;
