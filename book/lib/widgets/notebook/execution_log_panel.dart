import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';

/// Log entry for execution output
class LogEntry {
  final DateTime timestamp;
  final String type; // 'stdout', 'stderr', 'error', 'info', 'success'
  final String message;
  final String? cellId;

  LogEntry({
    required this.type,
    required this.message,
    this.cellId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Color get color {
    switch (type) {
      case 'stderr':
      case 'error':
        return Colors.red.shade400;
      case 'success':
        return Colors.green.shade400;
      case 'info':
        return Colors.blue.shade400;
      case 'warning':
        return Colors.orange.shade400;
      default:
        return AppColors.foreground;
    }
  }

  IconData get icon {
    switch (type) {
      case 'stderr':
      case 'error':
        return LucideIcons.alertCircle;
      case 'success':
        return LucideIcons.checkCircle;
      case 'info':
        return LucideIcons.info;
      case 'warning':
        return LucideIcons.alertTriangle;
      default:
        return LucideIcons.terminal;
    }
  }
}

/// Floating panel that shows execution logs in real-time
class ExecutionLogPanel extends StatefulWidget {
  final List<LogEntry> logs;
  final bool isExecuting;
  final VoidCallback? onClear;
  final VoidCallback? onClose;
  final VoidCallback? onMinimize;
  final bool isMinimized;

  const ExecutionLogPanel({
    super.key,
    required this.logs,
    this.isExecuting = false,
    this.onClear,
    this.onClose,
    this.onMinimize,
    this.isMinimized = false,
  });

  @override
  State<ExecutionLogPanel> createState() => _ExecutionLogPanelState();
}

class _ExecutionLogPanelState extends State<ExecutionLogPanel> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void didUpdateWidget(ExecutionLogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to bottom when new logs arrive
    if (_autoScroll && widget.logs.length > oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMinimized) {
      return _buildMinimized();
    }
    return _buildExpanded();
  }

  Widget _buildMinimized() {
    final errorCount = widget.logs.where((l) => l.type == 'error' || l.type == 'stderr').length;

    return Positioned(
      bottom: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(24),
        color: AppColors.card,
        child: InkWell(
          onTap: widget.onMinimize,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isExecuting) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else
                  Icon(LucideIcons.terminal, size: 16, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                Text(
                  'Logs (${widget.logs.length})',
                  style: TextStyle(fontSize: 13, color: AppColors.foreground),
                ),
                if (errorCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$errorCount',
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(12),
        color: AppColors.card,
        child: Container(
          width: 450,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    if (widget.isExecuting) ...[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else
                      Icon(LucideIcons.terminal, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Execution Logs',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                    const Spacer(),
                    // Auto-scroll toggle
                    IconButton(
                      icon: Icon(
                        _autoScroll ? LucideIcons.arrowDownToLine : LucideIcons.pause,
                        size: 14,
                        color: _autoScroll ? AppColors.primary : AppColors.mutedForeground,
                      ),
                      onPressed: () => setState(() => _autoScroll = !_autoScroll),
                      tooltip: _autoScroll ? 'Disable auto-scroll' : 'Enable auto-scroll',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    IconButton(
                      icon: Icon(LucideIcons.trash2, size: 14, color: AppColors.mutedForeground),
                      onPressed: widget.onClear,
                      tooltip: 'Clear logs',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    IconButton(
                      icon: Icon(LucideIcons.minus, size: 14, color: AppColors.mutedForeground),
                      onPressed: widget.onMinimize,
                      tooltip: 'Minimize',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    IconButton(
                      icon: Icon(LucideIcons.x, size: 14, color: AppColors.mutedForeground),
                      onPressed: widget.onClose,
                      tooltip: 'Close',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),
              ),
              // Logs list
              Expanded(
                child: widget.logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.terminal, size: 32, color: AppColors.mutedForeground),
                            const SizedBox(height: 8),
                            Text(
                              'No logs yet',
                              style: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Run a cell to see output here',
                              style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: widget.logs.length,
                        itemBuilder: (context, index) {
                          final log = widget.logs[index];
                          return _buildLogEntry(log);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    final timeStr = '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(width: 8),
          // Icon
          Icon(log.icon, size: 12, color: log.color),
          const SizedBox(width: 6),
          // Message
          Expanded(
            child: SelectableText(
              log.message,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: log.color,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
