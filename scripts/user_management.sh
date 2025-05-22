#!/bin/bash
# MySQL Cluster User Management Script
# This script manages users across all MySQL nodes and ProxySQL instances
# Author: DevOpsAgent
# Date: 2025-05-22

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-"rootpassword"}
PROXYSQL_ADMIN_USER=${PROXYSQL_ADMIN_USER:-"radmin"}
PROXYSQL_ADMIN_PASSWORD=${PROXYSQL_ADMIN_PASSWORD:-"radmin"}
DEFAULT_HOSTGROUP=10  # Read hostgroup by default

# Function to display usage information
usage() {
    echo "Usage: $0 [options] <command>"
    echo
    echo "Commands:"
    echo "  create <username> <password> [permissions]   Create a new user"
    echo "  delete <username>                           Delete an existing user"
    echo "  list                                        List all users"
    echo
    echo "Options:"
    echo "  -h, --hostgroup <id>       Specify ProxySQL hostgroup (default: 10 - read-only)"
    echo "  -w, --write                Set user for write access (hostgroup 0)"
    echo "  -r, --read                 Set user for read-only access (hostgroup 10)"
    echo "  -a, --admin                Grant admin privileges (all permissions)"
    echo "  -d, --database <name>      Specify database for permissions (default: all)"
    echo "  -t, --table <name>         Specify table for permissions (default: all)"
    echo "  -p, --permissions <perms>  Specify custom permissions (e.g., 'SELECT,INSERT')"
    echo "  --help                     Display this help message"
    echo
    echo "Examples:"
    echo "  $0 create readonly_user password123"
    echo "  $0 -w create readwrite_user password123"
    echo "  $0 -a create admin_user password123"
    echo "  $0 -d test_db -p 'SELECT,INSERT' create custom_user password123"
    echo "  $0 delete user_to_delete"
    echo "  $0 list"
}

# Function to create a user on all MySQL nodes
create_mysql_user() {
    local username=$1
    local password=$2
    local permissions=$3
    local database=$4
    local table=$5
    
    echo -e "${BLUE}Creating MySQL user '$username' on all nodes...${NC}"
    
    # List of MySQL nodes
    mysql_nodes=("mysql1" "mysql2")
    
    for node in "${mysql_nodes[@]}"; do
        echo -e "${YELLOW}Creating user on $node...${NC}"
        
        # Construct the SQL command
        sql_command="CREATE USER '$username'@'%' IDENTIFIED WITH mysql_native_password BY '$password';"
        
        # Add permissions
        if [ -n "$permissions" ]; then
            # Construct the database.table part
            db_table=""
            if [ -n "$database" ]; then
                db_table="$database"
                if [ -n "$table" ]; then
                    db_table="$db_table.$table"
                else
                    db_table="$db_table.*"
                fi
            else
                db_table="*.*"
            fi
            
            sql_command="$sql_command GRANT $permissions ON $db_table TO '$username'@'%';"
        fi
        
        sql_command="$sql_command FLUSH PRIVILEGES;"
        
        # Execute the SQL command
        if docker exec -it "$node" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "$sql_command" &>/dev/null; then
            echo -e "${GREEN}✓ User created successfully on $node${NC}"
        else
            echo -e "${RED}✗ Failed to create user on $node${NC}"
            return 1
        fi
    done
    
    return 0
}

# Function to add a user to all ProxySQL instances
add_proxysql_user() {
    local username=$1
    local password=$2
    local hostgroup=$3
    
    echo -e "${BLUE}Adding user '$username' to all ProxySQL instances...${NC}"
    
    # List of ProxySQL nodes
    proxysql_nodes=("proxysql" "proxysql2")
    
    for node in "${proxysql_nodes[@]}"; do
        echo -e "${YELLOW}Adding user to $node...${NC}"
        
        # Construct the SQL command
        sql_command="INSERT INTO mysql_users(username, password, default_hostgroup, active) VALUES ('$username', '$password', $hostgroup, 1); LOAD MYSQL USERS TO RUNTIME; SAVE MYSQL USERS TO DISK;"
        
        # Execute the SQL command
        if docker exec -it "$node" mysql -h127.0.0.1 -P6032 -u"$PROXYSQL_ADMIN_USER" -p"$PROXYSQL_ADMIN_PASSWORD" -e "$sql_command" &>/dev/null; then
            echo -e "${GREEN}✓ User added successfully to $node${NC}"
        else
            echo -e "${RED}✗ Failed to add user to $node${NC}"
            return 1
        fi
    done
    
    return 0
}

