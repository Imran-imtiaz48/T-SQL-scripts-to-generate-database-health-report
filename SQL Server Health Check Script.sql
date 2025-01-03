select  a.database_id,
a.name,a.create_date,b.name,a.user_access_desc,a.state_desc,compatibility_level, recovery_model_desc, Sum((c.size*8)/1024) as DBSizeInMB
from sys.databases a inner join sys.server_principals b on a.owner_sid=b.sid inner join sys.master_files c on a.database_id=c.database_id
Where a.database_id>5
Group by a.name,a.create_date,b.name,a.user_access_desc,compatibility_level,a.state_desc, recovery_model_desc,a.database_id

--Server and Instance Status
declare @DatabaseServerInformation nvarchar(max);
declare @Hostname varchar(50) = (select convert(varchar(50),@@SERVERNAME));
declare @Version varchar(max) = (select convert(varchar(max),@@version));
declare @Edition varchar(50) = (select convert(varchar(50),SERVERPROPERTY('edition')));
declare @IsClusteredInstance varchar(50) = 
    (SELECT CASE SERVERPROPERTY ('IsClustered') WHEN 1 THEN 'Clustered Instance' WHEN 0 THEN 'Non Clustered instance' ELSE 'null' END);
declare @IsInstanceinSingleUserMode varchar(50) = 
    (SELECT CASE SERVERPROPERTY ('IsSingleUser') WHEN 1 THEN 'Single user' WHEN 0 THEN 'Multi user' ELSE 'null' END);

-- Output the Value
SELECT 
    @Hostname AS Hostname,
    @Version AS Version,
    @Edition AS Edition,
    @IsClusteredInstance AS IsClusteredInstance,
    @IsInstanceinSingleUserMode AS IsInstanceinSingleUserMode;

--Disk Status
SELECT DISTINCT volumes.logical_volume_name AS LogicalName,
    volumes.volume_mount_point AS Drive,
    CONVERT(INT,volumes.available_bytes/1024/1024/1024) AS FreeSpace,
    CONVERT(INT,volumes.total_bytes/1024/1024/1024) AS TotalSpace,
    CONVERT(INT,volumes.total_bytes/1024/1024/1024) - CONVERT(INT,volumes.available_bytes/1024/1024/1024) AS OccupiedSpace
FROM sys.master_files mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.FILE_ID) volumes

--Database backup info
create table #BackupInformation 
(DatabaseName varchar(200), backup_type varchar(50), backupstartdate datetime, backupfinishdate datetime, username varchar(200), backupsize numeric(10,2), BackupUser varchar(250)) 
;with backup_information as
(
    select
        database_name,
        backup_type =
            case type
                when 'D' then 'Full backup'
                when 'I' then 'Differential backup'
                    when 'L' then 'Log backup'
                else 'Other or copy only backup'
            end ,
            backup_start_date ,
        backup_finish_date ,
        user_name  ,
        server_name ,
        compressed_backup_size ,
        rownum = 
            row_number() over
            (
                partition by database_name, type 
                order by backup_finish_date desc
            )
    from msdb.dbo.backupset
)
insert into #BackupInformation
select
    database_name [Database Name],
    backup_type [Backup Type],
    backup_start_date [Backup start date],
    backup_finish_date [Backup finish date],
    server_name [Server Name],
    Convert(varchar,convert(numeric(10,2),compressed_backup_size/ 1024/1024)) [Backup size in MB],
    user_name [Backup taken by]
from backup_information
where rownum = 1
order by database_name;


SELECT * FROM #BackupInformation;

--Status of the SQL Jobs
create table #JobInformation
(Servername varchar(100), categoryname varchar(100),JobName varchar(500),
ownerID varchar(250),Enabled varchar(5),NextRunDate datetime, LastRunDate datetime, status varchar(50)
)
Insert into #JobInformation (Servername,categoryname,JobName,ownerID,Enabled,NextRunDate,LastRunDate,status)
SELECT 
    convert (varchar, SERVERPROPERTY('Servername')) AS ServerName
