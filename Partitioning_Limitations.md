# MySQL Cluster Partitioning Limitations

## Overview

MySQL Cluster uses partitioning to distribute data across multiple data nodes for improved performance and scalability. However, there are specific limitations regarding partitioning schemes and configurations that must be understood when designing your database schema for MySQL Cluster.

## Supported Partitioning Schemes

Unlike standard MySQL, which supports various partitioning methods, MySQL Cluster has the following limitations:

1. **Only KEY and LINEAR KEY partitioning schemes are supported in production**
   - KEY partitioning: Uses a hashing function based on the primary key or unique key
   - LINEAR KEY partitioning: Similar to KEY but uses a linear hashing algorithm that allows for faster redistribution when adding or removing nodes

2. **Other partitioning types are not supported for production use**:
   - RANGE partitioning
   - LIST partitioning
   - HASH partitioning
   - LINEAR HASH partitioning

## Maximum Number of Partitions

The maximum number of partitions that can be explicitly defined for any NDB table is calculated as:

```
8 * [number of LDM threads] * [number of node groups]
```

Where:
- **LDM (Local Data Manager) threads**: The number of threads handling data operations on each data node
- **Node groups**: The number of node groups in the cluster

### Example Calculation

For a cluster with:
- 2 node groups
- 4 LDM threads per data node (using ndbmtd)

The maximum number of partitions would be:
```
8 * 4 * 2 = 64 partitions
```

When running `ndbd` (single-threaded) instead of `ndbmtd` (multi-threaded), the number of LDM threads is effectively 1.

## Implicit vs. Explicit Partitioning

1. **Implicit Partitioning**: 
   - By default, MySQL Cluster automatically partitions tables based on the primary key
   - The number of partitions equals the number of data nodes in the cluster

2. **Explicit Partitioning**:
   - You can explicitly define partitioning using the PARTITION BY clause
   - Must adhere to the limitations described above

## Example: Creating a Table with KEY Partitioning

```sql
CREATE TABLE customer (
    id INT NOT NULL,
    name VARCHAR(50),
    address VARCHAR(100),
    PRIMARY KEY (id)
) ENGINE=NDB
PARTITION BY KEY(id)
PARTITIONS 8;
```

## Example: Creating a Table with LINEAR KEY Partitioning

```sql
CREATE TABLE orders (
    order_id INT NOT NULL,
    customer_id INT NOT NULL,
    order_date DATETIME,
    PRIMARY KEY (order_id)
) ENGINE=NDB
PARTITION BY LINEAR KEY(order_id)
PARTITIONS 16;
```

## Best Practices for Partitioning in MySQL Cluster

1. **Choose Primary Keys Carefully**:
   - Primary keys are used for partitioning by default
   - Choose primary keys that distribute data evenly across partitions

2. **Avoid Hot Spots**:
   - Ensure your key selection doesn't create "hot spots" where certain partitions receive more traffic
   - Sequential keys can cause hot spots; consider using UUIDs or other non-sequential values

3. **Consider Partition Pruning**:
   - Design queries to take advantage of partition pruning
   - Queries that include the partitioning key in the WHERE clause can skip scanning irrelevant partitions

4. **Monitor Partition Distribution**:
   - Regularly check the distribution of data across partitions
   - Use the `ndb_desc` tool with the `-p` option to view partition information

## Checking Partition Information

To check how a table is partitioned:

```bash
ndb_desc -d database_name -t table_name -p
```

This command shows the distribution of partitions across data nodes.

## Limitations When Using User-Defined Partitioning

1. **ALTER TABLE with ADD/DROP PARTITION is not supported** for NDB tables with user-defined partitioning

2. **Maximum partition size** is determined by the amount of memory allocated to each data node

3. **Partition selection** must use the entire primary key; you cannot select partitions based on a subset of the primary key columns

4. **Online schema changes** involving partitioning are limited and may require table rebuilds

## Conclusion

Understanding the partitioning limitations in MySQL Cluster is essential for designing efficient and scalable database schemas. By adhering to the supported partitioning schemes (KEY and LINEAR KEY) and being aware of the maximum partition limits, you can optimize your MySQL Cluster deployment for performance and reliability.
