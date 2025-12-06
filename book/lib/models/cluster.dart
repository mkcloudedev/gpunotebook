/// Cluster and GPU node models for distributed kernel execution.

enum NodeStatus {
  online,
  offline,
  busy,
  error,
  maintenance;

  String get displayName {
    switch (this) {
      case NodeStatus.online:
        return 'Online';
      case NodeStatus.offline:
        return 'Offline';
      case NodeStatus.busy:
        return 'Busy';
      case NodeStatus.error:
        return 'Error';
      case NodeStatus.maintenance:
        return 'Maintenance';
    }
  }
}

class GPUInfo {
  final int index;
  final String name;
  final int memoryTotal;
  final int memoryUsed;
  final int memoryFree;
  final int utilization;
  final int temperature;
  final double powerUsage;
  final String driverVersion;
  final String cudaVersion;

  GPUInfo({
    this.index = 0,
    this.name = 'Unknown GPU',
    this.memoryTotal = 0,
    this.memoryUsed = 0,
    this.memoryFree = 0,
    this.utilization = 0,
    this.temperature = 0,
    this.powerUsage = 0.0,
    this.driverVersion = '',
    this.cudaVersion = '',
  });

  factory GPUInfo.fromJson(Map<String, dynamic> json) {
    return GPUInfo(
      index: json['index'] ?? 0,
      name: json['name'] ?? 'Unknown GPU',
      memoryTotal: json['memory_total'] ?? 0,
      memoryUsed: json['memory_used'] ?? 0,
      memoryFree: json['memory_free'] ?? 0,
      utilization: json['utilization'] ?? 0,
      temperature: json['temperature'] ?? 0,
      powerUsage: (json['power_usage'] ?? 0.0).toDouble(),
      driverVersion: json['driver_version'] ?? '',
      cudaVersion: json['cuda_version'] ?? '',
    );
  }

  double get memoryUsagePercent => memoryTotal > 0 ? memoryUsed / memoryTotal * 100 : 0;
  String get memoryDisplay => '${(memoryUsed / 1024).toStringAsFixed(1)} / ${(memoryTotal / 1024).toStringAsFixed(1)} GB';
}

class ClusterNode {
  final String id;
  final String name;
  final String host;
  final int port;
  final NodeStatus status;
  final List<GPUInfo> gpus;
  final int cpuCount;
  final int memoryTotal;
  final int memoryAvailable;
  final int activeKernels;
  final int maxKernels;
  final DateTime? lastHeartbeat;
  final DateTime createdAt;
  final List<String> tags;
  final int priority;

  ClusterNode({
    required this.id,
    required this.name,
    required this.host,
    this.port = 8888,
    this.status = NodeStatus.offline,
    this.gpus = const [],
    this.cpuCount = 0,
    this.memoryTotal = 0,
    this.memoryAvailable = 0,
    this.activeKernels = 0,
    this.maxKernels = 10,
    this.lastHeartbeat,
    DateTime? createdAt,
    this.tags = const [],
    this.priority = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ClusterNode.fromJson(Map<String, dynamic> json) {
    return ClusterNode(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      host: json['host'] ?? '',
      port: json['port'] ?? 8888,
      status: _parseStatus(json['status']),
      gpus: (json['gpus'] as List<dynamic>?)
              ?.map((g) => GPUInfo.fromJson(g))
              .toList() ??
          [],
      cpuCount: json['cpu_count'] ?? 0,
      memoryTotal: json['memory_total'] ?? 0,
      memoryAvailable: json['memory_available'] ?? 0,
      activeKernels: json['active_kernels'] ?? 0,
      maxKernels: json['max_kernels'] ?? 10,
      lastHeartbeat: json['last_heartbeat'] != null
          ? DateTime.tryParse(json['last_heartbeat'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      priority: json['priority'] ?? 0,
    );
  }

  static NodeStatus _parseStatus(String? status) {
    switch (status) {
      case 'online':
        return NodeStatus.online;
      case 'busy':
        return NodeStatus.busy;
      case 'error':
        return NodeStatus.error;
      case 'maintenance':
        return NodeStatus.maintenance;
      default:
        return NodeStatus.offline;
    }
  }

  int get totalGpuMemory => gpus.fold(0, (sum, gpu) => sum + gpu.memoryTotal);
  int get freeGpuMemory => gpus.fold(0, (sum, gpu) => sum + gpu.memoryFree);
  bool get isOnline => status == NodeStatus.online;
  bool get hasAvailableSlots => activeKernels < maxKernels;
}

class ClusterStats {
  final int totalNodes;
  final int onlineNodes;
  final int totalGpus;
  final int availableGpus;
  final int totalMemory;
  final int availableMemory;
  final int activeKernels;
  final int maxKernels;

  ClusterStats({
    this.totalNodes = 0,
    this.onlineNodes = 0,
    this.totalGpus = 0,
    this.availableGpus = 0,
    this.totalMemory = 0,
    this.availableMemory = 0,
    this.activeKernels = 0,
    this.maxKernels = 0,
  });

  factory ClusterStats.fromJson(Map<String, dynamic> json) {
    return ClusterStats(
      totalNodes: json['total_nodes'] ?? 0,
      onlineNodes: json['online_nodes'] ?? 0,
      totalGpus: json['total_gpus'] ?? 0,
      availableGpus: json['available_gpus'] ?? 0,
      totalMemory: json['total_memory'] ?? 0,
      availableMemory: json['available_memory'] ?? 0,
      activeKernels: json['active_kernels'] ?? 0,
      maxKernels: json['max_kernels'] ?? 0,
    );
  }

  double get nodeAvailability => totalNodes > 0 ? onlineNodes / totalNodes * 100 : 0;
  double get kernelUtilization => maxKernels > 0 ? activeKernels / maxKernels * 100 : 0;
}

class KernelPlacement {
  final String? nodeId;
  final int? gpuIndex;
  final bool requireGpu;
  final int minGpuMemory;
  final List<String> tags;

  KernelPlacement({
    this.nodeId,
    this.gpuIndex,
    this.requireGpu = true,
    this.minGpuMemory = 0,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      if (nodeId != null) 'node_id': nodeId,
      if (gpuIndex != null) 'gpu_index': gpuIndex,
      'require_gpu': requireGpu,
      'min_gpu_memory': minGpuMemory,
      'tags': tags,
    };
  }
}
