# Performance Tuning

[← Monitoring and Observability](monitoring.md) | [Documentation Index](../index.md) | [Scaling →](scaling.md)

*Related: [Configuration Overview](../configuration/overview.md) | [Troubleshooting Performance Issues](../troubleshooting/performance-issues.md)*

This document provides comprehensive guidance on performance tuning for your MySQL Cluster with ProxySQL deployment.

## Performance Tuning Methodology

Effective performance tuning follows a systematic approach:

1. **Establish Baselines**: Measure current performance under typical workloads
2. **Identify Bottlenecks**: Use monitoring to identify performance bottlenecks
3. **Implement Changes**: Make targeted configuration changes
4. **Measure Impact**: Evaluate the impact of changes
5. **Iterate**: Repeat the process for continuous improvement

## System-Level Tuning

### CPU Optimization

1. **CPU Frequency Scaling**:
   - Set CPU governor to "performance" mode:
     ```bash
     for CPU in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
       echo performance > $CPU
     done
     ```

2. **Process Scheduling**:
   - Set MySQL and ProxySQL process priorities:
     ```bash
     sudo renice -10 $(pgrep -x mysqld)
     sudo renice -10 $(pgrep -x proxysql)
     ```

3. **CPU Affinity**:
   - Bind MySQL and ProxySQL processes to specific CPUs:
     ```bash
     # Bind MySQL to CPUs 0-3
     sudo taskset -pc 0-3 $(pgrep -x mysqld)
     
     # Bind ProxySQL to CPUs 4-7
     sudo taskset -pc 4-7 $(pgrep -x proxysql)
     ```

### Memory Optimization

1. **Swappiness**:
   - Reduce swappiness to minimize swapping:
     ```bash
     sudo sysctl -w vm.swappiness=10
     ```

2. **Transparent Huge Pages**:
   - Disable transparent huge pages:
     ```bash
     sudo echo never > /sys/kernel/mm/transparent_hugepage/enabled
     sudo echo never > /sys/kernel/mm/transparent_hugepage/defrag
     ```

3. **Memory Overcommit**:
   - Disable memory overcommit:
     ```bash
     sudo sysctl -w vm.overcommit_memory=2
     sudo sysctl -w vm.overcommit_ratio=80
     ```

### Disk I/O Optimization

1. **I/O Scheduler**:
   - Use the appropriate I/O scheduler:
     ```bash
     # For SSDs
     echo noop > /sys/block/sda/queue/scheduler
     
     # For HDDs
     echo deadline > /sys/block/sda/queue/scheduler
     ```

2. **Readahead**:
   - Optimize readahead settings:
     ```bash
     sudo blockdev --setra 256 /dev/sda
     ```

3. **File System**:
   - Use XFS or ext4 with appropriate mount options:
     ```bash
     # XFS mount options
     mount -o noatime,nodiratime,logbufs=8,logbsize=256k,nobarrier /dev/sda1 /var/lib/mysql
     
     # ext4 mount options
     mount -o noatime,nodiratime,data=writeback,barrier=0,nobh,errors=remount-ro /dev/sda1 /var/lib/mysql
     ```

### Network Optimization

1. **TCP Settings**:
   - Optimize TCP settings:
     ```bash
     sudo sysctl -w net.core.somaxconn=4096
     sudo sysctl -w net.ipv4.tcp_max_syn_backlog=4096
     sudo sysctl -w net.core.netdev_max_backlog=4096
     sudo sysctl -w net.ipv4.tcp_fin_timeout=15
     sudo sysctl -w net.ipv4.tcp_keepalive_time=300
     sudo sysctl -w net.ipv4.tcp_keepalive_intvl=60
     sudo sysctl -w net.ipv4.tcp_keepalive_probes=5
     ```

2. **Network Interface**:
   - Enable jumbo frames if supported:
     ```bash
     sudo ip link set eth0 mtu 9000
     ```

