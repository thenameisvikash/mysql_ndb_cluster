# Architecture Overview

[← Documentation Index](../index.md) | [High Throughput Architecture →](high-throughput.md)

*Related: [Node Groups and Split Brain](node-groups.md) | [Configuration Overview](../configuration/overview.md)*

This document provides a detailed overview of the MySQL Cluster architecture implemented in this project.

## Overview

The MySQL Cluster architecture is designed for high availability, fault tolerance, and scalability. It uses a shared-nothing architecture where each component can operate independently, and no single point of failure exists.

![MySQL Cluster Architecture](../images/mysql_cluster_architecture.svg)

## Components

### Management Nodes

Management nodes (ndb_mgmd) are responsible for:
- Cluster configuration management
- Node monitoring and failure detection
- Coordinating cluster operations
- Providing API for cluster management

**Implementation Details:**
- We deploy 2 management nodes for redundancy
- Primary: management1 (NodeId=1)
- Secondary: management2 (NodeId=8)
- Configuration stored in `config/management-config.ini`

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
- mysql1 (NodeId=4)
- mysql2 (NodeId=5)
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
- Configuration in `config/proxysql-config.cnf`

## Network Architecture

All components communicate over a dedicated Docker network:
- Network: `ndb-net`
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

If the primary management node fails:
1. The secondary management node takes over
2. All cluster nodes connect to the secondary management node
3. No interruption to database operations

### Data Node Failover

If a data node fails:
1. The other node in the same node group continues to serve data
2. No data loss occurs due to synchronous replication
3. When the failed node comes back online, it automatically synchronizes

### SQL Node Failover

If an SQL node fails:
1. ProxySQL detects the failure through health checks
2. Queries are routed to the remaining healthy SQL node
3. No interruption to database operations

### ProxySQL Failover

If the primary ProxySQL instance fails:
1. Applications can connect to the secondary ProxySQL instance
2. The secondary instance has the same configuration and routing rules
3. Minimal interruption to database operations

## Security Architecture

The architecture includes several security layers:
- Network isolation through Docker networking
- User authentication and authorization
- Encrypted connections (optional)
- Principle of least privilege for user permissions

## Performance Considerations

- Data nodes are memory-intensive (configure DataMemory and IndexMemory appropriately)
- SQL nodes benefit from connection pooling through ProxySQL
- Read/write splitting improves performance for read-heavy workloads
- Node groups provide horizontal scalability

## Related Documentation

- [High Throughput Architecture](high-throughput.md) - For high-throughput workloads
- [Optimized Architecture](optimized.md) - Performance-optimized configurations
- [Node Groups and Split Brain](node-groups.md) - Understanding node groups and split-brain prevention
- [Configuration Overview](../configuration/overview.md) - Configuration principles and best practices
