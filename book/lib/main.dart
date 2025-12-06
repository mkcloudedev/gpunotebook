import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'screens/shell_screen.dart';
import 'services/gpu_history_service.dart';
import 'services/keyboard_shortcuts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path URL strategy (no hash in URLs)
  usePathUrlStrategy();

  // Suppress trackpad assertion error in Flutter Web debug mode
  FlutterError.onError = (details) {
    if (details.toString().contains('trackpad')) return;
    FlutterError.presentError(details);
  };

  // Initialize keyboard shortcuts
  await keyboardShortcutsService.init();

  // Start GPU history collection on app start
  gpuHistoryService.startAutoRefresh();

  runApp(const GPUNotebookApp());
}

class GPUNotebookApp extends StatefulWidget {
  const GPUNotebookApp({super.key});

  @override
  State<GPUNotebookApp> createState() => _GPUNotebookAppState();
}

class _GPUNotebookAppState extends State<GPUNotebookApp> {
  @override
  void initState() {
    super.initState();
    // Listen to theme changes
    themeProvider.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      themeProvider: themeProvider,
      child: MaterialApp(
        title: 'GPU Notebook',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        initialRoute: '/',
        onGenerateRoute: (settings) {
          // Parse the route
          final uri = Uri.parse(settings.name ?? '/');
          final path = uri.path;

          // Extract notebook ID if present
          String? notebookId;
          if (path.startsWith('/notebook/')) {
            notebookId = path.substring('/notebook/'.length);
          }

          // Map path to page index
          int pageIndex = 0;
          switch (path) {
            case '/':
            case '/home':
              pageIndex = 0;
              break;
            case '/notebooks':
              pageIndex = 1;
              break;
            case '/playground':
              pageIndex = 2;
              break;
            case '/ai':
              pageIndex = 3;
              break;
            case '/automl':
              pageIndex = 4;
              break;
            case '/gpu':
              pageIndex = 5;
              break;
            case '/files':
              pageIndex = 6;
              break;
            case '/kaggle':
              pageIndex = 7;
              break;
            case '/cluster':
              pageIndex = 8;
              break;
            case '/settings':
              pageIndex = 9;
              break;
            case '/help':
              pageIndex = 10;
              break;
            default:
              if (path.startsWith('/notebook/')) {
                pageIndex = 1; // Notebooks page but with editor open
              }
          }

          return MaterialPageRoute(
            settings: settings,
            builder: (context) => ShellScreen(
              initialPageIndex: pageIndex,
              initialNotebookId: notebookId,
            ),
          );
        },
      ),
    );
  }
}
