# SQL Server Health Check Scripts and Stored Procedure

## Overview

This repository contains SQL scripts and a stored procedure designed for monitoring and optimizing SQL Server performance. The scripts provide insights into various aspects of SQL Server health, including database status, server metrics, backup information, job status, and more.

## Contents

1. **Health Check Script Using SQL Queries**
   - This script consists of multiple SQL queries aimed at retrieving vital information about the SQL Server environment.
   - Queries include:
     - Database information (size, compatibility, recovery model)
     - Server and instance status (hostname, version, edition, clustering)
     - Disk status (free space, total space, occupied space)
     - Database backup information (latest backup details)
     - SQL job status (next run date, last run date, status)
     - Performance metrics (CPU utilization, memory usage, long-running queries, blocked processes)

2. **Stored Procedure**
   - The stored procedure encapsulates all queries from the health check script into a single executable unit.
   - Provides a streamlined approach for generating comprehensive health reports.
   - Promotes consistency and ease of use across different SQL Server instances.

## How to Use

### Health Check Script Using SQL Queries

- Open and execute the script in your SQL Server Management Studio (SSMS) connected to the target SQL Server instance.
- Review the results to assess the health and performance metrics of the SQL Server environment.

### Stored Procedure

- Execute the stored procedure in SSMS to automate the generation of health check reports.
- Customize parameters within the stored procedure as needed (e.g., database thresholds, performance metrics).

## Additional Notes

- Ensure appropriate permissions are granted to execute these scripts on the SQL Server instance.
- Regularly monitor and review the generated reports to proactively manage SQL Server performance and health.

