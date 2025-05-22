# Scaling MySQL Cluster

[← Performance Tuning](performance-tuning.md) | [Documentation Index](../index.md) | [High Availability →](high-availability.md)

*Related: [Architecture Overview](../architecture/overview.md) | [Node Groups](../architecture/node-groups.md)*

This document provides comprehensive guidance on scaling your MySQL Cluster with ProxySQL deployment to handle growing workloads.

## Scaling Fundamentals

MySQL Cluster offers several scaling dimensions:

1. **Vertical Scaling**: Increasing resources (CPU, memory, disk) of existing nodes
2. **Horizontal Scaling**: Adding more nodes to the cluster
3. **Read Scaling**: Distributing read queries across multiple SQL nodes
4. **Write Scaling**: Distributing write operations across node groups
5. **Geographic Scaling**: Distributing nodes across geographic locations

## When to Scale

Consider scaling your MySQL Cluster when you observe:

1. **Resource Saturation**:
   - CPU utilization consistently above 70%
   - Memory usage consistently above 80%
   - Disk I/O bottlenecks
   - Network saturation

2. **Performance Degradation**:
   - Increasing query latency
   - Growing transaction response times
   - Increasing lock contention
   - Query timeouts

3. **Growth Indicators**:
   - Increasing user base
   - Growing data volume
   - Higher transaction rates
   - More concurrent connections

## Vertical Scaling

### When to Use Vertical Scaling

Vertical scaling is appropriate when:
- Single-node performance is the bottleneck
- Specific resource (CPU, memory, disk) is saturated
- Quick solution is needed without architecture changes
- Data volume fits on a single node

### Vertical Scaling Process

1. **Identify Resource Bottlenecks**:
   ```bash
   # Check CPU usage
   top -bn1 | grep "Cpu(s)"
   
   # Check memory usage
   free -m
   
   # Check disk I/O
   iostat -x 1
   ```

2. **Plan Resource Upgrade**:
   - Determine which resources to upgrade
   - Select appropriate instance types (if cloud-based)
   - Schedule maintenance window

3. **Upgrade Data Nodes**:
   ```bash
   # Stop the data node
   ndb_mgm -e "2 stop"
   
   # Upgrade resources (cloud provider specific or hardware upgrade)
   
   # Start the data node
   ndb_mgm -e "2 start"
   ```

4. **Upgrade SQL Nodes**:
   ```bash
   # Stop the SQL node
   systemctl stop mysql
   
   # Upgrade resources
   
   # Start the SQL node
   systemctl start mysql
   ```

5. **Adjust Configuration for New Resources**:
   ```ini
   [ndbd default]
   # Increase memory allocations
   DataMemory=32G         # Increased from 16G
   IndexMemory=8G         # Increased from 4G
   
   [mysqld]
   # Adjust buffer sizes
   innodb_buffer_pool_size=8G  # Increased from 4G
   ```

### Vertical Scaling Limitations

- Physical hardware limits
- Diminishing returns on resource addition
- Single point of failure remains
- Downtime during upgrades (unless using cloud with live migration)

## Horizontal Scaling

### When to Use Horizontal Scaling

Horizontal scaling is appropriate when:
- Workload exceeds capabilities of a single node
- High availability is required
- Data volume exceeds single node capacity
- Read/write throughput needs to scale linearly

### Scaling SQL Nodes

1. **Add New SQL Node**:
   ```bash
   # Install MySQL on new node
   apt-get install mysql-cluster-community-server
   
   # Configure my.cnf
   cat > /etc/my.cnf << EOF
   [mysqld]
   ndbcluster
   ndb-connectstring=management1:1186,management2:1186
   default_storage_engine=ndbcluster
   server_id=3  # Unique ID for this SQL node
   EOF
   
   # Start MySQL
   systemctl start mysql
   ```

