import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../core/theme/app_colors.dart';
import '../models/kernel.dart';
import '../services/kernel_service.dart';
import '../services/gpu_service.dart';
import '../services/notebook_service.dart';
import '../services/file_service.dart';
import '../services/api_client.dart';
import '../widgets/notebook/ai_chat_panel.dart';
import 'content/home_content.dart';
import 'content/notebooks_content.dart';
import 'content/notebook_editor_content.dart';
import 'content/playground_content.dart';
import 'content/ai_assistant_content.dart';
import 'content/gpu_monitor_content.dart';
import 'content/files_content.dart' as files_content;
import 'content/settings_content.dart';
import 'content/help_content.dart';
import 'content/kaggle_content.dart';
import 'content/automl_content.dart';
import 'content/cluster_content.dart';

class ShellScreen extends StatefulWidget {
  final int initialPageIndex;
  final String? initialNotebookId;

  const ShellScreen({
    super.key,
    this.initialPageIndex = 0,
    this.initialNotebookId,
  });

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  late int _selectedIndex;
  String? _openNotebookId;
  bool _showHelp = false;
  final GlobalKey<files_content.FilesContentState> _filesKey = GlobalKey<files_content.FilesContentState>();
  final GlobalKey<NotebooksContentState> _notebooksKey = GlobalKey<NotebooksContentState>();
  final GlobalKey<NotebookEditorContentState> _notebookEditorKey = GlobalKey<NotebookEditorContentState>();
  final GlobalKey<PlaygroundContentState> _playgroundKey = GlobalKey<PlaygroundContentState>();
  final GlobalKey<AIAssistantContentState> _aiAssistantKey = GlobalKey<AIAssistantContentState>();

  // Kernel state
  List<Kernel> _kernels = [];
  Kernel? _selectedKernel;

  // GPU state
  String _gpuName = 'GPU';
  String _driverVersion = '';
  String _cudaVersion = '';
  bool _gpuAvailable = false;

