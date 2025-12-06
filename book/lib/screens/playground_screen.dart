import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../widgets/layout/main_layout.dart';
import '../widgets/notebook/code_editor.dart';

class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  String _code = '''import torch
import torch.nn as nn

# Check GPU availability
print(f"CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")

# Create a simple tensor
x = torch.randn(3, 3).cuda()
print(f"Tensor on GPU: {x}")
''';
  String _output = '';
  bool _isRunning = false;
  String _language = 'Python';

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Playground',
      actions: [
        _buildRunButton(),
      ],
      child: Column(
        children: [
          // Header with %playground
          _buildHeader(),
          // Split panels: Editor | Output
          Expanded(
            child: Row(
              children: [
                // Editor panel
                Expanded(child: _buildEditorPanel()),
                // Divider
                Container(width: 1, color: AppColors.border),
                // Output panel
                Expanded(child: _buildOutputPanel()),
              ],
            ),
          ),
          // Footer with quick snippets
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildRunButton() {
    return ElevatedButton.icon(
      onPressed: _isRunning ? null : _runCode,
      icon: Icon(_isRunning ? LucideIcons.loader2 : LucideIcons.play, size: 16),
      label: Text(_isRunning ? 'Running...' : 'Run'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Code block header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.codeBg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
              child: Text(
                '%playground',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Code Playground',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quick code execution with $_language',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Language selector
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(0xFF3572A5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_language, style: TextStyle(fontSize: 14, color: AppColors.foreground)),
                            const SizedBox(width: 8),
                            Icon(LucideIcons.chevronDown, size: 16, color: AppColors.mutedForeground),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isRunning ? null : _runCode,
                        icon: Icon(_isRunning ? LucideIcons.loader2 : LucideIcons.play, size: 16),
                        label: Text(_isRunning ? 'Running...' : 'Run Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorPanel() {
    return Container(
      color: AppColors.codeBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.code2, size: 16, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                Text(
                  'Code',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground),
                ),
                const Spacer(),
                _EditorAction(icon: LucideIcons.copy, onTap: () {}),
                _EditorAction(icon: LucideIcons.eraser, onTap: () => setState(() => _code = '')),
              ],
            ),
          ),
          // Code editor with line numbers
          Expanded(
            child: CodeEditor(
              key: ValueKey(_code.isEmpty ? 'empty' : 'code'),
              initialValue: _code,
              onChanged: (value) => _code = value,
              showLineNumbers: true,
              enableFolding: false,
              enableScroll: true,
              hintText: '# Enter Python code...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputPanel() {
    return Container(
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.terminal, size: 16, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                Text(
                  'Output',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground),
                ),
                if (_output.isNotEmpty) ...[
                  const Spacer(),
                  _EditorAction(icon: LucideIcons.x, onTap: () => setState(() => _output = '')),
                ],
              ],
            ),
          ),
          // Output content
          Expanded(
            child: _output.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.terminal, size: 48, color: AppColors.mutedForeground.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Run your code to see output here',
                          style: TextStyle(color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: SelectableText(_output, style: AppTheme.monoStyle),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Snippets',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SnippetChip(label: 'GPU Info', onTap: () => _insertSnippet('torch.cuda.get_device_properties(0)')),
              _SnippetChip(label: 'Memory Usage', onTap: () => _insertSnippet('torch.cuda.memory_allocated()')),
              _SnippetChip(label: 'Clear Cache', onTap: () => _insertSnippet('torch.cuda.empty_cache()')),
              _SnippetChip(label: 'Random Tensor', onTap: () => _insertSnippet('torch.randn(3, 3).cuda()')),
              _SnippetChip(label: 'Import NumPy', onTap: () => _insertSnippet('import numpy as np')),
              _SnippetChip(label: 'Import Pandas', onTap: () => _insertSnippet('import pandas as pd')),
            ],
          ),
        ],
      ),
    );
  }

  void _insertSnippet(String snippet) {
    setState(() {
      _code = _code + '\n' + snippet;
    });
  }

  void _runCode() {
    setState(() {
      _isRunning = true;
      _output = '';
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _output = '''CUDA available: True
GPU: NVIDIA GeForce RTX 4090

Tensor on GPU: tensor([[ 0.4231, -1.2341,  0.8912],
        [-0.5521,  1.1234, -0.3421],
        [ 0.7812, -0.2134,  0.9123]], device='cuda:0')

Execution completed in 0.234s
Memory used: 245.3 MB''';
        });
      }
    });
  }
}

class _EditorAction extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _EditorAction({required this.icon, required this.onTap});

  @override
  State<_EditorAction> createState() => _EditorActionState();
}

class _EditorActionState extends State<_EditorAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            widget.icon,
            size: 14,
            color: _isHovered ? AppColors.foreground : AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _SnippetChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _SnippetChip({required this.label, required this.onTap});

  @override
  State<_SnippetChip> createState() => _SnippetChipState();
}

class _SnippetChipState extends State<_SnippetChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.primary.withOpacity(0.1) : AppColors.muted,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.border),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              color: _isHovered ? AppColors.primary : AppColors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
