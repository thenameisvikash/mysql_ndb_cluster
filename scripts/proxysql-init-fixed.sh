#!/bin/bash
# ProxySQL initialization script
# This script configures ProxySQL with the correct server and user settings

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
sleep 45

# Check if MySQL is actually ready
MAX_ATTEMPTS=10
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]
do
  echo "Checking MySQL connectivity (attempt $((ATTEMPT+1))/$MAX_ATTEMPTS)..."
  if mysql -h mysql1 -uroot -prootpassword -e "SELECT 1" &>/dev/null; then
    echo "Successfully connected to MySQL!"
    break
  fi
  ATTEMPT=$((ATTEMPT+1))
  sleep 10
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo "Failed to connect to MySQL after $MAX_ATTEMPTS attempts. Continuing anyway..."
fi

# Configure ProxySQL
echo "Configuring ProxySQL..."
mysql -h127.0.0.1 -P6032 -uadmin -padmin << EOF
-- Configure MySQL Servers
DELETE FROM mysql_servers;
INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight, max_connections, comment) 
  VALUES (0, 'mysql1', 3306, 1000, 2000, 'NDB SQL Node 1 - Primary Write');
INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight, max_connections, comment) 
  VALUES (0, 'mysql2', 3306, 500, 2000, 'NDB SQL Node 2 - Secondary Write');
INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight, max_connections, comment) 
  VALUES (10, 'mysql1', 3306, 500, 2000, 'NDB SQL Node 1 - Secondary Read');
INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight, max_connections, comment) 
  VALUES (10, 'mysql2', 3306, 1000, 2000, 'NDB SQL Node 2 - Primary Read');

-- Configure MySQL Users
DELETE FROM mysql_users;
INSERT INTO mysql_users(username, password, default_hostgroup, active) 
  VALUES ('root', 'rootpassword', 0, 1);
INSERT INTO mysql_users(username, password, default_hostgroup, active) 
  VALUES ('readwrite', 'readwritepass', 0, 1);
INSERT INTO mysql_users(username, password, default_hostgroup, active) 
  VALUES ('readonly', 'readonlypass', 10, 1);
INSERT INTO mysql_users(username, password, default_hostgroup, active) 
  VALUES ('testuser', 'testpass', 0, 1);
INSERT INTO mysql_users(username, password, default_hostgroup, active) 
  VALUES ('proxyuser', 'proxypass', 0, 1);
INSERT INTO mysql_users(username, password, default_hostgroup, active) 
  VALUES ('proxysql_monitor', 'monitorpass123', 0, 1);

-- Configure Query Rules
DELETE FROM mysql_query_rules;
INSERT INTO mysql_query_rules(rule_id, active, match_digest, destination_hostgroup, apply) 
  VALUES (1, 1, '^\\s*INSERT\\s|^\\s*UPDATE\\s|^\\s*DELETE\\s|^\\s*REPLACE\\s', 0, 1);
INSERT INTO mysql_query_rules(rule_id, active, match_digest, destination_hostgroup, apply) 
  VALUES (2, 1, '^\\s*SELECT\\s', 10, 1);
INSERT INTO mysql_query_rules(rule_id, active, match_digest, destination_hostgroup, apply) 
  VALUES (3, 1, '^\\s*CREATE\\s|^\\s*ALTER\\s|^\\s*DROP\\s|^\\s*TRUNCATE\\s', 0, 1);
INSERT INTO mysql_query_rules(rule_id, active, username, destination_hostgroup, apply) 
  VALUES (100, 1, 'readonly', 10, 1);
INSERT INTO mysql_query_rules(rule_id, active, username, destination_hostgroup, apply) 
  VALUES (101, 1, 'readwrite', 0, 1);
INSERT INTO mysql_query_rules(rule_id, active, match_digest, destination_hostgroup, apply) 
  VALUES (1000, 1, '.*', 0, 1);

-- Configure monitoring user
UPDATE global_variables SET variable_value='proxysql_monitor' WHERE variable_name='mysql-monitor_username';
UPDATE global_variables SET variable_value='monitorpass123' WHERE variable_name='mysql-monitor_password';
UPDATE global_variables SET variable_value='true' WHERE variable_name='mysql-monitor_enabled';

-- Apply changes
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;
EOF

echo "ProxySQL configuration complete!"
