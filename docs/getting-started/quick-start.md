# Quick Start Guide

[← Documentation Index](../index.md) | [Installation Guide →](installation.md)

*Related: [Prerequisites](prerequisites.md) | [Production Readiness](production-ready.md)*

This guide will help you quickly set up a MySQL Cluster with ProxySQL for development or testing purposes.

## Prerequisites

- Docker Engine (20.10+)
- Docker Compose (2.0+)
- At least 8GB RAM available for Docker
- At least 20GB free disk space
- MySQL client (for testing connections)

## Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/mysql-cluster-proxysql.git
cd mysql-cluster-proxysql
```

## Step 2: Start the Cluster

```bash
# Start all components
docker-compose up -d

# Check the status of all containers
docker-compose ps
```

The startup process may take a minute or two as the components initialize and connect to each other.

## Step 3: Verify the Deployment

Run the health check to verify that all components are running correctly:

```bash
./mysql_cluster_test_suite.sh health
```

You should see all tests passing, indicating that the cluster is healthy.

## Step 4: Connect to the Cluster

Connect through ProxySQL for normal operations:

```bash
# For read/write operations
mysql -h127.0.0.1 -P6033 -u${READWRITE_USER} -p${READWRITE_PASSWORD}

# For read-only operations
mysql -h127.0.0.1 -P6033 -u${READONLY_USER} -p${READONLY_PASSWORD}
```

Default credentials:
- Read/write user: `readwrite` with password `readwritepass`
- Read-only user: `readonly` with password `readonlypass`

## Step 5: Run a Simple Test

Create a test database and table:

```sql
CREATE DATABASE test_db;
USE test_db;
CREATE TABLE test_table (
  id INT AUTO_INCREMENT PRIMARY KEY,
  data VARCHAR(100)
) ENGINE=NDBCLUSTER;

-- Insert some test data
INSERT INTO test_table (data) VALUES ('Test data 1');
INSERT INTO test_table (data) VALUES ('Test data 2');

-- Verify the data
SELECT * FROM test_table;
```

## Step 6: Test Failover (Optional)

To test the high availability features, you can simulate a failure of one of the components:

```bash
# Stop one of the MySQL nodes
docker stop mysql1

# Verify that the cluster still works
mysql -h127.0.0.1 -P6033 -u${READWRITE_USER} -p${READWRITE_PASSWORD} -e "USE test_db; SELECT * FROM test_table;"

# Restart the MySQL node
docker start mysql1
```

## Step 7: Stop the Cluster (When Done)

```bash
docker-compose down
```

## Next Steps

- Read the [Installation Guide](installation.md) for detailed installation instructions
- Learn about the [Architecture](../architecture/overview.md) of the MySQL Cluster
- Configure the cluster for [Production](production-ready.md)
- Explore the [Testing Guide](../testing/overview.md) for comprehensive testing procedures

## Troubleshooting

If you encounter issues during startup:

- Check container logs: `docker-compose logs`
- Ensure all ports are available
- Verify Docker has enough resources allocated
- Run the test suite with specific tests: `./mysql_cluster_test_suite.sh [test_name]`

For more detailed troubleshooting, see the [Troubleshooting Guide](../troubleshooting/common-issues.md).
