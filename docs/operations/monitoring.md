# Monitoring and Observability

[← Management](management.md) | [Documentation Index](../index.md) | [Backup and Recovery →](backup-recovery.md)

*Related: [Troubleshooting Common Issues](../troubleshooting/common-issues.md) | [Performance Tuning](performance-tuning.md)*

This document provides comprehensive guidance on monitoring and observability for your MySQL Cluster with ProxySQL deployment.

## Monitoring Architecture

A comprehensive monitoring solution for MySQL Cluster includes:

1. **System-level Monitoring**: CPU, memory, disk, network
2. **Cluster-level Monitoring**: Node status, replication status
3. **MySQL-level Monitoring**: Query performance, connections, errors
4. **ProxySQL Monitoring**: Connection pools, query routing, backend status
5. **Application-level Monitoring**: Error rates, latency, throughput

## Essential Metrics to Monitor

### System Metrics

| Metric | Description | Warning Threshold | Critical Threshold |
|--------|-------------|-------------------|-------------------|
| CPU Usage | CPU utilization percentage | >70% | >90% |
| Memory Usage | Memory utilization percentage | >80% | >90% |
| Disk Usage | Disk space utilization | >80% | >90% |
| Disk I/O | Disk read/write operations | Varies by hardware | Varies by hardware |
| Network I/O | Network traffic in/out | >70% capacity | >90% capacity |
| Load Average | System load average | >CPU cores | >2x CPU cores |

### Cluster Metrics

| Metric | Description | Warning Threshold | Critical Threshold |
|--------|-------------|-------------------|-------------------|
| Node Status | Status of each node (connected/disconnected) | Any warning | Any disconnected |
| Cluster Events | Significant cluster events | Unusual patterns | Error events |
| Arbitration Status | Arbitration status and rank | Any change | Loss of arbitration |
| Heartbeat Status | Heartbeat between nodes | Delayed heartbeats | Missing heartbeats |
| Replication Status | Replication between node groups | Any lag | Replication errors |

### MySQL Metrics

| Metric | Description | Warning Threshold | Critical Threshold |
|--------|-------------|-------------------|-------------------|
| Queries Per Second | Number of queries executed per second | >80% capacity | >90% capacity |
| Slow Queries | Queries exceeding long_query_time | >0 | >10/minute |
| Connection Count | Number of active connections | >80% max_connections | >90% max_connections |
| Connection Errors | Failed connection attempts | >0 | >10/minute |
| Table Locks | Number of table locks | >10/second | >100/second |
| Buffer Pool Hit Ratio | InnoDB buffer pool hit ratio | <95% | <90% |
| Temporary Tables | Temporary tables created on disk | >10/minute | >100/minute |
| Thread Cache Hit Ratio | Thread cache hit ratio | <90% | <80% |

### ProxySQL Metrics

| Metric | Description | Warning Threshold | Critical Threshold |
|--------|-------------|-------------------|-------------------|
| Backend Status | Status of backend servers | Any server not OK | Multiple servers not OK |
| Connection Pool Usage | Connection pool utilization | >80% | >90% |
| Query Processor Errors | Errors in query processing | >0 | >10/minute |
| Query Cache Hit Ratio | Query cache hit ratio (if enabled) | <50% | <20% |
| Query Routing Distribution | Distribution of queries across backends | Significant imbalance | Extreme imbalance |
| Query Response Time | Average query response time | >100ms | >1000ms |

## Monitoring Tools

### Built-in Tools

#### MySQL Cluster Manager

The MySQL Cluster Manager (ndb_mgm) provides basic monitoring capabilities:

```bash
# Show cluster status
ndb_mgm -e "show"

# Show cluster events
ndb_mgm -e "show eventlog"

# Show memory usage
ndb_mgm -e "all report memory"

# Show connection status
ndb_mgm -e "all report connection"
```

#### MySQL Status Commands

MySQL provides several commands for monitoring:

