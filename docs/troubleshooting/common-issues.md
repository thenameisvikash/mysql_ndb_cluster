# Common Issues and Solutions

[← Documentation Index](../index.md) | [Cluster Issues →](cluster-issues.md)

*Related: [ProxySQL Issues](proxysql-issues.md) | [Testing Overview](../testing/overview.md)*

This guide provides solutions to common issues you might encounter when working with MySQL Cluster and ProxySQL.

## Startup Issues

### Containers Fail to Start

**Symptoms:**
- Containers show status "Exited" or "Restarting"
- Docker logs show errors during startup

**Solutions:**
1. Check resource availability:
   ```bash
   docker info | grep Memory
   docker info | grep CPU
   ```

2. Check port conflicts:
   ```bash
   netstat -tuln | grep '3306\|6033\|1186'
   ```

3. Check container logs:
   ```bash
   docker-compose logs management1
   docker-compose logs mysql1
   docker-compose logs proxysql
   ```

4. Restart with clean state:
   ```bash
   docker-compose down
   rm -rf data/*
   docker-compose up -d
   ```

### Management Node Fails to Start

**Symptoms:**
- Management node container exits shortly after starting
- Logs show configuration errors

**Solutions:**
1. Check configuration file:
   ```bash
   cat config/management-config.ini
   ```

2. Verify IP addresses and hostnames:
   ```bash
   docker network inspect ndb-net
   ```

3. Reset management node:
   ```bash
   docker-compose down
   rm -rf management1-data/*
   docker-compose up -d management1
   ```

### Data Nodes Fail to Connect

**Symptoms:**
- Data nodes show "not connected" status
- Logs show connection errors to management nodes

**Solutions:**
1. Check management node status:
   ```bash
   docker exec management1 ndb_mgm -e "show" --ndb-connectstring=management1:1186
   ```

2. Verify network connectivity:
   ```bash
   docker exec ndb1 ping -c 3 management1
   ```

3. Check data node logs:
   ```bash
   docker-compose logs ndb1
   ```

4. Restart data nodes:
   ```bash
   docker-compose restart ndb1 ndb2 ndb3 ndb4
   ```

### MySQL Nodes Fail to Start

**Symptoms:**
- MySQL containers exit with errors
- Logs show issues connecting to cluster

**Solutions:**
1. Check MySQL configuration:
   ```bash
   cat config/mysql1/my.cnf
   ```

2. Verify cluster connection:
   ```bash
   docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW ENGINE NDBCLUSTER STATUS\\G"
   ```

3. Check error logs:
   ```bash
   docker exec mysql1 cat /var/log/mysql/error.log
   ```

4. Restart MySQL nodes:
   ```bash
   docker-compose restart mysql1 mysql2
   ```

### ProxySQL Fails to Start

**Symptoms:**
- ProxySQL container exits with errors
- Cannot connect to ProxySQL admin interface

**Solutions:**
1. Check ProxySQL configuration:
   ```bash
   cat config/proxysql-config.cnf
   ```

2. Verify MySQL backend availability:
   ```bash
   docker exec -it mysql1 mysqladmin -uroot -p${MYSQL_ROOT_PASSWORD} ping
   docker exec -it mysql2 mysqladmin -uroot -p${MYSQL_ROOT_PASSWORD} ping
   ```

3. Check ProxySQL logs:
   ```bash
   docker-compose logs proxysql
   ```

4. Reset ProxySQL:
   ```bash
   docker-compose down
   rm -rf proxysql-data/*
   docker-compose up -d proxysql
   ```

## Connection Issues

### Cannot Connect to ProxySQL

**Symptoms:**
- Connection errors when trying to connect to ProxySQL
- "Access denied" errors

**Solutions:**
1. Verify ProxySQL is running:
   ```bash
   docker ps | grep proxysql
   ```

2. Check user configuration:
   ```bash
   docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "SELECT username, active FROM mysql_users"
   ```

3. Check server configuration:
   ```bash
   docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "SELECT hostgroup_id, hostname, status FROM mysql_servers"
   ```

4. Verify network connectivity:
   ```bash
   telnet 127.0.0.1 6033
   ```

### Cannot Connect to MySQL Directly

**Symptoms:**
- Connection errors when trying to connect directly to MySQL nodes
- "Access denied" errors

