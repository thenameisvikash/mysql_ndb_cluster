# Understanding Node Groups and Split-Brain Scenarios in MySQL Cluster

This document provides a detailed explanation of node groups in MySQL Cluster and how to prevent and handle split-brain scenarios. It's designed to complement the main MySQL Cluster DevOps Guide.

## Table of Contents

1. [Node Groups in MySQL Cluster](#node-groups-in-mysql-cluster)
2. [How to Determine the Optimal Node Group Configuration](#how-to-determine-the-optimal-node-group-configuration)
3. [Split-Brain Scenarios: Causes and Risks](#split-brain-scenarios-causes-and-risks)
4. [Arbitration Mechanisms in MySQL Cluster](#arbitration-mechanisms-in-mysql-cluster)
5. [Preventing Split-Brain Scenarios](#preventing-split-brain-scenarios)
6. [Detecting and Recovering from Split-Brain](#detecting-and-recovering-from-split-brain)
7. [Network Configuration Best Practices](#network-configuration-best-practices)

## Node Groups in MySQL Cluster

### What is a Node Group?

A node group in MySQL Cluster is a collection of data nodes that store complete replicas of all data. Each node group contains a set of data nodes equal to the `NoOfReplicas` configuration parameter (typically 2).

```
Node Group 0:   [Data Node 1]  [Data Node 2]
Node Group 1:   [Data Node 3]  [Data Node 4]
```

### How Data is Distributed Across Node Groups

MySQL Cluster automatically partitions data across node groups using a process called **horizontal partitioning** or **sharding**:

1. **Partitioning**: Data is first divided into partitions based on the primary key using a hashing function
2. **Distribution**: Each partition is then assigned to a node group
3. **Replication**: Within each node group, the partition is replicated according to `NoOfReplicas`

For example, with 2 node groups and 4 data nodes (2 nodes per group):

```
Table with 4 partitions:
- Partition 0: Primary on Node 1 (Group 0), Replica on Node 2 (Group 0)
- Partition 1: Primary on Node 3 (Group 1), Replica on Node 4 (Group 1)
- Partition 2: Primary on Node 2 (Group 0), Replica on Node 1 (Group 0)
- Partition 3: Primary on Node 4 (Group 1), Replica on Node 3 (Group 1)
```

### Node Group Significance

The critical aspect of node groups is that **each node group contains a complete copy of all data**. This means:

1. As long as at least one node in each node group is operational, the cluster can access all data
2. If all nodes in a single node group fail, the cluster loses access to some partitions and cannot operate fully
3. Adding more node groups increases capacity and performance but not redundancy within a group

## How to Determine the Optimal Node Group Configuration

### Factors to Consider

1. **High Availability Requirements**:
   - Minimum: 1 node group with `NoOfReplicas=2` (2 data nodes total)
   - Better: 2+ node groups with `NoOfReplicas=2` (4+ data nodes total)

2. **Performance Requirements**:
   - More node groups = more parallelism for queries
   - More node groups = higher total throughput

3. **Data Volume**:
   - Each node group adds capacity
   - Formula: `Total Capacity = DataMemory × Number of Node Groups`

4. **Geographic Distribution**:
   - For disaster recovery, place different node groups in different data centers
   - Ensure sufficient bandwidth and low latency between sites

### Recommended Configurations

| Scenario | Configuration | Benefits |
|----------|---------------|----------|
| Development/Testing | 1 node group, 2 data nodes | Minimal resource usage |
| Small Production | 2 node groups, 4 data nodes | Basic HA with some scalability |
| Medium Production | 3-4 node groups, 6-8 data nodes | Good balance of HA and performance |
| Large Production | 6+ node groups, 12+ data nodes | High throughput and capacity |
| Geographic HA | 3+ node groups across 3+ data centers | Disaster recovery capability |

### Configuration Example

```ini
[ndbd default]
NoOfReplicas=2    # Number of replicas per partition

# Node Group 0
[ndbd]
NodeId=2
Hostname=ndbd1
NodeGroup=0       # Explicit node group assignment

[ndbd]
NodeId=3
Hostname=ndbd2
NodeGroup=0       # Same node group as ndbd1

# Node Group 1
[ndbd]
NodeId=4
Hostname=ndbd3
NodeGroup=1       # Different node group

[ndbd]
NodeId=5
Hostname=ndbd4
NodeGroup=1       # Same node group as ndbd3
```

## Split-Brain Scenarios: Causes and Risks

### What is a Split-Brain?

A split-brain scenario occurs when a cluster is divided into two or more partitions due to network issues, and each partition believes it's the only valid part of the cluster. This can lead to:

1. Data inconsistency
2. Conflicting writes
3. Data loss
4. System instability

### Common Causes of Split-Brain

1. **Network Partitions**: Physical or logical separation of network segments
2. **Switch Failures**: Core network equipment issues
3. **Misconfigured Firewalls**: Blocking cluster communication
4. **High Network Latency**: Causing heartbeat timeouts
5. **Improper Shutdown**: Nodes not properly removed from the cluster

### Specific Risks in MySQL Cluster

In MySQL Cluster, a split-brain can cause:

1. **Data Divergence**: Different partitions accepting conflicting writes
2. **Cluster Instability**: Nodes constantly trying to rejoin and reorganize
3. **Transaction Failures**: Inability to complete distributed transactions
4. **Metadata Inconsistency**: Schema changes applied differently across partitions

## Arbitration Mechanisms in MySQL Cluster

MySQL Cluster has built-in arbitration mechanisms to prevent split-brain scenarios.

### How Arbitration Works

1. When a network partition occurs, nodes in each partition determine if they form a "majority"
2. The arbitrator (typically the management node) decides which partition survives
3. Nodes in the non-surviving partition shut down or enter a special state

### Arbitration Types

MySQL Cluster supports several arbitration types, configured with the `Arbitration` parameter:

1. **Default**: Uses the management server as arbitrator
2. **WaitExternal**: Waits for external input before deciding
3. **Disabled**: No arbitration (dangerous, can lead to split-brain)

### Arbitration Configuration

```ini
[ndbd default]
# Arbitration settings
Arbitration=Default                # Arbitration type
ArbitrationTimeout=7500            # Timeout in milliseconds
ArbitrationRank=1                  # Priority in arbitration (higher = preferred)

[ndb_mgmd]
NodeId=1
HostName=mgmd1
ArbitrationRank=1                  # Management node as primary arbitrator
```

## Preventing Split-Brain Scenarios

### Network Configuration

1. **Redundant Networks**:
   - Implement redundant network paths between all nodes
   - Use separate switches and network cards
   - Configure bonded network interfaces

2. **Heartbeat Network**:
   - Dedicate a separate network for cluster interconnect
   - Ensure low latency and high reliability

### Proper Cluster Configuration

1. **Appropriate Timeouts**:
   ```ini
   [ndbd default]
   HeartbeatIntervalDbDb=1500      # Heartbeat between data nodes (ms)
   HeartbeatIntervalDbApi=1500     # Heartbeat to API nodes (ms)
   TimeBetweenWatchDogCheck=6000   # Node failure detection (ms)
   ```

2. **Node Placement**:
   - Distribute node groups across different failure domains
   - Ensure management nodes are highly available

3. **Minimum Node Count**:
   - Always use at least 3 physical servers (2 for data nodes, 1 for management)
   - For production, use 5+ physical servers

### Quorum and Majority Rules

MySQL Cluster uses quorum-based decision making:

1. **Node Count Majority**: A partition must contain more than half of all nodes
2. **Node Group Majority**: A partition must contain at least one node from each node group
3. **Arbitration Decision**: The arbitrator makes the final decision in ambiguous cases

## Detecting and Recovering from Split-Brain

### Detection Methods

1. **Cluster Logs**:
   - Monitor for messages like "Network partitioning detected"
   - Check for arbitration events

2. **Management Client**:
   ```bash
   ndb_mgm -e "show"               # Shows disconnected nodes
   ndb_mgm -e "all report"         # Detailed status report
   ```

3. **Monitoring Tools**:
   - Configure alerts for node disconnections
   - Monitor transaction failures

### Recovery Procedures

1. **Automatic Recovery**:
   - MySQL Cluster will automatically recover in many cases
   - The non-surviving partition will restart and rejoin

2. **Manual Intervention**:
   ```bash
   # Stop all nodes in both partitions
   ndb_mgm -e "shutdown"
   
   # Start management nodes first
   systemctl start ndb_mgmd
   
   # Start data nodes in sequence
   systemctl start ndbd
   
   # Check cluster status
   ndb_mgm -e "show"
   ```

3. **Data Reconciliation**:
   - If data divergence occurred, you may need to restore from backup
   - Use binary logs for point-in-time recovery

## Network Configuration Best Practices

### Physical Network Design

1. **Redundant Physical Paths**:
   - Multiple network interfaces
   - Multiple switches
   - Multiple routers

2. **Network Segmentation**:
   - Separate cluster traffic from application traffic
   - Use VLANs to isolate cluster communication

### Network Parameters

1. **TCP Settings**:
   ```bash
   # /etc/sysctl.conf
   net.ipv4.tcp_keepalive_time = 30
   net.ipv4.tcp_keepalive_intvl = 10
   net.ipv4.tcp_keepalive_probes = 3
   ```

2. **Firewall Configuration**:
   - Allow all cluster ports (1186, 3306, etc.)
   - Consider dedicated security groups for cluster nodes

### Monitoring Network Health

1. **Latency Monitoring**:
   ```bash
   # Set up regular ping tests between nodes
   ping -c 1 node2 | grep time
   ```

2. **Bandwidth Monitoring**:
   - Use tools like iftop or nethogs
   - Monitor for network saturation

3. **Packet Loss Detection**:
   ```bash
   # Check for packet loss between nodes
   ping -c 100 node2 | grep loss
   ```

## Conclusion

Understanding node groups and preventing split-brain scenarios is critical for maintaining a reliable MySQL Cluster deployment. By properly configuring node groups, implementing redundant networks, and understanding the arbitration mechanisms, you can minimize the risk of data inconsistency and service disruptions.

For your high-throughput application processing 1.5 Lac TPS and 60 Crore daily records, a properly configured MySQL Cluster with multiple node groups and robust network infrastructure will provide the necessary reliability and performance.
