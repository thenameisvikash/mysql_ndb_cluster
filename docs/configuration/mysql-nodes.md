# MySQL Nodes Configuration

[← Configuration Overview](overview.md) | [Documentation Index](../index.md) | [ProxySQL Configuration →](proxysql.md)

*Related: [Architecture Overview](../architecture/overview.md) | [Node Groups](../architecture/node-groups.md)*

This guide provides detailed instructions for configuring MySQL nodes in your MySQL Cluster deployment.

## MySQL Node Types

MySQL Cluster consists of several types of nodes:

1. **Management Nodes (ndb_mgmd)**: Manage the cluster configuration and operations
2. **Data Nodes (ndbd)**: Store and replicate data
3. **SQL Nodes (mysqld)**: Provide SQL interface to the cluster
4. **API Nodes**: Custom applications that access the cluster directly

This guide focuses on configuring SQL nodes (mysqld).

## Configuration File Structure

The MySQL configuration file (`my.cnf`) for SQL nodes is organized into several sections:

```ini
# Client section
[client]
port=3306
socket=/var/run/mysqld/mysqld.sock

# MySQL server section
[mysqld]
port=3306
socket=/var/run/mysqld/mysqld.sock
basedir=/usr
datadir=/var/lib/mysql
tmpdir=/tmp
user=mysql

# NDB Cluster section
ndbcluster
ndb-connectstring=management1:1186,management2:1186
default_storage_engine=ndbcluster

# InnoDB section
innodb_buffer_pool_size=128M
innodb_log_file_size=48M

# MyISAM section
key_buffer_size=32M

# Query cache
query_cache_size=0
query_cache_type=0

# Logging
log_error=/var/log/mysql/error.log
log_bin=/var/log/mysql/mysql-bin.log
binlog_format=ROW
```

## Essential Configuration Parameters

### Basic MySQL Configuration

```ini
[mysqld]
# Network settings
port=3306                          # Port to listen on
bind-address=0.0.0.0               # Listen on all interfaces
socket=/var/run/mysqld/mysqld.sock # Unix socket location

# Directory settings
basedir=/usr                       # Base directory
datadir=/var/lib/mysql             # Data directory
tmpdir=/tmp                        # Temporary directory
user=mysql                         # User to run as

# Character set and collation
character-set-server=utf8mb4       # Default character set
collation-server=utf8mb4_0900_ai_ci # Default collation

# Connection settings
max_connections=1000               # Maximum connections
max_connect_errors=10000           # Maximum connect errors
connect_timeout=10                 # Connection timeout in seconds
wait_timeout=28800                 # Wait timeout in seconds
interactive_timeout=28800          # Interactive timeout in seconds
```

### NDB Cluster Configuration

```ini
[mysqld]
# Enable NDB Cluster storage engine
ndbcluster                         # Enable NDB Cluster

# Management node connection
ndb-connectstring=management1:1186,management2:1186  # Management nodes

# Default storage engine
default_storage_engine=ndbcluster  # Use NDB as default

# NDB-specific settings
ndb_autoincrement_prefetch_sz=256  # Autoincrement prefetch size
ndb_force_send=1                   # Force send
ndb_use_exact_count=0              # Don't use exact count
ndb_use_transactions=1             # Use transactions
ndb_data_node_neighbour=3          # Preferred data node
```

### Storage Engine Configuration

```ini
[mysqld]
# InnoDB settings
innodb_buffer_pool_size=128M       # Buffer pool size
innodb_log_file_size=48M           # Log file size
innodb_flush_log_at_trx_commit=1   # Flush log at commit
innodb_file_per_table=1            # One file per table

# MyISAM settings
key_buffer_size=32M                # Key buffer size
myisam_sort_buffer_size=64M        # Sort buffer size
```

### Query Cache Configuration

```ini
[mysqld]
# Disable query cache (recommended for NDB Cluster)
query_cache_size=0                 # Query cache size
query_cache_type=0                 # Query cache type
```

### Logging Configuration

