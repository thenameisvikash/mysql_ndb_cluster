# Performance Tuning Guide

[← Troubleshooting](troubleshooting.md) | [Documentation Index](../DOCUMENTATION.md) | [Architecture →](architecture.md)

*Related: [High Throughput Architecture](../High_Throughput_Architecture.md) | [Optimized Architecture](../Optimized_Architecture.md)*

This guide provides recommendations for optimizing the performance of your MySQL Cluster with ProxySQL setup.

## Performance Benchmarks

The default configuration is designed to handle:
- Up to 150,000 transactions per second (TPS)
- Up to 600 million daily records
- Sub-millisecond query response times for simple queries

## Key Performance Factors

### 1. Hardware Resources

The performance of your MySQL Cluster depends significantly on the hardware resources allocated:

| Component | CPU | Memory | Disk | Network |
|-----------|-----|--------|------|---------|
| Data Nodes | 4+ cores | 4GB+ | Fast SSD | 10Gbps+ |
| SQL Nodes | 2+ cores | 2GB+ | Fast SSD | 10Gbps+ |
| ProxySQL | 2+ cores | 2GB+ | Fast SSD | 10Gbps+ |

#### Recommendations:

- **Data Nodes**: Prioritize memory and network bandwidth
- **SQL Nodes**: Prioritize CPU and network bandwidth
- **ProxySQL**: Prioritize CPU for query routing

### 2. Memory Configuration

MySQL Cluster stores all data in memory, making memory configuration critical:

#### Data Node Memory

```ini
[ndbd default]
DataMemory=512M               # Memory for data storage
IndexMemory=128M              # Memory for indexes
```

**Calculation Guidelines:**
- DataMemory: Estimate your total data size and multiply by 1.2
- IndexMemory: Typically 20-25% of DataMemory

#### SQL Node Memory

```ini
[mysqld]
table_open_cache=4000         # Number of open tables
join_buffer_size=2M           # Memory for joins
sort_buffer_size=2M           # Memory for sorting
```

#### ProxySQL Memory

```ini
mysql-max_connections=2000    # Maximum client connections
mysql-thread_pool_max_threads=64  # Worker threads
```

### 3. Connection Pooling

ProxySQL's connection pooling significantly improves performance by reducing the overhead of establishing new connections:

```ini
mysql-connection_pool_size=100  # Connections per backend server
mysql-free_connections_pct=10   # Percentage to keep free
```

**Optimization Tips:**
- Set connection_pool_size to handle your peak load
- Monitor connection usage with `stats_mysql_connection_pool`
- Adjust based on the number of concurrent clients

### 4. Query Routing

Efficient query routing ensures optimal utilization of your cluster:

```ini
mysql_query_rules:
(
    { rule_id=1, active=1, match_digest="^SELECT.*FOR UPDATE.*", destination_hostgroup=0, apply=1 },
    { rule_id=2, active=1, match_digest="^SELECT.*", destination_hostgroup=10, apply=1 },
    { rule_id=3, active=1, match_digest=".*", destination_hostgroup=0, apply=1 }
)
```

**Optimization Tips:**
- Route read-only queries to hostgroup 10
- Route write queries to hostgroup 0
- Consider adding specialized rules for frequently executed queries

### 5. Data Node Configuration

Data node configuration affects both performance and reliability:

```ini
[ndbd default]
MaxNoOfConcurrentOperations=1000000  # Max concurrent operations
MaxNoOfConcurrentTransactions=1000000  # Max concurrent transactions
RedoBuffer=64M                # Memory for redo log
```

**Optimization Tips:**
- Increase MaxNoOfConcurrentOperations for high-throughput workloads
- Set RedoBuffer based on your write intensity
- Monitor data node CPU and memory usage

## Performance Monitoring

### ProxySQL Metrics

Monitor ProxySQL performance with these queries:

```sql
-- Query Statistics
SELECT digest_text, count_star, sum_time, hostgroup 
FROM stats_mysql_query_digest 
ORDER BY sum_time DESC LIMIT 10;

-- Connection Pool Statistics
SELECT * FROM stats_mysql_connection_pool;

-- Command Counters
SELECT * FROM stats_mysql_commands_counters;
```

### MySQL Cluster Metrics

Monitor MySQL Cluster performance with these commands:

```bash
# Memory usage
docker exec -it management1 ndb_mgm -e "all report memory" --ndb-connectstring=172.20.0.2:1186

# Transaction statistics
docker exec -it mysql1 mysql -uroot -prootpassword -e "SHOW ENGINE NDBCLUSTER STATUS\G" | grep -A 10 "latest_epoch"

# Cluster operations
docker exec -it management1 ndb_mgm -e "all report OperationReply" --ndb-connectstring=172.20.0.2:1186
```

## Performance Tuning Scenarios

### Scenario 1: High Read Workload

If your application is read-heavy:

1. Add more SQL nodes for read scaling:
   ```yaml
   mysql3:
     image: mysql/mysql-cluster:8.0.32
     command: mysqld
   ```

2. Adjust ProxySQL weights to distribute read traffic:
   ```ini
   mysql_servers:
   (
       { address="mysql1", port=3306, hostgroup=10, weight=100 },
       { address="mysql2", port=3306, hostgroup=10, weight=100 },
       { address="mysql3", port=3306, hostgroup=10, weight=200 }  # Higher weight for dedicated read node
   )
   ```

3. Consider adding query caching in ProxySQL:
   ```ini
   mysql_query_rules:
   (
       { rule_id=1, active=1, match_digest="^SELECT.*FROM frequently_read_table.*", cache_ttl=60000, apply=1 }
   )
   ```

