# High-Throughput Architecture with Redis Sentinel and MySQL Cluster

[← Documentation Index](DOCUMENTATION.md) | [Architecture Overview](docs/architecture.md) | [Optimized Architecture →](Optimized_Architecture.md)

*Related: [Performance Tuning](docs/performance-tuning.md)*

This document outlines the architecture for a high-throughput system processing 1.5 Lac TPS (150,000 transactions per second) with Redis as a queue and MySQL Cluster for storing 60 Crore (600 million) daily records.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Details](#component-details)
3. [Data Flow](#data-flow)
4. [High Availability Design](#high-availability-design)
5. [Scaling Considerations](#scaling-considerations)
6. [Network Requirements](#network-requirements)
7. [Hardware Specifications](#hardware-specifications)
8. [Deployment Guidelines](#deployment-guidelines)

## Architecture Overview

The architecture consists of two main subsystems:

1. **Redis Queue Subsystem**: 3 servers with Redis and Sentinel for high-availability queue management
2. **MySQL Cluster Subsystem**: 7 servers forming a MySQL Cluster with 3 node groups for data storage

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             REDIS QUEUE SUBSYSTEM                            │
├─────────────────┬─────────────────┬─────────────────┬─────────────────┬─────┘
│                 │                 │                 │                 │
│  ┌─────────────┐│  ┌─────────────┐│  ┌─────────────┐│  ┌─────────────┐│
│  │ Redis Server││  │ Redis Server││  │ Redis Server││  │ Load        ││
│  │    #1       ││  │    #2       ││  │    #3       ││  │ Balancer    ││
│  │             ││  │             ││  │             ││  │             ││
│  │ ┌─────────┐ ││  │ ┌─────────┐ ││  │ ┌─────────┐ ││  │             ││
│  │ │ Redis   │ ││  │ │ Redis   │ ││  │ │ Redis   │ ││  │             ││
│  │ │ Master  │◄┼┼──┼─┤ Replica │ ││  │ │ Replica │ ││  │             ││
│  │ └─────────┘ ││  │ └─────────┘ ││  │ └─────────┘ ││  │             ││
│  │             ││  │             ││  │             ││  │             ││
│  │ ┌─────────┐ ││  │ ┌─────────┐ ││  │ ┌─────────┐ ││  │             ││
│  │ │Sentinel │ ││  │ │Sentinel │ ││  │ │Sentinel │ ││  │             ││
│  │ │  #1     │◄┼┼──┼─┤  #2     │◄┼┼──┼─┤  #3     │ ││  │             ││
│  │ └─────────┘ ││  │ └─────────┘ ││  │ └─────────┘ ││  │             ││
│  │             ││  │             ││  │             ││  │             ││
│  │ ┌─────────┐ ││  │ ┌─────────┐ ││  │ ┌─────────┐ ││  │             ││
│  │ │Consumer │ ││  │ │Consumer │ ││  │ │Consumer │ ││  │             ││
│  │ │Services │ ││  │ │Services │ ││  │ │Services │ ││  │             ││
│  │ └─────────┘ ││  │ └─────────┘ ││  │ └─────────┘ ││  │             ││
│  └─────────────┘│  └─────────────┘│  └─────────────┘│  └─────────────┘│
│                 │                 │                 │                 │
├─────────────────┴─────────────────┴─────────────────┴─────────────────┴─────┐
│                                                                              │
│                            MYSQL CLUSTER SUBSYSTEM                           │
├──────────────────────────────────────────────────────────────────────────────┘
│
│  ┌─────────────┐   ┌─────────────┐
│  │ Management  │   │ Management  │
│  │  Node #1    │◄──┤  Node #2    │
│  └─────────────┘   └─────────────┘
│         │                │
│         └────────┬───────┘
│                  │
│  ┌───────────────┼───────────────┐
│  │               │               │
│  ▼               ▼               ▼
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│  │  Node Group │ │  Node Group │ │  Node Group │
│  │     #1      │ │     #2      │ │     #3      │
│  │             │ │             │ │             │
│  │ ┌─────────┐ │ │ ┌─────────┐ │ │ ┌─────────┐ │
│  │ │Data Node│ │ │ │Data Node│ │ │ │Data Node│ │
│  │ │   #1    │ │ │ │   #3    │ │ │ │   #5    │ │
│  │ └─────────┘ │ │ └─────────┘ │ │ └─────────┘ │
│  │             │ │             │ │             │
│  │ ┌─────────┐ │ │ ┌─────────┐ │ │ ┌─────────┐ │
│  │ │Data Node│ │ │ │Data Node│ │ │ │Data Node│ │
│  │ │   #2    │ │ │ │   #4    │ │ │ │   #6    │ │
│  │ └─────────┘ │ │ └─────────┘ │ │ └─────────┘ │
│  └─────────────┘ └─────────────┘ └─────────────┘
│         │               │               │
│         └───────┬───────┴───────┬───────┘
│                 │               │
│                 ▼               ▼
│         ┌─────────────┐ ┌─────────────┐
│         │  SQL Node   │ │  SQL Node   │
│         │     #1      │ │     #2      │
│         └─────────────┘ └─────────────┘
│                │               │
│                └───────┬───────┘
│                        │
│                        ▼
│                ┌─────────────┐
│                │ Application │
│                │   Servers   │
│                └─────────────┘
```

## Component Details

### Redis Queue Subsystem

**Server 1:**
- Redis Master instance
- Redis Sentinel #1
- Consumer Services Group #1

**Server 2:**
- Redis Replica #1
- Redis Sentinel #2
- Consumer Services Group #2

**Server 3:**
- Redis Replica #2
- Redis Sentinel #3
- Consumer Services Group #3

**Load Balancer:**
- Distributes producer connections across Redis instances
- Health monitoring for Redis instances

### MySQL Cluster Subsystem

**Management Servers (2):**
- Management Node #1
- Management Node #2

**Node Group 1 (2 servers):**
- Data Node #1
- Data Node #2

**Node Group 2 (2 servers):**
- Data Node #3
- Data Node #4

**Node Group 3 (2 servers):**
- Data Node #5
- Data Node #6

**SQL Nodes (1 server):**
- SQL Node #1
- SQL Node #2 (on same physical server)

## Data Flow

1. **Producer Applications → Redis Master**
   - Applications push data to Redis queue at 1.5 Lac TPS
   - Data is automatically replicated to Redis replicas

2. **Redis → Consumer Services**
   - Consumer services on each Redis server process queue items
   - Each consumer group handles a portion of the workload

3. **Consumer Services → MySQL Cluster**
   - Consumers process data and insert into MySQL Cluster
   - Batch inserts are used for efficiency (1000-5000 records per batch)

4. **MySQL Cluster Internal Flow**
   - SQL Nodes receive insert requests
   - Data is automatically partitioned across node groups
   - Each partition is replicated within its node group

## High Availability Design

### Redis High Availability

1. **Redis Sentinel**
   - Monitors Redis instances
   - Performs automatic failover if master fails
   - Requires 2/3 sentinels to agree on failover

2. **Redis Replication**
   - Master → Replica asynchronous replication
   - Replicas can be promoted to master by Sentinel

### MySQL Cluster High Availability

1. **Node Group Redundancy**
   - Each node group contains 2 data nodes
   - Data is automatically replicated within node groups
   - Cluster remains operational as long as one node in each group is available

2. **Management Node Redundancy**
   - Two management nodes for configuration and arbitration
   - Prevents split-brain scenarios

3. **SQL Node Redundancy**
   - Multiple SQL nodes for query processing
   - Application can connect to any available SQL node

## Scaling Considerations

### Vertical Scaling

1. **Redis Servers**
   - Increase memory for larger queue capacity
   - Add CPU cores for faster queue processing

2. **MySQL Data Nodes**
   - Increase memory (DataMemory and IndexMemory)
   - Add CPU cores (increase MaxNoOfExecutionThreads)

### Horizontal Scaling

1. **Redis Scaling**
   - Add more Redis consumer instances
   - Implement Redis Cluster for sharding (future enhancement)

2. **MySQL Cluster Scaling**
   - Add more node groups (in pairs)
   - Add more SQL nodes for higher query throughput

## Network Requirements

### Network Topology

1. **Public Network**
   - Application → Redis Load Balancer
   - Application → MySQL SQL Nodes

2. **Private Network**
   - Redis Master ↔ Redis Replicas
   - Redis Sentinel interconnect
   - MySQL Cluster interconnect (critical)

### Bandwidth Requirements

1. **Redis Subsystem**
   - Redis Replication: 1-2 Gbps
   - Client Connections: 5-10 Gbps

2. **MySQL Cluster Subsystem**
   - Inter-node communication: 10-25 Gbps
   - Data node interconnect: 25-100 Gbps (critical)
   - SQL node connections: 10 Gbps

### Latency Requirements

1. **Redis Subsystem**
   - Redis Replication: <5ms
   - Sentinel Communication: <10ms

2. **MySQL Cluster Subsystem**
   - Data Node Interconnect: <1ms (critical)
   - Management Node Communication: <5ms
   - SQL Node Communication: <5ms

## Hardware Specifications

### Redis Servers (3)

| Component | Specification | Notes |
|-----------|---------------|-------|
| CPU | 16-32 cores | For consumer services |
| RAM | 64-128 GB | For Redis and consumers |
| Storage | 500GB-1TB SSD | For Redis persistence |
| Network | 10-25 Gbps | Redundant NICs |

### MySQL Management Nodes (2)

| Component | Specification | Notes |
|-----------|---------------|-------|
| CPU | 8 cores | For cluster management |
| RAM | 16 GB | For configuration |
| Storage | 100GB SSD | For logs and config |
| Network | 10 Gbps | Redundant NICs |

### MySQL Data Nodes (6)

| Component | Specification | Notes |
|-----------|---------------|-------|
| CPU | 32-64 cores | For data processing |
| RAM | 128-256 GB | For in-memory data storage |
| Storage | 1-2TB NVMe SSD | For logs and disk operations |
| Network | 25-100 Gbps | Redundant NICs, low latency |

### MySQL SQL Nodes (1)

| Component | Specification | Notes |
|-----------|---------------|-------|
| CPU | 32-64 cores | For query processing |
| RAM | 64-128 GB | For query execution |
| Storage | 1TB SSD | For binary logs |
| Network | 10-25 Gbps | Redundant NICs |

## Deployment Guidelines

### Redis Subsystem Deployment

1. **Redis Configuration**
   ```conf
   # Master/Replica configuration
   port 6379
   maxmemory 48gb
   maxmemory-policy allkeys-lru
   appendonly yes
   appendfsync everysec
   
   # Replication (on replicas)
   replicaof redis-master 6379
   ```

2. **Sentinel Configuration**
   ```conf
   port 26379
   sentinel monitor mymaster redis-master 6379 2
   sentinel down-after-milliseconds mymaster 5000
   sentinel failover-timeout mymaster 60000
   ```

3. **Consumer Services**
   - Deploy as containers or systemd services
   - Configure for batch processing
   - Implement circuit breakers for MySQL connection issues

### MySQL Cluster Deployment

1. **Management Node Configuration**
   ```ini
   [ndbd default]
   NoOfReplicas=2
   DataMemory=64G
   IndexMemory=16G
   RedoBuffer=1G
   
   # Node Group 1
   [ndbd]
   NodeId=2
   Hostname=datanode1
   NodeGroup=0
   
   [ndbd]
   NodeId=3
   Hostname=datanode2
   NodeGroup=0
   
   # Node Group 2
   [ndbd]
   NodeId=4
   Hostname=datanode3
   NodeGroup=1
   
   [ndbd]
   NodeId=5
   Hostname=datanode4
   NodeGroup=1
   
   # Node Group 3
   [ndbd]
   NodeId=6
   Hostname=datanode5
   NodeGroup=2
   
   [ndbd]
   NodeId=7
   Hostname=datanode6
   NodeGroup=2
   ```

2. **Data Node Configuration**
   ```ini
   [mysqld]
   ndbcluster
   ndb-connectstring=mgmd1,mgmd2
   ```

3. **SQL Node Configuration**
   ```ini
   [mysqld]
   ndbcluster
   ndb-connectstring=mgmd1,mgmd2
   max_connections=5000
   thread_cache_size=256
   ```

### Network Configuration

1. **Firewall Rules**
   - Redis: 6379, 26379
   - MySQL Management: 1186
   - MySQL Data Nodes: 2202
   - MySQL SQL Nodes: 3306

2. **Network Optimization**
   ```bash
   # /etc/sysctl.conf
   net.core.rmem_max = 16777216
   net.core.wmem_max = 16777216
   net.ipv4.tcp_rmem = 4096 87380 16777216
   net.ipv4.tcp_wmem = 4096 65536 16777216
   ```

## Component Roles and Resource Utilization

### Redis Subsystem Components

1. **Redis Master**
   - **Role**: Handles all write operations and replicates to replicas
   - **Resource Utilization**:
     - **CPU**: Medium (30-40% utilization) - Primarily single-threaded
     - **Memory**: Very High (80-90% utilization) - Stores all queue data
     - **Network**: Very High (inbound from producers, outbound to replicas)
     - **Disk I/O**: Low to Medium (only for persistence)

2. **Redis Replicas**
   - **Role**: Provide read scalability and failover capability
   - **Resource Utilization**:
     - **CPU**: Low to Medium (20-30% utilization)
     - **Memory**: Very High (80-90% utilization) - Mirrors master data
     - **Network**: High (inbound replication traffic)
     - **Disk I/O**: Low to Medium (only for persistence)

3. **Redis Sentinel**
   - **Role**: Monitors Redis instances and performs automatic failover
   - **Resource Utilization**:
     - **CPU**: Very Low (5-10% utilization)
     - **Memory**: Very Low (minimal footprint)
     - **Network**: Low (heartbeat and monitoring traffic)
     - **Disk I/O**: Negligible

4. **Consumer Services**
   - **Role**: Process data from Redis queue and insert into MySQL Cluster
   - **Resource Utilization**:
     - **CPU**: Very High (70-90% utilization) - Main processing bottleneck
     - **Memory**: Medium to High (50-70% utilization)
     - **Network**: High (outbound to MySQL Cluster)
     - **Disk I/O**: Low (logging only)

### MySQL Cluster Components

1. **Management Nodes**
   - **Role**: Store cluster configuration, monitor node status, arbitrate in split-brain scenarios
   - **Resource Utilization**:
     - **CPU**: Very Low (5-10% utilization) except during configuration changes
     - **Memory**: Low (10-20% utilization)
     - **Network**: Low (control traffic only)
     - **Disk I/O**: Very Low (configuration and logs)

2. **Data Nodes**
   - **Role**: Store and process data, handle replication within node groups
   - **Resource Utilization**:
     - **CPU**: High (60-80% utilization) - Multi-threaded processing
     - **Memory**: Extremely High (90%+ utilization) - Primary bottleneck
     - **Network**: Very High (inter-node communication)
     - **Disk I/O**: Medium (redo logs and checkpoints)

3. **SQL Nodes**
   - **Role**: Process SQL queries, translate between SQL and NDB API
   - **Resource Utilization**:
     - **CPU**: High (60-80% utilization) during query processing
     - **Memory**: Medium to High (40-60% utilization)
     - **Network**: High (communication with data nodes and clients)
     - **Disk I/O**: Medium (binary logs)

4. **ProxySQL**
   - **Role**: Load balance connections to SQL nodes, connection pooling
   - **Resource Utilization**:
     - **CPU**: Medium (30-50% utilization)
     - **Memory**: Medium (30-50% utilization)
     - **Network**: High (all client traffic)
     - **Disk I/O**: Very Low (configuration and logs)

## Optimized Server Distribution

To achieve high availability while minimizing the number of servers, the following optimized distribution strategy can be implemented:

### Minimum Configuration (10 Servers)

| Server | Components | Resource Considerations |
|--------|------------|-------------------------|
| **Server 1** | Redis Master + Sentinel #1 + Consumer Services #1 | High memory for Redis, high CPU for consumers |
| **Server 2** | Redis Replica #1 + Sentinel #2 + Consumer Services #2 | Balance between memory and CPU |
| **Server 3** | Redis Replica #2 + Sentinel #3 + Consumer Services #3 | Balance between memory and CPU |
| **Server 4** | Management Node #1 + SQL Node #1 | Low resource utilization, good combination |
| **Server 5** | Management Node #2 + SQL Node #2 + ProxySQL | Low resource utilization, good combination |
| **Server 6** | Data Node #1 (Node Group 1) | High memory, dedicated server recommended |
| **Server 7** | Data Node #2 (Node Group 1) | High memory, dedicated server recommended |
| **Server 8** | Data Node #3 (Node Group 2) | High memory, dedicated server recommended |
| **Server 9** | Data Node #4 (Node Group 2) | High memory, dedicated server recommended |
| **Server 10** | Data Node #5 + Data Node #6 (Node Group 3) | Very high memory, can be split if needed |

### Further Optimization (8 Servers)

If budget constraints require further optimization, the following configuration can be used with some trade-offs:

| Server | Components | Trade-offs |
|--------|------------|-----------|
| **Server 1** | Redis Master + Sentinel #1 + Consumer Services #1 | No change |
| **Server 2** | Redis Replica #1 + Sentinel #2 + Consumer Services #2 | No change |
| **Server 3** | Redis Replica #2 + Sentinel #3 + Consumer Services #3 | No change |
| **Server 4** | Management Node #1 + Management Node #2 + SQL Node #1 + ProxySQL | Risk of management node failure correlation |
| **Server 5** | Data Node #1 (Node Group 1) + SQL Node #2 | SQL performance impact during high data node load |
| **Server 6** | Data Node #2 (Node Group 1) + Data Node #3 (Node Group 2) | Reduced redundancy if server fails |
| **Server 7** | Data Node #4 (Node Group 2) + Data Node #5 (Node Group 3) | Reduced redundancy if server fails |
| **Server 8** | Data Node #6 (Node Group 3) | No change |

### Critical Considerations for Colocation

When collocating components on the same server:

1. **Never place both nodes from the same node group on the same server**
   - This would eliminate redundancy within the node group

2. **Management nodes should ideally be on separate physical servers**
   - Prevents split-brain scenarios due to single server failure

3. **Data nodes are memory-intensive and should have dedicated resources**
   - Memory contention will severely impact performance

4. **SQL nodes can be collocated with management nodes**
   - They have complementary resource profiles

5. **ProxySQL can be collocated with SQL or management nodes**
   - Relatively low resource requirements

## Conclusion

This architecture provides a robust solution for handling 1.5 Lac TPS with Redis as a queue and storing 60 Crore daily records in MySQL Cluster. The design ensures:

1. **High Availability**: Through Redis Sentinel and MySQL Cluster's node group redundancy
2. **Scalability**: By allowing both vertical and horizontal scaling
3. **Performance**: Through optimized hardware and network configuration
4. **Data Integrity**: With proper replication and failover mechanisms
5. **Resource Efficiency**: By strategically collocating compatible components

The separation of Redis and MySQL Cluster subsystems allows for independent scaling and maintenance while maintaining the required throughput and reliability for the application. The optimized server distribution strategies provide options to balance between maximum availability and cost efficiency.
