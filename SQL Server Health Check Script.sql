select  a.database_id,
a.name,a.create_date,b.name,a.user_access_desc,a.state_desc,compatibility_level, recovery_model_desc, Sum((c.size*8)/1024) as DBSizeInMB
from sys.databases a inner join sys.server_principals b on a.owner_sid=b.sid inner join sys.master_files c on a.database_id=c.database_id
Where a.database_id>5
Group by a.name,a.create_date,b.name,a.user_access_desc,compatibility_level,a.state_desc, recovery_model_desc,a.database_id

--Server and Instance status
declare @DatabaseServerInformation nvarchar(max);
declare @Hostname varchar(50) = (select convert(varchar(50),@@SERVERNAME));
declare @Version varchar(max) = (select convert(varchar(max),@@version));
declare @Edition varchar(50) = (select convert(varchar(50),SERVERPROPERTY('edition')));
declare @IsClusteredInstance varchar(50) = 
    (SELECT CASE SERVERPROPERTY ('IsClustered') WHEN 1 THEN 'Clustered Instance' WHEN 0 THEN 'Non Clustered instance' ELSE 'null' END);
declare @IsInstanceinSingleUserMode varchar(50) = 
    (SELECT CASE SERVERPROPERTY ('IsSingleUser') WHEN 1 THEN 'Single user' WHEN 0 THEN 'Multi user' ELSE 'null' END);

-- Output the values
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

--Database backup information
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

