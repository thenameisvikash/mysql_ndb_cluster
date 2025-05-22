# MySQL Cluster Troubleshooting Guide

[← Testing Documentation](MySQL_Cluster_Testing_Documentation.md) | [Documentation Index](DOCUMENTATION.md) | [Detailed Troubleshooting →](docs/troubleshooting.md)

## Common Issues and Solutions

This guide covers the most common issues encountered with MySQL Cluster deployments and provides step-by-step solutions to resolve them.

## Table of Contents

1. [Split-Brain Scenarios](#split-brain-scenarios)
2. [Node Failures](#node-failures)
3. [Performance Issues](#performance-issues)
4. [Connection Problems](#connection-problems)
5. [Data Inconsistency](#data-inconsistency)
6. [Memory Issues](#memory-issues)
7. [Disk Space Problems](#disk-space-problems)
8. [Diagnostic Tools](#diagnostic-tools)

## Split-Brain Scenarios

### Symptoms
- Different node groups report conflicting cluster states
- Inconsistent data between node groups
- Error messages about "network partitioning" or "possible split-brain situation"

### Causes
- Network partitioning between node groups
- Failure of arbitration mechanism
- Misconfigured arbitration settings

### Solutions

1. **Verify Network Connectivity**
   ```bash
   # Check connectivity between nodes
   ping node_hostname
   
   # Check network interfaces
   ip addr show
   
   # Verify no firewall rules blocking cluster traffic
   iptables -L
   ```

2. **Check Arbitration Configuration**
   ```bash
   # Connect to management node
   ndb_mgm -c management1
   
   # Check cluster status
   ndb_mgm> show
   
   # Review arbitration settings in config.ini
   grep -i arbitration /path/to/config.ini
   ```

3. **Resolve Split-Brain**
   
   If a split-brain has occurred:
   
   a. Identify the node group with the most current data
   
   b. Stop the nodes in the other node group:
   ```bash
   ndb_mgm> node_id stop
   ```
   
   c. Restart the stopped nodes with the `--initial` flag to resync data:
   ```bash
   ndbd --initial -c management1
   ```

4. **Prevent Future Split-Brain Issues**
   
   a. Configure proper arbitration:
   ```ini
   [ndbd default]
   Arbitration=Default
   ArbitrationTimeout=7500
   ```
   
   b. Ensure an odd number of nodes or use an external arbitrator
   
   c. Implement redundant network connections between node groups

## Node Failures

### Symptoms
- Node showing as "not connected" in management client
- Error messages in cluster logs
- Applications reporting connection errors

### Causes
- Hardware failure
- Resource exhaustion (CPU, memory, disk)
- Network issues
- Configuration problems

### Solutions

1. **Check Node Status**
   ```bash
   ndb_mgm> show
   ```

2. **Review Error Logs**
   ```bash
   # Check cluster logs
   tail -f /var/lib/mysql-cluster/ndb_*.log
   
   # Check system logs
   journalctl -u ndbd
   ```

3. **Restart Failed Node**
   ```bash
   # Normal restart (preserves data)
   ndb_mgm> node_id restart
   
   # If data is corrupted, use initial restart
   ndb_mgm> node_id restart -i
   ```

4. **Verify Resource Utilization**
   ```bash
   # Check memory usage
   free -h
   
   # Check disk space
   df -h
   
   # Check CPU usage
   top
   ```

5. **Adjust Configuration if Needed**
   
   If resource limits are causing failures, adjust in config.ini:
   ```ini
   [ndbd default]
   DataMemory=8G
   IndexMemory=2G
   ```

## Performance Issues

### Symptoms
- Slow query response times
- High CPU usage
- Increased latency
- Timeouts

### Causes
- Insufficient resources
- Poor query design
- Uneven data distribution
- Network bottlenecks

### Solutions

1. **Identify Slow Queries**
   ```bash
   # Enable slow query log
   mysql> SET GLOBAL slow_query_log=ON;
   mysql> SET GLOBAL long_query_time=1;
   
   # Analyze slow queries
   mysqldumpslow /var/lib/mysql/slow-query.log
   ```

2. **Check Cluster Performance Statistics**
   ```bash
   ndb_mgm> show
   
   # Use ndbinfo database for detailed statistics
   mysql> USE ndbinfo;
   mysql> SELECT * FROM memoryusage;
   mysql> SELECT * FROM operations_per_fragment;
   ```

3. **Optimize Data Distribution**
   
   Ensure data is evenly distributed across node groups:
   ```bash
   ndb_desc -d database -t table -p
   ```

4. **Adjust Configuration Parameters**
   
   Tune performance-related parameters:
   ```ini
   [ndbd default]
   MaxNoOfConcurrentOperations=200000
   MaxNoOfConcurrentTransactions=16384
   BatchSizePerLocalScan=512
   ```

5. **Add Resources**
   
   If needed, add more:
   - CPU cores
   - Memory
   - Network bandwidth
   - Node groups (for horizontal scaling)

## Connection Problems

### Symptoms
- Applications unable to connect to SQL nodes
- "Unable to connect to NDB" errors
- Connection timeouts

### Causes
- Firewall blocking connections
- Incorrect connection strings
- SQL node not connected to cluster
- Authentication issues

### Solutions

1. **Verify SQL Node Status**
   ```bash
   ndb_mgm> show
   ```

2. **Check Firewall Settings**
   ```bash
   # Check if ports are open
   netstat -tulpn | grep mysql
   
   # Verify firewall rules
   iptables -L
   ```

3. **Test Connection Manually**
   ```bash
   mysql -h sql_node_ip -u root -p
   
   # Once connected, verify NDB engine is available
   mysql> SHOW ENGINES;
   ```

4. **Check Connection String**
   
   Ensure applications are using the correct connection string:
   ```
   jdbc:mysql://host:port/database?useConfigs=maxPerformance
   ```

5. **Restart SQL Node if Needed**
   ```bash
   systemctl restart mysql
   ```

## Data Inconsistency

### Symptoms
- Different results from queries on different SQL nodes
- Error messages about inconsistent data
- Replication failures

### Causes
- Split-brain scenario
- Incomplete recovery after failure
- Bug in application logic

### Solutions

1. **Verify Data Consistency**
   ```bash
   # Run consistency check
   ndb_restore --check-orphans --backup-id=backup_id --backup-path=/path/to/backup
   ```

2. **Force Synchronization**
   
   If inconsistencies are detected:
   ```bash
   # Perform full database backup
   ndb_mgm> start backup
   
   # Restore from backup to all nodes
   ndb_restore --restore-data --backup-id=backup_id --backup-path=/path/to/backup -r
   ```

3. **Rebuild Indexes**
   ```bash
   ndb_restore --rebuild-indexes --backup-id=backup_id --backup-path=/path/to/backup
   ```

4. **Implement Application-Level Validation**
   
   Add checksums or validation logic to critical data in your application

## Memory Issues

### Symptoms
- "Out of memory" errors in logs
- Node failures during high load
- Performance degradation over time

### Causes
- Insufficient DataMemory or IndexMemory
- Memory leaks
- Too many concurrent operations

### Solutions

1. **Monitor Memory Usage**
   ```bash
   mysql> USE ndbinfo;
   mysql> SELECT * FROM memoryusage;
   mysql> SELECT * FROM resources;
   ```

2. **Adjust Memory Configuration**
   ```ini
   [ndbd default]
   DataMemory=16G
   IndexMemory=4G
   ```

3. **Implement Memory Usage Alerts**
   
   Set up monitoring to alert when memory usage exceeds 80%

4. **Optimize Queries to Reduce Memory Usage**
   
   Review and optimize queries that create temporary tables or use excessive memory

## Disk Space Problems

### Symptoms
- "No space left on device" errors
- Failed backups
- Node failures

### Causes
- Insufficient disk space
- Large transaction logs
- Excessive temporary files

### Solutions

1. **Check Disk Usage**
   ```bash
   df -h
   du -sh /var/lib/mysql-cluster/*
   ```

2. **Clean Up Old Files**
   ```bash
   # Remove old backups
   find /var/lib/mysql-cluster/BACKUP -type d -name "BACKUP-*" -mtime +7 -exec rm -rf {} \;
   
   # Clean up old logs
   find /var/lib/mysql-cluster -name "*.log.*" -mtime +7 -delete
   ```

3. **Configure Log Rotation**
   
   Set up proper log rotation for MySQL Cluster logs

4. **Add More Disk Space**
   
   Expand volumes or add new storage as needed

## Diagnostic Tools

### ndb_mgm (Management Client)
```bash
# Connect to management node
ndb_mgm -c management1

# Show cluster status
ndb_mgm> show

# Get detailed node info
ndb_mgm> node_id status

# View cluster configuration
ndb_mgm> get config
```

### ndb_config
```bash
# Get configuration information
ndb_config --config-file=/path/to/config.ini --query=nodeid,type,host --type=ndbd

# Check connection string
ndb_config --config-file=/path/to/config.ini --query=connectstring
```

### ndbinfo Database
```sql
-- Connect to MySQL
mysql -u root -p

-- Switch to ndbinfo database
USE ndbinfo;

-- Check cluster memory usage
SELECT * FROM memoryusage;

-- Check node connection status
SELECT * FROM nodes;

-- Monitor operations
SELECT * FROM operations_per_fragment;
```

### System Monitoring
```bash
# Check system resources
top
vmstat 1
iostat -x 1

# Network monitoring
iptraf-ng
tcpdump -i eth0 port 1186
```

## Conclusion

This troubleshooting guide covers the most common issues encountered with MySQL Cluster. By following the diagnostic steps and solutions provided, you can quickly identify and resolve problems to maintain a healthy and performant cluster.

For more complex issues, consider:
1. Consulting the official MySQL Cluster documentation
2. Reviewing the MySQL Cluster mailing list archives
3. Opening a support ticket if you have Oracle support
4. Engaging with the MySQL community forums
