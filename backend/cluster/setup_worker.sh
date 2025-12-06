#!/bin/bash
# =============================================================================
# GPU Worker Node Setup Script for Jupyter Enterprise Gateway
# =============================================================================
#
# This script sets up a GPU machine as a worker node in the cluster.
# Run this on each GPU machine you want to add to the cluster.
#
# Usage:
#   chmod +x setup_worker.sh
#   sudo ./setup_worker.sh
#
# Requirements:
#   - NVIDIA GPU with drivers installed
#   - Python 3.9+
#   - CUDA Toolkit (for GPU kernels)
# =============================================================================

set -e

echo "=========================================="
echo "  GPU Worker Node Setup"
echo "=========================================="

# Configuration
GATEWAY_PORT=${GATEWAY_PORT:-8888}
INSTALL_DIR=${INSTALL_DIR:-/opt/jupyter-gateway}
VENV_DIR="$INSTALL_DIR/venv"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo ./setup_worker.sh)"
    exit 1
fi

# Check for NVIDIA GPU
echo ""
echo "[1/7] Checking for NVIDIA GPU..."
if ! command -v nvidia-smi &> /dev/null; then
    echo "ERROR: nvidia-smi not found. Please install NVIDIA drivers first."
    exit 1
fi

nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
echo "✓ NVIDIA GPU detected"

# Check Python version
echo ""
echo "[2/7] Checking Python version..."
PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
echo "Python version: $PYTHON_VERSION"

# Create installation directory
echo ""
echo "[3/7] Creating installation directory..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Create virtual environment
echo ""
echo "[4/7] Creating virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# Install dependencies
echo ""
echo "[5/7] Installing Jupyter Enterprise Gateway..."
pip install --upgrade pip
pip install jupyter_enterprise_gateway
pip install ipykernel
pip install numpy pandas matplotlib scikit-learn  # Common data science packages

# Install PyTorch with CUDA
echo ""
echo "[6/7] Installing PyTorch with CUDA support..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Create configuration
echo ""
echo "[7/7] Creating configuration..."

cat > "$INSTALL_DIR/config.py" << 'EOF'
# Jupyter Enterprise Gateway Configuration
c = get_config()

# Server settings
c.EnterpriseGatewayApp.ip = '0.0.0.0'
c.EnterpriseGatewayApp.port = 8888
c.EnterpriseGatewayApp.port_retries = 0

# Allow all origins (configure for your network in production)
c.EnterpriseGatewayApp.allow_origin = '*'

# Kernel management
c.EnterpriseGatewayApp.default_kernel_name = 'python3'
c.EnterpriseGatewayApp.kernel_spec_manager_class = 'jupyter_client.kernelspec.KernelSpecManager'

# Resource limits (adjust as needed)
c.EnterpriseGatewayApp.max_kernels = 10
c.EnterpriseGatewayApp.kernel_launch_timeout = 60

# Logging
c.EnterpriseGatewayApp.log_level = 'INFO'
EOF

# Create GPU info API endpoint
cat > "$INSTALL_DIR/gpu_api.py" << 'EOF'
"""
Custom API extension for GPU information.
"""
import subprocess
import json
from tornado import web

class GPUHandler(web.RequestHandler):
    def get(self):
        try:
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=index,name,memory.total,memory.used,memory.free,utilization.gpu,temperature.gpu,power.draw,driver_version', '--format=csv,noheader,nounits'],
                capture_output=True, text=True
            )

            gpus = []
            for line in result.stdout.strip().split('\n'):
                parts = [p.strip() for p in line.split(',')]
                if len(parts) >= 9:
                    gpus.append({
                        'index': int(parts[0]),
                        'name': parts[1],
                        'memory_total': int(parts[2]),
                        'memory_used': int(parts[3]),
                        'memory_free': int(parts[4]),
                        'utilization': int(parts[5]) if parts[5] != '[N/A]' else 0,
                        'temperature': int(parts[6]) if parts[6] != '[N/A]' else 0,
                        'power_usage': float(parts[7]) if parts[7] != '[N/A]' else 0.0,
                        'driver_version': parts[8],
                        'cuda_version': self._get_cuda_version()
                    })

            self.set_header('Content-Type', 'application/json')
            self.write(json.dumps({'gpus': gpus}))
        except Exception as e:
            self.set_status(500)
            self.write(json.dumps({'error': str(e)}))

    def _get_cuda_version(self):
        try:
            result = subprocess.run(['nvcc', '--version'], capture_output=True, text=True)
            for line in result.stdout.split('\n'):
                if 'release' in line:
                    return line.split('release')[1].split(',')[0].strip()
            return ''
        except:
            return ''


class SystemHandler(web.RequestHandler):
    def get(self):
        import psutil
        mem = psutil.virtual_memory()

        self.set_header('Content-Type', 'application/json')
        self.write(json.dumps({
            'cpu_count': psutil.cpu_count(),
            'memory_total': mem.total // (1024 * 1024),  # MB
            'memory_available': mem.available // (1024 * 1024),  # MB
            'cpu_percent': psutil.cpu_percent(),
        }))


def setup_handlers(app):
    app.add_handlers(r".*", [
        (r"/api/gpu", GPUHandler),
        (r"/api/system", SystemHandler),
    ])
EOF

# Install psutil for system info
pip install psutil

# Create systemd service
cat > /etc/systemd/system/jupyter-gateway.service << EOF
[Unit]
Description=Jupyter Enterprise Gateway
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$VENV_DIR/bin:/usr/local/cuda/bin:/usr/bin"
ExecStart=$VENV_DIR/bin/jupyter enterprisegateway --config=$INSTALL_DIR/config.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable jupyter-gateway
systemctl start jupyter-gateway

# Check status
echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Jupyter Enterprise Gateway is running on port $GATEWAY_PORT"
echo ""
echo "Node Information:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
echo ""
echo "Test the connection:"
echo "  curl http://localhost:$GATEWAY_PORT/api"
echo ""
echo "Add this node to your cluster in the GPU Notebook UI."
echo ""
echo "Service commands:"
echo "  sudo systemctl status jupyter-gateway"
echo "  sudo systemctl restart jupyter-gateway"
echo "  sudo journalctl -u jupyter-gateway -f"
echo ""
