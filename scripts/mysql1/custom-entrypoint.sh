#!/bin/bash
set -eo pipefail

# Remove any existing socket files to avoid conflicts
rm -f /var/run/mysqld/mysqld.sock* /var/run/mysqld/mysqlx.sock*

# Execute the original entrypoint with all arguments
exec /entrypoint.sh "$@"
