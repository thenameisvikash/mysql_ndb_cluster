# Testing Guide

[← User Management](user-management.md) | [Documentation Index](../DOCUMENTATION.md) | [Troubleshooting →](troubleshooting.md)

*Related: [MySQL Cluster Testing Documentation](../MySQL_Cluster_Testing_Documentation.md)*

This guide explains how to test your MySQL Cluster with ProxySQL deployment to ensure it's working correctly and can handle failures gracefully.

## Automated Testing Suite

The project includes a comprehensive test suite (`mysql_cluster_test_suite.sh`) that verifies all aspects of the cluster functionality, including high availability, failover, and performance.

### Running the Test Suite

```bash
# Make the test script executable (if not already)
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

### Test Suite Configuration

The test suite can be configured through environment variables:

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
- `PROXYSQL_ADMIN_PASSWORD`: ProxySQL admin password (default: "radmin")
- `PROXYSQL2_PORT`: Secondary ProxySQL MySQL protocol port (default: "6034")
- `TEST_DATA_SIZE`: Number of rows for performance tests (default: 100)
- `WAIT_TIME`: Wait time in seconds for failover tests (default: 10)

## Manual Testing Procedures

If you prefer to test specific aspects manually, follow these procedures:

### 1. Cluster Health Testing

```bash
# Check management node status
docker exec -it management1 ndb_mgm -e "show" --ndb-connectstring=172.20.0.2:1186

# Check all nodes status
docker exec -it management1 ndb_mgm -e "all status" --ndb-connectstring=172.20.0.2:1186

# Check MySQL connection to cluster
docker exec -it mysql1 mysql -uroot -prootpassword -e "SHOW ENGINE NDBCLUSTER STATUS\G"
docker exec -it mysql2 mysql -uroot -prootpassword -e "SHOW ENGINE NDBCLUSTER STATUS\G"
```

### 2. ProxySQL Configuration Testing

```bash
# Check ProxySQL server configuration
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT hostgroup_id, hostname, port, status FROM mysql_servers"

# Check user configuration
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT username, default_hostgroup, active FROM mysql_users"

# Check query routing rules
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT rule_id, active, username, match_digest, destination_hostgroup FROM mysql_query_rules ORDER BY rule_id"

# Check monitoring status
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT * FROM mysql_server_ping_log ORDER BY time_start_us DESC LIMIT 5"
```

### 3. Data Operations Testing

```bash
# Test write operations through ProxySQL
mysql -h127.0.0.1 -P6033 -ureadwrite -preadwritepass -e "USE test_db; INSERT INTO test_table (data) VALUES ('ProxySQL write test'); SELECT * FROM test_table WHERE data='ProxySQL write test'"

# Test read operations through ProxySQL
mysql -h127.0.0.1 -P6033 -ureadonly -preadonlypass -e "USE test_db; SELECT COUNT(*) FROM test_table"

# Verify write permission restrictions for readonly user
mysql -h127.0.0.1 -P6033 -ureadonly -preadonlypass -e "USE test_db; INSERT INTO test_table (data) VALUES ('This should fail')"
# Expected output: ERROR 1142 (42000): INSERT command denied to user 'readonly'@'...' for table 'test_table'
```

### 4. MySQL Node Failover Testing

```bash
# Stop mysql1
docker stop mysql1

# Verify ProxySQL redirects traffic to mysql2
mysql -h127.0.0.1 -P6033 -ureadwrite -preadwritepass -e "USE test_db; INSERT INTO test_table (data) VALUES ('Failover test - mysql1 down'); SELECT * FROM test_table ORDER BY id DESC LIMIT 1"

# Restart mysql1
docker start mysql1
sleep 30  # Wait for it to rejoin

# Verify mysql1 is back in the pool
docker exec -it mysql1 mysql -uroot -prootpassword -e "SHOW ENGINE NDBCLUSTER STATUS\G"
```

### 5. Data Node Failover Testing

```bash
# Stop ndb1
docker stop ndb1

# Check cluster status - should show ndb1 as not connected
docker exec -it management1 ndb_mgm -e "show" --ndb-connectstring=172.20.0.2:1186

