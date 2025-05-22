# Node Groups and Split Brain Prevention

[← Architecture Overview](overview.md) | [Documentation Index](../index.md) | [High Throughput Architecture →](high-throughput.md)

*Related: [Arbitration Configuration](../configuration/arbitration.md) | [Data Nodes Configuration](../configuration/data-nodes.md)*

This document explains node groups in MySQL Cluster and how to prevent split-brain scenarios.

## Node Groups Overview

In MySQL Cluster, data nodes are organized into node groups. Each node group contains a complete copy of the cluster data, providing redundancy and high availability.

### Key Concepts

- **Node Group**: A set of data nodes that store a complete copy of the data
- **Replica**: A copy of the data within a node group
- **NoOfReplicas**: The number of replicas in each node group (typically 2)
- **Partitioning**: Data is automatically partitioned across node groups

### Node Group Structure

In a typical MySQL Cluster configuration with 4 data nodes:

```
[ndbd(NDB)]     4 node(s)
id=2    @172.20.0.3  (mysql-8.0.32 ndb-8.0.32, Nodegroup: 0, *)
id=3    @172.20.0.4  (mysql-8.0.32 ndb-8.0.32, Nodegroup: 0)
id=6    @172.20.0.7  (mysql-8.0.32 ndb-8.0.32, Nodegroup: 1)
id=7    @172.20.0.8  (mysql-8.0.32 ndb-8.0.32, Nodegroup: 1, *)
```

This configuration has:
- 2 node groups (0 and 1)
- 2 replicas per node group (NoOfReplicas=2)
- Node group 0: nodes 2 and 3
- Node group 1: nodes 6 and 7

### Data Distribution

Data is distributed across node groups as follows:

1. Each table is partitioned into fragments
2. Fragments are distributed evenly across node groups
3. Each fragment is replicated within its node group
4. All nodes in a node group contain the same fragments

This distribution provides:
- Horizontal scalability (by adding more node groups)
- High availability (through replication within node groups)
- Load balancing (by distributing queries across nodes)

## Split Brain Scenarios

A split-brain scenario occurs when a cluster is divided into two or more parts that cannot communicate with each other, but each part believes it is the only active part of the cluster.

### Causes of Split Brain

1. **Network Partition**: Network failures that isolate parts of the cluster
2. **Management Node Failure**: Failure of management nodes that coordinate the cluster
3. **Misconfiguration**: Incorrect configuration of node groups or arbitration
4. **Resource Exhaustion**: Resource issues that cause nodes to become unresponsive

### Consequences of Split Brain

Split-brain scenarios can lead to:
- **Data Inconsistency**: Different parts of the cluster may accept conflicting changes
- **Data Loss**: When the cluster is reunited, some changes may be lost
- **Service Disruption**: Parts of the cluster may become unavailable
- **System Instability**: The cluster may behave unpredictably

## Preventing Split Brain

MySQL Cluster provides several mechanisms to prevent split-brain scenarios:

### 1. Arbitration

Arbitration is the process by which the cluster decides which part should remain active in case of a network partition.

#### Arbitration Types

MySQL Cluster supports several arbitration types:

- **Default**: Uses a data node as arbitrator
- **Disk**: Uses a shared disk as arbitrator
- **WaitExternal**: Waits for external arbitration
- **Disabled**: No arbitration (not recommended)

#### Configuring Arbitration

In the management node configuration (`management-config.ini`):

```ini
[ndbd default]
Arbitration=Default                # Arbitration type
ArbitrationTimeout=7500            # Timeout in milliseconds
```

### 2. Node Group Configuration

Proper node group configuration is essential for preventing split-brain scenarios:

- **Minimum of 2 Replicas**: Always configure at least 2 replicas per node group
- **Balanced Node Groups**: Distribute nodes evenly across node groups
- **Physical Separation**: Place nodes in different physical locations
- **Network Redundancy**: Provide redundant network paths between nodes

Example configuration:

```ini
[ndbd default]
NoOfReplicas=2                     # Number of replicas per node group

[ndbd]
NodeId=2
HostName=ndb1
NodeGroup=0

[ndbd]
NodeId=3
HostName=ndb2
NodeGroup=0

[ndbd]
NodeId=6
HostName=ndb3
NodeGroup=1

[ndbd]
NodeId=7
HostName=ndb4
NodeGroup=1
```

### 3. Heartbeat Configuration

Heartbeat mechanisms detect node failures and network partitions:

```ini
[ndbd default]
HeartbeatIntervalDbDb=15000        # Heartbeat interval between data nodes (ms)
HeartbeatIntervalDbApi=15000       # Heartbeat interval between data and API nodes (ms)
TimeBetweenWatchdogCheck=6000      # Watchdog check interval (ms)
```

