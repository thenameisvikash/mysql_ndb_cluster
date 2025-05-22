# Configuration Guide

[← Installation](installation.md) | [Documentation Index](../DOCUMENTATION.md) | [User Management →](user-management.md)

*Related: [Arbitration Configuration](../Arbitration_Configuration.md) | [Partitioning Limitations](../Partitioning_Limitations.md)*

This guide explains how to configure the MySQL Cluster with ProxySQL for optimal performance and reliability.

## Configuration Files Overview

The MySQL Cluster configuration is spread across multiple files:

| Component | Configuration File | Purpose |
|-----------|-------------------|---------|
| Management Node 1 | `config/management1-config/management-config.ini` | NDB Cluster configuration |
| Management Node 2 | `config/management2-config/management-config.ini` | NDB Cluster configuration (redundant) |
| MySQL Node 1 | `config/mysql1/my.cnf` | MySQL server configuration |
| MySQL Node 2 | `config/mysql2/my.cnf` | MySQL server configuration |
| ProxySQL 1 | `config/proxysql1-config/proxysql-fixed-complete.cnf` | ProxySQL configuration |
| ProxySQL 2 | `config/proxysql2-config/proxysql-fixed-complete.cnf` | ProxySQL configuration (redundant) |
| Docker Compose | `docker-compose.yml` | Container orchestration |

## Management Node Configuration

The management node configuration (`management-config.ini`) defines the overall cluster structure, including data nodes, SQL nodes, and their properties.

### Key Parameters

```ini
[ndbd default]
NoOfReplicas=2                # Number of replicas for data
DataMemory=512M               # Memory allocated for data storage
IndexMemory=128M              # Memory allocated for indexes
MaxNoOfConcurrentOperations=1000000  # Maximum concurrent operations
MaxNoOfConcurrentTransactions=1000000  # Maximum concurrent transactions
```

### Scaling Recommendations

- **DataMemory**: Increase for larger datasets (rule of thumb: 2x your expected data size)
- **IndexMemory**: Typically 20-25% of DataMemory
- **MaxNoOfConcurrentOperations**: Increase for high-throughput workloads
- **NoOfReplicas**: Keep at 2 for redundancy (changing requires cluster rebuild)

## MySQL Node Configuration

The MySQL configuration (`my.cnf`) configures the SQL nodes that provide the SQL interface to the cluster.

### Key Parameters

```ini
[mysqld]
ndbcluster                      # Enable NDB Cluster storage engine
default_storage_engine=ndbcluster  # Set NDB as default storage engine
ndb-connectstring=management1:1186  # Connection to management node

max_connections=1000           # Maximum client connections
table_open_cache=4000          # Table cache size
thread_cache_size=100          # Thread cache size
```

### Scaling Recommendations

- **max_connections**: Increase for more concurrent client connections
- **table_open_cache**: Increase if you have many tables
- **thread_cache_size**: Increase for better performance with many connections
- **innodb_buffer_pool_size**: Only relevant for InnoDB tables (not NDB)

## ProxySQL Configuration

The ProxySQL configuration (`proxysql-fixed-complete.cnf`) defines how queries are routed and connections are managed.

### Key Parameters

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

### Scaling Recommendations

- **max_connections**: Increase for more concurrent client connections
- **weight**: Adjust to balance load between nodes (higher weight = more connections)
- **mysql-max_connections**: Global maximum client connections
- **mysql-thread_pool_max_threads**: Maximum worker threads

## Docker Compose Configuration

The Docker Compose file (`docker-compose.yml`) defines the container setup and networking.

### Key Parameters

```yaml
services:
  management1:
    image: mysql/mysql-cluster:8.0.32
    command: ndb_mgmd --ndb-nodeid=1
    volumes:
      - ./config/management1-config:/etc/mysql-cluster
    healthcheck:
      test: ["CMD", "ndb_mgm", "-e", "show", "--ndb-connectstring=localhost:1186"]
      
  mysql1:
    image: mysql/mysql-cluster:8.0.32
    command: mysqld
    volumes:
      - ./config/mysql1:/etc/mysql
      - ./scripts:/docker-entrypoint-initdb.d
    environment:
      - MYSQL_ROOT_PASSWORD=rootpassword
```

### Scaling Recommendations

- **restart**: Set to `always` for production environments
- **mem_limit** and **cpu_limit**: Add for resource constraints
- **volumes**: Use named volumes for production data persistence

## Scaling the Cluster

### Adding More Data Nodes

1. Update the management node configuration:

```ini
[ndbd]
NodeId=8
hostname=ndb5

[ndbd]
NodeId=9
hostname=ndb6
```

2. Add the new nodes to `docker-compose.yml`:

```yaml
ndb5:
  image: mysql/mysql-cluster:8.0.32
  command: ndbd --ndb-nodeid=8 --ndb-connectstring=management1:1186
  volumes:
    - ./data/ndb5:/var/lib/mysql
  depends_on:
    - management1

ndb6:
  image: mysql/mysql-cluster:8.0.32
  command: ndbd --ndb-nodeid=9 --ndb-connectstring=management1:1186
  volumes:
    - ./data/ndb6:/var/lib/mysql
  depends_on:
    - management1
```

### Adding More SQL Nodes

1. Update the management node configuration:

