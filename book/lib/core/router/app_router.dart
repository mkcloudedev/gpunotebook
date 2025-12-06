import 'package:flutter/material.dart';
import '../../screens/home_screen.dart';
import '../../screens/notebooks_screen.dart';
import '../../screens/notebook_editor_screen.dart';
import '../../screens/playground_screen.dart';
import '../../screens/ai_assistant_screen.dart';
import '../../screens/gpu_monitor_screen.dart';
import '../../screens/files_screen.dart';
import '../../screens/settings_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String notebooks = '/notebooks';
  static const String notebookEditor = '/notebooks/:id';
  static const String playground = '/playground';
  static const String aiAssistant = '/ai';
  static const String gpuMonitor = '/gpu';
  static const String files = '/files';
  static const String settings = '/settings';
}

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case AppRoutes.notebooks:
        return MaterialPageRoute(builder: (_) => const NotebooksScreen());
      case AppRoutes.playground:
        return MaterialPageRoute(builder: (_) => const PlaygroundScreen());
      case AppRoutes.aiAssistant:
        return MaterialPageRoute(builder: (_) => const AIAssistantScreen());
      case AppRoutes.gpuMonitor:
        return MaterialPageRoute(builder: (_) => const GPUMonitorScreen());
      case AppRoutes.files:
        return MaterialPageRoute(builder: (_) => const FilesScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        if (settings.name?.startsWith('/notebooks/') ?? false) {
          final id = settings.name!.split('/').last;
          return MaterialPageRoute(
            builder: (_) => NotebookEditorScreen(notebookId: id),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}
