-- Retrieve detailed database information
SELECT 
    a.database_id,
    a.name AS DatabaseName,
    a.create_date AS CreationDate,
    b.name AS OwnerName,
    a.user_access_desc AS AccessType,
    a.state_desc AS State,
    a.compatibility_level AS CompatibilityLevel,
    a.recovery_model_desc AS RecoveryModel,
    SUM((c.size * 8) / 1024) AS DBSizeInMB
FROM sys.databases a
INNER JOIN sys.server_principals b ON a.owner_sid = b.sid
INNER JOIN sys.master_files c ON a.database_id = c.database_id
WHERE a.database_id > 5
GROUP BY 
    a.database_id, a.name, a.create_date, b.name, 
    a.user_access_desc, a.state_desc, 
    a.compatibility_level, a.recovery_model_desc;

-- Retrieve server and instance status
DECLARE 
    @DatabaseServerInfo NVARCHAR(MAX),
    @Hostname VARCHAR(50) = CONVERT(VARCHAR(50), @@SERVERNAME),
    @Version NVARCHAR(MAX) = CONVERT(VARCHAR(MAX), @@VERSION),
    @Edition VARCHAR(50) = CONVERT(VARCHAR(50), SERVERPROPERTY('Edition')),
    @IsClusteredInstance VARCHAR(50) = 
        CASE SERVERPROPERTY('IsClustered')
            WHEN 1 THEN 'Clustered Instance'
            WHEN 0 THEN 'Non-Clustered Instance'
            ELSE 'Unknown'
        END,
    @IsInstanceSingleUser VARCHAR(50) = 
        CASE SERVERPROPERTY('IsSingleUser')
            WHEN 1 THEN 'Single User'
            WHEN 0 THEN 'Multi-User'
            ELSE 'Unknown'
        END;

-- Output server and instance status
SELECT 
    @Hostname AS Hostname,
    @Version AS Version,
    @Edition AS Edition,
    @IsClusteredInstance AS IsClusteredInstance,
    @IsInstanceSingleUser AS InstanceUserMode;

-- Retrieve disk status
SELECT DISTINCT 
    volumes.logical_volume_name AS LogicalName,
    volumes.volume_mount_point AS Drive,
    CONVERT(INT, volumes.available_bytes / 1024 / 1024 / 1024) AS FreeSpaceGB,
    CONVERT(INT, volumes.total_bytes / 1024 / 1024 / 1024) AS TotalSpaceGB,
    CONVERT(INT, volumes.total_bytes / 1024 / 1024 / 1024) - 
    CONVERT(INT, volumes.available_bytes / 1024 / 1024 / 1024) AS OccupiedSpaceGB
FROM sys.master_files mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.FILE_ID) volumes;

-- Backup information
CREATE TABLE #BackupInformation (
    DatabaseName VARCHAR(200),
    BackupType VARCHAR(50),
    BackupStartDate DATETIME,
    BackupFinishDate DATETIME,
    UserName VARCHAR(200),
    BackupSize NUMERIC(10, 2),
    BackupUser VARCHAR(250)
);

WITH backup_info AS (
    SELECT 
        database_name,
        CASE type
            WHEN 'D' THEN 'Full Backup'
            WHEN 'I' THEN 'Differential Backup'
            WHEN 'L' THEN 'Log Backup'
            ELSE 'Other or Copy-Only Backup'
        END AS BackupType,
        backup_start_date,
        backup_finish_date,
        user_name,
        compressed_backup_size,
        ROW_NUMBER() OVER (PARTITION BY database_name, type ORDER BY backup_finish_date DESC) AS RowNum
    FROM msdb.dbo.backupset
)
INSERT INTO #BackupInformation
SELECT 
    database_name AS DatabaseName,
    BackupType,
    backup_start_date AS BackupStartDate,
    backup_finish_date AS BackupFinishDate,
    user_name AS BackupUser,
    CONVERT(VARCHAR, CONVERT(NUMERIC(10, 2), compressed_backup_size / 1024 / 1024)) AS BackupSizeMB
FROM backup_info
WHERE RowNum = 1;

SELECT * FROM #BackupInformation;

-- Status of SQL Jobs
CREATE TABLE #JobInformation (
    ServerName VARCHAR(100),
    CategoryName VARCHAR(100),
    JobName VARCHAR(500),
    OwnerID VARCHAR(250),
    Enabled VARCHAR(5),
    NextRunDate DATETIME,
    LastRunDate DATETIME,
    Status VARCHAR(50)
);

INSERT INTO #JobInformation (ServerName, CategoryName, JobName, OwnerID, Enabled, NextRunDate, LastRunDate, Status)
SELECT 
    CONVERT(VARCHAR, SERVERPROPERTY('ServerName')) AS ServerName,
    categories.name AS CategoryName,
    sqljobs.name AS JobName,
    SUSER_SNAME(sqljobs.owner_sid) AS OwnerID,
    CASE sqljobs.enabled WHEN 1 THEN 'Yes' ELSE 'No' END AS Enabled,
    CASE job_schedule.next_run_date
        WHEN 0 THEN CONVERT(DATETIME, '1900-01-01')
        ELSE CONVERT(DATETIME, CONVERT(CHAR(8), job_schedule.next_run_date, 112) + ' ' + 
        STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), job_schedule.next_run_time), 6), 5, 0, ':'), 3, 0, ':'))
    END AS NextRunDate,
    lastrunjobhistory.LastRunDate,
    ISNULL(lastrunjobhistory.run_status_desc, 'Unknown') AS Status
FROM msdb.dbo.sysjobs sqljobs
LEFT JOIN msdb.dbo.sysjobschedules job_schedule ON sqljobs.job_id = job_schedule.job_id
LEFT JOIN msdb.dbo.sysschedules schedule ON job_schedule.schedule_id = schedule.schedule_id
INNER JOIN msdb.dbo.syscategories categories ON sqljobs.category_id = categories.category_id
LEFT JOIN (
    SELECT 
        sysjobhist.job_id,
        CASE sysjobhist.run_date
            WHEN 0 THEN CONVERT(DATETIME, '1900-01-01')
            ELSE CONVERT(DATETIME, CONVERT(CHAR(8), sysjobhist.run_date, 112) + ' ' + 
            STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), sysjobhist.run_time), 6), 5, 0, ':'), 3, 0, ':'))
        END AS LastRunDate,
        CASE sysjobhist.run_status
            WHEN 0 THEN 'Failed'
            WHEN 1 THEN 'Succeeded'
            WHEN 2 THEN 'Retry'
            WHEN 3 THEN 'Canceled'
            ELSE 'Unknown'
        END AS run_status_desc
    FROM msdb.dbo.sysjobhistory sysjobhist
    WHERE sysjobhist.step_id = 0
) lastrunjobhistory ON lastrunjobhistory.job_id = sqljobs.job_id;

SELECT * FROM #JobInformation;
