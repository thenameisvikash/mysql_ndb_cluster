# Installation Guide

[← Architecture](architecture.md) | [Documentation Index](../DOCUMENTATION.md) | [Configuration Guide →](configuration.md)

*Related: [Production Readiness](../production_ready.md)*

This guide provides step-by-step instructions for installing and configuring the MySQL Cluster with ProxySQL.

## Prerequisites

- Linux-based operating system (Ubuntu 20.04+ recommended)
- Docker Engine (20.10+)
- Docker Compose (2.0+)
- At least 8GB RAM available for Docker
- At least 20GB free disk space
- MySQL client (for testing connections)

## Installation Steps

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/mysql-cluster-proxysql.git
cd mysql-cluster-proxysql
```

### 2. Configure Environment (Optional)

The default configuration works out of the box, but you can customize it by editing the following files:

- `docker-compose.yml`: Container configuration
- `config/management1-config/management-config.ini`: NDB Cluster configuration
- `config/mysql1/my.cnf` and `config/mysql2/my.cnf`: MySQL configuration
- `config/proxysql1-config/proxysql-fixed-complete.cnf`: ProxySQL configuration

### 3. Start the Cluster

```bash
# Start all components
docker-compose up -d

# Check the status of all containers
docker-compose ps
```

The startup process may take a minute or two as the components initialize and connect to each other.

### 4. Verify the Deployment

Run the health check to verify that all components are running correctly:

```bash
./mysql_cluster_test_suite.sh health
```

You should see all tests passing, indicating that the cluster is healthy.

### 5. Initialize Users (Optional)

The default deployment includes the following users:
- `root`: Administrative access (password: `rootpassword`)
- `readwrite`: Read/write access (password: `readwritepass`)
- `readonly`: Read-only access (password: `readonlypass`)

If you want to create additional users, use the user management script:

```bash
# Create a new read-only user
./scripts/user_management.sh create new_readonly_user password123

# Create a new read/write user
./scripts/user_management.sh -w create new_readwrite_user password123
```

## Connection Information

### ProxySQL Endpoints

- Primary ProxySQL:
  - MySQL Protocol: `127.0.0.1:6033`
  - Admin Interface: `127.0.0.1:6032` (username: `radmin`, password: `radmin`)

- Secondary ProxySQL:
  - MySQL Protocol: `127.0.0.1:6034`
  - Admin Interface: `127.0.0.1:6035` (username: `radmin`, password: `radmin`)

### Direct MySQL Endpoints

- MySQL Node 1: `127.0.0.1:3306`
- MySQL Node 2: `127.0.0.1:3307`

## Troubleshooting Initial Deployment

### Issue: Containers Show as "Unhealthy"

If some containers show as "unhealthy" during the first deployment, it may be because the cluster needs more time to initialize. Try the following:

```bash
# Stop all containers
docker-compose down

# Start them again
docker-compose up -d
```

### Issue: MySQL Nodes Fail to Join the Cluster

If MySQL nodes fail to join the cluster, check the logs:

```bash
docker-compose logs mysql1
docker-compose logs mysql2
```

Common issues include:
- Management nodes not fully initialized
- Data nodes not fully initialized
- Incorrect configuration in my.cnf

### Issue: ProxySQL Monitoring User Missing

If ProxySQL shows errors about the monitoring user, you can fix it with:

```bash
./mysql_cluster_test_suite.sh fix-monitoring
```

## Next Steps

After successful installation:

1. Run the full test suite to verify all functionality:
   ```bash
   ./mysql_cluster_test_suite.sh all
   ```

2. Review the [Architecture Overview](architecture.md) to understand the system components

3. Learn about [User Management](user-management.md) to set up proper access control

4. Explore [Configuration Guide](configuration.md) for tuning options
