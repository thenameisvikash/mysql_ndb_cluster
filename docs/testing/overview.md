# Testing Overview

[← Documentation Index](../index.md) | [Automated Tests →](automated-tests.md)

*Related: [Manual Tests](manual-tests.md) | [Performance Tests](performance-tests.md)*

This guide provides an overview of testing strategies and methodologies for the MySQL Cluster with ProxySQL.

## Testing Philosophy

Testing a distributed system like MySQL Cluster requires a comprehensive approach that covers:

1. **Functionality**: Ensuring all components work as expected
2. **High Availability**: Verifying failover mechanisms
3. **Performance**: Measuring throughput and latency
4. **Data Integrity**: Ensuring data consistency across nodes
5. **Security**: Validating access controls and permissions

## Testing Tools

The project includes several testing tools:

1. **Automated Test Suite**: `mysql_cluster_test_suite.sh` - A comprehensive Bash script that tests all aspects of the cluster
2. **Performance Testing Script**: `test-load.py` - A Python script for performance testing
3. **Manual Testing Procedures**: Documented procedures for manual testing
4. **ProxySQL Testing Tools**: Scripts for testing ProxySQL configuration and routing

## Testing Categories

### 1. Health Tests

Health tests verify that all components are running and properly connected:

- Management node status
- Data node status
- SQL node status
- ProxySQL status
- Connectivity between components

### 2. Functionality Tests

Functionality tests verify that the cluster can perform basic operations:

- Database creation
- Table creation with NDB storage engine
- Data insertion
- Data retrieval
- Data modification
- Data deletion

### 3. High Availability Tests

High availability tests verify that the cluster can handle component failures:

- Management node failover
- Data node failover
- SQL node failover
- ProxySQL failover
- Network partition handling

### 4. Performance Tests

Performance tests measure the cluster's performance under various conditions:

- Read throughput
- Write throughput
- Mixed workload performance
- Connection handling
- Query latency

### 5. Security Tests

Security tests verify that the cluster's security mechanisms work as expected:

- User authentication
- Access control
- Read-only user restrictions
- Administrative access controls

## Testing Environments

Tests should be run in different environments:

1. **Development**: Local testing during development
2. **Staging**: Testing in a staging environment before production
3. **Production**: Limited testing in production to verify deployment

## Testing Workflow

A typical testing workflow includes:

1. **Initial Setup Testing**: Run health tests after initial setup
2. **Functional Testing**: Verify basic functionality
3. **High Availability Testing**: Verify failover mechanisms
4. **Performance Testing**: Measure performance under expected load
5. **Security Testing**: Verify security mechanisms
6. **Regression Testing**: Rerun tests after configuration changes

## Test Suite Configuration

The test suite can be configured through environment variables:

```bash
# Example: Change the test data size for performance tests
export TEST_DATA_SIZE=500
./mysql_cluster_test_suite.sh performance

# Example: Change the wait time for failover tests
export WAIT_TIME=20
./mysql_cluster_test_suite.sh mysql-failover
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

## Test Reports

The test suite generates reports for each test run, including:

- Test name
- Test result (PASS/FAIL)
- Detailed output for failed tests
- Summary of all tests

## Continuous Testing

For production environments, it's recommended to set up continuous testing:

1. Schedule regular test runs
2. Monitor test results
3. Alert on test failures
4. Track performance trends over time

## Related Documentation

- [Automated Tests](automated-tests.md) - Using the automated test suite
- [Manual Tests](manual-tests.md) - Manual testing procedures
- [Performance Tests](performance-tests.md) - Performance testing
- [Troubleshooting](../troubleshooting/common-issues.md) - Troubleshooting common issues