3. **Network Buffers**:
   - Increase network buffer sizes:
     ```bash
     sudo sysctl -w net.core.rmem_max=16777216
     sudo sysctl -w net.core.wmem_max=16777216
     sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
     sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
     ```

## MySQL Cluster Tuning

### Data Node Configuration

1. **Memory Allocation**:
   ```ini
   [ndbd default]
   # Total memory allocated for data storage
   DataMemory=10G
   
   # Total memory allocated for indexes
   IndexMemory=2G
   
   # Transaction memory
   TransactionMemory=1G
   
   # Disk page buffer memory
   DiskPageBufferMemory=64M
   
   # Shared global memory
   SharedGlobalMemory=128M
   ```

2. **Transaction Handling**:
   ```ini
   [ndbd default]
   # Maximum number of parallel transactions
   MaxNoOfConcurrentTransactions=16384
   
   # Maximum number of concurrent operations
   MaxNoOfConcurrentOperations=100000
   
   # Maximum number of local operations
   MaxNoOfLocalOperations=32768
   
   # Maximum number of concurrent scans
   MaxNoOfConcurrentScans=500
   ```

3. **Disk Data Settings**:
   ```ini
   [ndbd default]
   # Disk data file settings
   InitialLogFileGroup=1
   InitialTablespace=1
   
   # Undo log buffer size
   UndoDataBuffer=16M
   UndoIndexBuffer=2M
   ```

4. **Timeouts and Heartbeats**:
   ```ini
   [ndbd default]
   # Heartbeat interval between data nodes
   HeartbeatIntervalDbDb=1500
   
   # Heartbeat interval between data and API nodes
   HeartbeatIntervalDbApi=1500
   
   # Transaction deadlock detection timeout
   TransactionDeadlockDetectionTimeout=1200
   
   # Transaction inactive timeout
   TransactionInactiveTimeout=0
   ```

### SQL Node Configuration

1. **Buffer Pool**:
   ```ini
   [mysqld]
   # InnoDB buffer pool size (if using InnoDB tables)
   innodb_buffer_pool_size=1G
   
   # InnoDB buffer pool instances
   innodb_buffer_pool_instances=8
   ```

2. **Thread Handling**:
   ```ini
   [mysqld]
   # Thread cache size
   thread_cache_size=64
   
   # Maximum connections
   max_connections=1000
   
   # Thread stack size
   thread_stack=256K
   ```

3. **Query Cache**:
   ```ini
   [mysqld]
   # Disable query cache for NDB Cluster
   query_cache_size=0
   query_cache_type=0
   ```

4. **Temporary Tables**:
   ```ini
   [mysqld]
   # Temporary table size
   tmp_table_size=64M
   
   # Maximum heap table size
   max_heap_table_size=64M
   ```

5. **NDB-Specific Settings**:
   ```ini
   [mysqld]
   # NDB batch size
   ndb_batch_size=32768
   
   # NDB cluster connection pool size
   ndb_cluster_connection_pool=8
   
   # NDB index statistics
   ndb_index_stat_enable=1
   
   # NDB autoincrement prefetch size
   ndb_autoincrement_prefetch_sz=256
   
   # NDB use exact count (disable for better performance)
   ndb_use_exact_count=0
   
   # NDB force send
   ndb_force_send=1
   ```

### ProxySQL Tuning

1. **Thread Configuration**:
   ```ini
   mysql_variables=
   {
     # Number of worker threads
     threads=8
     
     # Maximum connections
     max_connections=2048
     
     # Stack size for threads
     stacksize=1048576
   }
   ```

2. **Connection Pooling**:
   ```ini
   mysql_servers=
   (
     {
       address="mysql1",
       port=3306,
       hostgroup=0,
       max_connections=200,
       max_replication_lag=10,
       weight=1000
     }
   )
   ```

3. **Query Cache**:
   ```ini
   mysql_variables=
   {
     # Query cache size
     query_cache_size_MB=256
   }
   
   mysql_query_rules=
   (
     {
       rule_id=1,
       active=1,
       match_digest="^SELECT .* FROM static_data",
       cache_ttl=3600000,
       destination_hostgroup=10,
       apply=1
     }
   )
   ```

