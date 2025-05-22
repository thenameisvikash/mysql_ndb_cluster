#!/bin/bash
sleep 15  # Wait for ProxySQL to start

# Connect to ProxySQL admin interface
mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
# Configure MySQL Servers with proper hostgroups for NDB Cluster
DELETE FROM mysql_servers;

# In NDB Cluster, both SQL nodes can handle reads and writes
# We'll put both in hostgroup 0 for writes with different weights for load balancing
INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight, max_connections, comment) 
  VALUES (0, 'mysql1', 3306, 1000, 200, 'NDB SQL Node 1 - Write');
INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight, max_connections, comment) 
  VALUES (0, 'mysql2', 3306, 500, 200, 'NDB SQL Node 2 - Write');

# We'll also put both in hostgroup 10 for reads with balanced weights
INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight, max_connections, comment) 
  VALUES (10, 'mysql1', 3306, 500, 200, 'NDB SQL Node 1 - Read');
INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight, max_connections, comment) 
  VALUES (10, 'mysql2', 3306, 1000, 200, 'NDB SQL Node 2 - Read');

# Configure MySQL Users
DELETE FROM mysql_users;

# Regular user with transaction persistence - using mysql_native_password for compatibility
INSERT INTO mysql_users(username, password, default_hostgroup, active, transaction_persistent, max_connections, frontend) 
  VALUES ('testuser', 'testpassword', 0, 1, 1, 1000, 1);

# Read-only user - using mysql_native_password for compatibility
INSERT INTO mysql_users(username, password, default_hostgroup, active, transaction_persistent, max_connections, frontend) 
  VALUES ('readonly', 'readonlypass', 10, 1, 0, 1000, 1);

# Read-write user - using mysql_native_password for compatibility
INSERT INTO mysql_users(username, password, default_hostgroup, active, transaction_persistent, max_connections, frontend) 
  VALUES ('readwrite', 'readwritepass', 0, 1, 1, 1000, 1);

# Admin user - using mysql_native_password for compatibility
INSERT INTO mysql_users(username, password, default_hostgroup, active, transaction_persistent, max_connections, frontend) 
  VALUES ('admin', 'adminpass', 0, 1, 1, 1000, 1);

# Monitoring user - using mysql_native_password for compatibility
INSERT INTO mysql_users(username, password, default_hostgroup, active, transaction_persistent, max_connections, frontend) 
  VALUES ('proxysql_monitor', 'monitorpass123', 0, 1, 0, 1000, 1);

# Configure Query Rules for Read/Write Splitting
DELETE FROM mysql_query_rules;

# Route writes to hostgroup 0 (both SQL nodes can handle writes in NDB Cluster)
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

# Route reads to hostgroup 10 (both SQL nodes can handle reads in NDB Cluster)
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) 
  VALUES (100, 1, '^SELECT', 10, 1);
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) 
  VALUES (101, 1, '^SHOW', 10, 1);
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) 
  VALUES (102, 1, '^(DESCRIBE|EXPLAIN)', 10, 1);

# User-specific routing
INSERT INTO mysql_query_rules(rule_id, active, username, destination_hostgroup, apply) 
  VALUES (200, 1, 'readonly', 10, 1);
INSERT INTO mysql_query_rules(rule_id, active, username, destination_hostgroup, apply) 
  VALUES (201, 1, 'readwrite', 0, 1);

# Fallback rule
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) 
  VALUES (1000, 1, '.*', 0, 1);

# Configure monitoring for high availability
UPDATE global_variables SET variable_value='true' WHERE variable_name='mysql-monitor_enabled';
UPDATE global_variables SET variable_value='2000' WHERE variable_name='mysql-monitor_connect_interval';
UPDATE global_variables SET variable_value='1000' WHERE variable_name='mysql-monitor_ping_interval';

# Apply changes
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;

LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;

LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;

LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;
"
