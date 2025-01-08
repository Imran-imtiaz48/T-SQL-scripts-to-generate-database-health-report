CREATE PROCEDURE GetServerDatabaseInfo
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Step 1: Fetch Database Information
        PRINT 'Fetching Database Information...';
        SELECT  
            a.database_id,
            a.name AS DatabaseName,
            a.create_date AS CreationDate,
            b.name AS OwnerName,
            a.user_access_desc AS UserAccess,
            a.state_desc AS State,
            a.compatibility_level AS CompatibilityLevel,
            a.recovery_model_desc AS RecoveryModel,
            SUM((c.size * 8) / 1024) AS DBSizeInMB
        FROM 
            sys.databases a
            INNER JOIN sys.server_principals b ON a.owner_sid = b.sid
            INNER JOIN sys.master_files c ON a.database_id = c.database_id
        WHERE 
            a.database_id > 5 -- Exclude system databases
        GROUP BY 
            a.database_id, a.name, a.create_date, b.name, a.user_access_desc,
            a.compatibility_level, a.state_desc, a.recovery_model_desc;

        -- Step 2: Server and Instance Status
        PRINT 'Fetching Server and Instance Status...';
        SELECT 
            CONVERT(VARCHAR(50), @@SERVERNAME) AS Hostname,
            CONVERT(VARCHAR(MAX), @@VERSION) AS Version,
            SERVERPROPERTY('edition') AS Edition,
            CASE SERVERPROPERTY('IsClustered') 
                WHEN 1 THEN 'Clustered Instance' 
                ELSE 'Non-Clustered Instance' 
            END AS IsClusteredInstance,
            CASE SERVERPROPERTY('IsSingleUser') 
                WHEN 1 THEN 'Single User' 
                ELSE 'Multi-User' 
            END AS IsInstanceInSingleUserMode;

        -- Step 3: Disk Status
        PRINT 'Fetching Disk Status...';
        SELECT DISTINCT 
            volumes.logical_volume_name AS LogicalName,
            volumes.volume_mount_point AS Drive,
            CONVERT(INT, volumes.available_bytes / 1024 / 1024 / 1024) AS FreeSpaceGB,
            CONVERT(INT, volumes.total_bytes / 1024 / 1024 / 1024) AS TotalSpaceGB,
            CONVERT(INT, volumes.total_bytes / 1024 / 1024 / 1024) 
            - CONVERT(INT, volumes.available_bytes / 1024 / 1024 / 1024) AS OccupiedSpaceGB
        FROM 
            sys.master_files mf
            CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.FILE_ID) volumes;

        -- Step 4: Database Backup Information
        PRINT 'Fetching Database Backup Information...';
        CREATE TABLE #BackupInformation 
        (
            DatabaseName VARCHAR(200), 
            BackupType VARCHAR(50), 
            BackupStartDate DATETIME, 
            BackupFinishDate DATETIME, 
            Username VARCHAR(200), 
            BackupSizeInMB NUMERIC(10, 2)
        );

        WITH BackupData AS
        (
            SELECT
                database_name,
                CASE type
                    WHEN 'D' THEN 'Full Backup'
                    WHEN 'I' THEN 'Differential Backup'
                    WHEN 'L' THEN 'Log Backup'
                    ELSE 'Other/Copy-only Backup'
                END AS BackupType,
                backup_start_date,
                backup_finish_date,
                user_name AS Username,
                compressed_backup_size / 1024 / 1024 AS BackupSizeInMB,
                ROW_NUMBER() OVER (PARTITION BY database_name, type ORDER BY backup_finish_date DESC) AS RowNum
            FROM 
                msdb.dbo.backupset
        )
        INSERT INTO #BackupInformation
        SELECT 
            database_name, BackupType, backup_start_date, backup_finish_date, Username, BackupSizeInMB
        FROM 
            BackupData
        WHERE 
            RowNum = 1;

        SELECT * FROM #BackupInformation;
        DROP TABLE #BackupInformation;

        -- Step 5: SQL Job Status
        PRINT 'Fetching SQL Job Information...';
        CREATE TABLE #JobInformation
        (
            ServerName VARCHAR(100), 
            CategoryName VARCHAR(100),
            JobName VARCHAR(500),
            Owner VARCHAR(250),
            Enabled VARCHAR(5),
            NextRunDate DATETIME, 
            LastRunDate DATETIME, 
            Status VARCHAR(50)
        );

        INSERT INTO #JobInformation
        SELECT 
            CONVERT(VARCHAR, SERVERPROPERTY('Servername')) AS ServerName,
            categories.name AS CategoryName,
            jobs.name AS JobName,
            SUSER_SNAME(jobs.owner_sid) AS Owner,
            CASE jobs.enabled WHEN 1 THEN 'Yes' ELSE 'No' END AS Enabled,
            CASE schedules.next_run_date
                WHEN 0 THEN NULL
                ELSE CONVERT(DATETIME, 
                    CONVERT(CHAR(8), schedules.next_run_date, 112) 
                    + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), schedules.next_run_time), 6), 5, 0, ':'), 3, 0, ':'))
            END AS NextRunDate,
            history.LastRunDate,
            history.RunStatus
        FROM 
            msdb.dbo.sysjobs jobs
            LEFT JOIN msdb.dbo.sysjobschedules schedules ON jobs.job_id = schedules.job_id
            LEFT JOIN msdb.dbo.syscategories categories ON jobs.category_id = categories.category_id
            LEFT JOIN 
            (
                SELECT 
                    job_id,
                    MAX(CONVERT(DATETIME, CONVERT(CHAR(8), run_date, 112) 
                    + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), run_time), 6), 5, 0, ':'), 3, 0, ':'))) AS LastRunDate,
                    CASE MAX(run_status)
                        WHEN 0 THEN 'Failed'
                        WHEN 1 THEN 'Succeeded'
                        ELSE 'Unknown'
                    END AS RunStatus
                FROM 
                    msdb.dbo.sysjobhistory
                WHERE step_id = 0
                GROUP BY job_id
            ) history ON jobs.job_id = history.job_id;

        SELECT * FROM #JobInformation;
        DROP TABLE #JobInformation;

    END TRY
    BEGIN CATCH
        PRINT 'Error occurred while executing the procedure.';
        SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_SEVERITY() AS Severity, ERROR_STATE() AS ErrorState;
    END CATCH
END;
