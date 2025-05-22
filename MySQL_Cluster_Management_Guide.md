# MySQL Cluster (NDB) Management Guide

This guide provides comprehensive instructions for managing your MySQL Cluster deployment, from basic operations to advanced configurations. It's designed to be accessible for beginners while providing detailed information for advanced users.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Basic Operations](#basic-operations)
   - [Starting and Stopping the Cluster](#starting-and-stopping-the-cluster)
   - [Checking Cluster Status](#checking-cluster-status)
   - [Connecting to the Cluster](#connecting-to-the-cluster)
3. [User Management](#user-management)
   - [Creating and Managing MySQL Users](#creating-and-managing-mysql-users)
   - [Managing ProxySQL Users](#managing-proxysql-users)
   - [User Permissions and Security](#user-permissions-and-security)
4. [Data Management](#data-management)
   - [Creating NDB Tables](#creating-ndb-tables)
   - [Data Distribution and Partitioning](#data-distribution-and-partitioning)
   - [Backup and Recovery](#backup-and-recovery)
5. [Performance Tuning](#performance-tuning)
   - [Memory Configuration](#memory-configuration)
   - [Query Optimization](#query-optimization)
   - [ProxySQL Optimization](#proxysql-optimization)
6. [High Availability](#high-availability)
   - [Handling Node Failures](#handling-node-failures)
   - [Adding New Nodes](#adding-new-nodes)
   - [Node Group Management](#node-group-management)
7. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
   - [Common Issues and Solutions](#common-issues-and-solutions)
   - [Performance Monitoring](#performance-monitoring)
   - [Log Analysis](#log-analysis)
8. [Advanced Topics](#advanced-topics)
   - [Scaling the Cluster](#scaling-the-cluster)
   - [Online Schema Changes](#online-schema-changes)
   - [Upgrading MySQL Cluster](#upgrading-mysql-cluster)

## Architecture Overview

Your MySQL Cluster consists of the following components:

- **Management Node (ndb_mgmd)**: Manages the cluster configuration
- **Data Nodes (ndbd)**: Store and replicate data
- **SQL Nodes (mysqld)**: Provide SQL interface to the cluster
- **ProxySQL**: Load balancer for distributing queries

The current setup includes:
- 1 Management Node (management1)
- 4 Data Nodes (ndb1, ndb2, ndb3, ndb4) organized in 2 node groups
- 2 SQL Nodes (mysql1, mysql2)
- 2 ProxySQL instances for high availability

This architecture provides:
- High availability with no single point of failure
- Data redundancy with 2 copies of all data
- Read/write splitting for optimal performance
- Load balancing across SQL nodes

## Basic Operations

### Starting and Stopping the Cluster

**Starting the Cluster:**

```bash
# Start the entire stack
docker-compose up -d

# Check the status of the containers
docker ps
```

**Stopping the Cluster:**

```bash
# Graceful shutdown of the entire cluster
docker-compose down

# Stop individual components (if needed)
docker stop management1
docker stop ndb1 ndb2 ndb3 ndb4
docker stop mysql1 mysql2
docker stop proxysql proxysql2
```

**Restarting Individual Components:**

```bash
# Restart a specific component
docker restart mysql1

# Start a stopped component
docker start ndb1
```

### Checking Cluster Status

**Management Node Status:**

```bash
# Connect to the management node
docker exec -it management1 bash

# Check cluster status
ndb_mgm -e show

# You should see all nodes connected and started
```

**Data Node Status:**

```bash
# Check data node status from MySQL
docker exec -it mysql1 mysql -uroot -prootpassword -e "USE ndbinfo; SELECT node_id, status FROM nodes;"

# Expected output should show all nodes as STARTED
```

**SQL Node Status:**

```bash
# Check if MySQL nodes are running
docker exec -it mysql1 mysqladmin -uroot -prootpassword ping
docker exec -it mysql2 mysqladmin -uroot -prootpassword ping
```

**ProxySQL Status:**

```bash
# Check ProxySQL runtime configuration
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "SELECT * FROM mysql_servers;"
```

### Connecting to the Cluster

**Direct Connection to MySQL Nodes:**

```bash
# Connect to MySQL node 1
mysql -h127.0.0.1 -P3306 -uroot -prootpassword

# Connect to MySQL node 2
mysql -h127.0.0.1 -P3307 -uroot -prootpassword
```

**Connection Through ProxySQL:**

```bash
# Connect with regular user (balanced between write/read hostgroups)
mysql -h127.0.0.1 -P6033 -utestuser -ptestpassword

# Connect with read-only user (routed to read hostgroup)
mysql -h127.0.0.1 -P6033 -ureadonly -preadonlypass

# Connect with read-write user (routed to write hostgroup)
mysql -h127.0.0.1 -P6033 -ureadwrite -preadwritepass
```

## User Management

### Creating and Managing MySQL Users

In MySQL Cluster, user accounts are stored in the MySQL system tables, which are replicated across all SQL nodes. This means:

1. You only need to create a user once on any SQL node
2. The user will automatically be available on all SQL nodes
3. Changes to user permissions are automatically propagated

**Creating a New User:**

```sql
-- Connect to any SQL node
mysql -h127.0.0.1 -P3306 -uroot -prootpassword

-- Create a new user with mysql_native_password authentication
CREATE USER 'newuser'@'%' IDENTIFIED WITH mysql_native_password BY 'newpassword';

-- Grant appropriate permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON database_name.* TO 'newuser'@'%';

-- Apply changes
FLUSH PRIVILEGES;
```

**Modifying User Permissions:**

```sql
-- Add additional permissions
GRANT CREATE, ALTER, DROP ON database_name.* TO 'newuser'@'%';

-- Remove permissions
REVOKE DROP ON database_name.* FROM 'newuser'@'%';

-- Apply changes
FLUSH PRIVILEGES;
```

**Deleting a User:**

```sql
DROP USER 'newuser'@'%';
FLUSH PRIVILEGES;
```

### Managing ProxySQL Users

ProxySQL maintains its own user list that's independent of MySQL users. After creating a user in MySQL, you need to add it to ProxySQL:

**Adding a User to ProxySQL:**

```sql
-- Connect to ProxySQL admin interface
mysql -h127.0.0.1 -P6032 -uadmin -padmin

-- Add a new user
INSERT INTO mysql_users(username, password, default_hostgroup, active) 
  VALUES ('newuser', 'newpassword', 0, 1);

-- Apply changes
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;
```

**Configuring User Properties:**

```sql
-- Configure a read-only user (route to read hostgroup)
INSERT INTO mysql_users(username, password, default_hostgroup, active, transaction_persistent) 
  VALUES ('readonly_user', 'password', 10, 1, 0);

-- Configure a read-write user (route to write hostgroup)
INSERT INTO mysql_users(username, password, default_hostgroup, active, transaction_persistent) 
  VALUES ('readwrite_user', 'password', 0, 1, 1);

-- Apply changes
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;
```

**Modifying User Properties:**

```sql
-- Update user properties
UPDATE mysql_users SET max_connections=500 WHERE username='newuser';

-- Apply changes
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;
```

### User Permissions and Security

**Best Practices for User Management:**

1. **Principle of Least Privilege**: Grant only the permissions a user needs
2. **Use Different Users for Different Applications**: Create separate users for each application
3. **Regular Auditing**: Periodically review user permissions
4. **Password Policies**: Use strong passwords and consider password rotation

**Example User Setup for a Typical Application:**

```sql
-- Application user with specific permissions
CREATE USER 'app_user'@'%' IDENTIFIED WITH mysql_native_password BY 'strong_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_database.* TO 'app_user'@'%';

-- Read-only reporting user
CREATE USER 'report_user'@'%' IDENTIFIED WITH mysql_native_password BY 'report_password';
GRANT SELECT ON app_database.* TO 'report_user'@'%';

-- Admin user with full privileges
CREATE USER 'admin_user'@'%' IDENTIFIED WITH mysql_native_password BY 'admin_password';
GRANT ALL PRIVILEGES ON app_database.* TO 'admin_user'@'%';

-- Apply changes
FLUSH PRIVILEGES;
```

## Data Management

### Creating NDB Tables

When creating tables in MySQL Cluster, you need to specify the NDBCLUSTER storage engine:

```sql
CREATE TABLE example_table (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=NDBCLUSTER;
```

**Important NDB Table Considerations:**

1. **Primary Key**: Every NDB table should have a primary key
2. **Partitioning**: Consider using explicit partitioning for large tables
3. **Data Types**: Some data types have limitations in NDB
4. **Foreign Keys**: Foreign keys have some limitations in NDB

### Data Distribution and Partitioning

Data in MySQL Cluster is automatically distributed across data nodes based on the primary key. You can control this distribution using explicit partitioning:

```sql
CREATE TABLE partitioned_table (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=NDBCLUSTER
PARTITION BY KEY(id) PARTITIONS 8;
```

**Partitioning Strategies:**

1. **KEY Partitioning**: Distributes data based on a hash of the key columns
2. **LINEAR KEY Partitioning**: Uses a linear hashing algorithm for faster partition pruning
3. **RANGE Partitioning**: Distributes data based on value ranges
4. **LIST Partitioning**: Distributes data based on discrete values

### Backup and Recovery

**Creating a Backup:**

```bash
# Connect to the management node
docker exec -it management1 bash

# Create a backup
ndb_mgm -e "START BACKUP"
```

**Restoring from Backup:**

```bash
# Stop the cluster
docker-compose down

# Start only the management node
docker-compose up -d management1

# Restore from backup (replace BACKUP-ID with the actual backup ID)
ndb_restore -b BACKUP-ID -n 2 -r --backup_path=/var/lib/mysql-cluster/BACKUP/BACKUP-ID/ --connect=management1:1186
ndb_restore -b BACKUP-ID -n 3 -r --backup_path=/var/lib/mysql-cluster/BACKUP/BACKUP-ID/ --connect=management1:1186
ndb_restore -b BACKUP-ID -n 6 -r --backup_path=/var/lib/mysql-cluster/BACKUP/BACKUP-ID/ --connect=management1:1186
ndb_restore -b BACKUP-ID -n 7 -r --backup_path=/var/lib/mysql-cluster/BACKUP/BACKUP-ID/ --connect=management1:1186

# Start the rest of the cluster
docker-compose up -d
```

## Performance Tuning

### Memory Configuration

The most critical configuration parameters for MySQL Cluster performance are related to memory allocation:

**Data Node Memory Settings:**

```ini
[ndbd default]
DataMemory=512M      # Memory for storing data
IndexMemory=128M     # Memory for storing indexes
```

**Recommended Settings Based on Data Size:**

| Data Size | DataMemory | IndexMemory |
|-----------|------------|-------------|
| < 5GB     | 1GB        | 256MB       |
| 5-20GB    | 4GB        | 1GB         |
| 20-50GB   | 8GB        | 2GB         |
| > 50GB    | 16GB+      | 4GB+        |

### Query Optimization

**Best Practices for NDB Query Optimization:**

1. **Use Primary Key Lookups**: Queries using primary key are much faster
2. **Avoid JOINs on Large Tables**: JOINs can be expensive in NDB
3. **Use Covering Indexes**: Include all columns needed in the index
4. **Batch Operations**: Use multi-row inserts and updates
5. **Avoid Large Transactions**: Keep transactions small and focused

**Example of Optimized vs. Unoptimized Queries:**

```sql
-- Unoptimized (full table scan)
SELECT * FROM customers WHERE last_name = 'Smith';

-- Optimized (using index)
ALTER TABLE customers ADD INDEX idx_lastname (last_name);
SELECT * FROM customers WHERE last_name = 'Smith';

-- Unoptimized (joining large tables)
SELECT * FROM orders JOIN order_items ON orders.id = order_items.order_id;

-- Optimized (using limit and specific columns)
SELECT o.id, o.customer_id, oi.product_id, oi.quantity 
FROM orders o JOIN order_items oi ON o.id = oi.order_id 
WHERE o.created_at > '2025-01-01' 
LIMIT 1000;
```

### ProxySQL Optimization

**Key ProxySQL Settings for Performance:**

```
mysql_variables=
{
    threads=16                   # Number of worker threads
    max_connections=8192         # Maximum client connections
    default_query_timeout=3600000 # Query timeout in ms
    free_connections_pct=10      # Percentage of connections to keep free
    multiplexing=true            # Connection multiplexing
}
```

**Query Rules for Efficient Routing:**

```sql
-- Route all SELECTs to read hostgroup except in transactions
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) 
  VALUES (100, 1, '^SELECT', 10, 1);

-- Route SELECTs with FOR UPDATE to write hostgroup
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) 
  VALUES (101, 1, '^SELECT.*FOR UPDATE', 0, 1);

-- Apply changes
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
```

## High Availability

### Handling Node Failures

MySQL Cluster is designed to handle node failures automatically:

1. **Data Node Failure**: If a data node fails, its node group partner contains a complete copy of all data
2. **SQL Node Failure**: If an SQL node fails, ProxySQL will route connections to the remaining SQL nodes
3. **Management Node Failure**: The cluster continues to operate even if the management node is down

**Testing Node Failure Recovery:**

```bash
# Stop a data node
docker stop ndb1

# Verify cluster continues to operate
docker exec -it mysql1 mysql -uroot -prootpassword -e "USE test_db; SELECT COUNT(*) FROM test_table;"

# Restart the data node
docker start ndb1

# Verify node rejoins the cluster
docker exec -it management1 ndb_mgm -e show
```

### Adding New Nodes

**Adding a New SQL Node:**

1. Update docker-compose.yml to add the new SQL node
2. Start the new node: `docker-compose up -d mysql3`
3. Add the new node to ProxySQL:

```sql
-- Connect to ProxySQL admin
mysql -h127.0.0.1 -P6032 -uadmin -padmin

-- Add the new SQL node to both hostgroups
INSERT INTO mysql_servers(hostgroup_id, hostname, port) VALUES (0, 'mysql3', 3306);
INSERT INTO mysql_servers(hostgroup_id, hostname, port) VALUES (10, 'mysql3', 3306);

-- Apply changes
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
```

**Adding New Data Nodes:**

1. Update management-config.ini to include the new data nodes
2. Update docker-compose.yml to add the new data nodes
3. Start the new nodes: `docker-compose up -d ndb5 ndb6`
4. Initialize the new nodes: `docker exec -it management1 ndb_mgm -e "ALL START"`

### Node Group Management

Node groups in MySQL Cluster provide data redundancy. Each node group contains a complete copy of all data.

**Current Node Group Configuration:**

```
# Node Group 0
[ndbd]
NodeId=2
HostName=ndb1
NodeGroup=0

[ndbd]
NodeId=3
HostName=ndb2
NodeGroup=0

# Node Group 1
[ndbd]
NodeId=6
HostName=ndb3
NodeGroup=1

[ndbd]
NodeId=7
HostName=ndb4
NodeGroup=1
```

**Adding a New Node Group:**

```
# Node Group 2
[ndbd]
NodeId=8
HostName=ndb5
NodeGroup=2

[ndbd]
NodeId=9
HostName=ndb6
NodeGroup=2
```

## Monitoring and Troubleshooting

### Common Issues and Solutions

**Connection Issues with ProxySQL:**

```
ERROR 9001 (HY000): Max connect timeout reached while reaching hostgroup 0 after 10000ms
```

**Solution:**
1. Check if MySQL servers are running: `docker ps`
2. Verify ProxySQL configuration: `docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "SELECT * FROM mysql_servers;"`
3. Check network connectivity: `docker exec -it proxysql ping mysql1`
4. Restart ProxySQL: `docker restart proxysql`

**Data Node Out of Memory:**

```
ERROR 1297 (HY000): Got temporary error 2301 'Out of operation records...' from NDBCLUSTER
```

**Solution:**
1. Increase DataMemory and IndexMemory in management-config.ini
2. Restart the cluster with the new configuration

**Slow Queries:**

**Solution:**
1. Enable query logging: `SET GLOBAL log_output = 'TABLE'; SET GLOBAL slow_query_log = 1;`
2. Analyze slow queries: `SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 10;`
3. Add appropriate indexes based on query patterns

### Performance Monitoring

**Monitoring NDB Cluster Performance:**

```sql
-- Check memory usage
SELECT node_id, memory_type, used, total FROM ndbinfo.memoryusage;

-- Check operations per second
SELECT node_id, SUM(count) as operations FROM ndbinfo.operations_per_fragment GROUP BY node_id;

-- Check transaction statistics
SELECT * FROM ndbinfo.cluster_transactions;
```

**Monitoring ProxySQL:**

```sql
-- Check query statistics
SELECT * FROM stats.stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10;

-- Check connection pool status
SELECT * FROM stats.stats_mysql_connection_pool;
```

### Log Analysis

**Checking MySQL Logs:**

```bash
# View MySQL error log
docker exec -it mysql1 cat /var/log/mysql/error.log

# View MySQL general log
docker exec -it mysql1 mysql -uroot -prootpassword -e "SELECT * FROM mysql.general_log ORDER BY event_time DESC LIMIT 10;"
```

**Checking NDB Cluster Logs:**

```bash
# View management node log
docker exec -it management1 cat /var/lib/mysql-cluster/ndb_1_cluster.log

# View data node logs
docker exec -it ndb1 cat /var/lib/mysql-cluster/ndb_2_out.log
```

## Advanced Topics

### Scaling the Cluster

**Vertical Scaling:**

1. Update docker-compose.yml to increase resources for existing nodes:
   ```yaml
   ndb1:
     mem_limit: 4g  # Increase from 2g
   ```

2. Update management-config.ini to increase memory allocation:
   ```ini
   [ndbd default]
   DataMemory=2G    # Increase from 512M
   IndexMemory=512M # Increase from 128M
   ```

**Horizontal Scaling:**

1. Add more data nodes (in pairs to maintain node groups)
2. Add more SQL nodes
3. Update ProxySQL configuration to include new SQL nodes

### Online Schema Changes

MySQL Cluster supports online schema changes with some limitations:

```sql
-- Add a column (online operation)
ALTER TABLE customers ADD COLUMN email VARCHAR(100);

-- Add an index (online operation)
ALTER TABLE customers ADD INDEX idx_email (email);

-- Change column type (may require table copy)
ALTER TABLE customers MODIFY COLUMN name VARCHAR(200);
```

**Best Practices for Schema Changes:**

1. Perform schema changes during low-traffic periods
2. Test schema changes in a staging environment first
3. Consider using tools like gh-ost or pt-online-schema-change for complex changes

### Upgrading MySQL Cluster

**In-Place Upgrade Process:**

1. Back up all data: `ndb_mgm -e "START BACKUP"`
2. Update docker-compose.yml to use the new MySQL Cluster version
3. Perform a rolling upgrade:
   ```bash
   # Upgrade SQL nodes one at a time
   docker-compose stop mysql1
   docker-compose up -d mysql1
   # Wait for node to rejoin, then upgrade next node
   docker-compose stop mysql2
   docker-compose up -d mysql2
   
   # Upgrade data nodes one at a time (within different node groups)
   docker-compose stop ndb1
   docker-compose up -d ndb1
   # Wait for node to rejoin, then upgrade a node from another node group
   docker-compose stop ndb3
   docker-compose up -d ndb3
   # Continue until all nodes are upgraded
   
   # Finally, upgrade the management node
   docker-compose stop management1
   docker-compose up -d management1
   ```

4. Verify cluster status after upgrade: `ndb_mgm -e show`

---

This guide covers the essential aspects of managing your MySQL Cluster deployment. For more detailed information, refer to the official MySQL Cluster documentation at https://dev.mysql.com/doc/refman/8.0/en/mysql-cluster.html.
