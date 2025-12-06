# GPU Cluster Setup Guide

This guide explains how to set up a multi-GPU cluster for distributed notebook execution.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      GPU Notebook (Flutter)                      │
│                        - Select GPU Node                         │
│                        - Run kernels remotely                    │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Main Backend (FastAPI)                       │
│                    - Cluster Manager                             │
│                    - Node Health Monitoring                      │
│                    - Kernel Routing                              │
└───────────┬─────────────────┬─────────────────┬─────────────────┘
            │                 │                 │
            ▼                 ▼                 ▼
┌───────────────────┐ ┌───────────────────┐ ┌───────────────────┐
│   GPU Node 1      │ │   GPU Node 2      │ │   GPU Node N      │
│   RTX 4090        │ │   RTX 3090        │ │   A100            │
│   Enterprise GW   │ │   Enterprise GW   │ │   Enterprise GW   │
│   Port: 8888      │ │   Port: 8888      │ │   Port: 8888      │
└───────────────────┘ └───────────────────┘ └───────────────────┘
```

## Quick Start

### 1. Setup Worker Nodes

On each GPU machine, run:

```bash
# Download and run setup script
curl -O https://raw.githubusercontent.com/your-repo/setup_worker.sh
chmod +x setup_worker.sh
sudo ./setup_worker.sh
```

The script will:
- Check for NVIDIA GPU
- Install Jupyter Enterprise Gateway
- Install PyTorch with CUDA
- Create systemd service
- Start the gateway on port 8888

### 2. Verify Worker Node

```bash
# Check service status
sudo systemctl status jupyter-gateway

# Test API
curl http://localhost:8888/api

# Test GPU endpoint
curl http://localhost:8888/api/gpu
```

### 3. Add Nodes in UI

1. Open GPU Notebook
2. Go to Settings → Cluster
3. Click "Add Node"
4. Enter node name, IP address, and port (8888)
5. Click "Add"

The node will appear in the cluster panel with GPU information.

### 4. Use Cluster Kernels

When creating a notebook or running code:
1. Select a node from the node selector (or use "Auto")
2. Kernels will be created on the selected node
3. Code execution happens on the remote GPU

## Configuration

### Worker Node Configuration

Edit `/opt/jupyter-gateway/config.py`:

```python
c = get_config()

# Network
c.EnterpriseGatewayApp.ip = '0.0.0.0'
c.EnterpriseGatewayApp.port = 8888

# Security (for production)
c.EnterpriseGatewayApp.allow_origin = 'https://your-domain.com'

# Limits
c.EnterpriseGatewayApp.max_kernels = 10
c.EnterpriseGatewayApp.kernel_launch_timeout = 60
```

Restart after changes:
```bash
sudo systemctl restart jupyter-gateway
```

### Main Backend Configuration

Edit `cluster_config.json` (auto-created):

```json
{
  "nodes": [
    {
      "id": "node-1",
      "name": "GPU Server 1",
      "host": "192.168.1.100",
      "port": 8888,
      "tags": ["training", "high-memory"],
      "priority": 10
    }
  ]
}
```

## Kernel Placement

### Auto Placement

When "Auto" is selected, the system chooses the best node based on:
1. Node must be online
2. Node must have available kernel slots
3. If GPU required, node must have GPU with free memory
4. Prefer nodes with higher priority
5. Prefer nodes with lower utilization

### Manual Placement

Specify a node when creating kernels:
- Use the node selector in the UI
- Or specify `node_id` in API calls

### Tag-based Placement

Use tags to route kernels to specific nodes:
- Add tags to nodes (e.g., "training", "inference")
- Specify required tags when creating kernels

## API Reference

### List Nodes
```
GET /api/cluster/nodes
```

### Add Node
```
POST /api/cluster/nodes
{
  "name": "GPU Server 1",
  "host": "192.168.1.100",
  "port": 8888,
  "tags": ["training"],
  "priority": 10
}
```

### Create Kernel
```
POST /api/cluster/kernels
{
  "placement": {
    "node_id": null,          # null for auto
    "require_gpu": true,
    "min_gpu_memory": 8000,   # MB
    "tags": ["training"]
  },
  "kernel_name": "python3"
}
```

### Get Cluster Stats
```
GET /api/cluster/stats
```

## Monitoring

### Health Checks

The cluster manager automatically:
- Checks node health every 30 seconds
- Updates GPU/memory status
- Tracks kernel counts
- Detects offline nodes

### Logs

Main backend:
```bash
tail -f /var/log/notebook-backend.log
```

Worker nodes:
```bash
sudo journalctl -u jupyter-gateway -f
```

## Troubleshooting

### Node shows "Offline"

1. Check if the gateway is running:
   ```bash
   sudo systemctl status jupyter-gateway
   ```

2. Check firewall:
   ```bash
   sudo ufw allow 8888/tcp
   ```

3. Test connectivity:
   ```bash
   curl http://node-ip:8888/api
   ```

### Kernel fails to start

1. Check gateway logs:
   ```bash
   sudo journalctl -u jupyter-gateway -n 100
   ```

2. Verify Python/CUDA:
   ```bash
   /opt/jupyter-gateway/venv/bin/python -c "import torch; print(torch.cuda.is_available())"
   ```

### GPU not detected

1. Check NVIDIA drivers:
   ```bash
   nvidia-smi
   ```

2. Check CUDA:
   ```bash
   nvcc --version
   ```

## Security Recommendations

For production deployments:

1. **Use TLS**: Configure HTTPS on gateway
2. **Firewall**: Only allow connections from main backend
3. **Authentication**: Enable token authentication
4. **Network**: Use private network/VPN

Example secure configuration:
```python
c.EnterpriseGatewayApp.certfile = '/path/to/cert.pem'
c.EnterpriseGatewayApp.keyfile = '/path/to/key.pem'
c.EnterpriseGatewayApp.allow_origin = 'https://your-domain.com'
```
