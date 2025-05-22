# Troubleshooting Guide

[← Testing](testing.md) | [Documentation Index](../DOCUMENTATION.md) | [Performance Tuning →](performance-tuning.md)

*Related: [Main Troubleshooting Guide](../Troubleshooting_Guide.md)*

This guide provides solutions to common issues you might encounter with your MySQL Cluster and ProxySQL setup.

## Startup Issues

### Containers Show as "Unhealthy" During Initial Deployment

**Symptoms:**
- Some containers show as "unhealthy" in `docker-compose ps` output
- The cluster doesn't fully initialize

**Solution:**
```bash
# Stop all containers
docker-compose down

# Start them again
docker-compose up -d
```

**Explanation:**
During the first deployment, there's a timing issue where some components might try to connect to others before they're fully initialized. Running the deployment a second time usually resolves this issue.

### MySQL Nodes Fail to Join the Cluster

**Symptoms:**
- MySQL containers start but don't join the cluster
- `SHOW ENGINE NDBCLUSTER STATUS` shows errors or no connection

**Solution:**
```bash
# Check MySQL logs
docker logs mysql1

# Verify the management node is running
docker exec -it management1 ndb_mgm -e "show" --ndb-connectstring=172.20.0.2:1186

# Restart the MySQL container
docker-compose restart mysql1
```

**Explanation:**
MySQL nodes need to connect to the management nodes to join the cluster. If the management nodes aren't fully initialized when MySQL starts, the connection might fail.

## Connection Issues

### Can't Connect to ProxySQL

**Symptoms:**
- `ERROR 2003 (HY000): Can't connect to MySQL server on '127.0.0.1' (111)`
- `ERROR 1045 (28000): Access denied for user`

**Solution:**
```bash
# Check if ProxySQL is running
docker ps | grep proxysql

# Check ProxySQL logs
docker logs proxysql

# Verify ProxySQL configuration
docker exec -it proxysql cat /etc/proxysql.cnf | grep mysql_interfaces
```

**Explanation:**
Connection issues can be caused by ProxySQL not running, incorrect port mapping, or authentication problems.

### Can't Connect to MySQL Directly

**Symptoms:**
- `ERROR 2003 (HY000): Can't connect to MySQL server on '127.0.0.1' (111)`

**Solution:**
```bash
# Check if MySQL is running
docker ps | grep mysql

# Check MySQL logs
docker logs mysql1

# Verify MySQL is listening on the expected port
docker exec -it mysql1 netstat -tuln | grep 3306
```

**Explanation:**
Direct MySQL connection issues can be caused by incorrect port mapping or MySQL not running.

## User Management Issues

### ProxySQL Monitoring User Missing

**Symptoms:**
- ProxySQL shows errors about the monitoring user in logs
- `mysql_server_ping_log` shows access denied errors

**Solution:**
```bash
# Fix the monitoring user issue
./mysql_cluster_test_suite.sh fix-monitoring

# Or manually create the monitoring user on both MySQL nodes
docker exec -it mysql1 mysql -uroot -prootpassword -e "CREATE USER 'proxysql_monitor'@'%' IDENTIFIED WITH mysql_native_password BY 'monitorpass123'; GRANT USAGE, REPLICATION CLIENT, PROCESS, SELECT ON *.* TO 'proxysql_monitor'@'%'; FLUSH PRIVILEGES;"
docker exec -it mysql2 mysql -uroot -prootpassword -e "CREATE USER 'proxysql_monitor'@'%' IDENTIFIED WITH mysql_native_password BY 'monitorpass123'; GRANT USAGE, REPLICATION CLIENT, PROCESS, SELECT ON *.* TO 'proxysql_monitor'@'%'; FLUSH PRIVILEGES;"
```

**Explanation:**
The monitoring user needs to exist on both MySQL nodes for ProxySQL to properly monitor them.

### User Created on One MySQL Node Not Available on Another

**Symptoms:**
- User can connect through one MySQL node but not another
- `Access denied for user` errors when connecting through ProxySQL

**Solution:**
```bash
# Use the user management script to create users across all nodes
./scripts/user_management.sh create username password

# Or manually create the user on both MySQL nodes
docker exec -it mysql1 mysql -uroot -prootpassword -e "CREATE USER 'username'@'%' IDENTIFIED WITH mysql_native_password BY 'password'; GRANT SELECT ON *.* TO 'username'@'%'; FLUSH PRIVILEGES;"
docker exec -it mysql2 mysql -uroot -prootpassword -e "CREATE USER 'username'@'%' IDENTIFIED WITH mysql_native_password BY 'password'; GRANT SELECT ON *.* TO 'username'@'%'; FLUSH PRIVILEGES;"
```

**Explanation:**
In this MySQL Cluster setup, user accounts are not automatically replicated between SQL nodes. You need to create users on all SQL nodes manually or use the provided user management script.

## Data Node Issues

### Data Node Won't Start

**Symptoms:**
- Data node container starts but the node doesn't join the cluster
- Management node shows the data node as "not connected"

**Solution:**
```bash
# Check data node logs
docker logs ndb1

# Clear data node data (caution: this will delete all data)
docker-compose down
rm -rf ./data/ndb1/*
docker-compose up -d
```

**Explanation:**
Data nodes might fail to start if their data files are corrupted or if there's a configuration mismatch.

### Data Node Runs Out of Memory