  // AI Assistant state
  List<Map<String, dynamic>> _conversations = [];
  String? _currentConversationTitle;
  int _totalTokens = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialPageIndex == 10 ? 0 : widget.initialPageIndex;
    _showHelp = widget.initialPageIndex == 10;
    _openNotebookId = widget.initialNotebookId;
    _loadKernels();
    _loadGpuStatus();
    _loadConversations();
    _loadTokenUsage();
  }

  Future<void> _loadConversations() async {
    try {
      final response = await apiClient.get('/api/ai/conversations');
      if (mounted) {
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(response['conversations'] ?? []);
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _loadTokenUsage() async {
    try {
      final response = await apiClient.get('/api/ai/tokens');
      if (mounted) {
        setState(() {
          _totalTokens = response['total_tokens'] ?? 0;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  String _formatTokenCount(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    }
    return tokens.toString();
  }

  void _showTokenUsageModal() {
    showDialog(
      context: context,
      builder: (context) => _TokenUsageDialog(onReset: () {
        _loadTokenUsage();
      }),
    );
  }

  void updateConversationTitle(String title) {
    setState(() {
      _currentConversationTitle = title;
    });
  }

  void refreshConversations() {
    _loadConversations();
    _loadTokenUsage();
  }

  void _navigateTo(int index, {String? notebookId, bool showHelp = false}) {
    setState(() {
      _selectedIndex = index;
      _openNotebookId = notebookId;
      _showHelp = showHelp;
    });

    // Update browser URL without rebuilding the widget
    _updateBrowserUrl(index, notebookId: notebookId);
  }

  void _updateBrowserUrl(int index, {String? notebookId}) {
    final route = _getRouteForIndex(index, notebookId: notebookId);
    // Use html.window.history to update URL without navigation
    try {
      html.window.history.replaceState(null, '', route);
    } catch (e) {
      // Ignore if not running in browser
    }
  }

  String _getRouteForIndex(int index, {String? notebookId}) {
    if (notebookId != null) {
      return '/notebook/$notebookId';
    }
    switch (index) {
      case 0: return '/';
      case 1: return '/notebooks';
      case 2: return '/playground';
      case 3: return '/ai';
      case 4: return '/automl';
      case 5: return '/gpu';
      case 6: return '/files';
      case 7: return '/kaggle';
      case 8: return '/cluster';
      case 9: return '/settings';
      case 10: return '/help';
      default: return '/';
    }
  }

  Future<void> _loadKernels() async {
    try {
      final kernels = await kernelService.list();
      print('Loaded ${kernels.length} kernels');
      if (mounted) {
        setState(() {
          _kernels = kernels;
          if (kernels.isNotEmpty && _selectedKernel == null) {
            _selectedKernel = kernels.first;
            print('Selected kernel: ${_selectedKernel?.id}');
          }
        });
      }
    } catch (e) {
      print('Error loading kernels: $e');
    }
  }

  Future<Kernel?> _ensureKernelExists() async {
    if (_selectedKernel != null) return _selectedKernel;

    try {
      // Try to get existing kernels first
      final kernels = await kernelService.list();
      if (kernels.isNotEmpty) {
        setState(() {
          _kernels = kernels;
          _selectedKernel = kernels.first;
        });
        return _selectedKernel;
      }

      // Create a new kernel if none exists
      final newKernel = await kernelService.create('python3');
      if (newKernel != null && mounted) {
        setState(() {
          _kernels = [newKernel];
          _selectedKernel = newKernel;
        });
        return newKernel;
      }
    } catch (e) {
      print('Error ensuring kernel exists: $e');
    }
    return null;
  }

  Future<void> _loadGpuStatus() async {
    try {
      final status = await gpuService.getStatus();
      if (mounted && status.primaryGpu != null) {
        setState(() {
          _gpuName = status.primaryGpu!.name;
          _driverVersion = status.driverVersion;
          _cudaVersion = status.cudaVersion;
          _gpuAvailable = true;
        });
      }
    } catch (e) {
      // GPU not available
    }
  }

  // Nav items indices:
  // 0: Home, 1: Notebooks, 2: Playground, 3: AI, 4: AutoML, 5: GPU, 6: Files, 7: Kaggle, 8: Cluster, 9: Settings
  static const List<_NavItem> _navItems = [
    _NavItem(icon: LucideIcons.home, label: 'Home', route: '/'),           // 0
    _NavItem(icon: LucideIcons.fileCode, label: 'Notebooks', route: '/notebooks'), // 1
    _NavItem(icon: LucideIcons.play, label: 'Playground', route: '/playground'),   // 2
    _NavItem(icon: LucideIcons.bot, label: 'AI', route: '/ai'),            // 3
    _NavItem(icon: LucideIcons.brain, label: 'AutoML', route: '/automl'),  // 4
    _NavItem(icon: LucideIcons.cpu, label: 'GPU', route: '/gpu'),          // 5
    _NavItem(icon: LucideIcons.folderOpen, label: 'Files', route: '/files'), // 6
    _NavItem(icon: LucideIcons.database, label: 'Kaggle', route: '/kaggle'), // 7
    _NavItem(icon: LucideIcons.server, label: 'Cluster', route: '/cluster'), // 8
  ];

  @override
  Widget build(BuildContext context) {
    final isNotebookEditor = _openNotebookId != null && !_showHelp;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar - w-16 (64px)
          _buildSidebar(),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Header - h-12 (48px)
                _buildHeader(),
                // Breadcrumb
                _buildBreadcrumb(),
                // Content
                Expanded(child: _buildContent()),
              ],
            ),
          ),
          // AI Chat Panel - extends full height when in notebook editor
          if (isNotebookEditor)
            _buildAIChatSidebar(),
        ],
      ),
    );
  }

  Widget _buildAIChatSidebar() {
    return Container(
      width: 420,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: _openNotebookId != null
          ? AIChatPanel(
              key: ValueKey('ai_chat_$_openNotebookId'),
              notebookId: _openNotebookId!,
              getCells: () => _notebookEditorKey.currentState?.notebook?.cells ?? [],
              getSelectedCellId: () => _notebookEditorKey.currentState?.selectedCellId,
              onCreateCell: (code, position) => _notebookEditorKey.currentState?.addCellWithCode(code, position),
              onEditCell: (cellId, code) => _notebookEditorKey.currentState?.updateCellSource(cellId, code),
              onDeleteCell: (cellId) => _notebookEditorKey.currentState?.deleteCellById(cellId),
              onExecuteCell: (cellId) => _notebookEditorKey.currentState?.runCellById(cellId),
            )
          : SizedBox.shrink(),
    );
  }

  // ============================================================================
  // KERNEL SELECTOR
  // ============================================================================
  Widget _buildKernelSelector() {
    if (_kernels.isEmpty) {
      return Row(
        children: [
          Text('Kernel:', style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: AppColors.mutedForeground, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text('No Kernel', style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
        ],
      );
    }

    final statusColor = _selectedKernel?.status == KernelStatus.idle
        ? AppColors.success
        : _selectedKernel?.status == KernelStatus.busy
            ? AppColors.warning
            : AppColors.mutedForeground;

    return PopupMenuButton<Kernel>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: AppColors.card,
      onSelected: (kernel) => setState(() => _selectedKernel = kernel),
      itemBuilder: (context) => _kernels.map((kernel) {
        final isSelected = kernel.id == _selectedKernel?.id;
        final kernelStatusColor = kernel.status == KernelStatus.idle
            ? AppColors.success
            : kernel.status == KernelStatus.busy
                ? AppColors.warning
                : AppColors.mutedForeground;
        return PopupMenuItem<Kernel>(
          value: kernel,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: kernelStatusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  kernel.name,
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                Icon(LucideIcons.check, size: 14, color: AppColors.primary),
            ],
          ),
        );
      }).toList(),
      child: Row(
        children: [
          Text('Kernel:', style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(_selectedKernel?.name ?? 'Select', style: TextStyle(fontSize: 14, color: AppColors.foreground)),
          const SizedBox(width: 4),
          Icon(LucideIcons.chevronDown, size: 16, color: AppColors.mutedForeground),
        ],
      ),
    );
  }

  // ============================================================================
  // SIDEBAR
  // ============================================================================
  Widget _buildSidebar() {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(right: BorderSide(color: AppColors.sidebarHover)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Logo
          GestureDetector(
            onTap: () => _navigateTo(0),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(LucideIcons.zap, size: 18, color: AppColors.primaryForeground),
            ),
          ),
          const SizedBox(height: 24),
          // Nav items
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: List.generate(_navItems.length, (index) {
                  return _SidebarIcon(
                    item: _navItems[index],
                    isActive: _selectedIndex == index && _openNotebookId == null && !_showHelp,
                    onTap: () => _navigateTo(index),
                  );
                }),
              ),
            ),
          ),
          // Settings at bottom (index 9)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: _SidebarIcon(
              item: const _NavItem(icon: LucideIcons.settings, label: 'Settings', route: '/settings'),
              isActive: _selectedIndex == 9 && !_showHelp,
              onTap: () => _navigateTo(9),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ============================================================================
  // HEADER
  // ============================================================================
  Widget _buildHeader() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Title with dropdown
          Row(
            children: [
              Text(
                'GPU Notebook',
                style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.foreground),
              ),
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronDown, size: 16, color: AppColors.mutedForeground),
            ],
          ),
          const Spacer(),
          // GPU Status (index 5)
          GestureDetector(
            onTap: () => _navigateTo(5),
            child: Row(
              children: [
                Icon(LucideIcons.cpu, size: 16, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                Text(_gpuAvailable ? _gpuName : 'No GPU', style: TextStyle(fontSize: 14, color: _gpuAvailable ? AppColors.foreground : AppColors.mutedForeground)),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: _gpuAvailable ? AppColors.success : AppColors.mutedForeground, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Kernel Selector
          _buildKernelSelector(),
          const SizedBox(width: 16),
          // Help button
          _HeaderButton(
            icon: LucideIcons.helpCircle,
            label: 'Help',
            onTap: () => _navigateTo(_selectedIndex, showHelp: true),
          ),
          const SizedBox(width: 16),
          // User avatar with dropdown
          PopupMenuButton<String>(
            offset: const Offset(0, 45),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            color: AppColors.card,
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  _navigateTo(9);
                  break;
                case 'help':
                  _navigateTo(_selectedIndex, showHelp: true);
                  break;
                case 'logout':
                  // Handle logout
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.foreground)),
                    const SizedBox(height: 2),
                    Text('user@local', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(LucideIcons.settings, size: 16, color: AppColors.foreground),
                    SizedBox(width: 8),
                    Text('Settings', style: TextStyle(color: AppColors.foreground)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'help',
                child: Row(
                  children: [
                    Icon(LucideIcons.helpCircle, size: 16, color: AppColors.foreground),
                    SizedBox(width: 8),
                    Text('Help', style: TextStyle(color: AppColors.foreground)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(LucideIcons.logOut, size: 16, color: AppColors.destructive),
                    SizedBox(width: 8),
                    Text('Log out', style: TextStyle(color: AppColors.destructive)),
                  ],
                ),
              ),
            ],
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.user, size: 16, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // BREADCRUMB
  // ============================================================================
  Widget _buildBreadcrumb() {
    final routeNames = {
      0: 'Home',
      1: 'Notebooks',
      2: 'Playground',
      3: 'AI Assistant',
      4: 'AutoML',
      5: 'GPU Monitor',
      6: 'Files',
      7: 'Kaggle',
      8: 'Settings',
    };

    final currentRoute = _showHelp
        ? 'Help'
        : _openNotebookId != null
            ? 'Notebook Editor'
            : routeNames[_selectedIndex] ?? 'Home';
    final isNotebookEditor = _openNotebookId != null && !_showHelp;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb path
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateTo(0),
                  child: Text('Home', style: TextStyle(fontSize: 14, color: AppColors.primary)),
                ),
                if (_showHelp) ...[
                  Text(' / ', style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
                  Text('Help', style: TextStyle(fontSize: 14, color: AppColors.foreground)),
                ] else if (_selectedIndex > 0 || isNotebookEditor) ...[
                  Text(' / ', style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
                  GestureDetector(
                    onTap: () {
                      if (isNotebookEditor) {
                        _navigateTo(1);
                      }
                    },
                    child: Text(
                      isNotebookEditor ? 'Notebooks' : (routeNames[_selectedIndex] ?? ''),
                      style: TextStyle(
                        fontSize: 14,
                        color: isNotebookEditor ? AppColors.primary : AppColors.foreground,
                      ),
                    ),
                  ),
                ],
                if (isNotebookEditor) ...[
                  Text(' / ', style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
                  Text(
                    'Notebook $_openNotebookId',
                    style: TextStyle(fontSize: 14, color: AppColors.foreground),
                  ),
                ],
              ],
            ),
          ),
          // Title row
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Text(
                  currentRoute,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.foreground),
                ),
                if (isNotebookEditor) ...[
                  const SizedBox(width: 12),
                  Text(
                    'ID: $_openNotebookId',
                    style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text('Saved', style: TextStyle(fontSize: 14, color: AppColors.foreground)),
                ],
                const Spacer(),
                if (_selectedIndex == 0 && !_showHelp) ...[
                  OutlinedButton.icon(
                    onPressed: () => _navigateTo(1),
                    icon: Icon(LucideIcons.fileCode, size: 16),
                    label: Text('Notebooks'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.foreground,
                      side: BorderSide(color: AppColors.border),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _navigateTo(2),
                    icon: Icon(LucideIcons.play, size: 16),
                    label: Text('Playground'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.foreground,
                      side: BorderSide(color: AppColors.border),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _navigateTo(3),
                    icon: Icon(LucideIcons.bot, size: 16),
                    label: Text('AI Assistant'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.foreground,
                      side: BorderSide(color: AppColors.border),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
                // Actions
                if (isNotebookEditor) ...[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text('Kernel Ready', style: TextStyle(fontSize: 14, color: AppColors.foreground)),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronDown, size: 16, color: AppColors.mutedForeground),
                ],
                if (_selectedIndex == 1 && !isNotebookEditor) ...[
                  SizedBox(
                    width: 200,
                    height: 32,
                    child: TextField(
                      style: TextStyle(fontSize: 13, color: AppColors.foreground),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
                        prefixIcon: Icon(LucideIcons.search, size: 16, color: AppColors.mutedForeground),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primary)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _notebooksKey.currentState?.importNotebook(),
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
                    onPressed: () => _notebooksKey.currentState?.createNewNotebook(),
                    icon: Icon(LucideIcons.plus, size: 16),
                    label: Text('New'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryForeground,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
                // AI Assistant actions
                if (_selectedIndex == 3) ...[
                  // Conversations dropdown
                  PopupMenuButton<String>(
                    tooltip: 'Conversation History',
                    offset: const Offset(0, 40),
                    color: AppColors.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onSelected: (value) {
                      if (value == 'new') {
                        _aiAssistantKey.currentState?.createNewConversation();
                      } else {
                        _aiAssistantKey.currentState?.loadConversation(value);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'new',
                        child: Row(
                          children: [
                            Icon(LucideIcons.plus, size: 16, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('New Conversation', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      ...(_conversations.take(10).map((c) => PopupMenuItem(
                        value: c['id'] as String,
                        child: Row(
                          children: [
                            Icon(LucideIcons.messageSquare, size: 14, color: AppColors.mutedForeground),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['title'] as String? ?? 'Untitled',
                                    style: TextStyle(fontSize: 13, color: AppColors.foreground),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${c['message_count'] ?? 0} messages',
                                    style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ))),
                    ],
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.messageSquare, size: 14, color: AppColors.foreground),
                          const SizedBox(width: 8),
                          Text(
                            _currentConversationTitle ?? 'New Chat',
                            style: TextStyle(fontSize: 13, color: AppColors.foreground),
                          ),
                          const SizedBox(width: 6),
                          Icon(LucideIcons.chevronDown, size: 14, color: AppColors.mutedForeground),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Token counter button
                  GestureDetector(
                    onTap: _showTokenUsageModal,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.coins, size: 14, color: Colors.amber[700]),
                          const SizedBox(width: 6),
                          Text(
                            _formatTokenCount(_totalTokens),
                            style: TextStyle(fontSize: 12, color: Colors.amber[700], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _aiAssistantKey.currentState?.createNewConversation(),
                    icon: Icon(LucideIcons.plus, size: 16),
                    label: Text('New Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryForeground,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
                // Playground actions
                if (_selectedIndex == 2) ...[
                  _BreadcrumbAction(icon: LucideIcons.copy, tooltip: 'Copy Code', onTap: () => _playgroundKey.currentState?.copyCode()),
                  _BreadcrumbAction(icon: LucideIcons.eraser, tooltip: 'Clear Code', onTap: () => _playgroundKey.currentState?.clearCode()),
                  _BreadcrumbAction(icon: LucideIcons.trash2, tooltip: 'Clear Output', onTap: () => _playgroundKey.currentState?.clearOutput()),
                  const SizedBox(width: 8),
                  _buildKernelSelector(),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _playgroundKey.currentState?.runCode(),
                    icon: Icon(LucideIcons.play, size: 16),
                    label: Text('Run'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
                // GPU Monitor actions (index 5)
                if (_selectedIndex == 5) ...[
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: Icon(LucideIcons.cpu, size: 20, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_gpuAvailable ? _gpuName : 'No GPU Detected', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                          Row(
                            children: [
                              Text('Driver: ${_driverVersion.isNotEmpty ? _driverVersion : 'N/A'}', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                              const SizedBox(width: 8),
                              Text('•', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                              const SizedBox(width: 8),
                              Text('CUDA: ${_cudaVersion.isNotEmpty ? _cudaVersion : 'N/A'}', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                              const SizedBox(width: 8),
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: _gpuAvailable ? AppColors.success : AppColors.mutedForeground, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text(_gpuAvailable ? 'Active' : 'Inactive', style: TextStyle(fontSize: 12, color: _gpuAvailable ? AppColors.success : AppColors.mutedForeground)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _loadGpuStatus,
                    icon: Icon(LucideIcons.refreshCw, size: 16),
                    label: Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.foreground,
                      side: BorderSide(color: AppColors.border),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
                // Files actions (index 6)
                if (_selectedIndex == 6) ...[
                  OutlinedButton.icon(
                    onPressed: () => _filesKey.currentState?.createNewFolder(),
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
                    onPressed: () => _filesKey.currentState?.uploadFiles(),
                    icon: Icon(LucideIcons.upload, size: 16),
                    label: Text('Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryForeground,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Notebook toolbar - compact version
          if (isNotebookEditor)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  _CompactToolbarButton(icon: LucideIcons.play, tooltip: 'Run All', onTap: () => _notebookEditorKey.currentState?.runAllCells()),
                  _CompactToolbarButton(icon: LucideIcons.square, tooltip: 'Stop', onTap: () => _notebookEditorKey.currentState?.stopExecution()),
                  _CompactToolbarButton(icon: LucideIcons.rotateCcw, tooltip: 'Restart', onTap: () => _notebookEditorKey.currentState?.restartKernel()),
                  Container(width: 1, height: 14, color: AppColors.border, margin: EdgeInsets.symmetric(horizontal: 6)),
                  _CompactToolbarButton(icon: LucideIcons.plus, tooltip: 'Code', onTap: () => _notebookEditorKey.currentState?.addCodeCell()),
                  _CompactToolbarButton(icon: LucideIcons.fileText, tooltip: 'Markdown', onTap: () => _notebookEditorKey.currentState?.addMarkdownCell()),
                  Container(width: 1, height: 14, color: AppColors.border, margin: EdgeInsets.symmetric(horizontal: 6)),
                  _CompactToolbarButton(icon: LucideIcons.eraser, tooltip: 'Clear Outputs', onTap: () => _notebookEditorKey.currentState?.clearAllOutputs()),
                  _CompactToolbarButton(icon: LucideIcons.save, tooltip: 'Save', onTap: () => _notebookEditorKey.currentState?.saveNotebook()),
                  Container(width: 1, height: 14, color: AppColors.border, margin: EdgeInsets.symmetric(horizontal: 6)),
                  _CompactToolbarButton(
                    icon: LucideIcons.variable,
                    tooltip: 'Variables',
                    onTap: () => _notebookEditorKey.currentState?.toggleVariables(),
                    isActive: _notebookEditorKey.currentState?.showVariables ?? false,
                  ),
                  _CompactToolbarButton(
                    icon: LucideIcons.package,
                    tooltip: 'Packages',
                    onTap: () => _notebookEditorKey.currentState?.togglePackages(),
                    isActive: _notebookEditorKey.currentState?.showPackages ?? false,
                  ),
                  _CompactToolbarButton(
                    icon: LucideIcons.columns,
                    tooltip: 'Split View',
                    onTap: () => _notebookEditorKey.currentState?.toggleSplitView(),
                    isActive: _notebookEditorKey.currentState?.showSplitView ?? false,
                  ),
                  _CompactToolbarButton(
                    icon: LucideIcons.keyboard,
                    tooltip: 'Keyboard Shortcuts (Ctrl+/)',
                    onTap: () => _notebookEditorKey.currentState?.showKeyboardShortcuts(),
                  ),
                  Container(width: 1, height: 14, color: AppColors.border, margin: EdgeInsets.symmetric(horizontal: 6)),
                  // Upload file button
                  _CompactToolbarButton(
                    icon: LucideIcons.upload,
                    tooltip: 'Upload File',
                    onTap: _showUploadDialog,
                  ),
                  // Export menu
                  _buildExportMenu(),
                  const Spacer(),
                  // Kernel status indicator
                  _buildKernelStatusIndicator(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (context) => _UploadFileDialog(
        onUpload: (filename, path) {
          // Insert code to load the file in notebook
          final code = '''# File uploaded: $filename
import pandas as pd

# Load the file
# df = pd.read_csv("$path")
# or
# with open("$path", "r") as f:
#     data = f.read()
''';
          _notebookEditorKey.currentState?.addCellWithCode(code, null);
        },
      ),
    );
  }

  Widget _buildExportMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Export',
      offset: const Offset(0, 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: AppColors.card,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.download, size: 14, color: AppColors.mutedForeground),
            const SizedBox(width: 4),
            Text('Export', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
            Icon(LucideIcons.chevronDown, size: 12, color: AppColors.mutedForeground),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'python',
          child: Row(
            children: [
              Icon(LucideIcons.fileCode, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Export as Python (.py)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'ipynb',
          child: Row(
            children: [
              Icon(LucideIcons.fileJson, size: 16, color: AppColors.warning),
              const SizedBox(width: 8),
              Text('Export as Jupyter (.ipynb)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'html',
          child: Row(
            children: [
              Icon(LucideIcons.code2, size: 16, color: AppColors.success),
              const SizedBox(width: 8),
              Text('Export as HTML (.html)'),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        if (_openNotebookId == null) return;

        String url;
        String ext;
        switch (value) {
          case 'python':
            url = notebookService.getExportPythonUrl(_openNotebookId!);
            ext = '.py';
            break;
          case 'ipynb':
            url = notebookService.getExportIpynbUrl(_openNotebookId!);
            ext = '.ipynb';
            break;
          case 'html':
            url = notebookService.getExportHtmlUrl(_openNotebookId!);
            ext = '.html';
            break;
          default:
            return;
        }
        final name = _notebookEditorKey.currentState?.notebook?.name ?? 'notebook';

        // Copy URL to clipboard and show snackbar
        await Clipboard.setData(ClipboardData(text: url));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(LucideIcons.check, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Export URL copied! Open in browser to download $name$ext')),
                ],
              ),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
  }

  Widget _buildKernelStatusIndicator() {
    final status = _notebookEditorKey.currentState?.kernelStatus ?? 'starting';
    Color statusColor;
    String statusText;

    switch (status) {
      case 'idle':
        statusColor = AppColors.success;
        statusText = 'Idle';
        break;
      case 'busy':
        statusColor = AppColors.warning;
        statusText = 'Running';
        break;
      case 'starting':
      case 'restarting':
        statusColor = AppColors.warning;
        statusText = 'Starting...';
        break;
      case 'error':
        statusColor = AppColors.destructive;
        statusText = 'Error';
        break;
      default:
        statusColor = AppColors.mutedForeground;
        statusText = 'Ready';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(statusText, style: TextStyle(fontSize: 11, color: AppColors.foreground)),
      ],
    );
  }

  // ============================================================================
  // CONTENT
  // ============================================================================
  Widget _buildContent() {
    // Show Help page when _showHelp is true
    if (_showHelp) {
      return HelpContent(onClose: () => _navigateTo(_selectedIndex));
    }

    if (_openNotebookId != null) {
      return NotebookEditorContent(key: _notebookEditorKey, notebookId: _openNotebookId!);
    }

    switch (_selectedIndex) {
      case 0:
        return HomeContent(
          onNavigate: (index) => _navigateTo(index),
          onOpenNotebook: (id) => _navigateTo(1, notebookId: id),
        );
      case 1:
        return NotebooksContent(
          key: _notebooksKey,
          onOpenNotebook: (id) => _navigateTo(1, notebookId: id),
        );
      case 2:
        return PlaygroundContent(
          key: _playgroundKey,
          kernel: _selectedKernel,
          onKernelNeeded: _ensureKernelExists,
        );
      case 3:
        return AIAssistantContent(
          key: _aiAssistantKey,
          onOpenNotebook: (id) => _navigateTo(1, notebookId: id),
          onConversationChanged: (title) => updateConversationTitle(title),
          onRefreshNeeded: () => refreshConversations(),
        );
      case 4:
        return const AutoMLContent();
      case 5:
        return const GPUMonitorContent();
      case 6:
        return files_content.FilesContent(key: _filesKey);
      case 7:
        return KaggleContent(onNavigateToSettings: () => _navigateTo(9));
      case 8:
        return const ClusterContent();
      case 9:
        return const SettingsContent();
      default:
        return HomeContent(
          onNavigate: (index) => _navigateTo(index),
          onOpenNotebook: (id) => _navigateTo(1, notebookId: id),
        );
    }
  }
}

// ============================================================================
// SIDEBAR COMPONENTS
// ============================================================================
class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem({required this.icon, required this.label, required this.route});
}

class _SidebarIcon extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarIcon({required this.item, required this.isActive, required this.onTap});

  @override
  State<_SidebarIcon> createState() => _SidebarIconState();
}

class _SidebarIconState extends State<_SidebarIcon> {
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
          margin: EdgeInsets.only(bottom: 4),
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: widget.isActive || _isHovered ? AppColors.sidebarHover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.item.icon,
                size: 20,
                color: widget.isActive ? AppColors.sidebarActive : AppColors.sidebarMuted,
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.label,
                style: TextStyle(
                  fontSize: 10,
                  color: widget.isActive ? AppColors.sidebarActive : AppColors.sidebarMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.label, required this.onTap});

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
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
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.muted : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: AppColors.mutedForeground),
              const SizedBox(width: 4),
              Text(widget.label, style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarIcon extends StatefulWidget {
  final IconData icon;
  const _ToolbarIcon({required this.icon});

  @override
  State<_ToolbarIcon> createState() => _ToolbarIconState();
}

class _ToolbarIconState extends State<_ToolbarIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          widget.icon,
          size: 16,
          color: _isHovered ? AppColors.foreground : AppColors.mutedForeground,
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarIconButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_ToolbarIconButton> createState() => _ToolbarIconButtonState();
}

class _ToolbarIconButtonState extends State<_ToolbarIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: EdgeInsets.all(6),
            margin: EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _isHovered ? AppColors.muted : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: _isHovered ? AppColors.foreground : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarTextButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarTextButton({required this.icon, required this.label, required this.tooltip, required this.onTap});

  @override
  State<_ToolbarTextButton> createState() => _ToolbarTextButtonState();
}

class _ToolbarTextButtonState extends State<_ToolbarTextButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isHovered ? AppColors.muted : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 14,
                  color: _isHovered ? AppColors.foreground : AppColors.mutedForeground,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: _isHovered ? AppColors.foreground : AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BreadcrumbAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _BreadcrumbAction({required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_BreadcrumbAction> createState() => _BreadcrumbActionState();
}

class _BreadcrumbActionState extends State<_BreadcrumbAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: EdgeInsets.all(6),
            margin: EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: _isHovered ? AppColors.muted : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 16, color: _isHovered ? AppColors.foreground : AppColors.mutedForeground),
          ),
        ),
      ),
    );
  }
}

class _CompactToolbarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;

  const _CompactToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<_CompactToolbarButton> createState() => _CompactToolbarButtonState();
}

class _CompactToolbarButtonState extends State<_CompactToolbarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: EdgeInsets.all(4),
            margin: EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? AppColors.primary.withOpacity(0.2)
                  : (_isHovered ? AppColors.muted : Colors.transparent),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: widget.isActive
                  ? AppColors.primary
                  : (_isHovered ? AppColors.foreground : AppColors.mutedForeground),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TOKEN USAGE DIALOG
// ============================================================================

class _TokenUsageDialog extends StatefulWidget {
  final VoidCallback onReset;

  const _TokenUsageDialog({required this.onReset});

  @override
  State<_TokenUsageDialog> createState() => _TokenUsageDialogState();
}

class _TokenUsageDialogState extends State<_TokenUsageDialog> {
  bool _isLoading = true;
  Map<String, dynamic> _usage = {};

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    try {
      final response = await apiClient.get('/api/ai/tokens');
      if (mounted) {
        setState(() {
          _usage = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetUsage() async {
    try {
      await apiClient.delete('/api/ai/tokens');
      widget.onReset();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token usage reset'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatNumber(int num) {
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(2)}M';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(2)}K';
    }
    return num.toString();
  }

  @override
  Widget build(BuildContext context) {
    final byProvider = _usage['by_provider'] as Map<String, dynamic>? ?? {};

    return Dialog(
      backgroundColor: AppColors.card,
      child: Container(
        width: 400,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.coins, size: 22, color: Colors.amber[700]),
                const SizedBox(width: 10),
                Text('Token Usage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                const Spacer(),
                IconButton(
                  icon: Icon(LucideIcons.x, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(color: AppColors.border),
            const SizedBox(height: 12),
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else ...[
              // Total usage card
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.withOpacity(0.1), Colors.orange.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatNumber(_usage['total_tokens'] ?? 0),
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.amber[700]),
                    ),
                    Text('Total Tokens', style: TextStyle(color: AppColors.mutedForeground)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildTokenStat('Input', _usage['total_input_tokens'] ?? 0, Colors.blue),
                        _buildTokenStat('Output', _usage['total_output_tokens'] ?? 0, Colors.green),
                      ],
                    ),
                  ],
                ),
              ),
              if (byProvider.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('By Provider', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                const SizedBox(height: 8),
                ...byProvider.entries.map((e) => _buildProviderRow(e.key, e.value as Map<String, dynamic>)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetUsage,
                      icon: Icon(LucideIcons.trash2, size: 16),
                      label: Text('Reset'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.destructive,
                        side: BorderSide(color: AppColors.destructive),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: Text('Close'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTokenStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(_formatNumber(value), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
      ],
    );
  }

  Widget _buildProviderRow(String provider, Map<String, dynamic> data) {
    final color = provider == 'claude' ? Colors.purple : provider == 'openai' ? Colors.green : Colors.blue;
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              provider[0].toUpperCase() + provider.substring(1),
              style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.foreground),
            ),
            const Spacer(),
            Text(
              _formatNumber(data['total'] ?? 0),
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// UPLOAD FILE DIALOG
// ============================================================================

class _UploadFileDialog extends StatefulWidget {
  final void Function(String filename, String path) onUpload;

  const _UploadFileDialog({required this.onUpload});

  @override
  State<_UploadFileDialog> createState() => _UploadFileDialogState();
}

class _UploadFileDialogState extends State<_UploadFileDialog> {
  bool _isUploading = false;
  String? _selectedFileName;
  List<int>? _selectedFileBytes;
  String _uploadPath = 'uploads';
  String? _error;

  final _supportedExtensions = [
    'csv', 'json', 'txt', 'parquet', 'xlsx', 'xls',
    'png', 'jpg', 'jpeg', 'gif', 'svg',
    'py', 'ipynb', 'md', 'yaml', 'yml',
    'zip', 'tar', 'gz',
    'h5', 'pkl', 'joblib', 'pt', 'pth', 'onnx',  // ML model files
  ];

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _supportedExtensions,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = file.bytes;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error selecting file: $e';
      });
    }
  }

  Future<void> _upload() async {
    if (_selectedFileName == null || _selectedFileBytes == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final success = await fileService.uploadFile(
        _selectedFileName!,
        _selectedFileBytes!,
        _uploadPath,
      );

      if (success) {
        final fullPath = '$_uploadPath/$_selectedFileName';
        widget.onUpload(_selectedFileName!, fullPath);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(LucideIcons.check, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('File "$_selectedFileName" uploaded successfully!'),
                ],
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        setState(() {
          _error = 'Upload failed. Please try again.';
          _isUploading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error uploading file: $e';
        _isUploading = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'csv':
      case 'xlsx':
      case 'xls':
        return LucideIcons.table;
      case 'json':
        return LucideIcons.braces;
      case 'py':
        return LucideIcons.fileCode;
      case 'ipynb':
        return LucideIcons.fileCode2;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
        return LucideIcons.image;
      case 'zip':
      case 'tar':
      case 'gz':
        return LucideIcons.archive;
      case 'h5':
      case 'pkl':
      case 'pt':
      case 'pth':
      case 'onnx':
        return LucideIcons.brain;
      default:
        return LucideIcons.file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      child: Container(
        width: 450,
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.upload, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload File',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.foreground),
                      ),
                      Text(
                        'Upload data files to use in your notebook',
                        style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(LucideIcons.x, size: 18),
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 18,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Drop zone / File picker
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedFileName != null ? AppColors.primary : AppColors.border,
                    width: _selectedFileName != null ? 2 : 1,
                  ),
                ),
                child: _selectedFileName != null
                    ? Column(
                        children: [
                          Icon(
                            _getFileIcon(_selectedFileName!),
                            size: 40,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedFileName!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.foreground,
                            ),
                          ),
                          if (_selectedFileBytes != null)
                            Text(
                              _formatFileSize(_selectedFileBytes!.length),
                              style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                            ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _pickFile,
                            icon: Icon(LucideIcons.refreshCw, size: 14),
                            label: Text('Change file'),
                            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Icon(
                            LucideIcons.uploadCloud,
                            size: 48,
                            color: AppColors.mutedForeground,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Click to select a file',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'CSV, JSON, Images, Python, Models, etc.',
                            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Upload path input
            Text(
              'Upload to folder:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.foreground),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: TextEditingController(text: _uploadPath),
              onChanged: (value) => _uploadPath = value,
              style: TextStyle(fontSize: 13, color: AppColors.foreground),
              decoration: InputDecoration(
                hintText: 'uploads',
                hintStyle: TextStyle(color: AppColors.mutedForeground),
                prefixIcon: Icon(LucideIcons.folder, size: 16, color: AppColors.mutedForeground),
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
            ),

            // Error message
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.destructive.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.destructive.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertCircle, size: 16, color: AppColors.destructive),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(fontSize: 12, color: AppColors.destructive),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.foreground,
                      side: BorderSide(color: AppColors.border),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedFileName != null && !_isUploading ? _upload : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryForeground,
                      disabledBackgroundColor: AppColors.muted,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(AppColors.primaryForeground),
                            ),
                          )
                        : Text('Upload'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

