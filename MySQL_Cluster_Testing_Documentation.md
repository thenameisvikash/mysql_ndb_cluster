# MySQL Cluster with ProxySQL Testing Documentation

[← Documentation Index](DOCUMENTATION.md) | [Testing Guide](docs/testing.md) | [Troubleshooting Guide →](Troubleshooting_Guide.md)

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Component Descriptions](#component-descriptions)
3. [Testing Procedures](#testing-procedures)
4. [Common Issues and Troubleshooting](#common-issues-and-troubleshooting)
5. [Automated Testing Suite](#automated-testing-suite)
6. [Performance Benchmarks](#performance-benchmarks)
7. [Monitoring Guidelines](#monitoring-guidelines)

## Architecture Overview

The MySQL Cluster setup consists of the following components:

![MySQL Cluster Architecture](https://dev.mysql.com/doc/refman/8.0/en/images/cluster-components-1.png)

### Component Layout

1. **Management Nodes (2)**:
   - `management1` (NodeId=1) - Primary management node at 172.20.0.2
   - `management2` (NodeId=8) - Secondary management node at 172.20.0.11

2. **Data Nodes (4 - organized in 2 node groups)**:
   - Node Group 0: `ndb1` (NodeId=2) and `ndb2` (NodeId=3)
   - Node Group 1: `ndb3` (NodeId=6) and `ndb4` (NodeId=7)
   - Each with 512MB data memory and 128MB index memory
   - Configured with 2 replicas for redundancy

3. **MySQL SQL Nodes (2)**:
   - `mysql1` (NodeId=4) - Primary SQL node at 172.20.0.5
   - `mysql2` (NodeId=5) - Secondary SQL node at 172.20.0.6
   - Both configured with ndbcluster storage engine

4. **ProxySQL Instances (2)**:
   - `proxysql` - Primary load balancer (ports 6033/6032)
   - `proxysql2` - Secondary load balancer (ports 6034/6035)
   - Configured with read/write splitting
   - Multiple user types with different permissions

## Component Descriptions

### Management Nodes
Management nodes are responsible for cluster configuration, node management, and failover coordination. They maintain the configuration data and orchestrate the cluster operations.

```bash
# Check management node status
docker exec -it management1 ndb_mgm -e "show" --ndb-connectstring=172.20.0.2:1186
```

### Data Nodes
Data nodes store the actual data in memory and on disk. They are organized in node groups for redundancy, with each node group containing a complete copy of the data.

```bash
# Check data node status
docker exec -it management1 ndb_mgm -e "all status" --ndb-connectstring=172.20.0.2:1186
```

### MySQL SQL Nodes
SQL nodes provide the SQL interface to the cluster. They process queries and communicate with the data nodes to retrieve and store data.

```bash
# Check MySQL node connection to cluster
docker exec -it mysql1 mysql -uroot -prootpassword -e "SHOW ENGINE NDBCLUSTER STATUS\G"
```

### ProxySQL
ProxySQL provides load balancing, connection pooling, and query routing between applications and the MySQL Cluster. It's configured for read/write splitting, with write operations going to hostgroup 0 and read operations to hostgroup 10.

```bash
# Check ProxySQL configuration
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT * FROM mysql_servers"
```

## Testing Procedures

### 1. Cluster Health Verification

```bash
# Check management node status
docker exec -it management1 ndb_mgm -e "show" --ndb-connectstring=172.20.0.2:1186

# Expected Output:
# Connected to Management Server at: 172.20.0.2:1186
# Cluster Configuration
# ---------------------
# [ndbd(NDB)]     4 node(s)
# id=2    @172.20.0.3  (mysql-8.0.32 ndb-8.0.32, Nodegroup: 0)
# id=3    @172.20.0.4  (mysql-8.0.32 ndb-8.0.32, Nodegroup: 0)
# id=6    @172.20.0.7  (mysql-8.0.32 ndb-8.0.32, Nodegroup: 1)
# id=7    @172.20.0.8  (mysql-8.0.32 ndb-8.0.32, Nodegroup: 1)
#
# [ndb_mgmd(MGM)] 2 node(s)
# id=1    @172.20.0.2  (mysql-8.0.32 ndb-8.0.32)
# id=8    @172.20.0.11  (mysql-8.0.32 ndb-8.0.32)
#
# [mysqld(API)]   2 node(s)
# id=4    @172.20.0.5  (mysql-8.0.32 ndb-8.0.32)
# id=5    @172.20.0.6  (mysql-8.0.32 ndb-8.0.32)

# Check detailed cluster status
docker exec -it management1 ndb_mgm -e "all status" --ndb-connectstring=172.20.0.2:1186

# Expected Output:
# Connected to Management Server at: 172.20.0.2:1186
# Node 2: started (mysql-8.0.32 ndb-8.0.32)
# Node 3: started (mysql-8.0.32 ndb-8.0.32)
# Node 6: started (mysql-8.0.32 ndb-8.0.32)
# Node 7: started (mysql-8.0.32 ndb-8.0.32)

# Check MySQL nodes connection to cluster
docker exec -it mysql1 mysql -uroot -prootpassword -e "SHOW ENGINE NDBCLUSTER STATUS\G"
docker exec -it mysql2 mysql -uroot -prootpassword -e "SHOW ENGINE NDBCLUSTER STATUS\G"

# Expected Output should include:
# number_of_data_nodes=4, number_of_ready_data_nodes=4
```

### 2. ProxySQL Configuration Verification

```bash
# Check ProxySQL server configuration
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT hostgroup_id, hostname, port, status FROM mysql_servers"

# Expected Output:
# +--------------+----------+------+--------+
# | hostgroup_id | hostname | port | status |
# +--------------+----------+------+--------+
# | 0            | mysql1   | 3306 | ONLINE |
# | 0            | mysql2   | 3306 | ONLINE |
# | 10           | mysql1   | 3306 | ONLINE |
# | 10           | mysql2   | 3306 | ONLINE |
# +--------------+----------+------+--------+

# Check user configuration
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT username, default_hostgroup, active FROM mysql_users"

# Expected Output:
# +------------------+-------------------+--------+
# | username         | default_hostgroup | active |
# +------------------+-------------------+--------+
# | root             | 0                 | 1      |
# | testuser         | 0                 | 1      |
# | readonly         | 10                | 1      |
# | readwrite        | 0                 | 1      |
# | admin            | 0                 | 1      |
# | proxysql_monitor | 0                 | 1      |
# +------------------+-------------------+--------+

# Check monitoring status
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT * FROM mysql_server_ping_log ORDER BY time_start_us DESC LIMIT 5"

# Expected Output (all entries should have NULL in ping_error column):
# +----------+------+------------------+----------------------+------------+
# | hostname | port | time_start_us    | ping_success_time_us | ping_error |
# +----------+------+------------------+----------------------+------------+
# | mysql2   | 3306 | 1747892600471030 | 351                  | NULL       |
# | mysql1   | 3306 | 1747892600443279 | 365                  | NULL       |
# | mysql2   | 3306 | 1747892598476366 | 372                  | NULL       |
# | mysql1   | 3306 | 1747892598442110 | 403                  | NULL       |
# | mysql2   | 3306 | 1747892596467104 | 416                  | NULL       |
# +----------+------+------------------+----------------------+------------+
```

### 3. Data Operations Testing

```bash
# Test write operations through ProxySQL
mysql -h127.0.0.1 -P6033 -ureadwrite -preadwritepass -e "USE test_db; INSERT INTO test_table (data) VALUES ('ProxySQL write test'); SELECT * FROM test_table WHERE data='ProxySQL write test'"

# Expected Output:
# +-----+-------------------+---------------------+
# | id  | data              | created_at          |
# +-----+-------------------+---------------------+
# | xxx | ProxySQL write test | YYYY-MM-DD HH:MM:SS |
# +-----+-------------------+---------------------+

# Test read operations through ProxySQL
mysql -h127.0.0.1 -P6033 -ureadonly -preadonlypass -e "USE test_db; SELECT COUNT(*) FROM test_table"

# Expected Output:
# +----------+
# | COUNT(*) |
# +----------+
# | xxx      |
# +----------+

# Verify write permission restrictions for readonly user
mysql -h127.0.0.1 -P6033 -ureadonly -preadonlypass -e "USE test_db; INSERT INTO test_table (data) VALUES ('This should fail')"

# Expected Output:
# ERROR 1142 (42000): INSERT command denied to user 'readonly'@'proxysql.mysqlcluster_ndb-net' for table 'test_table'
```

### 4. Failover Testing

#### MySQL Node Failover

```bash
# Stop mysql1
docker stop mysql1

# Verify ProxySQL redirects traffic to mysql2
mysql -h127.0.0.1 -P6033 -ureadwrite -preadwritepass -e "USE test_db; INSERT INTO test_table (data) VALUES ('Failover test - mysql1 down'); SELECT * FROM test_table ORDER BY id DESC LIMIT 1"

# Expected Output:
# +-----+-----------------------------+---------------------+
# | id  | data                        | created_at          |
# +-----+-----------------------------+---------------------+
# | xxx | Failover test - mysql1 down | YYYY-MM-DD HH:MM:SS |
# +-----+-----------------------------+---------------------+

# Restart mysql1
docker start mysql1
sleep 30  # Wait for it to rejoin

# Verify mysql1 is back in the pool
docker exec -it mysql1 mysql -uroot -prootpassword -e "SHOW ENGINE NDBCLUSTER STATUS\G"
```

#### Data Node Failover

```bash
# Stop ndb1
docker stop ndb1

# Check cluster status - should show ndb1 as not connected
docker exec -it management1 ndb_mgm -e "show" --ndb-connectstring=172.20.0.2:1186

# Expected Output should include:
# id=2 (not connected, accepting connect from ndb1)

# Insert data during failover
mysql -h127.0.0.1 -P6033 -ureadwrite -preadwritepass -e "USE test_db; INSERT INTO test_table (data) VALUES ('Failover test - ndb1 down'); SELECT * FROM test_table ORDER BY id DESC LIMIT 1"

# Restart ndb1
docker start ndb1
sleep 60  # Wait for it to rejoin

# Verify cluster status
docker exec -it management1 ndb_mgm -e "show" --ndb-connectstring=172.20.0.2:1186
```

#### ProxySQL Failover

```bash
# Stop proxysql
docker stop proxysql

# Test connection through secondary ProxySQL
mysql -h127.0.0.1 -P6034 -ureadwrite -preadwritepass -e "USE test_db; INSERT INTO test_table (data) VALUES ('Failover test - proxysql down'); SELECT * FROM test_table ORDER BY id DESC LIMIT 1"

# Expected Output:
# +-----+-------------------------------+---------------------+
# | id  | data                          | created_at          |
# +-----+-------------------------------+---------------------+
# | xxx | Failover test - proxysql down | YYYY-MM-DD HH:MM:SS |
# +-----+-------------------------------+---------------------+

# Restart proxysql
docker start proxysql
```

### 5. User Management Testing

```bash
# Create a new user
mysql -h127.0.0.1 -P6033 -uroot -prootpassword -e "CREATE USER 'newuser'@'%' IDENTIFIED WITH mysql_native_password BY 'newpass'; GRANT SELECT ON test_db.* TO 'newuser'@'%'; FLUSH PRIVILEGES"

# Add the new user to ProxySQL
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "INSERT INTO mysql_users(username, password, default_hostgroup, active) VALUES ('newuser', 'newpass', 10, 1); LOAD MYSQL USERS TO RUNTIME; SAVE MYSQL USERS TO DISK"

# Test the new user connection
mysql -h127.0.0.1 -P6033 -unewuser -pnewpass -e "USE test_db; SELECT * FROM test_table LIMIT 3"

# Verify the new user can't write
mysql -h127.0.0.1 -P6033 -unewuser -pnewpass -e "USE test_db; INSERT INTO test_table (data) VALUES ('This should fail for newuser')"

# Expected Output:
# ERROR 1142 (42000): INSERT command denied to user 'newuser'@'proxysql.mysqlcluster_ndb-net' for table 'test_table'

# Delete the user
mysql -h127.0.0.1 -P6033 -uroot -prootpassword -e "DROP USER 'newuser'@'%'; FLUSH PRIVILEGES"
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "DELETE FROM mysql_users WHERE username='newuser'; LOAD MYSQL USERS TO RUNTIME; SAVE MYSQL USERS TO DISK"
```

### 6. Performance Testing

```bash
# Create a test script for batch inserts
cat > /tmp/performance_test.sql << EOF
USE test_db;
START TRANSACTION;
INSERT INTO test_table (data) VALUES ('Performance test row 1');
INSERT INTO test_table (data) VALUES ('Performance test row 2');
...
INSERT INTO test_table (data) VALUES ('Performance test row 100');
COMMIT;
EOF

# Run performance test with timing
time mysql -h127.0.0.1 -P6033 -ureadwrite -preadwritepass < /tmp/performance_test.sql

# Expected Output:
# real    0m0.083s
# user    0m0.020s
# sys     0m0.017s

# Test read performance
time mysql -h127.0.0.1 -P6033 -ureadonly -preadonlypass -e "USE test_db; SELECT COUNT(*) FROM test_table"
```

## Common Issues and Troubleshooting

### 1. ProxySQL Monitoring User Issue

**Symptom**: ProxySQL shows access denied errors for the monitoring user on mysql2.

```
mysql_server_ping_log shows:
Access denied for user 'proxysql_monitor'@'proxysql.mysqlcluster_ndb-net' (using password: YES)
```

**Root Cause**: The `proxysql_monitor` user exists on mysql1 but not on mysql2. This occurs due to a race condition during initialization where the mysql-init.sh script might run on mysql2 before it's fully synchronized with the cluster.

**Solution**:

```bash
# Check if the monitoring user exists on mysql2
docker exec -it mysql2 mysql -uroot -prootpassword -e "SELECT User, Host FROM mysql.user WHERE User='proxysql_monitor'"

# If it doesn't exist, create it
docker exec -it mysql2 mysql -uroot -prootpassword -e "CREATE USER 'proxysql_monitor'@'%' IDENTIFIED WITH mysql_native_password BY 'monitorpass123'; GRANT USAGE, REPLICATION CLIENT, PROCESS, SELECT ON *.* TO 'proxysql_monitor'@'%'; FLUSH PRIVILEGES;"
```

### 2. Initial Deployment Requiring Multiple Attempts

**Symptom**: During initial deployment, `docker compose up -d` shows "container mysql2 is unhealthy" and requires a second attempt.

**Root Cause**: The MySQL containers need time to initialize and join the NDB cluster. The healthcheck might run before MySQL has fully initialized with the NDB engine.

**Solution**:

1. Increase the `interval` and `retries` in the healthcheck configuration in docker-compose.yml:

```yaml
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p$$MYSQL_ROOT_PASSWORD"]
  interval: 20s  # Increased from 10s
  timeout: 5s
  retries: 10    # Increased from 5
```

2. Increase the sleep time in mysql-init.sh:

```bash
# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
sleep 60  # Increased from 30
```

### 3. ProxySQL Admin Authentication Issues

**Symptom**: Unable to connect to ProxySQL admin interface with error "Access denied for user 'admin'@'127.0.0.1'".

**Root Cause**: ProxySQL uses 'radmin' as the default admin username for the admin interface (port 6032), while 'admin' is a MySQL user.

**Solution**: Use the correct credentials for the admin interface:

```bash
# Correct command
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT * FROM mysql_servers"
```

## Automated Testing Suite

An automated testing suite is provided to verify all aspects of the MySQL Cluster functionality. The script `mysql_cluster_test_suite.sh` can run individual tests or the complete test suite.

### Usage

```bash
# Make the script executable
chmod +x mysql_cluster_test_suite.sh

# Run all tests
./mysql_cluster_test_suite.sh all

# Run specific test modules
./mysql_cluster_test_suite.sh health       # Test cluster health
./mysql_cluster_test_suite.sh proxysql     # Test ProxySQL configuration
./mysql_cluster_test_suite.sh data         # Test data operations
./mysql_cluster_test_suite.sh users        # Test user management
./mysql_cluster_test_suite.sh mysql-failover    # Test MySQL node failover
./mysql_cluster_test_suite.sh data-failover     # Test data node failover
./mysql_cluster_test_suite.sh proxysql-failover # Test ProxySQL failover
./mysql_cluster_test_suite.sh performance  # Test performance
./mysql_cluster_test_suite.sh monitoring   # Test monitoring
./mysql_cluster_test_suite.sh fix-monitoring    # Fix monitoring user issue
```

### Configuration

The test suite can be configured by setting environment variables:

```bash
# Example: Change the test data size for performance tests
TEST_DATA_SIZE=500 ./mysql_cluster_test_suite.sh performance

# Example: Change the wait time for failover tests
WAIT_TIME=20 ./mysql_cluster_test_suite.sh mysql-failover
```

Available configuration variables:

- `MYSQL_ROOT_PASSWORD`: Root password for MySQL (default: "rootpassword")
- `MYSQL_HOST`: MySQL host (default: "127.0.0.1")
- `MYSQL_PORT`: MySQL port (default: "3306")
- `PROXYSQL_HOST`: ProxySQL host (default: "127.0.0.1")
- `PROXYSQL_PORT`: ProxySQL MySQL protocol port (default: "6033")
- `PROXYSQL_ADMIN_PORT`: ProxySQL admin interface port (default: "6032")
- `PROXYSQL_ADMIN_USER`: ProxySQL admin username (default: "radmin")
- `PROXYSQL_ADMIN_PASSWORD`: ProxySQL admin password (default: "admin")
- `PROXYSQL2_PORT`: Secondary ProxySQL MySQL protocol port (default: "6034")
- `TEST_DATA_SIZE`: Number of rows for performance tests (default: 100)
- `WAIT_TIME`: Wait time in seconds for failover tests (default: 10)

## Performance Benchmarks

Performance testing of the MySQL Cluster with ProxySQL showed excellent results:

1. **Transaction Performance**:
   - Small transaction (10 INSERTs): Completed in 0.064 seconds
   - Large transaction (100 INSERTs): Completed in 0.083 seconds
   - Minimal performance degradation with increased transaction size

2. **Query Routing Statistics**:
   - Write operations (INSERT, CREATE, DROP) correctly routed to hostgroup 0
   - Read operations (SELECT) correctly routed to hostgroup 10
   - ProxySQL properly enforced query routing rules

3. **Connection Distribution**:
   - mysql1 handled most write operations (121 queries in hostgroup 0)
   - Read queries were distributed between MySQL nodes
   - Connection pooling working correctly with ConnFree connections available

4. **Load Balancing Effectiveness**:
   - ProxySQL effectively distributed the workload according to the configured weights
   - No connection errors observed during testing
   - Low latency across all operations (278μs average)

## Monitoring Guidelines

For production deployments, consider implementing the following monitoring:

1. **Cluster Health Monitoring**:
   - Regular checks of management node status
   - Monitoring of data node availability and memory usage
   - Alerts for node failures or disconnections

2. **ProxySQL Monitoring**:
   - Connection pool utilization
   - Query routing statistics
   - Server ping status

3. **Performance Monitoring**:
   - Transaction throughput
   - Query latency
   - Connection counts

4. **Integration with External Monitoring Systems**:
   - Prometheus and Grafana for metrics collection and visualization
   - Alerting for critical issues
   - Historical performance data analysis

### Example Prometheus Metrics Collection

For a production environment, consider implementing Prometheus metrics collection:

```yaml
# Example prometheus.yml configuration
scrape_configs:
  - job_name: 'mysql_exporter'
    static_configs:
      - targets: ['mysql1:9104', 'mysql2:9104']
  - job_name: 'proxysql_exporter'
    static_configs:
      - targets: ['proxysql:9104', 'proxysql2:9104']
```

This would require setting up the MySQL and ProxySQL exporters on each respective container.