### 4. Timeouts and Failure Detection

Proper timeout configuration ensures timely detection of failures:

```ini
[ndbd default]
TimeBetweenEpochs=100              # Time between epochs (ms)
TimeBetweenEpochsTimeout=0         # Timeout for epochs (ms)
TransactionDeadlockDetectionTimeout=1200  # Deadlock detection timeout (ms)
TransactionInactiveTimeout=0       # Transaction inactive timeout (ms)
```

### 5. Management Node Redundancy

Deploy multiple management nodes for redundancy:

```ini
[ndb_mgmd]
NodeId=1
HostName=management1
DataDir=/var/lib/mysql-cluster

[ndb_mgmd]
NodeId=8
HostName=management2
DataDir=/var/lib/mysql-cluster
```

## Detecting Split Brain

To detect potential split-brain scenarios:

### 1. Monitor Cluster Status

Regularly check the cluster status:

```bash
ndb_mgm -e "show"
```

Look for:
- Nodes that are not connected
- Nodes in different states
- Unexpected node group configurations

### 2. Check Error Logs

Monitor error logs for signs of network issues or node failures:

```bash
# Check management node logs
cat /var/lib/mysql-cluster/ndb_1_cluster.log

# Check data node logs
cat /var/lib/mysql-cluster/ndb_2_error.log
```

### 3. Monitor Network Connectivity

Regularly check network connectivity between nodes:

```bash
# From each node, ping all other nodes
ping ndb1
ping ndb2
ping management1
```

### 4. Use Monitoring Tools

Set up monitoring tools to alert on potential split-brain conditions:

- Monitor node status
- Monitor network connectivity
- Monitor cluster events
- Set up alerts for node failures

## Recovering from Split Brain

If a split-brain scenario occurs, follow these steps to recover:

### 1. Identify the Issue

Determine the cause of the split-brain:
- Network partition
- Node failure
- Resource exhaustion
- Configuration issue

### 2. Isolate Affected Nodes

Stop the affected nodes to prevent further data inconsistency:

```bash
# Stop data nodes
ndb_mgm -e "2 stop"
ndb_mgm -e "3 stop"
```

### 3. Resolve the Root Cause

Fix the underlying issue:
- Repair network connectivity
- Resolve resource issues
- Correct configuration problems

### 4. Restart the Cluster

Restart the cluster in a controlled manner:

```bash
# Start management nodes first
ndb_mgm -e "1 start"
ndb_mgm -e "8 start"

# Start data nodes in node group 0
ndb_mgm -e "2 start"
ndb_mgm -e "3 start"

# Start data nodes in node group 1
ndb_mgm -e "6 start"
ndb_mgm -e "7 start"

# Start SQL nodes
ndb_mgm -e "4 start"
ndb_mgm -e "5 start"
```

### 5. Verify Data Consistency

Check for data inconsistencies:

```sql
-- Run consistency checks on important tables
CHECK TABLE important_table;
```

### 6. Restore from Backup if Necessary

If data inconsistencies cannot be resolved, restore from a backup:

```bash
# Restore from backup
ndb_restore -c management1:1186 -n 2 -b backup_id -m -r /path/to/backup
```

## Best Practices

### Node Group Design

1. **Minimum of 2 Node Groups**: Deploy at least 2 node groups for redundancy
2. **2 Replicas per Node Group**: Configure 2 replicas in each node group
3. **Physical Separation**: Place nodes in different physical locations
4. **Balanced Resources**: Ensure all nodes have similar resources

### Network Configuration

1. **Redundant Networks**: Provide redundant network paths
2. **Dedicated Network**: Use a dedicated network for cluster communication
3. **Low Latency**: Ensure low latency between nodes
4. **Network Monitoring**: Monitor network performance and connectivity

### Arbitration Configuration

1. **Default Arbitration**: Use default arbitration for most deployments
2. **Appropriate Timeouts**: Configure appropriate arbitration timeouts
3. **Regular Testing**: Test arbitration by simulating node failures
4. **Documentation**: Document arbitration configuration and procedures

### Monitoring and Alerting

1. **Proactive Monitoring**: Monitor cluster status proactively
2. **Automated Alerts**: Set up alerts for potential issues
3. **Regular Checks**: Perform regular health checks
4. **Documentation**: Document monitoring procedures and alert responses

## Related Documentation

- [Architecture Overview](overview.md) - Core architecture of MySQL Cluster
- [Arbitration Configuration](../configuration/arbitration.md) - Detailed arbitration configuration
- [Data Nodes Configuration](../configuration/data-nodes.md) - Data node configuration
- [Troubleshooting](../troubleshooting/cluster-issues.md) - Troubleshooting cluster issues
