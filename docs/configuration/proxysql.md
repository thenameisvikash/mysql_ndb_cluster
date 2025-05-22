# ProxySQL Configuration

[← MySQL Nodes Configuration](mysql-nodes.md) | [Documentation Index](../index.md) | [Arbitration Configuration →](arbitration.md)

*Related: [Configuration Overview](overview.md) | [Troubleshooting ProxySQL Issues](../troubleshooting/proxysql-issues.md)*

This guide provides detailed instructions for configuring ProxySQL in your MySQL Cluster deployment.

## ProxySQL Overview

ProxySQL is a high-performance SQL proxy that sits between your application and MySQL servers. It provides:

- **Connection Pooling**: Efficiently manages database connections
- **Query Routing**: Routes queries to appropriate backend servers
- **Read/Write Splitting**: Directs read and write queries to different server groups
- **Load Balancing**: Distributes queries across multiple servers
- **High Availability**: Automatic failover to healthy servers
- **Query Caching**: Optional caching of query results
- **Query Rewriting**: Ability to rewrite queries on-the-fly

## Configuration File Structure

The ProxySQL configuration file (`proxysql.cnf`) is organized into several sections:

```ini
# Global variables
datadir="/var/lib/proxysql"

# Admin interface settings
admin_variables=
{
  admin_credentials="admin:admin"
  mysql_ifaces="0.0.0.0:6032"
}

# MySQL server settings
mysql_variables=
{
  threads=4
  max_connections=2048
  default_query_delay=0
  default_query_timeout=36000000
  have_compress=true
  poll_timeout=2000
  interfaces="0.0.0.0:6033"
  default_schema="information_schema"
  stacksize=1048576
  server_version="8.0.32"
  connect_timeout_server=3000
  monitor_username="monitor"
  monitor_password="monitor"
  monitor_history=600000
  monitor_connect_interval=60000
  monitor_ping_interval=10000
  monitor_read_only_interval=1500
  monitor_read_only_timeout=500
  ping_interval_server_msec=120000
  ping_timeout_server=500
  commands_stats=true
  sessions_sort=true
  connect_retries_on_failure=10
}

# MySQL servers
mysql_servers=
(
  { address="mysql1", port=3306, hostgroup=0, max_connections=100, max_replication_lag=10, weight=1000 },
  { address="mysql2", port=3306, hostgroup=0, max_connections=100, max_replication_lag=10, weight=1000 },
  { address="mysql1", port=3306, hostgroup=10, max_connections=100, max_replication_lag=10, weight=1000 },
  { address="mysql2", port=3306, hostgroup=10, max_connections=100, max_replication_lag=10, weight=1000 }
)

# MySQL users
mysql_users=
(
  { username="root", password="rootpassword", default_hostgroup=0, active=1 },
  { username="readwrite", password="readwritepass", default_hostgroup=0, active=1 },
  { username="readonly", password="readonlypass", default_hostgroup=10, active=1 }
)

# MySQL query rules
mysql_query_rules=
(
  { rule_id=1, active=1, match_digest="^SELECT", destination_hostgroup=10, apply=1 },
  { rule_id=2, active=1, match_digest=".*", destination_hostgroup=0, apply=1 }
)
```

## Configuration Sections

### Admin Variables

The `admin_variables` section configures the ProxySQL admin interface:

```ini
admin_variables=
{
  admin_credentials="admin:admin"       # Username:password for admin interface
  mysql_ifaces="0.0.0.0:6032"           # Admin interface binding
  refresh_interval=2000                 # Refresh interval in milliseconds
  web_enabled=false                     # Whether to enable the web interface
  web_port=6080                         # Web interface port
}
```

### MySQL Variables

The `mysql_variables` section configures global MySQL settings:

