# Security Overview

[← Documentation Index](../index.md) | [Authentication →](authentication.md)

*Related: [Encryption](encryption.md) | [User Management](../operations/user-management.md)*

This document provides an overview of security considerations and best practices for your MySQL Cluster with ProxySQL deployment.

## Security Architecture

The MySQL Cluster with ProxySQL architecture includes several security layers:

1. **Network Isolation**: Components communicate over a dedicated Docker network
2. **Authentication**: User authentication at both MySQL and ProxySQL layers
3. **Authorization**: Role-based access control with read-only and read-write users
4. **Encryption**: Optional TLS/SSL encryption for data in transit
5. **Audit**: Logging and monitoring of access and operations

## Network Security

### Docker Network Isolation

The cluster uses a dedicated Docker network (`ndb-net`) with fixed IP addresses for all components. This provides network isolation from other Docker containers and the host network.

### Port Exposure

Only necessary ports are exposed to the host:
- ProxySQL MySQL Protocol (6033): For client connections
- ProxySQL Admin Interface (6032): For administration
- MySQL Direct Access (3306, 3307): For direct access to MySQL nodes (can be restricted in production)
- Management Node (1186): For cluster management (can be restricted in production)

### Firewall Recommendations

In production environments, configure a firewall to restrict access:

```bash
# Allow ProxySQL client connections only from trusted networks
sudo ufw allow from 192.168.1.0/24 to any port 6033

# Allow ProxySQL admin connections only from admin workstations
sudo ufw allow from 192.168.1.10 to any port 6032

# Restrict direct MySQL access
sudo ufw deny 3306
sudo ufw deny 3307

# Restrict management node access
sudo ufw deny 1186
```

## Authentication

### MySQL Authentication

MySQL nodes use native password authentication for user accounts. Default users include:
- `root`: Administrative access
- `readwrite`: Read/write access
- `readonly`: Read-only access

### ProxySQL Authentication

ProxySQL authenticates users against its own user table, which should be synchronized with MySQL users. The admin interface uses separate credentials:
- Default admin user: `radmin`
- Default admin password: `radmin`

## Authorization

### MySQL Authorization

Users are granted specific privileges based on their role:
- Read-only users: `SELECT` privileges only
- Read-write users: `SELECT`, `INSERT`, `UPDATE`, `DELETE` privileges
- Admin users: All privileges

### ProxySQL Authorization

ProxySQL routes queries based on user and query type:
- Read-only users are directed to the read hostgroup (10)
- Read-write users are directed to the write hostgroup (0) for write operations and read hostgroup (10) for read operations

## Encryption

### Transport Encryption

MySQL supports TLS/SSL encryption for client connections. To enable:

1. Generate SSL certificates:
   ```bash
   mkdir -p config/ssl
   cd config/ssl
   openssl genrsa 2048 > ca-key.pem
   openssl req -new -x509 -nodes -days 3600 -key ca-key.pem -out ca-cert.pem
   openssl req -newkey rsa:2048 -days 3600 -nodes -keyout server-key.pem -out server-req.pem
   openssl rsa -in server-key.pem -out server-key.pem
   openssl x509 -req -in server-req.pem -days 3600 -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out server-cert.pem
   ```

2. Update MySQL configuration:
   ```ini
   [mysqld]
   ssl-ca=/etc/mysql/ssl/ca-cert.pem
   ssl-cert=/etc/mysql/ssl/server-cert.pem
   ssl-key=/etc/mysql/ssl/server-key.pem
   require_secure_transport=ON
   ```

3. Update ProxySQL configuration:
   ```ini
   mysql_servers:
   (
       { address="mysql1", port=3306, hostgroup=0, use_ssl=1 },
       { address="mysql2", port=3306, hostgroup=0, use_ssl=1 }
   )
   ```

### Data at Rest Encryption

MySQL supports tablespace encryption for data at rest. To enable:

1. Generate encryption key:
   ```bash
   openssl rand -hex 32 > config/mysql1/keyring
   openssl rand -hex 32 > config/mysql2/keyring
   ```

2. Update MySQL configuration:
   ```ini
   [mysqld]
   early-plugin-load=keyring_file.so
   keyring_file_data=/var/lib/mysql/keyring
   ```

3. Create encrypted tables:
   ```sql
   CREATE TABLE encrypted_table (
     id INT PRIMARY KEY,
     data VARCHAR(100)
   ) ENGINE=NDBCLUSTER ENCRYPTION='Y';
   ```

## Audit and Logging

### MySQL Audit

Enable MySQL audit plugin to log all access and operations:

```ini
[mysqld]
plugin-load-add=audit_log.so
audit_log_file=/var/log/mysql/audit.log
audit_log_format=JSON
audit_log_policy=ALL
```

### ProxySQL Logging

Enable detailed logging in ProxySQL:

```ini
mysql_variables:
(
    { variable="log_mysql_query_with_processed_query", value="ON" },
    { variable="log_mysql_connections", value="ON" },
    { variable="log_mysql_connection_pool", value="ON" }
)
```

## Security Best Practices

### Password Management

1. Use strong, unique passwords for all accounts
2. Rotate passwords regularly
3. Use environment variables instead of hardcoded passwords
4. Consider using a secret management solution for production

### Regular Updates

1. Keep Docker images updated with the latest security patches
2. Update MySQL and ProxySQL to the latest stable versions
3. Apply security patches promptly

### Principle of Least Privilege

1. Grant only necessary privileges to each user
2. Use read-only users for reporting and analytics
3. Restrict administrative access to authorized personnel

### Security Monitoring

1. Monitor login attempts and failures
2. Set up alerts for suspicious activities
3. Regularly review audit logs
4. Implement intrusion detection systems

### Regular Security Audits

1. Conduct regular security audits
2. Test for vulnerabilities
3. Perform penetration testing
4. Review and update security policies

## Security Checklist

- [ ] Change default passwords for all accounts
- [ ] Restrict network access to necessary ports only
- [ ] Enable TLS/SSL encryption for client connections
- [ ] Configure proper user privileges
- [ ] Set up audit logging
- [ ] Implement regular backup procedures
- [ ] Configure monitoring and alerting
- [ ] Document security procedures and incident response plans

## Related Documentation

- [Authentication](authentication.md) - Detailed authentication configuration
- [Encryption](encryption.md) - Encryption configuration
- [User Management](../operations/user-management.md) - User management procedures
- [Monitoring](../operations/monitoring.md) - Monitoring your cluster