### Scenario 2: High Write Workload

If your application is write-heavy:

1. Increase data node resources:
   ```ini
   [ndbd default]
   DataMemory=1024M
   RedoBuffer=128M
   ```

2. Add more data node groups for write scaling:
   ```ini
   [ndbd]
   NodeId=10
   hostname=ndb5
   
   [ndbd]
   NodeId=11
   hostname=ndb6
   ```

3. Optimize transaction batching in your application:
   ```sql
   START TRANSACTION;
   -- Multiple INSERT/UPDATE statements
   COMMIT;
   ```

### Scenario 3: Mixed Workload with Hot Spots

If you have tables that are accessed more frequently:

1. Create specialized query rules:
   ```ini
   mysql_query_rules:
   (
       { rule_id=1, active=1, match_digest="^SELECT.*FROM hot_table.*", destination_hostgroup=11, apply=1 }
   )
   ```

2. Dedicate SQL nodes for hot tables:
   ```ini
   mysql_servers:
   (
       { address="mysql3", port=3306, hostgroup=11, max_connections=2000 }
   )
   ```

## Query Optimization

### 1. Index Optimization

Ensure proper indexes for your queries:

```sql
-- Check if a query uses indexes
EXPLAIN SELECT * FROM test_table WHERE id = 1;

-- Add an index if needed
ALTER TABLE test_table ADD INDEX idx_column_name (column_name);
```

### 2. Query Rewriting

Optimize slow queries:

```sql
-- Before: Slow query
SELECT * FROM large_table WHERE created_at > '2025-01-01';

-- After: Optimized query with limit
SELECT * FROM large_table WHERE created_at > '2025-01-01' LIMIT 1000;
```

### 3. Batch Operations

Use batch operations for better performance:

```sql
-- Before: Multiple single inserts
INSERT INTO test_table (data) VALUES ('row1');
INSERT INTO test_table (data) VALUES ('row2');

-- After: Batch insert
INSERT INTO test_table (data) VALUES ('row1'), ('row2'), ('row3');
```

## Scaling Strategies

### Vertical Scaling

Increase resources for existing nodes:

1. Update Docker Compose resource limits:
   ```yaml
   services:
     ndb1:
       deploy:
         resources:
           limits:
             cpus: '2'
             memory: 4G
   ```

2. Increase memory allocation in configuration:
   ```ini
   [ndbd default]
   DataMemory=1024M
   IndexMemory=256M
   ```

### Horizontal Scaling

Add more nodes to the cluster:

1. Add more data node groups for increased storage capacity
2. Add more SQL nodes for increased query processing capacity
3. Add more ProxySQL instances for increased connection capacity

## Performance Testing

Use the included test suite to benchmark performance:

```bash
# Run performance tests
./mysql_cluster_test_suite.sh performance

# Customize test data size
TEST_DATA_SIZE=1000 ./mysql_cluster_test_suite.sh performance
```

## Advanced Optimization Techniques

### 1. Partitioning

Use partitioning for large tables:

```sql
CREATE TABLE partitioned_table (
    id INT NOT NULL AUTO_INCREMENT,
    data VARCHAR(255),
    created_at DATETIME,
    PRIMARY KEY (id, created_at)
) ENGINE=NDBCLUSTER
PARTITION BY RANGE (TO_DAYS(created_at)) (
    PARTITION p0 VALUES LESS THAN (TO_DAYS('2025-01-01')),
    PARTITION p1 VALUES LESS THAN (TO_DAYS('2025-02-01')),
    PARTITION p2 VALUES LESS THAN (TO_DAYS('2025-03-01')),
    PARTITION p3 VALUES LESS THAN MAXVALUE
);
```

### 2. Disk Data Tables

For very large datasets, consider using disk data tables:

```sql
CREATE TABLESPACE ts1
ADD DATAFILE 'ts1_data.dat'
USE LOGFILE GROUP lg1
INITIAL_SIZE 512M
ENGINE NDBCLUSTER;

CREATE TABLE disk_table (
    id INT NOT NULL AUTO_INCREMENT,
    data VARCHAR(255),
    PRIMARY KEY (id)
) ENGINE=NDBCLUSTER
TABLESPACE ts1 STORAGE DISK;
```

### 3. Multi-Threaded Data Nodes

Enable multi-threaded data nodes for better CPU utilization:

```ini
[ndbd default]
MaxNoOfExecutionThreads=8
```

## Common Performance Issues and Solutions

### Issue: High CPU Usage on Data Nodes

**Possible Causes:**
- Too many concurrent operations
- Inefficient queries
- Insufficient CPU resources

**Solutions:**
- Increase MaxNoOfExecutionThreads
- Optimize queries
- Add more data nodes or increase CPU allocation

### Issue: High Memory Usage on Data Nodes

**Possible Causes:**
- DataMemory or IndexMemory too small
- Too many concurrent transactions
- Memory leaks

**Solutions:**
- Increase DataMemory and IndexMemory
- Monitor memory usage with `all report memory`
- Add more data nodes to distribute data

### Issue: Slow Query Response Times

**Possible Causes:**
- Missing indexes
- Inefficient query routing
- Connection pool exhaustion

**Solutions:**
- Add appropriate indexes
- Optimize ProxySQL query rules
- Increase connection pool size

### Issue: Connection Errors Under Load

**Possible Causes:**
- Insufficient max_connections
- Thread pool exhaustion
- Network issues

**Solutions:**
- Increase max_connections in MySQL and ProxySQL
- Increase thread_pool_max_threads
- Check network connectivity and latency
