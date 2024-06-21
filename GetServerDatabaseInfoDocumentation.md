GetServerDatabaseInfo Stored Procedure
Overview
The GetServerDatabaseInfo stored procedure is designed to provide comprehensive information about the SQL Server instance, including details about databases, server and instance status, disk usage, database backup information, SQL job statuses, and server performance metrics. This procedure is useful for database administrators to monitor, audit, and optimize their SQL Server environment.
Features
•	Database Information: Retrieves information about all databases including their size, creation date, owner, state, user access level, compatibility level, and recovery model.
•	Server and Instance Status: Provides details about the server name, version, edition, whether it is clustered, and its user mode.
•	Disk Status: Shows the logical volume name, drive, free space, total space, and occupied space.
•	Database Backup Information: Lists the latest backup information for each database, including backup type, start and finish dates, username, and backup size.
•	SQL Jobs Status: Displays the status of SQL jobs, including their name, category, owner, enabled status, next scheduled run date, last run date, and current status.
•	Server Performance Metrics: Offers insights into server performance, including server version, list of databases, total and target server memory, CPU usage, long-running queries, and blocked processes.
Usage
To execute the stored procedure, use the following SQL command:
sql
Copy code
EXEC GetServerDatabaseInfo;
Detailed Output
1. Database Information
•	database_id: The unique identifier for each database.
•	name: The name of the database.
•	create_date: The date when the database was created.
•	owner_name: The name of the owner of the database.
•	user_access_desc: Describes the user access level.
•	state_desc: The current state of the database.
•	compatibility_level: The compatibility level of the database.
•	recovery_model_desc: The recovery model of the database.
•	DBSizeInMB: The size of the database in megabytes.
2. Server and Instance Status
•	Hostname: The name of the server.
•	Version: The SQL Server version.
•	Edition: The edition of SQL Server.
•	IsClusteredInstance: Indicates if the server is part of a cluster.
•	IsInstanceinSingleUserMode: Indicates if the server is in single user mode.
3. Disk Status
•	LogicalName: The logical name of the volume.
•	Drive: The drive letter or mount point.
•	FreeSpace: Free space on the volume in gigabytes.
•	TotalSpace: Total space on the volume in gigabytes.
•	OccupiedSpace: Occupied space on the volume in gigabytes.
4. Database Backup Information
•	DatabaseName: The name of the database.
•	BackupType: The type of backup (Full, Differential, Log, etc.).
•	BackupStartDate: The start date and time of the backup.
•	BackupFinishDate: The finish date and time of the backup.
•	Username: The name of the user who performed the backup.
•	BackupSize: The size of the backup in megabytes.
•	BackupUser: The user who took the backup.
5. SQL Jobs Status
•	Servername: The name of the server.
•	Categoryname: The category of the job.
•	JobName: The name of the SQL job.
•	OwnerID: The owner of the job.
•	Enabled: Indicates if the job is enabled.
•	NextRunDate: The next scheduled run date and time of the job.
•	LastRunDate: The last run date and time of the job.
•	Status: The current status of the job.
6. Server Performance Metrics
•	ServerVersion: The version of the SQL Server.
•	Databases: List of databases on the server.
•	DatabaseSizes: Total size of each database.
•	TotalServerMemory_MB: Total server memory usage in megabytes.
•	TargetServerMemory_MB: Target server memory in megabytes.
•	CPU_Usage_Percentage: CPU usage percentage.
•	LongRunningQueries: List of long-running queries.
•	BlockedProcesses: List of blocked processes.
Dependencies
This stored procedure relies on various system views and functions provided by SQL Server, including:
•	sys.databases
•	sys.server_principals
•	sys.master_files
•	sys.dm_os_volume_stats
•	msdb.dbo.backupset
•	msdb.dbo.sysjobs
•	msdb.dbo.sysjobschedules
•	msdb.dbo.sysschedules
•	msdb.dbo.syscategories
•	msdb.dbo.sysjobhistory
•	sys.dm_exec_requests
•	sys.dm_exec_sql_text
•	sys.dm_os_performance_counters
Author
This stored procedure was created to assist SQL Server administrators in monitoring and managing their database environments effectively.

This README provides a detailed explanation of the stored procedure's purpose, usage, and output, making it easier for users to understand and utilize the procedure effectively.

