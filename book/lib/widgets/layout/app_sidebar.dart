import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';

class SidebarNavItem {
  final IconData icon;
  final String label;
  final String route;

  const SidebarNavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  static const List<SidebarNavItem> _navItems = [
    SidebarNavItem(icon: LucideIcons.home, label: 'Home', route: AppRoutes.home),
    SidebarNavItem(icon: LucideIcons.bookOpen, label: 'Notebooks', route: AppRoutes.notebooks),
    SidebarNavItem(icon: LucideIcons.code2, label: 'Playground', route: AppRoutes.playground),
    SidebarNavItem(icon: LucideIcons.bot, label: 'AI Assistant', route: AppRoutes.aiAssistant),
    SidebarNavItem(icon: LucideIcons.cpu, label: 'GPU Monitor', route: AppRoutes.gpuMonitor),
    SidebarNavItem(icon: LucideIcons.folderOpen, label: 'Files', route: AppRoutes.files),
    SidebarNavItem(icon: LucideIcons.settings, label: 'Settings', route: AppRoutes.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '/';

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
          Expanded(child: _buildNavItems(context, currentRoute)),
          _buildUserAvatar(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        LucideIcons.cpu,
        size: 20,
        color: AppColors.primaryForeground,
      ),
    );
  }

  Widget _buildNavItems(BuildContext context, String currentRoute) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: _navItems
            .map((item) => _SidebarNavIcon(
                  item: item,
                  isActive: currentRoute == item.route,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.sidebarHover,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            LucideIcons.user,
            size: 18,
            color: AppColors.sidebarMuted,
          ),
        ),
      ),
    );
  }
}

class _SidebarNavIcon extends StatefulWidget {
  final SidebarNavItem item;
  final bool isActive;

  const _SidebarNavIcon({
    required this.item,
    required this.isActive,
  });

  @override
  State<_SidebarNavIcon> createState() => _SidebarNavIconState();
}

class _SidebarNavIconState extends State<_SidebarNavIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          if (!isActive) {
            Navigator.pushReplacementNamed(context, widget.item.route);
          }
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 4),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withOpacity(0.15)
                : _isHovered
                    ? AppColors.sidebarHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: AppColors.primary.withOpacity(0.3))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.item.icon,
                size: 20,
                color: isActive ? AppColors.primary : AppColors.sidebarMuted,
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppColors.primary : AppColors.sidebarMuted,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