```sql
-- Show global status variables
SHOW GLOBAL STATUS;

-- Show NDB status
SHOW ENGINE NDB STATUS;

-- Show process list
SHOW PROCESSLIST;

-- Show open tables
SHOW OPEN TABLES;

-- Show global variables
SHOW GLOBAL VARIABLES;
```

#### ProxySQL Admin Interface

ProxySQL provides monitoring through its admin interface:

```sql
-- Connect to ProxySQL admin interface
mysql -h127.0.0.1 -P6032 -uradmin -pradmin

-- Show backend server status
SELECT * FROM mysql_servers;

-- Show connection pool status
SELECT * FROM stats_mysql_connection_pool;

-- Show query digest
SELECT * FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10;

-- Show global variables
SELECT * FROM global_variables;
```

### External Monitoring Tools

#### Prometheus and Grafana

Prometheus and Grafana provide powerful monitoring and visualization:

1. **MySQL Exporter**: Collects MySQL metrics
2. **Node Exporter**: Collects system metrics
3. **ProxySQL Exporter**: Collects ProxySQL metrics
4. **Grafana**: Visualizes metrics and creates dashboards

Example Prometheus configuration:

```yaml
scrape_configs:
  - job_name: 'mysql'
    static_configs:
      - targets: ['mysql-exporter:9104']
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
  - job_name: 'proxysql'
    static_configs:
      - targets: ['proxysql-exporter:42004']
```

Example Grafana dashboard for MySQL Cluster:
- Node status and resources
- Query performance metrics
- Connection metrics
- Replication status
- Error rates and logs

#### Nagios/Icinga

Nagios or Icinga can be used for alerting and monitoring:

1. **check_mysql**: Monitors MySQL availability and performance
2. **check_ndb**: Custom plugin for MySQL Cluster monitoring
3. **check_proxysql**: Custom plugin for ProxySQL monitoring

Example Nagios configuration:

```
define service {
    use                 generic-service
    host_name           mysql-cluster
    service_description MySQL Cluster Status
    check_command       check_ndb!-H management1 -P 1186
    notifications_enabled 1
}
```

#### Percona Monitoring and Management (PMM)

PMM provides comprehensive MySQL monitoring:

1. **PMM Server**: Central monitoring server
2. **PMM Client**: Installed on each MySQL node
3. **Dashboards**: Pre-built dashboards for MySQL and system metrics

## Setting Up Monitoring

### Prometheus and Grafana Setup

1. **Deploy Exporters**:

```yaml
# In docker-compose.yml
services:
  mysql-exporter:
    image: prom/mysqld-exporter
    command:
      - '--collect.info_schema.tables'
      - '--collect.info_schema.innodb_metrics'
      - '--collect.global_status'
      - '--collect.global_variables'
    environment:
      - DATA_SOURCE_NAME=monitor:monitor@(mysql1:3306)/
    ports:
      - "9104:9104"
    networks:
      - ndb-net

  node-exporter:
    image: prom/node-exporter
    ports:
      - "9100:9100"
    networks:
      - ndb-net

  proxysql-exporter:
    image: percona/proxysql-exporter
    environment:
      - PROXYSQL_DSN=stats:stats@tcp(proxysql:6032)/
    ports:
      - "42004:42004"
    networks:
      - ndb-net

  prometheus:
    image: prom/prometheus
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
    networks:
      - ndb-net

  grafana:
    image: grafana/grafana
    depends_on:
      - prometheus
    ports:
      - "3000:3000"
    networks:
      - ndb-net
```

2. **Configure Prometheus**:

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'mysql'
    static_configs:
      - targets: ['mysql-exporter:9104']
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
  - job_name: 'proxysql'
    static_configs:
      - targets: ['proxysql-exporter:42004']
```

3. **Configure Grafana**:
   - Add Prometheus as a data source
   - Import MySQL Cluster dashboards
   - Set up alerting rules

### Custom Monitoring Scripts

Create custom scripts for specific monitoring needs:

```bash
#!/bin/bash
# check_mysql_cluster.sh
# Check MySQL Cluster status

# Get cluster status
STATUS=$(ndb_mgm -e "show" | grep "Node\|status")

