#!/bin/bash
# Script to fix ProxySQL configuration issues

# Wait for ProxySQL to be fully available
echo "Waiting for ProxySQL to be ready..."
sleep 5

# Connect to ProxySQL container
docker exec -it proxysql bash -c "
# Create a temporary configuration file
cat > /tmp/proxysql_fix.sql << 'EOF'
-- Reset server configurations
DELETE FROM mysql_servers;

-- Add MySQL servers with proper hostnames (container names)
INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight, max_connections, comment) 
  VALUES (0, 'mysql1', 3306, 1000, 200, 'NDB SQL Node 1 - Write');
INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight, max_connections, comment) 
  VALUES (0, 'mysql2', 3306, 500, 200, 'NDB SQL Node 2 - Write');
INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight, max_connections, comment) 
  VALUES (10, 'mysql1', 3306, 500, 200, 'NDB SQL Node 1 - Read');
INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight, max_connections, comment) 
  VALUES (10, 'mysql2', 3306, 1000, 200, 'NDB SQL Node 2 - Read');

-- Configure users
DELETE FROM mysql_users;
INSERT INTO mysql_users(username, password, default_hostgroup, active, transaction_persistent, max_connections) 
  VALUES ('testuser', 'testpassword', 0, 1, 1, 1000);
INSERT INTO mysql_users(username, password, default_hostgroup, active, transaction_persistent, max_connections) 
  VALUES ('readonly', 'readonlypass', 10, 1, 0, 1000);
INSERT INTO mysql_users(username, password, default_hostgroup, active, transaction_persistent, max_connections) 
  VALUES ('readwrite', 'readwritepass', 0, 1, 1, 1000);
INSERT INTO mysql_users(username, password, default_hostgroup, active, transaction_persistent, max_connections) 
  VALUES ('admin', 'adminpass', 0, 1, 1, 1000);
INSERT INTO mysql_users(username, password, default_hostgroup, active, transaction_persistent, max_connections) 
  VALUES ('root', 'rootpassword', 0, 1, 1, 1000);

-- Configure query rules for read/write splitting
DELETE FROM mysql_query_rules;
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) 
  VALUES (1, 1, '^INSERT', 0, 1);
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) 
  VALUES (2, 1, '^UPDATE', 0, 1);
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) 
  VALUES (3, 1, '^DELETE', 0, 1);
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) 
  VALUES (4, 1, '^REPLACE', 0, 1);
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) 
  VALUES (5, 1, '^CREATE', 0, 1);
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) 
  VALUES (6, 1, '^ALTER', 0, 1);
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) 
  VALUES (7, 1, '^DROP', 0, 1);
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) 
  VALUES (8, 1, '^TRUNCATE', 0, 1);
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) 
  VALUES (100, 1, '^SELECT', 10, 1);

-- Apply changes
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
EOF

# Execute the SQL file
mysql -h127.0.0.1 -P6032 -uadmin -padmin < /tmp/proxysql_fix.sql
"

echo "ProxySQL configuration has been updated."
echo "Testing connection to ProxySQL..."

# Test connection with testuser
mysql -h127.0.0.1 -P6033 -utestuser -ptestpassword -e "SELECT 'Connection successful!' AS Status;"

# Test connection with readonly user
mysql -h127.0.0.1 -P6033 -ureadonly -preadonlypass -e "SELECT 'Connection successful!' AS Status;"

# Test connection with readwrite user
mysql -h127.0.0.1 -P6033 -ureadwrite -preadwritepass -e "SELECT 'Connection successful!' AS Status;"

echo "Configuration complete!"
