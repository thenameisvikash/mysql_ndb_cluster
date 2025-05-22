#!/bin/bash
# MySQL initialization script to be run on the first MySQL node
# This will create all necessary users for ProxySQL

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

# Create users for ProxySQL
echo "Creating users for ProxySQL using host: $MYSQL_HOST"

if [ "$MYSQL_HOST" = "localhost" ]; then
  mysql -uroot -prootpassword < /docker-entrypoint-initdb.d/init-mysql-users.sql
else
  mysql -h"$MYSQL_HOST" -P3306 -uroot -prootpassword < /docker-entrypoint-initdb.d/init-mysql-users.sql
fi

echo "MySQL initialization completed!"

echo "MySQL initialization complete!"
