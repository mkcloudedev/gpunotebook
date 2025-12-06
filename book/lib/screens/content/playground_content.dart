import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/kernel_service.dart';
import '../../services/execution_service.dart';
import '../../models/kernel.dart';
import '../../models/execution.dart';
import '../../widgets/notebook/code_editor.dart';

class PlaygroundContent extends StatefulWidget {
  final Kernel? kernel;
  final Future<Kernel?> Function()? onKernelNeeded;

  const PlaygroundContent({
    super.key,
    this.kernel,
    this.onKernelNeeded,
  });

  @override
  State<PlaygroundContent> createState() => PlaygroundContentState();
}

class PlaygroundContentState extends State<PlaygroundContent> {
  final _codeController = TextEditingController(text: '''import torch
import torch.nn as nn

# Check GPU availability
print(f"CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")

# Create a simple tensor
x = torch.randn(3, 3).cuda()
print(f"Tensor on GPU: {x}")
''');

  String _output = '';
  bool _isExecuting = false;
  ExecutionService? _executionService;
  String? _connectedKernelId;

  // Public methods for external access (breadcrumb buttons)
  void runCode() => _executeCode();
  void clearOutput() => setState(() => _output = '');
  void clearCode() => _codeController.clear();
  void copyCode() {
    final code = _codeController.text;
    if (code.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: code));
    }
  }
  Future<void> stopExecution() async {
    if (!_isExecuting) return;
    try {
      if (widget.kernel != null) {
        await kernelService.interrupt(widget.kernel!.id);
      }
      setState(() => _isExecuting = false);
    } catch (e) {
      setState(() => _isExecuting = false);
    }
  }
  bool get isExecuting => _isExecuting;

  @override
  void initState() {
    super.initState();
    _connectToKernel();
  }

  @override
  void didUpdateWidget(PlaygroundContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reconnect if kernel changed
    if (widget.kernel?.id != oldWidget.kernel?.id) {
      _connectToKernel();
    }
  }

  Future<void> _connectToKernel() async {
    Kernel? kernel = widget.kernel;

    // If no kernel provided, try to get one via callback
    if (kernel == null && widget.onKernelNeeded != null) {
      kernel = await widget.onKernelNeeded!();
    }

    if (kernel == null) return;
    if (_connectedKernelId == kernel.id) return;

    try {
      _executionService?.disconnectFromKernel();
      _executionService = ExecutionService();
      await _executionService!.connectToKernel(kernel.id);
      _connectedKernelId = kernel.id;
      print('Connected to kernel: ${kernel.id}');
    } catch (e) {
      print('Error connecting to kernel: $e');
    }
  }

  Future<void> _executeCode() async {
    if (_isExecuting) return;

    setState(() {
      _isExecuting = true;
      _output = '';
    });

    // Ensure we have a kernel
    Kernel? kernel = widget.kernel;
    if (kernel == null && widget.onKernelNeeded != null) {
      kernel = await widget.onKernelNeeded!();
    }

    // Connect to kernel if needed
    if (kernel != null && _connectedKernelId != kernel.id) {
      try {
        _executionService?.disconnectFromKernel();
        _executionService = ExecutionService();
        await _executionService!.connectToKernel(kernel.id);
        _connectedKernelId = kernel.id;
      } catch (e) {
        setState(() {
          _output = 'Error connecting to kernel: $e';
          _isExecuting = false;
        });
        return;
      }
    }

    if (_executionService != null && kernel != null) {
      try {
        final request = ExecutionRequest(
          kernelId: kernel.id,
          code: _codeController.text,
          cellId: 'playground',
        );
        final result = await _executionService!.execute(request);
        setState(() {
          _output = result.outputs.map((o) => o.text ?? '').join('\n');
          if (result.error != null) {
            _output += '\n${result.error}';
          }
          _isExecuting = false;
        });
      } catch (e) {
        setState(() {
          _output = 'Error: $e';
          _isExecuting = false;
        });
      }
    } else {
      setState(() {
        _output = 'No kernel available. Select a kernel from the dropdown above or check backend connection.';
        _isExecuting = false;
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _executionService?.disconnectFromKernel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Editor + Output panels
        Expanded(
          child: Row(
            children: [
              // Code Editor with syntax highlighting
              Expanded(
                child: Container(
                  color: AppColors.codeBg,
                  child: CodeEditor(
                    initialValue: _codeController.text,
                    onChanged: (code) => _codeController.text = code,
                    showLineNumbers: true,
                    enableFolding: true,
                    kernelId: widget.kernel?.id,
                  ),
                ),
              ),
              Container(width: 1, color: AppColors.border),
              // Output
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: AppColors.card,
                  child: _isExecuting
                      ? Center(child: CircularProgressIndicator())
                      : _output.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.terminal, size: 40, color: AppColors.mutedForeground.withOpacity(0.3)),
                                  const SizedBox(height: 12),
                                  Text('Run code to see output', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              padding: EdgeInsets.all(16),
                              child: SelectableText(_output, style: AppTheme.monoStyle),
                            ),
                ),
              ),
            ],
          ),
        ),
        // Footer - Quick Snippets
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Text('Snippets:', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _SnippetChip(label: 'GPU Info', onTap: () => _insertSnippet('torch.cuda.get_device_properties(0)')),
                      const SizedBox(width: 8),
                      _SnippetChip(label: 'Memory', onTap: () => _insertSnippet('torch.cuda.memory_allocated()')),
                      const SizedBox(width: 8),
                      _SnippetChip(label: 'Clear Cache', onTap: () => _insertSnippet('torch.cuda.empty_cache()')),
                      const SizedBox(width: 8),
                      _SnippetChip(label: 'Tensor', onTap: () => _insertSnippet('torch.randn(3, 3).cuda()')),
                      const SizedBox(width: 8),
                      _SnippetChip(label: 'NumPy', onTap: () => _insertSnippet('import numpy as np')),
                      const SizedBox(width: 8),
                      _SnippetChip(label: 'Pandas', onTap: () => _insertSnippet('import pandas as pd')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _insertSnippet(String snippet) {
    final text = _codeController.text;
    final selection = _codeController.selection;
    final newText = text.replaceRange(selection.start, selection.end, snippet);
    _codeController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + snippet.length),
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
          child: Text(widget.label, style: TextStyle(fontSize: 11, color: _isHovered ? AppColors.primary : AppColors.foreground)),
        ),
      ),
    );
  }
}