**Solutions:**
1. Verify MySQL is running:
   ```bash
   docker ps | grep mysql
   ```

2. Check user permissions:
   ```bash
   docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SELECT user, host FROM mysql.user"
   ```

3. Verify network connectivity:
   ```bash
   telnet 127.0.0.1 3306
   ```

4. Check authentication method:
   ```bash
   docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SELECT user, plugin FROM mysql.user"
   ```

## Data Issues

### Tables Not Created as NDB Tables

**Symptoms:**
- Tables created but not visible across all nodes
- `SHOW ENGINE NDBCLUSTER STATUS` doesn't show tables

**Solutions:**
1. Verify storage engine:
   ```bash
   docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW CREATE TABLE database_name.table_name\\G"
   ```

2. Set default storage engine:
   ```bash
   docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SET default_storage_engine=NDBCLUSTER"
   ```

3. Recreate table with correct engine:
   ```sql
   ALTER TABLE database_name.table_name ENGINE=NDBCLUSTER;
   ```

### Data Inconsistency Between Nodes

**Symptoms:**
- Different query results on different MySQL nodes
- Data visible on one node but not another

**Solutions:**
1. Check cluster status:
   ```bash
   docker exec management1 ndb_mgm -e "all status" --ndb-connectstring=management1:1186
   ```

2. Verify table is using NDB engine:
   ```bash
   docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW CREATE TABLE database_name.table_name\\G"
   ```

3. Check for partitioning issues:
   ```bash
   docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "EXPLAIN PARTITIONS SELECT * FROM database_name.table_name WHERE primary_key_column=value\\G"
   ```

4. Restart the cluster if necessary:
   ```bash
   docker-compose restart
   ```

## Performance Issues

### Slow Queries

**Symptoms:**
- Queries take longer than expected
- High CPU usage on MySQL nodes

**Solutions:**
1. Check query execution plan:
   ```bash
   docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "EXPLAIN SELECT * FROM database_name.table_name WHERE condition\\G"
   ```

2. Check for missing indexes:
   ```bash
   docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW INDEX FROM database_name.table_name"
   ```

3. Verify ProxySQL query routing:
   ```bash
   docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "SELECT * FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10"
   ```

4. Optimize table:
   ```bash
   docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "OPTIMIZE TABLE database_name.table_name"
   ```

### Connection Pool Exhaustion

**Symptoms:**
- "Too many connections" errors
- Connections hang or timeout

**Solutions:**
1. Check current connections:
   ```bash
   docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW STATUS LIKE 'Threads_connected'"
   ```

2. Check ProxySQL connection pool:
   ```bash
   docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "SELECT * FROM stats_mysql_connection_pool"
   ```

3. Increase connection limits:
   ```bash
   docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SET GLOBAL max_connections=1000"
   ```

4. Adjust ProxySQL connection pool:
   ```bash
   docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "UPDATE mysql_servers SET max_connections=500 WHERE hostname='mysql1'; LOAD MYSQL SERVERS TO RUNTIME; SAVE MYSQL SERVERS TO DISK"
   ```

## Diagnostic Commands

### Check Cluster Status

```bash
docker exec management1 ndb_mgm -e "show" --ndb-connectstring=management1:1186
docker exec management1 ndb_mgm -e "all status" --ndb-connectstring=management1:1186
```

### Check MySQL Status

```bash
docker exec mysql1 mysqladmin -uroot -p${MYSQL_ROOT_PASSWORD} status
docker exec mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW ENGINE NDBCLUSTER STATUS\\G"
```

### Check ProxySQL Status

```bash
docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "SELECT * FROM mysql_servers"
docker exec proxysql mysql -h127.0.0.1 -P6032 -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -e "SELECT * FROM stats_mysql_connection_pool"
```

### Run Test Suite

```bash
./mysql_cluster_test_suite.sh health
./mysql_cluster_test_suite.sh proxysql
./mysql_cluster_test_suite.sh data
```

## Related Documentation

- [Cluster Issues](cluster-issues.md) - Troubleshooting cluster-specific issues
- [ProxySQL Issues](proxysql-issues.md) - Troubleshooting ProxySQL-specific issues
- [Testing Overview](../testing/overview.md) - Testing principles and strategies
