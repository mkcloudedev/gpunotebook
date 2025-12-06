import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../models/sidebar_item.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  static const List<SidebarItem> _items = [
    SidebarItem(icon: LucideIcons.clock, label: 'Recent'),
    SidebarItem(icon: LucideIcons.home, label: 'My Home', active: true),
    SidebarItem(icon: LucideIcons.layoutGrid, label: 'Common'),
    SidebarItem(icon: LucideIcons.users, label: 'Users'),
    SidebarItem(icon: LucideIcons.bookOpen, label: 'Examples'),
    SidebarItem(icon: LucideIcons.database, label: 'Tables'),
    SidebarItem(icon: LucideIcons.hardDrive, label: 'S3'),
  ];

  @override
  void initState() {
    super.initState();
    themeProvider.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(
          right: BorderSide(color: AppColors.sidebarHover),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildLogo(),
          const SizedBox(height: 24),
          Expanded(child: _buildNavItems()),
          _ThemeToggle(),
          const SizedBox(height: 8),
          _buildBottomIcon(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        LucideIcons.sparkles,
        size: 20,
        color: AppColors.primaryForeground,
      ),
    );
  }

  Widget _buildNavItems() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: _items.map((item) => _SidebarIcon(item: item)).toList(),
      ),
    );
  }

  Widget _buildBottomIcon() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: _SidebarIcon(
        item: SidebarItem(icon: LucideIcons.sparkles, label: ''),
      ),
    );
  }
}

/// Theme toggle button widget
class _ThemeToggle extends StatefulWidget {
  @override
  State<_ThemeToggle> createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<_ThemeToggle> {
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    themeProvider.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeProvider.isDarkMode;

    return Tooltip(
      message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            themeProvider.toggleTheme();
          },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isHovered ? AppColors.sidebarHover : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDark ? LucideIcons.sun : LucideIcons.moon,
                  size: 20,
                  color: _isHovered ? AppColors.sidebarActive : AppColors.sidebarMuted,
                ),
                const SizedBox(height: 4),
                Text(
                  isDark ? 'Light' : 'Dark',
                  style: TextStyle(
                    fontSize: 10,
                    color: _isHovered ? AppColors.sidebarActive : AppColors.sidebarMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarIcon extends StatefulWidget {
  final SidebarItem item;

  const _SidebarIcon({required this.item});

  @override
  State<_SidebarIcon> createState() => _SidebarIconState();
}

class _SidebarIconState extends State<_SidebarIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.item.active;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {},
        child: Container(
          margin: EdgeInsets.only(bottom: 4),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive || _isHovered
                ? AppColors.sidebarHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.item.icon,
                size: 20,
                color: isActive ? AppColors.sidebarActive : AppColors.sidebarMuted,
              ),
              if (widget.item.label.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.item.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive ? AppColors.sidebarActive : AppColors.sidebarMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
