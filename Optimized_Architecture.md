# Optimized High-Throughput Architecture with Redis Sentinel and MySQL Cluster

This document presents an optimized architecture for a high-throughput system processing 1.5 Lac TPS (150,000 transactions per second) with Redis as a queue and MySQL Cluster for storing 60 Crore (600 million) daily records.

## Data Flow Overview

```
Producer Applications → Redis Queue → Consumer Services → MySQL Cluster → Analytics/Reporting
```

1. **Producer Applications** generate data at 1.5 Lac TPS (150,000 transactions per second)
2. **Redis Queue** stores this data temporarily in memory (HIGH MEMORY USAGE)
3. **Consumer Services** process data from Redis and prepare it for storage (HIGH CPU USAGE)
4. **MySQL Cluster** stores the processed data (60 Crore/600M records daily) (HIGH MEMORY & I/O USAGE)
5. **Analytics/Reporting** applications query the data as needed (via SQL Nodes)

## Optimized Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       PRODUCER APPLICATIONS                                  │
├──────────────────────────────────────────────────────────────────────────────┘
│                              │                                               
│                              │                                   
│                              ▼                                               
│                    ┌─────────────────┐                                       
│                    │  Sentinel-aware │                                       
│                    │  Redis Clients  │                                             
│                    └─────────────────┘                                       
│                              │                                               
│                              │                                               
│                              ▼                                               
├─────────────────────────────────────────────────────────────────────────────┐
│                             REDIS QUEUE SUBSYSTEM                            │
├─────────────────┬─────────────────┬─────────────────┬─────────────────┬─────┘
│                 │                 │                 │                 │
│  ┌─────────────┐│  ┌─────────────┐│  ┌─────────────┐│                 │
│  │ Redis Server││  │ Redis Server││  │ Redis Server││                 │
│  │    #1       ││  │    #2       ││  │    #3       ││                 │
│  │             ││  │             ││  │             ││                 │
│  │ ┌─────────┐ ││  │ ┌─────────┐ ││  │ ┌─────────┐ ││                 │
│  │ │ Redis   │ ││  │ │ Redis   │ ││  │ │ Redis   │ ││                 │
│  │ │ Master  │◄┼┼──┼─┤ Replica │◄┼┼──┼─┤ Replica │ ││                 │
│  │ └─────────┘ ││  │ └─────────┘ ││  │ └─────────┘ ││                 │
│  │             ││  │             ││  │             ││                 │
│  │ ┌─────────┐ ││  │ ┌─────────┐ ││  │ ┌─────────┐ ││                 │
│  │ │Sentinel │ ││  │ │Sentinel │ ││  │ │Sentinel │ ││                 │
│  │ │  #1     │◄┼┼──┼─┤  #2     │◄┼┼──┼─┤  #3     │ ││                 │
│  │ └─────────┘ ││  │ └─────────┘ ││  │ └─────────┘ ││                 │
│  │             ││  │             ││  │             ││                 │
│  │ ┌─────────┐ ││  │ ┌─────────┐ ││  │ ┌─────────┐ ││                 │
│  │ │Consumer │ ││  │ │Consumer │ ││  │ │Consumer │ ││                 │
│  │ │Services │ ││  │ │Services │ ││  │ │Services │ ││ ◄── HIGH CPU USAGE
│  │ └─────────┘ ││  │ └─────────┘ ││  │ └─────────┘ ││                 │
│  └─────────────┘│  └─────────────┘│  └─────────────┘│                 │
│                 │                 │                 │                 │
│                              │                                               
│                              │ Batch Inserts                                 
│                              ▼                                               
├──────────────────────────────────────────────────────────────────────────────┘
│                                                                              │
│                            MYSQL CLUSTER SUBSYSTEM                           │
├──────────────────────────────────────────────────────────────────────────────┘
│
│  ┌───────────────────────┐   ┌───────────────────────┐
│  │      Server #1        │   │      Server #2        │
│  │                       │   │                       │
│  │  ┌─────────────────┐  │   │  ┌─────────────────┐  │
│  │  │  Management     │  │   │  │  Management     │  │
│  │  │   Node #1       │◄─┼───┼─►│   Node #2       │  │ ◄── LOW RESOURCE USAGE
│  │  └─────────────────┘  │   │  └─────────────────┘  │
│  │                       │   │                       │
│  │  ┌─────────────────┐  │   │  ┌─────────────────┐  │
│  │  │    SQL Node     │  │   │  │    SQL Node     │  │ ◄── HIGH CPU USAGE
│  │  │      #1         │  │   │  │      #2         │  │
│  │  └─────────────────┘  │   │  └─────────────────┘  │
│  │                       │   │                       │
│  │  ┌─────────────────┐  │   │  ┌─────────────────┐  │
│  │  │    ProxySQL     │◄─┼───┼─►│    ProxySQL     │  │ ◄── HIGH NETWORK TRAFFIC
│  │  │      #1         │  │   │  │      #2         │  │
│  │  └─────────────────┘  │   │  └─────────────────┘  │
│  │                       │   │                       │
│  │  ┌─────────────────┐  │   │  ┌─────────────────┐  │
│  │  │   Prometheus    │  │   │  │    Grafana      │  │ ◄── MONITORING
│  │  │                 │  │   │  │                 │  │
│  │  └─────────────────┘  │   │  └─────────────────┘  │
│  └───────────────────────┘   └───────────────────────┘
│              │                          │
│              └──────────────┬───────────┘
│                             │
│                             ▼
│  ┌───────────────────────────────────────────────────────────┐
│  │                   Physical Servers with Data Nodes          │
│  │                                                            │
│  │  ┌────────────────────────┐  ┌────────────────────────┐  ┌────────────────────────┐
│  │  │      Server #6         │  │      Server #7         │  │      Server #8         │
│  │  │                        │  │                        │  │                        │
│  │  │  ┌──────────────────┐  │  │  ┌──────────────────┐  │  │  ┌──────────────────┐  │
│  │  │  │Data Node #1      │  │  │  │Data Node #2      │  │  │  │Data Node #4      │  │
│  │  │  │(Node Group 1)    │  │  │  │(Node Group 1)    │  │  │  │(Node Group 2)    │  │
│  │  │  │                  │  │  │  │                  │  │  │  │                  │  │
│  │  │  │HIGH MEMORY USAGE │  │  │  │HIGH MEMORY USAGE │  │  │  │HIGH MEMORY USAGE │  │
│  │  │  └──────────────────┘  │  │  └──────────────────┘  │  │  └──────────────────┘  │
│  │  │                        │  │                        │  │                        │
│  │  │  ┌──────────────────┐  │  │  ┌──────────────────┐  │  │  ┌──────────────────┐  │
│  │  │  │Data Node #3      │  │  │  │Data Node #5      │  │  │  │Data Node #6      │  │
│  │  │  │(Node Group 2)    │  │  │  │(Node Group 3)    │  │  │  │(Node Group 3)    │  │
│  │  │  │                  │  │  │  │                  │  │  │  │                  │  │
│  │  │  │HIGH MEMORY USAGE │  │  │  │HIGH MEMORY USAGE │  │  │  │HIGH MEMORY USAGE │  │
│  │  │  └──────────────────┘  │  │  └──────────────────┘  │  │  └──────────────────┘  │
│  │  │                        │  │                        │  │                        │
│  │  │  HIGH NETWORK TRAFFIC  │  │  HIGH NETWORK TRAFFIC  │  │  HIGH NETWORK TRAFFIC  │
│  │  └────────────────────────┘  └────────────────────────┘  └────────────────────────┘
│  └───────────────────────────────────────────────────────────┘
```

## Key Architecture Changes

### 1. Redis Client Connection Pattern

In the optimized architecture, we've **removed the load balancer** for Redis connections. Instead, we're using the **Sentinel-aware client pattern**:

1. **Direct Sentinel Integration**: Redis clients connect directly to Sentinel nodes to discover the current master
2. **Automatic Failover Handling**: When a master fails, clients query Sentinel for the new master address
3. **Connection Process**:
   - Client connects to any Sentinel node
   - Client asks for master address using `SENTINEL get-master-addr-by-name`
   - Client connects directly to the master
   - If connection fails, process repeats

This approach eliminates the need for a separate load balancer while providing automatic failover capabilities.

### 2. MySQL Cluster Component Colocation

We've colocated compatible components to reduce the number of servers required:

1. **Management Node + SQL Node + ProxySQL**:
   - Management nodes have low resource utilization
   - SQL nodes have complementary resource profiles
   - ProxySQL has moderate resource requirements
   - Each server hosts one of each component for redundancy

2. **Data Nodes**:
   - Remain on dedicated servers due to high memory requirements
   - Organized in three node groups with two nodes each
   - Each node group contains a complete copy of all data

## Optimized Server Distribution

### Minimum Configuration (8 Servers)

| Server | Components | Resource Considerations |
|--------|------------|-------------------------|
| **Server 1** | Redis Master + Sentinel #1 + Consumer Services #1 | HIGH MEMORY: Redis (80-90%)<br>HIGH CPU: Consumer services (70-90%) |
| **Server 2** | Redis Replica #1 + Sentinel #2 + Consumer Services #2 | HIGH MEMORY: Redis (80-90%)<br>HIGH CPU: Consumer services (70-90%) |
| **Server 3** | Redis Replica #2 + Sentinel #3 + Consumer Services #3 | HIGH MEMORY: Redis (80-90%)<br>HIGH CPU: Consumer services (70-90%) |
| **Server 4** | Management Node #1 + SQL Node #1 + ProxySQL #1 + Prometheus | LOW MEMORY: Management node (10-20%)<br>HIGH CPU: SQL node (60-80%) |
| **Server 5** | Management Node #2 + SQL Node #2 + ProxySQL #2 + Grafana | LOW MEMORY: Management node (10-20%)<br>HIGH CPU: SQL node (60-80%) |
| **Server 6** | Data Node #1 (Group 1) + Data Node #3 (Group 2) | EXTREME MEMORY: Data nodes (90%+)<br>HIGH NETWORK: Inter-node traffic |
| **Server 7** | Data Node #2 (Group 1) + Data Node #5 (Group 3) | EXTREME MEMORY: Data nodes (90%+)<br>HIGH NETWORK: Inter-node traffic |
| **Server 8** | Data Node #4 (Group 2) + Data Node #6 (Group 3) | EXTREME MEMORY: Data nodes (90%+)<br>HIGH NETWORK: Inter-node traffic |

### Critical Considerations for This Layout

1. **Data Node Pairing**:
   - Data nodes from the same node group are NEVER on the same server
   - If Server 6 fails, Node Group 1 and 2 each still have one functioning node
   - Complete data availability is maintained even with a server failure
   - Node group assignment is EXPLICITLY configured in the MySQL Cluster configuration

2. **Management Node Separation**:
   - Management nodes are on separate servers to prevent split-brain scenarios
   - If one server fails, the other management node continues to function
   - Management nodes serve as arbitrators in split-brain scenarios

3. **SQL Node and ProxySQL Redundancy**:
   - SQL nodes are distributed across two servers
   - ProxySQL instances provide connection load balancing and failover

4. **Monitoring Integration**:
   - Prometheus collects metrics from all components
   - Grafana provides visualization dashboards
   - Monitoring components are placed on management/SQL servers due to complementary resource profiles

## Component Roles and Responsibilities

### Redis Subsystem

1. **Redis Master**: 
   - Primary write target for all producer applications
   - Handles all write operations at 1.5 Lac TPS
   - Resource profile: HIGH MEMORY, MEDIUM CPU, HIGH NETWORK

2. **Redis Replicas**: 
   - Provide redundancy and read scaling
   - Asynchronously replicate data from master
   - Resource profile: HIGH MEMORY, LOW-MEDIUM CPU, MEDIUM NETWORK

3. **Redis Sentinel**: 
   - Monitors Redis instances and manages automatic failover
   - Provides service discovery for clients
   - Resource profile: VERY LOW MEMORY, VERY LOW CPU, LOW NETWORK

4. **Consumer Services**: 
   - Process data from Redis queue and write to MySQL Cluster
   - Perform data transformation and batch operations
   - Resource profile: MEDIUM MEMORY, VERY HIGH CPU, MEDIUM-HIGH NETWORK

### MySQL Cluster Subsystem

1. **Management Nodes**: 
   - Store cluster configuration
   - Monitor node status
   - Arbitrate in split-brain scenarios
   - Coordinate cluster operations
   - Resource profile: LOW MEMORY, LOW CPU, LOW NETWORK

2. **SQL Nodes**:
   - Process SQL queries
   - Translate between SQL and NDB API
   - Handle client connections
   - Resource profile: MEDIUM-HIGH MEMORY, HIGH CPU, HIGH NETWORK

3. **ProxySQL**:
   - Load balance connections to SQL nodes
   - Provide connection pooling
   - Handle SQL node failover
   - Resource profile: MEDIUM MEMORY, MEDIUM CPU, HIGH NETWORK

4. **Data Nodes**:
   - Store and process data
   - Automatically partition data across node groups
   - Replicate data within node groups
   - Handle transaction processing
   - Resource profile: EXTREME MEMORY, HIGH CPU, VERY HIGH NETWORK

5. **Monitoring Components**:
   - **Prometheus**: Collect metrics from all components
   - **Grafana**: Visualize metrics and set up alerts
   - Resource profile: LOW-MEDIUM MEMORY, LOW-MEDIUM CPU, LOW NETWORK

## Node Group Configuration

To ensure proper distribution of data nodes across servers, we explicitly configure node groups in the MySQL Cluster configuration file:

```ini
# Node Group 1
[ndbd]
NodeId=2
Hostname=server6  # Physical server 6
NodeGroup=0       # Explicitly assigned to node group 0

