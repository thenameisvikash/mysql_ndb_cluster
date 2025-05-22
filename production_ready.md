# Production-Ready ProxySQL MySQL NDB Cluster Setup

## Overview of Your Setup

Your MySQL NDB Cluster with ProxySQL setup is approaching production-grade quality. Here's an analysis of your current configuration and recommendations for improvements:

## Configuration Assessment

### Components
- 1 Management Node
- 4 Data Nodes (2 node groups with 2 nodes each)
- 2 SQL Nodes
- 2 ProxySQL instances for load balancing and high availability

### Docker Compose Behavior
When you run `docker-compose up` after the initial setup:
- If volumes exist, initialization scripts in `/docker-entrypoint-initdb.d/` will NOT run again
- Container configuration changes WILL apply
- Container restarts WILL occur if there are changes in the configuration

## Required Improvements for Production

### 1. Create the Missing Health Check Script

Create this file at `scripts/proxysql_ndb_check.sh`:

```bash
#!/bin/bash
# NDB Cluster health check script for ProxySQL

# Variables
MYSQL_USER="proxysql_monitor"
MYSQL_PASS="monitorpass123"
MYSQL_PORT=3306
LOG_FILE="/var/log/proxysql_ndb_check.log"

# Check if MySQL nodes are alive and connected to NDB
check_mysql_node() {
    local host=$1
    local status=$(mysql -h$host -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASS -N -e "
        SELECT 1 FROM INFORMATION_SCHEMA.ENGINES WHERE ENGINE='ndbcluster' AND SUPPORT='YES' AND COMMENT LIKE '%Connected%';" 2>/dev/null)
    
    if [ "$status" = "1" ]; then
        echo "$(date) - MySQL node $host is connected to NDB Cluster" >> $LOG_FILE
        return 0
    else
        echo "$(date) - WARNING: MySQL node $host is NOT connected to NDB Cluster" >> $LOG_FILE
        return 1
    fi
}

# Check data nodes status from management node
check_data_nodes() {
    local management_host="management1"
    local management_port="1186"
    
    # Use ndb_mgm to check data node status
    local status=$(ndb_mgm -c $management_host:$management_port -e "show" 2>/dev/null | grep "Node.*ndbd" | grep -v "not connected")
    
    if [ -n "$status" ]; then
        echo "$(date) - Data nodes status: OK" >> $LOG_FILE
        return 0
    else
        echo "$(date) - WARNING: Some data nodes are not connected" >> $LOG_FILE
        return 1
    fi
}

# Main execution
echo "$(date) - Running NDB Cluster health check" >> $LOG_FILE

# Check MySQL SQL nodes
mysql1_status=$(check_mysql_node "mysql1")
mysql2_status=$(check_mysql_node "mysql2")

# Check data nodes
data_nodes_status=$(check_data_nodes)

# Exit with appropriate status code
if [ $mysql1_status -eq 0 ] && [ $mysql2_status -eq 0 ] && [ $data_nodes_status -eq 0 ]; then
    echo "$(date) - All components are healthy" >> $LOG_FILE
    exit 0
else
    echo "$(date) - WARNING: Some components are unhealthy" >> $LOG_FILE
    exit 1
fi
```

Don't forget to make it executable:
```bash
chmod +x scripts/proxysql_ndb_check.sh
```

### 2. Add Volume Persistence Protection

Create a script that prevents accidental data loss:

```bash
#!/bin/bash
# save-volumes.sh - Save current volumes before redeployment

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="volume_backups/$DATE"

# Create backup directory  
mkdir -p $BACKUP_DIR

# Copy volume data
echo "Backing up volumes to $BACKUP_DIR..."
cp -r ./management-data $BACKUP_DIR/ 2>/dev/null || echo "No management data to backup"
cp -r ./ndb*-data $BACKUP_DIR/ 2>/dev/null || echo "No NDB data to backup"
cp -r ./mysql*-data $BACKUP_DIR/ 2>/dev/null || echo "No MySQL data to backup"

echo "Backup complete!"
```

### 3. Update ProxySQL Cluster Configuration

For true high availability between your two ProxySQL instances, you should enable ProxySQL clustering. Update your `proxysql.cnf` file to add:

```
# ProxySQL Clustering Configuration
proxysql_servers=(
    {
        hostname="proxysql2"
        port=6032
        comment="ProxySQL Instance 2"
    }
)

# Second ProxySQL instance needs this config
# proxysql_servers=(
#    {
#        hostname="proxysql"
#        port=6032
#        comment="ProxySQL Instance 1"
#    }
# )
```

### 4. Security Improvements

Create a `secure-passwords.sh` script to generate random secure passwords:

