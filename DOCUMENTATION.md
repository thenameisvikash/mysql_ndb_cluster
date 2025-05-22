# MySQL Cluster with ProxySQL Documentation

## Documentation Structure

This document serves as the central index for all documentation related to the MySQL Cluster with ProxySQL project.

## Getting Started

- [README](README.md) - Project overview and quick start guide
- [Installation Guide](docs/installation.md) - Detailed installation instructions
- [Production Readiness](production_ready.md) - Guidelines for production deployment

## Architecture

- [Architecture Overview](docs/architecture.md) - Core architecture of MySQL Cluster with ProxySQL
- [High Throughput Architecture](High_Throughput_Architecture.md) - Architecture for high-throughput workloads (150K TPS, 600M daily records)
- [Optimized Architecture](Optimized_Architecture.md) - Performance-optimized architecture
- [Node Groups and Split Brain](Node_Groups_and_Split_Brain.md) - Understanding node groups and preventing split-brain scenarios

## Configuration

- [Configuration Guide](docs/configuration.md) - Detailed configuration options
- [Arbitration Configuration](Arbitration_Configuration.md) - Configuring arbitration to prevent split-brain
- [Partitioning Limitations](Partitioning_Limitations.md) - Understanding partitioning limitations in MySQL Cluster

## Operations

- [MySQL Cluster Management Guide](MySQL_Cluster_Management_Guide.md) - Day-to-day management operations
- [MySQL Cluster DevOps Guide](MySQL_Cluster_DevOps_Guide.md) - DevOps practices for MySQL Cluster
- [Backup and Recovery](Backup_and_Recovery.md) - Backup and recovery procedures
- [Upgrade Procedures](Upgrade_Procedures.md) - How to upgrade MySQL Cluster components
- [Node Group Expansion](Node_Group_Expansion.md) - Adding node groups to scale horizontally

## User Management

- [User Management Guide](docs/user-management.md) - Managing users across MySQL nodes and ProxySQL

## Testing and Performance

- [Testing Guide](docs/testing.md) - How to test your MySQL Cluster deployment
- [MySQL Cluster Testing Documentation](MySQL_Cluster_Testing_Documentation.md) - Comprehensive testing procedures
- [Performance Tuning](docs/performance-tuning.md) - Performance optimization guidelines

## Troubleshooting

- [Troubleshooting Guide](Troubleshooting_Guide.md) - Solutions to common problems
- [Detailed Troubleshooting](docs/troubleshooting.md) - In-depth troubleshooting procedures

## Scripts

- [MySQL Cluster Test Suite](mysql_cluster_test_suite.sh) - Automated testing script
- [User Management Script](scripts/user_management.sh) - Script for managing users across all nodes
