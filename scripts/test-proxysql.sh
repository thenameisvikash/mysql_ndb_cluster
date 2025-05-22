#!/bin/bash

# Function to print section headers
section() {
    echo -e "\n\033[1;33m=== $1 ===\033[0m"
}

# Test ProxySQL admin interface
section "Testing ProxySQL Admin Interface"
docker exec -it proxysql mysql -uadmin -padmin -h127.0.0.1 -P6032 -e "
    SELECT * FROM mysql_servers;
    SELECT rule_id, active, match_pattern, destination_hostgroup, apply FROM mysql_query_rules ORDER BY rule_id;
"

# Test read/write splitting with different users
section "Testing Read/Write Splitting"

# Test with testuser (default routing)
section "Testing with testuser (default routing)"
echo "Write operation (should go to writer - mysql1):"
docker exec -it proxysql mysql -utestuser -ptestpassword -h127.0.0.1 -P6033 -e "
    USE test_db;
    INSERT INTO test_table (data) VALUES ('test_data_from_testuser');
    SELECT 'Last insert ID:', LAST_INSERT_ID() AS last_id;
"

echo -e "\nRead operation (should go to reader - mysql2):"
docker exec -it proxysql mysql -utestuser -ptestpassword -h127.0.0.1 -P6033 -e "
    USE test_db;
    SELECT * FROM test_table ORDER BY created_at DESC LIMIT 5;
"

# Test with readwrite user (should always go to writer)
section "Testing with readwrite user (writer only)"
echo "Write operation (should go to writer - mysql1):"
docker exec -it proxysql mysql -ureadwrite -preadwritepass -h127.0.0.1 -P6033 -e "
    USE test_db;
    INSERT INTO test_table (data) VALUES ('test_data_from_readwrite');
    SELECT 'Last insert ID:', LAST_INSERT_ID() AS last_id;
"

# Test with readonly user (should always go to reader)
section "Testing with readonly user (reader only)"
echo "Read operation (should go to reader - mysql2):"
docker exec -it proxysql mysql -ureadonly -preadonlypass -h127.0.0.1 -P6033 -e "
    USE test_db;
    SELECT * FROM test_table ORDER BY created_at DESC LIMIT 5;
" 2>&1 | grep -v "Using a password"

# Check query routing and statistics
section "ProxySQL Query Routing Statistics"
docker exec -it proxysql mysql -uadmin -padmin -h127.0.0.1 -P6032 -e "
    SELECT 
        hostgroup, 
        srv_host, 
        srv_port,
        status, 
        ConnUsed, 
        ConnFree, 
        ConnOK, 
        ConnERR,
        Queries,
        Bytes_data_sent,
        Bytes_data_recv
    FROM stats.stats_mysql_connection_pool 
    ORDER BY hostgroup, srv_host;
    
    SELECT 
        hostgroup, 
        srv_host, 
        Queries,
        Latency_us 
    FROM stats.stats_mysql_connection_pool 
    ORDER BY hostgroup, srv_host;
"

echo -e "\n\033[1;32mTesting completed!\033[0m"
echo "Check the output above to verify read/write splitting and user-based routing."
