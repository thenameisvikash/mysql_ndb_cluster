# MySQL Cluster Upgrade Procedures

## Overview

Upgrading a MySQL Cluster installation requires careful planning and execution to minimize downtime and ensure data integrity. This guide outlines the procedures for upgrading MySQL Cluster to newer versions while maintaining high availability.

## Table of Contents

1. [Upgrade Planning](#upgrade-planning)
2. [Upgrade Paths](#upgrade-paths)
3. [Pre-Upgrade Checklist](#pre-upgrade-checklist)
4. [Rolling Upgrade Procedure](#rolling-upgrade-procedure)
5. [Offline Upgrade Procedure](#offline-upgrade-procedure)
6. [Post-Upgrade Verification](#post-upgrade-verification)
7. [Rollback Procedures](#rollback-procedures)
8. [Docker Environment Upgrades](#docker-environment-upgrades)
9. [Upgrading from Very Old Versions](#upgrading-from-very-old-versions)
10. [Common Upgrade Issues](#common-upgrade-issues)
11. [Best Practices](#best-practices)

## Upgrade Planning

### Considerations Before Upgrading

1. **Review Release Notes**: Understand new features, deprecated features, and breaking changes
2. **Check Compatibility**: Ensure your applications are compatible with the new version
3. **Estimate Downtime**: Even rolling upgrades may have brief periods of reduced performance
4. **Create a Detailed Plan**: Document each step with timing and responsible personnel
5. **Prepare Rollback Plan**: In case the upgrade encounters issues

### Testing the Upgrade

Always test the upgrade procedure in a non-production environment that mirrors your production setup:

1. **Create a Test Environment**: Clone your production environment as closely as possible
2. **Perform a Test Upgrade**: Follow the same procedures planned for production
3. **Test Applications**: Verify all applications work correctly with the upgraded cluster
4. **Measure Performance**: Compare performance metrics before and after the upgrade
5. **Document Issues**: Note any issues encountered and their solutions

## Upgrade Paths

MySQL Cluster supports the following upgrade paths:

1. **Minor Version Upgrades**: (e.g., 8.0.27 to 8.0.28)
   - Can usually be performed as rolling upgrades
   - Minimal compatibility issues

2. **Major Version Upgrades**: (e.g., 7.6 to 8.0)
   - May require offline upgrades
   - More potential for compatibility issues
   - May require schema changes

3. **Supported Direct Upgrade Paths**:
   - 7.6 → 8.0
   - 8.0 → 8.1
   - 8.1 → 8.2

For other paths, you may need to perform intermediate upgrades.

## Pre-Upgrade Checklist

Complete these tasks before beginning the upgrade:

1. **Backup the Cluster**:
   ```bash
   ndb_mgm -c management1 -e "start backup"
   ```

2. **Check Cluster Health**:
   ```bash
   ndb_mgm -c management1 -e "show"
   ```
   All nodes should be running and connected.

3. **Verify Disk Space**:
   Ensure sufficient disk space for both old and new versions during the upgrade.
   ```bash
   df -h
   ```

4. **Check for Schema Incompatibilities**:
   ```bash
   mysqlcheck -u root -p --all-databases
   ```

5. **Review Configuration Parameters**:
   Some parameters may be deprecated or have different defaults in the new version.
   ```bash
   ndb_config --config-file=/path/to/config.ini --query=all
   ```

6. **Update Monitoring Systems**:
   Ensure monitoring systems are aware of the planned upgrade to avoid false alarms.

7. **Communicate with Stakeholders**:
   Inform all stakeholders about the upgrade timing and potential impact.

## Rolling Upgrade Procedure

A rolling upgrade allows you to upgrade MySQL Cluster with minimal downtime. The general sequence is:

1. Management nodes
2. SQL nodes
3. Data nodes

### Step 1: Upgrade Management Nodes

1. **Upgrade one management node at a time**:
   ```bash
   # Stop the management node
   ndb_mgm -c management1 -e "shutdown"
   
   # Install new software
   apt-get update
   apt-get install mysql-cluster-community-management-server=8.0.28-1ubuntu20.04
   
   # Start the management node with the new version
   ndb_mgmd -f /path/to/config.ini --reload
   ```

2. **Verify the management node is running**:
   ```bash
   ndb_mgm -c management1 -e "show"
   ```

3. **Repeat for other management nodes**

### Step 2: Upgrade SQL Nodes

1. **Upgrade one SQL node at a time**:
   ```bash
   # Stop MySQL server
   systemctl stop mysql
   
   # Install new software
   apt-get update
   apt-get install mysql-cluster-community-server=8.0.28-1ubuntu20.04
   
   # Start MySQL server
   systemctl start mysql
   ```

2. **Verify the SQL node is connected to the cluster**:
   ```bash
   mysql -u root -p -e "SHOW ENGINE NDB STATUS\G"
   ```

3. **Repeat for other SQL nodes**

### Step 3: Upgrade Data Nodes

1. **Upgrade data nodes one node group at a time**. For each node group:

   a. **Upgrade the first node in the group**:
   ```bash
   # Stop the data node
   ndb_mgm -c management1 -e "node_id stop"
   
   # Install new software
   apt-get update
   apt-get install mysql-cluster-community-data-node=8.0.28-1ubuntu20.04
   
   # Start the data node
   ndbd -c management1
   ```

   b. **Wait for the node to rejoin the cluster**:
   ```bash
   ndb_mgm -c management1 -e "show"
   ```

   c. **Upgrade the second node in the group** using the same procedure

2. **Repeat for all node groups**

### Step 4: Finalize the Upgrade

1. **Verify all nodes are running the new version**:
   ```bash
   ndb_mgm -c management1 -e "show"
   mysql -u root -p -e "SELECT @@VERSION"
   ```

2. **Run MySQL upgrade procedure** on one SQL node:
   ```bash
   mysql_upgrade -u root -p
   ```

## Offline Upgrade Procedure

For major version upgrades or when rolling upgrades are not possible:

1. **Notify users of the planned downtime**

2. **Create a full backup**:
   ```bash
   ndb_mgm -c management1 -e "start backup"
   ```

3. **Shut down the entire cluster in this order**:
   ```bash
   # Stop SQL nodes
   systemctl stop mysql
   
   # Stop data nodes
   ndb_mgm -c management1 -e "shutdown"
   ```

4. **Upgrade all nodes**:
   ```bash
   # On all nodes
   apt-get update
   apt-get install mysql-cluster-*=8.0.28-1ubuntu20.04
   ```

5. **Update configuration files** if needed

6. **Start the cluster in this order**:
   ```bash
   # Start management nodes
   ndb_mgmd -f /path/to/config.ini
   
   # Start data nodes
   ndbd -c management1
   
   # Start SQL nodes
   systemctl start mysql
   ```

7. **Run MySQL upgrade procedure**:
   ```bash
   mysql_upgrade -u root -p
   ```

## Post-Upgrade Verification

After completing the upgrade:

1. **Verify Cluster Status**:
   ```bash
   ndb_mgm -c management1 -e "show"
   ```
   All nodes should be running and connected.

2. **Check Version Information**:
   ```bash
   mysql -u root -p -e "SELECT @@VERSION"
   mysql -u root -p -e "SHOW VARIABLES LIKE 'ndb_version%'"
   ```

3. **Verify Data Integrity**:
   ```bash
   mysqlcheck -u root -p --all-databases
   ```

4. **Run Application Tests**:
   Verify that all applications can connect and function correctly.

5. **Check Performance Metrics**:
   Compare key performance metrics with pre-upgrade baselines.

## Rollback Procedures

If you encounter critical issues during or after the upgrade:

### Rolling Back a Rolling Upgrade

1. **If still in progress**, upgrade remaining nodes to the old version instead of the new version

2. **If completed**, perform a rolling downgrade following the same procedure as the rolling upgrade but installing the previous version

### Rolling Back an Offline Upgrade

1. **Shut down the entire cluster**

2. **Reinstall the previous version** on all nodes

3. **Restore from backup** if necessary:
   ```bash
   # Restore metadata
   ndb_restore -c management1 -n 1 -b backup_id -m -r /path/to/backup
   
   # Restore data to all nodes
   ndb_restore -c management1 -n node_id -b backup_id -r /path/to/backup
   ```

## Docker Environment Upgrades

For MySQL Cluster running in Docker containers:

1. **Update the image tag** in your docker-compose.yml:
   ```yaml
   services:
     management1:
       image: mysql/mysql-cluster:8.0.28
       # other settings...
   ```

2. **Pull the new images**:
   ```bash
   docker-compose pull
   ```

3. **Perform a rolling upgrade** by restarting containers one at a time:
   ```bash
   # For each service
   docker-compose stop service_name
   docker-compose up -d service_name
   ```

4. **Verify the upgrade**:
   ```bash
   docker-compose exec mysql1 mysql -u root -p -e "SELECT @@VERSION"
   ```

## Upgrading from Very Old Versions

When upgrading from versions older than 7.6:

1. **Use a staged approach**:
   - First upgrade to 7.6
   - Then upgrade to 8.0
   - Finally upgrade to the target version

2. **Consider schema changes**:
   - Export schemas and data
   - Modify schemas as needed for compatibility
   - Import into the new version

3. **Plan for longer downtime**:
   - These upgrades typically cannot be done as rolling upgrades
   - Schedule extended maintenance windows

## Common Upgrade Issues

### Issue: Node Fails to Join Cluster After Upgrade

**Solution**:
```bash
# Check error logs
tail -f /var/lib/mysql-cluster/ndb_*.log

# Restart with --initial if needed
ndbd -c management1 --initial
```

### Issue: Incompatible Configuration Parameters

**Solution**:
```bash
# Check for deprecated parameters
grep -i deprecated /var/log/mysql-cluster/*.log

# Update config.ini with compatible parameters
# Restart affected nodes
```

### Issue: Performance Degradation After Upgrade

**Solution**:
```bash
# Check for configuration differences
diff old_config.ini new_config.ini

# Adjust buffer sizes and cache settings
# Monitor query performance
```

## Best Practices

1. **Document Everything**:
   - Create detailed upgrade runbooks
   - Record all commands executed
   - Document issues encountered and solutions

2. **Maintain Version Consistency**:
   - Keep all nodes at the same version in production
   - Complete upgrades promptly; don't leave the cluster in a mixed-version state

3. **Schedule Regular Upgrades**:
   - Plan for regular minor version upgrades
   - Stay current with security patches
   - Avoid falling too far behind the current release

4. **Test Thoroughly**:
   - Always test upgrades in a staging environment
   - Include application testing in your upgrade validation
   - Simulate failure scenarios during testing

5. **Monitor Closely During and After Upgrades**:
   - Increase monitoring frequency during the upgrade window
   - Watch for performance changes post-upgrade
   - Be prepared to roll back if necessary

## Conclusion

Upgrading MySQL Cluster requires careful planning and execution, but with proper preparation, you can minimize downtime and ensure a smooth transition to newer versions. By following the procedures outlined in this guide, you can maintain high availability while benefiting from new features, performance improvements, and security enhancements in newer MySQL Cluster versions.
