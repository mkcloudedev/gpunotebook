# GPU Notebook - Frontend

Flutter web application for GPU Notebook.

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run in Chrome
flutter run -d chrome

# Build for production
flutter build web
```

## Project Structure

```
book/
├── lib/
│   ├── screens/           # Application screens
│   │   ├── shell_screen.dart
│   │   ├── content/
│   │   │   ├── dashboard_content.dart
│   │   │   ├── notebook_editor_content.dart
│   │   │   ├── playground_content.dart
│   │   │   ├── gpu_monitor_content.dart
│   │   │   └── ai_assistant_content.dart
│   ├── widgets/           # Reusable components
│   │   ├── notebook/
│   │   ├── gpu/
│   │   ├── ai/
│   │   └── layout/
│   ├── services/          # API services
│   │   ├── api_client.dart
│   │   ├── notebook_service.dart
│   │   ├── kernel_service.dart
│   │   └── ai_service.dart
│   ├── models/            # Data models
│   ├── core/
│   │   ├── theme/        # App theme
│   │   └── router/       # Navigation
│   └── main.dart
├── pubspec.yaml
└── web/
```

## Configuration

Update the API base URL in `lib/services/api_client.dart`:

```dart
class ApiClient {
  static const baseUrl = 'http://localhost:8000';
  // ...
}
```

## Features

- **Notebook Editor** - Create and edit notebooks with code cells
- **Code Editor** - Syntax highlighting, code folding, autocomplete
- **AI Assistant** - Chat with AI for code help
- **GPU Monitor** - Real-time GPU metrics
- **Playground** - Quick code execution
- **File Manager** - Upload and manage files
- **Package Manager** - Install Python packages

## Key Dependencies

- `http` - HTTP client
- `web_socket_channel` - WebSocket support
- `google_fonts` - Typography
- `lucide_icons` - Icon set
- `file_picker` - File selection

## Development

```bash
# Hot reload
flutter run -d chrome

# Analyze code
flutter analyze

# Run tests
flutter test
```