4. **Query Routing**:
   ```ini
   mysql_query_rules=
   (
     # Route SELECT queries to read hostgroup
     {
       rule_id=1,
       active=1,
       match_digest="^SELECT",
       destination_hostgroup=10,
       apply=1
     },
     
     # Route long-running queries to dedicated hostgroup
     {
       rule_id=2,
       active=1,
       match_digest="^SELECT .* FROM large_table",
       destination_hostgroup=20,
       apply=1
     }
   )
   ```

## Schema and Query Optimization

### Table Design

1. **Partitioning**:
   - Partition large tables to improve performance:
     ```sql
     CREATE TABLE orders (
       id INT NOT NULL AUTO_INCREMENT,
       customer_id INT NOT NULL,
       order_date DATE NOT NULL,
       total DECIMAL(10,2) NOT NULL,
       PRIMARY KEY (id, order_date)
     ) ENGINE=NDBCLUSTER
     PARTITION BY RANGE (TO_DAYS(order_date)) (
       PARTITION p_2023_01 VALUES LESS THAN (TO_DAYS('2023-02-01')),
       PARTITION p_2023_02 VALUES LESS THAN (TO_DAYS('2023-03-01')),
       PARTITION p_2023_03 VALUES LESS THAN (TO_DAYS('2023-04-01')),
       PARTITION p_future VALUES LESS THAN MAXVALUE
     );
     ```

2. **Indexing Strategy**:
   - Create appropriate indexes for common queries:
     ```sql
     -- Index for frequent lookups
     CREATE INDEX idx_customer_id ON orders(customer_id);
     
     -- Index for range queries
     CREATE INDEX idx_order_date ON orders(order_date);
     
     -- Composite index for common joins
     CREATE INDEX idx_customer_date ON orders(customer_id, order_date);
     ```

3. **Data Types**:
   - Use appropriate data types to minimize storage and improve performance:
     ```sql
     -- Use TINYINT for small ranges
     CREATE TABLE status (
       status_id TINYINT UNSIGNED NOT NULL,
       status_name VARCHAR(20) NOT NULL,
       PRIMARY KEY (status_id)
     ) ENGINE=NDBCLUSTER;
     
     -- Use fixed-length fields for better performance
     CREATE TABLE fixed_data (
       id INT NOT NULL,
       data CHAR(10) NOT NULL,
       PRIMARY KEY (id)
     ) ENGINE=NDBCLUSTER;
     ```

### Query Optimization

1. **EXPLAIN Analysis**:
   - Use EXPLAIN to analyze query execution plans:
     ```sql
     EXPLAIN SELECT * FROM orders WHERE customer_id = 123 AND order_date > '2023-01-01';
     ```

2. **Query Rewriting**:
   - Rewrite inefficient queries:
     ```sql
     -- Before
     SELECT * FROM orders WHERE YEAR(order_date) = 2023;
     
     -- After (more efficient)
     SELECT * FROM orders WHERE order_date >= '2023-01-01' AND order_date < '2024-01-01';
     ```

3. **Limit Result Sets**:
   - Use LIMIT to restrict result sets:
     ```sql
     SELECT * FROM large_table WHERE condition LIMIT 100;
     ```

4. **Avoid SELECT ***:
   - Select only needed columns:
     ```sql
     -- Before
     SELECT * FROM customers JOIN orders ON customers.id = orders.customer_id;
     
     -- After
     SELECT customers.name, orders.order_date, orders.total 
     FROM customers JOIN orders ON customers.id = orders.customer_id;
     ```

## Workload-Specific Tuning

### OLTP Workloads

1. **Configuration Priorities**:
   - Optimize for high transaction throughput
   - Minimize transaction latency
   - Ensure consistent response times

