import 'api_client.dart';

class GPUStatus {
  final int index;
  final String name;
  final int temperature;
  final int utilizationGpu;
  final int memoryUsed;
  final int memoryTotal;
  final int powerDraw;
  final int powerLimit;
  final String driverVersion;
  final String cudaVersion;

  GPUStatus({
    required this.index,
    required this.name,
    required this.temperature,
    required this.utilizationGpu,
    required this.memoryUsed,
    required this.memoryTotal,
    required this.powerDraw,
    required this.powerLimit,
    required this.driverVersion,
    required this.cudaVersion,
  });

  factory GPUStatus.fromJson(Map<String, dynamic> json) {
    return GPUStatus(
      index: json['index'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown GPU',
      temperature: json['temperature_c'] as int? ?? json['temperature'] as int? ?? 0,
      utilizationGpu: json['utilization_percent'] as int? ?? json['utilization_gpu'] as int? ?? 0,
      memoryUsed: json['memory_used_mb'] as int? ?? json['memory_used'] as int? ?? 0,
      memoryTotal: json['memory_total_mb'] as int? ?? json['memory_total'] as int? ?? 0,
      powerDraw: (json['power_draw_w'] as num?)?.toInt() ?? json['power_draw'] as int? ?? 0,
      powerLimit: (json['power_limit_w'] as num?)?.toInt() ?? json['power_limit'] as int? ?? 0,
      driverVersion: json['driver_version'] as String? ?? '',
      cudaVersion: json['cuda_version'] as String? ?? '',
    );
  }

  double get memoryUsedGB => memoryUsed / 1024;
  double get memoryTotalGB => memoryTotal / 1024;
  double get memoryPercent => memoryTotal > 0 ? (memoryUsed / memoryTotal) * 100 : 0;
  double get powerPercent => powerLimit > 0 ? (powerDraw / powerLimit) * 100 : 0;
}

class GPUProcess {
  final int pid;
  final String name;
  final int memoryMb;

  GPUProcess({required this.pid, required this.name, required this.memoryMb});

  factory GPUProcess.fromJson(Map<String, dynamic> json) {
    return GPUProcess(
      pid: json['pid'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      memoryMb: json['memory_used_mb'] as int? ?? json['memory_mb'] as int? ?? json['memory'] as int? ?? 0,
    );
  }
}

class GPUSystemStatus {
  final List<GPUStatus> gpus;
  final String driverVersion;
  final String cudaVersion;

  GPUSystemStatus({
    required this.gpus,
    required this.driverVersion,
    required this.cudaVersion,
  });

  factory GPUSystemStatus.fromJson(Map<String, dynamic> json) {
    return GPUSystemStatus(
      gpus: (json['gpus'] as List<dynamic>?)
              ?.map((g) => GPUStatus.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
      driverVersion: json['driver_version'] as String? ?? '',
      cudaVersion: json['cuda_version'] as String? ?? '',
    );
  }

  GPUStatus? get primaryGpu => gpus.isNotEmpty ? gpus.first : null;
}

class GpuService {
  final ApiClient _api;

  GpuService({ApiClient? api}) : _api = api ?? apiClient;

  Future<GPUSystemStatus> getStatus() async {
    try {
      final response = await _api.get('/api/gpu');
      return GPUSystemStatus.fromJson(response);
    } catch (e) {
      return GPUSystemStatus(gpus: [], driverVersion: '', cudaVersion: '');
    }
  }

  Future<GPUStatus?> getGPU(int index) async {
    try {
      final response = await _api.get('/api/gpu/$index');
      return GPUStatus.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<GPUProcess>> getProcesses(int index) async {
    try {
      final response = await _api.get('/api/gpu/$index/processes');
      final processes = response['processes'] as List<dynamic>? ?? [];
      return processes.map((p) => GPUProcess.fromJson(p as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }
}

final gpuService = GpuService();