```ini
mysql_variables=
{
  threads=4                             # Number of worker threads
  max_connections=2048                  # Maximum client connections
  default_query_delay=0                 # Delay in milliseconds for each query
  default_query_timeout=36000000        # Query timeout in milliseconds
  have_compress=true                    # Enable compression
  poll_timeout=2000                     # Poll timeout in milliseconds
  interfaces="0.0.0.0:6033"             # MySQL interface binding
  default_schema="information_schema"   # Default schema
  stacksize=1048576                     # Stack size for threads
  server_version="8.0.32"               # MySQL server version to report
  connect_timeout_server=3000           # Connection timeout for backend servers
  monitor_username="monitor"            # Username for monitoring
  monitor_password="monitor"            # Password for monitoring
  monitor_history=600000                # Monitor history in milliseconds
  monitor_connect_interval=60000        # Connection check interval
  monitor_ping_interval=10000           # Ping interval
  monitor_read_only_interval=1500       # Read-only check interval
  monitor_read_only_timeout=500         # Read-only check timeout
  ping_interval_server_msec=120000      # Ping interval for servers
  ping_timeout_server=500               # Ping timeout for servers
  commands_stats=true                   # Enable command statistics
  sessions_sort=true                    # Sort sessions
  connect_retries_on_failure=10         # Connection retries on failure
}
```

### MySQL Servers

The `mysql_servers` section defines the backend MySQL servers:

```ini
mysql_servers=
(
  {
    address="mysql1",                   # Server hostname or IP
    port=3306,                          # Server port
    hostgroup=0,                        # Hostgroup ID (0 for write)
    max_connections=100,                # Maximum connections to this server
    max_replication_lag=10,             # Maximum replication lag in seconds
    weight=1000,                        # Server weight for load balancing
    use_ssl=0                           # Whether to use SSL for connections
  },
  {
    address="mysql2",                   # Server hostname or IP
    port=3306,                          # Server port
    hostgroup=0,                        # Hostgroup ID (0 for write)
    max_connections=100,                # Maximum connections to this server
    max_replication_lag=10,             # Maximum replication lag in seconds
    weight=1000,                        # Server weight for load balancing
    use_ssl=0                           # Whether to use SSL for connections
  },
  {
    address="mysql1",                   # Server hostname or IP
    port=3306,                          # Server port
    hostgroup=10,                       # Hostgroup ID (10 for read)
    max_connections=100,                # Maximum connections to this server
    max_replication_lag=10,             # Maximum replication lag in seconds
    weight=1000,                        # Server weight for load balancing
    use_ssl=0                           # Whether to use SSL for connections
  },
  {
    address="mysql2",                   # Server hostname or IP
    port=3306,                          # Server port
    hostgroup=10,                       # Hostgroup ID (10 for read)
    max_connections=100,                # Maximum connections to this server
    max_replication_lag=10,             # Maximum replication lag in seconds
    weight=1000,                        # Server weight for load balancing
    use_ssl=0                           # Whether to use SSL for connections
  }
)
```

### MySQL Users

The `mysql_users` section defines the users that can connect to ProxySQL:

```ini
mysql_users=
(
  {
    username="root",                    # Username
    password="rootpassword",            # Password
    default_hostgroup=0,                # Default hostgroup
    active=1,                           # Whether the user is active
    max_connections=1000,               # Maximum connections for this user
    default_schema="information_schema", # Default schema
    transaction_persistent=1,           # Whether transactions are persistent
    fast_forward=0                      # Whether to use fast forward
  },
  {
    username="readwrite",               # Username
    password="readwritepass",           # Password
    default_hostgroup=0,                # Default hostgroup
    active=1,                           # Whether the user is active
    max_connections=1000,               # Maximum connections for this user
    default_schema="information_schema", # Default schema
    transaction_persistent=1,           # Whether transactions are persistent
    fast_forward=0                      # Whether to use fast forward
  },
  {
    username="readonly",                # Username
    password="readonlypass",            # Password
    default_hostgroup=10,               # Default hostgroup
    active=1,                           # Whether the user is active
    max_connections=1000,               # Maximum connections for this user
    default_schema="information_schema", # Default schema
    transaction_persistent=1,           # Whether transactions are persistent
    fast_forward=0                      # Whether to use fast forward
  }
)
```

### MySQL Query Rules

The `mysql_query_rules` section defines rules for routing queries:

