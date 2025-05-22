#!/bin/bash
# MySQL initialization script to be run on the first MySQL node
# This will create all necessary users for ProxySQL and test database/tables

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
  mysql -uroot -prootpassword << EOF
# Create test database
CREATE DATABASE IF NOT EXISTS test_db;
USE test_db;

# Create test table with NDB storage engine
CREATE TABLE IF NOT EXISTS test_table (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  data VARCHAR(255) NOT NULL
) ENGINE=NDBCLUSTER;

# Insert initial test data
INSERT INTO test_table (data) VALUES ('Initial test data 1'), ('Initial test data 2'), ('Initial test data 3')
ON DUPLICATE KEY UPDATE data=VALUES(data);
