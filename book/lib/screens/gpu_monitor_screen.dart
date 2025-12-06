import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_colors.dart';
import '../models/gpu_status.dart';
import '../services/gpu_service.dart' hide GPUStatus, GPUProcess;
import '../widgets/layout/main_layout.dart';

class GPUMonitorScreen extends StatefulWidget {
  const GPUMonitorScreen({super.key});

  @override
  State<GPUMonitorScreen> createState() => _GPUMonitorScreenState();
}

class _GPUMonitorScreenState extends State<GPUMonitorScreen> {
  int _selectedGpuIndex = 0;
  bool _isLoading = true;
  Timer? _refreshTimer;

  List<GPUStatus> _gpus = [];

  @override
  void initState() {
    super.initState();
    _loadGpuData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadGpuData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadGpuData() async {
    try {
      final status = await gpuService.getStatus();
      if (mounted && status.gpus.isNotEmpty) {
        final gpuList = <GPUStatus>[];
        for (var i = 0; i < status.gpus.length; i++) {
          final gpu = status.gpus[i];
          final processes = await gpuService.getProcesses(i);
          gpuList.add(GPUStatus(
            index: gpu.index,
            name: gpu.name,
            uuid: 'GPU-$i',
            temperature: gpu.temperature.toDouble(),
            utilization: gpu.utilizationGpu.toDouble(),
            memory: GPUMemory(
              used: gpu.memoryUsedGB,
              total: gpu.memoryTotalGB,
              free: gpu.memoryTotalGB - gpu.memoryUsedGB,
            ),
            power: GPUPower(
              draw: gpu.powerDraw.toDouble(),
              limit: gpu.powerLimit.toDouble(),
            ),
            processes: processes.map((p) => GPUProcess(
              pid: p.pid,
              name: p.name,
              memoryUsedMb: p.memoryMb.toDouble(),
              gpuIndex: i,
            )).toList(),
          ));
        }
        setState(() {
          _gpus = gpuList;
          _isLoading = false;
          if (_selectedGpuIndex >= _gpus.length) {
            _selectedGpuIndex = 0;
          }
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  GPUStatus? get _selectedGpu => _gpus.isNotEmpty ? _gpus[_selectedGpuIndex] : null;

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'GPU Monitor',
      actions: [
        ElevatedButton.icon(
          onPressed: _loadGpuData,
          icon: Icon(LucideIcons.refreshCw, size: 14),
          label: Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.muted,
            foregroundColor: AppColors.foreground,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ],
      child: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _gpus.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.alertCircle, size: 48, color: AppColors.mutedForeground.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('No GPUs detected', style: TextStyle(color: AppColors.mutedForeground, fontSize: 16)),
                    ],
                  ),
                )
              : Row(
                  children: [
                    // Main content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Card
                            _buildHeaderCard(),
                            const SizedBox(height: 16),
                            // Summary cards
                            _buildSummaryCards(),
                            const SizedBox(height: 16),
                            // GPU Cards
                            _buildGPUCards(),
                          ],
                        ),
                      ),
                    ),
                    // Side panel - GPU Processes
                    _buildSidePanel(),
                  ],
                ),
    );
  }

  Widget _buildHeaderCard() {
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
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.codeBg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Text(
              '%gpu',
              style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.mutedForeground),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GPU Monitor',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.foreground),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_gpus.length} GPUs detected • Last updated: just now',
                      style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: Icon(LucideIcons.download, size: 16),
                      label: Text('Export'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.foreground,
                        side: BorderSide(color: AppColors.border),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: Icon(LucideIcons.refreshCw, size: 16),
                      label: Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryForeground,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalMemory = _gpus.fold<double>(0, (sum, gpu) => sum + gpu.memory.total);
    final usedMemory = _gpus.fold<double>(0, (sum, gpu) => sum + gpu.memory.used);
    final avgTemp = _gpus.fold<double>(0, (sum, gpu) => sum + gpu.temperature) / _gpus.length;
    final totalPower = _gpus.fold<double>(0, (sum, gpu) => sum + gpu.power.draw);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _SummaryCard(
          icon: LucideIcons.cpu,
          label: 'Total GPUs',
          value: '${_gpus.length}',
          color: AppColors.primary,
        ),
        _SummaryCard(
          icon: LucideIcons.hardDrive,
          label: 'Memory Used',
          value: '${usedMemory.toStringAsFixed(1)} / ${totalMemory.toStringAsFixed(0)} GB',
          color: AppColors.success,
        ),
        _SummaryCard(
          icon: LucideIcons.thermometer,
          label: 'Avg Temperature',
          value: '${avgTemp.toInt()}°C',
          color: avgTemp < 60 ? AppColors.success : AppColors.warning,
        ),
        _SummaryCard(
          icon: LucideIcons.zap,
          label: 'Total Power',
          value: '${totalPower.toInt()}W',
          color: AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildGPUCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GPU Devices',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground),
        ),
        const SizedBox(height: 12),
        ...List.generate(_gpus.length, (index) {
          final gpu = _gpus[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _GPUCard(
              gpu: gpu,
              isSelected: index == _selectedGpuIndex,
              onTap: () => setState(() => _selectedGpuIndex = index),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSidePanel() {
    final gpu = _selectedGpu;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text('GPU Processes', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.foreground)),
                const Spacer(),
                Text('${gpu?.processes.length ?? 0} running', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
              ],
            ),
          ),
          // Process list
          Expanded(
            child: (gpu?.processes.isEmpty ?? true)
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.cpu, size: 48, color: AppColors.mutedForeground.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('No active processes', style: TextStyle(color: AppColors.mutedForeground)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(12),
                    itemCount: gpu!.processes.length,
                    itemBuilder: (context, index) {
                      final process = gpu.processes[index];
                      return _ProcessItem(process: process);
                    },
                  ),
          ),
          // Kill all button
          if (gpu != null && gpu.processes.isNotEmpty)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: Icon(LucideIcons.xCircle, size: 16, color: AppColors.destructive),
                  label: Text('Kill All Processes'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.destructive,
                    side: BorderSide(color: AppColors.destructive),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          // GPU Info
          if (gpu != null)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
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
                    Text(gpu.name, style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.foreground)),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Memory', value: '${gpu.memory.used.toStringAsFixed(1)} / ${gpu.memory.total.toStringAsFixed(0)} GB'),
                    _InfoRow(label: 'Utilization', value: '${gpu.utilization}%'),
                    _InfoRow(label: 'Temperature', value: '${gpu.temperature}°C'),
                    _InfoRow(label: 'Power', value: '${gpu.power.draw.toInt()} / ${gpu.power.limit.toInt()} W'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GPUCard extends StatefulWidget {
  final GPUStatus gpu;
  final bool isSelected;
  final VoidCallback onTap;

  const _GPUCard({
    required this.gpu,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_GPUCard> createState() => _GPUCardState();
}

class _GPUCardState extends State<_GPUCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final memoryPercent = widget.gpu.memory.used / widget.gpu.memory.total;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected ? AppColors.primary : (_isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.border),
              width: widget.isSelected ? 2 : 1,
            ),
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
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(LucideIcons.cpu, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.gpu.name, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.foreground)),
                        const SizedBox(height: 4),
                        Text('GPU ${widget.gpu.index}', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text('Active', style: TextStyle(fontSize: 11, color: AppColors.success)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Memory progress bar
              Row(
                children: [
                  Text('Memory', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                  const Spacer(),
                  Text('${widget.gpu.memory.used.toStringAsFixed(1)} / ${widget.gpu.memory.total.toStringAsFixed(0)} GB', style: TextStyle(fontSize: 12, color: AppColors.foreground)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: memoryPercent,
                  backgroundColor: AppColors.muted,
                  valueColor: AlwaysStoppedAnimation(memoryPercent > 0.8 ? AppColors.destructive : AppColors.primary),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatChip(icon: LucideIcons.thermometer, label: '${widget.gpu.temperature}°C'),
                  const SizedBox(width: 12),
                  _StatChip(icon: LucideIcons.activity, label: '${widget.gpu.utilization}%'),
                  const SizedBox(width: 12),
                  _StatChip(icon: LucideIcons.zap, label: '${widget.gpu.power.draw.toInt()}W'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.mutedForeground),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.foreground)),
      ],
    );
  }
}

class _ProcessItem extends StatelessWidget {
  final GPUProcess process;

  const _ProcessItem({required this.process});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(LucideIcons.terminal, size: 16, color: AppColors.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(process.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                Text('PID: ${process.pid}', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${(process.memoryUsedMb / 1024).toStringAsFixed(1)} GB', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.foreground)),
              Text('Memory', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {},
            icon: Icon(LucideIcons.x, size: 14, color: AppColors.destructive),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          Text(value, style: TextStyle(fontSize: 12, color: AppColors.foreground)),
        ],
      ),
    );
  }
}
