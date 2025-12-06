import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../services/gpu_service.dart';
import '../../services/kernel_service.dart';
import '../../models/kernel.dart';

class AppHeader extends StatefulWidget {
  final String title;
  final List<Widget>? actions;

  const AppHeader({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  String _gpuName = 'GPU';
  bool _gpuAvailable = false;
  List<Kernel> _kernels = [];
  Kernel? _selectedKernel;

  @override
  void initState() {
    super.initState();
    _loadGpuStatus();
    _loadKernels();
  }

  Future<void> _loadGpuStatus() async {
    try {
      final status = await gpuService.getStatus();
      if (mounted && status.primaryGpu != null) {
        setState(() {
          _gpuName = status.primaryGpu!.name;
          _gpuAvailable = true;
        });
      }
    } catch (e) {
      // GPU not available
    }
  }

  Future<void> _loadKernels() async {
    try {
      final kernels = await kernelService.list();
      if (mounted) {
        setState(() {
          _kernels = kernels;
          if (kernels.isNotEmpty) {
            _selectedKernel = kernels.first;
          }
        });
      }
    } catch (e) {
      // Kernels not available
    }
  }

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
          Text(
            widget.title,
            style: TextStyle(
              color: AppColors.foreground,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          _buildGPUStatus(),
          const SizedBox(width: 16),
          _buildKernelSelector(),
          if (widget.actions != null) ...[
            const SizedBox(width: 16),
            ...widget.actions!,
          ],
          const SizedBox(width: 16),
          _buildHelpButton(),
        ],
      ),
    );
  }

  Widget _buildGPUStatus() {
    final statusColor = _gpuAvailable ? AppColors.success : AppColors.mutedForeground;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _gpuAvailable ? _gpuName : 'No GPU',
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKernelSelector() {
    if (_kernels.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.activity, size: 12, color: AppColors.mutedForeground),
            SizedBox(width: 6),
            Text(
              'No Kernel',
              style: TextStyle(color: AppColors.mutedForeground, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<Kernel>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: AppColors.card,
      onSelected: (kernel) => setState(() => _selectedKernel = kernel),
      itemBuilder: (context) => _kernels.map((kernel) {
        final isSelected = kernel.id == _selectedKernel?.id;
        final statusColor = kernel.status == KernelStatus.idle
            ? AppColors.success
            : kernel.status == KernelStatus.busy
                ? AppColors.warning
                : AppColors.mutedForeground;
        return PopupMenuItem<Kernel>(
          value: kernel,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  kernel.name,
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                Icon(LucideIcons.check, size: 14, color: AppColors.primary),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _selectedKernel?.status == KernelStatus.idle
                    ? AppColors.success
                    : _selectedKernel?.status == KernelStatus.busy
                        ? AppColors.warning
                        : AppColors.mutedForeground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _selectedKernel?.name ?? 'Select Kernel',
              style: TextStyle(color: AppColors.foreground, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 12, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpButton() {
    return _HeaderIconButton(
      icon: LucideIcons.helpCircle,
      onTap: () {},
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.muted : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: _isHovered ? AppColors.foreground : AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}