[ndbd]
NodeId=3
Hostname=server7  # Physical server 7
NodeGroup=0       # Same node group, different server

# Node Group 2
[ndbd]
NodeId=4
Hostname=server8  # Physical server 8
NodeGroup=1       # Different node group

[ndbd]
NodeId=5
Hostname=server6  # Same physical server as NodeId=2
NodeGroup=1       # Different node group

# Node Group 3
[ndbd]
NodeId=6
Hostname=server8  # Same physical server as NodeId=4
NodeGroup=2       # Different node group

[ndbd]
NodeId=7
Hostname=server7  # Same physical server as NodeId=3
NodeGroup=2       # Different node group
```

This explicit configuration ensures that:
1. Each node group has its nodes on different physical servers
2. Each server hosts nodes from different node groups
3. If any single server fails, all node groups still have one functioning node

## Monitoring Configuration

The monitoring setup includes:

1. **Prometheus**:
   - Collects metrics from all components
   - Configured with appropriate retention policies
   - Deployed on Server #4 alongside Management Node #1

2. **Grafana**:
   - Provides visualization dashboards
   - Pre-configured dashboards for Redis, MySQL Cluster, and system metrics
   - Deployed on Server #5 alongside Management Node #2

3. **Key Metrics to Monitor**:
   - Redis memory usage and throughput
   - Consumer service processing rates
   - MySQL Cluster data node memory usage
   - Query performance and throughput
   - System-level metrics (CPU, memory, network, disk)

## Bill of Quantities (BOQ)

The following specifications are recommended to handle the workload of 1.5 Lac TPS (150,000 transactions per second) and storing 60 Crore (600 million) daily records:

### Server Hardware Requirements

| Server ID | Role | CPU Cores (Physical) | RAM | Storage | Network |
|-----------|------|---------------------|-----|---------|--------|
| Server #1 | Redis Master + Sentinel + Consumer Services | 16 physical cores (32 threads) | 256 GB | 2 TB SSD (RAID 1) | 25 Gbps redundant |
| Server #2 | Redis Replica + Sentinel + Consumer Services | 16 physical cores (32 threads) | 256 GB | 2 TB SSD (RAID 1) | 25 Gbps redundant |
| Server #3 | Redis Replica + Sentinel + Consumer Services | 16 physical cores (32 threads) | 256 GB | 2 TB SSD (RAID 1) | 25 Gbps redundant |
| Server #4 | Management Node + SQL Node + ProxySQL + Prometheus | 12 physical cores (24 threads) | 128 GB | 4 TB SSD (RAID 10) | 25 Gbps redundant |
| Server #5 | Management Node + SQL Node + ProxySQL + Grafana | 12 physical cores (24 threads) | 128 GB | 4 TB SSD (RAID 10) | 25 Gbps redundant |
| Server #6 | Data Nodes (2) | 12 physical cores (24 threads) | 512 GB | 8 TB SSD (RAID 10) | 100 Gbps redundant |
| Server #7 | Data Nodes (2) | 12 physical cores (24 threads) | 512 GB | 8 TB SSD (RAID 10) | 100 Gbps redundant |
| Server #8 | Data Nodes (2) | 12 physical cores (24 threads) | 512 GB | 8 TB SSD (RAID 10) | 100 Gbps redundant |

### Network Requirements

| Component | Specification | Quantity |
|-----------|--------------|----------|
| Core Switches | 100 Gbps with redundancy | 2 |
| ToR Switches | 25/100 Gbps | 4 |
| Network Cards | 25/100 Gbps (redundant) | 16 |

### Storage Configuration

| Server Type | Storage Configuration | Purpose | Required IOPS |
|-------------|----------------------|---------|---------------|
| Redis Servers | RAID 1 | OS, Redis persistence | 150,000 IOPS |
| Management/SQL Servers | RAID 10 | OS, MySQL binaries, logs | 200,000 IOPS |
| Data Node Servers | RAID 10 | OS, MySQL data | 500,000 IOPS |

### Capacity Planning

| Component | Sizing Calculation | Recommended Capacity |
|-----------|-------------------|---------------------|
| Redis Memory | Peak TPS (150K) × Avg. Message Size (2KB) × Buffer (3x) | 900 GB (300 GB per server) |
| MySQL Storage | Daily Records (600M) × Avg. Record Size (1KB) × Retention (90 days) × Replication (2x) | 108 TB (36 TB per server) |
| Network Bandwidth | Peak TPS (150K) × Avg. Message Size (2KB) × 8 bits × 3 (replication factor) | ~7.2 Gbps minimum |

## Conclusion

This optimized architecture provides:

1. **Reduced Server Count**: From 10+ servers to 8 servers
2. **Maintained High Availability**: Through strategic component placement
3. **Simplified Client Connectivity**: Using Sentinel-aware clients instead of a load balancer
4. **Efficient Resource Utilization**: By colocating components with complementary resource profiles
5. **Comprehensive Monitoring**: With Prometheus and Grafana integration
6. **Clear Data Flow**: From producer applications through Redis to MySQL Cluster
7. **Resource Optimization**: Components placed according to their resource profiles

The architecture ensures that the system can handle 1.5 Lac TPS with Redis as a queue and store 60 Crore daily records in MySQL Cluster while maintaining high availability and performance.
