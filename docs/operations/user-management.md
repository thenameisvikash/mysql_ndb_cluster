# User Management

[← Backup and Recovery](backup-recovery.md) | [Documentation Index](../index.md) | [Scaling Operations →](scaling.md)

*Related: [Security Overview](../security/overview.md) | [Authentication](../security/authentication.md)*

This guide provides comprehensive instructions for managing users in your MySQL Cluster with ProxySQL deployment.

## User Management Overview

User management in a MySQL Cluster with ProxySQL environment involves:

1. **MySQL User Management**: Creating and managing users on MySQL nodes
2. **ProxySQL User Management**: Synchronizing users with ProxySQL
3. **Access Control**: Setting appropriate permissions
4. **User Synchronization**: Ensuring consistency across all nodes

## User Types

The system uses different user types for different purposes:

1. **Administrative Users**: Full access to the database (e.g., `root`)
2. **Read-Write Users**: Can read and write data (e.g., `readwrite`)
3. **Read-Only Users**: Can only read data (e.g., `readonly`)
4. **Monitoring Users**: Limited access for monitoring purposes (e.g., `monitor`)
5. **Application-Specific Users**: Tailored access for specific applications

## User Management Script

The project includes a user management script (`scripts/user_management.sh`) that simplifies user management across all nodes:

```bash
# View script usage
./scripts/user_management.sh help

# Create a read-only user
./scripts/user_management.sh create username password

# Create a read-write user
./scripts/user_management.sh -w create username password

# Delete a user
./scripts/user_management.sh delete username

# List all users
./scripts/user_management.sh list
```

## Manual User Management

### Creating Users in MySQL

To manually create users in MySQL:

```bash
# Connect to MySQL
docker exec -it mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD}

# Create a read-only user
CREATE USER 'readonly_user'@'%' IDENTIFIED WITH mysql_native_password BY 'password';
GRANT SELECT ON *.* TO 'readonly_user'@'%';
FLUSH PRIVILEGES;

# Create a read-write user
CREATE USER 'readwrite_user'@'%' IDENTIFIED WITH mysql_native_password BY 'password';
GRANT SELECT, INSERT, UPDATE, DELETE ON *.* TO 'readwrite_user'@'%';
FLUSH PRIVILEGES;
```

### Adding Users to ProxySQL

To manually add users to ProxySQL:

```bash
# Connect to ProxySQL admin interface
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD}

# Add a read-only user
INSERT INTO mysql_users(username, password, default_hostgroup, active) 
VALUES ('readonly_user', 'password', 10, 1);
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;

# Add a read-write user
INSERT INTO mysql_users(username, password, default_hostgroup, active) 
VALUES ('readwrite_user', 'password', 0, 1);
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;
```

## User Synchronization

To ensure users are synchronized across all MySQL nodes:

```bash
# Create user on mysql1
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "
CREATE USER 'new_user'@'%' IDENTIFIED WITH mysql_native_password BY 'password';
GRANT SELECT ON *.* TO 'new_user'@'%';
FLUSH PRIVILEGES;"

# Verify user on mysql2
docker exec mysql2 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SELECT User, Host FROM mysql.user WHERE User='new_user'"
```

## Password Management

### Changing Passwords

To change a user's password:

```bash
# Change password in MySQL
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "
ALTER USER 'username'@'%' IDENTIFIED WITH mysql_native_password BY 'new_password';
FLUSH PRIVILEGES;"

# Update password in ProxySQL
docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "
UPDATE mysql_users SET password='new_password' WHERE username='username';
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;"
```

### Password Rotation

For security, rotate passwords regularly:

```bash
#!/bin/bash
# password-rotation.sh

# Generate a random password
NEW_PASSWORD=$(openssl rand -base64 12)

# Update password in MySQL
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "
ALTER USER 'username'@'%' IDENTIFIED WITH mysql_native_password BY '$NEW_PASSWORD';
FLUSH PRIVILEGES;"

# Update password in ProxySQL
docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "
UPDATE mysql_users SET password='$NEW_PASSWORD' WHERE username='username';
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;"

# Store the new password securely
echo "Username: username, New Password: $NEW_PASSWORD" | gpg -e -r admin@example.com > /secure/path/passwords.gpg
```

## Access Control

### Granting Permissions

To grant specific permissions to a user:

```bash
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "
GRANT SELECT, INSERT ON database_name.* TO 'username'@'%';
FLUSH PRIVILEGES;"
```

### Revoking Permissions

To revoke permissions from a user:

```bash
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "
REVOKE INSERT ON database_name.* FROM 'username'@'%';
FLUSH PRIVILEGES;"
```

### Viewing User Permissions