# Check for disconnected nodes
if echo "$STATUS" | grep -q "not connected"; then
  echo "CRITICAL - Disconnected nodes found"
  echo "$STATUS"
  exit 2
fi

# Check for nodes not started
if echo "$STATUS" | grep -q "starting\|shutting down"; then
  echo "WARNING - Nodes not fully started"
  echo "$STATUS"
  exit 1
fi

# All good
echo "OK - All nodes connected and running"
echo "$STATUS"
exit 0
```

## Alerting

### Alert Thresholds

Set up alerts for critical metrics:

1. **System Alerts**:
   - CPU usage > 90% for 5 minutes
   - Memory usage > 90% for 5 minutes
   - Disk usage > 90%
   - High load average > 2x CPU cores for 10 minutes

2. **Cluster Alerts**:
   - Node disconnected
   - Arbitration issues
   - Replication errors
   - Cluster events with severity > warning

3. **MySQL Alerts**:
   - Connection count > 90% of max_connections
   - Slow queries > 10 per minute
   - Error log entries with severity > warning
   - Buffer pool hit ratio < 90%

4. **ProxySQL Alerts**:
   - Backend server down
   - Connection pool usage > 90%
   - Query errors > 10 per minute
   - High query latency > 1000ms

### Alert Channels

Configure multiple alert channels:

1. **Email**: For non-urgent notifications
2. **SMS/Phone**: For critical alerts
3. **Chat/Slack**: For team notifications
4. **PagerDuty/OpsGenie**: For on-call rotation

### Alert Escalation

Implement alert escalation procedures:

1. **Level 1**: Automated alerts to on-call engineer
2. **Level 2**: Escalation to senior engineer after 15 minutes
3. **Level 3**: Escalation to team lead after 30 minutes
4. **Level 4**: Escalation to management after 1 hour

## Log Management

### Log Types

Collect and analyze logs from all components:

1. **System Logs**: `/var/log/syslog`, `/var/log/messages`
2. **MySQL Error Logs**: `/var/log/mysql/error.log`
3. **MySQL Slow Query Logs**: `/var/log/mysql/slow-query.log`
4. **MySQL Cluster Logs**: `/var/lib/mysql-cluster/ndb_*.log`
5. **ProxySQL Logs**: `/var/lib/proxysql/proxysql.log`

### Log Aggregation

Use a log aggregation system:

1. **ELK Stack**: Elasticsearch, Logstash, Kibana
2. **Graylog**: Centralized log management
3. **Fluentd/Fluent Bit**: Log collection and forwarding

Example Fluentd configuration:

```xml
<source>
  @type tail
  path /var/log/mysql/error.log
  tag mysql.error
  <parse>
    @type multiline
    format_firstline /^\d{4}-\d{2}-\d{2}/
    format1 /^(?<time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) (?<level>\w+) (?<message>.*)/
  </parse>
</source>

<match mysql.**>
  @type elasticsearch
  host elasticsearch
  port 9200
  logstash_format true
  logstash_prefix mysql
  <buffer>
    flush_interval 5s
  </buffer>
