# Automated Tests

[← Testing Overview](overview.md) | [Documentation Index](../index.md) | [Manual Tests →](manual-tests.md)

*Related: [Performance Tests](performance-tests.md) | [Troubleshooting](../troubleshooting/common-issues.md)*

This guide explains how to use the automated test suite to verify the functionality, high availability, and performance of your MySQL Cluster with ProxySQL.

## Test Suite Overview

The project includes a comprehensive test suite (`mysql_cluster_test_suite.sh`) that automates testing of all aspects of the cluster. The test suite is written in Bash and includes tests for:

- Cluster health
- ProxySQL configuration
- Data operations
- User management
- Failover scenarios
- Performance

## Running the Test Suite

### Prerequisites

- The MySQL Cluster must be running
- MySQL client must be installed on the host machine
- Bash shell environment

### Basic Usage

To run all tests:

```bash
./mysql_cluster_test_suite.sh all
```

To run specific test modules:

```bash
./mysql_cluster_test_suite.sh health       # Test cluster health
./mysql_cluster_test_suite.sh proxysql     # Test ProxySQL configuration
./mysql_cluster_test_suite.sh data         # Test data operations
./mysql_cluster_test_suite.sh users        # Test user management
./mysql_cluster_test_suite.sh mysql-failover    # Test MySQL node failover
./mysql_cluster_test_suite.sh data-failover     # Test data node failover
./mysql_cluster_test_suite.sh proxysql-failover # Test ProxySQL failover
./mysql_cluster_test_suite.sh performance  # Test performance
```

### Configuration

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

## Test Modules

### Health Tests

Health tests verify that all components are running and properly connected:

```bash
./mysql_cluster_test_suite.sh health
```

This includes:
- Management node status
- Data node status
- MySQL node status
- ProxySQL status
- Connectivity between components

### ProxySQL Tests

ProxySQL tests verify the ProxySQL configuration and routing:

```bash
./mysql_cluster_test_suite.sh proxysql
```

This includes:
- Server configuration
- User configuration
- Query routing rules
- Connection pooling
- Monitoring status

### Data Operations Tests

Data operations tests verify that the cluster can perform basic operations:

```bash
./mysql_cluster_test_suite.sh data
```

This includes:
- Database creation
- Table creation with NDB storage engine
- Data insertion
- Data retrieval
- Data modification
- Data deletion

### User Management Tests

User management tests verify that user management works correctly:

```bash
./mysql_cluster_test_suite.sh users
```

This includes:
- Creating users
- Granting permissions
- Revoking permissions
- Testing read-only users
- Testing read-write users

### Failover Tests

Failover tests verify that the cluster can handle component failures:

```bash
./mysql_cluster_test_suite.sh mysql-failover    # Test MySQL node failover
./mysql_cluster_test_suite.sh data-failover     # Test data node failover
./mysql_cluster_test_suite.sh proxysql-failover # Test ProxySQL failover
```

These tests simulate failures by stopping containers and verifying that the cluster continues to function.

### Performance Tests

Performance tests measure the cluster's performance under various conditions:

```bash
./mysql_cluster_test_suite.sh performance
```

This includes:
- Read throughput
- Write throughput
- Mixed workload performance

## Understanding Test Results

The test suite provides detailed output for each test:

```
========== CLUSTER HEALTH TESTS ==========

✓ PASS: Management Node Status
Connected to Management Server at: management1:1186
Cluster Configuration
---------------------
[ndbd(NDB)]     4 node(s)
id=2    @172.20.0.3  (mysql-8.0.32 ndb-8.0.32, Nodegroup: 0, *)
id=3    @172.20.0.4  (mysql-8.0.32 ndb-8.0.32, Nodegroup: 0)
id=6    @172.20.0.7  (mysql-8.0.32 ndb-8.0.32, Nodegroup: 1)
id=7    @172.20.0.8  (mysql-8.0.32 ndb-8.0.32, Nodegroup: 1, *)

[ndb_mgmd(MGM)] 2 node(s)
id=1    @172.20.0.2  (mysql-8.0.32 ndb-8.0.32)
id=8    @172.20.0.11  (mysql-8.0.32 ndb-8.0.32)

[mysqld(API)]   2 node(s)
id=4    @172.20.0.5  (mysql-8.0.32 ndb-8.0.32)
id=5    @172.20.0.6  (mysql-8.0.32 ndb-8.0.32)
```

Each test is marked as PASS or FAIL, with detailed output for failed tests.

At the end of the test run, a summary is provided:

```
========== TEST SUMMARY ==========

Total tests: 25
Passed: 25
Failed: 0

All tests passed!
```

## Extending the Test Suite

The test suite can be extended with additional tests:

1. Open `mysql_cluster_test_suite.sh` in a text editor
2. Add a new test function following the existing pattern
3. Add the new test to the appropriate test module or create a new module
4. Update the usage information and case statement in the main function

Example of adding a new test function:

```bash
# Function to test a new feature
test_new_feature() {
    print_header "NEW FEATURE TESTS"
    
    # Test 1: Description of test
    run_test_command "Test Name" \
        "command to run" \
        "true"  # true if the command should succeed, false if it should fail
    
    # Test 2: Check if output contains expected string
    check_output_contains "Test Name" \
        "command to run" \
        "expected string" \
        "false"  # false to check if string is present, true to check if string is absent
}
```

## Troubleshooting Test Failures

If tests fail, follow these steps:

1. Check the detailed output for the failed test
2. Verify that all components are running:
   ```bash
   docker-compose ps
   ```
3. Check component logs:
   ```bash
   docker-compose logs management1
   docker-compose logs mysql1
   docker-compose logs proxysql
   ```
4. Fix any issues and rerun the tests

Common issues include:
- Network connectivity problems
- Configuration errors
- Resource limitations
- Timing issues (try increasing WAIT_TIME)

## Continuous Testing

For production environments, it's recommended to set up continuous testing:

1. Schedule regular test runs using cron:
   ```bash
   # Run health tests every hour
   0 * * * * cd /path/to/mysql-cluster && ./mysql_cluster_test_suite.sh health > /var/log/mysql-cluster/health-test-$(date +\%Y\%m\%d\%H\%M\%S).log 2>&1
   
   # Run full tests daily
   0 0 * * * cd /path/to/mysql-cluster && ./mysql_cluster_test_suite.sh all > /var/log/mysql-cluster/full-test-$(date +\%Y\%m\%d).log 2>&1
   ```

2. Monitor test results and alert on failures

## Related Documentation

- [Testing Overview](overview.md) - Testing principles and strategies
- [Manual Tests](manual-tests.md) - Manual testing procedures
- [Performance Tests](performance-tests.md) - Performance testing
- [Troubleshooting](../troubleshooting/common-issues.md) - Troubleshooting common issues