2. **Update ProxySQL Configuration**:
   ```sql
   -- Connect to ProxySQL admin
   mysql -h127.0.0.1 -P6032 -uradmin -pradmin
   
   -- Add new SQL node to backend servers
   INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight) 
   VALUES (0, 'mysql3', 3306, 1000);
   INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight) 
   VALUES (10, 'mysql3', 3306, 1000);
   
   -- Apply changes
   LOAD MYSQL SERVERS TO RUNTIME;
   SAVE MYSQL SERVERS TO DISK;
   ```

3. **Verify New SQL Node**:
   ```sql
   -- Check if node is visible in the cluster
   SHOW STATUS LIKE 'ndb%';
   
   -- Check ProxySQL connection
   SELECT * FROM mysql_servers;
   SELECT * FROM stats_mysql_connection_pool;
   ```

### Scaling Data Nodes

1. **Plan Node Group Structure**:
   - Determine if adding to existing node group or creating new node group
   - Ensure balanced node groups

2. **Update Cluster Configuration**:
   ```ini
   # Add new data nodes to config.ini
   [ndbd]
   NodeId=8
   HostName=ndb5
   NodeGroup=2
   DataDir=/var/lib/mysql-cluster
   
   [ndbd]
   NodeId=9
   HostName=ndb6
   NodeGroup=2
   DataDir=/var/lib/mysql-cluster
   ```

3. **Initialize New Data Nodes**:
   ```bash
   # On new data nodes, install software
   apt-get install mysql-cluster-community-data-node
   
   # Configure config.ini
   mkdir -p /var/lib/mysql-cluster
   cat > /etc/my.cnf << EOF
   [mysql_cluster]
   ndb-connectstring=management1:1186,management2:1186
   EOF
   
   # Start data node
   ndbd
   ```

4. **Verify New Data Nodes**:
   ```bash
   # Check cluster status
   ndb_mgm -e "show"
   ```

5. **Redistribute Data**:
   - New tables will automatically use all node groups
   - Existing tables need reorganization to use new node groups:
     ```sql
     ALTER TABLE large_table ALGORITHM=INPLACE, REORGANIZE PARTITION;
     ```

### Adding Node Groups

Adding node groups increases both capacity and performance:

1. **Add New Node Group**:
   ```ini
   # Add new node group to config.ini
   [ndbd]
   NodeId=10
   HostName=ndb7
   NodeGroup=3
   DataDir=/var/lib/mysql-cluster
   
   [ndbd]
   NodeId=11
   HostName=ndb8
   NodeGroup=3
   DataDir=/var/lib/mysql-cluster
   ```

2. **Initialize New Node Group**:
   - Follow the same process as adding data nodes

3. **Verify Node Group**:
   ```bash
   # Check node group configuration
   ndb_mgm -e "show"
   ```

4. **Rebalance Data**:
   - Reorganize tables to use new node groups
   - Create new tables with appropriate partitioning

## Read Scaling

### ProxySQL Read/Write Splitting

1. **Configure Hostgroups**:
   ```sql
   -- Connect to ProxySQL admin
   mysql -h127.0.0.1 -P6032 -uradmin -pradmin
   
   -- Define writer hostgroup
   INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight) 
   VALUES (0, 'mysql1', 3306, 1000);
   INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight) 
   VALUES (0, 'mysql2', 3306, 1000);
   
   -- Define reader hostgroup
   INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight) 
   VALUES (10, 'mysql1', 3306, 1000);
   INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight) 
   VALUES (10, 'mysql2', 3306, 1000);
   INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight) 
   VALUES (10, 'mysql3', 3306, 1000);
   INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight) 
   VALUES (10, 'mysql4', 3306, 1000);
   
   -- Apply changes
   LOAD MYSQL SERVERS TO RUNTIME;
   SAVE MYSQL SERVERS TO DISK;
   ```

