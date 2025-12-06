import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../services/settings_service.dart';
import '../../services/kaggle_service.dart';

class SettingsContent extends StatefulWidget {
  const SettingsContent({super.key});

  @override
  State<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<SettingsContent> {
  String _claudeKey = '';
  String _openaiKey = '';
  String _geminiKey = '';

  String _theme = 'dark';
  String _fontSize = '14';
  String _tabSize = '4';
  bool _autoSave = true;

  String _defaultPython = 'python3.11';
  String _gpuMemory = '80';
  String _timeout = '60';

  // Kaggle credentials
  String _kaggleUsername = '';
  String _kaggleKey = '';
  bool _kaggleConfigured = false;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadKaggleStatus();
  }

  Future<void> _loadSettings() async {
    final settings = await settingsService.get();
    if (mounted) {
      setState(() {
        _claudeKey = settings.claudeKey ?? '';
        _openaiKey = settings.openaiKey ?? '';
        _geminiKey = settings.geminiKey ?? '';
        _theme = settings.theme;
        _fontSize = settings.fontSize;
        _tabSize = settings.tabSize;
        _autoSave = settings.autoSave;
        _defaultPython = settings.defaultPython;
        _gpuMemory = settings.gpuMemory;
        _timeout = settings.timeout;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadKaggleStatus() async {
    final status = await kaggleService.getStatus();
    if (mounted) {
      setState(() {
        _kaggleConfigured = status.configured;
        if (status.username != null) {
          _kaggleUsername = status.username!;
        }
      });
    }
  }

  Future<void> _saveSettings() async {
    final settings = AppSettings(
      claudeKey: _claudeKey.isNotEmpty ? _claudeKey : null,
      openaiKey: _openaiKey.isNotEmpty ? _openaiKey : null,
      geminiKey: _geminiKey.isNotEmpty ? _geminiKey : null,
      theme: _theme,
      fontSize: _fontSize,
      tabSize: _tabSize,
      autoSave: _autoSave,
      defaultPython: _defaultPython,
      gpuMemory: _gpuMemory,
      timeout: _timeout,
    );
    final success = await settingsService.save(settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Settings saved successfully' : 'Failed to save settings'),
          backgroundColor: success ? AppColors.success : AppColors.destructive,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First row: AI Providers, Editor, Kernel
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildAIProvidersSection()),
                const SizedBox(width: 16),
                Expanded(child: _buildEditorSection()),
                const SizedBox(width: 16),
                Expanded(child: _buildKernelSection()),
              ],
            ),
            const SizedBox(height: 16),
            // Second row: Kaggle
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildKaggleSection()),
                const SizedBox(width: 16),
                Expanded(child: SizedBox()),
                const SizedBox(width: 16),
                Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIProvidersSection() {
    return _SettingsSection(
      title: 'AI Providers',
      description: 'Configure API keys for AI assistants',
      children: [
        _APIKeyInput(label: 'Claude (Anthropic)', provider: 'claude', value: _claudeKey, placeholder: 'sk-ant-...', onChanged: (v) => setState(() => _claudeKey = v)),
        const SizedBox(height: 16),
        _APIKeyInput(label: 'OpenAI', provider: 'openai', value: _openaiKey, placeholder: 'sk-...', onChanged: (v) => setState(() => _openaiKey = v)),
        const SizedBox(height: 16),
        _APIKeyInput(label: 'Google Gemini', provider: 'gemini', value: _geminiKey, placeholder: 'AIza...', onChanged: (v) => setState(() => _geminiKey = v)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: Icon(LucideIcons.save, size: 16),
            label: Text('Save API Keys'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryForeground,
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditorSection() {
    return _SettingsSection(
      title: 'Editor',
      description: 'Customize the code editor',
      children: [
        _SettingsSelect(
          label: 'Theme',
          value: _theme,
          options: const [
            _SelectOption('dark', 'Dark'),
            _SelectOption('light', 'Light'),
            _SelectOption('system', 'System'),
          ],
          onChanged: (v) { setState(() => _theme = v); _saveSettings(); },
        ),
        const SizedBox(height: 16),
        _SettingsSelect(
          label: 'Font Size',
          value: _fontSize,
          options: const [
            _SelectOption('12', '12px'),
            _SelectOption('14', '14px'),
            _SelectOption('16', '16px'),
            _SelectOption('18', '18px'),
          ],
          onChanged: (v) { setState(() => _fontSize = v); _saveSettings(); },
        ),
        const SizedBox(height: 16),
        _SettingsSelect(
          label: 'Tab Size',
          value: _tabSize,
          options: const [
            _SelectOption('2', '2 spaces'),
            _SelectOption('4', '4 spaces'),
          ],
          onChanged: (v) { setState(() => _tabSize = v); _saveSettings(); },
        ),
        const SizedBox(height: 16),
        _SettingsToggle(
          label: 'Auto-save',
          description: 'Automatically save notebooks',
          value: _autoSave,
          onChanged: (v) { setState(() => _autoSave = v); _saveSettings(); },
        ),
      ],
    );
  }

  Widget _buildKernelSection() {
    return _SettingsSection(
      title: 'Kernel',
      description: 'Configure Python kernel settings',
      children: [
        _SettingsSelect(
          label: 'Default Python',
          value: _defaultPython,
          options: const [
            _SelectOption('python3.11', 'Python 3.11'),
            _SelectOption('python3.10', 'Python 3.10'),
            _SelectOption('python3.9', 'Python 3.9'),
          ],
          onChanged: (v) { setState(() => _defaultPython = v); _saveSettings(); },
        ),
        const SizedBox(height: 16),
        _SettingsSelect(
          label: 'GPU Memory Limit',
          value: _gpuMemory,
          options: const [
            _SelectOption('50', '50%'),
            _SelectOption('70', '70%'),
            _SelectOption('80', '80%'),
            _SelectOption('90', '90%'),
            _SelectOption('100', '100%'),
          ],
          onChanged: (v) { setState(() => _gpuMemory = v); _saveSettings(); },
        ),
        const SizedBox(height: 16),
        _SettingsSelect(
          label: 'Execution Timeout',
          value: _timeout,
          options: const [
            _SelectOption('30', '30 seconds'),
            _SelectOption('60', '60 seconds'),
            _SelectOption('120', '2 minutes'),
            _SelectOption('300', '5 minutes'),
            _SelectOption('600', '10 minutes'),
          ],
          onChanged: (v) { setState(() => _timeout = v); _saveSettings(); },
        ),
      ],
    );
  }

  Widget _buildKaggleSection() {
    return _SettingsSection(
      title: 'Kaggle',
      description: 'Configure Kaggle API credentials',
      children: [
        // Status indicator
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kaggleConfigured
                ? AppColors.success.withOpacity(0.1)
                : AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _kaggleConfigured
                  ? AppColors.success.withOpacity(0.3)
                  : AppColors.warning.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _kaggleConfigured ? LucideIcons.checkCircle : LucideIcons.alertCircle,
                size: 16,
                color: _kaggleConfigured ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _kaggleConfigured ? 'Connected' : 'Not configured',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _kaggleConfigured ? AppColors.success : AppColors.warning,
                      ),
                    ),
                    if (_kaggleConfigured && _kaggleUsername.isNotEmpty)
                      Text(
                        'Username: $_kaggleUsername',
                        style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Username input
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Username', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _kaggleUsername),
              onChanged: (v) => _kaggleUsername = v,
              style: TextStyle(fontSize: 14, color: AppColors.foreground),
              decoration: InputDecoration(
                hintText: 'Your Kaggle username',
                hintStyle: TextStyle(color: AppColors.mutedForeground),
                filled: true,
                fillColor: AppColors.background,
                prefixIcon: Icon(LucideIcons.user, size: 16, color: AppColors.mutedForeground),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primary)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // API Key input
        _KaggleKeyInput(
          value: _kaggleKey,
          onChanged: (v) => setState(() => _kaggleKey = v),
        ),
        const SizedBox(height: 24),
        // Save button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveKaggleCredentials,
            icon: Icon(LucideIcons.save, size: 16),
            label: Text('Save Kaggle Credentials'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20BEFF),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Help link
        Center(
          child: TextButton.icon(
            onPressed: () {},
            icon: Icon(LucideIcons.externalLink, size: 14),
            label: Text('Get your API key from kaggle.com/settings'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.mutedForeground,
              textStyle: TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveKaggleCredentials() async {
    if (_kaggleUsername.isEmpty || _kaggleKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both username and API key'),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    final success = await kaggleService.setCredentials(_kaggleUsername, _kaggleKey);
    if (mounted) {
      if (success) {
        setState(() {
          _kaggleConfigured = true;
          _kaggleKey = ''; // Clear the key after saving
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kaggle credentials saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save Kaggle credentials'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.description, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }
}

class _APIKeyInput extends StatefulWidget {
  final String label;
  final String provider;
  final String value;
  final String placeholder;
  final ValueChanged<String> onChanged;

  const _APIKeyInput({required this.label, required this.provider, required this.value, required this.placeholder, required this.onChanged});

  @override
  State<_APIKeyInput> createState() => _APIKeyInputState();
}

class _APIKeyInputState extends State<_APIKeyInput> {
  late TextEditingController _controller;
  bool _obscured = true;
  bool _testing = false;
  bool? _testResult;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_APIKeyInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testKey() async {
    final key = _controller.text;
    if (key.isEmpty) return;

    setState(() { _testing = true; _testResult = null; _testMessage = null; });

    try {
      final result = await settingsService.testApiKey(widget.provider, key);
      if (mounted) {
        setState(() {
          _testing = false;
          _testResult = result;
          _testMessage = result ? 'Valid' : 'Invalid key';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _testResult = false;
          _testMessage = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
            if (_testResult != null) ...[
              const SizedBox(width: 8),
              Icon(
                _testResult! ? LucideIcons.checkCircle : LucideIcons.xCircle,
                size: 14,
                color: _testResult! ? AppColors.success : AppColors.destructive,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                obscureText: _obscured,
                onChanged: widget.onChanged,
                style: TextStyle(fontSize: 14, color: AppColors.foreground),
                decoration: InputDecoration(
                  hintText: widget.placeholder,
                  hintStyle: TextStyle(color: AppColors.mutedForeground),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primary)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: IconButton(
                    icon: Icon(_obscured ? LucideIcons.eye : LucideIcons.eyeOff, size: 16, color: AppColors.mutedForeground),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _testing ? null : _testKey,
              style: ElevatedButton.styleFrom(
                backgroundColor: _testResult == true ? AppColors.success : AppColors.muted,
                foregroundColor: _testResult == true ? Colors.white : AppColors.foreground,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: _testing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_testResult == true ? 'Valid' : 'Test'),
            ),
          ],
        ),
        if (_testMessage != null && _testResult == false) ...[
          const SizedBox(height: 4),
          Text(_testMessage!, style: TextStyle(fontSize: 12, color: AppColors.destructive)),
        ],
      ],
    );
  }
}

class _SelectOption {
  final String value;
  final String label;

  const _SelectOption(this.value, this.label);
}

class _SettingsSelect extends StatelessWidget {
  final String label;
  final String value;
  final List<_SelectOption> options;
  final ValueChanged<String> onChanged;

  const _SettingsSelect({required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: AppColors.foreground)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: AppColors.card,
              style: TextStyle(fontSize: 14, color: AppColors.foreground),
              items: options.map((opt) => DropdownMenuItem(value: opt.value, child: Text(opt.label))).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({required this.label, required this.description, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 14, color: AppColors.foreground)),
            const SizedBox(height: 2),
            Text(description, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ],
    );
  }
}

class _KaggleKeyInput extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _KaggleKeyInput({required this.value, required this.onChanged});

  @override
  State<_KaggleKeyInput> createState() => _KaggleKeyInputState();
}

class _KaggleKeyInputState extends State<_KaggleKeyInput> {
  late TextEditingController _controller;
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_KaggleKeyInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('API Key', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          obscureText: _obscured,
          onChanged: widget.onChanged,
          style: TextStyle(fontSize: 14, color: AppColors.foreground),
          decoration: InputDecoration(
            hintText: 'Your Kaggle API key',
            hintStyle: TextStyle(color: AppColors.mutedForeground),
            filled: true,
            fillColor: AppColors.background,
            prefixIcon: Icon(LucideIcons.key, size: 16, color: AppColors.mutedForeground),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primary)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: IconButton(
              icon: Icon(_obscured ? LucideIcons.eye : LucideIcons.eyeOff, size: 16, color: AppColors.mutedForeground),
              onPressed: () => setState(() => _obscured = !_obscured),
            ),
          ),
        ),
      ],
    );
  }
}
