# Prerequisites

[← Installation Guide](installation.md) | [Documentation Index](../index.md) | [Production Readiness →](production-ready.md)

*Related: [Quick Start Guide](quick-start.md) | [Architecture Overview](../architecture/overview.md)*

This document outlines the prerequisites for deploying a MySQL Cluster with ProxySQL.

## System Requirements

### Hardware Requirements

#### Development Environment
- **CPU**: 4+ cores
- **RAM**: 8GB+ (16GB recommended)
- **Disk Space**: 20GB+ free space
- **Network**: Stable network connection

#### Production Environment
- **CPU**: 8+ cores (16+ recommended)
- **RAM**: 32GB+ (64GB+ recommended)
- **Disk Space**: 100GB+ SSD storage
- **Network**: High-speed, low-latency network connection

### Operating System

- **Linux**: Ubuntu 20.04+, Debian 10+, CentOS 8+, or RHEL 8+
- **macOS**: 10.15+ (Catalina or later)
- **Windows**: Windows 10 with WSL2 (Linux subsystem)

## Software Requirements

### Required Software

- **Docker Engine**: 20.10+
  - Installation: [Docker Installation Guide](https://docs.docker.com/engine/install/)
  - Verify with: `docker --version`

- **Docker Compose**: 2.0+
  - Installation: [Docker Compose Installation Guide](https://docs.docker.com/compose/install/)
  - Verify with: `docker-compose --version`

- **MySQL Client**: 8.0+
  - Ubuntu/Debian: `sudo apt-get install mysql-client`
  - CentOS/RHEL: `sudo yum install mysql`
  - macOS: `brew install mysql-client`
  - Verify with: `mysql --version`

### Optional Software

- **Git**: For cloning the repository
  - Installation: [Git Installation Guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - Verify with: `git --version`

- **Python**: 3.6+ for running performance tests
  - Installation: [Python Installation Guide](https://www.python.org/downloads/)
  - Verify with: `python3 --version`

- **Bash**: 4.0+ for running scripts
  - Most Linux distributions include Bash by default
  - macOS: `brew install bash`
  - Verify with: `bash --version`

## Network Requirements

### Ports

The following ports must be available on your host machine:

| Port | Service | Description |
|------|---------|-------------|
| 1186 | Management Node | NDB management server |
| 1187 | Management Node 2 | Secondary NDB management server |
| 3306 | MySQL | MySQL server 1 |
| 3307 | MySQL | MySQL server 2 |
| 6033 | ProxySQL | MySQL protocol interface |
| 6032 | ProxySQL | Admin interface |
| 6034 | ProxySQL 2 | Secondary MySQL protocol interface |
| 6035 | ProxySQL 2 | Secondary admin interface |

Verify port availability with:

```bash
# Check if ports are in use
netstat -tuln | grep -E '1186|1187|3306|3307|6033|6032|6034|6035'
```

### Docker Network

The deployment creates a dedicated Docker network (`ndb-net`) for internal communication between containers. Ensure Docker can create and manage networks on your system.

## Docker Configuration

### Resource Allocation

Configure Docker with sufficient resources:

- **Memory**: At least 8GB
- **CPU**: At least 4 cores
- **Disk**: At least 20GB

#### Docker Desktop Configuration

If using Docker Desktop:

1. Open Docker Desktop
2. Go to Settings/Preferences
3. Select Resources
4. Allocate at least 8GB of memory and 4 CPUs
5. Apply and restart Docker

### Docker Permissions

Ensure your user has permissions to run Docker commands:

```bash
# Add your user to the docker group (Linux)
sudo usermod -aG docker $USER

# Apply changes
newgrp docker
```

## Environment Variables

The following environment variables can be set to customize the deployment:

```bash
# MySQL Credentials
export MYSQL_ROOT_PASSWORD=your_secure_root_password
export READWRITE_USER=readwrite
export READWRITE_PASSWORD=your_secure_readwrite_password
export READONLY_USER=readonly
export READONLY_PASSWORD=your_secure_readonly_password

# ProxySQL Credentials
export PROXYSQL_ADMIN_USER=radmin
export PROXYSQL_ADMIN_PASSWORD=your_secure_admin_password

# Resource Allocation
export DATA_MEMORY=512M
export INDEX_MEMORY=128M
```

## Security Considerations

### Firewall Configuration

If you have a firewall enabled, allow the required ports:

```bash
# Ubuntu/Debian with UFW
sudo ufw allow 1186/tcp
sudo ufw allow 1187/tcp
sudo ufw allow 3306/tcp
sudo ufw allow 3307/tcp
sudo ufw allow 6033/tcp
sudo ufw allow 6032/tcp
sudo ufw allow 6034/tcp
sudo ufw allow 6035/tcp

# CentOS/RHEL with firewalld
sudo firewall-cmd --permanent --add-port=1186/tcp
sudo firewall-cmd --permanent --add-port=1187/tcp
sudo firewall-cmd --permanent --add-port=3306/tcp
sudo firewall-cmd --permanent --add-port=3307/tcp
sudo firewall-cmd --permanent --add-port=6033/tcp
sudo firewall-cmd --permanent --add-port=6032/tcp
sudo firewall-cmd --permanent --add-port=6034/tcp
sudo firewall-cmd --permanent --add-port=6035/tcp
sudo firewall-cmd --reload
```

### SELinux Configuration

If SELinux is enabled, configure it to allow Docker to access the necessary directories:

```bash
# Allow Docker to access the project directory
sudo chcon -Rt container_file_t /path/to/mysql-cluster-proxysql
```

## Verification Checklist

Use this checklist to verify that all prerequisites are met:

- [ ] Hardware meets minimum requirements
- [ ] Operating system is supported
- [ ] Docker Engine is installed and running
- [ ] Docker Compose is installed
- [ ] MySQL Client is installed
- [ ] Required ports are available
- [ ] Docker has sufficient resources allocated
- [ ] User has permissions to run Docker commands
- [ ] Firewall is configured (if applicable)
- [ ] SELinux is configured (if applicable)

Run the following command to verify Docker is working correctly:

```bash
docker run --rm hello-world
```

If successful, you should see a message indicating that Docker is working correctly.

## Troubleshooting

### Docker Issues

- **Error**: "Cannot connect to the Docker daemon"
  - **Solution**: Ensure Docker service is running
    ```bash
    sudo systemctl start docker
    ```

- **Error**: "Permission denied"
  - **Solution**: Add your user to the docker group
    ```bash
    sudo usermod -aG docker $USER
    newgrp docker
    ```

### Port Conflicts

- **Error**: "Port is already allocated"
  - **Solution**: Identify and stop the process using the port
    ```bash
    sudo lsof -i :<port_number>
    sudo kill <process_id>
    ```
  - Alternatively, modify the `docker-compose.yml` file to use different ports

### Resource Limitations

- **Error**: "No space left on device"
  - **Solution**: Free up disk space or increase Docker's storage allocation

- **Error**: "Container exited due to OOM (Out of Memory)"
  - **Solution**: Increase Docker's memory allocation

## Next Steps

Once you have met all prerequisites, proceed to the [Installation Guide](installation.md) for detailed installation instructions.

## Related Documentation

- [Quick Start Guide](quick-start.md) - Get up and running quickly
- [Installation Guide](installation.md) - Detailed installation instructions
- [Production Readiness](production-ready.md) - Guidelines for production deployment
- [Architecture Overview](../architecture/overview.md) - Core architecture of MySQL Cluster with ProxySQL
