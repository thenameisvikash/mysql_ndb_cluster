# MySQL Cluster Backup and Recovery Guide

## Overview

Backup and recovery are critical operational aspects of any production database system. MySQL Cluster provides native tools and methods for backing up and restoring data, ensuring business continuity and data protection. This guide covers comprehensive backup strategies, recovery procedures, and best practices for MySQL Cluster environments.

## Table of Contents

1. [Backup Types](#backup-types)
2. [Online Backup](#online-backup)
3. [Scheduling Regular Backups](#scheduling-regular-backups)
4. [Backup Verification](#backup-verification)
5. [Recovery Procedures](#recovery-procedures)
6. [Point-in-Time Recovery](#point-in-time-recovery)
7. [Partial Backups and Restores](#partial-backups-and-restores)
8. [Backup Storage Considerations](#backup-storage-considerations)
9. [Backup Compression](#backup-compression)
10. [Docker Environment Considerations](#docker-environment-considerations)
11. [Best Practices](#best-practices)

## Backup Types

MySQL Cluster supports several backup approaches:

1. **NDB Native Backups**: Using the `ndb_mgm` client and `ndb_restore` utility
2. **Logical Backups**: Using `mysqldump` for schema-level backups
3. **Binary Backups**: Using file system snapshots for complete system backups

Each approach has different use cases, advantages, and limitations.

## Online Backup

One of the key advantages of MySQL Cluster is the ability to perform online backups without interrupting service. These backups are consistent snapshots of the cluster data at a point in time.

### Performing an Online Backup

1. **Connect to the management node**:
   ```bash
   ndb_mgm -c management1
   ```

2. **Initiate a backup**:
   ```
   ndb_mgm> start backup
   ```
   This command returns a backup ID that you'll need for restoration.

3. **Check backup status**:
   ```
   ndb_mgm> show
   ```

### Backup Files Location

Backup files are stored in the data directory of each data node, typically under:
```
/var/lib/mysql-cluster/BACKUP/BACKUP-{backup_id}/
```

Each backup consists of multiple files:
- `.ctl` - Control files containing metadata
- `.data` - Data files containing actual table data
- `.log` - Log files containing transaction information

## Scheduling Regular Backups

For production environments, automated regular backups are essential.

### Using Cron to Schedule Backups

1. **Create a backup script** (`/usr/local/bin/ndb_backup.sh`):
   ```bash
   #!/bin/bash
   # Script to perform MySQL Cluster backup
   
   # Set variables
   MGMD_HOST="management1"
   BACKUP_DIR="/var/backups/mysql-cluster"
   DATE=$(date +%Y%m%d-%H%M%S)
   LOG_FILE="/var/log/mysql-cluster/backup-$DATE.log"
   
   # Ensure backup directory exists
   mkdir -p $BACKUP_DIR
   mkdir -p $(dirname $LOG_FILE)
   
   # Perform backup
   echo "Starting MySQL Cluster backup at $(date)" >> $LOG_FILE
   BACKUP_ID=$(ndb_mgm -c $MGMD_HOST -e "start backup" | grep -oP 'Backup \K[0-9]+')
   
   if [ -z "$BACKUP_ID" ]; then
     echo "Backup failed - no backup ID returned" >> $LOG_FILE
     exit 1
   fi
   
   echo "Backup completed with ID: $BACKUP_ID at $(date)" >> $LOG_FILE
   
   # Copy backup files to backup directory
   for NODE in $(ndb_mgm -c $MGMD_HOST -e "show" | grep ndbd | awk '{print $2}'); do
     NODE_HOST=$(ndb_mgm -c $MGMD_HOST -e "show" | grep "id=$NODE" | awk '{print $3}' | cut -d'@' -f2)
     NODE_DIR="/var/lib/mysql-cluster/BACKUP/BACKUP-$BACKUP_ID"
     
     echo "Copying backup files from node $NODE ($NODE_HOST)" >> $LOG_FILE
     rsync -avz $NODE_HOST:$NODE_DIR $BACKUP_DIR/BACKUP-$BACKUP_ID-node$NODE/
   done
   
   # Cleanup old backups (keep last 7 days)
   find $BACKUP_DIR -type d -name "BACKUP-*" -mtime +7 -exec rm -rf {} \;
   
   echo "Backup process completed at $(date)" >> $LOG_FILE
   ```

2. **Make the script executable**:
   ```bash
   chmod +x /usr/local/bin/ndb_backup.sh
   ```

3. **Add to crontab** (daily backup at 1 AM):
   ```bash
   0 1 * * * /usr/local/bin/ndb_backup.sh
   ```

## Backup Verification

It's critical to verify that backups are valid and can be successfully restored.

### Backup Verification Process

1. **Perform a test restore** on a regular basis:
   ```bash
   # Create a test environment
   mkdir -p /tmp/ndb_restore_test
   
   # Restore metadata (create tables)
   ndb_restore -c management1 -n 1 -b backup_id -m -r /path/to/backup/BACKUP-backup_id
   
   # Restore data
   ndb_restore -c management1 -n 1 -b backup_id -r /path/to/backup/BACKUP-backup_id
   ```

2. **Validate restored data**:
   ```sql
   -- Connect to MySQL and run validation queries
   USE your_database;
   SELECT COUNT(*) FROM your_table;
   -- Compare with production counts
   ```

3. **Automate verification** with a script that performs test restores and validation checks

## Recovery Procedures

### Full Cluster Recovery

If you need to restore the entire cluster:

1. **Stop all MySQL Cluster processes**:
   ```bash
   # On management nodes
   ndb_mgmd -c management1 --shutdown
   
   # On data nodes
   ndbd -c management1 --shutdown
   
   # On SQL nodes
   systemctl stop mysql
   ```

2. **Clear data directories** on all data nodes:
   ```bash
   rm -rf /var/lib/mysql-cluster/ndb_*
   ```

3. **Start management nodes**:
   ```bash
   ndb_mgmd -f /path/to/config.ini
   ```

4. **Start data nodes with --initial flag**:
   ```bash
   ndbd -c management1 --initial
   ```

5. **Restore metadata** (schema):
   ```bash
   ndb_restore -c management1 -n 1 -b backup_id -m -r /path/to/backup/BACKUP-backup_id
   ```

6. **Restore data to all nodes**:
   ```bash
   # For node 1
   ndb_restore -c management1 -n 1 -b backup_id -r /path/to/backup/BACKUP-backup_id
   
   # For node 2
   ndb_restore -c management1 -n 2 -b backup_id -r /path/to/backup/BACKUP-backup_id
   
   # Repeat for all data nodes
   ```

7. **Rebuild indexes**:
   ```bash
   ndb_restore -c management1 -n 1 -b backup_id --rebuild-indexes -r /path/to/backup/BACKUP-backup_id
   ```

8. **Start SQL nodes**:
   ```bash
   systemctl start mysql
   ```

### Single Node Recovery

If only one data node has failed:

1. **Stop the failed node**:
   ```bash
   ndb_mgm> node_id stop
   ```

2. **Clear the node's data directory**:
   ```bash
   rm -rf /var/lib/mysql-cluster/ndb_*
   ```

3. **Restart the node with --initial flag**:
   ```bash
   ndbd -c management1 --initial
   ```

The node will automatically synchronize with the cluster.

## Point-in-Time Recovery

For point-in-time recovery, you need:
1. A full backup
2. Binary logs from the time of the backup to the desired recovery point

### Process:

1. **Restore the full backup** as described above

2. **Apply binary logs** up to the desired point in time:
   ```bash
   mysqlbinlog --start-datetime="2025-05-10 10:00:00" --stop-datetime="2025-05-10 11:00:00" /path/to/binlog | mysql -u root -p
   ```

## Partial Backups and Restores

You can perform partial backups and restores for specific databases or tables.

### Backing Up Specific Databases

Using mysqldump for logical backups of specific databases:
```bash
mysqldump -u root -p --databases db1 db2 > specific_dbs_backup.sql
```

### Restoring Specific Tables

1. **Create a restore filter file** (`/tmp/restore_filter.txt`):
   ```
   DATABASE.TABLE1
   DATABASE.TABLE2
   ```

2. **Use the filter with ndb_restore**:
   ```bash
   ndb_restore -c management1 -n 1 -b backup_id -r --include-tables=/tmp/restore_filter.txt /path/to/backup/BACKUP-backup_id
   ```

## Backup Storage Considerations

### Remote Storage

For disaster recovery, store backups in a remote location:

1. **Automatically copy backups** to remote storage:
   ```bash
   # Add to backup script
   aws s3 sync $BACKUP_DIR s3://your-backup-bucket/mysql-cluster/
   # Or for non-AWS environments
   rsync -avz $BACKUP_DIR remote_server:/backup/mysql-cluster/
   ```

2. **Implement retention policies** for both local and remote storage

### Storage Requirements

Calculate storage requirements based on:
- Database size
- Growth rate
- Retention period
- Compression ratio

A general guideline is to allocate 3-5x your database size for backup storage.

## Backup Compression

Compress backups to save storage space:

```bash
# Compress backup files
tar -czf backup-$BACKUP_ID.tar.gz /var/lib/mysql-cluster/BACKUP/BACKUP-$BACKUP_ID/

# For restoring compressed backups
tar -xzf backup-$BACKUP_ID.tar.gz -C /tmp/
ndb_restore -c management1 -n 1 -b $BACKUP_ID -m -r /tmp/BACKUP-$BACKUP_ID
```

## Docker Environment Considerations

For MySQL Cluster running in Docker containers:

1. **Mount backup volumes** to persist backups outside containers:
   ```yaml
   volumes:
     - ./backups:/var/lib/mysql-cluster/BACKUP
   ```

2. **Create a backup container** that has access to all data node volumes:
   ```yaml
   backup-service:
     image: mysql/mysql-cluster:8.0
     volumes:
       - ./ndb1/data:/var/lib/mysql-cluster/ndb1
       - ./ndb2/data:/var/lib/mysql-cluster/ndb2
       - ./backups:/backups
     command: /bin/bash -c "/usr/local/bin/ndb_backup.sh && tail -f /dev/null"
   ```

3. **Use Docker exec** to run backups manually:
   ```bash
   docker exec -it management1 ndb_mgm -e "start backup"
   ```

## Best Practices

1. **Implement a 3-2-1 backup strategy**:
   - 3 copies of data
   - 2 different storage types
   - 1 off-site copy

2. **Automate backup verification**:
   - Regularly test restores
   - Validate data integrity
   - Document recovery time

3. **Monitor backup processes**:
   - Set up alerts for backup failures
   - Track backup sizes and durations
   - Monitor storage usage

4. **Document recovery procedures**:
   - Create step-by-step recovery playbooks
   - Assign roles and responsibilities
   - Conduct regular recovery drills

5. **Secure backups**:
   - Encrypt sensitive data
   - Implement access controls
   - Audit backup access

6. **Optimize backup windows**:
   - Schedule backups during low-traffic periods
   - Use incremental backups where possible
   - Distribute backup load across nodes

## Conclusion

A robust backup and recovery strategy is essential for MySQL Cluster deployments. By implementing the procedures outlined in this guide, you can ensure data protection, minimize downtime, and maintain business continuity in the event of failures or data corruption.

Remember that backup strategies should evolve with your database environment. Regularly review and update your backup procedures to accommodate changes in data volume, criticality, and infrastructure.
