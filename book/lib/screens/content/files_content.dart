import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../services/file_service.dart';
import '../../services/api_client.dart';

class FilesContent extends StatefulWidget {
  final VoidCallback? onNewFolder;
  final VoidCallback? onUpload;

  const FilesContent({super.key, this.onNewFolder, this.onUpload});

  @override
  State<FilesContent> createState() => FilesContentState();
}

class FilesContentState extends State<FilesContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _currentPath = [];
  List<FileItem> _files = [];
  StorageInfo? _storageInfo;
  bool _isLoading = true;

  // Datasets state
  List<DatasetInfo> _datasets = [];
  bool _isLoadingDatasets = true;

  String get currentPath => _currentPath.isEmpty ? '' : _currentPath.join('/');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChange);
    _loadFiles();
    _loadDatasets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChange() {
    if (_tabController.index == 1 && _datasets.isEmpty) {
      _loadDatasets();
    }
  }

  void createNewFolder() {
    _showNewFolderDialog();
  }

  void uploadFiles() {
    if (_tabController.index == 0) {
      _pickAndUploadFiles();
    } else {
      _showUploadDatasetDialog();
    }
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final path = _currentPath.isEmpty ? '' : _currentPath.join('/');
      final results = await Future.wait([
        fileService.list(path),
        fileService.getStorageInfo(),
      ]);
      if (mounted) {
        setState(() {
          _files = results[0] as List<FileItem>;
          _storageInfo = results[1] as StorageInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _files = [];
          _isLoading = false;
        });
      }
    }
  }

  FileType _getFileType(FileItem file) {
    if (file.isDirectory) return FileType.directory;
    final ext = file.name.split('.').last.toLowerCase();
    switch (ext) {
      case 'py': return FileType.python;
      case 'png': case 'jpg': case 'jpeg': case 'gif': case 'webp': return FileType.image;
      case 'csv': case 'json': case 'xlsx': case 'parquet': return FileType.data;
      default: return FileType.other;
    }
  }

  Future<void> _loadDatasets() async {
    setState(() => _isLoadingDatasets = true);
    try {
      // Load datasets from files (CSV, Parquet, Excel)
      final allFiles = await fileService.list('');
      final datasets = <DatasetInfo>[];

      Future<void> scanDirectory(String path) async {
        final files = await fileService.list(path);
        for (final file in files) {
          if (file.isDirectory) {
            await scanDirectory(file.path);
          } else {
            final ext = file.name.split('.').last.toLowerCase();
            if (['csv', 'parquet', 'xlsx', 'xls', 'json'].contains(ext)) {
              datasets.add(DatasetInfo(
                name: file.name,
                path: file.path,
                size: file.size,
                format: ext.toUpperCase(),
                modifiedAt: file.modifiedAt,
              ));
            }
          }
        }
      }

      await scanDirectory('');

      if (mounted) {
        setState(() {
          _datasets = datasets;
          _isLoadingDatasets = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _datasets = [];
          _isLoadingDatasets = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.mutedForeground,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.folder, size: 16),
                    SizedBox(width: 8),
                    Text('Files'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.database, size: 16),
                    SizedBox(width: 8),
                    Text('Datasets'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFilesTab(),
              _buildDatasetsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilesTab() {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFileBreadcrumb(),
                        const SizedBox(height: 16),
                        _buildFileGrid(),
                      ],
                    ),
                  ),
          ),
        ),
        _buildSidePanel(),
      ],
    );
  }

  Widget _buildDatasetsTab() {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: _isLoadingDatasets
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDatasetActions(),
                        const SizedBox(height: 16),
                        _buildDatasetsList(),
                      ],
                    ),
                  ),
          ),
        ),
        _buildDatasetSidePanel(),
      ],
    );
  }

  Widget _buildDatasetActions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _DatasetActionCard(
          icon: LucideIcons.upload,
          label: 'Upload Dataset',
          description: 'Import CSV, Excel, Parquet',
          color: AppColors.primary,
          onTap: _showUploadDatasetDialog,
        ),
        _DatasetActionCard(
          icon: LucideIcons.filePlus,
          label: 'Create Dataset',
          description: 'New empty dataset',
          color: AppColors.success,
          onTap: _showCreateDatasetDialog,
        ),
        _DatasetActionCard(
          icon: LucideIcons.sparkles,
          label: 'Clean Data',
          description: 'Remove duplicates, nulls',
          color: Colors.orange,
          onTap: _showCleanDataDialog,
        ),
        _DatasetActionCard(
          icon: LucideIcons.globe,
          label: 'Web Scraping',
          description: 'Extract data from web',
          color: Colors.purple,
          onTap: _showWebScrapingDialog,
        ),
      ],
    );
  }

  Widget _buildDatasetsList() {
    if (_datasets.isEmpty) {
      return Container(
        padding: EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(LucideIcons.database, size: 48, color: AppColors.mutedForeground.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No datasets yet', style: TextStyle(fontSize: 16, color: AppColors.mutedForeground)),
            const SizedBox(height: 8),
            Text('Upload or create a dataset to get started', style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_datasets.length} Datasets', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground)),
        const SizedBox(height: 12),
        ..._datasets.map((dataset) => _DatasetRow(
          dataset: dataset,
          onPreview: () => _previewDataset(dataset),
          onClean: () => _showCleanDataDialog(dataset: dataset),
          onDelete: () => _deleteDataset(dataset),
        )),
      ],
    );
  }

  Widget _buildDatasetSidePanel() {
    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(children: [Text('Dataset Tools', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.foreground))]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildToolCard(LucideIcons.filter, 'Filter & Transform', 'Apply transformations', _showFilterDialog),
                  const SizedBox(height: 8),
                  _buildToolCard(LucideIcons.split, 'Train/Test Split', 'Split for ML', _showSplitDialog),
                  const SizedBox(height: 8),
                  _buildToolCard(LucideIcons.combine, 'Merge Datasets', 'Join multiple files', _showMergeDialog),
                  const SizedBox(height: 8),
                  _buildToolCard(LucideIcons.fileDown, 'Export', 'Download processed data', _showExportDialog),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Data Quality', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                const SizedBox(height: 8),
                _buildQualityMetric('Total Datasets', '${_datasets.length}', AppColors.primary),
                const SizedBox(height: 4),
                _buildQualityMetric('Total Size', _formatTotalSize(), Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    if (_datasets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No datasets available'), backgroundColor: Colors.orange),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        datasets: _datasets,
        onFilter: (path, outputName, columns, filterExpr, sortBy, ascending, limit) async {
          try {
            await apiClient.post('/api/datasets/filter', {
              'path': path,
              'output_name': outputName,
              if (columns != null && columns.isNotEmpty) 'columns': columns,
              if (filterExpr != null && filterExpr.isNotEmpty) 'filter_expr': filterExpr,
              if (sortBy != null && sortBy.isNotEmpty) 'sort_by': sortBy,
              'ascending': ascending,
              if (limit != null) 'limit': limit,
            });
            _loadDatasets();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dataset filtered successfully!'), backgroundColor: Colors.green),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  void _showSplitDialog() {
    if (_datasets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No datasets available'), backgroundColor: Colors.orange),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => _SplitDialog(
        datasets: _datasets,
        onSplit: (path, trainRatio, shuffle) async {
          try {
            await apiClient.post('/api/datasets/split', {
              'path': path,
              'train_ratio': trainRatio,
              'shuffle': shuffle,
            });
            _loadDatasets();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dataset split successfully!'), backgroundColor: Colors.green),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  void _showMergeDialog() {
    if (_datasets.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 datasets to merge'), backgroundColor: Colors.orange),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => _MergeDialog(
        datasets: _datasets,
        onMerge: (paths, outputName, mergeType, joinColumn) async {
          try {
            await apiClient.post('/api/datasets/merge', {
              'paths': paths,
              'output_name': outputName,
              'merge_type': mergeType,
              if (joinColumn != null && joinColumn.isNotEmpty) 'join_column': joinColumn,
            });
            _loadDatasets();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Datasets merged successfully!'), backgroundColor: Colors.green),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  void _showExportDialog() {
    if (_datasets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No datasets available'), backgroundColor: Colors.orange),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => _ExportDialog(
        datasets: _datasets,
        onExport: (path, format) async {
          try {
            final result = await apiClient.post('/api/datasets/export', {
              'path': path,
              'format': format,
            });
            _loadDatasets();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Exported to ${result['output_path']}'), backgroundColor: Colors.green),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildToolCard(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 14, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityMetric(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  String _formatTotalSize() {
    final total = _datasets.fold<int>(0, (sum, d) => sum + d.size);
    if (total < 1024) return '$total B';
    if (total < 1024 * 1024) return '${(total / 1024).toStringAsFixed(1)} KB';
    if (total < 1024 * 1024 * 1024) return '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(total / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _showUploadDatasetDialog() {
    final input = html.FileUploadInputElement()
      ..accept = '.csv,.xlsx,.xls,.parquet,.json'
      ..multiple = true;
    input.click();

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) return;

      for (final file in files) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);

        await reader.onLoadEnd.first;
        final data = reader.result as Uint8List;

        await fileService.uploadFile(file.name, data, 'datasets');
      }
      _loadDatasets();
    });
  }

  void _showCreateDatasetDialog() {
    final nameController = TextEditingController();
    final columnsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Create Dataset', style: TextStyle(color: AppColors.foreground)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Dataset Name',
                  hintText: 'my_dataset.csv',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: columnsController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Columns (comma-separated)',
                  hintText: 'id, name, age, email',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && columnsController.text.isNotEmpty) {
                Navigator.pop(context);
                await _createEmptyDataset(nameController.text, columnsController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createEmptyDataset(String name, String columnsStr) async {
    final columns = columnsStr.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    final csvContent = '${columns.join(',')}\n';
    final bytes = Uint8List.fromList(csvContent.codeUnits);

    final fileName = name.endsWith('.csv') ? name : '$name.csv';
    await fileService.uploadFile(fileName, bytes, 'datasets');
    _loadDatasets();
  }

  void _showCleanDataDialog({DatasetInfo? dataset}) {
    showDialog(
      context: context,
      builder: (context) => _CleanDataDialog(
        datasets: _datasets,
        selectedDataset: dataset,
        onClean: (ds, options) => _cleanDataset(ds, options),
      ),
    );
  }

  Future<void> _cleanDataset(DatasetInfo dataset, Map<String, bool> options) async {
    try {
      await apiClient.post('/api/datasets/clean', {
        'path': dataset.path,
        'remove_duplicates': options['duplicates'] ?? false,
        'remove_nulls': options['nulls'] ?? false,
        'trim_whitespace': options['whitespace'] ?? false,
        'normalize_case': options['normalize'] ?? false,
      });
      _loadDatasets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cleaning data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showWebScrapingDialog() {
    showDialog(
      context: context,
      builder: (context) => _WebScrapingDialog(
        onScrape: (url, selector, name) => _scrapeWebData(url, selector, name),
      ),
    );
  }

  Future<void> _scrapeWebData(String url, String selector, String name) async {
    try {
      await apiClient.post('/api/datasets/scrape', {
        'url': url,
        'selector': selector,
        'output_name': name,
      });
      _loadDatasets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Web scraping completed!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scraping: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _previewDataset(DatasetInfo dataset) {
    showDialog(
      context: context,
      builder: (context) => _DatasetPreviewDialog(dataset: dataset),
    );
  }

  Future<void> _deleteDataset(DatasetInfo dataset) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Delete Dataset?', style: TextStyle(color: AppColors.foreground)),
        content: Text('Are you sure you want to delete "${dataset.name}"?', style: TextStyle(color: AppColors.foreground)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await fileService.delete(dataset.path);
      _loadDatasets();
    }
  }

  Widget _buildFileBreadcrumb() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _currentPath.clear()),
          child: Row(
            children: [
              Icon(LucideIcons.folder, size: 16, color: _currentPath.isEmpty ? AppColors.foreground : AppColors.mutedForeground),
              const SizedBox(width: 4),
              Text('workspace', style: TextStyle(fontSize: 14, fontWeight: _currentPath.isEmpty ? FontWeight.w500 : FontWeight.normal, color: _currentPath.isEmpty ? AppColors.foreground : AppColors.mutedForeground)),
            ],
          ),
        ),
        ..._currentPath.asMap().entries.map((entry) {
          final isLast = entry.key == _currentPath.length - 1;
          return Row(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(LucideIcons.chevronRight, size: 16, color: AppColors.mutedForeground),
              ),
              GestureDetector(
                onTap: () => setState(() => _currentPath.removeRange(entry.key + 1, _currentPath.length)),
                child: Text(entry.value, style: TextStyle(fontSize: 14, fontWeight: isLast ? FontWeight.w500 : FontWeight.normal, color: isLast ? AppColors.foreground : AppColors.mutedForeground)),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildFileGrid() {
    if (_files.isEmpty) {
      return Container(
        padding: EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.folderOpen, size: 48, color: AppColors.mutedForeground.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No files yet', style: TextStyle(fontSize: 16, color: AppColors.mutedForeground)),
            const SizedBox(height: 8),
            Text('Upload files to get started', style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _files.map((file) => SizedBox(
            width: (constraints.maxWidth - 12 * (crossAxisCount - 1)) / crossAxisCount,
            child: _FileRow(
              file: file,
              fileType: _getFileType(file),
              onTap: () {
                if (file.isDirectory) {
                  setState(() => _currentPath.add(file.name));
                  _loadFiles();
                }
              },
              onDelete: () => _deleteFile(file),
            ),
          )).toList(),
        );
      },
    );
  }

  Future<void> _deleteFile(FileItem file) async {
    final success = await fileService.delete(file.path);
    if (success) {
      _loadFiles();
    }
  }

  void _showNewFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('New Folder', style: TextStyle(color: AppColors.foreground)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppColors.foreground),
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: TextStyle(color: AppColors.mutedForeground),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primary)),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(context);
              _createFolder(value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                _createFolder(controller.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder(String name) async {
    final path = _currentPath.isEmpty ? name : '${_currentPath.join('/')}/$name';
    final success = await fileService.createDirectory(path);
    if (success) {
      _loadFiles();
    }
  }

  Future<void> _pickAndUploadFiles() async {
    final input = html.FileUploadInputElement()..multiple = true;
    input.click();

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) return;

      for (final file in files) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);

        await reader.onLoadEnd.first;
        final data = reader.result as Uint8List;

        await fileService.uploadFile(
          file.name,
          data,
          currentPath,
        );
      }
      _loadFiles();
    });
  }

  Widget _buildSidePanel() {
    return Container(
      width: 288,
      decoration: BoxDecoration(color: AppColors.card, border: Border(left: BorderSide(color: AppColors.border))),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(children: [Text('Storage', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.foreground))]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStorageCard(),
                  const SizedBox(height: 16),
                  _buildQuickUpload(),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: _buildFileTypesCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageCard() {
    final usedGB = _storageInfo?.usedGB ?? 2.4;
    final totalGB = _storageInfo?.totalGB ?? 50;
    final percent = _storageInfo?.percent ?? 4.8;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Icon(LucideIcons.hardDrive, size: 20, color: Color(0xFF60A5FA)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Workspace', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                  Text('Local storage', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Used', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
              Text('${usedGB.toStringAsFixed(1)} GB / ${totalGB.toStringAsFixed(0)} GB', style: TextStyle(fontSize: 12, color: AppColors.foreground)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: AppColors.muted,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Upload', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 2, style: BorderStyle.solid),
          ),
          child: Column(
            children: [
              Icon(LucideIcons.upload, size: 24, color: AppColors.mutedForeground),
              const SizedBox(height: 8),
              Text('Drop files here or click to upload', style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFileTypesCard() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('File Types', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.foreground)),
          const SizedBox(height: 8),
          _buildFileTypeRow(LucideIcons.fileCode, 'Python', '2 files', const Color(0xFF60A5FA)),
          const SizedBox(height: 4),
          _buildFileTypeRow(LucideIcons.fileImage, 'Images', '1 file', const Color(0xFFC084FC)),
          const SizedBox(height: 4),
          _buildFileTypeRow(LucideIcons.fileText, 'Data', '1 file', const Color(0xFF4ADE80)),
        ],
      ),
    );
  }

  Widget _buildFileTypeRow(IconData icon, String label, String count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          ],
        ),
        Text(count, style: TextStyle(fontSize: 12, color: AppColors.foreground)),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes == 0) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}

enum FileType { directory, python, image, data, other }

class _FileRow extends StatefulWidget {
  final FileItem file;
  final FileType fileType;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _FileRow({required this.file, required this.fileType, required this.onTap, required this.onDelete});

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
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
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(8)),
                child: Icon(_getFileIcon(), size: 20, color: _getFileColor()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.file.name, style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.foreground)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(_formatSize(widget.file.size), style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                        const SizedBox(width: 12),
                        Icon(LucideIcons.clock, size: 12, color: AppColors.mutedForeground),
                        const SizedBox(width: 4),
                        Text(_formatDate(widget.file.modifiedAt), style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(LucideIcons.moreVertical, size: 16, color: AppColors.mutedForeground),
                onSelected: (value) {
                  if (value == 'delete') widget.onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'preview', child: Row(children: [Icon(LucideIcons.eye, size: 16), SizedBox(width: 8), Text('Preview')])),
                  PopupMenuItem(value: 'download', child: Row(children: [Icon(LucideIcons.download, size: 16), SizedBox(width: 8), Text('Download')])),
                  PopupMenuItem(value: 'delete', child: Row(children: [Icon(LucideIcons.trash2, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon() {
    switch (widget.fileType) {
      case FileType.directory: return LucideIcons.folder;
      case FileType.python: return LucideIcons.fileCode;
      case FileType.image: return LucideIcons.fileImage;
      case FileType.data: return LucideIcons.fileText;
      case FileType.other: return LucideIcons.file;
    }
  }

  Color _getFileColor() {
    switch (widget.fileType) {
      case FileType.directory: return const Color(0xFFFACC15);
      case FileType.python: return const Color(0xFF60A5FA);
      case FileType.image: return const Color(0xFFC084FC);
      case FileType.data: return const Color(0xFF4ADE80);
      case FileType.other: return AppColors.mutedForeground;
    }
  }

  String _formatSize(int bytes) {
    if (bytes == 0) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 1) return 'Just now';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ============================================================================
// DATASET MODELS & WIDGETS
// ============================================================================

class DatasetInfo {
  final String name;
  final String path;
  final int size;
  final String format;
  final DateTime modifiedAt;
  final int? rows;
  final int? columns;

  DatasetInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.format,
    required this.modifiedAt,
    this.rows,
    this.columns,
  });
}

class _DatasetActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _DatasetActionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  State<_DatasetActionCard> createState() => _DatasetActionCardState();
}

class _DatasetActionCardState extends State<_DatasetActionCard> {
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
          width: 180,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered ? widget.color.withOpacity(0.1) : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _isHovered ? widget.color : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, size: 20, color: widget.color),
              ),
              const SizedBox(height: 12),
              Text(widget.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground)),
              const SizedBox(height: 4),
              Text(widget.description, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatasetRow extends StatefulWidget {
  final DatasetInfo dataset;
  final VoidCallback onPreview;
  final VoidCallback onClean;
  final VoidCallback onDelete;

  const _DatasetRow({
    required this.dataset,
    required this.onPreview,
    required this.onClean,
    required this.onDelete,
  });

  @override
  State<_DatasetRow> createState() => _DatasetRowState();
}

class _DatasetRowState extends State<_DatasetRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getFormatColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(LucideIcons.fileSpreadsheet, size: 18, color: _getFormatColor()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.dataset.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _buildChip(widget.dataset.format, _getFormatColor()),
                      const SizedBox(width: 8),
                      Text(_formatSize(widget.dataset.size), style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                    ],
                  ),
                ],
              ),
            ),
            if (_isHovered) ...[
              IconButton(
                icon: Icon(LucideIcons.eye, size: 16),
                onPressed: widget.onPreview,
                tooltip: 'Preview',
                color: AppColors.mutedForeground,
              ),
              IconButton(
                icon: Icon(LucideIcons.sparkles, size: 16),
                onPressed: widget.onClean,
                tooltip: 'Clean',
                color: Colors.orange,
              ),
              IconButton(
                icon: Icon(LucideIcons.trash2, size: 16),
                onPressed: widget.onDelete,
                tooltip: 'Delete',
                color: Colors.red,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color)),
    );
  }

  Color _getFormatColor() {
    switch (widget.dataset.format.toUpperCase()) {
      case 'CSV': return Colors.green;
      case 'XLSX': case 'XLS': return Colors.blue;
      case 'JSON': return Colors.orange;
      case 'PARQUET': return Colors.purple;
      default: return AppColors.mutedForeground;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _CleanDataDialog extends StatefulWidget {
  final List<DatasetInfo> datasets;
  final DatasetInfo? selectedDataset;
  final Function(DatasetInfo, Map<String, bool>) onClean;

  const _CleanDataDialog({
    required this.datasets,
    this.selectedDataset,
    required this.onClean,
  });

  @override
  State<_CleanDataDialog> createState() => _CleanDataDialogState();
}

class _CleanDataDialogState extends State<_CleanDataDialog> {
  late DatasetInfo? _selected;
  bool _removeDuplicates = true;
  bool _removeNulls = true;
  bool _trimWhitespace = true;
  bool _normalizeCase = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedDataset ?? (widget.datasets.isNotEmpty ? widget.datasets.first : null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Row(
        children: [
          Icon(LucideIcons.sparkles, size: 20, color: Colors.orange),
          const SizedBox(width: 8),
          Text('Clean Dataset', style: TextStyle(color: AppColors.foreground)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Dataset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.mutedForeground)),
            const SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DatasetInfo>(
                  isExpanded: true,
                  value: _selected,
                  dropdownColor: AppColors.card,
                  items: widget.datasets.map((d) => DropdownMenuItem(
                    value: d,
                    child: Text(d.name, style: TextStyle(color: AppColors.foreground)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selected = v),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Cleaning Options', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.mutedForeground)),
            const SizedBox(height: 8),
            _buildOption('Remove duplicate rows', _removeDuplicates, (v) => setState(() => _removeDuplicates = v)),
            _buildOption('Remove rows with null values', _removeNulls, (v) => setState(() => _removeNulls = v)),
            _buildOption('Trim whitespace', _trimWhitespace, (v) => setState(() => _trimWhitespace = v)),
            _buildOption('Normalize text to lowercase', _normalizeCase, (v) => setState(() => _normalizeCase = v)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: _selected != null ? () {
            Navigator.pop(context);
            widget.onClean(_selected!, {
              'duplicates': _removeDuplicates,
              'nulls': _removeNulls,
              'whitespace': _trimWhitespace,
              'normalize': _normalizeCase,
            });
          } : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: Text('Clean Data'),
        ),
      ],
    );
  }

  Widget _buildOption(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: Colors.orange,
          ),
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.foreground)),
        ],
      ),
    );
  }
}

class _WebScrapingDialog extends StatefulWidget {
  final Function(String url, String selector, String name) onScrape;

  const _WebScrapingDialog({required this.onScrape});

  @override
  State<_WebScrapingDialog> createState() => _WebScrapingDialogState();
}

class _WebScrapingDialogState extends State<_WebScrapingDialog> {
  final _urlController = TextEditingController();
  final _selectorController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _useAI = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Row(
        children: [
          Icon(LucideIcons.globe, size: 20, color: Colors.purple),
          const SizedBox(width: 8),
          Text('AI Web Scraping', style: TextStyle(color: AppColors.foreground)),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.sparkles, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('AI Agent', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.withOpacity(0.1), AppColors.primary.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.brain, size: 18, color: Colors.purple),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI Agent analyzes the page and extracts data automatically. No selector needed!',
                      style: TextStyle(fontSize: 12, color: AppColors.foreground),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com/data',
                prefixIcon: Icon(LucideIcons.link, size: 18),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _useAI,
                  onChanged: (v) => setState(() => _useAI = v ?? true),
                  activeColor: AppColors.primary,
                ),
                Text('Use AI Agent', style: TextStyle(fontSize: 13, color: AppColors.foreground)),
                const Spacer(),
                if (!_useAI) Text('(Manual mode)', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
              ],
            ),
            if (!_useAI) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _selectorController,
                decoration: InputDecoration(
                  labelText: 'CSS Selector',
                  hintText: 'table, .data-table, #results',
                  prefixIcon: Icon(LucideIcons.code, size: 18),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Output File Name',
                hintText: 'scraped_data.csv',
                prefixIcon: Icon(LucideIcons.file, size: 18),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _useAI
                          ? 'AI will analyze page structure, identify data patterns, and extract content intelligently.'
                          : 'Manual mode: specify CSS selector to target specific elements.',
                      style: TextStyle(fontSize: 12, color: AppColors.foreground),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : () {
            if (_urlController.text.isNotEmpty && _nameController.text.isNotEmpty) {
              Navigator.pop(context);
              widget.onScrape(
                _urlController.text,
                _useAI ? '' : _selectorController.text,
                _nameController.text,
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_useAI) ...[
                      Icon(LucideIcons.sparkles, size: 14),
                      const SizedBox(width: 6),
                    ],
                    Text('Start Scraping'),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DatasetPreviewDialog extends StatefulWidget {
  final DatasetInfo dataset;

  const _DatasetPreviewDialog({required this.dataset});

  @override
  State<_DatasetPreviewDialog> createState() => _DatasetPreviewDialogState();
}

class _DatasetPreviewDialogState extends State<_DatasetPreviewDialog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rows = [];
  List<String> _headers = [];
  int _totalRows = 0;
  int _totalColumns = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final response = await apiClient.get('/api/datasets/preview/${widget.dataset.path}?limit=50');
      _headers = List<String>.from(response['columns'] ?? []);
      _rows = List<Map<String, dynamic>>.from(response['rows'] ?? []);
      _totalRows = response['total_rows'] ?? 0;
      _totalColumns = response['total_columns'] ?? 0;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      child: Container(
        width: 800,
        height: 500,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.eye, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Preview: ${widget.dataset.name}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                const Spacer(),
                IconButton(
                  icon: Icon(LucideIcons.x, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(color: AppColors.border),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error: $_error', style: TextStyle(color: Colors.red)))
                      : _rows.isEmpty
                          ? Center(child: Text('No data to preview', style: TextStyle(color: AppColors.mutedForeground)))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(AppColors.muted),
                                  columns: _headers.map((h) => DataColumn(
                                    label: Text(h, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.foreground)),
                                  )).toList(),
                                  rows: _rows.map((row) => DataRow(
                                    cells: _headers.map((h) => DataCell(
                                      Text('${row[h] ?? ''}', style: TextStyle(fontSize: 12, color: AppColors.foreground)),
                                    )).toList(),
                                  )).toList(),
                                ),
                              ),
                            ),
            ),
            const SizedBox(height: 8),
            Text('Showing ${_rows.length} of $_totalRows rows ($_totalColumns columns)', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DATASET TOOLS DIALOGS
// ============================================================================

class _FilterDialog extends StatefulWidget {
  final List<DatasetInfo> datasets;
  final Function(String path, String outputName, List<String>? columns, String? filterExpr, String? sortBy, bool ascending, int? limit) onFilter;

  const _FilterDialog({required this.datasets, required this.onFilter});

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late DatasetInfo _selected;
  final _outputController = TextEditingController();
  final _filterController = TextEditingController();
  final _sortController = TextEditingController();
  final _limitController = TextEditingController();
  bool _ascending = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.datasets.first;
    _outputController.text = '${_selected.name.split('.').first}_filtered';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Row(
        children: [
          Icon(LucideIcons.filter, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('Filter & Transform', style: TextStyle(color: AppColors.foreground)),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dataset', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            const SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DatasetInfo>(
                  isExpanded: true,
                  value: _selected,
                  dropdownColor: AppColors.card,
                  items: widget.datasets.map((d) => DropdownMenuItem(
                    value: d,
                    child: Text(d.name, style: TextStyle(color: AppColors.foreground)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selected = v!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _outputController,
              decoration: InputDecoration(
                labelText: 'Output Name',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _filterController,
              decoration: InputDecoration(
                labelText: 'Filter Expression (optional)',
                hintText: 'e.g., age > 18 and status == "active"',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sortController,
                    decoration: InputDecoration(
                      labelText: 'Sort By Column',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Text('Order', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                    Switch(
                      value: _ascending,
                      onChanged: (v) => setState(() => _ascending = v),
                      activeColor: AppColors.primary,
                    ),
                    Text(_ascending ? 'Asc' : 'Desc', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _limitController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Limit Rows (optional)',
                hintText: 'Leave empty for all',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onFilter(
              _selected.path,
              _outputController.text,
              null,
              _filterController.text.isEmpty ? null : _filterController.text,
              _sortController.text.isEmpty ? null : _sortController.text,
              _ascending,
              _limitController.text.isEmpty ? null : int.tryParse(_limitController.text),
            );
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text('Apply Filter'),
        ),
      ],
    );
  }
}

class _SplitDialog extends StatefulWidget {
  final List<DatasetInfo> datasets;
  final Function(String path, double trainRatio, bool shuffle) onSplit;

  const _SplitDialog({required this.datasets, required this.onSplit});

  @override
  State<_SplitDialog> createState() => _SplitDialogState();
}

class _SplitDialogState extends State<_SplitDialog> {
  late DatasetInfo _selected;
  double _trainRatio = 0.8;
  bool _shuffle = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.datasets.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Row(
        children: [
          Icon(LucideIcons.split, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text('Train/Test Split', style: TextStyle(color: AppColors.foreground)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dataset', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            const SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DatasetInfo>(
                  isExpanded: true,
                  value: _selected,
                  dropdownColor: AppColors.card,
                  items: widget.datasets.map((d) => DropdownMenuItem(
                    value: d,
                    child: Text(d.name, style: TextStyle(color: AppColors.foreground)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selected = v!),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Train Ratio:', style: TextStyle(color: AppColors.foreground)),
                const SizedBox(width: 12),
                Text('${(_trainRatio * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
              ],
            ),
            Slider(
              value: _trainRatio,
              min: 0.5,
              max: 0.95,
              divisions: 9,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _trainRatio = v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Train: ${(_trainRatio * 100).toInt()}%', style: TextStyle(fontSize: 12, color: Colors.green)),
                Text('Test: ${((1 - _trainRatio) * 100).toInt()}%', style: TextStyle(fontSize: 12, color: Colors.orange)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _shuffle,
                  onChanged: (v) => setState(() => _shuffle = v ?? true),
                  activeColor: AppColors.primary,
                ),
                Text('Shuffle data before splitting', style: TextStyle(color: AppColors.foreground)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onSplit(_selected.path, _trainRatio, _shuffle);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: Text('Split Dataset'),
        ),
      ],
    );
  }
}

class _MergeDialog extends StatefulWidget {
  final List<DatasetInfo> datasets;
  final Function(List<String> paths, String outputName, String mergeType, String? joinColumn) onMerge;

  const _MergeDialog({required this.datasets, required this.onMerge});

  @override
  State<_MergeDialog> createState() => _MergeDialogState();
}

class _MergeDialogState extends State<_MergeDialog> {
  final Set<String> _selectedPaths = {};
  final _outputController = TextEditingController(text: 'merged_dataset');
  final _joinColumnController = TextEditingController();
  String _mergeType = 'concat';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Row(
        children: [
          Icon(LucideIcons.combine, size: 20, color: Colors.purple),
          const SizedBox(width: 8),
          Text('Merge Datasets', style: TextStyle(color: AppColors.foreground)),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select datasets to merge:', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView(
                shrinkWrap: true,
                children: widget.datasets.map((d) => CheckboxListTile(
                  value: _selectedPaths.contains(d.path),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedPaths.add(d.path);
                      } else {
                        _selectedPaths.remove(d.path);
                      }
                    });
                  },
                  title: Text(d.name, style: TextStyle(fontSize: 13, color: AppColors.foreground)),
                  subtitle: Text(d.format, style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                  activeColor: Colors.purple,
                  dense: true,
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _outputController,
              decoration: InputDecoration(
                labelText: 'Output Name',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Merge Type:', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: Text('Concatenate'),
                  selected: _mergeType == 'concat',
                  onSelected: (_) => setState(() => _mergeType = 'concat'),
                  selectedColor: Colors.purple.withOpacity(0.3),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Join'),
                  selected: _mergeType == 'join',
                  onSelected: (_) => setState(() => _mergeType = 'join'),
                  selectedColor: Colors.purple.withOpacity(0.3),
                ),
              ],
            ),
            if (_mergeType == 'join') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _joinColumnController,
                decoration: InputDecoration(
                  labelText: 'Join Column',
                  hintText: 'Column to join on',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: _selectedPaths.length >= 2 ? () {
            Navigator.pop(context);
            widget.onMerge(
              _selectedPaths.toList(),
              _outputController.text,
              _mergeType,
              _mergeType == 'join' ? _joinColumnController.text : null,
            );
          } : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          child: Text('Merge'),
        ),
      ],
    );
  }
}

class _ExportDialog extends StatefulWidget {
  final List<DatasetInfo> datasets;
  final Function(String path, String format) onExport;

  const _ExportDialog({required this.datasets, required this.onExport});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late DatasetInfo _selected;
  String _format = 'csv';

  @override
  void initState() {
    super.initState();
    _selected = widget.datasets.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Row(
        children: [
          Icon(LucideIcons.fileDown, size: 20, color: Colors.green),
          const SizedBox(width: 8),
          Text('Export Dataset', style: TextStyle(color: AppColors.foreground)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dataset', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            const SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DatasetInfo>(
                  isExpanded: true,
                  value: _selected,
                  dropdownColor: AppColors.card,
                  items: widget.datasets.map((d) => DropdownMenuItem(
                    value: d,
                    child: Text(d.name, style: TextStyle(color: AppColors.foreground)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selected = v!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Export Format:', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _formatChip('CSV', 'csv', Colors.green),
                _formatChip('Excel', 'xlsx', Colors.blue),
                _formatChip('Parquet', 'parquet', Colors.purple),
                _formatChip('JSON', 'json', Colors.orange),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onExport(_selected.path, _format);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.download, size: 16),
              const SizedBox(width: 6),
              Text('Export as ${_format.toUpperCase()}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formatChip(String label, String value, Color color) {
    final isSelected = _format == value;
    return GestureDetector(
      onTap: () => setState(() => _format = value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : AppColors.border, width: isSelected ? 2 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : AppColors.foreground,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
