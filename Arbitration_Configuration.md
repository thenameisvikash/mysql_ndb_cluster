# MySQL Cluster Arbitration Configuration Guide

## Overview

Arbitration is a critical mechanism in MySQL Cluster that prevents split-brain scenarios. A split-brain occurs when a cluster is partitioned into two or more groups that cannot communicate with each other, causing each group to believe it is the only surviving part of the cluster. This can lead to data inconsistency and corruption.

## Arbitration Parameter Configuration

The `Arbitration` parameter in the management node configuration file (`config.ini`) controls how arbitration is performed. This parameter is crucial for maintaining high availability while preventing split-brain scenarios.

### Available Arbitration Settings

```ini
[ndbd default]
# or in specific [ndbd] sections
Arbitration=Default|Disabled|WaitExternal
```

- **Default**: The management server acts as the arbitrator (default setting). This is suitable for most deployments.
- **Disabled**: No arbitration is used. Not recommended for production as it can lead to split-brain scenarios.
- **WaitExternal**: The cluster waits for an external arbitrator application to perform arbitration. This requires additional setup.

### Example Configuration

```ini
[ndb_mgmd]
NodeId=1
HostName=management1
DataDir=/var/lib/mysql-cluster

[ndbd default]
NoOfReplicas=2
Arbitration=Default
ArbitrationTimeout=7500
```

## Related Arbitration Parameters

### ArbitrationTimeout

```ini
ArbitrationTimeout=7500
```

This parameter specifies the maximum time (in milliseconds) that the cluster will wait for arbitration to complete before declaring a node dead. The default is 7500 ms (7.5 seconds).

### ArbitrationRank

```ini
ArbitrationRank=1
```

This parameter determines which nodes can act as arbitrators. Nodes with higher ranks are preferred as arbitrators:
- 0: Node cannot be arbitrator (default for API nodes)
- 1: Low priority (default for management nodes)
- 2: High priority

## Best Practices for Arbitration Configuration

1. **Always have an odd number of nodes**: This ensures a majority can always be established.

2. **Configure multiple management nodes**: For redundancy, configure at least two management nodes with different arbitration ranks.

3. **Network considerations**: Ensure reliable network connectivity between all nodes, especially management nodes that act as arbitrators.

4. **Monitor arbitration events**: Set up alerts for arbitration events in the cluster log to quickly identify potential issues.

## Example: Robust Arbitration Setup

For a production environment, consider this configuration with two management nodes:

```ini
[ndb_mgmd]
NodeId=1
HostName=management1
DataDir=/var/lib/mysql-cluster
ArbitrationRank=1

[ndb_mgmd]
NodeId=2
HostName=management2
DataDir=/var/lib/mysql-cluster
ArbitrationRank=2

[ndbd default]
NoOfReplicas=2
Arbitration=Default
ArbitrationTimeout=7500
```

In this setup, `management2` will be the preferred arbitrator due to its higher arbitration rank.

## Verifying Arbitration Configuration

To verify your arbitration configuration:

1. Connect to the management node using the ndb_mgm client:
   ```bash
   ndb_mgm -c management1
   ```

2. Check the status of arbitration:
   ```
   ndb_mgm> show
   ```

3. Review the cluster log for arbitration-related events:
   ```bash
   grep -i arbitration /var/lib/mysql-cluster/ndb_*.log
   ```

By properly configuring arbitration, you can ensure your MySQL Cluster remains highly available while preventing data inconsistency issues caused by split-brain scenarios.
