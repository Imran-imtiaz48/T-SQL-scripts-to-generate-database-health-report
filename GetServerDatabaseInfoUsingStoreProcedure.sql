CREATE PROCEDURE GetServerDatabaseInfo
AS
BEGIN
    -- Step 1: Database Information
    SELECT  
        a.database_id,
        a.name AS DatabaseName,
        a.create_date AS CreationDate,
        b.name AS OwnerName,
        a.user_access_desc AS UserAccess,
        a.state_desc AS State,
        a.compatibility_level AS CompatibilityLevel,
        a.recovery_model_desc AS RecoveryModel,
        SUM(c.size * 8 / 1024) AS DBSizeInMB -- Convert to MB directly
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

    -- Step 2: Server and Instance Status
    SELECT
        CONVERT(VARCHAR(50), @@SERVERNAME) AS Hostname,
        CONVERT(VARCHAR(MAX), @@VERSION) AS Version,
        CONVERT(VARCHAR(50), SERVERPROPERTY('edition')) AS Edition,
        CASE SERVERPROPERTY('IsClustered') WHEN 1 THEN 'Clustered Instance' ELSE 'Non-Clustered Instance' END AS ClusteredInstance,
        CASE SERVERPROPERTY('IsSingleUser') WHEN 1 THEN 'Single User' ELSE 'Multi User' END AS InstanceUserMode;

    -- Step 3: Disk Status
    SELECT DISTINCT 
        volumes.logical_volume_name AS LogicalName,
        volumes.volume_mount_point AS Drive,
        CONVERT(INT, volumes.available_bytes / 1024 / 1024 / 1024) AS FreeSpaceGB,
        CONVERT(INT, volumes.total_bytes / 1024 / 1024 / 1024) AS TotalSpaceGB,
        CONVERT(INT, (volumes.total_bytes - volumes.available_bytes) / 1024 / 1024 / 1024) AS OccupiedSpaceGB
    FROM sys.master_files mf
    CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.FILE_ID) volumes;

    -- Step 4: Database Backup Information
    WITH backup_information AS
    (
        SELECT
            database_name AS DatabaseName,
            CASE type
                WHEN 'D' THEN 'Full'
                WHEN 'I' THEN 'Differential'
                WHEN 'L' THEN 'Log'
                ELSE 'Other'
            END AS BackupType,
            backup_start_date,
            backup_finish_date,
            user_name AS BackupUser,
            server_name AS ServerName,
            CONVERT(NUMERIC(10, 2), compressed_backup_size / 1024 / 1024) AS BackupSizeMB,
            ROW_NUMBER() OVER (PARTITION BY database_name, type ORDER BY backup_finish_date DESC) AS RowNum
        FROM msdb.dbo.backupset
    )
    SELECT 
        DatabaseName,
        BackupType,
        backup_start_date AS BackupStartDate,
        backup_finish_date AS BackupFinishDate,
        BackupSizeMB,
        BackupUser
    FROM backup_information
    WHERE RowNum = 1
    ORDER BY DatabaseName;

    -- Step 5: SQL Job Status
    WITH last_job_run AS
    (
        SELECT
            job_id,
            MAX(CONVERT(DATETIME, CONVERT(CHAR(8), run_date, 112) + ' ' + 
                         STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), run_time), 6), 5, 0, ':'), 3, 0, ':'))) AS LastRunDate,
            MAX(CASE run_status 
                WHEN 0 THEN 'Failed'
                WHEN 1 THEN 'Succeeded'
                WHEN 2 THEN 'Retry'
                WHEN 3 THEN 'Canceled'
                WHEN 4 THEN 'In Progress'
                ELSE 'Unknown' 
            END) AS Status
        FROM msdb.dbo.sysjobhistory
        WHERE step_id = 0
        GROUP BY job_id
    )
    SELECT
        CONVERT(VARCHAR(100), SERVERPROPERTY('ServerName')) AS ServerName,
        categories.name AS CategoryName,
        sqljobs.name AS JobName,
        SUSER_SNAME(sqljobs.owner_sid) AS Owner,
        CASE sqljobs.enabled WHEN 1 THEN 'Yes' ELSE 'No' END AS Enabled,
        last_job_run.LastRunDate,
        last_job_run.Status
    FROM msdb.dbo.sysjobs sqljobs
    INNER JOIN msdb.dbo.syscategories categories ON sqljobs.category_id = categories.category_id
    LEFT JOIN last_job_run ON sqljobs.job_id = last_job_run.job_id;

    -- Step 6: CPU and Memory Utilization
    SELECT 
        record_id, 
        event_time, 
        SQLProcessUtilization, 
        SystemIdle, 
        100 - SystemIdle - SQLProcessUtilization AS OtherProcessUtilization
    FROM sys.dm_os_ring_buffers
    WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
    AND record_id = (SELECT MAX(record_id) FROM sys.dm_os_ring_buffers
                     WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR');

    -- Step 7: I/O Statistics
    SELECT 
        db_name(database_id) AS DatabaseName,
        file_id,
        io_stall_read_ms,
        num_of_reads,
        io_stall_write_ms,
        num_of_writes,
        io_stall_read_ms / NULLIF(num_of_reads, 0) AS AvgReadStallMS,
        io_stall_write_ms / NULLIF(num_of_writes, 0) AS AvgWriteStallMS
    FROM sys.dm_io_virtual_file_stats(null, null);

    -- Step 8: Wait Statistics
    SELECT 
        wait_type, 
        waiting_tasks_count, 
        wait_time_ms, 
        max_wait_time_ms, 
        signal_wait_time_ms
    FROM sys.dm_os_wait_stats
    ORDER BY wait_time_ms DESC;

    -- Step 9: Error Logs
    EXEC sp_readerrorlog;

    -- Step 10: Index Fragmentation
    SELECT 
        dbschemas.[name] AS SchemaName, 
        dbtables.[name] AS TableName, 
        dbindexes.[name] AS IndexName, 
        indexstats.avg_fragmentation_in_percent AS Fragmentation
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') indexstats
    INNER JOIN sys.tables dbtables ON indexstats.[object_id] = dbtables.[object_id]
    INNER JOIN sys.schemas dbschemas ON dbtables.[schema_id] = dbschemas.[schema_id]
    INNER JOIN sys.indexes dbindexes ON indexstats.[object_id] = dbindexes.[object_id]
    AND indexstats.index_id = dbindexes.index_id
    ORDER BY indexstats.avg_fragmentation_in_percent DESC;

    -- Step 11: Query Store Information
    SELECT TOP 10 
        qt.query_text AS QueryText,
        p.plan_id,
        q.execution_count,
        p.total_cpu_time_ms,
        p.total_duration_ms,
        p.total_logical_reads,
        p.total_logical_writes
    FROM sys.query_store_query_text qt
    JOIN sys.query_store_query q ON qt.query_text_id = q.query_text_id
    JOIN sys.query_store_plan p ON q.query_id = p.query_id
    ORDER BY p.total_cpu_time_ms DESC;

    -- Step 12: Blocking and Deadlocks
    SELECT 
        blocking_session_id, 
        session_id, 
        wait_type, 
        wait_duration_ms, 
        wait_resource
    FROM sys.dm_exec_requests
    WHERE blocking_session_id <> 0;

    -- Step 13: Security and Permission Audits
    SELECT 
        pr.principal_id, 
        pr.name AS PrincipalName, 
        pr.type_desc AS PrincipalType,
        pe.state_desc AS PermissionState,
        pe.permission_name AS Permission
    FROM sys.database_principals pr
    JOIN sys.database_permissions pe ON pr.principal_id = pe.grantee_principal_id
    ORDER BY pr.name;
END;
