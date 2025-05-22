# Configuration Overview

[← Architecture Overview](../architecture/overview.md) | [Documentation Index](../index.md) | [MySQL Nodes Configuration →](mysql-nodes.md)

*Related: [Data Nodes Configuration](data-nodes.md) | [ProxySQL Configuration](proxysql.md)*

This guide explains the configuration principles and best practices for the MySQL Cluster with ProxySQL.

## Configuration Files Overview

The MySQL Cluster configuration is spread across multiple files:

| Component | Configuration File | Purpose |
|-----------|-------------------|---------|
| Management Node | `config/management-config.ini` | NDB Cluster configuration |
| MySQL Node 1 | `config/mysql1/my.cnf` | MySQL server configuration |
| MySQL Node 2 | `config/mysql2/my.cnf` | MySQL server configuration |
| ProxySQL | `config/proxysql-config.cnf` | ProxySQL configuration |
| Docker Compose | `docker-compose.yml` | Container orchestration |

## Configuration Principles

### 1. High Availability

All components are configured for high availability:
- Redundant management nodes
- Multiple data nodes organized in node groups
- Multiple SQL nodes
- Multiple ProxySQL instances

### 2. Performance Optimization

Configuration parameters are tuned for optimal performance:
- Memory allocation for data and indexes
- Connection pooling
- Query routing
- Thread configuration

### 3. Scalability

The configuration allows for horizontal and vertical scaling:
- Adding more data nodes
- Adding more SQL nodes
- Increasing memory allocation
- Adjusting connection limits

### 4. Security

Security is implemented through:
- Network isolation
- User authentication and authorization
- Encrypted connections (optional)
- Principle of least privilege

## Configuration Workflow

1. **Basic Setup**: Start with the default configuration
2. **Testing**: Run the test suite to verify functionality
3. **Customization**: Adjust parameters based on your workload
4. **Validation**: Rerun tests to ensure everything works
5. **Monitoring**: Set up monitoring to track performance
6. **Tuning**: Fine-tune based on monitoring data

## Environment Variables

The configuration can be customized through environment variables:

```bash
# Example: Set MySQL root password
export MYSQL_ROOT_PASSWORD=your_secure_password

# Example: Set ProxySQL admin credentials
export PROXYSQL_ADMIN_USER=admin
export PROXYSQL_ADMIN_PASSWORD=admin_password

# Example: Set read/write user credentials
export READWRITE_USER=readwrite
export READWRITE_PASSWORD=readwrite_password

# Example: Set read-only user credentials
export READONLY_USER=readonly
export READONLY_PASSWORD=readonly_password
```

## Configuration Best Practices

### Management Node Configuration

- Use at least 2 management nodes for redundancy
- Configure arbitration to prevent split-brain scenarios
- Set appropriate timeouts for node failure detection

### Data Node Configuration

- Allocate sufficient memory for DataMemory and IndexMemory
- Configure disk data tablespaces for large datasets
- Set appropriate backup parameters
- Configure transaction parameters based on workload

### SQL Node Configuration

- Set appropriate connection limits
- Configure thread pools for optimal performance
- Enable query caching for read-heavy workloads
- Configure logging appropriately

### ProxySQL Configuration

- Set up read/write splitting rules
- Configure connection pooling
- Set up health checks for backend servers
- Configure query routing based on workload

## Configuration Examples

See the following pages for detailed configuration examples:

- [MySQL Nodes Configuration](mysql-nodes.md)
- [Data Nodes Configuration](data-nodes.md)
- [Management Nodes Configuration](management-nodes.md)
- [ProxySQL Configuration](proxysql.md)

## Configuration Validation

To validate your configuration:

```bash
# Validate MySQL configuration
docker exec mysql1 mysqld --validate-config

# Check NDB cluster configuration
docker exec management1 ndb_mgm -e "show" --ndb-connectstring=management1:1186

# Check ProxySQL configuration
docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "SELECT * FROM mysql_servers"
```

## Related Documentation

- [Architecture Overview](../architecture/overview.md)
- [Installation Guide](../getting-started/installation.md)
- [Production Readiness](../getting-started/production-ready.md)
- [Performance Tuning](../operations/performance-tuning.md)