2. **Key Settings**:
   ```ini
   [ndbd default]
   # Increase transaction memory
   TransactionMemory=2G
   
   # Increase concurrent transactions
   MaxNoOfConcurrentTransactions=32768
   
   # Increase concurrent operations
   MaxNoOfConcurrentOperations=200000
   
   [mysqld]
   # Optimize for OLTP
   max_connections=2000
   thread_cache_size=100
   innodb_flush_log_at_trx_commit=1
   ```

3. **ProxySQL Configuration**:
   ```ini
   mysql_variables=
   {
     # Increase threads for OLTP
     threads=16
     
     # Optimize connection handling
     connect_timeout_server=1000
     ping_interval_server_msec=5000
     ping_timeout_server=200
   }
   ```

### OLAP Workloads

1. **Configuration Priorities**:
   - Optimize for complex queries
   - Maximize scan performance
   - Support large result sets

2. **Key Settings**:
   ```ini
   [ndbd default]
   # Increase scan buffer
   DiskPageBufferMemory=1G
   
   # Increase concurrent scans
   MaxNoOfConcurrentScans=1000
   
   # Increase batch size
   BatchSizePerLocalScan=256
   
   [mysqld]
   # Optimize for OLAP
   join_buffer_size=1M
   sort_buffer_size=4M
   read_buffer_size=1M
   read_rnd_buffer_size=1M
   ```

3. **ProxySQL Configuration**:
   ```ini
   mysql_variables=
   {
     # Increase timeout for long queries
     default_query_timeout=3600000
     
     # Increase result set size
     default_max_resultset_size=100000000
   }
   
   # Create dedicated hostgroup for analytics
   mysql_servers=
   (
     {
       address="mysql1",
       port=3306,
       hostgroup=20,
       max_connections=50,
       max_replication_lag=60,
       weight=1000
     }
   )
   
   mysql_query_rules=
   (
     {
       rule_id=10,
       active=1,
       match_digest="^SELECT .* FROM analytics_",
       destination_hostgroup=20,
       apply=1
     }
   )
   ```

### Mixed Workloads

1. **Configuration Priorities**:
   - Balance OLTP and OLAP requirements
   - Isolate workloads where possible
   - Prevent resource contention

2. **Key Settings**:
   ```ini
   [ndbd default]
   # Balance memory allocation
   DataMemory=16G
   IndexMemory=4G
   TransactionMemory=2G
   DiskPageBufferMemory=512M
   
   # Balance transaction and scan settings
   MaxNoOfConcurrentTransactions=16384
   MaxNoOfConcurrentOperations=100000
   MaxNoOfConcurrentScans=500
   ```

3. **ProxySQL Configuration**:
   - Use query rules to route different query types to different hostgroups:
     ```ini
     mysql_query_rules=
     (
       # OLTP queries to hostgroup 0
       {
         rule_id=1,
         active=1,
         match_digest="^(INSERT|UPDATE|DELETE)",
         destination_hostgroup=0,
         apply=1
       },
       
       # Simple SELECT queries to hostgroup 10
       {
         rule_id=2,
         active=1,
         match_digest="^SELECT .* FROM (users|products|orders)",
         destination_hostgroup=10,
         apply=1
       },
       
       # Complex analytical queries to hostgroup 20
       {
         rule_id=3,
         active=1,
         match_digest="^SELECT .* (JOIN|GROUP BY|ORDER BY).*",
         destination_hostgroup=20,
         apply=1
       }
     )
     ```

## Performance Testing

### Benchmarking Tools

1. **sysbench**:
   - Install and run sysbench:
     ```bash
     # Install sysbench
     apt-get install sysbench
     
     # Prepare test database
     sysbench oltp_read_write --tables=10 --table-size=1000000 --mysql-db=test --mysql-user=root --mysql-password=password prepare
     
     # Run benchmark
     sysbench oltp_read_write --tables=10 --table-size=1000000 --threads=16 --time=60 --mysql-db=test --mysql-user=root --mysql-password=password run
     ```

