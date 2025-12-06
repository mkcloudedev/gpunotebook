class GPUProcess {
  final int pid;
  final String name;
  final double memoryUsedMb;
  final int gpuIndex;

  const GPUProcess({
    required this.pid,
    required this.name,
    required this.memoryUsedMb,
    required this.gpuIndex,
  });
}

class GPUMemory {
  final double used;
  final double total;
  final double free;

  const GPUMemory({
    required this.used,
    required this.total,
    required this.free,
  });

  double get usagePercent => (used / total) * 100;
}

class GPUPower {
  final double draw;
  final double limit;

  const GPUPower({
    required this.draw,
    required this.limit,
  });
}

class GPUStatus {
  final int index;
  final String name;
  final String uuid;
  final double temperature;
  final double utilization;
  final GPUMemory memory;
  final GPUPower power;
  final List<GPUProcess> processes;

  const GPUStatus({
    required this.index,
    required this.name,
    required this.uuid,
    required this.temperature,
    required this.utilization,
    required this.memory,
    required this.power,
    this.processes = const [],
  });
}
