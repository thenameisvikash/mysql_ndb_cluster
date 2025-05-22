#!/bin/bash
# MySQL initialization script to be run on the second MySQL node
# This will create all necessary users for ProxySQL and verify test database/tables

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
sleep 30

# Check if MySQL is actually ready - try both localhost and 127.0.0.1
MAX_ATTEMPTS=15
ATTEMPT=0
CONNECTED=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ] && [ "$CONNECTED" = false ]
do
  echo "Checking MySQL readiness (attempt $((ATTEMPT+1))/$MAX_ATTEMPTS)..."
  
  # Try localhost first (socket connection)
  if mysqladmin ping -h localhost -u root -prootpassword &>/dev/null; then
    echo "MySQL is ready via localhost socket!"
    MYSQL_HOST="localhost"
    CONNECTED=true
    break
  fi
  
  # Try IP connection
  if mysqladmin ping -h 127.0.0.1 -P 3306 -u root -prootpassword &>/dev/null; then
    echo "MySQL is ready via TCP connection!"
    MYSQL_HOST="127.0.0.1"
    CONNECTED=true
    break
  fi
  
  ATTEMPT=$((ATTEMPT+1))
  sleep 5
done

if [ "$CONNECTED" = false ]; then
  echo "Failed to connect to MySQL after $MAX_ATTEMPTS attempts. Will try to proceed anyway..."
  # Default to localhost and hope for the best
  MYSQL_HOST="localhost"
fi

# Create test database and table required by the test suite
echo "Creating test database and tables for test suite..."

if [ "$MYSQL_HOST" = "localhost" ]; then
  mysql -uroot -prootpassword << EOSQL
# Create test database
CREATE DATABASE IF NOT EXISTS test_db;
USE test_db;

# Create test table with NDB storage engine
CREATE TABLE IF NOT EXISTS test_table (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  data VARCHAR(255) NOT NULL
) ENGINE=NDBCLUSTER;

# Insert initial test data if table is empty
INSERT IGNORE INTO test_table (id, data) VALUES (1, 'Initial test data 1'), (2, 'Initial test data 2'), (3, 'Initial test data 3');
EOSQL
else
  mysql -h"$MYSQL_HOST" -P3306 -uroot -prootpassword << EOSQL
# Create test database
CREATE DATABASE IF NOT EXISTS test_db;
USE test_db;

# Create test table with NDB storage engine
CREATE TABLE IF NOT EXISTS test_table (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  data VARCHAR(255) NOT NULL
) ENGINE=NDBCLUSTER;

# Insert initial test data if table is empty
INSERT IGNORE INTO test_table (id, data) VALUES (1, 'Initial test data 1'), (2, 'Initial test data 2'), (3, 'Initial test data 3');
EOSQL
fi

# Create users for ProxySQL
echo "Creating users for ProxySQL using host: $MYSQL_HOST"

if [ "$MYSQL_HOST" = "localhost" ]; then
  mysql -uroot -prootpassword < /docker-entrypoint-initdb.d/init-mysql-users.sql
else
  mysql -h"$MYSQL_HOST" -P3306 -uroot -prootpassword < /docker-entrypoint-initdb.d/init-mysql-users.sql
fi

# Create additional users required by the test suite with mysql_native_password authentication
echo "Creating additional users required by the test suite..."

if [ "$MYSQL_HOST" = "localhost" ]; then
  mysql -uroot -prootpassword << EOSQL
# Create test user
CREATE USER IF NOT EXISTS 'testuser'@'%' IDENTIFIED WITH mysql_native_password BY 'testpassword';
GRANT ALL PRIVILEGES ON test_db.* TO 'testuser'@'%';

# Create read-write user
CREATE USER IF NOT EXISTS 'readwrite'@'%' IDENTIFIED WITH mysql_native_password BY 'readwritepass';
GRANT ALL PRIVILEGES ON test_db.* TO 'readwrite'@'%';

# Create read-only user
CREATE USER IF NOT EXISTS 'readonly'@'%' IDENTIFIED WITH mysql_native_password BY 'readonlypass';
GRANT SELECT ON test_db.* TO 'readonly'@'%';

# Create admin user
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED WITH mysql_native_password BY 'adminpass';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';

FLUSH PRIVILEGES;
EOSQL
else
  mysql -h"$MYSQL_HOST" -P3306 -uroot -prootpassword << EOSQL
# Create test user
CREATE USER IF NOT EXISTS 'testuser'@'%' IDENTIFIED WITH mysql_native_password BY 'testpassword';
GRANT ALL PRIVILEGES ON test_db.* TO 'testuser'@'%';

# Create read-write user
CREATE USER IF NOT EXISTS 'readwrite'@'%' IDENTIFIED WITH mysql_native_password BY 'readwritepass';
GRANT ALL PRIVILEGES ON test_db.* TO 'readwrite'@'%';

# Create read-only user
CREATE USER IF NOT EXISTS 'readonly'@'%' IDENTIFIED WITH mysql_native_password BY 'readonlypass';
GRANT SELECT ON test_db.* TO 'readonly'@'%';

# Create admin user
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED WITH mysql_native_password BY 'adminpass';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';

FLUSH PRIVILEGES;
EOSQL
fi

# Verify setup
echo "Verifying test database and users..."
if [ "$MYSQL_HOST" = "localhost" ]; then
  mysql -uroot -prootpassword -e "SHOW DATABASES LIKE 'test_db'; USE test_db; SHOW TABLES; SELECT * FROM test_table; SELECT User, Host, plugin FROM mysql.user WHERE User IN ('testuser', 'readwrite', 'readonly', 'admin');"
else
  mysql -h"$MYSQL_HOST" -P3306 -uroot -prootpassword -e "SHOW DATABASES LIKE 'test_db'; USE test_db; SHOW TABLES; SELECT * FROM test_table; SELECT User, Host, plugin FROM mysql.user WHERE User IN ('testuser', 'readwrite', 'readonly', 'admin');"
fi

echo "MySQL initialization completed!"

echo "MySQL initialization complete!"