2. **Configure Query Rules**:
   ```sql
   -- Route SELECT queries to reader hostgroup
   INSERT INTO mysql_query_rules(rule_id, active, match_digest, destination_hostgroup, apply)
   VALUES (1, 1, '^SELECT', 10, 1);
   
   -- Route all other queries to writer hostgroup
   INSERT INTO mysql_query_rules(rule_id, active, match_digest, destination_hostgroup, apply)
   VALUES (2, 1, '.*', 0, 1);
   
   -- Apply changes
   LOAD MYSQL QUERY RULES TO RUNTIME;
   SAVE MYSQL QUERY RULES TO DISK;
   ```

3. **Fine-tune Read Distribution**:
   ```sql
   -- Adjust weights for read distribution
   UPDATE mysql_servers SET weight=2000 WHERE hostname='mysql3' AND hostgroup_id=10;
   UPDATE mysql_servers SET weight=2000 WHERE hostname='mysql4' AND hostgroup_id=10;
   
   -- Apply changes
   LOAD MYSQL SERVERS TO RUNTIME;
   SAVE MYSQL SERVERS TO DISK;
   ```

### Application-Level Read Scaling

1. **Connection Pool Configuration**:
   ```java
   // Java example with HikariCP
   HikariConfig writeConfig = new HikariConfig();
   writeConfig.setJdbcUrl("jdbc:mysql://proxysql:6033/mydb");
   writeConfig.setUsername("app");
   writeConfig.setPassword("password");
   writeConfig.addDataSourceProperty("useWriteConnection", "true");
   HikariDataSource writeDs = new HikariDataSource(writeConfig);
   
   HikariConfig readConfig = new HikariConfig();
   readConfig.setJdbcUrl("jdbc:mysql://proxysql:6033/mydb");
   readConfig.setUsername("readonly");
   readConfig.setPassword("password");
   HikariDataSource readDs = new HikariDataSource(readConfig);
   ```

2. **Query Routing Logic**:
   ```java
   // Java example
   public Connection getConnection(boolean forWrite) {
       if (forWrite) {
           return writeDs.getConnection();
       } else {
           return readDs.getConnection();
       }
   }
   
   public <T> T executeQuery(String sql, ResultSetHandler<T> handler) {
       try (Connection conn = getConnection(false);
            PreparedStatement stmt = conn.prepareStatement(sql)) {
           ResultSet rs = stmt.executeQuery();
           return handler.handle(rs);
       }
   }
   
   public int executeUpdate(String sql, Object... params) {
       try (Connection conn = getConnection(true);
            PreparedStatement stmt = conn.prepareStatement(sql)) {
           for (int i = 0; i < params.length; i++) {
               stmt.setObject(i + 1, params[i]);
           }
           return stmt.executeUpdate();
       }
   }
   ```

## Write Scaling

### Partitioning for Write Distribution

1. **User-Defined Partitioning**:
   ```sql
   CREATE TABLE orders (
     id INT NOT NULL AUTO_INCREMENT,
     customer_id INT NOT NULL,
     order_date DATE NOT NULL,
     total DECIMAL(10,2) NOT NULL,
     PRIMARY KEY (id, customer_id)
   ) ENGINE=NDBCLUSTER
   PARTITION BY KEY(customer_id);
   ```

2. **Hash-Based Partitioning**:
   ```sql
   CREATE TABLE transactions (
     id INT NOT NULL AUTO_INCREMENT,
     account_id INT NOT NULL,
     transaction_date DATETIME NOT NULL,
     amount DECIMAL(10,2) NOT NULL,
     PRIMARY KEY (id, account_id)
   ) ENGINE=NDBCLUSTER
   PARTITION BY KEY(account_id);
   ```

