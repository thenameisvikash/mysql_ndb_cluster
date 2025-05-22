# Management Guide

[← Documentation Index](../index.md) | [Backup and Recovery →](backup-recovery.md)

*Related: [User Management](user-management.md) | [Scaling Operations](scaling.md)*

This guide provides instructions for day-to-day management operations of your MySQL Cluster with ProxySQL.

## Cluster Status Monitoring

### Checking Cluster Status

To check the overall status of the cluster:

```bash
docker exec management1 ndb_mgm -e "show" --ndb-connectstring=management1:1186
```

Example output:
```
Connected to Management Server at: management1:1186
Cluster Configuration
---------------------
[ndbd(NDB)]     2 node(s)
id=2    @172.20.0.3  (mysql-8.0.32 ndb-8.0.32, Nodegroup: 0, *)
id=3    @172.20.0.4  (mysql-8.0.32 ndb-8.0.32, Nodegroup: 0)

[ndb_mgmd(MGM)] 1 node(s)
id=1    @172.20.0.2  (mysql-8.0.32 ndb-8.0.32)

[mysqld(API)]   2 node(s)
id=4    @172.20.0.5  (mysql-8.0.32 ndb-8.0.32)
id=5    @172.20.0.6  (mysql-8.0.32 ndb-8.0.32)
```

To check the status of all nodes:

```bash
docker exec management1 ndb_mgm -e "all status" --ndb-connectstring=management1:1186
```

### Checking MySQL Status

To check the status of MySQL nodes:

```bash
docker exec mysql1 mysqladmin -uroot -p${MYSQL_ROOT_PASSWORD} status
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW ENGINE NDBCLUSTER STATUS\\G"
```

### Checking ProxySQL Status

To check ProxySQL server configuration:

```bash
docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "SELECT hostgroup_id, hostname, port, status FROM mysql_servers"
```

To check ProxySQL connection pool:

```bash
docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "SELECT * FROM stats_mysql_connection_pool"
```

## Cluster Management Operations

### Starting the Cluster

To start the entire cluster:

```bash
docker-compose up -d
```

To start specific components:

```bash
docker-compose up -d management1 management2
docker-compose up -d ndb1 ndb2 ndb3 ndb4
docker-compose up -d mysql1 mysql2
docker-compose up -d proxysql proxysql2
```

### Stopping the Cluster

To stop the entire cluster:

```bash
docker-compose down
```

To stop specific components:

```bash
docker-compose stop mysql1
docker-compose stop ndb1
```

### Restarting Components

To restart specific components:

```bash
docker-compose restart mysql1
docker-compose restart proxysql
```

### Checking Logs

To check logs for specific components:

```bash
docker-compose logs management1
docker-compose logs mysql1
docker-compose logs proxysql
```

To follow logs in real-time:

```bash
docker-compose logs -f mysql1
```

## Database Management

### Creating a Database

```bash
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE my_database"
```

### Creating a Table with NDB Engine

```bash
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "CREATE TABLE my_database.my_table (id INT PRIMARY KEY, data VARCHAR(100)) ENGINE=NDBCLUSTER"
```

### Checking Table Status

```bash
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW CREATE TABLE my_database.my_table\\G"
```

### Converting a Table to NDB Engine

```bash
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "ALTER TABLE my_database.my_table ENGINE=NDBCLUSTER"
```

### Optimizing Tables

```bash
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "OPTIMIZE TABLE my_database.my_table"
```

## User Management

### Creating a New User

For a read-write user:

```bash
./scripts/user_management.sh -w create new_user password123
```

For a read-only user:

```bash
./scripts/user_management.sh create new_readonly_user password123
```

### Listing Users

```bash
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SELECT user, host FROM mysql.user"
```

### Checking User Permissions

```bash
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW GRANTS FOR 'username'@'%'"
```

### Modifying User Permissions

```bash
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT SELECT, INSERT, UPDATE ON my_database.* TO 'username'@'%'"
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "FLUSH PRIVILEGES"
```

## ProxySQL Management

### Updating MySQL Servers in ProxySQL

```bash
docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "
UPDATE mysql_servers SET weight=1000 WHERE hostname='mysql1' AND hostgroup_id=0;
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK"
```

### Updating Query Rules

```bash
docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply) VALUES (10, 1, '^SELECT .* FOR UPDATE', 0, 1);
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK"
```

### Checking Query Statistics

```bash
docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "SELECT * FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10"
```

### Updating User Configurations

```bash
docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "
UPDATE mysql_users SET max_connections=200 WHERE username='readwrite';
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK"
```

## Performance Management

### Checking Resource Usage

```bash
docker stats mysql1 mysql2 ndb1 ndb2 ndb3 ndb4 proxysql
```

### Checking Query Performance

```bash
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW GLOBAL STATUS LIKE 'Queries'"
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW GLOBAL STATUS LIKE 'Slow_queries'"
```

### Checking Connection Status

```bash
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW STATUS LIKE 'Threads_connected'"
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW STATUS LIKE 'Max_used_connections'"
```

### Running Performance Tests

```bash
python test-load.py --threads 10 --records 1000 --batch-size 100
```

## Maintenance Operations

### Checking Disk Space

```bash
docker exec mysql1 df -h
```

### Checking Memory Usage

```bash
docker exec mysql1 free -m
```

### Checking Process Status

```bash
docker exec mysql1 ps aux
```

### Running Health Checks

```bash
./mysql_cluster_test_suite.sh health
```

## Related Documentation

- [Backup and Recovery](backup-recovery.md) - Backup and recovery procedures
- [User Management](user-management.md) - Detailed user management guide
- [Scaling Operations](scaling.md) - Scaling your cluster
- [Troubleshooting](../troubleshooting/common-issues.md) - Troubleshooting common issues