2. **mysqlslap**:
   - Run mysqlslap for concurrency testing:
     ```bash
     # Simple concurrency test
     mysqlslap --concurrency=50,100,200 --iterations=3 --number-int-cols=2 --number-char-cols=3 --auto-generate-sql --auto-generate-sql-add-autoincrement --auto-generate-sql-load-type=mixed --engine=ndbcluster --host=localhost --user=root --password=password
     
     # Test with specific queries
     mysqlslap --concurrency=50 --iterations=3 --query="SELECT * FROM orders WHERE customer_id=? AND order_date > ?" --number-of-queries=1000 --host=localhost --user=root --password=password
     ```

3. **Custom Load Testing**:
   - Create custom scripts to simulate real workloads:
     ```python
     import mysql.connector
     import random
     import time
     from concurrent.futures import ThreadPoolExecutor
     
     def execute_query(i):
         conn = mysql.connector.connect(
             host="localhost",
             user="root",
             password="password",
             database="test"
         )
         cursor = conn.cursor()
         
         # Simulate mixed workload
         if i % 10 == 0:
             # Complex query
             cursor.execute("SELECT customer_id, COUNT(*), SUM(total) FROM orders GROUP BY customer_id ORDER BY SUM(total) DESC LIMIT 10")
         else:
             # Simple query
             customer_id = random.randint(1, 1000)
             cursor.execute(f"SELECT * FROM orders WHERE customer_id = {customer_id} LIMIT 10")
             
         cursor.fetchall()
         cursor.close()
         conn.close()
     
     # Execute with concurrency
     with ThreadPoolExecutor(max_workers=50) as executor:
         for i in range(1000):
             executor.submit(execute_query, i)
     ```

### Performance Monitoring During Tests

1. **System Monitoring**:
   - Monitor system resources during tests:
     ```bash
     # Install monitoring tools
     apt-get install sysstat
     
     # Monitor CPU, memory, disk, network
     sar -u -r -d -n DEV 1 3600 > performance_test_system.log
     ```

2. **MySQL Monitoring**:
   - Monitor MySQL performance during tests:
     ```sql
     -- Before test
     SHOW GLOBAL STATUS LIKE 'Com_%';
     SHOW GLOBAL STATUS LIKE 'Handler_%';
     SHOW GLOBAL STATUS LIKE 'Innodb_%';
     
     -- After test
     SHOW GLOBAL STATUS LIKE 'Com_%';
     SHOW GLOBAL STATUS LIKE 'Handler_%';
     SHOW GLOBAL STATUS LIKE 'Innodb_%';
     ```

3. **ProxySQL Monitoring**:
   - Monitor ProxySQL during tests:
     ```sql
     -- Connect to ProxySQL admin
     mysql -h127.0.0.1 -P6032 -uradmin -pradmin
     
     -- Before test
     SELECT * FROM stats_mysql_global;
     
     -- After test
     SELECT * FROM stats_mysql_global;
     
     -- Query routing statistics
     SELECT * FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 20;
     ```

## Performance Tuning Scenarios

### Scenario 1: High CPU Usage

**Symptoms**:
- High CPU usage on data nodes
- Queries taking longer than expected
- System load average consistently high

**Solutions**:
1. **Identify CPU-intensive queries**:
   ```sql
   -- Find slow queries
   SELECT * FROM mysql.slow_log ORDER BY query_time DESC LIMIT 10;
   
   -- Check ProxySQL query digest
   SELECT * FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10;
   ```

2. **Optimize queries**:
   - Add appropriate indexes
   - Rewrite inefficient queries
   - Use EXPLAIN to analyze execution plans

3. **Adjust configuration**:
   ```ini
   [ndbd default]
   # Reduce batch size to decrease CPU usage
   BatchSizePerLocalScan=128
   
   # Adjust thread priority
   SchedulerSpinTimer=400
   ```

4. **Scale resources**:
   - Add more CPU cores
   - Distribute load across more nodes

### Scenario 2: Memory Pressure

**Symptoms**:
- Out of memory errors in data node logs
- Swapping activity on system
- Performance degradation over time