```ini
[mysqld]
NodeId=10
hostname=mysql3

[mysqld]
NodeId=11
hostname=mysql4
```

2. Add the new nodes to `docker-compose.yml`:

```yaml
mysql3:
  image: mysql/mysql-cluster:8.0.32
  command: mysqld
  volumes:
    - ./config/mysql3:/etc/mysql
    - ./scripts:/docker-entrypoint-initdb.d
  environment:
    - MYSQL_ROOT_PASSWORD=rootpassword
  depends_on:
    - management1
    - ndb1
    - ndb2

mysql4:
  image: mysql/mysql-cluster:8.0.32
  command: mysqld
  volumes:
    - ./config/mysql4:/etc/mysql
    - ./scripts:/docker-entrypoint-initdb.d
  environment:
    - MYSQL_ROOT_PASSWORD=rootpassword
  depends_on:
    - management1
    - ndb1
    - ndb2
```

3. Update ProxySQL configuration to include the new SQL nodes:

```ini
mysql_servers:
(
    { address="mysql1" , port=3306 , hostgroup=0, max_connections=2000 },
    { address="mysql2" , port=3306 , hostgroup=0, max_connections=2000 },
    { address="mysql3" , port=3306 , hostgroup=0, max_connections=2000 },
    { address="mysql4" , port=3306 , hostgroup=0, max_connections=2000 },
    { address="mysql1" , port=3306 , hostgroup=10, max_connections=2000 },
    { address="mysql2" , port=3306 , hostgroup=10, max_connections=2000 },
    { address="mysql3" , port=3306 , hostgroup=10, max_connections=2000 },
    { address="mysql4" , port=3306 , hostgroup=10, max_connections=2000 }
)
```

## Performance Tuning

### Memory Configuration

For optimal performance, allocate memory according to these guidelines:

1. **Data Nodes**:
   - DataMemory: 70-80% of available RAM
   - IndexMemory: 20-25% of DataMemory

2. **SQL Nodes**:
   - innodb_buffer_pool_size: Not critical for NDB tables
   - table_open_cache: 2000-4000 for most workloads

3. **ProxySQL**:
   - mysql-max_connections: 2-3x the sum of expected client connections
   - mysql-thread_pool_max_threads: Number of CPU cores * 4

### Connection Pooling

ProxySQL provides connection pooling to efficiently manage database connections:

```ini
mysql-connection_pool_size=100
mysql-free_connections_pct=10
mysql-thread_pool_max_threads=64
```

- **connection_pool_size**: Number of connections to pre-establish with backend servers
- **free_connections_pct**: Percentage of connections to keep free
- **thread_pool_max_threads**: Maximum number of worker threads

### Query Routing Optimization

Fine-tune query routing for better performance:

```ini
mysql_query_rules:
(
    # Route SELECT queries for specific tables to dedicated nodes
    { rule_id=1, active=1, match_digest="^SELECT.+FROM.+large_table.*", destination_hostgroup=11, apply=1 },
    
    # Route all other SELECTs to read hostgroup
    { rule_id=2, active=1, match_digest="^SELECT.*", destination_hostgroup=10, apply=1 },
    
    # Route all writes to write hostgroup
    { rule_id=3, active=1, match_digest=".*", destination_hostgroup=0, apply=1 }
)
```

## Security Configuration

### Encryption

To enable encrypted connections:

1. Add SSL configuration to MySQL nodes:

```ini
[mysqld]
ssl-ca=/etc/mysql/certs/ca.pem
ssl-cert=/etc/mysql/certs/server-cert.pem
ssl-key=/etc/mysql/certs/server-key.pem
require_secure_transport=ON
```

2. Add SSL configuration to ProxySQL:

```ini
mysql_variables:
{
    ssl_p2s_cert="/etc/proxysql/ssl/proxysql-cert.pem"
    ssl_p2s_key="/etc/proxysql/ssl/proxysql-key.pem"
    ssl_p2s_ca="/etc/proxysql/ssl/ca.pem"
}
```

### Network Security

1. Isolate the cluster network:

```yaml
networks:
  ndb-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

2. Expose only necessary ports:

```yaml
services:
  proxysql:
    ports:
      - "6033:6033"  # MySQL protocol
      - "6032:6032"  # Admin interface
```

## Configuration Validation

After making configuration changes, validate them:

1. Check MySQL configuration:
```bash
docker exec -it mysql1 mysqld --validate-config
```

2. Check ProxySQL configuration:
```bash
docker exec -it proxysql cat /etc/proxysql.cnf | grep -v "#" | grep -v "^$"
```

3. Run the test suite:
```bash
./mysql_cluster_test_suite.sh all
```

## Applying Configuration Changes

Different components require different approaches to apply configuration changes:

1. **Management Node Configuration**:
   - Requires a full cluster restart:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

2. **MySQL Configuration**:
   - Some parameters can be changed dynamically:
   ```bash
   docker exec -it mysql1 mysql -uroot -prootpassword -e "SET GLOBAL max_connections=1000"
   ```
   - Others require a restart:
   ```bash
   docker-compose restart mysql1 mysql2
   ```

3. **ProxySQL Configuration**:
   - Most changes can be applied dynamically:
   ```bash
   docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "LOAD MYSQL VARIABLES TO RUNTIME; SAVE MYSQL VARIABLES TO DISK"
   ```
