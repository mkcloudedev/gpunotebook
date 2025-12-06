import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Service for managing Python packages via pip
class PipService {
  String get _baseUrl => ApiClient.baseUrl;

  /// Get list of installed packages
  Future<List<PipPackage>> listInstalled() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/packages'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final packages = data['packages'] as List<dynamic>? ?? [];
        return packages.map((p) => PipPackage.fromJson(p)).toList();
      }
    } catch (e) {
      print('Error listing packages: $e');
    }
    return [];
  }

  /// Install a package
  Future<PipInstallResult> install(String packageName, {String? version}) async {
    try {
      final body = {
        'package': version != null ? '$packageName==$version' : packageName,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/packages/install'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PipInstallResult(
          success: data['success'] ?? false,
          message: data['message'] ?? '',
          output: data['output'] ?? '',
        );
      } else {
        final data = jsonDecode(response.body);
        return PipInstallResult(
          success: false,
          message: data['detail'] ?? 'Installation failed',
          output: '',
        );
      }
    } catch (e) {
      return PipInstallResult(
        success: false,
        message: 'Error: $e',
        output: '',
      );
    }
  }

  /// Uninstall a package
  Future<PipInstallResult> uninstall(String packageName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/packages/uninstall'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'package': packageName}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PipInstallResult(
          success: data['success'] ?? false,
          message: data['message'] ?? '',
          output: data['output'] ?? '',
        );
      } else {
        final data = jsonDecode(response.body);
        return PipInstallResult(
          success: false,
          message: data['detail'] ?? 'Uninstallation failed',
          output: '',
        );
      }
    } catch (e) {
      return PipInstallResult(
        success: false,
        message: 'Error: $e',
        output: '',
      );
    }
  }

  /// Search PyPI for packages
  Future<List<PyPIPackage>> search(String query) async {
    if (query.isEmpty) return [];

    try {
      // Use PyPI JSON API for search
      final response = await http.get(
        Uri.parse('https://pypi.org/pypi/$query/json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final info = data['info'] as Map<String, dynamic>;
        return [
          PyPIPackage(
            name: info['name'] ?? query,
            version: info['version'] ?? '',
            summary: info['summary'] ?? '',
            author: info['author'] ?? '',
            homePage: info['home_page'] ?? '',
            license: info['license'] ?? '',
          ),
        ];
      }
    } catch (e) {
      print('Error searching PyPI: $e');
    }

    // If exact match fails, try to get suggestions
    return await _searchSuggestions(query);
  }

  /// Get package suggestions from PyPI
  Future<List<PyPIPackage>> _searchSuggestions(String query) async {
    try {
      // Use PyPI simple API to get matching packages
      final response = await http.get(
        Uri.parse('https://pypi.org/simple/'),
      );

      if (response.statusCode == 200) {
        final html = response.body;
        final regex = RegExp(r'>([^<]+)</a>', multiLine: true);
        final matches = regex.allMatches(html);

        final suggestions = <PyPIPackage>[];
        final queryLower = query.toLowerCase();

        for (final match in matches) {
          final name = match.group(1);
          if (name != null && name.toLowerCase().contains(queryLower)) {
            suggestions.add(PyPIPackage(
              name: name,
              version: '',
              summary: '',
              author: '',
              homePage: '',
              license: '',
            ));
            if (suggestions.length >= 20) break;
          }
        }

        return suggestions;
      }
    } catch (e) {
      print('Error getting suggestions: $e');
    }
    return [];
  }

  /// Get package details from PyPI
  Future<PyPIPackage?> getPackageInfo(String packageName) async {
    try {
      final response = await http.get(
        Uri.parse('https://pypi.org/pypi/$packageName/json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final info = data['info'] as Map<String, dynamic>;
        final releases = data['releases'] as Map<String, dynamic>? ?? {};

        return PyPIPackage(
          name: info['name'] ?? packageName,
          version: info['version'] ?? '',
          summary: info['summary'] ?? '',
          author: info['author'] ?? '',
          homePage: info['home_page'] ?? info['project_url'] ?? '',
          license: info['license'] ?? '',
          description: info['description'] ?? '',
          requiresPython: info['requires_python'] ?? '',
          versions: releases.keys.toList().reversed.take(20).toList(),
        );
      }
    } catch (e) {
      print('Error getting package info: $e');
    }
    return null;
  }

  /// Get outdated packages
  Future<List<OutdatedPackage>> checkOutdated() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/packages/outdated'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final packages = data['packages'] as List<dynamic>? ?? [];
        return packages.map((p) => OutdatedPackage.fromJson(p)).toList();
      }
    } catch (e) {
      print('Error checking outdated: $e');
    }
    return [];
  }

  /// Upgrade a package
  Future<PipInstallResult> upgrade(String packageName) async {
    return install(packageName);
  }

  /// Export requirements.txt
  Future<String> exportRequirements() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/packages/requirements'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['requirements'] ?? '';
      }
    } catch (e) {
      print('Error exporting requirements: $e');
    }
    return '';
  }

  /// Install from requirements.txt content
  Future<PipInstallResult> installFromRequirements(String requirements) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/packages/install-requirements'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requirements': requirements}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PipInstallResult(
          success: data['success'] ?? false,
          message: data['message'] ?? '',
          output: data['output'] ?? '',
        );
      }
    } catch (e) {
      return PipInstallResult(
        success: false,
        message: 'Error: $e',
        output: '',
      );
    }
    return PipInstallResult(
      success: false,
      message: 'Unknown error',
      output: '',
    );
  }
}

/// Installed pip package
class PipPackage {
  final String name;
  final String version;
  final String location;

  const PipPackage({
    required this.name,
    required this.version,
    this.location = '',
  });

  factory PipPackage.fromJson(Map<String, dynamic> json) {
    return PipPackage(
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '',
      location: json['location'] as String? ?? '',
    );
  }
}

/// PyPI package info
class PyPIPackage {
  final String name;
  final String version;
  final String summary;
  final String author;
  final String homePage;
  final String license;
  final String description;
  final String requiresPython;
  final List<String> versions;

  const PyPIPackage({
    required this.name,
    required this.version,
    required this.summary,
    required this.author,
    required this.homePage,
    required this.license,
    this.description = '',
    this.requiresPython = '',
    this.versions = const [],
  });
}

/// Pip install result
class PipInstallResult {
  final bool success;
  final String message;
  final String output;

  const PipInstallResult({
    required this.success,
    required this.message,
    required this.output,
  });
}

/// Outdated package info
class OutdatedPackage {
  final String name;
  final String currentVersion;
  final String latestVersion;

  const OutdatedPackage({
    required this.name,
    required this.currentVersion,
    required this.latestVersion,
  });

  factory OutdatedPackage.fromJson(Map<String, dynamic> json) {
    return OutdatedPackage(
      name: json['name'] as String? ?? '',
      currentVersion: json['current_version'] as String? ?? json['version'] as String? ?? '',
      latestVersion: json['latest_version'] as String? ?? json['latest'] as String? ?? '',
    );
  }
}

/// Global pip service instance
final pipService = PipService();
