import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../models/gpu_status.dart';

class GPUProcesses extends StatelessWidget {
  final List<GPUProcess> processes;

  const GPUProcesses({
    super.key,
    required this.processes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (processes.isEmpty)
            _buildEmptyState()
          else
            ...processes.map((process) => _ProcessRow(process: process)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.listTree,
            size: 16,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(width: 8),
          Text(
            'GPU Processes',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${processes.length} active',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          'No active GPU processes',
          style: TextStyle(
            color: AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _ProcessRow extends StatefulWidget {
  final GPUProcess process;

  const _ProcessRow({required this.process});

  @override
  State<_ProcessRow> createState() => _ProcessRowState();
}

class _ProcessRowState extends State<_ProcessRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isHovered ? AppColors.muted.withOpacity(0.5) : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: AppColors.border),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Icon(
                LucideIcons.terminal,
                size: 14,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.process.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.foreground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'PID: ${widget.process.pid}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${widget.process.memoryUsedMb.toStringAsFixed(0)} MB',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
            if (_isHovered) ...[
              const SizedBox(width: 12),
              _KillButton(onTap: () {}),
            ],
          ],
        ),
      ),
    );
  }
}

class _KillButton extends StatefulWidget {
  final VoidCallback onTap;

  const _KillButton({required this.onTap});

  @override
  State<_KillButton> createState() => _KillButtonState();
}

class _KillButtonState extends State<_KillButton> {
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
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.destructive.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.x,
                size: 12,
                color: _isHovered ? AppColors.destructive : AppColors.mutedForeground,
              ),
              const SizedBox(width: 4),
              Text(
                'Kill',
                style: TextStyle(
                  fontSize: 11,
                  color: _isHovered ? AppColors.destructive : AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