**Symptoms:**
- Data node crashes or restarts frequently
- Logs show memory allocation errors

**Solution:**
```bash
# Check data node memory usage
docker exec -it management1 ndb_mgm -e "all report memory" --ndb-connectstring=172.20.0.2:1186

# Increase memory allocation in management-config.ini
# Edit the DataMemory and IndexMemory parameters
```

**Explanation:**
Data nodes store data in memory. If you have more data than allocated memory, the node will fail.

## ProxySQL Issues

### Query Routing Not Working Correctly

**Symptoms:**
- All queries go to the same hostgroup
- Read/write splitting not working as expected

**Solution:**
```bash
# Check query routing rules
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT rule_id, active, username, match_digest, destination_hostgroup FROM mysql_query_rules ORDER BY rule_id"

# Check query statistics
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT digest_text, count_star, sum_time, hostgroup FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10"
```

**Explanation:**
Query routing depends on properly configured rules in ProxySQL. The rules are matched in order, so rule priority matters.

### ProxySQL Admin Interface Access Denied

**Symptoms:**
- `ERROR 1045 (28000): ProxySQL Error: Access denied for user 'admin'@'127.0.0.1'`

**Solution:**
```bash
# Check the admin credentials in the configuration
docker exec -it proxysql cat /etc/proxysql.cnf | grep admin_credentials

# Use the correct credentials (usually radmin/radmin)
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin
```

**Explanation:**
ProxySQL uses separate credentials for the admin interface. The default is often `radmin`/`radmin`, not `admin`/`admin`.

## Performance Issues

### Slow Query Performance

**Symptoms:**
- Queries take longer than expected
- High latency reported in ProxySQL stats

**Solution:**
```bash
# Check ProxySQL connection pool
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT * FROM stats_mysql_connection_pool"

# Check for slow queries
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT digest_text, count_star, sum_time, hostgroup FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10"
```

**Explanation:**
Performance issues can be caused by insufficient connection pool size, poorly optimized queries, or resource constraints.

### Connection Errors Under Load

**Symptoms:**
- `ERROR 1040 (HY000): Too many connections`
- Connections fail during high load

**Solution:**
```bash
# Increase max_connections in MySQL
docker exec -it mysql1 mysql -uroot -prootpassword -e "SET GLOBAL max_connections = 1000"
docker exec -it mysql2 mysql -uroot -prootpassword -e "SET GLOBAL max_connections = 1000"

# Adjust ProxySQL connection pool settings
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "UPDATE mysql_servers SET max_connections=2000 WHERE hostname='mysql1'; UPDATE mysql_servers SET max_connections=2000 WHERE hostname='mysql2'; LOAD MYSQL SERVERS TO RUNTIME; SAVE MYSQL SERVERS TO DISK"
```

**Explanation:**
Under high load, you might hit connection limits in MySQL or ProxySQL. Adjusting these limits can help handle more concurrent connections.

## Cluster Recovery

### Recovering from Complete Cluster Failure

If all components of the cluster are down or in an inconsistent state:

```bash
# Stop all containers
docker-compose down

# Remove all data (caution: this will delete all data)
rm -rf ./data/*

# Start the cluster from scratch
docker-compose up -d
```

### Recovering from Management Node Failure

If the management nodes fail but data nodes are still running:

```bash
# Restart management nodes
docker-compose restart management1 management2

# Check cluster status
docker exec -it management1 ndb_mgm -e "show" --ndb-connectstring=172.20.0.2:1186
```

### Recovering from Data Node Failure

If some data nodes fail but others in the same node group are still running:

```bash
# Restart failed data nodes
docker-compose restart ndb1

# Check cluster status
docker exec -it management1 ndb_mgm -e "show" --ndb-connectstring=172.20.0.2:1186
```

## Diagnostic Tools

### Cluster Status

```bash
# Show cluster configuration
docker exec -it management1 ndb_mgm -e "show" --ndb-connectstring=172.20.0.2:1186

# Show node status
docker exec -it management1 ndb_mgm -e "all status" --ndb-connectstring=172.20.0.2:1186

# Show memory usage
docker exec -it management1 ndb_mgm -e "all report memory" --ndb-connectstring=172.20.0.2:1186
```

### MySQL Status

```bash
# Show MySQL cluster status
docker exec -it mysql1 mysql -uroot -prootpassword -e "SHOW ENGINE NDBCLUSTER STATUS\G"

# Show MySQL process list
docker exec -it mysql1 mysql -uroot -prootpassword -e "SHOW PROCESSLIST"

# Show MySQL variables
docker exec -it mysql1 mysql -uroot -prootpassword -e "SHOW VARIABLES LIKE '%ndb%'"
```

### ProxySQL Status

```bash
# Show server status
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT hostgroup_id, hostname, port, status FROM mysql_servers"

# Show connection pool
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT * FROM stats_mysql_connection_pool"

# Show query statistics
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT digest_text, count_star, sum_time, hostgroup FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10"
```

## Getting Help

If you encounter issues not covered in this guide:

1. Check container logs:
   ```bash
   docker-compose logs
   ```

2. Run the test suite to identify specific issues:
   ```bash
   ./mysql_cluster_test_suite.sh all
   ```

3. Open an issue on the GitHub repository with:
   - Detailed description of the problem
   - Steps to reproduce
   - Output of relevant diagnostic commands
   - Container logs
