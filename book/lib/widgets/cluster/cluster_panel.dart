import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../models/cluster.dart';
import '../../services/cluster_service.dart';

/// Panel displaying cluster status and GPU nodes
class ClusterPanel extends StatefulWidget {
  final Function(ClusterNode)? onNodeSelected;
  final String? selectedNodeId;

  const ClusterPanel({
    super.key,
    this.onNodeSelected,
    this.selectedNodeId,
  });

  @override
  State<ClusterPanel> createState() => _ClusterPanelState();
}

class _ClusterPanelState extends State<ClusterPanel> {
  List<ClusterNode> _nodes = [];
  ClusterStats _stats = ClusterStats();
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final nodes = await clusterService.listNodes();
    final stats = await clusterService.getStats();
    if (mounted) {
      setState(() {
        _nodes = nodes;
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with stats
        _buildHeader(),
        Divider(color: AppColors.border, height: 1),
        // Node list
        Expanded(
          child: _nodes.isEmpty ? _buildEmptyState() : _buildNodeList(),
        ),
        Divider(color: AppColors.border, height: 1),
        // Add node button
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.server, size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'GPU Cluster',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              Spacer(),
              IconButton(
                icon: Icon(LucideIcons.refreshCw, size: 16),
                onPressed: _loadData,
                tooltip: 'Refresh',
                color: AppColors.mutedForeground,
              ),
            ],
          ),
          SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              _StatChip(
                icon: LucideIcons.server,
                label: 'Nodes',
                value: '${_stats.onlineNodes}/${_stats.totalNodes}',
                color: _stats.onlineNodes > 0 ? AppColors.success : AppColors.destructive,
              ),
              SizedBox(width: 8),
              _StatChip(
                icon: LucideIcons.cpu,
                label: 'GPUs',
                value: '${_stats.availableGpus}/${_stats.totalGpus}',
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              _StatChip(
                icon: LucideIcons.play,
                label: 'Kernels',
                value: '${_stats.activeKernels}',
                color: AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.serverOff,
            size: 48,
            color: AppColors.mutedForeground.withOpacity(0.5),
          ),
          SizedBox(height: 16),
          Text(
            'No GPU nodes configured',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.mutedForeground,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add a node to start using the cluster',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _nodes.length,
      itemBuilder: (context, index) {
        final node = _nodes[index];
        final isSelected = widget.selectedNodeId == node.id;
        return _NodeCard(
          node: node,
          isSelected: isSelected,
          onTap: () => widget.onNodeSelected?.call(node),
          onRefresh: () => _refreshNode(node.id),
          onRemove: () => _removeNode(node.id),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showAddNodeDialog,
              icon: Icon(LucideIcons.plus, size: 16),
              label: Text('Add Node'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshNode(String nodeId) async {
    await clusterService.refreshNode(nodeId);
    await _loadData();
  }

  Future<void> _removeNode(String nodeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Remove Node?', style: TextStyle(color: AppColors.foreground)),
        content: Text(
          'This will remove the node from the cluster. Running kernels will be terminated.',
          style: TextStyle(color: AppColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
            child: Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await clusterService.removeNode(nodeId);
      await _loadData();
    }
  }

  void _showAddNodeDialog() {
    final nameController = TextEditingController();
    final hostController = TextEditingController();
    final portController = TextEditingController(text: '8888');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Row(
          children: [
            Icon(LucideIcons.serverCog, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Add GPU Node', style: TextStyle(color: AppColors.foreground)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Node Name',
                hintText: 'e.g., GPU Server 1',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: hostController,
              decoration: InputDecoration(
                labelText: 'Host / IP Address',
                hintText: 'e.g., 192.168.1.100',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: portController,
              decoration: InputDecoration(
                labelText: 'Enterprise Gateway Port',
                hintText: '8888',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || hostController.text.isEmpty) {
                return;
              }
              Navigator.pop(context);
              await clusterService.addNode(
                name: nameController.text,
                host: hostController.text,
                port: int.tryParse(portController.text) ?? 8888,
              );
              await _loadData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Add Node', style: TextStyle(color: AppColors.primaryForeground)),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  final ClusterNode node;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onRefresh;
  final VoidCallback? onRemove;

  const _NodeCard({
    required this.node,
    this.isSelected = false,
    this.onTap,
    this.onRefresh,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(node.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                Text(
                  node.status.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(LucideIcons.moreVertical, size: 14, color: AppColors.mutedForeground),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(LucideIcons.refreshCw, size: 14),
                          SizedBox(width: 8),
                          Text('Refresh'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(LucideIcons.trash2, size: 14, color: AppColors.destructive),
                          SizedBox(width: 8),
                          Text('Remove', style: TextStyle(color: AppColors.destructive)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'refresh') onRefresh?.call();
                    if (value == 'remove') onRemove?.call();
                  },
                ),
              ],
            ),
            SizedBox(height: 8),
            // Host info
            Text(
              '${node.host}:${node.port}',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: AppColors.mutedForeground,
              ),
            ),
            SizedBox(height: 8),
            // GPU info
            if (node.gpus.isNotEmpty) ...[
              ...node.gpus.map((gpu) => _buildGpuRow(gpu)),
            ] else
              Text(
                'No GPU info available',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                  fontStyle: FontStyle.italic,
                ),
              ),
            SizedBox(height: 8),
            // Kernels info
            Row(
              children: [
                Icon(LucideIcons.play, size: 12, color: AppColors.mutedForeground),
                SizedBox(width: 4),
                Text(
                  '${node.activeKernels}/${node.maxKernels} kernels',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
                Spacer(),
                if (node.tags.isNotEmpty)
                  ...node.tags.take(2).map((tag) => Container(
                        margin: EdgeInsets.only(left: 4),
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(fontSize: 9, color: AppColors.mutedForeground),
                        ),
                      )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpuRow(GPUInfo gpu) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(LucideIcons.cpu, size: 12, color: AppColors.primary),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              gpu.name,
              style: TextStyle(fontSize: 11, color: AppColors.foreground),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: gpu.memoryUsagePercent / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: _getMemoryColor(gpu.memoryUsagePercent),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          SizedBox(width: 6),
          Text(
            gpu.memoryDisplay,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(NodeStatus status) {
    switch (status) {
      case NodeStatus.online:
        return AppColors.success;
      case NodeStatus.busy:
        return AppColors.warning;
      case NodeStatus.error:
        return AppColors.destructive;
      case NodeStatus.maintenance:
        return AppColors.warning;
      case NodeStatus.offline:
        return AppColors.mutedForeground;
    }
  }

  Color _getMemoryColor(double percent) {
    if (percent > 90) return AppColors.destructive;
    if (percent > 70) return AppColors.warning;
    return AppColors.success;
  }
}
