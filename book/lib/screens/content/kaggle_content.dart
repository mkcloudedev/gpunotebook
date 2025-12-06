import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../services/kaggle_service.dart';

class KaggleContent extends StatefulWidget {
  final VoidCallback? onNavigateToSettings;

  const KaggleContent({super.key, this.onNavigateToSettings});

  @override
  State<KaggleContent> createState() => KaggleContentState();
}

class KaggleContentState extends State<KaggleContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isConfigured = false;
  String? _username;

  // Data
  List<KaggleDataset> _datasets = [];
  List<KaggleCompetition> _competitions = [];
  List<KaggleKernel> _kernels = [];

  // Search
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Download state
  final Set<String> _downloading = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final status = await kaggleService.getStatus();
    if (!mounted) return;

    setState(() {
      _isConfigured = status.configured;
      _username = status.username;
    });

    if (_isConfigured) {
      _loadData();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final results = await Future.wait([
      kaggleService.listDatasets(),
      kaggleService.listCompetitions(),
      kaggleService.listKernels(),
    ]);

    if (!mounted) return;
    setState(() {
      _datasets = results[0] as List<KaggleDataset>;
      _competitions = results[1] as List<KaggleCompetition>;
      _kernels = results[2] as List<KaggleKernel>;
      _isLoading = false;
    });
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      _loadData();
      return;
    }

    if (!mounted) return;
    setState(() => _searchQuery = query);

    final tabIndex = _tabController.index;

    if (tabIndex == 0) {
      final datasets = await kaggleService.searchDatasets(query);
      if (mounted) setState(() => _datasets = datasets);
    } else if (tabIndex == 2) {
      final kernels = await kaggleService.searchKernels(query);
      if (mounted) setState(() => _kernels = kernels);
    }
  }

  Future<void> _downloadDataset(KaggleDataset dataset) async {
    if (!mounted) return;
    setState(() => _downloading.add(dataset.ref));
    final result = await kaggleService.downloadDataset(dataset.ref);
    if (!mounted) return;
    setState(() => _downloading.remove(dataset.ref));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['success'] == true
              ? 'Dataset downloaded to ${result['path']}'
              : 'Failed to download: ${result['message']}'),
          backgroundColor: result['success'] == true ? AppColors.success : AppColors.destructive,
        ),
      );
    }
  }

  Future<void> _downloadCompetition(KaggleCompetition competition) async {
    if (!mounted) return;
    setState(() => _downloading.add(competition.ref));
    final result = await kaggleService.downloadCompetitionData(competition.ref);
    if (!mounted) return;
    setState(() => _downloading.remove(competition.ref));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['success'] == true
              ? 'Competition data downloaded to ${result['path']}'
              : 'Failed to download: ${result['message']}'),
          backgroundColor: result['success'] == true ? AppColors.success : AppColors.destructive,
        ),
      );
    }
  }

  Future<void> _pullKernel(KaggleKernel kernel) async {
    if (!mounted) return;
    setState(() => _downloading.add(kernel.ref));
    final result = await kaggleService.pullKernel(kernel.ref);
    if (!mounted) return;
    setState(() => _downloading.remove(kernel.ref));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['success'] == true
              ? 'Notebook downloaded to ${result['path']}'
              : 'Failed to download: ${result['message']}'),
          backgroundColor: result['success'] == true ? AppColors.success : AppColors.destructive,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConfigured && !_isLoading) {
      return _buildSetupScreen();
    }

    return Row(
      children: [
        // Main content
        Expanded(
          child: Column(
            children: [
              // Tabs
              Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.database, size: 14),
                          const SizedBox(width: 6),
                          Text('Datasets'),
                          if (_datasets.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _buildBadge('${_datasets.length}'),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.trophy, size: 14),
                          const SizedBox(width: 6),
                          Text('Competitions'),
                          if (_competitions.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _buildBadge('${_competitions.length}'),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.fileCode, size: 14),
                          const SizedBox(width: 6),
                          Text('Notebooks'),
                          if (_kernels.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _buildBadge('${_kernels.length}'),
                          ],
                        ],
                      ),
                    ),
                  ],
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.mutedForeground,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                ),
              ),
              // Content
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDatasetsTab(),
                          _buildCompetitionsTab(),
                          _buildKernelsTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
        // Side Panel
        _buildSidePanel(),
      ],
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildSidePanel() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onSubmitted: _search,
              style: TextStyle(fontSize: 13, color: AppColors.foreground),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
                prefixIcon: Icon(LucideIcons.search, size: 16, color: AppColors.mutedForeground),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(LucideIcons.x, size: 14),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadData();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          // Account Info
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF20BEFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(LucideIcons.user, size: 20, color: Color(0xFF20BEFF)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_username ?? 'Not connected', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.foreground)),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _isConfigured ? AppColors.success : AppColors.mutedForeground,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(_isConfigured ? 'Connected' : 'Not configured', style: TextStyle(fontSize: 11, color: _isConfigured ? AppColors.success : AppColors.mutedForeground)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          // Quick Stats
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Stats', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
                const SizedBox(height: 12),
                _buildStatRow(LucideIcons.database, 'Datasets', '${_datasets.length}'),
                const SizedBox(height: 8),
                _buildStatRow(LucideIcons.trophy, 'Competitions', '${_competitions.length}'),
                const SizedBox(height: 8),
                _buildStatRow(LucideIcons.fileCode, 'Notebooks', '${_kernels.length}'),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          // Actions
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Actions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loadData,
                    icon: Icon(LucideIcons.refreshCw, size: 14),
                    label: Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.foreground,
                      side: BorderSide(color: AppColors.border),
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Footer
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF20BEFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(LucideIcons.database, size: 16, color: Color(0xFF20BEFF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kaggle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.foreground)),
                      Text('kaggle.com', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.mutedForeground),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground))),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.foreground)),
      ],
    );
  }

  Widget _buildSetupScreen() {
    return Center(
      child: Container(
        width: 400,
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF20BEFF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(LucideIcons.database, size: 32, color: Color(0xFF20BEFF)),
            ),
            const SizedBox(height: 24),
            Text('Connect to Kaggle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.foreground)),
            const SizedBox(height: 8),
            Text(
              'Configure your Kaggle API credentials in Settings to access datasets, competitions, and notebooks.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onNavigateToSettings,
                icon: Icon(LucideIcons.settings, size: 18),
                label: Text('Go to Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20BEFF),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _checkStatus,
              icon: Icon(LucideIcons.refreshCw, size: 16),
              label: Text('Check Connection'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.foreground,
                side: BorderSide(color: AppColors.border),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {},
              icon: Icon(LucideIcons.externalLink, size: 14),
              label: Text('Get your API key from kaggle.com/settings', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: AppColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatasetsTab() {
    if (_datasets.isEmpty) {
      return _buildEmptyState('No datasets found', 'Search for datasets or refresh to load more', LucideIcons.database);
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _datasets.length,
      itemBuilder: (context, index) {
        final dataset = _datasets[index];
        final isDownloading = _downloading.contains(dataset.ref);
        return _ItemCard(
          icon: LucideIcons.database,
          iconColor: const Color(0xFF20BEFF),
          title: dataset.title,
          subtitle: dataset.ref,
          stats: [
            _Stat(LucideIcons.download, '${dataset.downloadCount}'),
            _Stat(LucideIcons.thumbsUp, '${dataset.voteCount}'),
            _Stat(LucideIcons.hardDrive, dataset.size),
          ],
          isDownloading: isDownloading,
          onDownload: () => _downloadDataset(dataset),
          secondaryAction: _SecondaryAction(label: 'Files', onTap: () => _showDatasetFiles(dataset)),
        );
      },
    );
  }

  Widget _buildCompetitionsTab() {
    if (_competitions.isEmpty) {
      return _buildEmptyState('No competitions found', 'Check back later for new competitions', LucideIcons.trophy);
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _competitions.length,
      itemBuilder: (context, index) {
        final competition = _competitions[index];
        final isDownloading = _downloading.contains(competition.ref);
        return _ItemCard(
          icon: LucideIcons.trophy,
          iconColor: const Color(0xFFF59E0B),
          title: competition.title,
          subtitle: competition.category,
          badge: competition.userHasEntered ? 'Entered' : null,
          stats: [
            _Stat(LucideIcons.gift, competition.reward),
            _Stat(LucideIcons.users, '${competition.teamCount}'),
            _Stat(LucideIcons.calendar, competition.deadline),
          ],
          isDownloading: isDownloading,
          onDownload: () => _downloadCompetition(competition),
          downloadLabel: 'Get Data',
          secondaryAction: _SecondaryAction(label: 'Submissions', onTap: () => _showSubmissions(competition)),
        );
      },
    );
  }

  Widget _buildKernelsTab() {
    if (_kernels.isEmpty) {
      return _buildEmptyState('No notebooks found', 'Search for notebooks to import', LucideIcons.fileCode);
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _kernels.length,
      itemBuilder: (context, index) {
        final kernel = _kernels[index];
        final isDownloading = _downloading.contains(kernel.ref);
        return _ItemCard(
          icon: LucideIcons.fileCode,
          iconColor: const Color(0xFF8B5CF6),
          title: kernel.title,
          subtitle: 'by ${kernel.author}',
          badge: kernel.language,
          stats: [
            _Stat(LucideIcons.thumbsUp, '${kernel.totalVotes}'),
            _Stat(LucideIcons.clock, kernel.lastRunTime),
          ],
          isDownloading: isDownloading,
          onDownload: () => _pullKernel(kernel),
          downloadLabel: 'Import',
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.mutedForeground.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.mutedForeground)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
        ],
      ),
    );
  }

  void _showDatasetFiles(KaggleDataset dataset) {
    showDialog(
      context: context,
      builder: (context) => _FilesDialog(
        title: 'Files in ${dataset.title}',
        loadFiles: () => kaggleService.getDatasetFiles(dataset.owner, dataset.name),
      ),
    );
  }

  void _showSubmissions(KaggleCompetition competition) {
    showDialog(
      context: context,
      builder: (context) => _SubmissionsDialog(competition: competition.ref),
    );
  }
}

// ============================================================================
// ITEM CARD
// ============================================================================

class _Stat {
  final IconData icon;
  final String value;
  const _Stat(this.icon, this.value);
}

class _SecondaryAction {
  final String label;
  final VoidCallback onTap;
  const _SecondaryAction({required this.label, required this.onTap});
}

class _ItemCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final List<_Stat> stats;
  final bool isDownloading;
  final VoidCallback onDownload;
  final String downloadLabel;
  final _SecondaryAction? secondaryAction;

  const _ItemCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.stats,
    required this.isDownloading,
    required this.onDownload,
    this.downloadLabel = 'Download',
    this.secondaryAction,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
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
          color: _isHovered ? AppColors.muted.withOpacity(0.5) : AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, size: 20, color: widget.iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.foreground),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(widget.badge!, style: TextStyle(fontSize: 10, color: AppColors.foreground)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(widget.subtitle, style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                  const SizedBox(height: 6),
                  Row(
                    children: widget.stats.map((stat) {
                      return Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Row(
                          children: [
                            Icon(stat.icon, size: 12, color: AppColors.mutedForeground),
                            const SizedBox(width: 4),
                            Text(stat.value, style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (widget.secondaryAction != null) ...[
              OutlinedButton(
                onPressed: widget.secondaryAction!.onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.foreground,
                  side: BorderSide(color: AppColors.border),
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  textStyle: TextStyle(fontSize: 12),
                ),
                child: Text(widget.secondaryAction!.label),
              ),
              const SizedBox(width: 8),
            ],
            ElevatedButton.icon(
              onPressed: widget.isDownloading ? null : widget.onDownload,
              icon: widget.isDownloading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(LucideIcons.download, size: 14),
              label: Text(widget.isDownloading ? '...' : widget.downloadLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.iconColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                textStyle: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DIALOGS
// ============================================================================

class _FilesDialog extends StatefulWidget {
  final String title;
  final Future<List<KaggleFile>> Function() loadFiles;

  const _FilesDialog({required this.title, required this.loadFiles});

  @override
  State<_FilesDialog> createState() => _FilesDialogState();
}

class _FilesDialogState extends State<_FilesDialog> {
  List<KaggleFile> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final files = await widget.loadFiles();
    setState(() {
      _files = files;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(widget.title, style: TextStyle(color: AppColors.foreground)),
      content: SizedBox(
        width: 400,
        height: 300,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _files.isEmpty
                ? Center(child: Text('No files found', style: TextStyle(color: AppColors.mutedForeground)))
                : ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      return ListTile(
                        leading: Icon(LucideIcons.file, color: AppColors.mutedForeground),
                        title: Text(file.name, style: TextStyle(color: AppColors.foreground)),
                        subtitle: Text(file.size, style: TextStyle(color: AppColors.mutedForeground)),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }
}

class _SubmissionsDialog extends StatefulWidget {
  final String competition;

  const _SubmissionsDialog({required this.competition});

  @override
  State<_SubmissionsDialog> createState() => _SubmissionsDialogState();
}

class _SubmissionsDialogState extends State<_SubmissionsDialog> {
  List<KaggleSubmission> _submissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final submissions = await kaggleService.getSubmissions(widget.competition);
    setState(() {
      _submissions = submissions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('Submissions', style: TextStyle(color: AppColors.foreground)),
      content: SizedBox(
        width: 500,
        height: 300,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _submissions.isEmpty
                ? Center(child: Text('No submissions yet', style: TextStyle(color: AppColors.mutedForeground)))
                : ListView.builder(
                    itemCount: _submissions.length,
                    itemBuilder: (context, index) {
                      final sub = _submissions[index];
                      return ListTile(
                        leading: Icon(
                          sub.status == 'complete' ? LucideIcons.checkCircle : LucideIcons.clock,
                          color: sub.status == 'complete' ? AppColors.success : AppColors.warning,
                        ),
                        title: Text(sub.fileName, style: TextStyle(color: AppColors.foreground)),
                        subtitle: Text('${sub.date} - Score: ${sub.publicScore}', style: TextStyle(color: AppColors.mutedForeground)),
                        trailing: Text(sub.status, style: TextStyle(color: AppColors.mutedForeground)),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }
}
