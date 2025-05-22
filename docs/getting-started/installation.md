# Installation Guide

[← Quick Start](quick-start.md) | [Documentation Index](../index.md) | [Prerequisites →](prerequisites.md)

*Related: [Production Readiness](production-ready.md) | [Configuration Overview](../configuration/overview.md)*

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

### 2. Configure Environment Variables (Optional)

Create a `.env` file to customize your deployment:

```bash
# MySQL Credentials
MYSQL_ROOT_PASSWORD=your_secure_root_password
READWRITE_USER=readwrite
READWRITE_PASSWORD=your_secure_readwrite_password
READONLY_USER=readonly
READONLY_PASSWORD=your_secure_readonly_password

# ProxySQL Credentials
PROXYSQL_ADMIN_USER=radmin
PROXYSQL_ADMIN_PASSWORD=your_secure_admin_password

# Resource Allocation
DATA_MEMORY=512M
INDEX_MEMORY=128M
```

### 3. Customize Configuration (Optional)

The default configuration works out of the box, but you can customize it by editing the following files:

#### Management Node Configuration

Edit `config/management-config.ini`:

```ini
[ndbd default]
NoOfReplicas=2                # Number of replicas for data
DataMemory=512M               # Memory allocated for data storage
IndexMemory=128M              # Memory allocated for indexes
MaxNoOfConcurrentOperations=1000000  # Maximum concurrent operations
MaxNoOfConcurrentTransactions=1000000  # Maximum concurrent transactions
```

#### MySQL Node Configuration

Edit `config/mysql1/my.cnf` and `config/mysql2/my.cnf`:

```ini
[mysqld]
ndbcluster                      # Enable NDB Cluster storage engine
default_storage_engine=ndbcluster  # Set NDB as default storage engine
ndb-connectstring=management1:1186,management2:1186  # Connection to management nodes

max_connections=1000           # Maximum client connections
table_open_cache=4000          # Table cache size
thread_cache_size=100          # Thread cache size
```

#### ProxySQL Configuration

Edit `config/proxysql-config.cnf`:

```ini
mysql_servers:
(
    { address="mysql1" , port=3306 , hostgroup=0, max_connections=2000, max_replication_lag=10, weight=1000 },
    { address="mysql2" , port=3306 , hostgroup=0, max_connections=2000, max_replication_lag=10, weight=1000 },
    { address="mysql1" , port=3306 , hostgroup=10, max_connections=2000, max_replication_lag=10, weight=1000 },
    { address="mysql2" , port=3306 , hostgroup=10, max_connections=2000, max_replication_lag=10, weight=1000 }
)

mysql_query_rules:
(
    { rule_id=1, active=1, match_digest="^SELECT.*", destination_hostgroup=10, apply=1 },
    { rule_id=2, active=1, match_digest=".*", destination_hostgroup=0, apply=1 }
)

mysql_users:
(
    { username="root", password="rootpassword", default_hostgroup=0, active=1 },
    { username="readwrite", password="readwritepass", default_hostgroup=0, active=1 },
    { username="readonly", password="readonlypass", default_hostgroup=10, active=1 }
)
```

### 4. Start the Cluster

```bash
# Start all components
docker-compose up -d

# Check the status of all containers
docker-compose ps
```

The startup process may take a minute or two as the components initialize and connect to each other.

### 5. Verify the Deployment

Run the health check to verify that all components are running correctly:

```bash
./mysql_cluster_test_suite.sh health
```

You should see all tests passing, indicating that the cluster is healthy.

### 6. Initialize Users (Optional)

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

# Start the management nodes first
docker-compose up -d management1 management2

# Wait for management nodes to initialize
sleep 30

# Start data nodes
docker-compose up -d ndb1 ndb2 ndb3 ndb4

# Wait for data nodes to initialize
sleep 30

# Start MySQL nodes
docker-compose up -d mysql1 mysql2

# Wait for MySQL nodes to initialize
sleep 30

# Start ProxySQL
docker-compose up -d proxysql proxysql2
```

### Issue: Cannot Connect to ProxySQL

If you cannot connect to ProxySQL, check the following:

```bash
# Check if ProxySQL is running
docker-compose ps proxysql

# Check ProxySQL logs
docker-compose logs proxysql

# Check if MySQL nodes are accessible to ProxySQL
docker exec proxysql ping -c 3 mysql1
docker exec proxysql ping -c 3 mysql2
```

### Issue: MySQL Nodes Cannot Connect to Cluster

If MySQL nodes cannot connect to the cluster, check the following:

```bash
# Check management node status
docker exec management1 ndb_mgm -e "show" --ndb-connectstring=management1:1186

# Check MySQL logs
docker-compose logs mysql1
docker-compose logs mysql2

# Check if MySQL can connect to management nodes
docker exec mysql1 ping -c 3 management1
docker exec mysql1 ping -c 3 management2
```

## Next Steps

- Read the [Configuration Guide](../configuration/overview.md) for detailed configuration options
- Learn about [User Management](../operations/user-management.md) to set up users and permissions
- Explore the [Testing Guide](../testing/overview.md) for comprehensive testing procedures
- Set up [Monitoring](../operations/monitoring.md) for your cluster
- Configure [Backup and Recovery](../operations/backup-recovery.md) procedures

## Related Documentation

- [Quick Start Guide](quick-start.md) - Get up and running quickly
- [Prerequisites](prerequisites.md) - System requirements and prerequisites
- [Production Readiness](production-ready.md) - Guidelines for production deployment
- [Configuration Overview](../configuration/overview.md) - Configuration principles and best practices
