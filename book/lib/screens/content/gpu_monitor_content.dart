import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../services/gpu_service.dart';
import '../../services/gpu_history_service.dart';

class GPUMonitorContent extends StatefulWidget {
  const GPUMonitorContent({super.key});

  @override
  State<GPUMonitorContent> createState() => _GPUMonitorContentState();
}

class _GPUMonitorContentState extends State<GPUMonitorContent> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    // Subscribe to updates from the history service
    _subscription = gpuHistoryService.onUpdate.listen((_) {
      if (mounted) setState(() {});
    });
    // Start auto-refresh if not already running
    gpuHistoryService.startAutoRefresh();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // Getters for service data
  bool get _isLoading => gpuHistoryService.isLoading;
  bool get _hasGpu => gpuHistoryService.hasGpu;
  GPUStatus? get _gpuStatus => gpuHistoryService.currentStatus;
  List<GPUProcess> get _processes => gpuHistoryService.currentProcesses;
  List<double> get _utilizationHistory => gpuHistoryService.utilizationHistory;
  List<double> get _memoryHistory => gpuHistoryService.memoryHistory;
  List<double> get _temperatureHistory => gpuHistoryService.temperatureHistory;

  int get _temperature => _gpuStatus?.temperature ?? 0;
  int get _utilization => _gpuStatus?.utilizationGpu ?? 0;
  int get _memoryUsed => _gpuStatus?.memoryUsed ?? 0;
  int get _memoryTotal => _gpuStatus?.memoryTotal ?? 0;
  int get _powerDraw => _gpuStatus?.powerDraw ?? 0;
  int get _powerLimit => _gpuStatus?.powerLimit ?? 0;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_hasGpu) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.cpu, size: 64, color: AppColors.mutedForeground),
            const SizedBox(height: 16),
            Text(
              'No GPU Detected',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.foreground),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect a CUDA-compatible GPU to view metrics',
              style: TextStyle(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => gpuHistoryService.loadGpuData(),
              icon: Icon(LucideIcons.refreshCw, size: 16),
              label: Text('Retry'),
            ),
          ],
        ),
      );
    }

    final memoryPercent = _memoryTotal > 0 ? (_memoryUsed / _memoryTotal) * 100 : 0.0;
    final powerPercent = _powerLimit > 0 ? (_powerDraw / _powerLimit) * 100 : 0.0;

    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMetricsGrid(memoryPercent, powerPercent),
                  const SizedBox(height: 16),
                  _buildChartsRow(),
                ],
              ),
            ),
          ),
        ),
        _buildProcessesPanel(powerPercent),
      ],
    );
  }

  Widget _buildMetricsGrid(double memoryPercent, double powerPercent) {
    return Row(
      children: [
        Expanded(child: _MetricCard(
          title: 'Temperature',
          value: '$_temperature°C',
          subtitle: 'Core temp',
          icon: LucideIcons.thermometer,
          iconColor: const Color(0xFFFB923C),
          bgColor: const Color(0xFFFB923C).withOpacity(0.2),
          percent: _temperature.toDouble(),
          status: _temperature > 80 ? 'HOT' : 'NORMAL',
        )),
        const SizedBox(width: 16),
        Expanded(child: _MetricCard(
          title: 'Utilization',
          value: '$_utilization%',
          subtitle: 'GPU compute',
          icon: LucideIcons.activity,
          iconColor: const Color(0xFF60A5FA),
          bgColor: const Color(0xFF60A5FA).withOpacity(0.2),
          percent: _utilization.toDouble(),
        )),
        const SizedBox(width: 16),
        Expanded(child: _MetricCard(
          title: 'Memory',
          value: '${(_memoryUsed / 1024).toStringAsFixed(1)} GB',
          subtitle: 'of ${(_memoryTotal / 1024).toStringAsFixed(0)} GB',
          icon: LucideIcons.hardDrive,
          iconColor: const Color(0xFF4ADE80),
          bgColor: const Color(0xFF4ADE80).withOpacity(0.2),
          percent: memoryPercent,
        )),
        const SizedBox(width: 16),
        Expanded(child: _MetricCard(
          title: 'Power',
          value: '${_powerDraw} W',
          subtitle: 'limit $_powerLimit W',
          icon: LucideIcons.zap,
          iconColor: const Color(0xFFFACC15),
          bgColor: const Color(0xFFFACC15).withOpacity(0.2),
          percent: powerPercent,
        )),
      ],
    );
  }

  Widget _buildChartsRow() {
    return Row(
      children: [
        Expanded(child: _ChartCard(
          title: 'GPU Utilization',
          subtitle: 'Last ${_utilizationHistory.length * 2}s',
          color: const Color(0xFF3B82F6),
          data: _utilizationHistory,
          maxValue: 100,
          currentValue: '$_utilization%',
        )),
        const SizedBox(width: 16),
        Expanded(child: _ChartCard(
          title: 'Memory & Temperature',
          subtitle: 'Last ${_memoryHistory.length * 2}s',
          color: const Color(0xFF10B981),
          data: _memoryHistory,
          maxValue: 100,
          secondColor: const Color(0xFFF59E0B),
          secondData: _temperatureHistory,
          secondMaxValue: 100,
          currentValue: '${(_memoryUsed / 1024).toStringAsFixed(1)} GB',
          secondCurrentValue: '$_temperature°C',
        )),
      ],
    );
  }

  Widget _buildProcessesPanel(double powerPercent) {
    return Container(
      width: 288,
      decoration: BoxDecoration(color: AppColors.card, border: Border(left: BorderSide(color: AppColors.border))),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('GPU Processes', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.foreground)),
                Text('${_processes.length} active', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: _processes.length,
              itemBuilder: (context, index) => _ProcessRow(process: _processes[index]),
            ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.zap, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Power Summary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPowerRow('Current', '$_powerDraw W', AppColors.foreground),
                  const SizedBox(height: 4),
                  _buildPowerRow('Limit', '$_powerLimit W', AppColors.foreground),
                  const SizedBox(height: 4),
                  _buildPowerRow('Efficiency', '${powerPercent.toStringAsFixed(0)}%', AppColors.success),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
        Text(value, style: TextStyle(fontSize: 12, color: valueColor)),
      ],
    );
  }
}