```ini
[mysqld]
# Error log
log_error=/var/log/mysql/error.log # Error log path

# Binary log
log_bin=/var/log/mysql/mysql-bin.log # Binary log path
binlog_format=ROW                  # Binary log format
expire_logs_days=7                 # Binary log expiration
max_binlog_size=100M               # Maximum binary log size

# General log
general_log=0                      # Disable general log
general_log_file=/var/log/mysql/mysql.log # General log path

# Slow query log
slow_query_log=1                   # Enable slow query log
slow_query_log_file=/var/log/mysql/mysql-slow.log # Slow query log path
long_query_time=2                  # Log queries longer than 2 seconds
```

## Advanced Configuration

### Performance Schema

```ini
[mysqld]
# Enable performance schema
performance_schema=ON              # Enable performance schema
performance_schema_max_table_instances=400 # Maximum table instances
performance_schema_max_table_handles=200   # Maximum table handles
performance_schema_max_file_instances=10000 # Maximum file instances
```

### Thread Pool

```ini
[mysqld]
# Thread pool settings
thread_handling=pool-of-threads    # Use thread pool
thread_pool_size=16                # Thread pool size
thread_pool_max_threads=1000       # Maximum threads
```

### Memory Usage

```ini
[mysqld]
# Memory settings
join_buffer_size=256K              # Join buffer size
sort_buffer_size=256K              # Sort buffer size
read_buffer_size=128K              # Read buffer size
read_rnd_buffer_size=256K          # Random read buffer size
tmp_table_size=16M                 # Temporary table size
max_heap_table_size=16M            # Maximum heap table size
```

### Table Configuration

```ini
[mysqld]
# Table settings
table_open_cache=2000              # Table open cache
table_definition_cache=1400        # Table definition cache
open_files_limit=5000              # Open files limit
```

## Multi-Node Configuration

For a multi-node MySQL Cluster, each SQL node should have a unique configuration:

### SQL Node 1

```ini
[mysqld]
# Basic settings
port=3306
socket=/var/run/mysqld/mysqld.sock
server_id=1                        # Unique server ID

# NDB Cluster settings
ndbcluster
ndb-connectstring=management1:1186,management2:1186
default_storage_engine=ndbcluster
ndb_data_node_neighbour=2          # Preferred data node
```

### SQL Node 2

```ini
[mysqld]
# Basic settings
port=3306
socket=/var/run/mysqld/mysqld.sock
server_id=2                        # Unique server ID

# NDB Cluster settings
ndbcluster
ndb-connectstring=management1:1186,management2:1186
default_storage_engine=ndbcluster
ndb_data_node_neighbour=3          # Preferred data node
```

## User Management

### Creating Users

Create users for different purposes:

```sql
-- Create admin user
CREATE USER 'admin'@'%' IDENTIFIED BY 'admin_password';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;

-- Create application user
CREATE USER 'app'@'%' IDENTIFIED BY 'app_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.* TO 'app'@'%';

-- Create read-only user
CREATE USER 'readonly'@'%' IDENTIFIED BY 'readonly_password';
GRANT SELECT ON myapp.* TO 'readonly'@'%';

-- Create monitoring user
CREATE USER 'monitor'@'%' IDENTIFIED BY 'monitor_password';
GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'monitor'@'%';

-- Apply changes
FLUSH PRIVILEGES;
```

### User Synchronization

When using ProxySQL, synchronize users across all SQL nodes:

```sql
-- On each SQL node, create the same users with the same privileges
CREATE USER 'app'@'%' IDENTIFIED BY 'app_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.* TO 'app'@'%';
FLUSH PRIVILEGES;
```

## Replication Configuration

MySQL Cluster automatically replicates data between data nodes. However, you can also set up asynchronous replication between clusters:

### Source Cluster

```ini
[mysqld]
# Binary log settings
log_bin=/var/log/mysql/mysql-bin.log
binlog_format=ROW
server_id=1                        # Unique server ID
```

### Replica Cluster

```ini
[mysqld]
# Replica settings
server_id=2                        # Unique server ID
relay_log=/var/log/mysql/mysql-relay-bin
log_slave_updates=1                # Log updates from the source
read_only=1                        # Read-only mode
```

Set up replication:

