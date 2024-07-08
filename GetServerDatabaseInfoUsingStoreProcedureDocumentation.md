# GetServerDatabaseInfo Stored Procedure

The `GetServerDatabaseInfo` stored procedure delivers detailed insights into your SQL Server instance and its databases. This procedure consolidates critical information, including database status, server status, disk usage, backup details, job statuses, and various performance metrics. It is an essential tool for database administrators to effectively monitor and optimize their SQL Server environments.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Usage](#usage)
4. [Output Details](#output-details)
5. [Additional Information](#additional-information)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

- SQL Server 2012 or later
- Sufficient permissions to access system views and execute stored procedures

## Installation

1. Open SQL Server Management Studio (SSMS).
2. Connect to the SQL Server instance where the stored procedure will be deployed.
3. Open a new query window.
4. Copy and paste the `GetServerDatabaseInfo` stored procedure script into the query window.
5. Execute the script to create the stored procedure.

```sql
-- Insert the GetServerDatabaseInfo stored procedure script here
```

## Usage

To execute the stored procedure, use the following command:

```sql
EXEC GetServerDatabaseInfo;
```

This command will execute the procedure and provide comprehensive details about your SQL Server instance and databases.

## Output Details

### Step 1: Database Information
- **Database ID**
- **Database Name**
- **Creation Date**
- **Owner Name**
- **User Access Description**
- **State Description**
- **Compatibility Level**
- **Recovery Model Description**
- **Database Size (MB)**

### Step 2: Server and Instance Status
- **Hostname**
- **SQL Server Version**
- **Edition**
- **Clustered Instance Status**
- **Single User Mode Status**

### Step 3: Disk Status
- **Logical Name**
- **Drive**
- **Free Space (GB)**
- **Total Space (GB)**
- **Occupied Space (GB)**

### Step 4: Database Backup Information
- **Database Name**
- **Backup Type**
- **Backup Start Date**
- **Backup Finish Date**
- **Username**
- **Backup Size (MB)**
- **Backup Taken By**

### Step 5: SQL Job Status
- **Server Name**
- **Category Name**
- **Job Name**
- **Owner ID**
- **Enabled Status**
- **Next Run Date**
- **Last Run Date**
- **Job Status**

### Step 6: Monitoring and Optimization
- **Server Version**
- **List of Databases**
- **Database Sizes**
- **Total Server Memory (MB)**
- **Target Server Memory (MB)**
- **CPU Usage Percentage**
- **Long Running Queries**
- **Blocked Processes**

### Additional Monitoring and Optimization Queries
- **CPU and Memory Utilization**
- **I/O Statistics**
- **Wait Statistics**
- **Error Logs**
- **Index Fragmentation**
- **Query Store Information**
- **Blocking and Deadlocks**
- **Security and Permission Audits**

## Additional Information

- **CPU and Memory Utilization**: Details about CPU and memory usage.
- **I/O Statistics**: Insights into read and write operations and their latencies.
- **Wait Statistics**: Various wait types and their durations.
- **Error Logs**: Recent error logs from the SQL Server.
- **Index Fragmentation**: Fragmented indexes and their fragmentation percentages.
- **Query Store Information**: Details about the most resource-intensive queries.
- **Blocking and Deadlocks**: Blocking sessions and deadlocks.
- **Security and Permission Audits**: Permissions for various database principals.

## Troubleshooting

- Ensure you have the necessary permissions to access system views and execute the stored procedure.
- Review error messages for specific issues related to permissions or missing objects if you encounter errors.
- For large databases or instances with many jobs, the procedure might take some time to execute. Consider running it during off-peak hours.

---

This documentation provides an overview of the `GetServerDatabaseInfo` stored procedure, covering its installation, usage, and the details it outputs. It serves as a guide for database administrators to effectively monitor and optimize their SQL Server environments.