```ini
mysql_query_rules=
(
  {
    rule_id=1,                          # Rule ID
    active=1,                           # Whether the rule is active
    match_digest="^SELECT",             # Regex pattern to match query
    destination_hostgroup=10,           # Destination hostgroup
    apply=1                             # Whether to apply this rule and stop
  },
  {
    rule_id=2,                          # Rule ID
    active=1,                           # Whether the rule is active
    match_digest=".*",                  # Regex pattern to match query
    destination_hostgroup=0,            # Destination hostgroup
    apply=1                             # Whether to apply this rule and stop
  }
)
```

## Hostgroup Configuration

ProxySQL uses hostgroups to organize backend servers:

- **Hostgroup 0**: Write operations (default)
- **Hostgroup 10**: Read operations

You can define additional hostgroups for specialized purposes:

```ini
mysql_servers=
(
  # Write hostgroup
  { address="mysql1", port=3306, hostgroup=0, max_connections=100, weight=1000 },
  { address="mysql2", port=3306, hostgroup=0, max_connections=100, weight=1000 },
  
  # Read hostgroup
  { address="mysql1", port=3306, hostgroup=10, max_connections=100, weight=1000 },
  { address="mysql2", port=3306, hostgroup=10, max_connections=100, weight=1000 },
  
  # Reporting hostgroup (for long-running queries)
  { address="mysql1", port=3306, hostgroup=20, max_connections=50, weight=1000 },
  { address="mysql2", port=3306, hostgroup=20, max_connections=50, weight=1000 }
)
```

## Query Routing Rules

Query routing rules determine how queries are routed to hostgroups:

```ini
mysql_query_rules=
(
  # Route SELECT queries to read hostgroup
  { rule_id=1, active=1, match_digest="^SELECT", destination_hostgroup=10, apply=1 },
  
  # Route SELECT FOR UPDATE queries to write hostgroup
  { rule_id=2, active=1, match_digest="^SELECT .* FOR UPDATE", destination_hostgroup=0, apply=1 },
  
  # Route long-running reporting queries to reporting hostgroup
  { rule_id=3, active=1, match_digest="^SELECT .* FROM report_", destination_hostgroup=20, apply=1 },
  
  # Default rule: route all other queries to write hostgroup
  { rule_id=4, active=1, match_digest=".*", destination_hostgroup=0, apply=1 }
)
```

## Connection Pooling

ProxySQL provides connection pooling to efficiently manage connections to backend servers:

```ini
mysql_servers=
(
  {
    address="mysql1",
    port=3306,
    hostgroup=0,
    max_connections=100,               # Maximum connections to this server
    max_replication_lag=10,
    weight=1000,
    compression=0,
    max_latency_ms=0,
    use_ssl=0
  }
)
```

Adjust `max_connections` based on your workload and server capacity.

## Monitoring Configuration

ProxySQL includes a monitoring module that checks the health of backend servers:

```ini
mysql_variables=
{
  monitor_username="monitor"            # Username for monitoring
  monitor_password="monitor"            # Password for monitoring
  monitor_history=600000                # Monitor history in milliseconds
  monitor_connect_interval=60000        # Connection check interval
  monitor_ping_interval=10000           # Ping interval
  monitor_read_only_interval=1500       # Read-only check interval
  monitor_read_only_timeout=500         # Read-only check timeout
}
```

Create a monitoring user in MySQL:

```sql
CREATE USER 'monitor'@'%' IDENTIFIED WITH mysql_native_password BY 'monitor';
GRANT USAGE, REPLICATION CLIENT ON *.* TO 'monitor'@'%';
FLUSH PRIVILEGES;
```

## High Availability Configuration

For high availability, deploy multiple ProxySQL instances:

```ini
# In docker-compose.yml
services:
  proxysql:
    image: proxysql/proxysql:latest
    container_name: proxysql
    volumes:
      - ./config/proxysql-config.cnf:/etc/proxysql.cnf
    ports:
      - "6033:6033"
      - "6032:6032"
    networks:
      ndb-net:
        ipv4_address: 172.20.0.9
    restart: unless-stopped
    
  proxysql2:
    image: proxysql/proxysql:latest
    container_name: proxysql2
    volumes:
      - ./config/proxysql-config.cnf:/etc/proxysql.cnf
    ports:
      - "6034:6033"
      - "6035:6032"
    networks:
      ndb-net:
        ipv4_address: 172.20.0.10
    restart: unless-stopped
```

