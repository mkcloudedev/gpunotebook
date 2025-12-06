import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../models/execution.dart';
import '../../models/notebook.dart';
import '../../services/ai_tools_service.dart';
import '../../services/notebook_service.dart';
import '../../services/file_service.dart';

/// Modal for AI to execute code and actions
class AIActionModal extends StatefulWidget {
  final String? initialCode;
  final AIActionType actionType;
  final Function(AIToolResult)? onResult;
  final Function(String notebookId)? onOpenNotebook;

  const AIActionModal({
    super.key,
    this.initialCode,
    this.actionType = AIActionType.executeCode,
    this.onResult,
    this.onOpenNotebook,
  });

  @override
  State<AIActionModal> createState() => _AIActionModalState();
}

enum AIActionType {
  executeCode,
  createNotebook,
  sendToNotebook,
  trainModel,
}

class _AIActionModalState extends State<AIActionModal> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _datasetController = TextEditingController();
  final _targetController = TextEditingController();

  bool _isExecuting = false;
  AIToolResult? _result;
  List<Notebook> _notebooks = [];
  String? _selectedNotebookId;
  String _selectedModelType = 'random_forest';

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;
    }
    if (widget.actionType == AIActionType.sendToNotebook) {
      _loadNotebooks();
    }
  }

  Future<void> _loadNotebooks() async {
    final notebooks = await notebookService.list();
    if (mounted) {
      setState(() {
        _notebooks = notebooks;
        if (notebooks.isNotEmpty) {
          _selectedNotebookId = notebooks.first.id;
        }
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _datasetController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(child: _buildBody()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final (icon, title) = switch (widget.actionType) {
      AIActionType.executeCode => (LucideIcons.play, 'Execute Code'),
      AIActionType.createNotebook => (LucideIcons.filePlus, 'Create Notebook'),
      AIActionType.sendToNotebook => (LucideIcons.send, 'Send to Notebook'),
      AIActionType.trainModel => (LucideIcons.brain, 'Train Model'),
    };

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground)),
          const Spacer(),
          IconButton(
            icon: Icon(LucideIcons.x, size: 18),
            onPressed: () => Navigator.pop(context),
            color: AppColors.mutedForeground,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          switch (widget.actionType) {
            AIActionType.executeCode => _buildCodeExecutionForm(),
            AIActionType.createNotebook => _buildCreateNotebookForm(),
            AIActionType.sendToNotebook => _buildSendToNotebookForm(),
            AIActionType.trainModel => _buildTrainModelForm(),
          },
          if (_result != null) ...[
            const SizedBox(height: 16),
            _buildResult(),
          ],
        ],
      ),
    );
  }

  Widget _buildCodeExecutionForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Code to Execute', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.mutedForeground)),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _codeController,
            maxLines: null,
            expands: true,
            style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.foreground),
            decoration: InputDecoration(
              hintText: '# Enter Python code...',
              hintStyle: TextStyle(color: AppColors.mutedForeground),
              contentPadding: EdgeInsets.all(12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateNotebookForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notebook Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.mutedForeground)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'My New Notebook',
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Initial Code (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.mutedForeground)),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _codeController,
            maxLines: null,
            expands: true,
            style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.foreground),
            decoration: InputDecoration(
              hintText: '# Initial code for the notebook...',
              hintStyle: TextStyle(color: AppColors.mutedForeground),
              contentPadding: EdgeInsets.all(12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSendToNotebookForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Notebook', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.mutedForeground)),
        const SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedNotebookId,
              isExpanded: true,
              dropdownColor: AppColors.card,
              hint: Text('Select a notebook...'),
              items: _notebooks.map((n) => DropdownMenuItem(
                value: n.id,
                child: Text(n.name, style: TextStyle(color: AppColors.foreground)),
              )).toList(),
              onChanged: (value) => setState(() => _selectedNotebookId = value),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Code to Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.mutedForeground)),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _codeController,
            maxLines: null,
            expands: true,
            style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.foreground),
            decoration: InputDecoration(
              hintText: '# Code to add to the notebook...',
              hintStyle: TextStyle(color: AppColors.mutedForeground),
              contentPadding: EdgeInsets.all(12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrainModelForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Model Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.mutedForeground)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildModelChip('random_forest', 'Random Forest', LucideIcons.trees),
            _buildModelChip('xgboost', 'XGBoost', LucideIcons.zap),
            _buildModelChip('neural_network', 'Neural Network', LucideIcons.brain),
            _buildModelChip('logistic', 'Logistic Regression', LucideIcons.trendingUp),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dataset Path', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.mutedForeground)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _datasetController,
                          decoration: InputDecoration(
                            hintText: '/path/to/dataset.csv',
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(LucideIcons.folderOpen),
                        onPressed: _browseForDataset,
                        tooltip: 'Browse files',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Target Column', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.mutedForeground)),
        const SizedBox(height: 8),
        TextField(
          controller: _targetController,
          decoration: InputDecoration(
            hintText: 'e.g., target, label, class',
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
          ),
        ),
      ],
    );
  }

  Widget _buildModelChip(String value, String label, IconData icon) {
    final isSelected = _selectedModelType == value;
    return InkWell(
      onTap: () => setState(() => _selectedModelType = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.mutedForeground),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, color: isSelected ? AppColors.primary : AppColors.foreground)),
          ],
        ),
      ),
    );
  }

  void _browseForDataset() async {
    final files = await fileService.list('');
    if (!mounted) return;

    // Show file picker dialog
    showDialog(
      context: context,
      builder: (context) => _FileBrowserDialog(
        onSelect: (path) {
          setState(() => _datasetController.text = path);
        },
      ),
    );
  }

  Widget _buildResult() {
    final result = _result!;
    final isSuccess = result.success;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess ? AppColors.success.withOpacity(0.1) : AppColors.destructive.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSuccess ? AppColors.success : AppColors.destructive),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSuccess ? LucideIcons.checkCircle : LucideIcons.xCircle,
                size: 16,
                color: isSuccess ? AppColors.success : AppColors.destructive,
              ),
              const SizedBox(width: 8),
              Text(
                isSuccess ? 'Success' : 'Error',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSuccess ? AppColors.success : AppColors.destructive,
                ),
              ),
            ],
          ),
          if (result.message != null) ...[
            const SizedBox(height: 8),
            Text(result.message!, style: TextStyle(fontSize: 13, color: AppColors.foreground)),
          ],
          if (result.error != null) ...[
            const SizedBox(height: 8),
            Text(result.error!, style: TextStyle(fontSize: 13, color: AppColors.destructive)),
          ],
          if (result.outputs != null && result.outputs!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Output:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.mutedForeground)),
            const SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(4),
              ),
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: result.outputs!.map((output) {
                    return Text(
                      output.text ?? output.data?.toString() ?? '',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.foreground),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
          if (result.data != null && result.data!['notebook_id'] != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onOpenNotebook?.call(result.data!['notebook_id']);
              },
              icon: Icon(LucideIcons.externalLink, size: 16),
              label: Text('Open Notebook'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isExecuting ? null : _executeAction,
            icon: _isExecuting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_getActionIcon(), size: 16),
            label: Text(_getActionLabel()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryForeground,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon() {
    return switch (widget.actionType) {
      AIActionType.executeCode => LucideIcons.play,
      AIActionType.createNotebook => LucideIcons.plus,
      AIActionType.sendToNotebook => LucideIcons.send,
      AIActionType.trainModel => LucideIcons.play,
    };
  }

  String _getActionLabel() {
    return switch (widget.actionType) {
      AIActionType.executeCode => 'Execute',
      AIActionType.createNotebook => 'Create',
      AIActionType.sendToNotebook => 'Send',
      AIActionType.trainModel => 'Train',
    };
  }

  Future<void> _executeAction() async {
    setState(() {
      _isExecuting = true;
      _result = null;
    });

    try {
      final result = await switch (widget.actionType) {
        AIActionType.executeCode => aiToolsService.executeCode(_codeController.text),
        AIActionType.createNotebook => aiToolsService.createNotebook(
            _nameController.text.isEmpty ? 'AI Generated Notebook' : _nameController.text,
            initialCells: _codeController.text.isNotEmpty ? [_codeController.text] : null,
          ),
        AIActionType.sendToNotebook => _selectedNotebookId != null
            ? aiToolsService.addCellToNotebook(_selectedNotebookId!, _codeController.text)
            : Future.value(AIToolResult(tool: AIToolType.addCellToNotebook, success: false, error: 'No notebook selected')),
        AIActionType.trainModel => aiToolsService.trainModel(
            modelType: _selectedModelType,
            datasetPath: _datasetController.text,
            targetColumn: _targetController.text,
          ),
      };

      if (mounted) {
        setState(() {
          _result = result;
          _isExecuting = false;
        });
        widget.onResult?.call(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = AIToolResult(
            tool: AIToolType.executeCode,
            success: false,
            error: e.toString(),
          );
          _isExecuting = false;
        });
      }
    }
  }
}

/// Simple file browser dialog
class _FileBrowserDialog extends StatefulWidget {
  final Function(String) onSelect;

  const _FileBrowserDialog({required this.onSelect});

  @override
  State<_FileBrowserDialog> createState() => _FileBrowserDialogState();
}

class _FileBrowserDialogState extends State<_FileBrowserDialog> {
  String _currentPath = '';
  List<FileItem> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles('');
  }

  Future<void> _loadFiles(String path) async {
    setState(() => _loading = true);
    final files = await fileService.list(path);
    if (mounted) {
      setState(() {
        _files = files;
        _currentPath = path;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        height: 400,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Select Dataset', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: Icon(LucideIcons.x, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (_currentPath.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  final parts = _currentPath.split('/');
                  parts.removeLast();
                  _loadFiles(parts.join('/'));
                },
                child: Row(
                  children: [
                    Icon(LucideIcons.arrowLeft, size: 16),
                    SizedBox(width: 8),
                    Text('Back', style: TextStyle(color: AppColors.primary)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _files.length,
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        final isDataFile = !file.isDirectory &&
                            (file.name.endsWith('.csv') ||
                             file.name.endsWith('.parquet') ||
                             file.name.endsWith('.xlsx'));

                        return ListTile(
                          leading: Icon(
                            file.isDirectory ? LucideIcons.folder : LucideIcons.file,
                            color: file.isDirectory ? Colors.amber : (isDataFile ? AppColors.primary : AppColors.mutedForeground),
                          ),
                          title: Text(file.name),
                          trailing: isDataFile ? Icon(LucideIcons.check, color: AppColors.success) : null,
                          onTap: () {
                            if (file.isDirectory) {
                              _loadFiles(file.path);
                            } else if (isDataFile) {
                              widget.onSelect(file.path);
                              Navigator.pop(context);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
