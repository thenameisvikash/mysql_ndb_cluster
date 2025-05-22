-- Drop existing users first to avoid conflicts
DROP USER IF EXISTS 'testuser'@'%';
DROP USER IF EXISTS 'proxysql_monitor'@'%';

-- Recreate with mysql_native_password plugin
CREATE USER 'testuser'@'%' IDENTIFIED WITH mysql_native_password BY 'testpassword';
GRANT ALL PRIVILEGES ON testdb.* TO 'testuser'@'%';

CREATE USER 'proxysql_monitor'@'%' IDENTIFIED WITH mysql_native_password BY 'monitorpass123';
GRANT USAGE, REPLICATION CLIENT ON *.* TO 'proxysql_monitor'@'%';

FLUSH PRIVILEGES;

-- Add this to your existing init.sql
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED WITH mysql_native_password BY 'admin';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
