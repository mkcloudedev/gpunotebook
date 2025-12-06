import 'package:flutter/material.dart';

class SidebarItem {
  final IconData icon;
  final String label;
  final bool active;

  const SidebarItem({
    required this.icon,
    required this.label,
    this.active = false,
  });
}
