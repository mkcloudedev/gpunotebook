# GPU Notebook - Backend

FastAPI backend for GPU Notebook with Jupyter kernel integration and AI providers.

## Quick Start

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or .\venv\Scripts\activate  # Windows

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Run server
python run.py
```

## Docker

```bash
docker-compose up --build
```

## API Documentation

- Scalar UI: http://localhost:8000/scalar
- OpenAPI: http://localhost:8000/openapi.json

## Project Structure

```
backend/
├── api/                    # API endpoints
│   ├── v1/                # API version 1
│   ├── notebooks.py       # Notebook CRUD
│   ├── kernels.py         # Kernel management
│   ├── ai.py              # AI integration
│   ├── gpu.py             # GPU monitoring
│   └── execute.py         # Code execution
├── ai/                    # AI providers
│   ├── claude_provider.py
│   ├── openai_provider.py
│   └── gemini_provider.py
├── services/              # Business logic
├── models/                # Data models
├── kernel/                # Jupyter integration
├── websocket/             # WebSocket handlers
├── core/                  # Core utilities
├── main.py               # App entry point
└── requirements.txt
```

## Environment Variables

See `.env.example` for all available configuration options.

### Required for AI Features

```env
ANTHROPIC_API_KEY=sk-ant-xxxxx
OPENAI_API_KEY=sk-xxxxx
GOOGLE_API_KEY=xxxxx
```

## Development

```bash
# Run with auto-reload
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Run tests
pytest

# Type checking
mypy .
```
