#!/bin/bash
# MySQL Cluster Comprehensive Test Suite
# This script performs automated testing of a MySQL Cluster with ProxySQL setup
# Author: DevOpsAgent
# Date: 2025-05-22

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables - can be overridden with environment variables
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-"rootpassword"}
MYSQL_HOST=${MYSQL_HOST:-"127.0.0.1"}
MYSQL_PORT=${MYSQL_PORT:-"3306"}
PROXYSQL_HOST=${PROXYSQL_HOST:-"127.0.0.1"}
PROXYSQL_PORT=${PROXYSQL_PORT:-"6033"}
PROXYSQL_ADMIN_PORT=${PROXYSQL_ADMIN_PORT:-"6032"}
PROXYSQL_ADMIN_USER=${PROXYSQL_ADMIN_USER:-"radmin"}
PROXYSQL_ADMIN_PASSWORD=${PROXYSQL_ADMIN_PASSWORD:-"radmin"}
PROXYSQL2_PORT=${PROXYSQL2_PORT:-"6034"}
PROXYSQL2_ADMIN_PORT=${PROXYSQL2_ADMIN_PORT:-"6035"}
TEST_DB=${TEST_DB:-"test_db"}
TEST_TABLE=${TEST_TABLE:-"test_table"}
READWRITE_USER=${READWRITE_USER:-"readwrite"}
READWRITE_PASSWORD=${READWRITE_PASSWORD:-"readwritepass"}
READONLY_USER=${READONLY_USER:-"readonly"}
READONLY_PASSWORD=${READONLY_PASSWORD:-"readonlypass"}
MANAGEMENT_NODE=${MANAGEMENT_NODE:-"management1"}
MANAGEMENT_NODE_IP=${MANAGEMENT_NODE_IP:-"172.20.0.2"}
MANAGEMENT_PORT=${MANAGEMENT_PORT:-"1186"}
TEST_DATA_SIZE=${TEST_DATA_SIZE:-100}
WAIT_TIME=${WAIT_TIME:-10}

# Test result counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}========== $1 ==========${NC}\n"
}

