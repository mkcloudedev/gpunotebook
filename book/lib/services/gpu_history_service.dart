import 'dart:async';
import 'gpu_service.dart';

class GPUHistoryService {
  static final GPUHistoryService _instance = GPUHistoryService._internal();
  factory GPUHistoryService() => _instance;
  GPUHistoryService._internal();

  // Historical data (persists across page navigation)
  final List<double> utilizationHistory = [];
  final List<double> memoryHistory = [];
  final List<double> temperatureHistory = [];
  static const int maxHistoryLength = 60; // 2 minutes of data at 2s intervals

  // Current values
  GPUStatus? currentStatus;
  List<GPUProcess> currentProcesses = [];
  bool hasGpu = false;
  bool isLoading = true;

  // Auto-refresh
  Timer? _timer;
  bool _autoRefresh = true;
  final _controller = StreamController<void>.broadcast();

  Stream<void> get onUpdate => _controller.stream;

  void startAutoRefresh() {
    _timer?.cancel();
    if (_autoRefresh) {
      // Load immediately
      loadGpuData();
      // Then refresh every 2 seconds
      _timer = Timer.periodic(const Duration(seconds: 2), (_) {
        loadGpuData();
      });
    }
  }

  void stopAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  void setAutoRefresh(bool value) {
    _autoRefresh = value;
    if (value) {
      startAutoRefresh();
    } else {
      stopAutoRefresh();
    }
  }

  Future<void> loadGpuData() async {
    try {
      final status = await gpuService.getStatus();
      if (status.primaryGpu != null) {
        final processes = await gpuService.getProcesses(0);

        currentStatus = status.primaryGpu;
        currentProcesses = processes;
        hasGpu = true;
        isLoading = false;

        // Update history
        _addToHistory(utilizationHistory, currentStatus!.utilizationGpu.toDouble());
        final memPercent = currentStatus!.memoryTotal > 0
            ? (currentStatus!.memoryUsed / currentStatus!.memoryTotal) * 100
            : 0.0;
        _addToHistory(memoryHistory, memPercent);
        _addToHistory(temperatureHistory, currentStatus!.temperature.toDouble());

        _controller.add(null);
      } else {
        hasGpu = false;
        isLoading = false;
        _controller.add(null);
      }
    } catch (e) {
      hasGpu = false;
      isLoading = false;
      _controller.add(null);
    }
  }

  void _addToHistory(List<double> history, double value) {
    history.add(value);
    if (history.length > maxHistoryLength) {
      history.removeAt(0);
    }
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

final gpuHistoryService = GPUHistoryService();
