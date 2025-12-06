import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_colors.dart';
import '../core/router/app_router.dart';
import '../models/notebook.dart';
import '../models/cell.dart';
import '../widgets/layout/main_layout.dart';
import '../widgets/home/quick_action_card.dart';
import '../widgets/home/gpu_status_card.dart';
import '../widgets/home/recent_notebooks_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final List<Notebook> _mockNotebooks = [
    Notebook(
      id: '1',
      name: 'Data Analysis Pipeline',
      cells: [
        const Cell(id: '1', cellType: CellType.code, source: 'import pandas as pd'),
        const Cell(id: '2', cellType: CellType.code, source: 'df = pd.read_csv("data.csv")'),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Notebook(
      id: '2',
      name: 'GPU Training Script',
      cells: [
        const Cell(id: '1', cellType: CellType.code, source: 'import torch'),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    Notebook(
      id: '3',
      name: 'Model Evaluation',
      cells: [],
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'GPU Notebook',
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 24),
            _buildMainContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your GPU notebook environment is ready',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                QuickActionCard(
                  icon: LucideIcons.plus,
                  title: 'New Notebook',
                  description: 'Create a new notebook',
                  iconColor: AppColors.primary,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.notebooks),
                ),
                QuickActionCard(
                  icon: LucideIcons.code2,
                  title: 'Playground',
                  description: 'Quick code execution',
                  iconColor: const Color(0xFF8B5CF6),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.playground),
                ),
                QuickActionCard(
                  icon: LucideIcons.bot,
                  title: 'AI Assistant',
                  description: 'Chat with AI',
                  iconColor: const Color(0xFF10B981),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.aiAssistant),
                ),
                QuickActionCard(
                  icon: LucideIcons.cpu,
                  title: 'GPU Monitor',
                  description: 'View GPU status',
                  iconColor: const Color(0xFFF59E0B),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.gpuMonitor),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: RecentNotebooksList(
                  notebooks: _mockNotebooks,
                  onNotebookTap: (notebook) {
                    Navigator.pushNamed(context, '/notebooks/${notebook.id}');
                  },
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: const GPUStatusCard(
                  gpuName: 'NVIDIA RTX 4090',
                  temperature: 45,
                  utilization: 23,
                  memoryUsed: 8.2,
                  memoryTotal: 24.0,
                ),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              const GPUStatusCard(
                gpuName: 'NVIDIA RTX 4090',
                temperature: 45,
                utilization: 23,
                memoryUsed: 8.2,
                memoryTotal: 24.0,
              ),
              const SizedBox(height: 24),
              RecentNotebooksList(
                notebooks: _mockNotebooks,
                onNotebookTap: (notebook) {
                  Navigator.pushNamed(context, '/notebooks/${notebook.id}');
                },
              ),
            ],
          );
        }
      },
    );
  }
}