,categories.NAME AS CategoryName
    ,sqljobs.name
    ,SUSER_SNAME(sqljobs.owner_sid) AS OwnerID
    ,CASE sqljobs.enabled WHEN 1 THEN 'Yes' ELSE 'No'END AS Enabled
    ,CASE job_schedule.next_run_date
    WHEN 0
    THEN CONVERT(DATETIME, '1900/1/1')
    ELSE CONVERT(DATETIME, CONVERT(CHAR(8), job_schedule.next_run_date, 112) 
    + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), job_schedule.next_run_time), 6), 5, 0, ':'), 3, 0, ':'))
    END NextScheduledRunDate
,lastrunjobhistory.LastRunDate
,ISNULL(lastrunjobhistory.run_status_desc,'Unknown') AS run_status_desc
    
FROM msdb.dbo.sysjobs AS sqljobs
LEFT JOIN msdb.dbo.sysjobschedules AS job_schedule
    ON sqljobs.job_id = job_schedule.job_id
LEFT JOIN msdb.dbo.sysschedules AS schedule
    ON job_schedule.schedule_id = schedule.schedule_id
INNER JOIN msdb.dbo.syscategories categories
    ON sqljobs.category_id = categories.category_id
LEFT OUTER JOIN (
    SELECT Jobhistory.job_id
    FROM msdb.dbo.sysjobhistory AS Jobhistory
    WHERE Jobhistory.step_id = 0
    GROUP BY Jobhistory.job_id
    ) AS jobhistory
    ON jobhistory.job_id = sqljobs.job_id  
LEFT OUTER JOIN
(
SELECT sysjobhist.job_id
    ,CASE sysjobhist.run_date
    WHEN 0
    THEN CONVERT(DATETIME, '1900/1/1')
    ELSE CONVERT(DATETIME, CONVERT(CHAR(8), sysjobhist.run_date, 112) 
    + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), sysjobhist.run_time), 6), 5, 0, ':'), 3, 0, ':'))
    END AS LastRunDate
    ,sysjobhist.run_status
    ,CASE sysjobhist.run_status
    WHEN 0
    THEN 'Failed'
    WHEN 1
    THEN 'Succeeded'
    WHEN 2
    THEN 'Retry'
    WHEN 3
    THEN 'Canceled'
    WHEN 4
    THEN 'In Progress'
    ELSE 'Unknown'
    END AS run_status_desc
    ,sysjobhist.retries_attempted
    ,sysjobhist.step_id
    ,sysjobhist.step_name
    ,sysjobhist.run_duration AS RunTimeInSeconds
    ,sysjobhist.message
    ,ROW_NUMBER() OVER (
    PARTITION BY sysjobhist.job_id ORDER BY CASE sysjobhist.run_date
    WHEN 0
        THEN CONVERT(DATETIME, '1900/1/1')
    ELSE CONVERT(DATETIME, CONVERT(CHAR(8), sysjobhist.run_date, 112) 
    + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), sysjobhist.run_time), 6), 5, 0, ':'), 3, 0, ':'))
    END DESC
    ) AS RowOrder
FROM msdb.dbo.sysjobhistory AS sysjobhist
WHERE sysjobhist.step_id = 0  
)AS lastrunjobhistory
    ON lastrunjobhistory.job_id = sqljobs.job_id  
    AND
    lastrunjobhistory.RowOrder=1

	select * FROM #JobInformation


	--Monitor and Optimize your SQL database server
	SELECT 
    -- Server version
    @@VERSION AS ServerVersion,
    -- List of databases
    GROUP_CONCAT(schema_name SEPARATOR ', ') AS Databases,
    -- Total size of each database
    GROUP_CONCAT(CONCAT(schema_name, ': ', ROUND(SUM((data_length + index_length) / 1024 / 1024), 2), ' MB') SEPARATOR ', ') AS DatabaseSizes,
    -- Total server memory usage
    (SELECT ROUND((cntr_value/1024), 2) FROM sys.dm_os_performance_counters WHERE counter_name = 'Total Server Memory (KB)') AS TotalServerMemory_MB,
    -- Target server memory
    (SELECT ROUND((cntr_value/1024), 2) FROM sys.dm_os_performance_counters WHERE counter_name = 'Target Server Memory (KB)') AS TargetServerMemory_MB,
    -- CPU usage
    (SELECT cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'Processor Time' AND object_name = 'Processor' AND instance_name = '_Total') AS CPU_Usage_Percentage,
    -- List of long-running queries
    (SELECT GROUP_CONCAT(CONCAT(t1.session_id, ': ', t2.text) SEPARATOR '; ') 
     FROM sys.dm_exec_requests t1 CROSS APPLY sys.dm_exec_sql_text(t1.sql_handle) AS t2 
     WHERE t1.status = 'running') AS LongRunningQueries,
    -- List of blocked processes
    (SELECT GROUP_CONCAT(CONCAT(t1.request_session_id, ' (Blocked by: ', t1.blocking_session_id, ')') SEPARATOR '; ') 
     FROM sys.dm_exec_requests t1 WHERE t1.blocking_session_id > 0) AS BlockedProcesses

	

