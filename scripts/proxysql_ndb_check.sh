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
