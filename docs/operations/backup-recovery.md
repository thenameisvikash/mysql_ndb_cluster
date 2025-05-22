# Backup and Recovery

[← Management Guide](management.md) | [Documentation Index](../index.md) | [Monitoring →](monitoring.md)

*Related: [User Management](user-management.md) | [Troubleshooting](../troubleshooting/common-issues.md)*

This guide provides comprehensive instructions for backing up and recovering your MySQL Cluster with ProxySQL deployment.

## Backup Types

MySQL Cluster supports several types of backups:

1. **Online Backups**: Full backups taken while the cluster is running
2. **Incremental Backups**: Backups of changes since the last backup
3. **Point-in-Time Recovery**: Recovery to a specific point in time using binary logs
4. **Snapshot Backups**: File system snapshots of data directories

## Online Backups

### Creating an Online Backup

To create an online backup of the entire cluster:

```bash
# Connect to the management node
docker exec -it management1 ndb_mgm --ndb-connectstring=management1:1186

# In the management client, run:
ndb_mgm> START BACKUP
```

This will create a backup in the data directory of each data node.

Alternatively, you can run the backup command directly:

```bash
docker exec management1 ndb_mgm -e "START BACKUP" --ndb-connectstring=management1:1186
```

The output will show the backup ID, which you'll need for restoration:

```
Waiting for completed, this may take several minutes
Node 2: Backup 1 started from node 1
Node 2: Backup 1 started from node 1 completed
 StartGCP: 177 StopGCP: 180
 #Records: 7362 #LogRecords: 0
 Data: 453648 bytes Log: 0 bytes
```

### Scheduling Regular Backups

To schedule regular backups, create a cron job:

```bash
# Edit the crontab
crontab -e

# Add a line to run a backup every day at 2 AM
0 2 * * * docker exec management1 ndb_mgm -e "START BACKUP" --ndb-connectstring=management1:1186 >> /var/log/mysql-cluster/backup.log 2>&1
```

### Backup Retention

To manage backup retention, create a script to delete old backups:

```bash
#!/bin/bash
# backup-cleanup.sh

# Keep backups for 7 days
RETENTION_DAYS=7

# Find and delete backups older than retention period
find /path/to/backup/directory -name "BACKUP-*" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;
```

Add this script to cron to run after your backup job.

## Incremental Backups

MySQL Cluster doesn't support native incremental backups, but you can achieve similar functionality using binary logs.

### Enabling Binary Logging

Edit the MySQL configuration files (`config/mysql1/my.cnf` and `config/mysql2/my.cnf`):

```ini
[mysqld]
log-bin=mysql-bin
binlog-format=ROW
expire_logs_days=7
```

Restart the MySQL nodes:

```bash
docker-compose restart mysql1 mysql2
```

### Backing Up Binary Logs

Periodically copy the binary logs to a safe location:

```bash
# For MySQL Node 1
docker cp mysql1:/var/lib/mysql/mysql-bin.* /path/to/backup/binlogs/mysql1/

# For MySQL Node 2
docker cp mysql2:/var/lib/mysql/mysql-bin.* /path/to/backup/binlogs/mysql2/
```

## Point-in-Time Recovery

To recover to a specific point in time:

1. Restore the last full backup
2. Apply binary logs up to the desired point in time

## Backup Verification

Always verify your backups to ensure they can be restored:

```bash
# Create a test environment
docker-compose -f docker-compose-test.yml up -d

# Restore the backup to the test environment
# (See restoration instructions below)

# Verify data integrity
docker exec mysql1-test mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SELECT COUNT(*) FROM database_name.table_name"
```

## Backup Storage

Store backups in multiple locations:

1. **Local Storage**: For quick recovery
2. **Remote Storage**: For disaster recovery
3. **Cloud Storage**: For additional redundancy

Example script to copy backups to Amazon S3:

```bash
#!/bin/bash
# backup-to-s3.sh

# Set variables
BACKUP_ID=$1
S3_BUCKET="your-backup-bucket"
DATE=$(date +%Y-%m-%d)

# Copy backup files to S3
aws s3 cp /path/to/backup/BACKUP-$BACKUP_ID s3://$S3_BUCKET/mysql-cluster-backups/$DATE/BACKUP-$BACKUP_ID --recursive
```

## Restoration

