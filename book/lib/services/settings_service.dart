import 'api_client.dart';

class AppSettings {
  final String? claudeKey;
  final String? openaiKey;
  final String? geminiKey;
  final String theme;
  final String fontSize;
  final String tabSize;
  final bool autoSave;
  final String defaultPython;
  final String gpuMemory;
  final String timeout;

  AppSettings({
    this.claudeKey,
    this.openaiKey,
    this.geminiKey,
    this.theme = 'dark',
    this.fontSize = '14',
    this.tabSize = '4',
    this.autoSave = true,
    this.defaultPython = 'python3.11',
    this.gpuMemory = '80',
    this.timeout = '60',
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      claudeKey: json['claude_key'] as String?,
      openaiKey: json['openai_key'] as String?,
      geminiKey: json['gemini_key'] as String?,
      theme: json['theme'] as String? ?? 'dark',
      fontSize: json['font_size'] as String? ?? '14',
      tabSize: json['tab_size'] as String? ?? '4',
      autoSave: json['auto_save'] as bool? ?? true,
      defaultPython: json['default_python'] as String? ?? 'python3.11',
      gpuMemory: json['gpu_memory'] as String? ?? '80',
      timeout: json['timeout'] as String? ?? '60',
    );
  }

  Map<String, dynamic> toJson() => {
    if (claudeKey != null) 'claude_key': claudeKey,
    if (openaiKey != null) 'openai_key': openaiKey,
    if (geminiKey != null) 'gemini_key': geminiKey,
    'theme': theme,
    'font_size': fontSize,
    'tab_size': tabSize,
    'auto_save': autoSave,
    'default_python': defaultPython,
    'gpu_memory': gpuMemory,
    'timeout': timeout,
  };
}

class SettingsService {
  final ApiClient _api;

  SettingsService({ApiClient? api}) : _api = api ?? apiClient;

  Future<AppSettings> get() async {
    try {
      final response = await _api.get('/api/settings');
      return AppSettings.fromJson(response);
    } catch (e) {
      return AppSettings();
    }
  }

  Future<bool> save(AppSettings settings) async {
    try {
      await _api.put('/api/settings', settings.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> testApiKey(String provider, String key) async {
    try {
      final response = await _api.post('/api/settings/test-key', {
        'provider': provider,
        'key': key,
      });
      return response['valid'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }
}

final settingsService = SettingsService();