3. **Range-Based Partitioning**:
   ```sql
   CREATE TABLE logs (
     id INT NOT NULL AUTO_INCREMENT,
     log_date DATE NOT NULL,
     level VARCHAR(10) NOT NULL,
     message TEXT NOT NULL,
     PRIMARY KEY (id, log_date)
   ) ENGINE=NDBCLUSTER
   PARTITION BY RANGE (TO_DAYS(log_date)) (
     PARTITION p_2023_01 VALUES LESS THAN (TO_DAYS('2023-02-01')),
     PARTITION p_2023_02 VALUES LESS THAN (TO_DAYS('2023-03-01')),
     PARTITION p_2023_03 VALUES LESS THAN (TO_DAYS('2023-04-01')),
     PARTITION p_future VALUES LESS THAN MAXVALUE
   );
   ```

### Application-Level Sharding

1. **Sharding by Customer ID**:
   ```java
   // Java example
   public Connection getConnectionForCustomer(int customerId) {
       int shardId = customerId % 4; // 4 shards
       switch (shardId) {
           case 0: return getConnection("shard0");
           case 1: return getConnection("shard1");
           case 2: return getConnection("shard2");
           case 3: return getConnection("shard3");
           default: throw new IllegalStateException("Invalid shard ID");
       }
   }
   
   public void createOrder(Order order) {
       try (Connection conn = getConnectionForCustomer(order.getCustomerId());
            PreparedStatement stmt = conn.prepareStatement(
                "INSERT INTO orders (customer_id, order_date, total) VALUES (?, ?, ?)")) {
           stmt.setInt(1, order.getCustomerId());
           stmt.setDate(2, new java.sql.Date(order.getOrderDate().getTime()));
           stmt.setBigDecimal(3, order.getTotal());
           stmt.executeUpdate();
       }
   }
   ```

2. **Sharding by Date Range**:
   ```java
   // Java example
   public Connection getConnectionForDate(Date date) {
       Calendar cal = Calendar.getInstance();
       cal.setTime(date);
       int month = cal.get(Calendar.MONTH);
       int quarter = month / 3;
       
       switch (quarter) {
           case 0: return getConnection("q1");
           case 1: return getConnection("q2");
           case 2: return getConnection("q3");
           case 3: return getConnection("q4");
           default: throw new IllegalStateException("Invalid quarter");
       }
   }
   ```

## Geographic Scaling

### Multi-Region Deployment

1. **Region-Based Cluster Setup**:
   - Deploy complete clusters in each region
   - Use asynchronous replication between regions

2. **Region Configuration**:
   ```ini
   # Primary region config.ini
   [mysqld]
   server_id=1
   log_bin=mysql-bin
   binlog_format=ROW
   
   # Secondary region config.ini
   [mysqld]
   server_id=2
   log_bin=mysql-bin
   binlog_format=ROW
   relay_log=mysql-relay-bin
   log_slave_updates=1
   ```

3. **Set Up Replication**:
   ```sql
   -- On secondary region
   CHANGE MASTER TO
     MASTER_HOST='primary-region-endpoint',
     MASTER_USER='replication_user',
     MASTER_PASSWORD='replication_password',
     MASTER_LOG_FILE='mysql-bin.000001',
     MASTER_LOG_POS=4;
   START SLAVE;
   ```

### Geographic Load Balancing

1. **DNS-Based Routing**:
   - Use GeoDNS to route users to nearest region
   - Configure health checks for failover

2. **Application-Level Routing**:
   ```java
   // Java example
   public Connection getConnectionForRegion(String userRegion) {
       switch (userRegion.toLowerCase()) {
           case "us-east": return getConnection("us-east-endpoint");
           case "us-west": return getConnection("us-west-endpoint");
           case "eu": return getConnection("eu-endpoint");
           case "asia": return getConnection("asia-endpoint");
           default: return getConnection("default-endpoint");
       }
   }
   ```

3. **Global Load Balancer Configuration**:
   - Configure AWS Global Accelerator or similar service
   - Set up health checks and failover policies
   - Define routing rules based on user location

## Scaling ProxySQL

### Vertical Scaling ProxySQL

