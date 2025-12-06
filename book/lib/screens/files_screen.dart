import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_colors.dart';
import '../models/file_info.dart';
import '../widgets/layout/main_layout.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String _currentPath = '/home/user/notebooks';
  final _searchController = TextEditingController();
  FileInfo? _selectedFile;

  final List<FileInfo> _files = [
    FileInfo(
      name: 'notebooks',
      path: '/home/user/notebooks',
      fileType: FileType.directory,
      size: 0,
      modifiedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    FileInfo(
      name: 'data',
      path: '/home/user/data',
      fileType: FileType.directory,
      size: 0,
      modifiedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    FileInfo(
      name: 'models',
      path: '/home/user/models',
      fileType: FileType.directory,
      size: 0,
      modifiedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    FileInfo(
      name: 'analysis.ipynb',
      path: '/home/user/analysis.ipynb',
      fileType: FileType.file,
      size: 45678,
      modifiedAt: DateTime.now().subtract(const Duration(hours: 5)),
      mimeType: 'application/x-ipynb+json',
    ),
    FileInfo(
      name: 'train.py',
      path: '/home/user/train.py',
      fileType: FileType.file,
      size: 12345,
      modifiedAt: DateTime.now().subtract(const Duration(days: 2)),
      mimeType: 'text/x-python',
    ),
    FileInfo(
      name: 'config.json',
      path: '/home/user/config.json',
      fileType: FileType.file,
      size: 2345,
      modifiedAt: DateTime.now().subtract(const Duration(days: 3)),
      mimeType: 'application/json',
    ),
    FileInfo(
      name: 'dataset.csv',
      path: '/home/user/dataset.csv',
      fileType: FileType.file,
      size: 1024000,
      modifiedAt: DateTime.now().subtract(const Duration(days: 7)),
      mimeType: 'text/csv',
    ),
    FileInfo(
      name: 'model_weights.pt',
      path: '/home/user/model_weights.pt',
      fileType: FileType.file,
      size: 536870912,
      modifiedAt: DateTime.now().subtract(const Duration(days: 14)),
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Files',
      actions: [
        ElevatedButton.icon(
          onPressed: _showUploadDialog,
          icon: Icon(LucideIcons.upload, size: 14),
          label: Text('Upload'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.primaryForeground,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () {},
          icon: Icon(LucideIcons.folderPlus, size: 14),
          label: Text('New Folder'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.muted,
            foregroundColor: AppColors.foreground,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ],
      child: Row(
        children: [
          // Main content
          Expanded(
            child: Column(
              children: [
                // Header card
                _buildHeaderCard(),
                // Toolbar
                _buildToolbar(),
                // File list
                Expanded(child: _buildFileList()),
              ],
            ),
          ),
          // Side panel - Storage info
          _buildSidePanel(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
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
                '%files',
                style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.mutedForeground),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File Manager',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.foreground),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_files.length} items • ${_formatSize(_getTotalSize())} used',
                        style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: Icon(LucideIcons.folderPlus, size: 16),
                        label: Text('New Folder'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.foreground,
                          side: BorderSide(color: AppColors.border),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _showUploadDialog,
                        icon: Icon(LucideIcons.upload, size: 16),
                        label: Text('Upload'),
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
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Breadcrumb
          _buildBreadcrumb(),
          const Spacer(),
          // Search
          SizedBox(
            width: 250,
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 13, color: AppColors.foreground),
              decoration: InputDecoration(
                hintText: 'Search files...',
                hintStyle: TextStyle(color: AppColors.mutedForeground),
                prefixIcon: Icon(LucideIcons.search, size: 16, color: AppColors.mutedForeground),
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
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
      ),
    );
  }

  Widget _buildBreadcrumb() {
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _currentPath = '/'),
          child: Icon(LucideIcons.home, size: 16, color: AppColors.primary),
        ),
        ...parts.map((part) => Row(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(LucideIcons.chevronRight, size: 14, color: AppColors.mutedForeground),
                ),
                Text(part, style: TextStyle(fontSize: 13, color: AppColors.foreground)),
              ],
            )),
      ],
    );
  }

  Widget _buildFileList() {
    return Container(
      color: AppColors.card,
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(child: Text('Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                SizedBox(width: 100, child: Text('Size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                SizedBox(width: 100, child: Text('Modified', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground))),
                SizedBox(width: 80),
              ],
            ),
          ),
          // File list
          Expanded(
            child: ListView.builder(
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index];
                return _FileRow(
                  file: file,
                  isSelected: _selectedFile?.path == file.path,
                  onTap: () {
                    if (file.isDirectory) {
                      setState(() => _currentPath = file.path);
                    } else {
                      setState(() => _selectedFile = file);
                    }
                  },
                  onDelete: () => setState(() => _files.removeAt(index)),
                );
              },
            ),
          ),
        ],
      ),
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
                Text('Storage', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.foreground)),
              ],
            ),
          ),
          // Storage info
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Used', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                          Text(_formatSize(_getTotalSize()), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 0.35,
                          backgroundColor: AppColors.muted,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Available', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                          Text('65 GB', style: TextStyle(fontSize: 12, color: AppColors.foreground)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // File type breakdown
                _StorageBreakdown(label: 'Notebooks', size: '12.5 GB', color: AppColors.primary, percent: 0.35),
                _StorageBreakdown(label: 'Models', size: '8.2 GB', color: AppColors.success, percent: 0.23),
                _StorageBreakdown(label: 'Data', size: '5.1 GB', color: AppColors.warning, percent: 0.14),
                _StorageBreakdown(label: 'Other', size: '2.3 GB', color: AppColors.mutedForeground, percent: 0.06),
              ],
            ),
          ),
          const Spacer(),
          // Selected file info
          if (_selectedFile != null)
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
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_getFileIcon(_selectedFile!), size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_selectedFile!.name, style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.foreground), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Size', value: _formatSize(_selectedFile!.size)),
                    _InfoRow(label: 'Modified', value: _formatDate(_selectedFile!.modifiedAt)),
                    _InfoRow(label: 'Type', value: _selectedFile!.mimeType ?? 'Unknown'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _getTotalSize() {
    return _files.fold(0, (sum, file) => sum + file.size);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 1) return 'Just now';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  IconData _getFileIcon(FileInfo file) {
    if (file.isDirectory) return LucideIcons.folder;
    final ext = file.name.split('.').last.toLowerCase();
    switch (ext) {
      case 'ipynb': return LucideIcons.fileCode;
      case 'py': return LucideIcons.fileCode;
      case 'json': return LucideIcons.fileJson;
      case 'csv': return LucideIcons.fileSpreadsheet;
      case 'pt': case 'pth': return LucideIcons.fileBox;
      case 'md': return LucideIcons.fileText;
      default: return LucideIcons.file;
    }
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
        child: Container(
          width: 400,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.uploadCloud, size: 48, color: AppColors.primary.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text('Drop files here or click to upload', style: TextStyle(color: AppColors.mutedForeground)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.primaryForeground),
                    child: Text('Upload'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatefulWidget {
  final FileInfo file;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _FileRow({
    required this.file,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _isHovered = false;

  IconData get _icon {
    if (widget.file.isDirectory) return LucideIcons.folder;
    final ext = widget.file.name.split('.').last.toLowerCase();
    switch (ext) {
      case 'ipynb': return LucideIcons.fileCode;
      case 'py': return LucideIcons.fileCode;
      case 'json': return LucideIcons.fileJson;
      case 'csv': return LucideIcons.fileSpreadsheet;
      case 'pt': case 'pth': return LucideIcons.fileBox;
      default: return LucideIcons.file;
    }
  }

  Color get _iconColor {
    if (widget.file.isDirectory) return const Color(0xFFF59E0B);
    final ext = widget.file.name.split('.').last.toLowerCase();
    switch (ext) {
      case 'ipynb': return const Color(0xFF3B82F6);
      case 'py': return const Color(0xFF10B981);
      case 'json': return const Color(0xFF8B5CF6);
      default: return AppColors.mutedForeground;
    }
  }

  String _formatSize(int bytes) {
    if (widget.file.isDirectory) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}';
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
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected ? AppColors.primary.withOpacity(0.05) : (_isHovered ? AppColors.muted : Colors.transparent),
            border: Border(
              left: BorderSide(color: widget.isSelected ? AppColors.primary : Colors.transparent, width: 2),
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              Icon(_icon, size: 18, color: _iconColor),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.file.name, style: TextStyle(fontSize: 14, color: AppColors.foreground))),
              SizedBox(width: 100, child: Text(_formatSize(widget.file.size), style: TextStyle(fontSize: 13, color: AppColors.mutedForeground))),
              SizedBox(width: 100, child: Text(_formatDate(widget.file.modifiedAt), style: TextStyle(fontSize: 13, color: AppColors.mutedForeground))),
              SizedBox(
                width: 80,
                child: _isHovered
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: Icon(LucideIcons.download, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            color: AppColors.mutedForeground,
                          ),
                          IconButton(
                            onPressed: widget.onDelete,
                            icon: Icon(LucideIcons.trash2, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            color: AppColors.destructive,
                          ),
                        ],
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageBreakdown extends StatelessWidget {
  final String label;
  final String size;
  final Color color;
  final double percent;

  const _StorageBreakdown({
    required this.label,
    required this.size,
    required this.color,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.foreground))),
          Text(size, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          Flexible(child: Text(value, style: TextStyle(fontSize: 12, color: AppColors.foreground), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