**Solutions**:
1. **Identify memory usage**:
   ```bash
   # Check memory usage in cluster
   ndb_mgm -e "all report memory"
   
   # Check system memory
   free -m
   ```

2. **Adjust memory allocation**:
   ```ini
   [ndbd default]
   # Increase data memory
   DataMemory=16G
   
   # Increase index memory
   IndexMemory=4G
   
   # Adjust transaction memory
   TransactionMemory=2G
   ```

3. **Optimize schema**:
   - Use appropriate data types
   - Normalize data to reduce duplication
   - Archive old data

4. **System settings**:
   ```bash
   # Adjust swappiness
   sudo sysctl -w vm.swappiness=10
   
   # Disable transparent huge pages
   sudo echo never > /sys/kernel/mm/transparent_hugepage/enabled
   ```

### Scenario 3: Disk I/O Bottlenecks

**Symptoms**:
- High disk I/O wait times
- Slow query performance for disk-based operations
- Backup and restore operations taking too long

**Solutions**:
1. **Identify I/O issues**:
   ```bash
   # Check disk I/O
   iostat -x 1
   
   # Check I/O wait time
   vmstat 1
   ```

2. **Optimize disk configuration**:
   - Use faster storage (SSD/NVMe)
   - Implement RAID for better performance
   - Use separate disks for data, logs, and backups

3. **Adjust disk-related settings**:
   ```ini
   [ndbd default]
   # Increase disk page buffer
   DiskPageBufferMemory=1G
   
   # Adjust disk I/O threads
   DiskIOThreadPool=8
   ```

4. **Filesystem tuning**:
   ```bash
   # Optimize filesystem
   sudo mount -o remount,noatime,nodiratime,nobarrier /var/lib/mysql
   
   # Adjust readahead
   sudo blockdev --setra 256 /dev/sda
   ```

### Scenario 4: Network Bottlenecks

**Symptoms**:
- High network latency between nodes
- Cluster synchronization delays
- Slow query response times

**Solutions**:
1. **Identify network issues**:
   ```bash
   # Check network traffic
   iftop -i eth0
   
   # Check network latency
   ping -c 10 mysql1
   ```

2. **Optimize network configuration**:
   - Use dedicated network for cluster traffic
   - Implement jumbo frames if supported
   - Upgrade network hardware if needed

3. **Adjust network-related settings**:
   ```ini
   [ndbd default]
   # Adjust heartbeat interval
   HeartbeatIntervalDbDb=1500
   
   # Optimize send buffer
   SendBufferMemory=8M
   
   # Optimize receive buffer
   ReceiveBufferMemory=8M
   ```

4. **System network settings**:
   ```bash
   # Optimize TCP settings
   sudo sysctl -w net.core.rmem_max=16777216
   sudo sysctl -w net.core.wmem_max=16777216
   sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
   sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
   ```

## Best Practices

1. **Systematic Approach**:
   - Make one change at a time
   - Measure impact before making additional changes
   - Document all changes and their effects

2. **Regular Maintenance**:
   - Analyze and optimize tables regularly
   - Monitor for performance regressions
   - Update statistics periodically

3. **Scaling Considerations**:
   - Scale vertically (larger nodes) for memory-intensive workloads
   - Scale horizontally (more nodes) for CPU-intensive workloads
   - Balance node groups for optimal data distribution

4. **Testing**:
   - Test performance changes in staging environment first
   - Use realistic data volumes and query patterns
   - Test under peak load conditions

5. **Documentation**:
   - Document baseline performance
   - Document all configuration changes
   - Document performance improvement results

## Related Documentation

- [Monitoring and Observability](monitoring.md) - Monitoring your MySQL Cluster
- [Configuration Overview](../configuration/overview.md) - Configuration principles
- [Troubleshooting Performance Issues](../troubleshooting/performance-issues.md) - Troubleshooting guide
- [Scaling](scaling.md) - Scaling your MySQL Cluster
- [Architecture Overview](../architecture/overview.md) - Core architecture of MySQL Cluster