1. **Increase Resources**:
   - Allocate more CPU and memory to ProxySQL container/VM
   - Update Docker Compose configuration:
     ```yaml
     services:
       proxysql:
         image: proxysql/proxysql:latest
         deploy:
           resources:
             limits:
               cpus: '4'
               memory: 8G
     ```

2. **Optimize Configuration**:
   ```ini
   mysql_variables=
   {
     threads=16                      # Increase thread count
     max_connections=4096            # Increase max connections
     stacksize=1048576               # Increase stack size
     default_query_timeout=3600000   # Increase query timeout
   }
   ```

### Horizontal Scaling ProxySQL

1. **Deploy Multiple ProxySQL Instances**:
   ```yaml
   # docker-compose.yml
   services:
     proxysql1:
       image: proxysql/proxysql:latest
       volumes:
         - ./config/proxysql.cnf:/etc/proxysql.cnf
       ports:
         - "6033:6033"
         - "6032:6032"
       networks:
         - ndb-net
     
     proxysql2:
       image: proxysql/proxysql:latest
       volumes:
         - ./config/proxysql.cnf:/etc/proxysql.cnf
       ports:
         - "6034:6033"
         - "6035:6032"
       networks:
         - ndb-net
   ```

2. **Load Balancer Configuration**:
   ```nginx
   # nginx.conf
   upstream proxysql {
     server proxysql1:6033 weight=1;
     server proxysql2:6033 weight=1;
   }
   
   server {
     listen 3306;
     proxy_pass proxysql;
   }
   ```

3. **Synchronize ProxySQL Configuration**:
   - Use a configuration management tool
   - Or use ProxySQL's built-in replication:
     ```ini
     # On proxysql1
     proxysql_servers:
     (
       { hostname="proxysql2", port=6032 }
     )
     ```

## Scaling Challenges and Solutions

### Data Consistency

**Challenge**: Maintaining data consistency across scaled cluster

**Solutions**:
1. Use transactions for related operations
2. Implement proper locking strategies
3. Design schemas to minimize contention
4. Use optimistic concurrency control

### Connection Management

**Challenge**: Managing growing number of connections

**Solutions**:
1. Implement connection pooling
2. Use ProxySQL for connection multiplexing
3. Optimize connection timeouts
4. Monitor and limit max connections per user

### Query Performance

**Challenge**: Maintaining query performance as data grows

**Solutions**:
1. Regularly update statistics
2. Monitor and optimize slow queries
3. Use appropriate indexes
4. Implement query caching where appropriate
5. Consider materialized views for complex queries

### Operational Complexity

**Challenge**: Managing a larger, more complex cluster

**Solutions**:
1. Automate deployment and configuration
2. Implement comprehensive monitoring
3. Use infrastructure as code
4. Document operational procedures
5. Implement automated testing

## Scaling Strategies by Workload Type

### OLTP Workloads

1. **Key Characteristics**:
   - High transaction volume
   - Short-lived transactions
   - Point queries by primary key
   - Low latency requirements

2. **Scaling Strategy**:
   - Scale SQL nodes horizontally for connection handling
   - Add node groups for write scaling
   - Use ProxySQL for read/write splitting
   - Implement connection pooling

3. **Configuration Focus**:
   ```ini
   [ndbd default]
   # Optimize for OLTP
   MaxNoOfConcurrentTransactions=32768
   MaxNoOfConcurrentOperations=200000
   TransactionMemory=2G
   ```

### OLAP Workloads

1. **Key Characteristics**:
   - Complex analytical queries
   - Long-running operations
   - Aggregations and joins
   - High data volume scans

2. **Scaling Strategy**:
   - Scale data nodes vertically for memory capacity
   - Dedicate SQL nodes for analytical queries
   - Implement query routing by complexity
   - Consider read-only replicas

3. **Configuration Focus**:
   ```ini
   [ndbd default]
   # Optimize for OLAP
   MaxNoOfConcurrentScans=1000
   BatchSizePerLocalScan=256
   DiskPageBufferMemory=1G
   ```

### Mixed Workloads

