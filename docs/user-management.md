# User Management Guide

[← Configuration](configuration.md) | [Documentation Index](../DOCUMENTATION.md) | [Testing Guide →](testing.md)

This guide explains how to manage users in the MySQL Cluster with ProxySQL setup.

## Understanding User Management in a Distributed Environment

In a MySQL Cluster with ProxySQL, user management involves two separate systems:

1. **MySQL Users**: Database users that need to be created on each MySQL node
2. **ProxySQL Users**: User entries in ProxySQL that route connections to the appropriate MySQL nodes

Our testing has confirmed that MySQL users created on one node are **not** automatically replicated to other nodes in the cluster. Similarly, ProxySQL instances maintain their own separate user lists.

To simplify this process, we've created a user management script that handles all the complexity for you.

## Using the User Management Script

The `user_management.sh` script provides a unified interface for managing users across all MySQL nodes and ProxySQL instances.

### Basic Usage

```bash
./scripts/user_management.sh [options] <command>
```

### Available Commands

- `create <username> <password> [permissions]`: Create a new user
- `delete <username>`: Delete an existing user
- `list`: List all users

### Options

- `-h, --hostgroup <id>`: Specify ProxySQL hostgroup (default: 10 - read-only)
- `-w, --write`: Set user for write access (hostgroup 0)
- `-r, --read`: Set user for read-only access (hostgroup 10)
- `-a, --admin`: Grant admin privileges (all permissions)
- `-d, --database <name>`: Specify database for permissions (default: all)
- `-t, --table <name>`: Specify table for permissions (default: all)
- `-p, --permissions <perms>`: Specify custom permissions (e.g., 'SELECT,INSERT')
- `--help`: Display help message

### Examples

#### Creating Users

```bash
# Create a read-only user (default)
./scripts/user_management.sh create readonly_user password123

# Create a read/write user
./scripts/user_management.sh -w create readwrite_user password123

# Create an admin user with all privileges
./scripts/user_management.sh -a create admin_user password123

# Create a user with custom permissions on a specific database
./scripts/user_management.sh -d test_db -p 'SELECT,INSERT' create custom_user password123
```

#### Deleting Users

```bash
./scripts/user_management.sh delete user_to_delete
```

#### Listing Users

```bash
./scripts/user_management.sh list
```

## Default User Accounts

The default deployment includes the following user accounts:

| Username | Password | Type | Description |
|----------|----------|------|-------------|
| `root` | `rootpassword` | Admin | Full administrative access |
| `readwrite` | `readwritepass` | Read/Write | For application write operations |
| `readonly` | `readonlypass` | Read-Only | For application read operations |
| `proxysql_monitor` | `monitorpass123` | System | Used by ProxySQL for monitoring |

## User Types and Permissions

### Read-Only Users (Hostgroup 10)

Read-only users are configured with:
- `SELECT`, `SHOW DATABASES`, `SHOW VIEW`, `PROCESS` permissions
- Routed to hostgroup 10 in ProxySQL
- Attempts to write data will be rejected with permission errors

### Read/Write Users (Hostgroup 0)

Read/write users are configured with:
- `ALL PRIVILEGES` (or a custom set of permissions that include write operations)
- Routed to hostgroup 0 in ProxySQL
- Can perform both read and write operations

### Admin Users

Admin users are configured with:
- `ALL PRIVILEGES WITH GRANT OPTION`
- Routed to hostgroup 0 in ProxySQL
- Can perform all database operations including user management

## Manual User Management (Advanced)

If you need to manually manage users, follow these steps:

### Creating a MySQL User on All Nodes

```bash
# Create user on mysql1
docker exec -it mysql1 mysql -uroot -prootpassword -e "
CREATE USER 'username'@'%' IDENTIFIED WITH mysql_native_password BY 'password';
GRANT SELECT ON *.* TO 'username'@'%';
FLUSH PRIVILEGES;"

# Create the same user on mysql2
docker exec -it mysql2 mysql -uroot -prootpassword -e "
CREATE USER 'username'@'%' IDENTIFIED WITH mysql_native_password BY 'password';
GRANT SELECT ON *.* TO 'username'@'%';
FLUSH PRIVILEGES;"
```

### Adding a User to ProxySQL

```bash
# Add user to proxysql
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "
INSERT INTO mysql_users(username, password, default_hostgroup, active)
VALUES ('username', 'password', 10, 1);
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;"

# Add the same user to proxysql2
docker exec -it proxysql2 mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "
INSERT INTO mysql_users(username, password, default_hostgroup, active)
VALUES ('username', 'password', 10, 1);
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;"
```

## Security Best Practices

1. **Use Strong Passwords**: Always use strong, unique passwords for each user
2. **Principle of Least Privilege**: Grant only the permissions needed for each user's role
3. **Regular Audits**: Periodically review user accounts and remove unused ones
4. **Separate Users for Applications**: Create separate users for different applications or services
5. **Avoid Using Root**: The root user should only be used for administrative tasks, not for application connections

## Troubleshooting

### User Can Connect to MySQL But Not Through ProxySQL

1. Verify the user exists in ProxySQL:
   ```bash
   docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT * FROM mysql_users WHERE username='problematic_user'"
   ```

2. Check if the user is active:
   ```bash
   docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "UPDATE mysql_users SET active=1 WHERE username='problematic_user'; LOAD MYSQL USERS TO RUNTIME; SAVE MYSQL USERS TO DISK"
   ```

### Permission Denied Errors

1. Verify the user has the correct permissions on both MySQL nodes:
   ```bash
   docker exec -it mysql1 mysql -uroot -prootpassword -e "SHOW GRANTS FOR 'problematic_user'@'%'"
   docker exec -it mysql2 mysql -uroot -prootpassword -e "SHOW GRANTS FOR 'problematic_user'@'%'"
   ```

2. Update permissions if needed:
   ```bash
   docker exec -it mysql1 mysql -uroot -prootpassword -e "GRANT SELECT ON database_name.* TO 'problematic_user'@'%'; FLUSH PRIVILEGES"
   docker exec -it mysql2 mysql -uroot -prootpassword -e "GRANT SELECT ON database_name.* TO 'problematic_user'@'%'; FLUSH PRIVILEGES"
   ```