To view a user's permissions:

```bash
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW GRANTS FOR 'username'@'%'"
```

## Database-Specific Users

For better security, create database-specific users:

```bash
# Create a user with access to a specific database
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "
CREATE USER 'app_user'@'%' IDENTIFIED WITH mysql_native_password BY 'password';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_database.* TO 'app_user'@'%';
FLUSH PRIVILEGES;"

# Add the user to ProxySQL
docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "
INSERT INTO mysql_users(username, password, default_hostgroup, active) 
VALUES ('app_user', 'password', 0, 1);
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;"
```

## Monitoring User

Create a dedicated user for monitoring:

```bash
# Create monitoring user in MySQL
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "
CREATE USER 'monitor'@'%' IDENTIFIED WITH mysql_native_password BY 'monitor_password';
GRANT USAGE, REPLICATION CLIENT ON *.* TO 'monitor'@'%';
GRANT SELECT ON performance_schema.* TO 'monitor'@'%';
FLUSH PRIVILEGES;"

# Add monitoring user to ProxySQL
docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "
INSERT INTO mysql_users(username, password, default_hostgroup, active) 
VALUES ('monitor', 'monitor_password', 0, 1);
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;"
```

## ProxySQL Query Rules

Configure ProxySQL query rules to route queries based on user and query type:

```bash
# Connect to ProxySQL admin interface
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD}

# Add a rule to route all queries from readonly users to the read hostgroup
INSERT INTO mysql_query_rules(rule_id, active, username, destination_hostgroup, apply) 
VALUES (100, 1, 'readonly_user', 10, 1);

# Add rules for readwrite users
INSERT INTO mysql_query_rules(rule_id, active, username, match_digest, destination_hostgroup, apply) 
VALUES (200, 1, 'readwrite_user', '^SELECT', 10, 1);
INSERT INTO mysql_query_rules(rule_id, active, username, destination_hostgroup, apply) 
VALUES (201, 1, 'readwrite_user', 0, 1);

# Apply the changes
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
```

## User Audit

Enable auditing to track user activity:

```bash
# Edit MySQL configuration
docker exec -it mysql1 bash -c "cat >> /etc/mysql/my.cnf << EOF
[mysqld]
plugin-load-add=audit_log.so
audit_log_file=/var/log/mysql/audit.log
audit_log_format=JSON
audit_log_policy=ALL
EOF"

# Restart MySQL
docker-compose restart mysql1 mysql2
```

To view audit logs:

```bash
docker exec mysql1 tail -f /var/log/mysql/audit.log
```

## Troubleshooting

### User Cannot Connect

If a user cannot connect:

1. Check if the user exists in MySQL:
   ```bash
   docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SELECT User, Host FROM mysql.user WHERE User='username'"
   ```

2. Check if the user exists in ProxySQL:
   ```bash
   docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "SELECT username, active FROM mysql_users WHERE username='username'"
   ```

3. Check if the password is correct:
   ```bash
   # Test connection directly to MySQL
   docker exec -it mysql1 mysql -uusername -ppassword -e "SELECT 1"
   
   # Test connection through ProxySQL
   mysql -h127.0.0.1 -P6033 -uusername -ppassword -e "SELECT 1"
   ```

4. Check if the user is active in ProxySQL:
   ```bash
   docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "
   UPDATE mysql_users SET active=1 WHERE username='username';
   LOAD MYSQL USERS TO RUNTIME;
   SAVE MYSQL USERS TO DISK;"
   ```

### Permission Issues

If a user has permission issues:

1. Check the user's grants:
   ```bash
   docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW GRANTS FOR 'username'@'%'"
   ```

2. Check ProxySQL routing:
   ```bash
   docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "
   SELECT * FROM mysql_query_rules WHERE username='username'"
   ```

3. Check which hostgroup the user is connecting to:
   ```bash
   docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "
   SELECT * FROM stats_mysql_connection_pool"
   ```

## Best Practices

1. **Use Strong Passwords**: Generate strong, random passwords
2. **Principle of Least Privilege**: Grant only necessary permissions
3. **Regular Audits**: Regularly audit user accounts and permissions
4. **Password Rotation**: Rotate passwords regularly
5. **Dedicated Users**: Create dedicated users for different applications
6. **Monitoring**: Monitor user activity and failed login attempts
7. **Documentation**: Document all user accounts and their purposes

## Related Documentation

- [Security Overview](../security/overview.md) - Security principles and best practices
- [Authentication](../security/authentication.md) - Authentication configuration
- [Backup and Recovery](backup-recovery.md) - Backup and recovery procedures
- [Scaling Operations](scaling.md) - Scaling your cluster
