import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/notebook.dart';
import '../../models/kernel.dart';
import '../../services/gpu_service.dart';
import '../../services/notebook_service.dart';
import '../../services/kernel_service.dart';

class HomeContent extends StatefulWidget {
  final void Function(int) onNavigate;
  final void Function(String) onOpenNotebook;

  const HomeContent({
    super.key,
    required this.onNavigate,
    required this.onOpenNotebook,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  GPUStatus? _gpuStatus;
  List<Notebook> _notebooks = [];
  List<Kernel> _kernels = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  bool _showWelcomeCard = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadGpuData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await Future.wait([
      _loadGpuData(),
      _loadNotebooks(),
      _loadKernels(),
    ]);
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadGpuData() async {
    final status = await gpuService.getStatus();
    if (mounted) {
      setState(() => _gpuStatus = status.primaryGpu);
    }
  }

  Future<void> _loadNotebooks() async {
    final notebooks = await notebookService.list();
    if (mounted) {
      setState(() => _notebooks = notebooks);
    }
  }

  Future<void> _loadKernels() async {
    final kernels = await kernelService.list();
    if (mounted) {
      setState(() => _kernels = kernels);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_showWelcomeCard) ...[
                    _buildWelcomeCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildMetricsGrid(),
                ],
              ),
            ),
          ),
        ),
        _RecentNotebooksPanel(
          notebooks: _notebooks,
          gpuStatus: _gpuStatus,
          onOpenNotebook: widget.onOpenNotebook,
          onRefresh: _loadData,
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
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
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.codeBg,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('%md', style: AppTheme.monoStyle.copyWith(color: AppColors.mutedForeground)),
                _CloseButton(onTap: () => setState(() => _showWelcomeCard = false)),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GPU Notebook - Quick Start', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                const SizedBox(height: 8),
                Text('1. Create a new notebook or open existing', style: TextStyle(fontSize: 14, color: AppColors.foreground)),
                Text('2. Write Python code with GPU support', style: TextStyle(fontSize: 14, color: AppColors.foreground)),
                Text('3. Run cells with Shift+Enter', style: TextStyle(fontSize: 14, color: AppColors.foreground)),
                const SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _gpuStatus != null
                            ? 'CUDA ${_gpuStatus!.cudaVersion} | Driver ${_gpuStatus!.driverVersion} | Python 3.11'
                            : 'Connecting to backend...',
                        style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _gpuStatus != null ? AppColors.success.withOpacity(0.2) : AppColors.warning.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _gpuStatus != null ? 'READY' : 'CONNECTING',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _gpuStatus != null ? AppColors.success : AppColors.warning),
                        ),
                      ),
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

  Widget _buildMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            _MetricCard(
              title: 'GPU Utilization',
              code: const ['import torch', '# Check GPU availability', "device = torch.device('cuda')", 'torch.cuda.get_device_name(0)'],
              metric: _gpuStatus != null ? '${_gpuStatus!.utilizationGpu}%' : '--',
              isReady: _gpuStatus != null,
              sparkJobs: 2,
            ),
            _MetricCard(
              title: 'Memory Usage',
              code: const ['import torch', 'allocated = torch.cuda.memory_', '  allocated() / 1e9'],
              metric: _gpuStatus != null ? '${_gpuStatus!.memoryUsedGB.toStringAsFixed(1)} GB' : '--',
              isReady: _gpuStatus != null,
              sparkJobs: 1,
              lastUpdated: _gpuStatus != null ? 'of ${_gpuStatus!.memoryTotalGB.toStringAsFixed(0)} GB total' : null,
            ),
            _MetricCard(
              title: 'Active Kernels',
              code: const ['# IPython kernel status', 'kernel.is_alive()'],
              metric: '${_kernels.where((k) => k.status == KernelStatus.idle || k.status == KernelStatus.busy).length}',
              isReady: true,
              sparkJobs: _kernels.length,
              lastUpdated: 'Python 3.11 ready',
            ),
            _MetricCard(
              title: 'Notebooks',
              code: const ['# Recent notebooks', 'notebooks = list_notebooks()'],
              metric: '${_notebooks.length}',
              isReady: true,
              sparkJobs: _notebooks.length,
              lastUpdated: _notebooks.isNotEmpty ? 'Last: ${_notebooks.first.name}' : 'No notebooks yet',
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final List<String> code;
  final String metric;
  final bool isReady;
  final int? sparkJobs;
  final String? lastUpdated;

  const _MetricCard({
    required this.title,
    required this.code,
    required this.metric,
    this.isReady = true,
    this.sparkJobs,
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.5),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isReady ? AppColors.success.withOpacity(0.2) : AppColors.warning.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isReady ? 'READY' : 'LOADING',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isReady ? AppColors.success : AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.play, size: 14, color: AppColors.mutedForeground),
                    SizedBox(width: 4),
                    Icon(LucideIcons.maximize2, size: 14, color: AppColors.mutedForeground),
                    SizedBox(width: 4),
                    Icon(LucideIcons.layoutGrid, size: 14, color: AppColors.mutedForeground),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              color: AppColors.codeBg,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('%python', style: AppTheme.codeText),
                    ...code.map((line) => _buildCodeLine(line)),
                  ],
                ),
              ),
            ),
          ),
          if (sparkJobs != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  Icon(LucideIcons.chevronDown, size: 16, color: AppColors.foreground),
                  const SizedBox(width: 4),
                  Text('Tasks ($sparkJobs)', style: TextStyle(fontSize: 14, color: AppColors.foreground)),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Text(metric, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.foreground)),
          ),
          if (lastUpdated != null)
            Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(lastUpdated!, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground), overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }

  Widget _buildCodeLine(String line) {
    if (line.startsWith('import') || line.startsWith('from')) {
      final parts = line.split(' ');
      return Padding(
        padding: EdgeInsets.only(top: 2),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '${parts[0]} ', style: AppTheme.codeKeyword),
          TextSpan(text: parts.sublist(1).join(' '), style: AppTheme.monoStyle),
        ])),
      );
    } else if (line.startsWith('#')) {
      return Padding(
        padding: EdgeInsets.only(top: 2),
        child: Text(line, style: AppTheme.monoStyle.copyWith(color: AppColors.codeComment)),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: 2),
      child: Text(line, style: AppTheme.monoStyle),
    );
  }
}

