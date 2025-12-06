# Plan: Convertir Dashboard a Notebook con GPU

## Objetivo
Transformar el dashboard existente en un notebook interactivo capaz de:
- Ejecutar código Python con acceso a GPU (CUDA)
- Entrenar y probar modelos ML/DL
- Integrar APIs de AI (Claude, OpenAI, Google)
- Backend robusto en Kotlin/Java

---

## Arquitectura Propuesta

```
┌─────────────────────────────────────────────────────────────────────┐
│                         FRONTEND (React)                            │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Notebook UI                               │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │   │
│  │  │ Code    │  │ Output  │  │ GPU     │  │ Model   │        │   │
│  │  │ Cells   │  │ Display │  │ Monitor │  │ Manager │        │   │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘        │   │
│  │                                                              │   │
│  │  Monaco Editor │ Xterm.js │ Charts │ Image Viewer           │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │ WebSocket + REST
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    BACKEND (Kotlin/Spring Boot)                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    API Gateway                               │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │   │
│  │  │ Session │  │ Kernel  │  │ File    │  │ AI      │        │   │
│  │  │ Manager │  │ Manager │  │ Manager │  │ Gateway │        │   │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘        │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    EXECUTION ENGINE                                 │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │           Python Kernel Pool (IPython/Jupyter)               │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                      │   │
│  │  │ Kernel 1│  │ Kernel 2│  │ Kernel N│  (Docker/Podman)     │   │
│  │  │ GPU:0   │  │ GPU:0   │  │ CPU     │                      │   │
│  │  └─────────┘  └─────────┘  └─────────┘                      │   │
│  │                                                              │   │
│  │  PyTorch │ TensorFlow │ Transformers │ OpenCV │ NumPy       │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Stack Tecnológico Recomendado

### Frontend (Mantener React existente)
| Componente | Librería | Propósito |
|------------|----------|-----------|
| Editor de código | Monaco Editor | Syntax highlighting, autocompletado |
| Terminal | Xterm.js | Output de ejecución en tiempo real |
| Gráficos | Recharts (ya instalado) | Visualización de métricas |
| WebSocket | socket.io-client | Comunicación bidireccional |
| Estado | Zustand o Jotai | Manejo de estado del notebook |

### Backend (Kotlin + Spring Boot)
| Componente | Tecnología | Propósito |
|------------|------------|-----------|
| Framework | Spring Boot 3.x | API REST + WebSocket |
| WebSocket | Spring WebSocket + STOMP | Streaming de output |
| Kernel Comm | Jupyter Client (ZeroMQ) | Comunicación con kernels Python |
| Contenedores | Docker Java API | Gestión de kernels aislados |
| Base de datos | PostgreSQL | Notebooks, usuarios, sesiones |
| Cache | Redis | Sesiones, estado de kernels |
| AI Gateway | OkHttp/Retrofit | Claude, OpenAI, Google APIs |

### Python Execution Layer
| Componente | Tecnología | Propósito |
|------------|------------|-----------|
| Kernel | IPython Kernel | Ejecución interactiva |
| GPU | CUDA 12.x + cuDNN | Aceleración GPU |
| ML Framework | PyTorch 2.x | Deep Learning |
| Transformers | HuggingFace | Modelos pre-entrenados |
| Aislamiento | Docker + nvidia-docker | Seguridad y recursos |

---

## Componentes Frontend a Desarrollar

### 1. NotebookEditor (Componente Principal)
```typescript
// Estructura de un notebook
interface Notebook {
  id: string;
  name: string;
  cells: Cell[];
  metadata: NotebookMetadata;
  kernelId?: string;
}

interface Cell {
  id: string;
  type: 'code' | 'markdown' | 'output';
  content: string;
  outputs: CellOutput[];
  executionCount?: number;
  status: 'idle' | 'running' | 'success' | 'error';
}

interface CellOutput {
  type: 'text' | 'image' | 'html' | 'error' | 'stream';
  data: string;
  mimeType?: string;
}
```

### 2. CodeCell Component
- Monaco Editor integrado
- Botón ejecutar (Shift+Enter)
- Indicador de estado (idle/running/done)
- Número de ejecución [1], [2], etc.
- Output area colapsable

### 3. OutputRenderer
- Texto plano (stdout/stderr)
- Imágenes (matplotlib, PIL)
- HTML (pandas DataFrames)
- Gráficos interactivos
- Errores con traceback formateado

### 4. GPUMonitor
- Uso de GPU en tiempo real
- Memoria VRAM utilizada
- Temperatura
- Procesos activos

### 5. KernelSelector
- Lista de kernels disponibles
- Estado de cada kernel
- Crear/reiniciar/detener kernel

### 6. AIAssistant Panel
- Chat con Claude/GPT para ayuda con código
- Sugerencias de código
- Explicación de errores
- Generación de código

---

## API Backend (Kotlin)

### Endpoints REST

```kotlin
// Notebooks
GET    /api/notebooks              // Listar notebooks
POST   /api/notebooks              // Crear notebook
GET    /api/notebooks/{id}         // Obtener notebook
PUT    /api/notebooks/{id}         // Actualizar notebook
DELETE /api/notebooks/{id}         // Eliminar notebook

