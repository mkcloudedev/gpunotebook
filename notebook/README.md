# GPU Notebook - Frontend

React + TypeScript frontend for GPU Notebook, a Python notebook environment with GPU acceleration and AI integration.

## Tech Stack

- **React 18** + **TypeScript 5**
- **Vite** - Fast build tool and dev server
- **Tailwind CSS** - Utility-first CSS framework
- **shadcn/ui** - Accessible UI components
- **Monaco Editor** - VS Code-powered code editor
- **React Router** - Client-side routing
- **TanStack Query** - Data fetching and caching

## Features

- Interactive notebook editor with Monaco code cells
- Real-time GPU monitoring with speedometer gauges
- AI chat integration (Claude, GPT-4, Gemini)
- File browser and management
- Package manager for pip packages
- AutoML experiment configuration
- Kaggle dataset integration
- Keyboard shortcuts (Jupyter-compatible)

## Getting Started

### Prerequisites

- Node.js 18+
- npm or bun

### Installation

```bash
# Install dependencies
npm install

# Create environment file
cp .env.example .env
# Edit .env with your backend URL
```

### Development

```bash
# Start development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Lint code
npm run lint
```

### Environment Variables

Create a `.env` file in the root directory:

```env
VITE_API_URL=http://localhost:8000
```

## Project Structure

```
src/
├── components/           # React components
│   ├── ui/              # shadcn/ui components
│   ├── notebook/        # Notebook-specific components
│   ├── Dashboard.tsx    # Main dashboard
│   ├── Sidebar.tsx      # Navigation sidebar
│   └── ...
├── pages/               # Page components
│   ├── NotebookEditor.tsx
│   ├── Index.tsx
│   └── ...
├── services/            # API services
│   ├── apiClient.ts     # HTTP client
│   ├── notebookService.ts
│   ├── kernelService.ts
│   ├── gpuService.ts
│   ├── aiService.ts
│   └── ...
├── hooks/               # Custom React hooks
│   ├── useKernelExecution.ts
│   ├── useKeyboardShortcuts.ts
│   └── ...
├── types/               # TypeScript types
└── lib/                 # Utilities
```

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server |
| `npm run build` | Build for production |
| `npm run preview` | Preview production build |
| `npm run lint` | Run ESLint |

## License

MIT
