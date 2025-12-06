import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ai_message.dart';

class ProviderSelector extends StatelessWidget {
  final AIProvider selectedProvider;
  final void Function(AIProvider) onProviderChanged;

  const ProviderSelector({
    super.key,
    required this.selectedProvider,
    required this.onProviderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Provider:',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(width: 12),
          _ProviderChip(
            provider: AIProvider.claude,
            label: 'Claude',
            icon: LucideIcons.sparkles,
            color: const Color(0xFFDA7756),
            isSelected: selectedProvider == AIProvider.claude,
            onTap: () => onProviderChanged(AIProvider.claude),
          ),
          const SizedBox(width: 8),
          _ProviderChip(
            provider: AIProvider.openai,
            label: 'GPT-4',
            icon: LucideIcons.brain,
            color: const Color(0xFF10A37F),
            isSelected: selectedProvider == AIProvider.openai,
            onTap: () => onProviderChanged(AIProvider.openai),
          ),
          const SizedBox(width: 8),
          _ProviderChip(
            provider: AIProvider.gemini,
            label: 'Gemini',
            icon: LucideIcons.diamond,
            color: const Color(0xFF4285F4),
            isSelected: selectedProvider == AIProvider.gemini,
            onTap: () => onProviderChanged(AIProvider.gemini),
          ),
        ],
      ),
    );
  }
}

class _ProviderChip extends StatefulWidget {
  final AIProvider provider;
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProviderChip({
    required this.provider,
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ProviderChip> createState() => _ProviderChipState();
}

class _ProviderChipState extends State<_ProviderChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.color.withOpacity(0.15)
                : _isHovered
                    ? AppColors.muted
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? widget.color.withOpacity(0.5)
                  : _isHovered
                      ? AppColors.border
                      : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.isSelected ? widget.color : AppColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: widget.isSelected ? widget.color : AppColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
