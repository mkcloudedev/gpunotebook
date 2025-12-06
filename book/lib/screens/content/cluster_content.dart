import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/cluster/cluster_panel.dart';

/// Content page for GPU Cluster management
class ClusterContent extends StatelessWidget {
  const ClusterContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Main content
        Expanded(
          child: Container(
            color: AppColors.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              LucideIcons.server,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GPU Cluster',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.foreground,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Manage distributed GPU nodes for notebook execution',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(color: AppColors.border, height: 1),
                // Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cluster panel
                        Container(
                          width: 400,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ClusterPanel(),
                        ),
                        SizedBox(width: 24),
                        // Info/Guide section
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Getting Started',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.foreground,
                                  ),
                                ),
                                SizedBox(height: 16),
                                _GuideStep(
                                  number: 1,
                                  title: 'Setup Worker Nodes',
                                  description: 'Run the setup script on each GPU machine to install Jupyter Enterprise Gateway.',
                                  code: 'sudo ./setup_worker.sh',
                                ),
                                SizedBox(height: 16),
                                _GuideStep(
                                  number: 2,
                                  title: 'Add Nodes to Cluster',
                                  description: 'Click "Add Node" and enter the hostname/IP and port of each GPU machine.',
                                ),
                                SizedBox(height: 16),
                                _GuideStep(
                                  number: 3,
                                  title: 'Select Node for Execution',
                                  description: 'When running notebooks, select a node from the dropdown or use "Auto" for automatic placement.',
                                ),
                                SizedBox(height: 24),
                                Divider(color: AppColors.border),
                                SizedBox(height: 24),
                                Text(
                                  'Features',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.foreground,
                                  ),
                                ),
                                SizedBox(height: 12),
                                _FeatureItem(
                                  icon: LucideIcons.zap,
                                  title: 'Auto Placement',
                                  description: 'Automatically selects the best available GPU node',
                                ),
                                _FeatureItem(
                                  icon: LucideIcons.activity,
                                  title: 'Health Monitoring',
                                  description: 'Real-time status and GPU metrics for all nodes',
                                ),
                                _FeatureItem(
                                  icon: LucideIcons.shuffle,
                                  title: 'Load Balancing',
                                  description: 'Distributes workloads across available nodes',
                                ),
                                _FeatureItem(
                                  icon: LucideIcons.tag,
                                  title: 'Tag-based Routing',
                                  description: 'Route kernels to specific nodes using tags',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GuideStep extends StatelessWidget {
  final int number;
  final String title;
  final String description;
  final String? code;

  const _GuideStep({
    required this.number,
    required this.title,
    required this.description,
    this.code,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: AppColors.primaryForeground,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
              ),
              if (code != null) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.codeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    code!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground,
                    fontSize: 13,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
