SQL Server Health Check Script Documentation
Overview
This document provides an overview and explanation of the SQL Server health check script. The script retrieves vital information about the SQL Server instance, including database details, server status, disk space usage, recent backup information, and SQL job statuses.
1. Database Information
Purpose
To retrieve detailed information about each database in the SQL Server instance, including its size, creation date, owner, user access level, state, compatibility level, and recovery model.
Key Fields
•	Database ID: Unique identifier for each database.
•	Database Name: Name of the database.
•	Creation Date: Date when the database was created.
•	Owner Name: Name of the database owner.
•	User Access Description: Describes the user access level of the database.
•	State Description: Current state of the database (e.g., online, offline).
•	Compatibility Level: SQL Server compatibility level of the database.
•	Recovery Model Description: Recovery model of the database (e.g., full, simple).
•	Database Size: Total size of the database in MB.
2. Server and Instance Status
Purpose
To capture and display the status and properties of the SQL Server instance, including the server name, SQL Server version, edition, clustering status, and user mode.
Key Fields
•	Hostname: Name of the SQL Server instance.
•	Version: Version information of the SQL Server.
•	Edition: Edition of the SQL Server (e.g., Standard, Enterprise).
•	Clustered Instance: Indicates whether the instance is part of a clustered setup.
•	Single User Mode: Indicates whether the instance is running in single-user mode.
3. Disk Status
Purpose
To retrieve information about the disk space usage on the server, including logical volume names, drive letters, available space, total space, and occupied space.
Key Fields
•	Logical Name: Name of the logical volume.
•	Drive: Drive letter or mount point.
•	Free Space: Available disk space in GB.
•	Total Space: Total disk space in GB.
•	Occupied Space: Used disk space in GB.
4. Database Backup Information
Purpose
To gather and display information about the most recent backups for each database, including backup type, start and finish times, user who performed the backup, and the backup size.
Key Fields
•	Database Name: Name of the database.
•	Backup Type: Type of backup (e.g., full, differential, log).
•	Backup Start Date: Date and time when the backup started.
•	Backup Finish Date: Date and time when the backup finished.
•	Backup User: User who performed the backup.
•	Backup Size: Size of the backup in MB.
5. Status of SQL Jobs
Purpose
To retrieve and display the status of SQL Server jobs, including job names, categories, owners, enablement status, next scheduled run date, last run date, and current status.
Key Fields
•	Server Name: Name of the server where the job is running.
•	Category Name: Category of the SQL job.
•	Job Name: Name of the SQL job.
•	Owner ID: Owner of the SQL job.
•	Enabled: Indicates whether the job is enabled.
•	Next Run Date: Date and time when the job is scheduled to run next.
•	Last Run Date: Date and time when the job was last run.
•	Status: Current status of the job (e.g., succeeded, failed, in progress).
Summary
This script provides a comprehensive overview of the health and status of a SQL Server instance. By collecting data on database configurations, server properties, disk usage, backups, and job statuses, it helps administrators ensure the SQL Server environment is running efficiently and effectively.

