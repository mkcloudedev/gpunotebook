import 'package:flutter/material.dart';
import '../layout/app_sidebar.dart';
import '../layout/app_header.dart';
import '../../core/theme/app_colors.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final List<Widget>? actions;
  final Widget? breadcrumb;

  const MainLayout({
    super.key,
    required this.child,
    required this.title,
    this.actions,
    this.breadcrumb,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          const AppSidebar(),
          Expanded(
            child: Column(
              children: [
                AppHeader(title: title, actions: actions),
                if (breadcrumb != null) breadcrumb!,
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