# Insert data during failover
mysql -h127.0.0.1 -P6033 -ureadwrite -preadwritepass -e "USE test_db; INSERT INTO test_table (data) VALUES ('Failover test - ndb1 down'); SELECT * FROM test_table ORDER BY id DESC LIMIT 1"

# Restart ndb1
docker start ndb1
sleep 60  # Wait for it to rejoin

# Verify cluster status
docker exec -it management1 ndb_mgm -e "show" --ndb-connectstring=172.20.0.2:1186
```

### 6. ProxySQL Failover Testing

```bash
# Stop proxysql
docker stop proxysql

# Test connection through secondary ProxySQL
mysql -h127.0.0.1 -P6034 -ureadwrite -preadwritepass -e "USE test_db; INSERT INTO test_table (data) VALUES ('Failover test - proxysql down'); SELECT * FROM test_table ORDER BY id DESC LIMIT 1"

# Restart proxysql
docker start proxysql
```

### 7. Performance Testing

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

# Test read performance
time mysql -h127.0.0.1 -P6033 -ureadonly -preadonlypass -e "USE test_db; SELECT COUNT(*) FROM test_table"
```

## Expected Test Results

### Cluster Health Tests

- All management nodes should be running
- All data nodes should be running and in the "started" state
- All SQL nodes should be connected to the cluster
- The number of ready data nodes should match the total number of data nodes

### ProxySQL Configuration Tests

- All MySQL servers should be in the "ONLINE" state
- User configurations should match expectations
- Query routing rules should be properly configured
- Monitoring should show successful pings to all MySQL nodes

### Data Operations Tests

- Write operations should succeed through the readwrite user
- Read operations should succeed through both readwrite and readonly users
- Write operations should be denied for the readonly user

### Failover Tests

- When a MySQL node fails, operations should continue through the remaining node
- When a data node fails, operations should continue through the remaining nodes in the same node group
- When the primary ProxySQL fails, operations should continue through the secondary instance
- All components should rejoin the cluster successfully after restart

### Performance Tests

- Transaction performance should be within acceptable limits
- Read/write splitting should be evident in the query statistics
- Connection pooling should be effective with free connections available

## Troubleshooting Test Failures

### MySQL Node Connection Issues

If tests fail due to MySQL connection issues:

1. Check if the MySQL containers are running:
   ```bash
   docker ps | grep mysql
   ```

2. Check MySQL logs for errors:
   ```bash
   docker logs mysql1
   docker logs mysql2
   ```

3. Verify MySQL is listening on the expected ports:
   ```bash
   docker exec -it mysql1 netstat -tuln | grep 3306
   ```

### ProxySQL Configuration Issues

If tests fail due to ProxySQL configuration issues:

1. Check ProxySQL logs:
   ```bash
   docker logs proxysql
   ```

2. Verify ProxySQL admin credentials:
   ```bash
   docker exec -it proxysql cat /etc/proxysql.cnf | grep admin_credentials
   ```

3. Check if ProxySQL can connect to MySQL:
   ```bash
   docker exec -it proxysql mysql -h mysql1 -uroot -prootpassword -e "SELECT 1"
   ```

### Data Node Issues

If tests fail due to data node issues:

1. Check data node logs:
   ```bash
   docker logs ndb1
   docker logs ndb2
   ```

2. Verify data node configuration:
   ```bash
   docker exec -it management1 cat /etc/mysql-cluster/config.ini
   ```

3. Check data node memory usage:
   ```bash
   docker exec -it management1 ndb_mgm -e "all report memory" --ndb-connectstring=172.20.0.2:1186
   ```

## Continuous Testing

For production environments, consider setting up continuous testing:

1. Schedule regular execution of the test suite:
   ```bash
   # Add to crontab
   0 2 * * * /path/to/mysql_cluster_test_suite.sh health >> /var/log/mysql-cluster-tests.log 2>&1
   ```

2. Implement monitoring and alerting based on test results

3. Periodically perform full test suite runs during maintenance windows