### Preparing for Restoration

Before restoring, stop the cluster:

```bash
docker-compose down
```

### Restoring an Online Backup

To restore from an online backup:

1. Start the management nodes:
   ```bash
   docker-compose up -d management1 management2
   ```

2. Start the data nodes with the `--initial` flag to clear existing data:
   ```bash
   docker-compose up -d ndb1 ndb2 ndb3 ndb4
   ```

3. Restore the backup to all data nodes:
   ```bash
   # Replace BACKUP_ID with your backup ID
   BACKUP_ID=1
   
   # Restore to all data nodes
   docker exec ndb1 ndb_restore -c management1:1186 -n 2 -b $BACKUP_ID -m -r /var/lib/mysql-cluster/BACKUP/BACKUP-$BACKUP_ID
   docker exec ndb2 ndb_restore -c management1:1186 -n 3 -b $BACKUP_ID -r /var/lib/mysql-cluster/BACKUP/BACKUP-$BACKUP_ID
   docker exec ndb3 ndb_restore -c management1:1186 -n 6 -b $BACKUP_ID -r /var/lib/mysql-cluster/BACKUP/BACKUP-$BACKUP_ID
   docker exec ndb4 ndb_restore -c management1:1186 -n 7 -b $BACKUP_ID -r /var/lib/mysql-cluster/BACKUP/BACKUP-$BACKUP_ID
   ```

4. Start the MySQL nodes:
   ```bash
   docker-compose up -d mysql1 mysql2
   ```

5. Start ProxySQL:
   ```bash
   docker-compose up -d proxysql proxysql2
   ```

### Restoring with Binary Logs

To restore with binary logs for point-in-time recovery:

1. Restore the full backup as described above

2. Apply binary logs up to the desired point in time:
   ```bash
   docker exec -i mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} < /path/to/backup/binlogs/mysql1/mysql-bin.000001
   ```

   Or to a specific position:
   ```bash
   docker exec mysql1 mysqlbinlog --stop-position=1234 /path/to/backup/binlogs/mysql1/mysql-bin.000001 | docker exec -i mysql1 mysql -uroot -p${MYSQL_ROOT_PASSWORD}
   ```

## Disaster Recovery

### Disaster Recovery Plan

1. **Backup Strategy**: Regular backups stored in multiple locations
2. **Recovery Time Objective (RTO)**: Define how quickly you need to recover
3. **Recovery Point Objective (RPO)**: Define acceptable data loss
4. **Disaster Recovery Environment**: Prepare a standby environment
5. **Testing**: Regularly test the disaster recovery process

### Cross-Region Replication

For critical deployments, consider setting up a cross-region replica:

1. Set up a second MySQL Cluster in a different region
2. Configure MySQL replication between the primary and secondary clusters
3. In case of disaster, promote the secondary cluster to primary

## Backup Monitoring

Monitor your backups to ensure they're running successfully:

```bash
# Check the last successful backup
docker exec management1 ls -la /var/lib/mysql-cluster/BACKUP/

# Check backup logs
cat /var/log/mysql-cluster/backup.log
```

Set up alerts for backup failures:

```bash
#!/bin/bash
# backup-monitor.sh

# Check if a backup was created in the last 24 hours
LATEST_BACKUP=$(docker exec management1 find /var/lib/mysql-cluster/BACKUP/ -name "BACKUP-*" -type d -mtime -1 | wc -l)

if [ $LATEST_BACKUP -eq 0 ]; then
  echo "No backup created in the last 24 hours!" | mail -s "MySQL Cluster Backup Failure" admin@example.com
fi
```

## Best Practices

1. **Regular Backups**: Schedule backups at least daily
2. **Multiple Backup Types**: Use both online backups and binary logs
3. **Multiple Storage Locations**: Store backups in multiple locations
4. **Backup Verification**: Regularly verify that backups can be restored
5. **Documentation**: Document the backup and recovery procedures
6. **Testing**: Regularly test the recovery process
7. **Monitoring**: Monitor backup jobs and set up alerts for failures
8. **Automation**: Automate backup and verification processes

## Related Documentation

- [Management Guide](management.md) - Day-to-day management operations
- [Monitoring](monitoring.md) - Monitoring your cluster
- [Troubleshooting](../troubleshooting/common-issues.md) - Troubleshooting common issues