```sql
-- On replica
CHANGE MASTER TO
  MASTER_HOST='source_host',
  MASTER_USER='replication_user',
  MASTER_PASSWORD='replication_password',
  MASTER_LOG_FILE='mysql-bin.000001',
  MASTER_LOG_POS=4;
START SLAVE;
```

## Security Configuration

### Network Security

```ini
[mysqld]
# Network security
bind-address=0.0.0.0               # Listen on all interfaces
skip-name-resolve                  # Skip name resolution
max_connect_errors=10000           # Maximum connect errors
```

### Authentication

```ini
[mysqld]
# Authentication
default_authentication_plugin=mysql_native_password  # Default authentication
secure_auth=ON                     # Secure authentication
```

### SSL/TLS

```ini
[mysqld]
# SSL/TLS settings
ssl                                # Enable SSL
ssl_ca=/etc/mysql/ssl/ca.pem       # CA certificate
ssl_cert=/etc/mysql/ssl/server-cert.pem  # Server certificate
ssl_key=/etc/mysql/ssl/server-key.pem    # Server key
require_secure_transport=ON        # Require SSL/TLS
```

### File System Security

```ini
[mysqld]
# File system security
secure_file_priv=/var/lib/mysql-files  # Secure file directory
```

## Monitoring Configuration

### Status Variables

Enable status variables for monitoring:

```ini
[mysqld]
# Status variables
innodb_monitor_enable=all          # Enable InnoDB monitors
```

### Slow Query Log

Enable slow query log for performance monitoring:

```ini
[mysqld]
# Slow query log
slow_query_log=1                   # Enable slow query log
slow_query_log_file=/var/log/mysql/mysql-slow.log  # Slow query log path
long_query_time=2                  # Log queries longer than 2 seconds
log_queries_not_using_indexes=1    # Log queries not using indexes
```

### Performance Schema

Enable performance schema for detailed monitoring:

```ini
[mysqld]
# Performance schema
performance_schema=ON              # Enable performance schema
performance_schema_consumer_events_statements_history=ON  # Statement history
performance_schema_consumer_events_statements_history_long=ON  # Long statement history
```

## Troubleshooting

### Common Issues

1. **Connection Issues**:
   - Check network connectivity
   - Verify user credentials
   - Check `max_connections` limit
   - Verify `bind-address` setting

2. **Performance Issues**:
   - Check buffer sizes
   - Analyze slow queries
   - Verify index usage
   - Check memory usage

3. **Cluster Issues**:
   - Verify `ndb-connectstring`
   - Check management node status
   - Verify data node status
   - Check cluster logs

### Diagnostic Queries

```sql
-- Check server status
SHOW STATUS;

-- Check variables
SHOW VARIABLES;

-- Check process list
SHOW PROCESSLIST;

-- Check engine status
SHOW ENGINE NDB STATUS;

-- Check cluster status
SHOW ENGINE NDBCLUSTER STATUS;

-- Check open tables
SHOW OPEN TABLES;

-- Check warnings
SHOW WARNINGS;
```

## Best Practices

1. **Configuration Management**:
   - Use version control for configuration files
   - Document all configuration changes
   - Test configuration changes in a staging environment
   - Use configuration templates for consistency

2. **Performance Optimization**:
   - Optimize buffer sizes based on workload
   - Use appropriate storage engines
   - Optimize queries and indexes
   - Monitor and tune regularly

3. **Security**:
   - Use strong passwords
   - Implement least privilege principle
   - Enable SSL/TLS
   - Regularly update and patch

4. **Monitoring**:
   - Set up comprehensive monitoring
   - Monitor performance metrics
   - Monitor error logs
   - Set up alerts for critical issues

5. **Backup and Recovery**:
   - Regular backups
   - Test recovery procedures
   - Document backup and recovery processes
   - Implement point-in-time recovery

## Related Documentation

- [Configuration Overview](overview.md) - Configuration principles and best practices
- [ProxySQL Configuration](proxysql.md) - ProxySQL configuration
- [Architecture Overview](../architecture/overview.md) - Core architecture of MySQL Cluster
- [Node Groups](../architecture/node-groups.md) - Node group configuration
- [Backup and Recovery](../operations/backup-recovery.md) - Backup and recovery procedures
