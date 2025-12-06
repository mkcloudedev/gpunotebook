import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_colors.dart';
import '../widgets/layout/main_layout.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Settings',
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Settings',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.foreground),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure your notebook environment',
                  style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 32),
                // AI Providers Section
                _SettingsSection(
                  title: 'AI Providers',
                  description: 'Configure API keys for AI assistants',
                  children: [
                    _APIKeyInput(
                      label: 'Claude (Anthropic)',
                      value: _claudeKey,
                      placeholder: 'sk-ant-...',
                      onChanged: (value) => setState(() => _claudeKey = value),
                    ),
                    const SizedBox(height: 16),
                    _APIKeyInput(
                      label: 'OpenAI',
                      value: _openaiKey,
                      placeholder: 'sk-...',
                      onChanged: (value) => setState(() => _openaiKey = value),
                    ),
                    const SizedBox(height: 16),
                    _APIKeyInput(
                      label: 'Google Gemini',
                      value: _geminiKey,
                      placeholder: 'AIza...',
                      onChanged: (value) => setState(() => _geminiKey = value),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Editor Section
                _SettingsSection(
                  title: 'Editor',
                  description: 'Customize the code editor',
                  children: [
                    _SettingsSelect(
                      label: 'Theme',
                      value: _theme,
                      options: const [
                        _SelectOption(value: 'dark', label: 'Dark'),
                        _SelectOption(value: 'light', label: 'Light'),
                        _SelectOption(value: 'system', label: 'System'),
                      ],
                      onChanged: (value) => setState(() => _theme = value),
                    ),
                    const SizedBox(height: 16),
                    _SettingsSelect(
                      label: 'Font Size',
                      value: _fontSize,
                      options: const [
                        _SelectOption(value: '12', label: '12px'),
                        _SelectOption(value: '14', label: '14px'),
                        _SelectOption(value: '16', label: '16px'),
                        _SelectOption(value: '18', label: '18px'),
                      ],
                      onChanged: (value) => setState(() => _fontSize = value),
                    ),
                    const SizedBox(height: 16),
                    _SettingsSelect(
                      label: 'Tab Size',
                      value: _tabSize,
                      options: const [
                        _SelectOption(value: '2', label: '2 spaces'),
                        _SelectOption(value: '4', label: '4 spaces'),
                      ],
                      onChanged: (value) => setState(() => _tabSize = value),
                    ),
                    const SizedBox(height: 16),
                    _SettingsToggle(
                      label: 'Auto-save',
                      description: 'Automatically save notebooks',
                      value: _autoSave,
                      onChanged: (value) => setState(() => _autoSave = value),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Kernel Section
                _SettingsSection(
                  title: 'Kernel',
                  description: 'Configure Python kernel settings',
                  children: [
                    _SettingsSelect(
                      label: 'Default Python',
                      value: _defaultPython,
                      options: const [
                        _SelectOption(value: 'python3.11', label: 'Python 3.11'),
                        _SelectOption(value: 'python3.10', label: 'Python 3.10'),
                        _SelectOption(value: 'python3.9', label: 'Python 3.9'),
                      ],
                      onChanged: (value) => setState(() => _defaultPython = value),
                    ),
                    const SizedBox(height: 16),
                    _SettingsSelect(
                      label: 'GPU Memory Limit',
                      value: _gpuMemory,
                      options: const [
                        _SelectOption(value: '50', label: '50%'),
                        _SelectOption(value: '70', label: '70%'),
                        _SelectOption(value: '80', label: '80%'),
                        _SelectOption(value: '90', label: '90%'),
                        _SelectOption(value: '100', label: '100%'),
                      ],
                      onChanged: (value) => setState(() => _gpuMemory = value),
                    ),
                    const SizedBox(height: 16),
                    _SettingsSelect(
                      label: 'Execution Timeout',
                      value: _timeout,
                      options: const [
                        _SelectOption(value: '30', label: '30 seconds'),
                        _SelectOption(value: '60', label: '60 seconds'),
                        _SelectOption(value: '120', label: '2 minutes'),
                        _SelectOption(value: '300', label: '5 minutes'),
                        _SelectOption(value: '600', label: '10 minutes'),
                      ],
                      onChanged: (value) => setState(() => _timeout = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.description,
    required this.children,
  });

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
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
              ],
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _APIKeyInput extends StatefulWidget {
  final String label;
  final String value;
  final String placeholder;
  final Function(String) onChanged;

  const _APIKeyInput({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onChanged,
  });

  @override
  State<_APIKeyInput> createState() => _APIKeyInputState();
}

class _APIKeyInputState extends State<_APIKeyInput> {
  bool _isVisible = false;
  bool _isTesting = false;
  bool? _isValid;

  void _testKey() async {
    if (widget.value.isEmpty) return;
    setState(() => _isTesting = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isTesting = false;
      _isValid = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.foreground)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                obscureText: !_isVisible,
                style: TextStyle(fontSize: 14, color: AppColors.foreground, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: widget.placeholder,
                  hintStyle: TextStyle(color: AppColors.mutedForeground),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => setState(() => _isVisible = !_isVisible),
                        icon: Icon(_isVisible ? LucideIcons.eyeOff : LucideIcons.eye, size: 16),
                        color: AppColors.mutedForeground,
                      ),
                      if (_isValid == true)
                        Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(LucideIcons.checkCircle, size: 16, color: AppColors.success),
                        ),
                    ],
                  ),
                ),
                onChanged: widget.onChanged,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isTesting ? null : _testKey,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.muted,
                foregroundColor: AppColors.foreground,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: Text(_isTesting ? 'Testing...' : 'Test'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SelectOption {
  final String value;
  final String label;

  const _SelectOption({required this.value, required this.label});
}

class _SettingsSelect extends StatelessWidget {
  final String label;
  final String value;
  final List<_SelectOption> options;
  final Function(String) onChanged;

  const _SettingsSelect({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

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
              icon: Icon(LucideIcons.chevronDown, size: 14),
              dropdownColor: AppColors.card,
              style: TextStyle(fontSize: 13, color: AppColors.foreground),
              items: options.map((option) {
                return DropdownMenuItem(value: option.value, child: Text(option.label));
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) onChanged(newValue);
              },
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
  final Function(bool) onChanged;

  const _SettingsToggle({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 14, color: AppColors.foreground)),
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