class _RecentNotebooksPanel extends StatelessWidget {
  final List<Notebook> notebooks;
  final GPUStatus? gpuStatus;
  final void Function(String) onOpenNotebook;
  final VoidCallback onRefresh;

  const _RecentNotebooksPanel({
    required this.notebooks,
    required this.gpuStatus,
    required this.onOpenNotebook,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Notebooks', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.foreground)),
                GestureDetector(
                  onTap: onRefresh,
                  child: Icon(LucideIcons.refreshCw, size: 16, color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
          Expanded(
            child: notebooks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.fileCode, size: 32, color: AppColors.mutedForeground),
                        SizedBox(height: 8),
                        Text('No notebooks yet', style: TextStyle(color: AppColors.mutedForeground)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(12),
                    itemCount: notebooks.length > 5 ? 5 : notebooks.length,
                    itemBuilder: (context, index) {
                      final notebook = notebooks[index];
                      return _RecentNotebookItem(
                        name: notebook.name,
                        cells: notebook.cells.length,
                        lastRun: _formatDate(notebook.updatedAt),
                        onTap: () => onOpenNotebook(notebook.id),
                      );
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.zap, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GPU Status', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.foreground)),
                        const SizedBox(height: 8),
                        if (gpuStatus != null) ...[
                          _gpuStatusRow(gpuStatus!.name, '${gpuStatus!.utilizationGpu}%', AppColors.success),
                          _gpuStatusRow('Memory', '${gpuStatus!.memoryUsedGB.toStringAsFixed(0)}GB / ${gpuStatus!.memoryTotalGB.toStringAsFixed(0)}GB', AppColors.foreground),
                          _gpuStatusRow('Temp', '${gpuStatus!.temperature}°C', gpuStatus!.temperature < 70 ? AppColors.success : AppColors.warning),
                        ] else ...[
                          _gpuStatusRow('Status', 'Connecting...', AppColors.warning),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _gpuStatusRow(String label, String value, Color valueColor) {
    return Padding(
      padding: EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          Text(value, style: TextStyle(fontSize: 12, color: valueColor)),
        ],
      ),
    );
  }
}

class _RecentNotebookItem extends StatefulWidget {
  final String name;
  final int cells;
  final String lastRun;
  final VoidCallback onTap;

  const _RecentNotebookItem({required this.name, required this.cells, required this.lastRun, required this.onTap});

  @override
  State<_RecentNotebookItem> createState() => _RecentNotebookItemState();
}

class _RecentNotebookItemState extends State<_RecentNotebookItem> {
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
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.fileCode, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('${widget.cells} cells', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                    Text(widget.lastRun, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
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
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.muted : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            LucideIcons.x,
            size: 14,
            color: _isHovered ? AppColors.foreground : AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}