// Kernels
POST   /api/kernels                // Crear kernel
GET    /api/kernels                // Listar kernels activos
GET    /api/kernels/{id}/status    // Estado del kernel
POST   /api/kernels/{id}/interrupt // Interrumpir ejecución
DELETE /api/kernels/{id}           // Detener kernel

// Ejecución
POST   /api/execute                // Ejecutar código
GET    /api/execute/{id}/status    // Estado de ejecución

// GPU
GET    /api/gpu/status             // Estado de GPUs
GET    /api/gpu/processes          // Procesos GPU

// AI Integration
POST   /api/ai/chat                // Chat con AI
POST   /api/ai/complete            // Autocompletado
POST   /api/ai/explain             // Explicar código/error

// Files
GET    /api/files                  // Listar archivos
POST   /api/files/upload           // Subir archivo
GET    /api/files/{path}           // Descargar archivo
```

### WebSocket Events

```kotlin
// Cliente -> Servidor
EXECUTE_CODE      // Ejecutar celda
INTERRUPT_KERNEL  // Interrumpir
KERNEL_RESTART    // Reiniciar kernel

// Servidor -> Cliente
EXECUTION_START   // Inicio de ejecución
STREAM_OUTPUT     // Output en streaming
EXECUTION_RESULT  // Resultado final
EXECUTION_ERROR   // Error
GPU_STATUS        // Actualización GPU
KERNEL_STATUS     // Estado del kernel
```

---

## Estructura del Proyecto Backend (Kotlin)

```
backend/
├── src/main/kotlin/com/notebook/
│   ├── NotebookApplication.kt
│   ├── config/
│   │   ├── WebSocketConfig.kt
│   │   ├── SecurityConfig.kt
│   │   ├── DockerConfig.kt
│   │   └── AIConfig.kt
│   ├── controller/
│   │   ├── NotebookController.kt
│   │   ├── KernelController.kt
│   │   ├── ExecutionController.kt
│   │   ├── GPUController.kt
│   │   └── AIController.kt
│   ├── service/
│   │   ├── NotebookService.kt
│   │   ├── KernelService.kt
│   │   ├── ExecutionService.kt
│   │   ├── GPUMonitorService.kt
│   │   └── ai/
│   │       ├── AIService.kt
│   │       ├── ClaudeProvider.kt
│   │       ├── OpenAIProvider.kt
│   │       └── GeminiProvider.kt
│   ├── kernel/
│   │   ├── KernelManager.kt
│   │   ├── KernelProcess.kt
│   │   ├── JupyterClient.kt
│   │   └── DockerKernelFactory.kt
│   ├── websocket/
│   │   ├── NotebookWebSocketHandler.kt
│   │   └── OutputStreamHandler.kt
│   ├── model/
│   │   ├── Notebook.kt
│   │   ├── Cell.kt
│   │   ├── Kernel.kt
│   │   ├── ExecutionResult.kt
│   │   └── GPUStatus.kt
│   └── repository/
│       ├── NotebookRepository.kt
│       └── KernelRepository.kt
├── src/main/resources/
│   ├── application.yml
│   └── docker/
│       └── Dockerfile.kernel
└── build.gradle.kts
```

---

## Dockerfile para Kernel Python con GPU

```dockerfile
FROM nvidia/cuda:12.2-runtime-ubuntu22.04

# Python y dependencias base
RUN apt-get update && apt-get install -y \
    python3.11 python3-pip python3.11-venv \
    libgl1-mesa-glx libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Crear usuario no-root
RUN useradd -m -s /bin/bash notebook
USER notebook
WORKDIR /home/notebook

# Entorno virtual
RUN python3.11 -m venv /home/notebook/venv
ENV PATH="/home/notebook/venv/bin:$PATH"

# Instalar dependencias ML
RUN pip install --no-cache-dir \
    ipykernel jupyter_client pyzmq \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 \
    transformers accelerate \
    numpy pandas matplotlib seaborn \
    opencv-python pillow \
    scikit-learn scipy \
    tqdm

