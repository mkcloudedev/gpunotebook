import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_colors.dart';
import '../models/notebook.dart';
import '../models/cell.dart';
import '../widgets/layout/main_layout.dart';
import '../widgets/notebooks/notebook_card.dart';
import '../widgets/notebooks/create_notebook_dialog.dart';

class NotebooksScreen extends StatefulWidget {
  const NotebooksScreen({super.key});

  @override
  State<NotebooksScreen> createState() => _NotebooksScreenState();
}

class _NotebooksScreenState extends State<NotebooksScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _createOpen = false;

  final List<Notebook> _notebooks = [
    Notebook(
      id: '1',
      name: 'Image Detection Model',
      cells: List.generate(15, (i) => Cell(id: '$i', cellType: CellType.code, source: '')),
      kernelId: 'kernel-1',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Notebook(
      id: '2',
      name: 'DINOv2 Fine-tuning',
      cells: List.generate(23, (i) => Cell(id: '$i', cellType: CellType.code, source: '')),
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Notebook(
      id: '3',
      name: 'Data Preprocessing Pipeline',
      cells: List.generate(8, (i) => Cell(id: '$i', cellType: CellType.code, source: '')),
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Notebook(
      id: '4',
      name: 'Model Evaluation Metrics',
      cells: List.generate(12, (i) => Cell(id: '$i', cellType: CellType.code, source: '')),
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  List<Notebook> get _filteredNotebooks {
    if (_searchQuery.isEmpty) return _notebooks;
    return _notebooks
        .where((n) => n.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Notebooks',
      actions: [
        ElevatedButton.icon(
          onPressed: () => setState(() => _createOpen = true),
          icon: Icon(LucideIcons.plus, size: 16),
          label: Text('New Notebook'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.primaryForeground,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ],
      child: Row(
        children: [
          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card with %notebooks
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  // Search & Filters
                  _buildSearchFilters(),
                  const SizedBox(height: 16),
                  // Notebooks List
                  _buildNotebooksList(),
                ],
              ),
            ),
          ),
          // Side Panel
          _buildSidePanel(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
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
              '%notebooks',
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
                      'Your Notebooks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_notebooks.length} notebooks • Python 3.11',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: Icon(LucideIcons.upload, size: 16),
                      label: Text('Import'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.foreground,
                        side: BorderSide(color: AppColors.border),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _createOpen = true),
                      icon: Icon(LucideIcons.plus, size: 16),
                      label: Text('New'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryForeground,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilters() {
    return Row(
      children: [
        // Search input
        Expanded(
          child: TextField(
            controller: _searchController,
            style: TextStyle(fontSize: 14, color: AppColors.foreground),
            decoration: InputDecoration(
              hintText: 'Search notebooks...',
              hintStyle: TextStyle(color: AppColors.mutedForeground),
              prefixIcon: Icon(LucideIcons.search, size: 18, color: AppColors.mutedForeground),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primary),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        const SizedBox(width: 12),
        // Filter button
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            onPressed: () {},
            icon: Icon(LucideIcons.filter, size: 18),
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(width: 8),
        // View toggle
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {},
                icon: Icon(LucideIcons.list, size: 18),
                color: AppColors.foreground,
                style: IconButton.styleFrom(backgroundColor: AppColors.secondary),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(LucideIcons.layoutGrid, size: 18),
                color: AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotebooksList() {
    if (_filteredNotebooks.isEmpty) {
      return Container(
        padding: EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(LucideIcons.fileCode, size: 48, color: AppColors.mutedForeground),
            const SizedBox(height: 16),
            Text(
              'No notebooks found',
              style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.foreground),
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isEmpty ? 'Create your first notebook to get started' : 'Try a different search term',
              style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => setState(() => _createOpen = true),
                icon: Icon(LucideIcons.plus, size: 16),
                label: Text('New Notebook'),
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

    return Column(
      children: _filteredNotebooks.map((notebook) {
        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _NotebookRow(
            notebook: notebook,
            onTap: () => Navigator.pushNamed(context, '/notebooks/${notebook.id}'),
            onDuplicate: () => _duplicateNotebook(notebook),
            onDelete: () => _deleteNotebook(notebook),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSidePanel() {
    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  'Quick Actions',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.foreground),
                ),
              ],
            ),
          ),
          // Quick action buttons
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                _QuickActionButton(
                  icon: LucideIcons.plus,
                  iconColor: AppColors.primary,
                  title: 'New Notebook',
                  description: 'Create a blank notebook',
                  onTap: () => setState(() => _createOpen = true),
                ),
                const SizedBox(height: 8),
                _QuickActionButton(
                  icon: LucideIcons.upload,
                  iconColor: AppColors.success,
                  title: 'Import .ipynb',
                  description: 'Upload Jupyter notebook',
                  onTap: () {},
                ),
                const SizedBox(height: 8),
                _QuickActionButton(
                  icon: LucideIcons.fileCode,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'From Template',
                  description: 'ML, Data Science, etc.',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const Spacer(),
          // Kernel Status
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kernel Status',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.foreground),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Python 3.11', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text('Ready', style: TextStyle(fontSize: 12, color: AppColors.success)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                      Text('2 kernels', style: TextStyle(fontSize: 12, color: AppColors.foreground)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _duplicateNotebook(Notebook notebook) {
    setState(() {
      _notebooks.insert(
        0,
        Notebook(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: '${notebook.name} (Copy)',
          cells: notebook.cells,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    });
  }

  void _deleteNotebook(Notebook notebook) {
    setState(() {
      _notebooks.removeWhere((n) => n.id == notebook.id);
    });
  }
}

class _NotebookRow extends StatefulWidget {
  final Notebook notebook;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _NotebookRow({
    required this.notebook,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  State<_NotebookRow> createState() => _NotebookRowState();
}

class _NotebookRowState extends State<_NotebookRow> {
  bool _isHovered = false;

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 1) return 'Just now';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(LucideIcons.fileCode, size: 20, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.notebook.name,
                      style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.foreground),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text('Python', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                        const SizedBox(width: 12),
                        Text('${widget.notebook.cells.length} cells', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                        const SizedBox(width: 12),
                        Icon(LucideIcons.clock, size: 12, color: AppColors.mutedForeground),
                        const SizedBox(width: 4),
                        Text(_formatDate(widget.notebook.updatedAt), style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(LucideIcons.moreVertical, size: 18, color: AppColors.mutedForeground),
                color: AppColors.card,
                onSelected: (value) {
                  if (value == 'duplicate') widget.onDuplicate();
                  if (value == 'delete') widget.onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'run', child: Row(children: [Icon(LucideIcons.play, size: 16), SizedBox(width: 8), Text('Run All')])),
                  PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(LucideIcons.copy, size: 16), SizedBox(width: 8), Text('Duplicate')])),
                  PopupMenuItem(value: 'delete', child: Row(children: [Icon(LucideIcons.trash2, size: 16, color: AppColors.destructive), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppColors.destructive))])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
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
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, size: 16, color: widget.iconColor),
                  const SizedBox(width: 8),
                  Text(widget.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                ],
              ),
              const SizedBox(height: 4),
              Text(widget.description, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }
}