</match>
```

### Log Rotation

Implement log rotation to manage log files:

```
# /etc/logrotate.d/mysql
/var/log/mysql/*.log {
  daily
  rotate 7
  compress
  delaycompress
  missingok
  create 640 mysql mysql
  postrotate
    if test -x /usr/bin/mysqladmin && test -S /var/run/mysqld/mysqld.sock; then
      /usr/bin/mysqladmin --socket=/var/run/mysqld/mysqld.sock --user=root --password=password flush-logs
    fi
  endscript
}
```

## Dashboards

### Essential Dashboard Components

Create comprehensive dashboards with:

1. **System Overview**:
   - CPU, memory, disk, network usage
   - System load and uptime

2. **Cluster Status**:
   - Node status and health
   - Replication status
   - Cluster events

3. **MySQL Performance**:
   - Queries per second
   - Slow queries
   - Connection count
   - Buffer pool usage

4. **ProxySQL Status**:
   - Backend server status
   - Connection pool usage
   - Query routing statistics
   - Query cache performance

5. **Alerts and Logs**:
   - Recent alerts
   - Error log entries
   - Slow query log entries

### Sample Grafana Dashboard

A comprehensive Grafana dashboard should include:

1. **Header Row**:
   - Cluster status summary
   - Node count and status
   - Alert count

2. **System Metrics Row**:
   - CPU usage graphs
   - Memory usage graphs
   - Disk usage graphs
   - Network traffic graphs

3. **MySQL Metrics Row**:
   - Queries per second graph
   - Connection count graph
   - Slow queries graph
   - Buffer pool usage graph

4. **ProxySQL Metrics Row**:
   - Backend status panel
   - Connection pool usage graph
   - Query routing distribution graph
   - Query response time graph

5. **Logs and Alerts Row**:
   - Recent error log entries
   - Recent slow queries
   - Active alerts

## Capacity Planning

### Metrics for Capacity Planning

Monitor these metrics for capacity planning:

1. **Resource Utilization Trends**:
   - CPU, memory, disk usage over time
   - Growth patterns and seasonality

2. **Query Performance Trends**:
   - Query throughput over time
   - Query latency trends
   - Slow query frequency

3. **Connection Trends**:
   - Connection count over time
   - Connection usage patterns
   - Peak connection periods

4. **Data Growth**:
   - Database size growth rate
   - Table growth rates
   - Index size growth

### Capacity Planning Process

1. **Collect Historical Data**:
   - Gather at least 3 months of metrics
   - Identify patterns and trends

2. **Analyze Growth Patterns**:
   - Calculate growth rates
   - Identify peak usage periods
   - Project future growth

3. **Define Capacity Thresholds**:
   - Set thresholds for each resource
   - Define when expansion is needed

4. **Create Expansion Plan**:
   - Document expansion procedures
   - Prepare for horizontal or vertical scaling
   - Budget for future expansion

## Best Practices

1. **Comprehensive Monitoring**:
   - Monitor all components and layers
   - Include system, cluster, database, and application metrics
   - Set appropriate thresholds based on your environment

2. **Proactive Alerting**:
   - Alert on trends, not just thresholds
   - Use predictive alerting when possible
   - Avoid alert fatigue with proper tuning

3. **Regular Review**:
   - Review monitoring setup quarterly
   - Adjust thresholds based on experience
   - Add new metrics as needed

4. **Documentation**:
   - Document monitoring architecture
   - Document alert procedures and escalation paths
   - Keep runbooks updated for common alerts

5. **Testing**:
   - Regularly test alerting system
   - Simulate failure scenarios
   - Verify monitoring during maintenance

6. **Integration**:
   - Integrate monitoring with incident management
   - Connect monitoring to automation where possible
   - Correlate metrics across systems

## Troubleshooting Common Monitoring Issues

### Missing or Incomplete Metrics

**Symptoms**:
- Gaps in monitoring data
- Missing metrics for specific components

**Solutions**:
1. Check exporter status and logs
2. Verify connectivity between components
3. Check permissions for monitoring users
4. Restart monitoring services if needed

### False Positives

**Symptoms**:
- Frequent alerts that don't indicate real issues
- Alert noise leading to ignored notifications

**Solutions**:
1. Adjust alert thresholds
2. Implement better alert conditions (duration, frequency)
3. Add context to alerts
4. Implement alert correlation

### Monitoring Performance Impact

**Symptoms**:
- Monitoring causes performance degradation
- High resource usage from monitoring tools

**Solutions**:
1. Reduce collection frequency
2. Optimize queries used by exporters
3. Use read replicas for monitoring
4. Implement sampling for high-volume metrics

## Related Documentation

- [Management](management.md) - Day-to-day management operations
- [Backup and Recovery](backup-recovery.md) - Backup and recovery procedures
- [Troubleshooting Common Issues](../troubleshooting/common-issues.md) - Troubleshooting guide
- [Performance Tuning](performance-tuning.md) - Performance optimization
- [Security Overview](../security/overview.md) - Security best practices
