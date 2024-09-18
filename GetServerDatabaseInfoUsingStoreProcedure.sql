CREATE PROCEDURE GetServerDatabaseInfo
AS
BEGIN
    -- Step 1: Retrieve Database Information
    SELECT  
        a.database_id,
        a.name AS DatabaseName,
        a.create_date AS CreationDate,
        b.name AS OwnerName,
        a.user_access_desc AS AccessType,
        a.state_desc AS DatabaseState,
        a.compatibility_level AS CompatibilityLevel,
        a.recovery_model_desc AS RecoveryModel,
        SUM((c.size * 8) / 1024) AS DBSizeInMB
    FROM sys.databases a 
    INNER JOIN sys.server_principals b ON a.owner_sid = b.sid 
    INNER JOIN sys.master_files c ON a.database_id = c.database_id
    WHERE a.database_id > 5
    GROUP BY 
        a.database_id,
        a.name,
        a.create_date,
        b.name,
        a.user_access_desc,
        a.state_desc,
        a.compatibility_level,
        a.recovery_model_desc;

    -- Step 2: Get Server and Instance Status
    DECLARE 
        @Hostname VARCHAR(50) = (SELECT CONVERT(VARCHAR(50), @@SERVERNAME)),
        @Version VARCHAR(MAX) = (SELECT CONVERT(VARCHAR(MAX), @@VERSION)),
        @Edition VARCHAR(50) = (SELECT CONVERT(VARCHAR(50), SERVERPROPERTY('Edition'))),
        @IsClustered VARCHAR(50) = (SELECT CASE SERVERPROPERTY('IsClustered') WHEN 1 THEN 'Clustered' ELSE 'Non-Clustered' END),
        @InstanceMode VARCHAR(50) = (SELECT CASE SERVERPROPERTY('IsSingleUser') WHEN 1 THEN 'Single-User' ELSE 'Multi-User' END);

    SELECT 
        @Hostname AS Hostname,
        @Version AS Version,
        @Edition AS Edition,
        @IsClustered AS ClusterType,
        @InstanceMode AS InstanceMode;

    -- Step 3: Disk Usage Status
    SELECT DISTINCT 
        volumes.logical_volume_name AS LogicalVolume,
        volumes.volume_mount_point AS MountPoint,
        CONVERT(INT, volumes.available_bytes / 1024 / 1024 / 1024) AS FreeSpaceGB,
        CONVERT(INT, volumes.total_bytes / 1024 / 1024 / 1024) AS TotalSpaceGB,
        CONVERT(INT, (volumes.total_bytes - volumes.available_bytes) / 1024 / 1024 / 1024) AS UsedSpaceGB
    FROM sys.master_files mf
    CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.FILE_ID) volumes;

    -- Step 4: Database Backup Information
    CREATE TABLE #BackupInfo 
    (
        DatabaseName VARCHAR(200), 
        BackupType VARCHAR(50), 
        BackupStartDate DATETIME, 
        BackupFinishDate DATETIME, 
        BackupUser VARCHAR(250), 
        BackupSizeInMB NUMERIC(10, 2)
    );

    WITH BackupDetails AS
    (
        SELECT
            database_name,
            CASE type
                WHEN 'D' THEN 'Full'
                WHEN 'I' THEN 'Differential'
                WHEN 'L' THEN 'Log'
                ELSE 'Other'
            END AS BackupType,
            backup_start_date,
            backup_finish_date,
            user_name,
            compressed_backup_size,
            ROW_NUMBER() OVER (PARTITION BY database_name, type ORDER BY backup_finish_date DESC) AS row_num
        FROM msdb.dbo.backupset
    )
    INSERT INTO #BackupInfo
    SELECT
        database_name AS DatabaseName,
        BackupType,
        backup_start_date AS BackupStartDate,
        backup_finish_date AS BackupFinishDate,
        user_name AS BackupUser,
        CONVERT(NUMERIC(10, 2), compressed_backup_size / 1024 / 1024) AS BackupSizeInMB
    FROM BackupDetails
    WHERE row_num = 1
    ORDER BY database_name;

    SELECT * FROM #BackupInfo;
    DROP TABLE #BackupInfo;

    -- Step 5: SQL Job Information
    CREATE TABLE #JobInfo
    (
        ServerName VARCHAR(100), 
        JobCategory VARCHAR(100),
        JobName VARCHAR(500),
        JobOwner VARCHAR(250),
        IsEnabled VARCHAR(5),
        NextRunDate DATETIME, 
        LastRunDate DATETIME, 
        JobStatus VARCHAR(50)
    );

    INSERT INTO #JobInfo 
    SELECT 
        CONVERT(VARCHAR, SERVERPROPERTY('ServerName')) AS ServerName,
        categories.NAME AS JobCategory,
        jobs.name AS JobName,
        SUSER_SNAME(jobs.owner_sid) AS JobOwner,
        CASE jobs.enabled WHEN 1 THEN 'Yes' ELSE 'No' END AS IsEnabled,
        CASE schedules.next_run_date
            WHEN 0 THEN NULL
            ELSE CONVERT(DATETIME, CONVERT(CHAR(8), schedules.next_run_date, 112) + ' ' + 
            STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), schedules.next_run_time), 6), 5, 0, ':'), 3, 0, ':'))
        END AS NextRunDate,
        last_run.LastRunDate,
        ISNULL(last_run.JobStatus, 'Unknown') AS JobStatus
    FROM msdb.dbo.sysjobs AS jobs
    LEFT JOIN msdb.dbo.sysjobschedules AS schedules ON jobs.job_id = schedules.job_id
    LEFT JOIN msdb.dbo.sysschedules AS schedule ON schedules.schedule_id = schedule.schedule_id
    INNER JOIN msdb.dbo.syscategories AS categories ON jobs.category_id = categories.category_id
    LEFT JOIN (
        SELECT 
            job_id,
            MAX(CONVERT(DATETIME, CONVERT(CHAR(8), run_date, 112) + ' ' + 
            STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), run_time), 6), 5, 0, ':'), 3, 0, ':'))) AS LastRunDate,
            CASE run_status
                WHEN 0 THEN 'Failed'
                WHEN 1 THEN 'Succeeded'
                WHEN 2 THEN 'Retry'
                WHEN 3 THEN 'Canceled'
                WHEN 4 THEN 'In Progress'
                ELSE 'Unknown'
            END AS JobStatus
        FROM msdb.dbo.sysjobhistory
        WHERE step_id = 0
        GROUP BY job_id
    ) AS last_run ON jobs.job_id = last_run.job_id;

    SELECT * FROM #JobInfo;
    DROP TABLE #JobInfo;

    -- Step 6: System Monitoring: CPU, Memory, and I/O Stats
    -- CPU and Memory Usage
    SELECT 
        record_id, 
        event_time, 
        SQLProcessUtilization, 
        SystemIdle, 
        100 - SystemIdle - SQLProcessUtilization AS OtherProcessUtilization 
    FROM sys.dm_os_ring_buffers 
    WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
    AND record_id = (SELECT MAX(record_id) 
                    FROM sys.dm_os_ring_buffers 
                    WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR');

    -- I/O Statistics
    SELECT 
        db_name(database_id) AS DatabaseName,
        file_id,
        io_stall_read_ms,
        num_of_reads,
        io_stall_write_ms,
        num_of_writes,
        io_stall_read_ms / num_of_reads AS AvgReadStallMS,
        io_stall_write_ms / num_of_writes AS AvgWriteStallMS
    FROM sys.dm_io_virtual_file_stats(NULL, NULL);

    -- Wait Statistics
    SELECT 
        wait_type, 
        waiting_tasks_count, 
        wait_time_ms, 
        max_wait_time_ms, 
        signal_wait_time_ms 
    FROM sys.dm_os_wait_stats 
    ORDER BY wait_time_ms DESC;

    -- Error Log
    EXEC sp_readerrorlog;

    -- Index Fragmentation
    SELECT 
        schemas.[name] AS SchemaName, 
        tables.[name] AS TableName, 
        indexes.[name] AS IndexName, 
        stats.avg_fragmentation_in_percent AS FragmentationPercentage
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS stats
    INNER JOIN sys.tables AS tables ON stats.[object_id] = tables.[object_id]
    INNER JOIN sys.schemas AS schemas ON tables.[schema_id] = schemas.[schema_id]
    INNER JOIN sys.indexes AS indexes ON stats.[object_id] = indexes.[object_id]
    WHERE stats.avg_fragmentation_in_percent > 10
    ORDER BY stats.avg_fragmentation_in_percent DESC;

    -- Query Store: Top Resource-Consuming Queries
    SELECT 
        TOP 10 query_text,
        plan_id,
        execution_count,
        total_cpu_time_ms,
        total_duration_ms,
        total_logical_reads,
        total_logical_writes
    FROM sys.query_store_query_text AS qt
    INNER JOIN sys.query_store_query AS q ON qt.query_text_id = q.query_text_id
    INNER JOIN sys.query_store_plan AS p ON q.query_id = p.query_id
    ORDER BY total_cpu_time_ms DESC;

    -- Blocking and Deadlocks
    SELECT 
        blocking_session_id, 
        session_id, 
        wait_type, 
        wait_duration_ms, 
        wait_resource 
    FROM sys.dm_exec_requests 
    WHERE blocking_session_id <> 0;

    -- Security and Permission Audit
    SELECT 
        principals.principal_id, 
        principals.name AS PrincipalName, 
        principals.type_desc AS PrincipalType, 
        permissions.state_desc AS PermissionState, 
        permissions.permission_name AS PermissionName
    FROM sys.database_principals AS principals
    LEFT JOIN sys.database_permissions AS permissions ON principals.principal_id = permissions.grantee_principal_id
    WHERE principals.type NOT IN ('R', 'S')
    ORDER BY principals.principal_id;

END;
