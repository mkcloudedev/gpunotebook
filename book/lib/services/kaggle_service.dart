import 'api_client.dart';

// Models
class KaggleDataset {
  final String ref;
  final String title;
  final String size;
  final String lastUpdated;
  final int downloadCount;
  final int voteCount;
  final double usabilityRating;

  KaggleDataset({
    required this.ref,
    required this.title,
    required this.size,
    required this.lastUpdated,
    required this.downloadCount,
    required this.voteCount,
    required this.usabilityRating,
  });

  factory KaggleDataset.fromJson(Map<String, dynamic> json) {
    return KaggleDataset(
      ref: json['ref'] ?? '',
      title: json['title'] ?? '',
      size: json['size'] ?? '0',
      lastUpdated: json['lastUpdated'] ?? '',
      downloadCount: json['downloadCount'] ?? 0,
      voteCount: json['voteCount'] ?? 0,
      usabilityRating: (json['usabilityRating'] ?? 0).toDouble(),
    );
  }

  String get owner => ref.split('/').first;
  String get name => ref.split('/').last;
}

class KaggleCompetition {
  final String ref;
  final String title;
  final String deadline;
  final String category;
  final String reward;
  final int teamCount;
  final bool userHasEntered;

  KaggleCompetition({
    required this.ref,
    required this.title,
    required this.deadline,
    required this.category,
    required this.reward,
    required this.teamCount,
    required this.userHasEntered,
  });

  factory KaggleCompetition.fromJson(Map<String, dynamic> json) {
    return KaggleCompetition(
      ref: json['ref'] ?? '',
      title: json['title'] ?? '',
      deadline: json['deadline'] ?? '',
      category: json['category'] ?? '',
      reward: json['reward'] ?? '',
      teamCount: json['teamCount'] ?? 0,
      userHasEntered: json['userHasEntered'] ?? false,
    );
  }
}

class KaggleKernel {
  final String ref;
  final String title;
  final String author;
  final String lastRunTime;
  final int totalVotes;
  final String language;

  KaggleKernel({
    required this.ref,
    required this.title,
    required this.author,
    required this.lastRunTime,
    required this.totalVotes,
    required this.language,
  });

  factory KaggleKernel.fromJson(Map<String, dynamic> json) {
    return KaggleKernel(
      ref: json['ref'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      lastRunTime: json['lastRunTime'] ?? '',
      totalVotes: json['totalVotes'] ?? 0,
      language: json['language'] ?? '',
    );
  }
}

class KaggleFile {
  final String name;
  final String size;
  final String? description;
  final String? creationDate;

  KaggleFile({
    required this.name,
    required this.size,
    this.description,
    this.creationDate,
  });

  factory KaggleFile.fromJson(Map<String, dynamic> json) {
    return KaggleFile(
      name: json['name'] ?? '',
      size: json['size'] ?? '0',
      description: json['description'],
      creationDate: json['creationDate'],
    );
  }
}

class KaggleSubmission {
  final String fileName;
  final String date;
  final String description;
  final String status;
  final String publicScore;
  final String privateScore;

  KaggleSubmission({
    required this.fileName,
    required this.date,
    required this.description,
    required this.status,
    required this.publicScore,
    required this.privateScore,
  });

  factory KaggleSubmission.fromJson(Map<String, dynamic> json) {
    return KaggleSubmission(
      fileName: json['fileName'] ?? '',
      date: json['date'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? '',
      publicScore: json['publicScore'] ?? '',
      privateScore: json['privateScore'] ?? '',
    );
  }
}

class KaggleStatus {
  final bool configured;
  final String? username;
  final String message;

  KaggleStatus({
    required this.configured,
    this.username,
    required this.message,
  });

  factory KaggleStatus.fromJson(Map<String, dynamic> json) {
    return KaggleStatus(
      configured: json['configured'] ?? false,
      username: json['username'],
      message: json['message'] ?? '',
    );
  }
}

// Service
class KaggleService {
  final ApiClient _api;

  KaggleService({ApiClient? api}) : _api = api ?? apiClient;

  // ============================================================================
  // STATUS & CREDENTIALS
  // ============================================================================

  Future<KaggleStatus> getStatus() async {
    try {
      final response = await _api.get('/api/kaggle/status');
      return KaggleStatus.fromJson(response);
    } catch (e) {
      return KaggleStatus(configured: false, message: 'Error: $e');
    }
  }