1. **Key Characteristics**:
   - Combination of OLTP and OLAP
   - Varying query patterns
   - Different performance requirements

2. **Scaling Strategy**:
   - Isolate workloads with dedicated node groups
   - Use query routing to separate traffic
   - Scale different components based on specific bottlenecks
   - Consider time-based workload separation

3. **Configuration Focus**:
   ```ini
   # ProxySQL query routing
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
       match_digest="^SELECT .* FROM (users|products|orders) WHERE",
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

## Monitoring Scaled Deployments

### Key Metrics for Scaled Clusters

1. **Cluster-Wide Metrics**:
   - Node group distribution
   - Data distribution
   - Replication status
   - Cluster events

2. **Per-Node Metrics**:
   - CPU, memory, disk, network usage
   - Query throughput
   - Connection count
   - Buffer usage

3. **ProxySQL Metrics**:
   - Backend status
   - Connection pool usage
   - Query routing distribution
   - Query response time by hostgroup

### Monitoring Configuration

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'mysql'
    static_configs:
      - targets: ['mysql1-exporter:9104', 'mysql2-exporter:9104', 'mysql3-exporter:9104', 'mysql4-exporter:9104']
  
  - job_name: 'proxysql'
    static_configs:
      - targets: ['proxysql1-exporter:42004', 'proxysql2-exporter:42004']
  
  - job_name: 'node'
    static_configs:
      - targets: ['node1-exporter:9100', 'node2-exporter:9100', 'node3-exporter:9100', 'node4-exporter:9100']
```

## Scaling Checklist

### Pre-Scaling Assessment

1. **Performance Analysis**:
   - Identify current bottlenecks
   - Determine scaling dimension (vertical, horizontal, read, write)
   - Establish performance baselines

2. **Capacity Planning**:
   - Project future growth
   - Determine resource requirements
   - Plan scaling phases

3. **Risk Assessment**:
   - Identify potential issues
   - Plan mitigation strategies
   - Create rollback procedures

### Scaling Implementation

1. **Preparation**:
   - Back up all data
   - Update documentation
   - Notify stakeholders
   - Schedule maintenance window

2. **Execution**:
   - Follow scaling procedure
   - Monitor progress
   - Test functionality
   - Verify performance

3. **Validation**:
   - Run performance tests
   - Verify data consistency
   - Check monitoring systems
   - Test failover scenarios

### Post-Scaling Activities

1. **Performance Tuning**:
   - Fine-tune configuration
   - Optimize for new scale
   - Update monitoring thresholds

2. **Documentation Update**:
   - Update architecture diagrams
   - Document new configuration
   - Update operational procedures

3. **Knowledge Transfer**:
   - Train team on new architecture
   - Review lessons learned
   - Plan for future scaling

## Best Practices

1. **Incremental Scaling**:
   - Scale in small, manageable increments
   - Test thoroughly after each change
   - Allow time for stabilization

2. **Data Distribution**:
   - Design for even data distribution
   - Use appropriate partitioning strategies
   - Monitor and rebalance as needed

3. **Connection Management**:
   - Implement connection pooling
   - Use ProxySQL for connection management
   - Set appropriate connection limits

4. **Query Optimization**:
   - Regularly review and optimize queries
   - Use EXPLAIN to analyze execution plans
   - Implement appropriate indexes

5. **Monitoring and Alerting**:
   - Set up comprehensive monitoring
   - Define appropriate alerting thresholds
   - Regularly review monitoring data

6. **Automation**:
   - Automate scaling procedures
   - Use infrastructure as code
   - Implement automated testing

## Related Documentation

- [Performance Tuning](performance-tuning.md) - Optimizing performance
- [Architecture Overview](../architecture/overview.md) - Core architecture
- [Node Groups](../architecture/node-groups.md) - Node group configuration
- [High Availability](high-availability.md) - High availability configuration
- [Monitoring and Observability](monitoring.md) - Monitoring your cluster