```bash
#!/bin/bash
# secure-passwords.sh - Generate secure passwords for MySQL NDB Cluster

# Generate secure random password
generate_password() {
    openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16
}

# Create passwords file if it doesn't exist
if [ ! -f ".env.passwords" ]; then
    echo "Generating secure passwords..."
    
    # Generate passwords
    ROOT_PASSWORD=$(generate_password)
    ADMIN_PASSWORD=$(generate_password)
    MONITOR_PASSWORD=$(generate_password)
    TESTUSER_PASSWORD=$(generate_password)
    READONLY_PASSWORD=$(generate_password)
    READWRITE_PASSWORD=$(generate_password)
    PROXYSQL_CLUSTER_PASSWORD=$(generate_password)
    
    # Write to .env.passwords file
    cat > .env.passwords << EOF
# MySQL and ProxySQL Passwords
# Generated on $(date)
# IMPORTANT: Keep this file secure!

ROOT_PASSWORD=$ROOT_PASSWORD
ADMIN_PASSWORD=$ADMIN_PASSWORD
MONITOR_PASSWORD=$MONITOR_PASSWORD
TESTUSER_PASSWORD=$TESTUSER_PASSWORD
READONLY_PASSWORD=$READONLY_PASSWORD
READWRITE_PASSWORD=$READWRITE_PASSWORD
PROXYSQL_CLUSTER_PASSWORD=$PROXYSQL_CLUSTER_PASSWORD
EOF
    
    echo "Passwords generated and saved to .env.passwords"
    echo "IMPORTANT: Keep this file secure and backed up!"
else
    echo ".env.passwords already exists. Not overwriting."
    echo "Delete this file if you want to generate new passwords."
fi
```

### 5. Persistent ProxySQL Monitoring

Create a script for monitoring your ProxySQL instances:

```bash
#!/bin/bash
# monitor-proxysql.sh - Monitor ProxySQL statistics

# Variables
ADMIN_USER="admin"
ADMIN_PASS="admin"  # Change this to your secure password
PROXYSQL1_HOST="127.0.0.1"
PROXYSQL1_PORT=6032
PROXYSQL2_HOST="127.0.0.1"
PROXYSQL2_PORT=6035

# Function to query ProxySQL
query_proxysql() {
    local host=$1
    local port=$2
    local query=$3
    
    mysql -h$host -P$port -u$ADMIN_USER -p$ADMIN_PASS -e "$query"
}

# Check connection status
echo "ProxySQL 1 - Backend Connections:"
query_proxysql $PROXYSQL1_HOST $PROXYSQL1_PORT "SELECT hostgroup_id, hostname, port, status, ConnUsed, ConnFree, ConnOK, ConnERR FROM mysql_servers"

echo -e "\nProxySQL 2 - Backend Connections:"
query_proxysql $PROXYSQL2_HOST $PROXYSQL2_PORT "SELECT hostgroup_id, hostname, port, status, ConnUsed, ConnFree, ConnOK, ConnERR FROM mysql_servers"

# Check query statistics
echo -e "\nProxySQL 1 - Query Statistics:"
query_proxysql $PROXYSQL1_HOST $PROXYSQL1_PORT "SELECT hostgroup, digest_text, count_star, sum_time FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10"

echo -e "\nProxySQL 2 - Query Statistics:"
query_proxysql $PROXYSQL2_HOST $PROXYSQL2_PORT "SELECT hostgroup, digest_text, count_star, sum_time FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10"
```

## Production Checklist

Before deploying this setup to production, ensure you've addressed the following:

1. **Security**:
   - [ ] Replace all default/weak passwords with strong, unique passwords
   - [ ] Enable SSL/TLS for MySQL and ProxySQL connections
   - [ ] Restrict network access to admin interfaces

2. **Monitoring**:
   - [ ] Implement comprehensive monitoring (Prometheus/Grafana recommended)
   - [ ] Set up alerting for critical events

3. **Backups**:
   - [ ] Implement regular backups of MySQL data
   - [ ] Test backup restoration procedure

4. **Resource Allocation**:
   - [ ] Adjust memory limits based on workload requirements
   - [ ] Consider dedicated physical servers for data nodes

5. **High Availability**:
   - [ ] Implement proper HAProxy or DNS-based load balancing in front of ProxySQL
   - [ ] Set up third-party monitoring to detect and handle failover scenarios

6. **Documentation**:
   - [ ] Document the entire setup, including recovery procedures
   - [ ] Create runbooks for common operational tasks

## Docker Compose Restart Behavior

To answer your specific question about `docker-compose up`:

When you run `docker-compose up` after the initial setup:
1. If volumes exist, initialization scripts in `/docker-entrypoint-initdb.d/` will NOT run again
2. Container configuration changes WILL apply
3. Container restarts WILL occur if there are changes in the configuration

If you need to force re-initialization:
1. Remove the volumes: `docker-compose down -v`
2. Start again: `docker-compose up`

However, this will delete all your data. For production, you should have proper backup procedures in place.
