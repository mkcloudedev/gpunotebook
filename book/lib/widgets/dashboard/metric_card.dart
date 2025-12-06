import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/metric_data.dart';

class MetricCard extends StatelessWidget {
  final MetricData data;

  const MetricCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Flexible(child: _buildCodeBlock()),
          if (data.sparkJobs != null) _buildSparkJobs(),
          _buildMetricValue(),
          if (data.lastUpdated != null) _buildLastUpdated(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    data.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.foreground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    data.status,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildHeaderIcons(),
        ],
      ),
    );
  }

  Widget _buildHeaderIcons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _HeaderIcon(icon: LucideIcons.play),
        _HeaderIcon(icon: LucideIcons.maximize2),
        _HeaderIcon(icon: LucideIcons.layoutGrid),
      ],
    );
  }

  Widget _buildCodeBlock() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(8),
      color: AppColors.codeBg,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '%spark',
              style: AppTheme.codeText,
            ),
            ...data.code.map((line) => _buildCodeLine(line)),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeLine(String line) {
    if (line.contains('var ')) {
      final parts = line.split('var ');
      return Padding(
        padding: EdgeInsets.only(top: 2),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(text: 'var ', style: AppTheme.codeKeyword),
              TextSpan(text: parts.length > 1 ? parts[1] : '', style: AppTheme.monoStyle),
            ],
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else if (line.contains('"')) {
      final beforeQuote = line.split('"')[0];
      final inQuote = line.split('"').length > 1 ? line.split('"')[1] : '';
      final afterQuote = line.split('"').length > 2 ? line.split('"')[2] : '';
      return Padding(
        padding: EdgeInsets.only(top: 2),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(text: beforeQuote, style: AppTheme.monoStyle),
              TextSpan(text: '"$inQuote"', style: AppTheme.codeString),
              TextSpan(text: afterQuote, style: AppTheme.monoStyle),
            ],
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: 2),
      child: Text(
        line,
        style: AppTheme.monoStyle,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSparkJobs() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.chevronDown,
            size: 14,
            color: AppColors.foreground,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Spark Jobs (${data.sparkJobs})',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.foreground,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricValue() {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Text(
        data.metric,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.foreground,
        ),
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Text(
        data.lastUpdated!,
        style: TextStyle(
          fontSize: 10,
          color: AppColors.mutedForeground,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _HeaderIcon extends StatefulWidget {
  final IconData icon;

  const _HeaderIcon({required this.icon});

  @override
  State<_HeaderIcon> createState() => _HeaderIconState();
}

class _HeaderIconState extends State<_HeaderIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Padding(
        padding: EdgeInsets.only(left: 2),
        child: Icon(
          widget.icon,
          size: 12,
          color: _isHovered ? AppColors.foreground : AppColors.mutedForeground,
        ),
      ),
    );
  }
}
