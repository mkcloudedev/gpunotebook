import '../models/cluster.dart';
import 'api_client.dart';

/// Service for managing GPU cluster nodes
class ClusterService {
  /// Get all cluster nodes
  Future<List<ClusterNode>> listNodes() async {
    try {
      final response = await apiClient.getList('/api/cluster/nodes');
      final nodes = <ClusterNode>[];
      for (final n in response) {
        nodes.add(ClusterNode.fromJson(n as Map<String, dynamic>));
      }
      return nodes;
    } catch (e) {
      return [];
    }
  }

  /// Get a specific node
  Future<ClusterNode?> getNode(String nodeId) async {
    try {
      final response = await apiClient.get('/api/cluster/nodes/$nodeId');
      return ClusterNode.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Add a new node to the cluster
  Future<ClusterNode?> addNode({
    required String name,
    required String host,
    int port = 8888,
    List<String> tags = const [],
    int priority = 0,
  }) async {
    try {
      final response = await apiClient.post('/api/cluster/nodes', {
        'name': name,
        'host': host,
        'port': port,
        'tags': tags,
        'priority': priority,
      });
      return ClusterNode.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Update a node
  Future<ClusterNode?> updateNode(String nodeId, {
    String? name,
    int? port,
    List<String>? tags,
    int? priority,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (port != null) data['port'] = port;
      if (tags != null) data['tags'] = tags;
      if (priority != null) data['priority'] = priority;

      final response = await apiClient.put('/api/cluster/nodes/$nodeId', data);
      return ClusterNode.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Remove a node from the cluster
  Future<bool> removeNode(String nodeId) async {
    try {
      await apiClient.delete('/api/cluster/nodes/$nodeId');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get cluster statistics
  Future<ClusterStats> getStats() async {
    try {
      final response = await apiClient.get('/api/cluster/stats');
      return ClusterStats.fromJson(response);
    } catch (e) {
      return ClusterStats();
    }
  }

  /// Create a kernel on the cluster
  Future<Map<String, dynamic>?> createKernel({
    KernelPlacement? placement,
    String kernelName = 'python3',
  }) async {
    try {
      final data = <String, dynamic>{
        'kernel_name': kernelName,
      };
      if (placement != null) {
        data['placement'] = placement.toJson();
      }

      final response = await apiClient.post('/api/cluster/kernels', data);
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Create a kernel on a specific node
  Future<Map<String, dynamic>?> createKernelOnNode(String nodeId, {
    String kernelName = 'python3',
  }) async {
    try {
      final response = await apiClient.post(
        '/api/cluster/nodes/$nodeId/kernels',
        {'kernel_name': kernelName},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Get the node running a kernel
  Future<ClusterNode?> getKernelNode(String kernelId) async {
    try {
      final response = await apiClient.get('/api/cluster/kernels/$kernelId/node');
      return ClusterNode.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Refresh node status
  Future<ClusterNode?> refreshNode(String nodeId) async {
    try {
      final response = await apiClient.post('/api/cluster/nodes/$nodeId/refresh', {});
      return ClusterNode.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}

/// Global instance
final clusterService = ClusterService();
