# MySQL Cluster Architecture

[← Documentation Index](../DOCUMENTATION.md) | [Installation Guide →](installation.md)

*Related: [High Throughput Architecture](../High_Throughput_Architecture.md) | [Node Groups and Split Brain](../Node_Groups_and_Split_Brain.md)*

This document provides a detailed overview of the MySQL Cluster architecture implemented in this project.

## Overview

The MySQL Cluster architecture is designed for high availability, fault tolerance, and scalability. It uses a shared-nothing architecture where each component can operate independently, and no single point of failure exists.

## Components

### Management Nodes

Management nodes (ndb_mgmd) are responsible for:
- Cluster configuration management
- Node monitoring and failure detection
- Coordinating cluster operations
- Providing API for cluster management

**Implementation Details:**
- We deploy 2 management nodes for redundancy
- Primary: management1 (NodeId=1) at 172.20.0.2
- Secondary: management2 (NodeId=8) at 172.20.0.11
- Configuration stored in `config/management1-config/management-config.ini` and `config/management2-config/management-config.ini`

### Data Nodes

Data nodes (ndbd) store and manage the actual data:
- In-memory data storage with disk persistence
- Automatic data partitioning (sharding)
- Synchronous replication between node groups
- Automatic recovery after failures

**Implementation Details:**
- 4 data nodes organized in 2 node groups
- Node Group 0: ndb1 (NodeId=2) and ndb2 (NodeId=3)
- Node Group 1: ndb3 (NodeId=6) and ndb4 (NodeId=7)
- Each with 512MB data memory and 128MB index memory
- 2 replicas for redundancy

### SQL Nodes

SQL nodes (mysqld) provide the SQL interface to the cluster:
- Process SQL queries
- Communicate with data nodes to retrieve and store data
- Handle transactions and ACID compliance
- Support standard MySQL client connections

**Implementation Details:**
- 2 SQL nodes for redundancy and load balancing
- mysql1 (NodeId=4) at 172.20.0.5
- mysql2 (NodeId=5) at 172.20.0.6
- Both configured with ndbcluster storage engine
- Configuration in `config/mysql1/my.cnf` and `config/mysql2/my.cnf`

### ProxySQL

ProxySQL provides load balancing and query routing:
- Connection pooling for efficient resource utilization
- Query routing based on query type (read/write splitting)
- Health monitoring of backend MySQL nodes
- Automatic failover to healthy nodes

**Implementation Details:**
- 2 ProxySQL instances for high availability
- proxysql (primary) listening on ports 6033 (MySQL) and 6032 (Admin)
- proxysql2 (secondary) listening on ports 6034 (MySQL) and 6035 (Admin)
- Configuration in `config/proxysql1-config/proxysql-fixed-complete.cnf` and `config/proxysql2-config/proxysql-fixed-complete.cnf`

## Network Architecture

All components communicate over a dedicated Docker network:
- Network: `ndb-net` (172.20.0.0/16)
- Fixed IP addresses for all components
- Internal DNS resolution using container names

## Data Flow

1. **Client Connection**:
   - Applications connect to ProxySQL (port 6033)
   - ProxySQL authenticates the connection using MySQL credentials

2. **Query Routing**:
   - ProxySQL analyzes the query type
   - SELECT queries → Hostgroup 10 (read)
   - INSERT/UPDATE/DELETE queries → Hostgroup 0 (write)

3. **SQL Processing**:
   - SQL node receives the query from ProxySQL
   - Parses and optimizes the query
   - Communicates with data nodes to retrieve or modify data

4. **Data Storage**:
   - Data nodes store the actual data in memory
   - Data is automatically partitioned across node groups
   - Each partition is replicated to ensure redundancy

## Failover Mechanisms

### Management Node Failover
- If the primary management node fails, the secondary takes over
- No interruption to cluster operations

### Data Node Failover
- If a data node fails, its partner in the same node group takes over
- Automatic recovery when the failed node rejoins
- No data loss due to synchronous replication

### SQL Node Failover
- If an SQL node fails, ProxySQL routes traffic to the remaining node
- Automatic recovery when the failed node rejoins

### ProxySQL Failover
- If the primary ProxySQL fails, applications can connect to the secondary
- Identical configuration ensures consistent behavior

## Scaling Considerations

### Vertical Scaling
- Increase memory allocation for data nodes
- Increase CPU allocation for SQL nodes
- Adjust ProxySQL connection pool settings

### Horizontal Scaling
- Add more data node groups for increased storage capacity
- Add more SQL nodes for increased query processing capacity
- Add more ProxySQL instances for increased connection capacity

## Monitoring and Management

- ProxySQL provides built-in monitoring through its admin interface
- MySQL Cluster provides monitoring through ndb_mgm
- Custom scripts for health checking and testing

## Security Considerations

- Network isolation through Docker networking
- User authentication and authorization
- Encrypted connections (optional)
- Principle of least privilege for user permissions
