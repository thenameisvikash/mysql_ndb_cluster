# MySQL Cluster DevOps Guide

As a DevOps engineer responsible for a MySQL Cluster deployment handling high-throughput workloads (1.5 Lac TPS and 600M daily records), this guide covers everything you need to know about MySQL Cluster from a DevOps perspective.

## Understanding MySQL Cluster Architecture

MySQL Cluster is a distributed, highly available database combining the MySQL server with the NDB (Network Database) storage engine. It consists of three main components:

1. **Management Nodes (ndb_mgmd)**: Control the cluster configuration
2. **Data Nodes (ndbd)**: Store and replicate data
3. **SQL Nodes (mysqld)**: Process SQL queries

![MySQL Cluster Architecture](https://dev.mysql.com/doc/refman/8.0/en/images/cluster-components-1.png)

## Key DevOps Considerations

### 1. Hardware Requirements

For your high-throughput requirements:

- **Management Node**: 2-4 CPU cores, 4-8GB RAM
- **Data Nodes**: 16+ CPU cores, 32-64GB RAM, SSD storage
- **SQL Nodes**: 8+ CPU cores, 16-32GB RAM
- **Network**: 10Gbps+ between all nodes (critical!)

### 2. Deployment Patterns

#### Production Deployment Pattern

For high availability in production:
- 2 Management nodes
- 4+ Data nodes (at least 2 node groups)
- 2+ SQL nodes
- Load balancer (ProxySQL/HAProxy)

#### Development/Testing Pattern

For development or testing:
- 1 Management node
- 2 Data nodes
- 1-2 SQL nodes

### 3. Memory Configuration

Data nodes are in-memory databases and require careful memory sizing:

- **DataMemory**: Size of all data stored in-memory (your primary concern)
- **IndexMemory**: Size of all indexes (typically 20% of DataMemory)
- **Shared Global Memory**: Transaction memory

Formula for 600M daily records with ~1KB per record:
```
DataMemory = Daily Records × Record Size × Retention Factor × Safety Factor
           = 600M × 1KB × 1.5 × 1.2 = ~1.1TB
```

Split this across your data nodes, with at least 2x replication.

### 4. Scaling Strategies

#### Vertical Scaling

- Increase RAM on data nodes (primary bottleneck)
- Add more CPU cores for concurrent operations

#### Horizontal Scaling

- Add more data nodes (in node groups of 2 for NoOfReplicas=2)
- Add more SQL nodes for query processing

### 5. Monitoring & Alerting

Critical metrics to monitor:

- **Memory Usage**: DataMemory and IndexMemory utilization
- **Disk Space**: For log files and backups
- **CPU Usage**: Especially on data nodes
- **Network**: Inter-node communication
- **Query Performance**: Slow queries and throughput
- **Connection Count**: Active connections to SQL nodes

Tools:
- Prometheus + Grafana (configured in docker-compose)
- MySQL Enterprise Monitor
- MySQL Cluster Manager

### 6. Backup & Recovery

#### Regular Backups

```bash
# Run from management node
ndb_mgm -e "START BACKUP"
```

#### Point-in-Time Recovery

Combine NDB backups with binary logs from SQL nodes.

#### Backup Strategy

- Daily full backups of NDB data
- Binary logging on SQL nodes
- Test restores regularly

### 7. High Availability Features

- **Automatic Failover**: Cluster handles node failures automatically
- **Online Operations**: Add/remove nodes without downtime
- **Geographic Distribution**: Can span multiple data centers

### 8. Performance Tuning

#### Key Performance Parameters

- **MaxNoOfConcurrentOperations**: Set high for your 1.5 Lac TPS
- **MaxNoOfExecutionThreads**: Usually 2× the number of CPU cores
- **BatchSize**: For bulk operations
- **FragmentLogFileSize**: For write-heavy workloads

#### Common Bottlenecks

- Insufficient DataMemory
- Network bandwidth between nodes
- Single-threaded operations
- Poor table partitioning

### 9. Sharding Considerations

MySQL Cluster implements automatic sharding through:

1. **Table Partitioning**: Data is distributed across data nodes
2. **User-Defined Partitioning**: Tables can be further partitioned

For your CDR application with 600M daily records:
- Partition tables by date range
- Distribute tables across node groups

### 10. Failover Testing

Regularly test failure scenarios:
- Management node failure
- Data node failure
- SQL node failure
- Network partition
- Full datacenter outage

### 11. Operational Procedures

#### Adding a Data Node

1. Update config on management node
2. Start new data node
3. Execute `ndb_mgm -e "ALL STATUS"` to verify

#### Rolling Upgrades

1. Upgrade management nodes
2. Upgrade SQL nodes one-by-one
3. Upgrade data nodes one-by-one

#### Daily Checks

- Review cluster logs
- Check memory usage
- Verify backup completion
- Validate replication status

## MySQL Cluster vs. Traditional MySQL Replication

| Feature | MySQL Cluster | Traditional Replication |
|---------|---------------|------------------------|
| Consistency | Synchronous | Asynchronous |
| Availability | Automatic failover | Manual/semi-automatic |
| Partitioning | Automatic sharding | Manual sharding |
| Memory Usage | In-memory storage | Disk-based with buffer |
| Latency | Microseconds | Milliseconds |
| Scaling | Linear scaling | Master-slave bottleneck |
| Use Case | High throughput OLTP | Mixed OLTP/OLAP |

## Tradeoffs and Edge Cases

### Pros of MySQL Cluster

- Extreme high availability (99.999%)
- Linear scalability for read/write operations
- In-memory performance
- Automatic sharding and load balancing

### Cons and Limitations

- High memory requirements (all data in RAM)
- Network-intensive between nodes
- Limited JOIN performance across node groups
- Smaller maximum row size than InnoDB (~8KB effective)
- No full-text search support
- Higher operational complexity

### Edge Cases to Watch For

1. **Memory Exhaustion**: Data nodes will shut down if they run out of DataMemory
2. **Network Partitions**: "Split-brain" scenarios possible with poor network
3. **Large Transactions**: Can cause timeouts and connection drops
4. **Long-running Queries**: Can block operations
5. **Schema Changes**: Some operations require cluster restart

## Deployment Steps with Docker Compose

1. Create necessary directories:
```bash
mkdir -p config
```

2. Create configuration files as defined in the artifacts

3. Deploy the cluster:
```bash
docker-compose up -d
```

4. Verify cluster status:
```bash
docker-compose exec ndb_mgmd ndb_mgm -e "SHOW"
```

5. Initialize database schema (let your developers handle this part)

## Conclusion

MySQL Cluster is well-suited for your high-throughput CDR processing requirements. The key to success is proper sizing of memory resources, network capacity, and regular monitoring of cluster health. With the provided Docker Compose setup and understanding of operational concerns, you'll be well-positioned to support the 1.5 Lac TPS and 600M daily records requirements.
