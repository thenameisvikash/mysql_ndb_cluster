# MySQL Cluster DevOps Guide for High-Throughput Applications

This comprehensive guide explains MySQL Cluster from a DevOps perspective, focusing on high-throughput applications that require handling 1.5 Lac TPS (150,000 transactions per second) with Redis as a queue and processing 60 Crore (600 million) daily records in MySQL.

## Table of Contents

1. [Understanding MySQL Cluster](#understanding-mysql-cluster)
2. [Architecture Components](#architecture-components)
3. [Deployment Patterns](#deployment-patterns)
4. [Hardware Sizing](#hardware-sizing)
5. [Memory Configuration](#memory-configuration)
6. [Performance Tuning](#performance-tuning)
7. [High Availability and Failover](#high-availability-and-failover)
8. [Monitoring and Alerting](#monitoring-and-alerting)
9. [Backup and Recovery](#backup-and-recovery)
10. [Scaling Strategies](#scaling-strategies)
11. [Common Operational Tasks](#common-operational-tasks)
12. [Troubleshooting](#troubleshooting)
13. [Edge Cases and Limitations](#edge-cases-and-limitations)
14. [Integration with Redis for High-Throughput Processing](#integration-with-redis)

## Understanding MySQL Cluster

MySQL Cluster is a distributed, real-time database that combines the MySQL server with the NDB (Network Database) storage engine. Unlike traditional MySQL with InnoDB, MySQL Cluster is designed for:

- **High Availability**: 99.999% uptime with automatic failover
- **Real-time Performance**: Sub-millisecond response times
- **Linear Scalability**: Add nodes to increase capacity
- **In-Memory Processing**: Primary data storage in memory for speed

These characteristics make it ideal for applications requiring high throughput and low latency, such as CDR (Call Detail Record) processing systems, payment processing, and session management.

## Architecture Components

MySQL Cluster consists of three main components:

![MySQL Cluster Architecture](https://dev.mysql.com/doc/refman/8.0/en/images/cluster-components-1.png)

### 1. Management Nodes (ndb_mgmd)

- **Purpose**: Control the cluster configuration and monitor node status
- **Functions**:
  - Store and distribute configuration
  - Monitor node health
  - Coordinate cluster operations
  - Manage node restarts
- **Deployment**: At least 1 for development, 2 for production (for redundancy)

### 2. Data Nodes (ndbd/ndbmtd)

- **Purpose**: Store and replicate data
- **Functions**:
  - Store data in memory
  - Handle data replication
  - Manage transactions
  - Perform automatic sharding
- **Deployment**: Minimum 2 nodes (for a single node group with replication)
- **Note**: `ndbmtd` is the multi-threaded version recommended for production

### 3. SQL Nodes (mysqld)

- **Purpose**: Process SQL queries and provide SQL interface
- **Functions**:
  - Parse and execute SQL statements
  - Optimize queries
  - Manage connections
  - Handle authentication
- **Deployment**: At least 2 for high availability

### 4. Additional Components for Production

- **Load Balancer** (ProxySQL/HAProxy): Distributes client connections
- **Monitoring Tools** (Prometheus/Grafana): Track performance and health
- **Backup Management**: For data protection and recovery

## Deployment Patterns

### Development/Testing Pattern

```
┌─────────────┐
│ Management  │
│    Node     │
└─────────────┘
       │
       ├─────────────┬─────────────┐
       │             │             │
┌─────────────┐┌─────────────┐┌─────────────┐
│  Data Node  ││  Data Node  ││  SQL Node   │
│     #1      ││     #2      ││             │
└─────────────┘└─────────────┘└─────────────┘
```

- 1 Management node
- 2 Data nodes (minimum for replication)
- 1 SQL node
- Suitable for: Local development, testing, proof of concept

### Production Pattern for High Throughput

```
┌─────────────┐     ┌─────────────┐
│ Management  │     │ Management  │
│  Node #1    │◄───►│  Node #2    │
└─────────────┘     └─────────────┘
       │                   │
       └───────┬───────────┘
               │
┌──────────────┼──────────────┐
│              │              │
▼              ▼              ▼
┌─────────────┐┌─────────────┐┌─────────────┐┌─────────────┐
│  Data Node  ││  Data Node  ││  Data Node  ││  Data Node  │
│  Group 1-1  ││  Group 1-2  ││  Group 2-1  ││  Group 2-2  │
└─────────────┘└─────────────┘└─────────────┘└─────────────┘
       ▲              ▲              ▲              ▲
       │              │              │              │
       └──────┬───────┴──────┬───────┴──────┬───────┘
              │              │              │
              ▼              ▼              ▼
        ┌─────────────┐┌─────────────┐┌─────────────┐
        │  SQL Node   ││  SQL Node   ││  SQL Node   │
        │     #1      ││     #2      ││     #3      │
        └─────────────┘└─────────────┘└─────────────┘
                 │              │              │
                 └──────┬───────┴──────┬───────┘
                        │              │
                        ▼              ▼
                ┌─────────────┐┌─────────────┐
                │  ProxySQL   ││  ProxySQL   │
                │     #1      ││     #2      │
                └─────────────┘└─────────────┘
                        │              │
                        └──────┬───────┘
                               │
                               ▼
                        ┌─────────────┐
                        │ Application │
                        │   Servers   │
                        └─────────────┘
```

- 2 Management nodes for redundancy
- 4+ Data nodes (at least 2 node groups for sharding)
- 3+ SQL nodes for high availability and load distribution
- 2 ProxySQL instances for load balancing
- Suitable for: Production systems with high throughput requirements

## Hardware Sizing

### For Your 1.5 Lac TPS and 60 Crore Daily Records

#### Management Nodes
- **CPU**: 4-8 cores
- **RAM**: 8-16 GB
- **Disk**: 100 GB SSD (for logs and configuration)
- **Network**: 10 Gbps

#### Data Nodes
- **CPU**: 16-32 cores (critical for multi-threaded data nodes)
- **RAM**: 64-128 GB (primary bottleneck for data nodes)
- **Disk**: 500 GB - 1 TB NVMe SSD (for logs and disk-based operations)
- **Network**: 25-100 Gbps (critical for inter-node communication)

#### SQL Nodes
- **CPU**: 16-32 cores
- **RAM**: 32-64 GB
- **Disk**: 500 GB SSD (for binary logs and temporary files)
- **Network**: 10-25 Gbps

#### Load Balancer (ProxySQL)
- **CPU**: 8-16 cores
- **RAM**: 16-32 GB
- **Disk**: 100 GB SSD
- **Network**: 10-25 Gbps

### Redis Nodes (for Queue)
- **CPU**: 8-16 cores
- **RAM**: 32-64 GB (sized to hold the queue)
- **Disk**: 100 GB SSD (for persistence)
- **Network**: 10-25 Gbps

## Memory Configuration

Data nodes store all data in memory, making memory configuration critical.

### Key Memory Parameters

1. **DataMemory**: Primary storage for table data
   - Formula: `Daily Records × Record Size × Retention Factor × Safety Factor / Number of Node Groups`
   - For 60 Crore records at ~1KB per record with 2-day retention:
     `600M × 1KB × 2 × 1.2 / 2 = ~720 GB` (distributed across node groups)

2. **IndexMemory**: Storage for indexes
   - Typically 20-25% of DataMemory
   - For the above example: ~180 GB

3. **SharedGlobalMemory**: For transaction handling
   - Formula: `(5-10% of DataMemory) + (MaxNoOfConcurrentTransactions × 1KB)`
   - For high throughput: 32-64 GB

### Configuration Example for High Throughput

```ini
[ndbd default]
NoOfReplicas=2
DataMemory=128G                     # Per data node (adjust based on node count)
IndexMemory=32G                     # Per data node
RedoBuffer=1G                       # Redo log buffer size
SharedGlobalMemory=16G              # Transaction memory

# Transaction handling for high throughput
MaxNoOfConcurrentOperations=4000000
MaxNoOfConcurrentTransactions=1000000
MaxNoOfLocalOperations=8000000
MaxDMLOperationsPerTransaction=100000
```

## Performance Tuning

### Critical Parameters for 1.5 Lac TPS

1. **Transaction Parameters**
   - `MaxNoOfConcurrentOperations`: 2-4 million
   - `MaxNoOfConcurrentTransactions`: 500K-1 million
   - `MaxNoOfLocalOperations`: 4-8 million
   - `MaxDMLOperationsPerTransaction`: 100K

2. **Thread Configuration**
   - `MaxNoOfExecutionThreads`: 16-32 (typically 2× CPU cores)
   - `ThreadConfig`: Fine-tune thread allocation (advanced)

3. **Batch Processing**
   - `ndb_batch_size`: 32K-128K (SQL node parameter)
   - `BatchSize`: 256-1024 (data node parameter)

4. **Network Tuning**
   - `SendBufferMemory`: 64-128 MB
   - `ReceiveBufferMemory`: 64-128 MB

### SQL Node Optimization

```ini
[mysqld]
# NDB Cluster optimizations
ndb_batch_size=65536
ndb_blob_read_batch_bytes=4194304
ndb_blob_write_batch_bytes=4194304

# Connection pool
max_connections=5000
thread_cache_size=256

# Query optimization
join_buffer_size=4M
sort_buffer_size=4M
```

### OS-Level Tuning

```bash
# File descriptor limits
echo "fs.file-max = 1000000" >> /etc/sysctl.conf
echo "* soft nofile 1000000" >> /etc/security/limits.conf
echo "* hard nofile 1000000" >> /etc/security/limits.conf

# Network tuning
echo "net.core.rmem_max = 16777216" >> /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" >> /etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 87380 16777216" >> /etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 65536 16777216" >> /etc/sysctl.conf
```

## High Availability and Failover

MySQL Cluster provides automatic failover through its distributed architecture.

### Failover Mechanisms

1. **Data Node Failover**
   - Data is automatically replicated across node groups
   - If a data node fails, its replica takes over automatically
   - No manual intervention required
   - Recovery time: Typically 5-30 seconds

2. **SQL Node Failover**
   - ProxySQL detects failed SQL nodes and redirects traffic
   - No data loss as data is stored in data nodes
   - Recovery time: 1-5 seconds

3. **Management Node Failover**
   - Secondary management node takes over
   - No impact on running operations
   - Only affects configuration changes

### Testing Failover

Regularly test failover scenarios:

```bash
# Simulate data node failure
docker stop ndbd1

# Simulate SQL node failure
docker stop mysql1

# Simulate management node failure
docker stop ndb_mgmd
```

### Monitoring Failover Events

```bash
# Check cluster status
ndb_mgm -e "show"

# View detailed node status
ndb_mgm -e "all status"

# Check cluster events
ndb_mgm -e "all report"
```

## Monitoring and Alerting

### Key Metrics to Monitor

1. **Cluster Health**
   - Node status (connected/disconnected)
   - Transaction success/abort rate
   - Replication status

2. **Resource Utilization**
   - DataMemory usage (critical - if full, node will shut down)
   - IndexMemory usage
   - CPU utilization
   - Network throughput between nodes

3. **Performance Metrics**
   - Transactions per second
   - Query latency
   - Connection count
   - Lock contention

### Monitoring Tools

1. **Prometheus & Grafana**
   - Set up MySQL exporters on each node
   - Create dashboards for key metrics
   - Configure alerts for critical thresholds

2. **MySQL Enterprise Monitor**
   - Commercial solution with comprehensive monitoring
   - Automatic advisors and recommendations

3. **Custom Scripts**
   - Use `ndb_mgm` to query cluster status
   - Parse and alert on log files

### Alert Thresholds

| Metric | Warning Threshold | Critical Threshold |
|--------|-------------------|-------------------|
| DataMemory Usage | 70% | 85% |
| IndexMemory Usage | 70% | 85% |
| Node Disconnection | Any | Multiple |
| Transaction Abort Rate | >1% | >5% |
| Query Latency | >100ms | >500ms |

## Backup and Recovery

### Backup Strategies

1. **Online Backups**
   ```bash
   # Create a backup
   ndb_mgm -e "START BACKUP"
   
   # Create a backup with wait completion
   ndb_mgm -e "START BACKUP WAIT COMPLETED"
   ```

2. **Scheduled Backups**
   - Create a cron job for daily backups
   ```bash
   # /etc/cron.d/mysql-cluster-backup
   0 2 * * * root ndb_mgm -e "START BACKUP WAIT COMPLETED" >> /var/log/mysql-backup.log 2>&1
   ```

3. **Binary Logs**
   - Enable binary logging on SQL nodes
   - Allows point-in-time recovery

### Recovery Procedures

1. **Full Cluster Recovery**
   ```bash
   # Stop all nodes
   ndb_mgm -e "SHUTDOWN"
   
   # Start management nodes
   systemctl start ndb_mgmd
   
   # Start data nodes
   systemctl start ndbd
   
   # Start SQL nodes
   systemctl start mysqld
   ```

2. **Restore from Backup**
   ```bash
   # Restore a backup (backup ID 1)
   ndb_restore --backupid=1 --restore-data --restore-meta -n 2 -b 1 -m
   ```

3. **Point-in-Time Recovery**
   - Restore full backup
   - Apply binary logs up to desired point

## Scaling Strategies

### Vertical Scaling

1. **Increase Memory**
   - Add more RAM to data nodes
   - Update `DataMemory` and `IndexMemory` parameters

2. **Add CPU Cores**
   - Increase `MaxNoOfExecutionThreads`
   - Update `ThreadConfig` for optimal thread distribution

### Horizontal Scaling

1. **Add Data Nodes**
   - Always add in pairs (for node groups)
   - Update management node configuration
   - Redistribute data (automatic but impacts performance)

2. **Add SQL Nodes**
   - Update ProxySQL configuration
   - No data redistribution needed

### Scaling Process

```bash
# 1. Update config.ini on management node
# 2. Restart management node
systemctl restart ndb_mgmd

# 3. Start new data nodes
systemctl start ndbd

# 4. Check cluster status
ndb_mgm -e "show"
```

## Common Operational Tasks

### Adding a New Data Node

1. Update the management node configuration:
   ```ini
   [ndbd]
   NodeId=6
   HostName=ndbd3
   DataDir=/var/lib/mysql
   ```

2. Restart the management node:
   ```bash
   systemctl restart ndb_mgmd
   ```

3. Start the new data node:
   ```bash
   systemctl start ndbd
   ```

4. Verify the node is connected:
   ```bash
   ndb_mgm -e "show"
   ```

### Adding a New SQL Node

1. Update the management node configuration:
   ```ini
   [mysqld]
   NodeId=7
   HostName=mysql3
   ```

2. Restart the management node:
   ```bash
   systemctl restart ndb_mgmd
   ```

3. Start the new SQL node:
   ```bash
   systemctl start mysqld
   ```

4. Update ProxySQL configuration:
   ```sql
   INSERT INTO mysql_servers(address,port,hostgroup_id) VALUES ('mysql3',3306,0);
   LOAD MYSQL SERVERS TO RUNTIME;
   SAVE MYSQL SERVERS TO DISK;
   ```

### Performing a Rolling Upgrade

1. Upgrade management nodes one by one:
   ```bash
   # On first management node
   systemctl stop ndb_mgmd
   # Upgrade software
   systemctl start ndb_mgmd
   
   # On second management node
   systemctl stop ndb_mgmd
   # Upgrade software
   systemctl start ndb_mgmd
   ```

2. Upgrade SQL nodes one by one:
   ```bash
   # On each SQL node
   systemctl stop mysqld
   # Upgrade software
   systemctl start mysqld
   ```

3. Upgrade data nodes one by one:
   ```bash
   # On each data node
   ndb_mgm -e "8 STOP" # Stop node 8
   # Upgrade software
   systemctl start ndbd
   # Wait for node to rejoin before stopping next node
   ```

## Troubleshooting

### Common Issues and Solutions

1. **Data Node Out of Memory**
   - **Symptoms**: Node shutdown, "DataMemory exhausted" in logs
   - **Solution**: Increase DataMemory, add more data nodes, or purge old data

2. **Slow Queries**
   - **Symptoms**: High latency, timeouts
   - **Solution**: Check query plans, add indexes, optimize table partitioning

3. **Node Connection Issues**
   - **Symptoms**: Nodes cannot connect to management node
   - **Solution**: Check network, firewall rules, hostname resolution

4. **Transaction Aborts**
   - **Symptoms**: High abort rate, application errors
   - **Solution**: Increase transaction timeouts, optimize transaction size

### Diagnostic Commands

```bash
# Check cluster status
ndb_mgm -e "show"

# Get detailed node status
ndb_mgm -e "all status"

# View cluster events
ndb_mgm -e "all report"

# Check memory usage
ndb_mgm -e "all report memory"

# View cluster configuration
ndb_config --config-file=/etc/mysql-cluster.cnf --query=nodeid,type,host --type=ndbd

# Check table fragmentation
ndb_desc -d test_db test_table --blob-info --extra-node-info
```

### Log Files to Monitor

1. **Management Node Logs**
   - Location: `/var/lib/mysql-cluster/ndb_*.log`
   - Contains: Cluster events, node status changes

2. **Data Node Logs**
   - Location: `/var/lib/mysql/ndb_*.log`
   - Contains: Memory usage, transaction issues, errors

3. **SQL Node Logs**
   - Location: `/var/log/mysqld.log`
   - Contains: Query errors, connection issues

## Edge Cases and Limitations

### Known Limitations

1. **Memory Constraints**
   - All data must fit in RAM
   - Running out of DataMemory causes node shutdown

2. **Transaction Limitations**
   - Maximum row size: ~14KB (effective ~8KB with overhead)
   - No support for SAVEPOINT
   - Limited support for foreign keys

3. **Query Limitations**
   - Complex JOINs across node groups can be slow
   - No full-text search
   - Limited support for subqueries

### Edge Cases to Watch For

1. **Memory Exhaustion**
   - Data nodes will shut down if they run out of DataMemory
   - Monitor memory usage closely and set alerts at 70-80%

2. **Network Partitions**
   - "Split-brain" scenarios can occur if network partitions happen
   - Use redundant network connections

3. **Backup Failures**
   - Backups can fail if disk space is insufficient
   - Monitor backup success/failure

4. **Schema Changes**
   - Online schema changes can be slow and resource-intensive
   - Plan maintenance windows for major schema changes

## Integration with Redis for High-Throughput Processing

### Architecture for 1.5 Lac TPS

```
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│   Producer    │────►│  Redis Queue  │◄────│   Consumer    │
│  Application  │     │  (In-Memory)  │     │   Services    │
└───────────────┘     └───────────────┘     └───────┬───────┘
                                                    │
                                                    ▼
                                            ┌───────────────┐
                                            │ MySQL Cluster │
                                            │  (CDR Data)   │
                                            └───────────────┘
```

### Redis Configuration for High Throughput

```conf
# /etc/redis/redis.conf
maxmemory 32gb
maxmemory-policy allkeys-lru
appendonly yes
appendfsync everysec
save 900 1
save 300 10
save 60 10000
```

### Consumer Design Patterns

1. **Multiple Consumer Groups**
   - Create separate consumer groups for different processing needs
   - Each record processed exactly once per group

2. **Parallel Processing**
   - Run multiple consumer instances
   - Each consumer handles a subset of the workload

3. **Batch Processing**
   - Process records in batches (1000-5000 records)
   - Use multi-row inserts for efficiency

### MySQL Table Design for CDR Data

```sql
CREATE TABLE cdr_records (
    id BIGINT NOT NULL AUTO_INCREMENT,
    timestamp DATETIME NOT NULL,
    caller_id VARCHAR(20) NOT NULL,
    recipient_id VARCHAR(20) NOT NULL,
    duration INT NOT NULL,
    service_type TINYINT NOT NULL,
    billing_type TINYINT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status TINYINT NOT NULL,
    region_id INT NOT NULL,
    -- Additional fields as needed
    PRIMARY KEY (id, timestamp),
    INDEX idx_caller (caller_id, timestamp),
    INDEX idx_recipient (recipient_id, timestamp),
    INDEX idx_region (region_id, timestamp)
) ENGINE=NDBCLUSTER
PARTITION BY RANGE (TO_DAYS(timestamp)) (
    PARTITION p_current VALUES LESS THAN (TO_DAYS(NOW())),
    PARTITION p_tomorrow VALUES LESS THAN (TO_DAYS(NOW() + INTERVAL 1 DAY)),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);
```

### Partitioning Strategy for 60 Crore Daily Records

1. **Time-Based Partitioning**
   - Partition by day or hour
   - Automate partition management

2. **Archiving Strategy**
   - Move older partitions to archive tables
   - Consider data warehousing solutions for historical analysis

3. **Maintenance Scripts**
   ```sql
   -- Create tomorrow's partition
   ALTER TABLE cdr_records REORGANIZE PARTITION p_future INTO (
       PARTITION p_tomorrow VALUES LESS THAN (TO_DAYS(NOW() + INTERVAL 1 DAY)),
       PARTITION p_future VALUES LESS THAN MAXVALUE
   );
   
   -- Archive old partitions (run daily)
   CREATE TABLE archive_cdr_records_20250505 LIKE cdr_records;
   ALTER TABLE archive_cdr_records_20250505 ENGINE=InnoDB;
   INSERT INTO archive_cdr_records_20250505 SELECT * FROM cdr_records PARTITION (p_current);
   ALTER TABLE cdr_records DROP PARTITION p_current;
   ```

## Conclusion

MySQL Cluster provides a robust solution for high-throughput applications requiring real-time processing and high availability. By properly configuring memory, optimizing for your workload, and implementing proper monitoring and maintenance procedures, you can successfully handle 1.5 Lac TPS and 60 Crore daily records.

This guide covers the essential aspects of MySQL Cluster from a DevOps perspective, but the technology is deep and complex. Continue to learn and experiment, especially with your specific workload patterns, to achieve optimal performance.

## Additional Resources

- [MySQL Cluster Official Documentation](https://dev.mysql.com/doc/refman/8.0/en/mysql-cluster.html)
- [ProxySQL Documentation](https://proxysql.com/documentation/)
- [Redis Documentation](https://redis.io/documentation)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