Use a load balancer or client-side logic to handle failover between ProxySQL instances.

## Query Caching

ProxySQL can cache query results for improved performance:

```ini
mysql_variables=
{
  query_cache_size_MB=256               # Query cache size in MB
}

# Enable query caching for specific queries
mysql_query_rules=
(
  {
    rule_id=1,
    active=1,
    match_digest="^SELECT .* FROM static_data",
    cache_ttl=3600000,                 # Cache TTL in milliseconds (1 hour)
    destination_hostgroup=10,
    apply=1
  }
)
```

## Admin Interface

The ProxySQL admin interface allows you to manage the configuration:

```bash
# Connect to the admin interface
mysql -h127.0.0.1 -P6032 -uradmin -pradmin

# View server configuration
SELECT * FROM mysql_servers;

# View user configuration
SELECT * FROM mysql_users;

# View query rules
SELECT * FROM mysql_query_rules;

# Apply changes
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;

LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;

LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
```

## Dynamic Configuration

ProxySQL configuration can be updated dynamically:

```sql
-- Add a new server
INSERT INTO mysql_servers(hostgroup_id, hostname, port) VALUES (0, 'mysql3', 3306);
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;

-- Add a new user
INSERT INTO mysql_users(username, password, default_hostgroup) VALUES ('newuser', 'newpass', 0);
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;

-- Add a new query rule
INSERT INTO mysql_query_rules(rule_id, active, match_digest, destination_hostgroup, apply) 
VALUES (10, 1, '^SELECT .* FROM new_table', 10, 1);
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
```

## Monitoring and Statistics

ProxySQL provides several tables for monitoring and statistics:

```sql
-- Connection pool statistics
SELECT * FROM stats_mysql_connection_pool;

-- Query digest (most frequent queries)
SELECT * FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10;

-- Command statistics
SELECT * FROM stats_mysql_commands_counters;

-- Global statistics
SELECT * FROM stats_mysql_global;
```

## Troubleshooting

### Common Issues

1. **Connection Errors**:
   - Check if ProxySQL is running
   - Verify user credentials
   - Check network connectivity

2. **Routing Issues**:
   - Verify query rules
   - Check server status
   - Check user default hostgroup

3. **Performance Issues**:
   - Adjust connection pool settings
   - Optimize query routing
   - Check backend server performance

### Diagnostic Queries

```sql
-- Check server status
SELECT * FROM mysql_servers;

-- Check server statistics
SELECT * FROM stats_mysql_connection_pool;

-- Check query routing
SELECT * FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10;

-- Check error logs
SELECT * FROM mysql_server_connect_log ORDER BY time_start_us DESC LIMIT 10;
SELECT * FROM mysql_server_ping_log ORDER BY time_start_us DESC LIMIT 10;
```

## Best Practices

1. **Connection Pooling**:
   - Set appropriate `max_connections` for each server
   - Monitor connection usage and adjust as needed

2. **Query Routing**:
   - Create specific rules for different query types
   - Use `match_digest` for pattern matching
   - Order rules from specific to general

3. **High Availability**:
   - Deploy multiple ProxySQL instances
   - Configure monitoring for health checks
   - Set appropriate timeouts and intervals

4. **Security**:
   - Use strong passwords
   - Restrict admin interface access
   - Consider using SSL for connections

5. **Performance**:
   - Enable query caching for appropriate queries
   - Monitor query patterns and adjust routing
   - Adjust thread count based on workload

## Related Documentation

- [Configuration Overview](overview.md) - Configuration principles and best practices
- [MySQL Nodes Configuration](mysql-nodes.md) - MySQL server configuration
- [Troubleshooting ProxySQL Issues](../troubleshooting/proxysql-issues.md) - Troubleshooting ProxySQL-specific issues
- [Security Overview](../security/overview.md) - Security principles and best practices