# Puerto ZeroMQ para comunicación con kernel
EXPOSE 5555-5560

# Comando de inicio
CMD ["python", "-m", "ipykernel_launcher", "-f", "/tmp/kernel.json"]
```

---

## Fases de Implementación

### Fase 1: Infraestructura Base
1. Configurar proyecto Spring Boot con Kotlin
2. Implementar WebSocket básico
3. Crear Docker image para kernel Python
4. Comunicación básica Kotlin <-> Python kernel

### Fase 2: Frontend Notebook
1. Integrar Monaco Editor
2. Componente CodeCell con ejecución
3. OutputRenderer básico (texto/errores)
4. Conexión WebSocket frontend

### Fase 3: Ejecución con GPU
1. nvidia-docker integration
2. GPU monitoring (nvidia-smi)
3. Múltiples kernels simultáneos
4. Gestión de recursos GPU

### Fase 4: Outputs Avanzados
1. Renderizar imágenes (matplotlib, PIL)
2. DataFrames HTML (pandas)
3. Gráficos interactivos
4. Rich output (HTML, SVG)

### Fase 5: Integración AI
1. API Gateway para AI providers
2. Claude API integration
3. OpenAI API integration
4. Google Gemini integration
5. Panel de asistente AI en el notebook

### Fase 6: Persistencia y Features
1. Guardar/cargar notebooks (formato .ipynb compatible)
2. Sistema de archivos del usuario
3. Historial de ejecuciones
4. Variables explorer

### Fase 7: Producción
1. Autenticación y autorización
2. Rate limiting
3. Logging y monitoreo
4. Deploy (Docker Compose / Kubernetes)

---

## Dependencias Clave

### build.gradle.kts (Backend)
```kotlin
dependencies {
    // Spring Boot
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-websocket")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")

    // Kotlin
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-reactor")

    // ZeroMQ para comunicación con Jupyter kernels
    implementation("org.zeromq:jeromq:0.5.3")

    // Docker
    implementation("com.github.docker-java:docker-java:3.3.4")

    // JSON
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin")

    // AI APIs
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // Database
    runtimeOnly("org.postgresql:postgresql")
    implementation("redis.clients:jedis:5.1.0")
}
```

### package.json (Frontend - nuevas dependencias)
```json
{
  "dependencies": {
    "@monaco-editor/react": "^4.6.0",
    "xterm": "^5.3.0",
    "xterm-addon-fit": "^0.8.0",
    "socket.io-client": "^4.7.2",
    "zustand": "^4.4.7",
    "react-markdown": "^9.0.1",
    "react-syntax-highlighter": "^15.5.0"
  }
}
```

---

## Seguridad Importante

1. **Aislamiento de Kernels**: Cada kernel en contenedor Docker separado
2. **Límites de recursos**: CPU, memoria, tiempo de ejecución
3. **Sin acceso a red desde kernel** (opcional, configurable)
4. **Sandboxing de archivos**: Solo acceso a workspace del usuario
5. **Rate limiting**: Límite de ejecuciones por minuto
6. **Validación de código**: Detectar patrones peligrosos (opcional)

---

## Preguntas para Definir Alcance

1. **¿Usuarios múltiples?** ¿Sistema multi-tenant con autenticación?
2. **¿GPU compartida o dedicada?** ¿Cómo distribuir recursos GPU entre usuarios?
3. **¿Formato de notebooks?** ¿Compatible con .ipynb de Jupyter?
4. **¿Colaboración?** ¿Notebooks compartidos entre usuarios?
5. **¿Cloud o self-hosted?** ¿Dónde correrá la GPU?
6. **¿Prioridad de AI providers?** ¿Claude primero, OpenAI, Google?

---

## Estimación de Complejidad

| Fase | Complejidad | Componentes Principales |
|------|-------------|------------------------|
| 1. Infraestructura | Alta | Spring Boot, Docker, ZeroMQ |
| 2. Frontend Notebook | Media | Monaco, WebSocket, Cells |
| 3. GPU Execution | Alta | nvidia-docker, monitoring |
| 4. Rich Outputs | Media | Image/HTML rendering |
| 5. AI Integration | Media | REST APIs, streaming |
| 6. Persistencia | Media | PostgreSQL, File system |
| 7. Producción | Alta | Auth, scaling, deploy |

---

## Próximos Pasos Sugeridos

1. **Confirmar stack**: ¿Kotlin/Spring Boot o preferirías otra opción?
2. **Definir MVP**: ¿Qué features son críticos para la primera versión?
3. **Comenzar con Fase 1**: Crear proyecto backend básico
4. **Crear componente NotebookEditor**: Modificar el frontend existente