  Future<bool> setCredentials(String username, String key) async {
    try {
      await _api.post('/api/kaggle/credentials', {
        'username': username,
        'key': key,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================================
  // DATASETS
  // ============================================================================

  Future<List<KaggleDataset>> listDatasets({
    String sortBy = 'hottest',
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _api.get(
        '/api/kaggle/datasets/list?sort_by=$sortBy&page=$page&page_size=$pageSize',
      );
      final datasets = response['datasets'] as List<dynamic>? ?? [];
      return datasets.map((d) => KaggleDataset.fromJson(d)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<KaggleDataset>> searchDatasets(
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _api.get(
        '/api/kaggle/datasets/search?query=$query&page=$page&page_size=$pageSize',
      );
      final datasets = response['datasets'] as List<dynamic>? ?? [];
      return datasets.map((d) => KaggleDataset.fromJson(d)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> downloadDataset(
    String datasetRef, {
    String? path,
    bool unzip = true,
  }) async {
    try {
      final slug = _extractSlug(datasetRef);
      final response = await _api.post('/api/kaggle/datasets/download', {
        'dataset': slug,
        if (path != null) 'path': path,
        'unzip': unzip,
      });
      return response;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<List<KaggleFile>> getDatasetFiles(String owner, String datasetName) async {
    try {
      final response = await _api.get('/api/kaggle/datasets/$owner/$datasetName/files');
      final files = response['files'] as List<dynamic>? ?? [];
      return files.map((f) => KaggleFile.fromJson(f)).toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================================================
  // COMPETITIONS
  // ============================================================================

  Future<List<KaggleCompetition>> listCompetitions({
    String category = 'all',
    String sortBy = 'latestDeadline',
    int page = 1,
  }) async {
    try {
      final response = await _api.get(
        '/api/kaggle/competitions/list?category=$category&sort_by=$sortBy&page=$page',
      );
      final competitions = response['competitions'] as List<dynamic>? ?? [];
      return competitions.map((c) => KaggleCompetition.fromJson(c)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<KaggleFile>> getCompetitionFiles(String competition) async {
    try {
      final slug = _extractSlug(competition);
      final response = await _api.get('/api/kaggle/competitions/$slug/files');
      final files = response['files'] as List<dynamic>? ?? [];
      return files.map((f) => KaggleFile.fromJson(f)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> downloadCompetitionData(
    String competition, {
    String? path,
    String? file,
  }) async {
    try {
      final slug = _extractSlug(competition);
      final response = await _api.post('/api/kaggle/competitions/download', {
        'competition': slug,
        if (path != null) 'path': path,
        if (file != null) 'file': file,
      });
      return response;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<List<KaggleSubmission>> getSubmissions(String competition) async {
    try {
      // Extract slug from full URL if needed
      final slug = _extractSlug(competition);
      final response = await _api.get('/api/kaggle/competitions/$slug/submissions');
      final submissions = response['submissions'] as List<dynamic>? ?? [];
      return submissions.map((s) => KaggleSubmission.fromJson(s)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Extract slug from Kaggle URL or return as-is if already a slug
  String _extractSlug(String refOrUrl) {
    // If it's a full URL like https://www.kaggle.com/competitions/name or https://www.kaggle.com/datasets/user/name
    if (refOrUrl.startsWith('http')) {
      final uri = Uri.tryParse(refOrUrl);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        // For competitions: /competitions/name -> name
        // For datasets: /datasets/user/name -> user/name
        // For kernels: /code/user/name -> user/name
        final segments = uri.pathSegments;
        if (segments.length >= 2) {
          if (segments[0] == 'competitions') {
            return segments[1];
          } else if (segments[0] == 'datasets' || segments[0] == 'code') {
            return segments.skip(1).join('/');
          }
        }
      }
    }
    return refOrUrl;
  }

  // ============================================================================
  // KERNELS / NOTEBOOKS
  // ============================================================================

  Future<List<KaggleKernel>> listKernels({
    String sortBy = 'hotness',
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _api.get(
        '/api/kaggle/kernels/list?sort_by=$sortBy&page=$page&page_size=$pageSize',
      );
      final kernels = response['kernels'] as List<dynamic>? ?? [];
      return kernels.map((k) => KaggleKernel.fromJson(k)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<KaggleKernel>> searchKernels(
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _api.get(
        '/api/kaggle/kernels/search?query=$query&page=$page&page_size=$pageSize',
      );
      final kernels = response['kernels'] as List<dynamic>? ?? [];
      return kernels.map((k) => KaggleKernel.fromJson(k)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> pullKernel(String kernelRef, {String? path}) async {
    try {
      final slug = _extractSlug(kernelRef);
      final response = await _api.post('/api/kaggle/kernels/pull', {
        'kernel_ref': slug,
        if (path != null) 'path': path,
      });
      return response;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}

final kaggleService = KaggleService();
