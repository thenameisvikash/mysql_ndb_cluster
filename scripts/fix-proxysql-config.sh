#!/bin/bash
# Script to fix ProxySQL configuration for MySQL Cluster

echo "Stopping ProxySQL container..."
docker stop proxysql

echo "Creating a new ProxySQL configuration file..."
cat > /home/vikash/test/mysqlcluster/config/proxysql-new.cnf << 'EOF'
# ProxySQL Configuration for MySQL NDB Cluster
# This configuration file contains optimized settings for MySQL Cluster

# ProxySQL Data Directory
datadir="/var/lib/proxysql"

# Admin Interface Configuration
admin_variables=
{
    admin_credentials="admin:admin;radmin:radmin"
    mysql_ifaces="0.0.0.0:6032"
    refresh_interval=2000
}

# MySQL Interface Configuration
mysql_variables=
{
    interfaces="0.0.0.0:6033"
    default_schema="test_db"
    server_version="8.0.32"
    threads=4
    max_connections=2048
    default_query_delay=0
    default_query_timeout=36000000
    have_compress=true
    poll_timeout=2000
    interfaces="0.0.0.0:6033"
    default_schema="test_db"
    stacksize=1048576
    connect_timeout_server=3000
    monitor_username="root"
    monitor_password="rootpassword"
    monitor_history=600000
    monitor_connect_interval=60000
    monitor_ping_interval=10000
    monitor_read_only_interval=1500
    monitor_read_only_timeout=500
    ping_interval_server_msec=120000
    ping_timeout_server=500
    commands_stats=true
    sessions_sort=true
    connect_retries_on_failure=10
}

# MySQL Servers Configuration
mysql_servers =
(
    {
        address="mysql1"
        port=3306
        hostgroup=0
        status="ONLINE"
        weight=1
        compression=0
        max_connections=1000
    },
    {
        address="mysql2"
        port=3306
        hostgroup=0
        status="ONLINE"
        weight=1
        compression=0
        max_connections=1000
    },
    {
        address="mysql1"
        port=3306
        hostgroup=1
        status="ONLINE"
        weight=1
        compression=0
        max_connections=1000
    },
    {
        address="mysql2"
        port=3306
        hostgroup=1
        status="ONLINE"
        weight=1
        compression=0
        max_connections=1000
    }
)

# MySQL Users Configuration
mysql_users =
(
    {
        username = "root"
        password = "rootpassword"
        default_hostgroup = 0
        active = 1
    },
    {
        username = "testuser"
        password = "testpassword"
        default_hostgroup = 0
        active = 1
    },
    {
        username = "readonly"
        password = "readonlypass"
        default_hostgroup = 1
        active = 1
    },
    {
        username = "readwrite"
        password = "readwritepass"
        default_hostgroup = 0
        active = 1
    },
    {
        username = "admin"
        password = "adminpass"
        default_hostgroup = 0
        active = 1
    }
)

# MySQL Query Rules Configuration
mysql_query_rules =
(
    {
        rule_id=1
        active=1
        match_pattern="^SELECT"
        destination_hostgroup=1
        apply=1
    },
    {
        rule_id=2
        active=1
        match_pattern=".*"
        destination_hostgroup=0
        apply=1
    }
)
EOF

echo "Updating docker-compose.yml to use the new configuration..."
sed -i 's|./config/proxysql-fixed.cnf:/etc/proxysql.cnf|./config/proxysql-new.cnf:/etc/proxysql.cnf|g' /home/vikash/test/mysqlcluster/docker-compose.yml

echo "Starting ProxySQL with the new configuration..."
docker start proxysql

echo "Waiting for ProxySQL to initialize..."
sleep 10

echo "Testing connection to ProxySQL..."
mysql -h127.0.0.1 -P6033 -utestuser -ptestpassword -e "SELECT USER(), CURRENT_USER(), @@hostname;"

echo "Testing read operations through ProxySQL..."
mysql -h127.0.0.1 -P6033 -ureadonly -preadonlypass -e "USE test_db; SELECT * FROM test_table LIMIT 3;"

echo "Testing write operations through ProxySQL..."
mysql -h127.0.0.1 -P6033 -ureadwrite -preadwritepass -e "USE test_db; INSERT INTO test_table (data) VALUES ('Test from readwrite user via ProxySQL'); SELECT * FROM test_table WHERE data='Test from readwrite user via ProxySQL';"

echo "ProxySQL configuration has been updated and tested."
