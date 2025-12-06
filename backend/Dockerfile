FROM nvidia/cuda:12.2-runtime-ubuntu22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install Python and dependencies
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3-pip \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -m -s /bin/bash app
USER app
WORKDIR /home/app

# Create virtual environment
RUN python3.11 -m venv /home/app/venv
ENV PATH="/home/app/venv/bin:$PATH"

# Copy requirements first for caching
COPY --chown=app:app requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install PyTorch with CUDA support
RUN pip install --no-cache-dir \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Install ML libraries
RUN pip install --no-cache-dir \
    transformers \
    accelerate \
    numpy \
    pandas \
    matplotlib \
    seaborn \
    opencv-python-headless \
    pillow \
    scikit-learn \
    scipy \
    tqdm

# Copy application code
COPY --chown=app:app . .

# Create directories
RUN mkdir -p uploads/notebooks

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/docs')"

# Run server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
