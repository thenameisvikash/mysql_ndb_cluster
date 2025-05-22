# MySQL Cluster Node Group Expansion Guide

## Overview

One of the powerful features of MySQL Cluster is the ability to add new node groups online to a running cluster. This capability allows you to scale your cluster horizontally without downtime, increasing both storage capacity and performance.

## Understanding Node Groups

A node group in MySQL Cluster consists of a set of data nodes that store replicas of the same partitions. Each node group contains a complete copy of all data in the cluster. Adding a new node group effectively increases the cluster's capacity and can improve performance for certain workloads.

## Benefits of Online Node Group Expansion

1. **Increased Storage Capacity**: Each new node group adds additional storage capacity to the cluster.
2. **Improved Query Performance**: More node groups can process queries in parallel, potentially improving performance.
3. **Enhanced Scalability**: Grow your cluster as your data and performance needs increase.
4. **Zero Downtime**: Add capacity without interrupting service to applications.

## Prerequisites for Node Group Expansion

Before adding new node groups to a running cluster:

1. Ensure your cluster is healthy and all existing nodes are online.
2. Verify you have sufficient hardware resources for the new nodes.
3. Check that network connectivity is properly configured for the new nodes.
4. Ensure the new nodes have the same MySQL Cluster software version as existing nodes.

## Step-by-Step Node Group Expansion Process

### 1. Prepare the Configuration File

Update your `config.ini` file to include the new data nodes. Each node group requires at least two data nodes (for the default `NoOfReplicas=2`).

Example of adding a new node group (node group 2) to an existing cluster with two node groups:

```ini
# Existing nodes in node group 0
[ndbd]
NodeId=1
HostName=ndb1
DataDir=/var/lib/mysql-cluster

[ndbd]
NodeId=2
HostName=ndb2
DataDir=/var/lib/mysql-cluster

# Existing nodes in node group 1
[ndbd]
NodeId=3
HostName=ndb3
DataDir=/var/lib/mysql-cluster

[ndbd]
NodeId=4
HostName=ndb4
DataDir=/var/lib/mysql-cluster

# New nodes in node group 2
[ndbd]
NodeId=5
HostName=ndb5
DataDir=/var/lib/mysql-cluster

[ndbd]
NodeId=6
HostName=ndb6
DataDir=/var/lib/mysql-cluster
```

### 2. Deploy the New Data Nodes

1. Install MySQL Cluster software on the new nodes.
2. Configure the new nodes with the updated `config.ini`.
3. Start the new data nodes:

```bash
# On each new data node
ndbmtd -c management1
```

### 3. Verify Node Group Addition

Connect to the management node and verify that the new nodes have joined the cluster:

```bash
ndb_mgm -c management1
ndb_mgm> show
```

You should see the new nodes listed with their respective node IDs and node groups.

### 4. Redistribute Data (Optional)

After adding new node groups, you may want to redistribute existing data to take advantage of the additional capacity:

```bash
ndb_mgm> all restart -n
```

This performs a rolling restart of all data nodes, which will redistribute data across all node groups.

## Using Docker Compose for Node Group Expansion

If you're using Docker Compose for your MySQL Cluster deployment, you can add new node groups by updating your `docker-compose.yml` file:

```yaml
# Add new services for the additional node group
  ndb5:
    image: mysql/mysql-cluster:8.0
    command: ndbd -c management1
    networks:
      - mysql-cluster
    depends_on:
      - management1
    restart: on-failure

  ndb6:
    image: mysql/mysql-cluster:8.0
    command: ndbd -c management1
    networks:
      - mysql-cluster
    depends_on:
      - management1
    restart: on-failure
```

Then apply the changes:

```bash
docker-compose up -d
```

## Monitoring Node Group Performance

After adding new node groups, monitor their performance to ensure they are functioning correctly:

1. Check the cluster log for any errors related to the new nodes.
2. Monitor the distribution of data across node groups using the `ndb_desc` tool.
3. Use Prometheus and Grafana to track performance metrics for the new nodes.

## Limitations and Considerations

1. **Maximum Node Groups**: MySQL Cluster supports up to 48 node groups.
2. **Resource Requirements**: Each new node group requires additional hardware resources.
3. **Network Impact**: More node groups increase network traffic between nodes.
4. **Backup Considerations**: Ensure your backup strategy accounts for the additional node groups.

## Conclusion

Online node group expansion is a powerful feature of MySQL Cluster that allows you to scale your cluster horizontally without downtime. By following the steps outlined in this guide, you can effectively increase your cluster's capacity and performance to meet growing demands.