# Function to delete a user from all MySQL nodes
delete_mysql_user() {
    local username=$1
    
    echo -e "${BLUE}Deleting MySQL user '$username' from all nodes...${NC}"
    
    # List of MySQL nodes
    mysql_nodes=("mysql1" "mysql2")
    
    for node in "${mysql_nodes[@]}"; do
        echo -e "${YELLOW}Deleting user from $node...${NC}"
        
        # Construct the SQL command
        sql_command="DROP USER IF EXISTS '$username'@'%'; FLUSH PRIVILEGES;"
        
        # Execute the SQL command
        if docker exec -it "$node" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "$sql_command" &>/dev/null; then
            echo -e "${GREEN}✓ User deleted successfully from $node${NC}"
        else
            echo -e "${RED}✗ Failed to delete user from $node${NC}"
            return 1
        fi
    done
    
    return 0
}

# Function to delete a user from all ProxySQL instances
delete_proxysql_user() {
    local username=$1
    
    echo -e "${BLUE}Deleting user '$username' from all ProxySQL instances...${NC}"
    
    # List of ProxySQL nodes
    proxysql_nodes=("proxysql" "proxysql2")
    
    for node in "${proxysql_nodes[@]}"; do
        echo -e "${YELLOW}Deleting user from $node...${NC}"
        
        # Construct the SQL command
        sql_command="DELETE FROM mysql_users WHERE username='$username'; LOAD MYSQL USERS TO RUNTIME; SAVE MYSQL USERS TO DISK;"
        
        # Execute the SQL command
        if docker exec -it "$node" mysql -h127.0.0.1 -P6032 -u"$PROXYSQL_ADMIN_USER" -p"$PROXYSQL_ADMIN_PASSWORD" -e "$sql_command" &>/dev/null; then
            echo -e "${GREEN}✓ User deleted successfully from $node${NC}"
        else
            echo -e "${RED}✗ Failed to delete user from $node${NC}"
            return 1
        fi
    done
    
    return 0
}

# Function to list all users
list_users() {
    echo -e "${BLUE}Listing MySQL users...${NC}"
    
    # Get users from MySQL
    echo -e "${YELLOW}Users in MySQL:${NC}"
    docker exec -it mysql1 mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT User, Host FROM mysql.user WHERE Host='%' ORDER BY User"
    
    echo
    
    # Get users from ProxySQL
    echo -e "${YELLOW}Users in ProxySQL:${NC}"
    docker exec -it proxysql mysql -h127.0.0.1 -P6032 -u"$PROXYSQL_ADMIN_USER" -p"$PROXYSQL_ADMIN_PASSWORD" -e "SELECT username, default_hostgroup, active FROM mysql_users ORDER BY username"
}

# Parse command line arguments
hostgroup=$DEFAULT_HOSTGROUP
database=""
table=""
permissions=""
command=""
username=""
password=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--hostgroup)
            hostgroup="$2"
            shift 2
            ;;
        -w|--write)
            hostgroup=0
            shift
            ;;
        -r|--read)
            hostgroup=10
            shift
            ;;
        -a|--admin)
            permissions="ALL PRIVILEGES"
            shift
            ;;
        -d|--database)
            database="$2"
            shift 2
            ;;
        -t|--table)
            table="$2"
            shift 2
            ;;
        -p|--permissions)
            permissions="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        create|delete|list)
            command="$1"
            shift
            
            if [ "$command" = "create" ]; then
                if [ $# -lt 2 ]; then
                    echo -e "${RED}Error: create command requires username and password${NC}"
                    usage
                    exit 1
                fi
                username="$1"
                password="$2"
                shift 2
                
                # If custom permissions not specified and we're in write hostgroup, set default write permissions
                if [ -z "$permissions" ] && [ "$hostgroup" -eq 0 ]; then
                    permissions="ALL PRIVILEGES"
                fi
                
                # If custom permissions not specified and we're in read hostgroup, set default read permissions
                if [ -z "$permissions" ] && [ "$hostgroup" -eq 10 ]; then
                    permissions="SELECT, SHOW DATABASES, SHOW VIEW, PROCESS"
                fi
            elif [ "$command" = "delete" ]; then
                if [ $# -lt 1 ]; then
                    echo -e "${RED}Error: delete command requires username${NC}"
                    usage
                    exit 1
                fi
                username="$1"
                shift
            fi
            ;;
        *)
            echo -e "${RED}Error: Unknown option or command: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Execute the appropriate command
if [ -z "$command" ]; then
    echo -e "${RED}Error: No command specified${NC}"
    usage
    exit 1
fi

case $command in
    create)
        create_mysql_user "$username" "$password" "$permissions" "$database" "$table" && \
        add_proxysql_user "$username" "$password" "$hostgroup" && \
        echo -e "${GREEN}User '$username' created successfully across all nodes${NC}" || \
        echo -e "${RED}Failed to create user '$username' on all nodes${NC}"
        ;;
    delete)
        delete_mysql_user "$username" && \
        delete_proxysql_user "$username" && \
        echo -e "${GREEN}User '$username' deleted successfully from all nodes${NC}" || \
        echo -e "${RED}Failed to delete user '$username' from all nodes${NC}"
        ;;
    list)
        list_users
        ;;
esac

exit 0
