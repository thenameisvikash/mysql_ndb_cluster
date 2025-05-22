#!/bin/bash
# Wait for MySQL servers to be fully available
echo "Waiting for MySQL servers to be ready..."
sleep 30

# Execute setup commands for ProxySQL
echo "Setting up ProxySQL..."

# Connect to ProxySQL admin interface
mysql -h 127.0.0.1 -P 6032 -u admin -padmin -e "
-- Make sure we're using the admin interface
USE admin;

-- Delete any existing server entries to avoid duplicates
DELETE FROM mysql_servers;

-- Insert MySQL servers into runtime
INSERT INTO mysql_servers (hostgroup_id, hostname, port, weight) VALUES (0, 'mysql1', 3306, 100);
INSERT INTO mysql_servers (hostgroup_id, hostname, port, weight) VALUES (0, 'mysql2', 3306, 100);

-- Configure user credentials
DELETE FROM mysql_users;
INSERT INTO mysql_users (username, password, active, default_hostgroup) VALUES ('root', 'rootpassword', 1, 0);
INSERT INTO mysql_users (username, password, active, default_hostgroup) VALUES ('testuser', 'testpassword', 1, 0);

-- Set monitoring credentials
UPDATE global_variables 
SET variable_value='root'
WHERE variable_name='mysql-monitor_username';

UPDATE global_variables 
SET variable_value='rootpassword'
WHERE variable_name='mysql-monitor_password';

-- Apply changes to runtime
LOAD MYSQL SERVERS TO RUNTIME;
LOAD MYSQL USERS TO RUNTIME;
LOAD MYSQL VARIABLES TO RUNTIME;

-- Save to disk
SAVE MYSQL SERVERS TO DISK;
SAVE MYSQL USERS TO DISK;
SAVE MYSQL VARIABLES TO DISK;
"

echo "ProxySQL setup completed"

# Keep the container running
tail -f /dev/null
