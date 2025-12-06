import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../services/pip_service.dart';

/// Panel for managing Python packages
class PackageManagerPanel extends StatefulWidget {
  final VoidCallback? onClose;

  const PackageManagerPanel({
    super.key,
    this.onClose,
  });

  @override
  State<PackageManagerPanel> createState() => _PackageManagerPanelState();
}

class _PackageManagerPanelState extends State<PackageManagerPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<PipPackage> _installedPackages = [];
  List<PyPIPackage> _searchResults = [];
  List<OutdatedPackage> _outdatedPackages = [];

  bool _isLoading = false;
  bool _isSearching = false;
  bool _isInstalling = false;
  String? _installingPackage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInstalledPackages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInstalledPackages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final packages = await pipService.listInstalled();
      if (mounted) {
        setState(() {
          _installedPackages = packages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load packages: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadOutdatedPackages() async {
    setState(() => _isLoading = true);

    try {
      final packages = await pipService.checkOutdated();
      if (mounted) {
        setState(() {
          _outdatedPackages = packages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchPackages(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await pipService.search(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _installPackage(String name, {String? version}) async {
    setState(() {
      _isInstalling = true;
      _installingPackage = name;
    });

    try {
      final result = await pipService.install(name, version: version);
      if (mounted) {
        setState(() {
          _isInstalling = false;
          _installingPackage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success
                ? 'Successfully installed $name'
                : 'Failed to install $name: ${result.message}'),
            backgroundColor:
                result.success ? AppColors.success : AppColors.destructive,
          ),
        );

        if (result.success) {
          _loadInstalledPackages();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInstalling = false;
          _installingPackage = null;
        });
      }
    }
  }

  Future<void> _uninstallPackage(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Uninstall Package', style: TextStyle(color: AppColors.foreground)),
        content: Text(
          'Are you sure you want to uninstall "$name"?',
          style: TextStyle(color: AppColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.mutedForeground)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            child: Text('Uninstall'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isInstalling = true;
      _installingPackage = name;
    });

    try {
      final result = await pipService.uninstall(name);
      if (mounted) {
        setState(() {
          _isInstalling = false;
          _installingPackage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success
                ? 'Successfully uninstalled $name'
                : 'Failed to uninstall $name: ${result.message}'),
            backgroundColor:
                result.success ? AppColors.success : AppColors.destructive,
          ),
        );

        if (result.success) {
          _loadInstalledPackages();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInstalling = false;
          _installingPackage = null;
        });
      }
    }
  }

  Future<void> _upgradePackage(String name) async {
    setState(() {
      _isInstalling = true;
      _installingPackage = name;
    });

    try {
      final result = await pipService.upgrade(name);
      if (mounted) {
        setState(() {
          _isInstalling = false;
          _installingPackage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success
                ? 'Successfully upgraded $name'
                : 'Failed to upgrade $name: ${result.message}'),
            backgroundColor:
                result.success ? AppColors.success : AppColors.destructive,
          ),
        );

        if (result.success) {
          _loadInstalledPackages();
          _loadOutdatedPackages();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInstalling = false;
          _installingPackage = null;
        });
      }
    }
  }

  void _showPackageInfo(String name) async {
    final info = await pipService.getPackageInfo(name);
    if (info == null || !mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => _PackageInfoDialog(package: info, onInstall: _installPackage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          // Tab bar
          _buildTabBar(),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInstalledTab(),
                _buildSearchTab(),
                _buildUpdatesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              LucideIcons.package,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Package Manager',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  '${_installedPackages.length} packages installed',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.refreshCw, size: 16),
            onPressed: _isLoading ? null : _loadInstalledPackages,
            tooltip: 'Refresh',
            color: AppColors.mutedForeground,
          ),
          if (widget.onClose != null)
            IconButton(
              icon: Icon(LucideIcons.x, size: 16),
              onPressed: widget.onClose,
              tooltip: 'Close',
              color: AppColors.mutedForeground,
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          if (index == 2) {
            _loadOutdatedPackages();
          }
        },
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.mutedForeground,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.list, size: 14),
                const SizedBox(width: 6),
                Text('Installed', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.search, size: 14),
                const SizedBox(width: 6),
                Text('Search', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.arrowUpCircle, size: 14),
                const SizedBox(width: 6),
                Text('Updates', style: TextStyle(fontSize: 12)),
                if (_outdatedPackages.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_outdatedPackages.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstalledTab() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading packages...',
              style: TextStyle(color: AppColors.mutedForeground),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.alertCircle, size: 48, color: AppColors.destructive),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: AppColors.destructive),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInstalledPackages,
              icon: Icon(LucideIcons.refreshCw, size: 16),
              label: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_installedPackages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.package, size: 48, color: AppColors.mutedForeground),
            const SizedBox(height: 16),
            Text(
              'No packages found',
              style: TextStyle(color: AppColors.mutedForeground),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: _installedPackages.length,
      itemBuilder: (context, index) {
        final package = _installedPackages[index];
        final isProcessing = _installingPackage == package.name;

        return _PackageListItem(
          name: package.name,
          version: package.version,
          isInstalled: true,
          isProcessing: isProcessing,
          onInfo: () => _showPackageInfo(package.name),
          onUninstall: () => _uninstallPackage(package.name),
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search input
        Container(
          padding: EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            style: TextStyle(fontSize: 14, color: AppColors.foreground),
            decoration: InputDecoration(
              hintText: 'Search PyPI packages...',
              hintStyle: TextStyle(color: AppColors.mutedForeground),
              prefixIcon: Icon(LucideIcons.search, size: 18, color: AppColors.mutedForeground),
              suffixIcon: _isSearching
                  ? Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchResults = []);
                          },
                        )
                      : null,
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
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (value) {
              if (value.length >= 2) {
                _searchPackages(value);
              } else {
                setState(() => _searchResults = []);
              }
            },
            onSubmitted: _searchPackages,
          ),
        ),
        // Quick install buttons
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickInstallChip(
                name: 'numpy',
                onTap: () => _installPackage('numpy'),
              ),
              _QuickInstallChip(
                name: 'pandas',
                onTap: () => _installPackage('pandas'),
              ),
              _QuickInstallChip(
                name: 'matplotlib',
                onTap: () => _installPackage('matplotlib'),
              ),
              _QuickInstallChip(
                name: 'torch',
                onTap: () => _installPackage('torch'),
              ),
              _QuickInstallChip(
                name: 'scikit-learn',
                onTap: () => _installPackage('scikit-learn'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Search results
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.search,
                        size: 48,
                        color: AppColors.mutedForeground,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Search for packages on PyPI',
                        style: TextStyle(color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final package = _searchResults[index];
                    final isInstalled = _installedPackages.any(
                      (p) => p.name.toLowerCase() == package.name.toLowerCase(),
                    );
                    final isProcessing = _installingPackage == package.name;

                    return _PackageListItem(
                      name: package.name,
                      version: package.version,
                      summary: package.summary,
                      isInstalled: isInstalled,
                      isProcessing: isProcessing,
                      onInfo: () => _showPackageInfo(package.name),
                      onInstall: isInstalled ? null : () => _installPackage(package.name),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUpdatesTab() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Checking for updates...',
              style: TextStyle(color: AppColors.mutedForeground),
            ),
          ],
        ),
      );
    }

    if (_outdatedPackages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCircle, size: 48, color: AppColors.success),
            const SizedBox(height: 16),
            Text(
              'All packages are up to date!',
              style: TextStyle(color: AppColors.foreground, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadOutdatedPackages,
              icon: Icon(LucideIcons.refreshCw, size: 14),
              label: Text('Check again'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Upgrade all button
        Container(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isInstalling
                  ? null
                  : () async {
                      for (final pkg in _outdatedPackages) {
                        await _upgradePackage(pkg.name);
                      }
                    },
              icon: Icon(LucideIcons.arrowUpCircle, size: 16),
              label: Text('Upgrade All (${_outdatedPackages.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryForeground,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        // Outdated list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 8),
            itemCount: _outdatedPackages.length,
            itemBuilder: (context, index) {
              final package = _outdatedPackages[index];
              final isProcessing = _installingPackage == package.name;

              return Container(
                margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            package.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.muted,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  package.currentVersion,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  LucideIcons.arrowRight,
                                  size: 12,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  package.latestVersion,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isProcessing)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: Icon(LucideIcons.arrowUpCircle, size: 18),
                        onPressed: () => _upgradePackage(package.name),
                        tooltip: 'Upgrade',
                        color: AppColors.primary,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PackageListItem extends StatelessWidget {
  final String name;
  final String version;
  final String? summary;
  final bool isInstalled;
  final bool isProcessing;
  final VoidCallback? onInfo;
  final VoidCallback? onInstall;
  final VoidCallback? onUninstall;

  const _PackageListItem({
    required this.name,
    required this.version,
    this.summary,
    required this.isInstalled,
    this.isProcessing = false,
    this.onInfo,
    this.onInstall,
    this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isInstalled
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isInstalled ? LucideIcons.packageCheck : LucideIcons.package,
              size: 18,
              color: isInstalled ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.foreground,
                      ),
                    ),
                    if (version.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          version,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (summary != null && summary!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    summary!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (isProcessing)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            if (onInfo != null)
              IconButton(
                icon: Icon(LucideIcons.info, size: 16),
                onPressed: onInfo,
                tooltip: 'Package Info',
                color: AppColors.mutedForeground,
                splashRadius: 18,
              ),
            if (onInstall != null)
              IconButton(
                icon: Icon(LucideIcons.download, size: 16),
                onPressed: onInstall,
                tooltip: 'Install',
                color: AppColors.primary,
                splashRadius: 18,
              ),
            if (onUninstall != null)
              IconButton(
                icon: Icon(LucideIcons.trash2, size: 16),
                onPressed: onUninstall,
                tooltip: 'Uninstall',
                color: AppColors.destructive,
                splashRadius: 18,
              ),
          ],
        ],
      ),
    );
  }
}

class _QuickInstallChip extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _QuickInstallChip({
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.plus, size: 12, color: AppColors.mutedForeground),
            const SizedBox(width: 4),
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageInfoDialog extends StatelessWidget {
  final PyPIPackage package;
  final Future<void> Function(String, {String? version}) onInstall;

  const _PackageInfoDialog({
    required this.package,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 480,
        constraints: BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      LucideIcons.package,
                      size: 24,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'v${package.version}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            if (package.license.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.muted,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  package.license,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    color: AppColors.mutedForeground,
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (package.summary.isNotEmpty) ...[
                      Text(
                        package.summary,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Author
                    if (package.author.isNotEmpty)
                      _InfoRow(
                        icon: LucideIcons.user,
                        label: 'Author',
                        value: package.author,
                      ),
                    // Python version
                    if (package.requiresPython.isNotEmpty)
                      _InfoRow(
                        icon: LucideIcons.code,
                        label: 'Python',
                        value: package.requiresPython,
                      ),
                    // Homepage
                    if (package.homePage.isNotEmpty)
                      _InfoRow(
                        icon: LucideIcons.globe,
                        label: 'Homepage',
                        value: package.homePage,
                        isLink: true,
                      ),
                    // Available versions
                    if (package.versions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Available Versions',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: package.versions.take(10).map((version) {
                          final isLatest = version == package.version;
                          return InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              onInstall(package.name, version: version);
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isLatest
                                    ? AppColors.success.withOpacity(0.15)
                                    : AppColors.muted,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isLatest
                                      ? AppColors.success.withOpacity(0.3)
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    version,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: isLatest
                                          ? AppColors.success
                                          : AppColors.foreground,
                                    ),
                                  ),
                                  if (isLatest) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '(latest)',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Close',
                      style: TextStyle(color: AppColors.mutedForeground),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onInstall(package.name);
                    },
                    icon: Icon(LucideIcons.download, size: 16),
                    label: Text('Install Latest'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLink;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLink = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.mutedForeground),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isLink ? AppColors.primary : AppColors.foreground,
                decoration: isLink ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
