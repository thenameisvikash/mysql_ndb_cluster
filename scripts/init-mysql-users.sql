-- Drop users if they exist to avoid duplicates
DROP USER IF EXISTS 'proxysql_monitor'@'%';
DROP USER IF EXISTS 'testuser'@'%';
DROP USER IF EXISTS 'readonly'@'%';
DROP USER IF EXISTS 'readwrite'@'%';
DROP USER IF EXISTS 'admin'@'%';
DROP USER IF EXISTS 'root'@'%';

-- Create users with explicit mysql_native_password plugin
CREATE USER 'proxysql_monitor'@'%' IDENTIFIED WITH mysql_native_password BY 'monitorpass123';
CREATE USER 'testuser'@'%' IDENTIFIED WITH mysql_native_password BY 'testpassword';
CREATE USER 'readonly'@'%' IDENTIFIED WITH mysql_native_password BY 'readonlypass';
CREATE USER 'readwrite'@'%' IDENTIFIED WITH mysql_native_password BY 'readwritepass';
CREATE USER 'admin'@'%' IDENTIFIED WITH mysql_native_password BY 'adminpass';
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'rootpassword';

-- Grant privileges
GRANT USAGE, REPLICATION CLIENT, PROCESS, SELECT ON *.* TO 'proxysql_monitor'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'testuser'@'%' WITH GRANT OPTION;
GRANT SELECT, SHOW DATABASES, SHOW VIEW, PROCESS ON *.* TO 'readonly'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'readwrite'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

FLUSH PRIVILEGES;

-- Create test database and table
CREATE DATABASE IF NOT EXISTS test_db;
USE test_db;
DROP TABLE IF EXISTS test_table;
CREATE TABLE test_table (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=NDBCLUSTER;
INSERT INTO test_table (data) VALUES ('initial_test_data');

