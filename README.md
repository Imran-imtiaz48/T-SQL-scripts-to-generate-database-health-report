# SQL Server Health Check Script and Stored Procedures

## Overview

This comprehensive resource provides an SQL script and a stored procedure designed to facilitate the proactive monitoring of your SQL Server's health.  It encompasses a holistic view of database status, performance metrics, backup schedules, job execution, and other critical aspects.

## Contents

1. **Health Check Script Using SQL Queries**
   - This script include multiple SQL queries to retrieve vital informations about the SQL Server environment.
   - Queries cover:
     - Database information (size, compatibility, recovery model)
     - Server and instance status (hostname, version, edition, clustering)
     - Disk status (free space, total space, occupied space)
     - Database backup information (latest backup details)
     - SQL job status (next run date, last run date, status)
     - Performance metrics (CPU utilization, memory usage, long-running queries, blocked processes)

2. **Stored Procedure**
   - Encapsulates all queries from the health check script into a single executable unit.
   - Streamlines the process of generating comprehensive health reports.
   - Ensures consistency and ease of use across different SQL Server instances.

## How to Use

### Health Check Script Using SQL Queries

- Open and execute the script in SQL Server Management Studio (SSMS) connected to the target SQL Server instance.
- Review the results to assess the health and performance metrics of the SQL Server environment.

### Stored Procedure

- Execute the stored procedure in SSMS to automate the generation of health check reports.
- Customize parameters within the stored procedure as needed (e.g., database thresholds, performance metrics).

## Additional Notes

- Ensure appropriate permissions are granted to execute these scripts on the SQL Server instance.
- Regularly monitor and review the generated reports to proactively manage SQL Server performance and health.

---

By using these scripts and stored procedures, you can effectively monitor and optimize your SQL Server environment, ensuring high performance and reliability.