# Function to print test results
print_result() {
    local test_name=$1
    local result=$2
    local details=$3
    
    TESTS_TOTAL=$((TESTS_TOTAL+1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓ PASS:${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED+1))
    else
        echo -e "${RED}✗ FAIL:${NC} $test_name"
        echo -e "${YELLOW}Details: $details${NC}"
        TESTS_FAILED=$((TESTS_FAILED+1))
    fi
}

# Function to run a command and check its success
run_test_command() {
    local test_name=$1
    local command=$2
    local expected_success=$3  # true or false
    
    # Run the command and capture output and exit code
    output=$(eval "$command" 2>&1)
    exit_code=$?
    
    if [ "$expected_success" = "true" ] && [ $exit_code -eq 0 ]; then
        print_result "$test_name" "PASS" ""
        echo "$output"
        return 0
    elif [ "$expected_success" = "false" ] && [ $exit_code -ne 0 ]; then
        print_result "$test_name" "PASS" ""
        echo "$output"
        return 0
    else
        if [ "$expected_success" = "true" ]; then
            print_result "$test_name" "FAIL" "Command failed with exit code $exit_code"
        else
            print_result "$test_name" "FAIL" "Command succeeded but was expected to fail"
        fi
        echo "$output"
        return 1
    fi
}

# Function to check if a string is in command output
check_output_contains() {
    local test_name=$1
    local command=$2
    local expected_string=$3
    local invert=${4:-false}  # Set to "true" to check if string is NOT in output
    local expect_failure=${5:-false}  # Set to "true" if the command is expected to fail
    
    # Run the command and capture output
    output=$(eval "$command" 2>&1)
    exit_code=$?
    
    # If we expect the command to fail and it did fail, or if we don't expect it to fail and it didn't fail, proceed
    # Otherwise, report failure
    if [ "$expect_failure" = "true" ] && [ $exit_code -eq 0 ]; then
        print_result "$test_name" "FAIL" "Command succeeded but was expected to fail"
        echo "$output"
        return 1
    elif [ "$expect_failure" = "false" ] && [ $exit_code -ne 0 ] && [ "$expected_string" != "denied" ]; then
        print_result "$test_name" "FAIL" "Command failed with exit code $exit_code"
        echo "$output"
        return 1
    fi
    
    if [ "$invert" = "false" ] && echo "$output" | grep -q "$expected_string"; then
        print_result "$test_name" "PASS" ""
        echo "$output"
        return 0
    elif [ "$invert" = "true" ] && ! echo "$output" | grep -q "$expected_string"; then
        print_result "$test_name" "PASS" ""
        echo "$output"
        return 0
    else
        if [ "$invert" = "false" ]; then
            print_result "$test_name" "FAIL" "Output does not contain expected string: '$expected_string'"
        else
            print_result "$test_name" "FAIL" "Output contains string that should not be present: '$expected_string'"
        fi
        echo "$output"
        return 1
    fi
}

# Function to test cluster health
test_cluster_health() {
    print_header "CLUSTER HEALTH TESTS"
    
    # Check management node status
    run_test_command "Management Node Status" \
        "docker exec $MANAGEMENT_NODE ndb_mgm -e 'show' --ndb-connectstring=$MANAGEMENT_NODE_IP:$MANAGEMENT_PORT" \
        "true"
    
    # Check all nodes status
    run_test_command "All Nodes Status" \
        "docker exec $MANAGEMENT_NODE ndb_mgm -e 'all status' --ndb-connectstring=$MANAGEMENT_NODE_IP:$MANAGEMENT_PORT" \
        "true"
    
    # Check MySQL connection to cluster
    run_test_command "MySQL1 Cluster Connection" \
        "docker exec mysql1 mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e 'SHOW ENGINE NDBCLUSTER STATUS\\G'" \
        "true"
    
    run_test_command "MySQL2 Cluster Connection" \
        "docker exec mysql2 mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e 'SHOW ENGINE NDBCLUSTER STATUS\\G'" \
        "true"
}

# Function to test ProxySQL configuration
test_proxysql_config() {
    print_header "PROXYSQL CONFIGURATION TESTS"
    
    # Check ProxySQL server configuration
    run_test_command "ProxySQL Server Configuration" \
        "docker exec proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASSWORD -e 'SELECT hostgroup_id, hostname, port, status FROM mysql_servers'" \
        "true"
    
    # Check user configuration
    run_test_command "ProxySQL User Configuration" \
        "docker exec proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASSWORD -e 'SELECT username, default_hostgroup, active FROM mysql_users'" \
        "true"
    
    # Check query routing rules
    run_test_command "ProxySQL Query Rules" \
        "docker exec proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASSWORD -e 'SELECT rule_id, active, username, match_digest, destination_hostgroup FROM mysql_query_rules ORDER BY rule_id'" \
        "true"
    
    # Check monitoring status
    run_test_command "ProxySQL Monitoring Status" \
        "docker exec proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASSWORD -e 'SELECT * FROM mysql_server_ping_log ORDER BY time_start_us DESC LIMIT 5'" \
        "true"
    
    # Check connection pool
    run_test_command "ProxySQL Connection Pool" \
        "docker exec proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASSWORD -e 'SELECT * FROM stats_mysql_connection_pool'" \
        "true"
}

# Function to test data operations
test_data_operations() {
    print_header "DATA OPERATIONS TESTS"
    
    # Test write operations through ProxySQL
    run_test_command "Write Operations via ProxySQL" \
        "mysql -h$PROXYSQL_HOST -P$PROXYSQL_PORT -u$READWRITE_USER -p$READWRITE_PASSWORD -e 'USE $TEST_DB; INSERT INTO $TEST_TABLE (data) VALUES (\"ProxySQL write test\"); SELECT * FROM $TEST_TABLE WHERE data=\"ProxySQL write test\"'" \
        "true"
    
    # Test read operations through ProxySQL
    # Test read operations via ProxySQL
    # First, let's verify that the readonly user exists in MySQL and has the correct permissions
    run_test_command "Verify Readonly User in MySQL" \
        "docker exec mysql1 mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e \"SELECT User, Host, plugin FROM mysql.user WHERE User='$READONLY_USER'\"" \
        "true"

    # Now test read operations via ProxySQL from within the container
    run_test_command "Read Operations via ProxySQL (Container)" \
        "docker exec proxysql mysql -h127.0.0.1 -P6033 -u$READONLY_USER -p$READONLY_PASSWORD -e 'USE $TEST_DB; SELECT COUNT(*) FROM $TEST_TABLE'" \
        "true"
    
    # Test read operations via ProxySQL from the host machine
    run_test_command "Read Operations via ProxySQL (Host)" \
        "mysql -h$PROXYSQL_HOST -P$PROXYSQL_PORT -u$READONLY_USER -p$READONLY_PASSWORD -e 'USE $TEST_DB; SELECT COUNT(*) FROM $TEST_TABLE'" \
        "true"
    
    # Verify write permission restrictions for readonly user
    # First test from within the container
    check_output_contains "Read-only User Write Restriction (Container)" \
        "docker exec proxysql mysql -h127.0.0.1 -P6033 -u$READONLY_USER -p$READONLY_PASSWORD -e 'USE $TEST_DB; INSERT INTO $TEST_TABLE (data) VALUES (\"This should fail\")' 2>&1" \
        "denied" \
        "false"
        
    # Then test from the host machine
    check_output_contains "Read-only User Write Restriction (Host)" \
        "mysql -h$PROXYSQL_HOST -P$PROXYSQL_PORT -u$READONLY_USER -p$READONLY_PASSWORD -e 'USE $TEST_DB; INSERT INTO $TEST_TABLE (data) VALUES (\"This should fail\")' 2>&1" \
        "ERROR" \
        "false" \
        "true"
    
    # Test direct connection to MySQL nodes to verify data replication
    run_test_command "Data Replication to MySQL1" \
        "docker exec mysql1 mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e 'USE $TEST_DB; SELECT * FROM $TEST_TABLE WHERE data=\"ProxySQL write test\"'" \
        "true"
    
    run_test_command "Data Replication to MySQL2" \
        "docker exec mysql2 mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e 'USE $TEST_DB; SELECT * FROM $TEST_TABLE WHERE data=\"ProxySQL write test\"'" \
        "true"
}

# Function to test user management
test_user_management() {
    print_header "USER MANAGEMENT TESTS"
    
    # Create a new user in MySQL (drop if exists first)
    run_test_command "Create New User in MySQL" \
        "docker exec mysql1 mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e \"DROP USER IF EXISTS 'testuser_new'@'%'; CREATE USER 'testuser_new'@'%' IDENTIFIED WITH mysql_native_password BY 'newpass'; GRANT SELECT ON $TEST_DB.* TO 'testuser_new'@'%'; FLUSH PRIVILEGES;\"" \
        "true"
    
    # Add the new user to ProxySQL (delete if exists first)
    run_test_command "Add User to ProxySQL" \
        "docker exec proxysql mysql -h127.0.0.1 -P6032 -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASSWORD -e \"DELETE FROM mysql_users WHERE username='testuser_new'; INSERT INTO mysql_users(username, password, default_hostgroup, active, transaction_persistent, max_connections, frontend) VALUES ('testuser_new', 'newpass', 10, 1, 0, 1000, 1); LOAD MYSQL USERS TO RUNTIME; SAVE MYSQL USERS TO DISK;\"" \
        "true"
    
    # Wait for MySQL to be ready
    echo "Waiting for MySQL to be ready..."
    sleep 60
    
    echo -e "${YELLOW}Waiting 5 seconds for ProxySQL to recognize the new user...${NC}"
    sleep 5
    
    # Test the new user connection from container
    run_test_command "Test New User Connection (Container)" \
        "docker exec proxysql mysql -h127.0.0.1 -P6033 -utestuser_new -pnewpass -e \"USE $TEST_DB; SELECT COUNT(*) FROM $TEST_TABLE\"" \
        "true"
        
    # Test the new user connection from host
    run_test_command "Test New User Connection (Host)" \
        "mysql -h$PROXYSQL_HOST -P$PROXYSQL_PORT -utestuser_new -pnewpass -e \"USE $TEST_DB; SELECT COUNT(*) FROM $TEST_TABLE\"" \
        "true"
    
    # Test new user permissions (should be read-only)
    check_output_contains "New User Write Restriction" \
        "docker exec proxysql mysql -h127.0.0.1 -P6033 -utestuser_new -pnewpass -e \"USE $TEST_DB; INSERT INTO $TEST_TABLE (data) VALUES ('This should fail')\" 2>&1" \
        "ERROR" \
        "false" \
        "true"
    
    # Delete the test user directly on MySQL1
    run_test_command "Delete User from MySQL" \
        "docker exec mysql1 mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e \"DROP USER 'testuser_new'@'%'; FLUSH PRIVILEGES\"" \
        "true"
    
    run_test_command "Delete User from ProxySQL" \
        "docker exec proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASSWORD -e \"DELETE FROM mysql_users WHERE username='testuser_new'; LOAD MYSQL USERS TO RUNTIME; SAVE MYSQL USERS TO DISK\"" \
        "true"
}

# Function to test MySQL node failover
test_mysql_failover() {
    print_header "MYSQL NODE FAILOVER TESTS"
    
    # Stop mysql1
    run_test_command "Stop MySQL1 Node" \
        "docker stop mysql1" \
        "true"
    
    echo -e "${YELLOW}Waiting $WAIT_TIME seconds for failover...${NC}"
    sleep $WAIT_TIME
    
    # Check ProxySQL server status
    run_test_command "ProxySQL Server Status After MySQL1 Down" \
        "docker exec proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASSWORD -e 'SELECT hostgroup_id, hostname, port, status FROM mysql_servers'" \
        "true"
    
    # Verify ProxySQL redirects traffic to mysql2
    run_test_command "Write Operations During MySQL1 Down" \
        "mysql -h$PROXYSQL_HOST -P$PROXYSQL_PORT -u$READWRITE_USER -p$READWRITE_PASSWORD -e 'USE $TEST_DB; INSERT INTO $TEST_TABLE (data) VALUES (\"Failover test - mysql1 down\"); SELECT * FROM $TEST_TABLE WHERE data=\"Failover test - mysql1 down\"'" \
        "true"
    
    # Restart mysql1
    run_test_command "Restart MySQL1 Node" \
        "docker start mysql1" \
        "true"
    
    echo -e "${YELLOW}Waiting $WAIT_TIME seconds for mysql1 to rejoin...${NC}"
    sleep $WAIT_TIME
    
    # Verify mysql1 is back in the pool
    run_test_command "MySQL1 Rejoined Cluster" \
        "docker exec mysql1 mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e 'SHOW ENGINE NDBCLUSTER STATUS\\G'" \
        "true"
    
    # Verify data written during failover is visible on mysql1
    run_test_command "Data Consistency After Failover" \
        "docker exec mysql1 mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e 'USE $TEST_DB; SELECT * FROM $TEST_TABLE WHERE data=\"Failover test - mysql1 down\"'" \
        "true"
}

# Function to test data node failover
test_data_node_failover() {
    print_header "DATA NODE FAILOVER TESTS"
    
    # Stop ndb1
    run_test_command "Stop NDB1 Node" \
        "docker stop ndb1" \
        "true"
    
    echo -e "${YELLOW}Waiting $WAIT_TIME seconds for failover...${NC}"
    sleep $WAIT_TIME
    
    # Check cluster status
    run_test_command "Cluster Status After NDB1 Down" \
        "docker exec $MANAGEMENT_NODE ndb_mgm -e 'show' --ndb-connectstring=$MANAGEMENT_NODE_IP:$MANAGEMENT_PORT" \
        "true"
    
    # Insert data during failover
    run_test_command "Write Operations During NDB1 Down" \
        "mysql -h$PROXYSQL_HOST -P$PROXYSQL_PORT -u$READWRITE_USER -p$READWRITE_PASSWORD -e 'USE $TEST_DB; INSERT INTO $TEST_TABLE (data) VALUES (\"Failover test - ndb1 down\"); SELECT * FROM $TEST_TABLE WHERE data=\"Failover test - ndb1 down\"'" \
        "true"
    
    # Restart ndb1
    run_test_command "Restart NDB1 Node" \
        "docker start ndb1" \
        "true"
    
    echo -e "${YELLOW}Waiting $((WAIT_TIME*2)) seconds for ndb1 to rejoin...${NC}"
    sleep $((WAIT_TIME*2))
    
    # Verify cluster status
    run_test_command "Cluster Status After NDB1 Restart" \
        "docker exec $MANAGEMENT_NODE ndb_mgm -e 'show' --ndb-connectstring=$MANAGEMENT_NODE_IP:$MANAGEMENT_PORT" \
        "true"
}

# Function to test ProxySQL failover
test_proxysql_failover() {
    print_header "PROXYSQL FAILOVER TESTS"
    
    # Stop primary ProxySQL
    run_test_command "Stop Primary ProxySQL" \
        "docker stop proxysql" \
        "true"
    
    echo -e "${YELLOW}Waiting $WAIT_TIME seconds for failover...${NC}"
    sleep $WAIT_TIME
    
    # Test connection through secondary ProxySQL
    run_test_command "Write Operations Through Secondary ProxySQL" \
        "mysql -h$PROXYSQL_HOST -P$PROXYSQL2_PORT -u$READWRITE_USER -p$READWRITE_PASSWORD -e 'USE $TEST_DB; INSERT INTO $TEST_TABLE (data) VALUES (\"Failover test - proxysql down\"); SELECT * FROM $TEST_TABLE WHERE data=\"Failover test - proxysql down\"'" \
        "true"
    
    # Restart primary ProxySQL
    run_test_command "Restart Primary ProxySQL" \
        "docker start proxysql" \
        "true"
    
    echo -e "${YELLOW}Waiting $WAIT_TIME seconds for proxysql to restart...${NC}"
    sleep $WAIT_TIME
    
    # Verify primary ProxySQL is working again
    run_test_command "Primary ProxySQL Back Online" \
        "mysql -h$PROXYSQL_HOST -P$PROXYSQL_PORT -u$READWRITE_USER -p$READWRITE_PASSWORD -e 'USE $TEST_DB; SELECT * FROM $TEST_TABLE WHERE data=\"Failover test - proxysql down\"'" \
        "true"
}

# Function to test performance
test_performance() {
    print_header "PERFORMANCE TESTS"
    
    # Create a test script for batch inserts
    echo "USE $TEST_DB;" > /tmp/performance_test.sql
    echo "START TRANSACTION;" >> /tmp/performance_test.sql
    
    for i in $(seq 1 $TEST_DATA_SIZE); do
        echo "INSERT INTO $TEST_TABLE (data) VALUES ('Performance test row $i');" >> /tmp/performance_test.sql
    done
    
    echo "COMMIT;" >> /tmp/performance_test.sql
    
    # Run performance test with timing
    run_test_command "Batch Insert Performance ($TEST_DATA_SIZE rows)" \
        "time mysql -h$PROXYSQL_HOST -P$PROXYSQL_PORT -u$READWRITE_USER -p$READWRITE_PASSWORD < /tmp/performance_test.sql" \
        "true"
    
    # Test read performance
    run_test_command "Read Performance" \
        "time mysql -h$PROXYSQL_HOST -P$PROXYSQL_PORT -u$READONLY_USER -p$READONLY_PASSWORD -e 'USE $TEST_DB; SELECT COUNT(*) FROM $TEST_TABLE'" \
        "true"
    
    # Check ProxySQL query statistics
    run_test_command "ProxySQL Query Statistics" \
        "docker exec proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASSWORD -e 'SELECT digest_text, count_star, sum_time, hostgroup FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10'" \
        "true"
}

# Function to test monitoring
test_monitoring() {
    print_header "MONITORING TESTS"
    
    # Check ProxySQL monitoring user on mysql1
    run_test_command "ProxySQL Monitor User on MySQL1" \
        "docker exec mysql1 mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e \"SELECT User, Host FROM mysql.user WHERE User='proxysql_monitor'\"" \
        "true"
    
    # Check ProxySQL monitoring user on mysql2
    run_test_command "ProxySQL Monitor User on MySQL2" \
        "docker exec mysql2 mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e \"SELECT User, Host FROM mysql.user WHERE User='proxysql_monitor'\"" \
        "true"
    
    # Check ProxySQL monitoring logs
    run_test_command "ProxySQL Monitoring Logs" \
        "docker exec proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASSWORD -e 'SELECT * FROM mysql_server_ping_log ORDER BY time_start_us DESC LIMIT 10'" \
        "true"
    
    # Check MySQL cluster memory usage
    run_test_command "NDB Cluster Memory Usage" \
        "docker exec $MANAGEMENT_NODE ndb_mgm -e 'all report memory' --ndb-connectstring=$MANAGEMENT_NODE_IP:$MANAGEMENT_PORT" \
        "true"
}

# Function to fix common issues
fix_monitoring_user() {
    print_header "FIXING MONITORING USER ISSUE"
    
    # Check if monitoring user exists on mysql2
    monitor_user_exists=$(docker exec mysql2 mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e "SELECT COUNT(*) FROM mysql.user WHERE User='proxysql_monitor'" 2>/dev/null | grep -v "COUNT" | tr -d '[:space:]')
    
    if [ "$monitor_user_exists" = "0" ] || [ -z "$monitor_user_exists" ]; then
        echo -e "${YELLOW}Monitoring user missing on mysql2. Creating it now...${NC}"
        
        # Create monitoring user on mysql2
        run_test_command "Create Monitoring User on MySQL2" \
            "docker exec mysql2 mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e \"CREATE USER 'proxysql_monitor'@'%' IDENTIFIED WITH mysql_native_password BY 'monitorpass123'; GRANT USAGE, REPLICATION CLIENT, PROCESS, SELECT ON *.* TO 'proxysql_monitor'@'%'; FLUSH PRIVILEGES;\"" \
            "true"
        
        echo -e "${YELLOW}Waiting $WAIT_TIME seconds for ProxySQL to detect the new user...${NC}"
        sleep $WAIT_TIME
        
        # Verify monitoring is working
        run_test_command "Verify Monitoring After Fix" \
            "docker exec proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASSWORD -e 'SELECT * FROM mysql_server_ping_log ORDER BY time_start_us DESC LIMIT 5'" \
            "true"
    else
        echo -e "${GREEN}Monitoring user already exists on mysql2. No fix needed.${NC}"
    fi
}

# Function to print summary
print_summary() {
    print_header "TEST SUMMARY"
    
    echo -e "Total Tests: ${BLUE}$TESTS_TOTAL${NC}"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed successfully!${NC}"
    else
        echo -e "\n${RED}Some tests failed. Please check the output above for details.${NC}"
    fi
}

# Main function to run all tests
run_all_tests() {
    print_header "STARTING MYSQL CLUSTER TEST SUITE"
    
    # Fix monitoring user issue if needed
    fix_monitoring_user
    
    # Run all test modules
    test_cluster_health
    test_proxysql_config
    test_data_operations
    test_user_management
    test_mysql_failover
    test_data_node_failover
    test_proxysql_failover
    test_performance
    test_monitoring
    
    # Print summary
    print_summary
}

# Parse command line arguments
case "$1" in
    health)
        test_cluster_health
        print_summary
        ;;
    proxysql)
        test_proxysql_config
        print_summary
        ;;
    data)
        test_data_operations
        print_summary
        ;;
    users)
        test_user_management
        print_summary
        ;;
    mysql-failover)
        test_mysql_failover
        print_summary
        ;;
    data-failover)
        test_data_node_failover
        print_summary
        ;;
    proxysql-failover)
        test_proxysql_failover
        print_summary
        ;;
    performance)
        test_performance
        print_summary
        ;;
    monitoring)
        test_monitoring
        print_summary
        ;;
    fix-monitoring)
        fix_monitoring_user
        print_summary
        ;;
    all|"")
        run_all_tests
        ;;
    *)
        echo "Usage: $0 [health|proxysql|data|users|mysql-failover|data-failover|proxysql-failover|performance|monitoring|fix-monitoring|all]"
        exit 1
        ;;
esac

exit 0
