-- Server and Instance Information
DECLARE 
    @Hostname VARCHAR(50) = CONVERT(VARCHAR(50), @@SERVERNAME),
    @Version VARCHAR(MAX) = CONVERT(VARCHAR(MAX), @@VERSION),
    @Edition VARCHAR(50) = CONVERT(VARCHAR(50), SERVERPROPERTY('edition')),
    @IsClusteredInstance VARCHAR(50) = CASE SERVERPROPERTY('IsClustered')
        WHEN 1 THEN 'Clustered Instance'
        WHEN 0 THEN 'Non-Clustered Instance'
        ELSE 'Unknown'
    END,
    @IsInstanceSingleUserMode VARCHAR(50) = CASE SERVERPROPERTY('IsSingleUser')
        WHEN 1 THEN 'Single User'
        WHEN 0 THEN 'Multi User'
        ELSE 'Unknown'
    END;

-- Output Server Information
SELECT 
    @Hostname AS Hostname,
    @Version AS Version,
    @Edition AS Edition,
    @IsClusteredInstance AS ClusteredInstance,
    @IsInstanceSingleUserMode AS InstanceMode;

-- Database Information
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
GROUP BY 
    db.database_id, 
    db.name, 
    db.create_date, 
    sp.name, 
    db.user_access_desc, 
    db.state_desc, 
    db.compatibility_level, 
    db.recovery_model_desc;

-- SQL Job Information
SELECT 
    job.name AS JobName,
    SUSER_SNAME(job.owner_sid) AS JobOwner,
    CASE job.enabled WHEN 1 THEN 'Enabled' ELSE 'Disabled' END AS JobStatus,
    CASE js.next_run_date 
        WHEN 0 THEN 'No Schedule' 
        ELSE CONVERT(VARCHAR, js.next_run_date, 112) + ' ' + CONVERT(VARCHAR(8), js.next_run_time, 108)
    END AS NextRunTime,
    ljs.LastRunDate,
    ISNULL(ljs.run_status_desc, 'Unknown') AS LastRunStatus
FROM 
    msdb.dbo.sysjobs AS job
LEFT JOIN 
    msdb.dbo.sysjobschedules AS js ON job.job_id = js.job_id
LEFT JOIN (
    SELECT 
        jh.job_id,
        MAX(CASE jh.run_date
            WHEN 0 THEN CONVERT(DATETIME, '1900-01-01')
            ELSE CONVERT(DATETIME, CONVERT(CHAR(8), jh.run_date, 112) 
                + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), jh.run_time), 6), 5, 0, ':'), 3, 0, ':'))
        END) AS LastRunDate,
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

-- Disk Space Information
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