-- CPU and Memory Utilizations
SELECT 
    record_id, 
    event_time, 
    SQLProcessUtilization, 
    SystemIdle, 
    100 - SystemIdle - SQLProcessUtilization AS OtherProcessUtilization 
FROM 
    sys.dm_os_ring_buffers 
WHERE 
    ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
    AND record_id = (SELECT MAX(record_id) FROM sys.dm_os_ring_buffers 
                     WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR');

-- I/O Statistics
SELECT 
    db_name(database_id) AS DatabaseName,
    file_id,
    io_stall_read_ms,
    num_of_reads,
    io_stall_write_ms,
    num_of_writes,
    io_stall_read_ms / num_of_reads AS avg_read_stall_ms,
    io_stall_write_ms / num_of_writes AS avg_write_stall_ms
FROM 
    sys.dm_io_virtual_file_stats(null, null);

-- Wait Statistics
SELECT 
    wait_type, 
    waiting_tasks_count, 
    wait_time_ms, 
    max_wait_time_ms, 
    signal_wait_time_ms 
FROM 
    sys.dm_os_wait_stats 
ORDER BY 
    wait_time_ms DESC;

-- Error Logs
EXEC sp_readerrorlog;

-- Index Fragmentations
SELECT 
    dbschemas.[name] AS 'Schema', 
    dbtables.[name] AS 'Table', 
    dbindexes.[name] AS 'Index', 
    indexstats.avg_fragmentation_in_percent 
FROM 
    sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, 'LIMITED') AS indexstats 
    INNER JOIN sys.tables dbtables ON indexstats.[object_id] = dbtables.[object_id] 
    INNER JOIN sys.schemas dbschemas ON dbtables.[schema_id] = dbschemas.[schema_id] 
    INNER JOIN sys.indexes AS dbindexes ON indexstats.[object_id] = dbindexes.[object_id] 
    AND indexstats.index_id = dbindexes.index_id 
ORDER BY 
    indexstats.avg_fragmentation_in_percent DESC;

-- Query Store Informations
SELECT 
    TOP 10 query_text, 
    plan_id, 
    execution_count, 
    total_cpu_time_ms, 
    total_duration_ms, 
    total_logical_reads, 
    total_logical_writes 
FROM 
    sys.query_store_query_text AS qt 
    JOIN sys.query_store_query AS q ON qt.query_text_id = q.query_text_id 
    JOIN sys.query_store_plan AS p ON q.query_id = p.query_id 
ORDER BY 
    total_cpu_time_ms DESC;

-- Blocking and Deadlock
SELECT 
    blocking_session_id, 
    session_id, 
    wait_type, 
    wait_duration_ms, 
    wait_resource 
FROM 
    sys.dm_exec_requests 
WHERE 
    blocking_session_id <> 0;

-- Security and Permission Audit
SELECT 
    pr.principal_id, 
    pr.name AS principal_name, 
    pr.type_desc AS principal_type_desc, 
    pe.state_desc AS permission_state_desc, 
    pe.permission_name 
FROM 
    sys.database_principals AS pr 
    JOIN sys.database_permissions AS pe ON pr.principal_id = pe.grantee_principal_id 
ORDER BY 
    pr.name;


