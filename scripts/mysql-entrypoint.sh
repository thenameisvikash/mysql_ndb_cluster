#!/bin/bash
# Custom MySQL entrypoint script to handle log directory permissions
set -e

echo "[MySQL Entrypoint] Starting custom initialization..."

# Create log directories with proper permissions
echo "[MySQL Entrypoint] Setting up log directories..."
mkdir -p /var/log/mysql
chmod -R 777 /var/log/mysql
touch /var/log/mysql/error.log /var/log/mysql/slow.log /var/log/mysql/general.log
chmod 666 /var/log/mysql/error.log /var/log/mysql/slow.log /var/log/mysql/general.log
ls -la /var/log/mysql

# Create data directory with proper permissions
echo "[MySQL Entrypoint] Setting up data directory..."
mkdir -p /var/lib/mysql
chmod -R 777 /var/lib/mysql
chown -R mysql:mysql /var/lib/mysql
ls -la /var/lib/mysql

echo "[MySQL Entrypoint] Custom initialization complete, starting MySQL..."

# Execute the original entrypoint
exec /usr/local/bin/docker-entrypoint.sh "$@"
