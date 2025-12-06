import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildNotebooksDropdown(),
          const Spacer(),
          _buildClustersSection(),
          const SizedBox(width: 16),
          _buildAccountSection(),
          const SizedBox(width: 16),
          _buildHelpButton(),
          const SizedBox(width: 16),
          _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildNotebooksDropdown() {
    return Row(
      children: [
        Text(
          'Notebooks',
          style: TextStyle(
            color: AppColors.foreground,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          LucideIcons.chevronDown,
          size: 16,
          color: AppColors.mutedForeground,
        ),
      ],
    );
  }

  Widget _buildClustersSection() {
    return Row(
      children: [
        Icon(
          LucideIcons.server,
          size: 16,
          color: AppColors.mutedForeground,
        ),
        const SizedBox(width: 8),
        Text(
          'Clusters',
          style: TextStyle(
            color: AppColors.mutedForeground,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          LucideIcons.chevronDown,
          size: 16,
          color: AppColors.mutedForeground,
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return Row(
      children: [
        Text(
          'Account:',
          style: TextStyle(
            color: AppColors.mutedForeground,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          LucideIcons.chevronDown,
          size: 16,
          color: AppColors.mutedForeground,
        ),
      ],
    );
  }

  Widget _buildHelpButton() {
    return Row(
      children: [
        Icon(
          LucideIcons.helpCircle,
          size: 16,
          color: AppColors.mutedForeground,
        ),
        const SizedBox(width: 4),
        Text(
          'Help',
          style: TextStyle(
            color: AppColors.mutedForeground,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        LucideIcons.user,
        size: 16,
        color: AppColors.primary,
      ),
    );
  }
}
