import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';

class GPUStatusCard extends StatelessWidget {
  final String gpuName;
  final double temperature;
  final double utilization;
  final double memoryUsed;
  final double memoryTotal;

  const GPUStatusCard({
    super.key,
    required this.gpuName,
    required this.temperature,
    required this.utilization,
    required this.memoryUsed,
    required this.memoryTotal,
  });

  @override
  Widget build(BuildContext context) {
    final memoryPercent = (memoryUsed / memoryTotal) * 100;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.cpu,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gpuName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMetricRow('Temperature', '${temperature.toInt()}°C', _getTemperatureColor(temperature)),
          const SizedBox(height: 8),
          _buildMetricRow('Utilization', '${utilization.toInt()}%', _getUtilizationColor(utilization)),
          const SizedBox(height: 8),
          _buildMemoryBar(memoryUsed, memoryTotal, memoryPercent),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMemoryBar(double used, double total, double percent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Memory',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
            Text(
              '${used.toStringAsFixed(1)} / ${total.toStringAsFixed(1)} GB',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent / 100,
            backgroundColor: AppColors.muted,
            valueColor: AlwaysStoppedAnimation<Color>(_getMemoryColor(percent)),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Color _getTemperatureColor(double temp) {
    if (temp < 50) return AppColors.success;
    if (temp < 70) return AppColors.warning;
    return AppColors.destructive;
  }

  Color _getUtilizationColor(double util) {
    if (util < 50) return AppColors.success;
    if (util < 80) return AppColors.primary;
    return AppColors.warning;
  }

  Color _getMemoryColor(double percent) {
    if (percent < 60) return AppColors.success;
    if (percent < 85) return AppColors.warning;
    return AppColors.destructive;
  }
}
