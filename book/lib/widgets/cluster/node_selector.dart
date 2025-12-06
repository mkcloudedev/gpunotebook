import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../models/cluster.dart';
import '../../services/cluster_service.dart';

/// Compact dropdown for selecting a cluster node
class NodeSelector extends StatefulWidget {
  final String? selectedNodeId;
  final Function(ClusterNode?) onNodeSelected;
  final bool showAuto;

  const NodeSelector({
    super.key,
    this.selectedNodeId,
    required this.onNodeSelected,
    this.showAuto = true,
  });

  @override
  State<NodeSelector> createState() => _NodeSelectorState();
}

class _NodeSelectorState extends State<NodeSelector> {
  List<ClusterNode> _nodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNodes();
  }

  Future<void> _loadNodes() async {
    final nodes = await clusterService.listNodes();
    if (mounted) {
      setState(() {
        _nodes = nodes;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Loading...', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          ],
        ),
      );
    }

    final selectedNode = widget.selectedNodeId != null
        ? _nodes.where((n) => n.id == widget.selectedNodeId).firstOrNull
        : null;

    return PopupMenuButton<String?>(
      tooltip: 'Select GPU Node',
      offset: Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: AppColors.card,
      onSelected: (nodeId) {
        if (nodeId == 'auto') {
          widget.onNodeSelected(null);
        } else {
          final node = _nodes.where((n) => n.id == nodeId).firstOrNull;
          widget.onNodeSelected(node);
        }
      },
      itemBuilder: (context) => [
        if (widget.showAuto)
          PopupMenuItem<String?>(
            value: 'auto',
            child: _buildMenuItem(
              icon: LucideIcons.sparkles,
              label: 'Auto (Best Available)',
              subtitle: 'Automatically select best node',
              isSelected: widget.selectedNodeId == null,
              statusColor: AppColors.primary,
            ),
          ),
        if (widget.showAuto && _nodes.isNotEmpty)
          PopupMenuDivider(),
        ..._nodes.map((node) => PopupMenuItem<String?>(
              value: node.id,
              enabled: node.isOnline && node.hasAvailableSlots,
              child: _buildMenuItem(
                icon: LucideIcons.server,
                label: node.name,
                subtitle: _getNodeSubtitle(node),
                isSelected: widget.selectedNodeId == node.id,
                statusColor: _getStatusColor(node.status),
                enabled: node.isOnline && node.hasAvailableSlots,
              ),
            )),
        if (_nodes.isEmpty)
          PopupMenuItem<String?>(
            enabled: false,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No nodes configured',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
      ],
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: selectedNode != null
                    ? _getStatusColor(selectedNode.status)
                    : AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8),
            Icon(
              selectedNode != null ? LucideIcons.server : LucideIcons.sparkles,
              size: 14,
              color: AppColors.foreground,
            ),
            SizedBox(width: 6),
            Text(
              selectedNode?.name ?? 'Auto',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.foreground,
              ),
            ),
            SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 12, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required Color statusColor,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Icon(LucideIcons.check, size: 14, color: AppColors.primary),
        ],
      ),
    );
  }

  String _getNodeSubtitle(ClusterNode node) {
    if (!node.isOnline) return 'Offline';
    if (!node.hasAvailableSlots) return 'No available slots';

    final gpuInfo = node.gpus.isNotEmpty
        ? '${node.gpus.length} GPU${node.gpus.length > 1 ? 's' : ''}'
        : 'No GPU';
    final kernelInfo = '${node.activeKernels}/${node.maxKernels} kernels';

    return '$gpuInfo • $kernelInfo';
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
}