class _ProcessRow extends StatelessWidget {
  final GPUProcess process;

  const _ProcessRow({required this.process});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(process.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground), overflow: TextOverflow.ellipsis),
                Text('PID: ${process.pid}', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${(process.memoryMb / 1024).toStringAsFixed(1)} GB', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
              Text('VRAM', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final double percent;
  final String status;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.percent,
    this.status = 'NORMAL',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                    const SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: status == 'NORMAL' ? AppColors.success.withOpacity(0.2) : AppColors.destructive.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(status, style: TextStyle(fontSize: 10, color: status == 'NORMAL' ? AppColors.success : AppColors.destructive)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(LucideIcons.refreshCw, size: 14, color: AppColors.mutedForeground),
                    const SizedBox(width: 8),
                    Icon(LucideIcons.settings, size: 14, color: AppColors.mutedForeground),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, size: 20, color: iconColor),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.foreground)),
                        Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (percent.isNaN || percent.isInfinite) ? 0.0 : (percent / 100).clamp(0.0, 1.0),
                    backgroundColor: AppColors.muted,
                    valueColor: AlwaysStoppedAnimation(percent < 50 ? AppColors.success : percent < 80 ? AppColors.warning : AppColors.destructive),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('${(percent.isNaN || percent.isInfinite) ? 0.0 : percent.clamp(0.0, 100.0).toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<double> data;
  final double maxValue;
  final String? currentValue;
  final Color? secondColor;
  final List<double>? secondData;
  final double? secondMaxValue;
  final String? secondCurrentValue;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.data,
    required this.maxValue,
    this.currentValue,
    this.secondColor,
    this.secondData,
    this.secondMaxValue,
    this.secondCurrentValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.foreground)),
                  if (currentValue != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(currentValue!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                    ),
                  ],
                  if (secondCurrentValue != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: secondColor?.withOpacity(0.2) ?? Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(secondCurrentValue!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondColor)),
                    ),
                  ],
                ],
              ),
              Text(subtitle, style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: data.isEmpty
                ? Center(
                    child: Text('Collecting data...', style: TextStyle(color: AppColors.mutedForeground)),
                  )
                : CustomPaint(
                    size: const Size(double.infinity, double.infinity),
                    painter: _ChartPainter(
                      color: color,
                      data: data,
                      maxValue: maxValue,
                      secondColor: secondColor,
                      secondData: secondData,
                      secondMaxValue: secondMaxValue,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final Color color;
  final List<double> data;
  final double maxValue;
  final Color? secondColor;
  final List<double>? secondData;
  final double? secondMaxValue;

  _ChartPainter({
    required this.color,
    required this.data,
    required this.maxValue,
    this.secondColor,
    this.secondData,
    this.secondMaxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = AppColors.border.withOpacity(0.5)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw first line (with fill)
    _drawLine(canvas, size, data, maxValue, color);

    // Draw second line if provided
    if (secondColor != null && secondData != null && secondData!.isNotEmpty) {
      _drawLine(canvas, size, secondData!, secondMaxValue ?? maxValue, secondColor!);
    }
  }

  void _drawLine(Canvas canvas, Size size, List<double> lineData, double max, Color lineColor) {
    if (lineData.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = lineColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < lineData.length; i++) {
      final x = lineData.length > 1 ? (i / (lineData.length - 1)) * size.width : size.width / 2;
      final normalizedValue = max > 0 ? (lineData[i] / max).clamp(0.0, 1.0) : 0.0;
      final y = size.height - (normalizedValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Complete fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw current value dot
    if (lineData.isNotEmpty) {
      final lastX = size.width;
      final lastNormalized = max > 0 ? (lineData.last / max).clamp(0.0, 1.0) : 0.0;
      final lastY = size.height - (lastNormalized * size.height);

      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(lastX, lastY), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.data.length != data.length ||
        (oldDelegate.data.isNotEmpty && data.isNotEmpty && oldDelegate.data.last != data.last);
  }
}
