import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';

class Breadcrumb extends StatelessWidget {
  const Breadcrumb({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBreadcrumbPath(),
          _buildTitleRow(),
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbPath() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _BreadcrumbLink(text: 'Home'),
          Text(
            ' / ',
            style: TextStyle(color: AppColors.mutedForeground, fontSize: 14),
          ),
          _BreadcrumbLink(text: 'DB - Quarterly Sales Analysis -...'),
        ],
      ),
    );
  }

  Widget _buildTitleRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  'DB - Quarterly Sales Anal...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'ID: 12633',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(LucideIcons.link, size: 16, color: AppColors.mutedForeground),
                const SizedBox(width: 12),
                Icon(LucideIcons.tag, size: 16, color: AppColors.mutedForeground),
                const SizedBox(width: 4),
                Text(
                  'No tags',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          _buildClusterStatus(),
          const SizedBox(width: 12),
          _buildNavigationIcons(),
        ],
      ),
    );
  }

  Widget _buildClusterStatus() {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Cluster 68948',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(width: 4),
        Icon(LucideIcons.chevronDown, size: 16, color: AppColors.mutedForeground),
      ],
    );
  }

  Widget _buildNavigationIcons() {
    return Row(
      children: [
        _IconButton(icon: LucideIcons.fileText),
        _IconButton(icon: LucideIcons.rotateCcw),
        _IconButton(icon: LucideIcons.chevronUp),
        _IconButton(icon: LucideIcons.chevronDown),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          _IconButton(icon: LucideIcons.play),
          _IconButton(icon: LucideIcons.maximize2),
          _IconButton(icon: LucideIcons.layoutGrid),
          _IconButton(icon: LucideIcons.edit3),
          Container(
            width: 1,
            height: 16,
            color: AppColors.border,
            margin: EdgeInsets.symmetric(horizontal: 4),
          ),
          _IconButton(icon: LucideIcons.fileText),
          _IconButton(icon: LucideIcons.settings),
          const Spacer(),
          _buildInterpretersSection(),
        ],
      ),
    );
  }

  Widget _buildInterpretersSection() {
    return Row(
      children: [
        Text(
          'Interpreters',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(width: 4),
        Icon(LucideIcons.fileText, size: 16, color: AppColors.mutedForeground),
        Icon(LucideIcons.settings, size: 16, color: AppColors.mutedForeground),
        const SizedBox(width: 12),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'default',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(width: 4),
        Icon(LucideIcons.chevronDown, size: 16, color: AppColors.mutedForeground),
      ],
    );
  }
}

class _BreadcrumbLink extends StatelessWidget {
  final String text;

  const _BreadcrumbLink({required this.text});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _IconButton extends StatefulWidget {
  final IconData icon;

  const _IconButton({required this.icon});

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Padding(
        padding: EdgeInsets.all(4),
        child: Icon(
          widget.icon,
          size: 16,
          color: _isHovered ? AppColors.foreground : AppColors.mutedForeground,
        ),
      ),
    );
  }
}
