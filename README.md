# GPU Notebook

A full-stack web application for creating, managing, and executing interactive notebooks with GPU acceleration and AI integration.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Python](https://img.shields.io/badge/python-3.11+-green.svg)
![Flutter](https://img.shields.io/badge/flutter-3.0+-blue.svg)
![CUDA](https://img.shields.io/badge/CUDA-12.2-green.svg)

## Features

- **Interactive Notebooks** - Create and execute code cells with real-time output
- **GPU Monitoring** - Real-time GPU status, memory usage, and process tracking
- **AI Integration** - Multi-provider support (Claude, GPT-4, Gemini) for code assistance
- **Syntax Highlighting** - Python syntax highlighting with code folding
- **Kernel Management** - Multiple concurrent Jupyter kernels
- **File Management** - Upload, download, and browse files
- **Package Manager** - Install and manage Python packages
- **AutoML** - Automated machine learning pipelines
- **Dataset Management** - Upload datasets and Kaggle integration
- **Real-time Updates** - WebSocket-based live updates

## Screenshots

<!-- Add screenshots here -->

## Tech Stack

### Frontend
- **Flutter** (Web)
- **Dart 3.0+**
- Google Fonts, Lucide Icons
- WebSocket for real-time communication

### Backend
- **FastAPI** (Python 3.11+)
- **Jupyter Client** for kernel management
- **SQLAlchemy** + SQLite
- **Redis** (optional, for caching)

### AI Providers
- Anthropic Claude
- OpenAI GPT-4
- Google Gemini

### Infrastructure
- Docker with NVIDIA CUDA 12.2
- Docker Compose

## Project Structure

```
gpu-notebook/
├── backend/                    # Python FastAPI backend
│   ├── api/                   # API endpoints
│   │   ├── notebooks.py       # Notebook CRUD
│   │   ├── kernels.py         # Kernel management
│   │   ├── ai.py              # AI chat & assistance
│   │   ├── gpu.py             # GPU monitoring
│   │   ├── execute.py         # Code execution
│   │   ├── files.py           # File management
│   │   └── packages.py        # Package management
│   ├── ai/                    # AI provider implementations
│   │   ├── claude_provider.py
│   │   ├── openai_provider.py
│   │   └── gemini_provider.py
│   ├── services/              # Business logic
│   ├── models/                # Data models
│   ├── kernel/                # Jupyter kernel integration
│   ├── websocket/             # WebSocket handlers
│   ├── main.py                # App entry point
│   ├── requirements.txt
│   ├── Dockerfile
│   └── docker-compose.yml
│
└── book/                      # Flutter frontend
    ├── lib/
    │   ├── screens/           # Application screens
    │   ├── widgets/           # Reusable components
    │   ├── services/          # API services
    │   ├── models/            # Data models
    │   └── core/              # Theme & routing
    └── pubspec.yaml
```

## Getting Started

### Prerequisites

- Python 3.11+
- Flutter 3.0+
- Docker & Docker Compose (optional)
- NVIDIA GPU with CUDA 12.2 (optional, for GPU features)

### Backend Setup

1. Navigate to the backend directory:
```bash
cd backend
```

2. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or
.\venv\Scripts\activate  # Windows
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your API keys and settings
```

5. Run the server:
```bash
python run.py
# or
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Frontend Setup

1. Navigate to the frontend directory:
```bash
cd book
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the application:
```bash
flutter run -d chrome
```

### Docker Setup

Run the entire stack with Docker Compose:

```bash
cd backend
docker-compose up --build
```

This will start:
- FastAPI backend on port 8000
- Redis cache on port 6379

## Configuration

Create a `.env` file in the `backend` directory:

```env
# Application
APP_NAME=GPU Notebook
VERSION=1.0.0
DEBUG=true

# Server
HOST=0.0.0.0
PORT=8000
CORS_ORIGINS=http://localhost:3000,http://localhost:8080

# Database
DATABASE_URL=sqlite:///./data/notebook.db

# Redis (optional)
REDIS_URL=redis://localhost:6379

# Kernel Settings
KERNEL_TIMEOUT=300
MAX_KERNELS=10

# GPU Settings
ENABLE_GPU=true
GPU_MEMORY_FRACTION=0.8

# AI API Keys
ANTHROPIC_API_KEY=your-anthropic-key
OPENAI_API_KEY=your-openai-key
GOOGLE_API_KEY=your-google-key

# File Upload
UPLOAD_DIR=./uploads
MAX_UPLOAD_SIZE=104857600  # 100MB
```

## API Documentation

Once the backend is running, access the API documentation at:

- **Scalar UI**: http://localhost:8000/scalar
- **OpenAPI JSON**: http://localhost:8000/openapi.json

### Main Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/v1/notebooks` | List all notebooks |
| `POST /api/v1/notebooks` | Create a notebook |
| `GET /api/v1/kernels` | List active kernels |
| `POST /api/v1/kernels` | Start a new kernel |
| `POST /api/v1/execute` | Execute code |
| `GET /api/v1/gpu/status` | Get GPU status |
| `POST /api/v1/ai/chat` | Chat with AI |
| `POST /api/v1/ai/chat/stream` | Stream AI response |
| `WS /ws/kernel/{id}` | Kernel WebSocket |

## Usage

### Creating a Notebook

1. Click "New Notebook" in the sidebar
2. Add code or markdown cells
3. Execute cells with Shift+Enter
4. Save your work with Ctrl+S

### AI Assistant

1. Open the AI panel (right sidebar)
2. Select your preferred AI provider
3. Ask questions or request code help
4. AI can create, edit, and execute cells

### GPU Monitoring

1. Navigate to "GPU Monitor" in the sidebar
2. View real-time GPU metrics
3. Monitor memory usage and processes

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Shift+Enter` | Run cell and advance |
| `Ctrl+Enter` | Run cell |
| `Ctrl+S` | Save notebook |
| `Esc` | Enter command mode |
| `Enter` | Enter edit mode |
| `A` | Insert cell above (command mode) |
| `B` | Insert cell below (command mode) |
| `DD` | Delete cell (command mode) |
| `M` | Change to markdown (command mode) |
| `Y` | Change to code (command mode) |

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Jupyter](https://jupyter.org/) for kernel architecture
- [FastAPI](https://fastapi.tiangolo.com/) for the backend framework
- [Flutter](https://flutter.dev/) for the frontend framework
- [Anthropic](https://anthropic.com/), [OpenAI](https://openai.com/), [Google](https://ai.google/) for AI APIs
