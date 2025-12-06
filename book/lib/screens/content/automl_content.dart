import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../services/automl_service.dart';
import '../../services/file_service.dart';

class AutoMLContent extends StatefulWidget {
  const AutoMLContent({super.key});

  @override
  State<AutoMLContent> createState() => AutoMLContentState();
}

class AutoMLContentState extends State<AutoMLContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Data
  List<Algorithm> _algorithms = [];
  List<AutoMLExperiment> _experiments = [];
  List<AlgorithmRecommendation> _recommendations = [];
  Map<String, List<Algorithm>> _algorithmsByCategory = {};

  // Selected
  String? _selectedCategory;
  String? _selectedTaskType;
  Algorithm? _selectedAlgorithm;

  // Filters
  bool _gpuOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        automlService.listAlgorithms(gpuOnly: _gpuOnly),
        automlService.listExperiments(),
      ]);

      final algorithms = results[0] as List<Algorithm>;
      final experiments = results[1] as List<AutoMLExperiment>;

      // Group by category
      final byCategory = <String, List<Algorithm>>{};
      for (final algo in algorithms) {
        byCategory.putIfAbsent(algo.category, () => []).add(algo);
      }

      setState(() {
        _algorithms = algorithms;
        _experiments = experiments;
        _algorithmsByCategory = byCategory;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _getRecommendations() async {
    // Show dialog to get parameters
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _RecommendationDialog(),
    );

    if (result == null) return;

    setState(() => _isLoading = true);
    try {
      final recommendations = await automlService.getRecommendations(
        taskType: result['task_type'],
        nSamples: result['n_samples'],
        nFeatures: result['n_features'],
        hasCategorical: result['has_categorical'] ?? false,
        hasMissing: result['has_missing'] ?? false,
        needInterpretability: result['need_interpretability'] ?? false,
        needSpeed: result['need_speed'] ?? false,
        hasGpu: result['has_gpu'] ?? false,
      );

      setState(() {
        _recommendations = recommendations;
        _isLoading = false;
      });

      // Switch to recommendations tab
      _tabController.animateTo(2);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting recommendations: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createExperiment() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateExperimentDialog(algorithms: _algorithms),
    );

    if (result == null) return;

    setState(() => _isLoading = true);
    try {
      await automlService.createExperiment(
        name: result['name'],
        datasetPath: result['dataset_path'],
        targetColumn: result['target_column'],
        taskType: result['task_type'],
        algorithms: result['algorithms'],
        maxTimeMinutes: result['max_time_minutes'],
      );

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Experiment started!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating experiment: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Main content
        Expanded(
          child: Column(
            children: [
              // Header with tabs
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.mutedForeground,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.cpu, size: 16),
                          const SizedBox(width: 8),
                          Text('Algorithms'),
                          const SizedBox(width: 6),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${_algorithms.length}', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.flaskConical, size: 16),
                          const SizedBox(width: 8),
                          Text('Experiments'),
                          if (_experiments.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${_experiments.length}', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.sparkles, size: 16),
                          const SizedBox(width: 8),
                          Text('Recommendations'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAlgorithmsTab(),
                          _buildExperimentsTab(),
                          _buildRecommendationsTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),

        // Side panel
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border(left: BorderSide(color: AppColors.border)),
          ),
          child: _buildSidePanel(),
        ),
      ],
    );
  }

  Widget _buildAlgorithmsTab() {
    return Row(
      children: [
        // Category list
        Container(
          width: 200,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.border.withOpacity(0.5))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Checkbox(
                      value: _gpuOnly,
                      onChanged: (v) {
                        setState(() => _gpuOnly = v ?? false);
                        _loadData();
                      },
                      activeColor: AppColors.primary,
                    ),
                    Text('GPU Only', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    _buildCategoryItem(null, 'All Categories', _algorithms.length),
                    Divider(height: 16),
                    ..._algorithmsByCategory.entries.map((e) =>
                      _buildCategoryItem(e.key, _formatCategory(e.key), e.value.length)
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Algorithm list
        Expanded(
          child: _buildAlgorithmList(),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(String? category, String label, int count) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: EdgeInsets.only(bottom: 2),
      child: ListTile(
        dense: true,
        selected: isSelected,
        selectedTileColor: AppColors.primary.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        leading: Icon(_getCategoryIcon(category ?? ''), size: 18, color: isSelected ? AppColors.primary : AppColors.mutedForeground),
        title: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.border.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: TextStyle(fontSize: 11)),
        ),
        onTap: () => setState(() => _selectedCategory = category),
      ),
    );
  }

  Widget _buildAlgorithmList() {
    var filtered = _algorithms;
    if (_selectedCategory != null) {
      filtered = filtered.where((a) => a.category == _selectedCategory).toList();
    }
    if (_selectedTaskType != null) {
      filtered = filtered.where((a) => a.taskTypes.contains(_selectedTaskType)).toList();
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final algo = filtered[index];
        final isSelected = _selectedAlgorithm?.id == algo.id;

        return _AlgorithmCard(
          algorithm: algo,
          isSelected: isSelected,
          onTap: () => setState(() => _selectedAlgorithm = algo),
        );
      },
    );
  }

  Widget _buildExperimentsTab() {
    if (_experiments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.flaskConical, size: 64, color: AppColors.mutedForeground.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No experiments yet', style: TextStyle(color: AppColors.mutedForeground, fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _createExperiment,
              icon: Icon(LucideIcons.plus, size: 16),
              label: Text('Create Experiment'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _experiments.length,
      itemBuilder: (context, index) {
        final exp = _experiments[index];
        return _ExperimentCard(
          experiment: exp,
          onDelete: () async {
            await automlService.deleteExperiment(exp.id);
            _loadData();
          },
          onStop: exp.status == 'running' ? () async {
            await automlService.stopExperiment(exp.id);
            _loadData();
          } : null,
        );
      },
    );
  }

  Widget _buildRecommendationsTab() {
    if (_recommendations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.sparkles, size: 64, color: AppColors.mutedForeground.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('Get AI-powered recommendations', style: TextStyle(color: AppColors.mutedForeground, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Based on your data characteristics', style: TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _getRecommendations,
              icon: Icon(LucideIcons.sparkles, size: 16),
              label: Text('Get Recommendations'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _recommendations.length,
      itemBuilder: (context, index) {
        final rec = _recommendations[index];
        return _RecommendationCard(
          recommendation: rec,
          rank: index + 1,
          onSelect: () => setState(() {
            _selectedAlgorithm = rec.algorithm;
            _tabController.animateTo(0);
          }),
        );
      },
    );
  }

  Widget _buildSidePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.brain, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('AutoML', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
        ),

        // Quick Stats
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick Stats', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.mutedForeground, fontSize: 12)),
              const SizedBox(height: 12),
              _buildStatRow(LucideIcons.cpu, 'Algorithms', '${_algorithms.length}'),
              _buildStatRow(LucideIcons.zap, 'GPU Accelerated', '${_algorithms.where((a) => a.gpuAccelerated).length}'),
              _buildStatRow(LucideIcons.flaskConical, 'Experiments', '${_experiments.length}'),
              _buildStatRow(LucideIcons.checkCircle, 'Completed', '${_experiments.where((e) => e.status == "completed").length}'),
            ],
          ),
        ),

        Divider(height: 1),

        // Actions
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Actions', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.mutedForeground, fontSize: 12)),
              const SizedBox(height: 12),
              _buildActionButton(LucideIcons.plus, 'New Experiment', _createExperiment),
              _buildActionButton(LucideIcons.sparkles, 'Get Recommendations', _getRecommendations),
              _buildActionButton(LucideIcons.refreshCw, 'Refresh', _loadData),
            ],
          ),
        ),

        Divider(height: 1),

        // Selected Algorithm Details
        if (_selectedAlgorithm != null) ...[
          Expanded(
            child: _buildAlgorithmDetails(_selectedAlgorithm!),
          ),
        ] else ...[
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.mousePointerClick, size: 32, color: AppColors.mutedForeground.withOpacity(0.5)),
                  const SizedBox(height: 8),
                  Text('Select an algorithm', style: TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],

        // Task Type Filter
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter by Task', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.mutedForeground, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildTaskChip(null, 'All'),
                  _buildTaskChip('classification', 'Classification'),
                  _buildTaskChip('regression', 'Regression'),
                  _buildTaskChip('clustering', 'Clustering'),
                  _buildTaskChip('anomaly_detection', 'Anomaly'),
                  _buildTaskChip('time_series', 'Time Series'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.mutedForeground),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskChip(String? taskType, String label) {
    final isSelected = _selectedTaskType == taskType;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedTaskType = selected ? taskType : null);
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      padding: EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAlgorithmDetails(Algorithm algo) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (algo.gpuAccelerated)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.zap, size: 12, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text('GPU', style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(algo.library, style: TextStyle(fontSize: 10, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(algo.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          Text(algo.description, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),

          const SizedBox(height: 16),
          Text('Complexity: ${algo.complexity}', style: TextStyle(fontSize: 12)),

          const SizedBox(height: 16),
          Text('Pros', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.green)),
          const SizedBox(height: 4),
          ...algo.pros.map((p) => Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.check, size: 12, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(child: Text(p, style: TextStyle(fontSize: 11))),
              ],
            ),
          )),

          const SizedBox(height: 12),
          Text('Cons', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.orange)),
          const SizedBox(height: 4),
          ...algo.cons.map((c) => Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.x, size: 12, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(child: Text(c, style: TextStyle(fontSize: 11))),
              ],
            ),
          )),

          const SizedBox(height: 16),
          Text('Hyperparameters', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 8),
          ...algo.hyperparameters.map((h) => Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.border.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(h['name'] ?? '', style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
                ),
                const SizedBox(width: 8),
                Text('${h['type']}', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  String _formatCategory(String category) {
    return category.replaceAll('_', ' ').split(' ').map((w) =>
      w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w
    ).join(' ');
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'linear': return LucideIcons.trendingUp;
      case 'tree_based': return LucideIcons.gitBranch;
      case 'ensemble': return LucideIcons.layers;
      case 'neural_network': return LucideIcons.brain;
      case 'svm': return LucideIcons.divide;
      case 'neighbors': return LucideIcons.users;
      case 'clustering': return LucideIcons.hexagon;
      case 'bayesian': return LucideIcons.pieChart;
      case 'dimensionality': return LucideIcons.minimize2;
      case 'boosting': return LucideIcons.rocket;
      case 'deep_learning': return LucideIcons.cpu;
      case 'transformer': return LucideIcons.sparkles;
      default: return LucideIcons.box;
    }
  }
}

// =============================================================================
// ALGORITHM CARD
// =============================================================================

class _AlgorithmCard extends StatelessWidget {
  final Algorithm algorithm;
  final bool isSelected;
  final VoidCallback onTap;

  const _AlgorithmCard({
    required this.algorithm,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      algorithm.name,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  if (algorithm.gpuAccelerated)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.zap, size: 12, color: Colors.green[700]),
                          const SizedBox(width: 4),
                          Text('GPU', style: TextStyle(fontSize: 10, color: Colors.green[700])),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(algorithm.library, style: TextStyle(fontSize: 10, color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                algorithm.description,
                style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: algorithm.taskTypes.map((t) => Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.border.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(t, style: TextStyle(fontSize: 10)),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// EXPERIMENT CARD
// =============================================================================

class _ExperimentCard extends StatelessWidget {
  final AutoMLExperiment experiment;
  final VoidCallback onDelete;
  final VoidCallback? onStop;

  const _ExperimentCard({
    required this.experiment,
    required this.onDelete,
    this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(experiment.status);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(experiment.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (experiment.status == 'running')
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(statusColor)),
                        )
                      else
                        Icon(_getStatusIcon(experiment.status), size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(experiment.status.toUpperCase(), style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (onStop != null)
                  IconButton(
                    icon: Icon(LucideIcons.square, size: 16),
                    onPressed: onStop,
                    tooltip: 'Stop',
                    color: Colors.orange,
                  ),
                IconButton(
                  icon: Icon(LucideIcons.trash2, size: 16),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  color: Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Dataset info
            Row(
              children: [
                _buildInfoChip(LucideIcons.database, '${experiment.datasetInfo.nSamples} samples'),
                const SizedBox(width: 8),
                _buildInfoChip(LucideIcons.columns, '${experiment.datasetInfo.nFeatures} features'),
                const SizedBox(width: 8),
                _buildInfoChip(LucideIcons.target, experiment.taskType),
              ],
            ),

            const SizedBox(height: 12),

            // Progress
            if (experiment.status == 'running' || experiment.status == 'completed') ...[
              Row(
                children: [
                  Text('Models trained: ${experiment.models.length}/${experiment.algorithmsToTry.length}',
                    style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                  const Spacer(),
                  if (experiment.bestModel != null)
                    Text('Best: ${experiment.bestModel!.algorithmName}',
                      style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: experiment.algorithmsToTry.isEmpty ? 0 : experiment.models.length / experiment.algorithmsToTry.length,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ],

            // Best model scores
            if (experiment.bestModel != null) ...[
              const SizedBox(height: 12),
              _buildScoreRow(experiment.bestModel!.scores, experiment.taskType),
            ],

            // Recommendations
            if (experiment.bestModel != null && experiment.bestModel!.recommendations.isNotEmpty) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                title: Text('Recommendations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.only(top: 8),
                children: experiment.bestModel!.recommendations.map((r) => Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.lightbulb, size: 14, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r, style: TextStyle(fontSize: 12))),
                    ],
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.border.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.mutedForeground),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
        ],
      ),
    );
  }

  Widget _buildScoreRow(ModelScore scores, String taskType) {
    Map<String, double?> scoreMap;
    if (taskType == 'classification') {
      scoreMap = scores.classificationScores;
    } else if (taskType == 'regression') {
      scoreMap = scores.regressionScores;
    } else if (taskType == 'clustering') {
      scoreMap = scores.clusteringScores;
    } else {
      scoreMap = scores.classificationScores;
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: scoreMap.entries.where((e) => e.value != null).map((e) =>
        _buildScoreChip(e.key, e.value!)
      ).toList(),
    );
  }

  Widget _buildScoreChip(String name, double value) {
    final color = value > 0.8 ? Colors.green : (value > 0.6 ? Colors.orange : Colors.red);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: TextStyle(fontSize: 10, color: color)),
          const SizedBox(width: 4),
          Text(value.toStringAsFixed(3), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'running': return Colors.blue;
      case 'completed': return Colors.green;
      case 'failed': return Colors.red;
      default: return AppColors.mutedForeground;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'running': return LucideIcons.loader;
      case 'completed': return LucideIcons.checkCircle;
      case 'failed': return LucideIcons.xCircle;
      default: return LucideIcons.clock;
    }
  }
}

// =============================================================================
// RECOMMENDATION CARD
// =============================================================================

class _RecommendationCard extends StatelessWidget {
  final AlgorithmRecommendation recommendation;
  final int rank;
  final VoidCallback onSelect;

  const _RecommendationCard({
    required this.recommendation,
    required this.rank,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = recommendation.score > 80 ? Colors.green :
                       (recommendation.score > 60 ? Colors.orange : Colors.red);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: rank == 1 ? Colors.amber : AppColors.border, width: rank == 1 ? 2 : 1),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rank badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: rank == 1 ? Colors.amber : AppColors.border,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('#$rank', style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rank == 1 ? Colors.white : AppColors.mutedForeground,
                  fontSize: 12,
                )),
              ),

              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(recommendation.algorithm.name,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: scoreColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${recommendation.score}%',
                            style: TextStyle(fontSize: 12, color: scoreColor, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(recommendation.algorithm.description,
                      style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: recommendation.reasons.map((r) => Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(r, style: TextStyle(fontSize: 10, color: AppColors.primary)),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DIALOGS
// =============================================================================

class _RecommendationDialog extends StatefulWidget {
  @override
  State<_RecommendationDialog> createState() => _RecommendationDialogState();
}

class _RecommendationDialogState extends State<_RecommendationDialog> {
  String _taskType = 'classification';
  int _nSamples = 1000;
  int _nFeatures = 10;
  bool _hasCategorical = false;
  bool _hasMissing = false;
  bool _needInterpretability = false;
  bool _needSpeed = false;
  bool _hasGpu = false;

  final _taskTypeInfo = {
    'classification': {'icon': LucideIcons.tag, 'color': Colors.blue, 'desc': 'Predict categories or labels'},
    'regression': {'icon': LucideIcons.trendingUp, 'color': Colors.green, 'desc': 'Predict continuous values'},
    'clustering': {'icon': LucideIcons.hexagon, 'color': Colors.purple, 'desc': 'Group similar data points'},
    'anomaly_detection': {'icon': LucideIcons.alertTriangle, 'color': Colors.orange, 'desc': 'Find outliers and anomalies'},
    'time_series': {'icon': LucideIcons.activity, 'color': Colors.teal, 'desc': 'Forecast future values'},
  };

  final _requirementOptions = [
    {'key': 'has_categorical', 'icon': LucideIcons.list, 'label': 'Categorical Features', 'desc': 'Dataset contains text or category columns'},
    {'key': 'has_missing', 'icon': LucideIcons.alertCircle, 'label': 'Missing Values', 'desc': 'Dataset has null or NaN values'},
    {'key': 'need_interpretability', 'icon': LucideIcons.eye, 'label': 'Interpretability', 'desc': 'Need to explain model decisions'},
    {'key': 'need_speed', 'icon': LucideIcons.zap, 'label': 'Fast Training', 'desc': 'Priority on quick model training'},
    {'key': 'has_gpu', 'icon': LucideIcons.cpu, 'label': 'GPU Available', 'desc': 'Can use GPU acceleration'},
  ];

  bool _getRequirementValue(String key) {
    switch (key) {
      case 'has_categorical': return _hasCategorical;
      case 'has_missing': return _hasMissing;
      case 'need_interpretability': return _needInterpretability;
      case 'need_speed': return _needSpeed;
      case 'has_gpu': return _hasGpu;
      default: return false;
    }
  }

  void _setRequirementValue(String key, bool value) {
    setState(() {
      switch (key) {
        case 'has_categorical': _hasCategorical = value; break;
        case 'has_missing': _hasMissing = value; break;
        case 'need_interpretability': _needInterpretability = value; break;
        case 'need_speed': _needSpeed = value; break;
        case 'has_gpu': _hasGpu = value; break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.1), Colors.purple.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, Colors.purple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Icon(LucideIcons.sparkles, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Algorithm Recommendations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Get personalized algorithm suggestions based on your data', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                    color: AppColors.mutedForeground,
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task Type Selection
                  _buildSectionHeader('What do you want to predict?', LucideIcons.target),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _taskTypeInfo.entries.map((entry) {
                      final isSelected = _taskType == entry.key;
                      final info = entry.value;
                      return InkWell(
                        onTap: () => setState(() => _taskType = entry.key),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? (info['color'] as Color).withOpacity(0.15) : AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? (info['color'] as Color) : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(info['icon'] as IconData, size: 16, color: info['color'] as Color),
                              const SizedBox(width: 8),
                              Text(
                                entry.key.replaceAll('_', ' ').split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? (info['color'] as Color) : AppColors.foreground,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                Icon(LucideIcons.check, size: 14, color: info['color'] as Color),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Dataset Size
                  _buildSectionHeader('Dataset characteristics', LucideIcons.database),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumberInput(
                          label: 'Number of Samples',
                          value: _nSamples,
                          icon: LucideIcons.rows,
                          hint: 'Rows in your dataset',
                          onChanged: (v) => setState(() => _nSamples = v),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildNumberInput(
                          label: 'Number of Features',
                          value: _nFeatures,
                          icon: LucideIcons.columns,
                          hint: 'Columns (excluding target)',
                          onChanged: (v) => setState(() => _nFeatures = v),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Requirements
                  _buildSectionHeader('Additional requirements', LucideIcons.settings2),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: _requirementOptions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final opt = entry.value;
                        final isSelected = _getRequirementValue(opt['key'] as String);
                        final isLast = index == _requirementOptions.length - 1;

                        return InkWell(
                          onTap: () => _setRequirementValue(opt['key'] as String, !isSelected),
                          borderRadius: BorderRadius.vertical(
                            top: index == 0 ? const Radius.circular(12) : Radius.zero,
                            bottom: isLast ? const Radius.circular(12) : Radius.zero,
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: isLast ? null : Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.muted.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    opt['icon'] as IconData,
                                    size: 16,
                                    color: isSelected ? AppColors.primary : AppColors.mutedForeground,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(opt['label'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                      Text(opt['desc'] as String, style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isSelected,
                                  onChanged: (v) => _setRequirementValue(opt['key'] as String, v),
                                  activeColor: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 16, color: AppColors.mutedForeground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'We\'ll analyze your requirements and suggest the best algorithms',
                      style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, {
                      'task_type': _taskType,
                      'n_samples': _nSamples,
                      'n_features': _nFeatures,
                      'has_categorical': _hasCategorical,
                      'has_missing': _hasMissing,
                      'need_interpretability': _needInterpretability,
                      'need_speed': _needSpeed,
                      'has_gpu': _hasGpu,
                    }),
                    icon: Icon(LucideIcons.sparkles, size: 16),
                    label: Text('Get Recommendations'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildNumberInput({
    required String label,
    required int value,
    required IconData icon,
    required String hint,
    required Function(int) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: '$value',
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 12, color: AppColors.mutedForeground.withOpacity(0.5), fontWeight: FontWeight.normal),
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
            onChanged: (v) => onChanged(int.tryParse(v) ?? value),
          ),
        ],
      ),
    );
  }
}

class _CreateExperimentDialog extends StatefulWidget {
  final List<Algorithm> algorithms;

  const _CreateExperimentDialog({required this.algorithms});

  @override
  State<_CreateExperimentDialog> createState() => _CreateExperimentDialogState();
}

class _CreateExperimentDialogState extends State<_CreateExperimentDialog> {
  final _nameController = TextEditingController();
  final _datasetController = TextEditingController();
  final _targetController = TextEditingController();
  String _taskType = 'classification';
  int _maxTime = 60;
  int _cvFolds = 5;
  double _testSize = 0.2;
  String _optimizationMetric = 'f1';
  List<String> _selectedAlgorithms = [];
  int _currentStep = 0;
  String _algorithmFilter = '';

  // File browser state
  bool _showFileBrowser = false;
  String _currentPath = '';
  List<FileItem> _files = [];
  bool _loadingFiles = false;

  final _taskTypeInfo = {
    'classification': {'icon': LucideIcons.tag, 'color': Colors.blue, 'metrics': ['accuracy', 'f1', 'precision', 'recall', 'roc_auc']},
    'regression': {'icon': LucideIcons.trendingUp, 'color': Colors.green, 'metrics': ['r2', 'mse', 'rmse', 'mae']},
    'clustering': {'icon': LucideIcons.hexagon, 'color': Colors.purple, 'metrics': ['silhouette', 'calinski_harabasz', 'davies_bouldin']},
    'anomaly_detection': {'icon': LucideIcons.alertTriangle, 'color': Colors.orange, 'metrics': ['f1', 'precision', 'recall']},
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 750,
        height: 650,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.08), AppColors.primary.withOpacity(0.02)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(LucideIcons.flaskConical, color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New AutoML Experiment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.foreground)),
                        SizedBox(height: 4),
                        Text('Configure and run automated machine learning', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.muted,
                      foregroundColor: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),

            // Stepper indicator
            Container(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 32),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  _buildStepIndicator(0, 'Dataset', LucideIcons.database),
                  _buildStepConnector(0),
                  _buildStepIndicator(1, 'Task', LucideIcons.target),
                  _buildStepConnector(1),
                  _buildStepIndicator(2, 'Algorithms', LucideIcons.cpu),
                  _buildStepConnector(2),
                  _buildStepIndicator(3, 'Review', LucideIcons.checkSquare),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Container(
                color: AppColors.background.withOpacity(0.5),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: _buildStepContent(),
                ),
              ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border(top: BorderSide(color: AppColors.border)),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _currentStep--),
                      icon: Icon(LucideIcons.arrowLeft, size: 16),
                      label: Text('Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.foreground,
                        side: BorderSide(color: AppColors.border),
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    )
                  else
                    const SizedBox(width: 100),
                  const Spacer(),
                  // Step indicator pills
                  Row(
                    children: List.generate(4, (i) => Container(
                      width: i == _currentStep ? 24 : 8,
                      height: 8,
                      margin: EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= _currentStep ? AppColors.primary : AppColors.muted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  const Spacer(),
                  if (_currentStep < 3)
                    ElevatedButton.icon(
                      onPressed: _canProceed() ? () => setState(() => _currentStep++) : null,
                      icon: Text('Continue'),
                      label: Icon(LucideIcons.arrowRight, size: 16),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _canCreate() ? _createExperiment : null,
                      icon: Icon(LucideIcons.play, size: 16),
                      label: Text('Start Experiment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.success
                  : isActive
                      ? AppColors.primary
                      : AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCompleted
                    ? AppColors.success
                    : isActive
                        ? AppColors.primary
                        : AppColors.border,
                width: 2,
              ),
              boxShadow: isActive ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ] : null,
            ),
            child: Icon(
              isCompleted ? LucideIcons.check : icon,
              color: isCompleted || isActive ? Colors.white : AppColors.mutedForeground,
              size: 20,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isCompleted
                  ? AppColors.success
                  : isActive
                      ? AppColors.primary
                      : AppColors.mutedForeground,
              fontWeight: isActive || isCompleted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final isCompleted = _currentStep > step;
    return Expanded(
      child: Container(
        height: 3,
        margin: EdgeInsets.only(bottom: 28, left: 4, right: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: isCompleted ? AppColors.success : AppColors.muted,
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0: return _buildDatasetStep();
      case 1: return _buildTaskStep();
      case 2: return _buildAlgorithmsStep();
      case 3: return _buildSettingsStep();
      default: return const SizedBox();
    }
  }

  Future<void> _loadFiles(String path) async {
    setState(() => _loadingFiles = true);
    try {
      final files = await fileService.list(path);
      if (mounted) {
        setState(() {
          _files = files;
          _currentPath = path;
          _loadingFiles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingFiles = false);
      }
    }
  }

  void _openFileBrowser() {
    setState(() => _showFileBrowser = true);
    _loadFiles(_currentPath);
  }

  void _selectFile(FileItem file) {
    if (file.isDirectory) {
      _loadFiles(file.path);
    } else {
      // Check if it's a valid data file
      final ext = file.name.toLowerCase();
      if (ext.endsWith('.csv') || ext.endsWith('.parquet') || ext.endsWith('.xlsx') || ext.endsWith('.xls')) {
        setState(() {
          _datasetController.text = file.path;
          _showFileBrowser = false;
        });
      }
    }
  }

  void _goUpDirectory() {
    if (_currentPath.isEmpty) return;
    final parts = _currentPath.split('/');
    if (parts.length > 1) {
      parts.removeLast();
      _loadFiles(parts.join('/'));
    } else {
      _loadFiles('');
    }
  }

  Widget _buildDatasetStep() {
    if (_showFileBrowser) {
      return _buildFileBrowser();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Experiment Details', LucideIcons.fileText),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Experiment Name',
            hintText: 'e.g., Customer Churn Prediction',
            prefixIcon: Icon(LucideIcons.tag, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: AppColors.background,
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Dataset Configuration', LucideIcons.database),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _datasetController,
                decoration: InputDecoration(
                  labelText: 'Dataset Path',
                  hintText: 'Select a file or enter path',
                  prefixIcon: Icon(LucideIcons.file, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: AppColors.background,
                  helperText: 'Supports CSV, Parquet, and Excel files',
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _openFileBrowser,
              icon: Icon(LucideIcons.folderOpen, size: 18),
              label: Text('Browse'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _targetController,
          decoration: InputDecoration(
            labelText: 'Target Column',
            hintText: 'e.g., target, label, y',
            prefixIcon: Icon(LucideIcons.crosshair, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: AppColors.background,
            helperText: 'The column you want to predict',
          ),
        ),
      ],
    );
  }

  Widget _buildFileBrowser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with back button
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _showFileBrowser = false),
              icon: Icon(LucideIcons.arrowLeft),
              tooltip: 'Back to form',
            ),
            const SizedBox(width: 8),
            _buildSectionTitle('Select Dataset File', LucideIcons.folderOpen),
          ],
        ),
        const SizedBox(height: 12),

        // Breadcrumb / current path
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => _loadFiles(''),
                child: Icon(LucideIcons.home, size: 16, color: AppColors.primary),
              ),
              if (_currentPath.isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(LucideIcons.chevronRight, size: 14, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentPath,
                    style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else ...[
                const SizedBox(width: 8),
                Text('Files', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
              ],
              if (_currentPath.isNotEmpty)
                IconButton(
                  onPressed: _goUpDirectory,
                  icon: Icon(LucideIcons.cornerLeftUp, size: 16),
                  tooltip: 'Go up',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // File list
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _loadingFiles
              ? Center(child: CircularProgressIndicator())
              : _files.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.folderOpen, size: 48, color: AppColors.mutedForeground.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          Text('No files found', style: TextStyle(color: AppColors.mutedForeground)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _files.length,
                      separatorBuilder: (_, __) => Divider(height: 1),
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        final isDataFile = !file.isDirectory &&
                            (file.name.toLowerCase().endsWith('.csv') ||
                             file.name.toLowerCase().endsWith('.parquet') ||
                             file.name.toLowerCase().endsWith('.xlsx') ||
                             file.name.toLowerCase().endsWith('.xls'));

                        return ListTile(
                          leading: Icon(
                            file.isDirectory
                                ? LucideIcons.folder
                                : isDataFile
                                    ? LucideIcons.fileSpreadsheet
                                    : LucideIcons.file,
                            color: file.isDirectory
                                ? Colors.amber
                                : isDataFile
                                    ? AppColors.primary
                                    : AppColors.mutedForeground,
                          ),
                          title: Text(
                            file.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isDataFile ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          subtitle: file.isDirectory
                              ? null
                              : Text(
                                  _formatFileSize(file.size),
                                  style: TextStyle(fontSize: 11),
                                ),
                          trailing: file.isDirectory
                              ? Icon(LucideIcons.chevronRight, size: 16)
                              : isDataFile
                                  ? Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('Select', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                                    )
                                  : null,
                          onTap: () => _selectFile(file),
                          enabled: file.isDirectory || isDataFile,
                        );
                      },
                    ),
        ),

        const SizedBox(height: 12),
        Text(
          'Supported formats: CSV, Parquet, Excel (.xlsx, .xls)',
          style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Widget _buildTaskStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Select Task Type', LucideIcons.target),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.5,
          physics: const NeverScrollableScrollPhysics(),
          children: _taskTypeInfo.entries.map((entry) {
            final isSelected = _taskType == entry.key;
            final info = entry.value;
            return InkWell(
              onTap: () => setState(() {
                _taskType = entry.key;
                _selectedAlgorithms = [];
                _optimizationMetric = (info['metrics'] as List<String>).first;
              }),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? (info['color'] as Color).withOpacity(0.1) : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? (info['color'] as Color) : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (info['color'] as Color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(info['icon'] as IconData, color: info['color'] as Color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            entry.key.replaceAll('_', ' ').split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            '${widget.algorithms.where((a) => a.taskTypes.contains(entry.key)).length} algorithms',
                            style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(LucideIcons.checkCircle, color: info['color'] as Color, size: 20),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Optimization Metric', LucideIcons.barChart),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (_taskTypeInfo[_taskType]!['metrics'] as List<String>).map((metric) {
            final isSelected = _optimizationMetric == metric;
            return ChoiceChip(
              label: Text(metric.toUpperCase()),
              selected: isSelected,
              onSelected: (v) => setState(() => _optimizationMetric = metric),
              selectedColor: AppColors.primary.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.foreground,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAlgorithmsStep() {
    final applicableAlgorithms = widget.algorithms
        .where((a) => a.taskTypes.contains(_taskType))
        .where((a) => _algorithmFilter.isEmpty ||
            a.name.toLowerCase().contains(_algorithmFilter.toLowerCase()) ||
            a.category.toLowerCase().contains(_algorithmFilter.toLowerCase()))
        .toList();

    final groupedAlgorithms = <String, List<Algorithm>>{};
    for (final algo in applicableAlgorithms) {
      groupedAlgorithms.putIfAbsent(algo.category, () => []).add(algo);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSectionTitle('Select Algorithms', LucideIcons.cpu)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('${_selectedAlgorithms.length} selected', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search algorithms...',
                  prefixIcon: Icon(LucideIcons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (v) => setState(() => _algorithmFilter = v),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => setState(() => _selectedAlgorithms = applicableAlgorithms.map((a) => a.id).toList()),
              child: Text('Select All'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => setState(() => _selectedAlgorithms = []),
              child: Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 280,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView(
            padding: EdgeInsets.all(8),
            children: groupedAlgorithms.entries.map((entry) {
              final category = entry.key;
              final algos = entry.value;
              final allSelected = algos.every((a) => _selectedAlgorithms.contains(a.id));

              return ExpansionTile(
                initiallyExpanded: true,
                tilePadding: EdgeInsets.symmetric(horizontal: 8),
                title: Row(
                  children: [
                    Text(category.replaceAll('_', ' ').split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${algos.length}', style: TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
                trailing: Checkbox(
                  value: allSelected,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        for (final a in algos) {
                          if (!_selectedAlgorithms.contains(a.id)) _selectedAlgorithms.add(a.id);
                        }
                      } else {
                        for (final a in algos) {
                          _selectedAlgorithms.remove(a.id);
                        }
                      }
                    });
                  },
                  activeColor: AppColors.primary,
                ),
                children: algos.map((algo) {
                  final isSelected = _selectedAlgorithms.contains(algo.id);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.only(left: 24, right: 8),
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedAlgorithms.add(algo.id);
                          } else {
                            _selectedAlgorithms.remove(algo.id);
                          }
                        });
                      },
                      activeColor: AppColors.primary,
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(algo.name, style: TextStyle(fontSize: 13))),
                        if (algo.gpuAccelerated)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.zap, size: 10, color: Colors.green[700]),
                                const SizedBox(width: 2),
                                Text('GPU', style: TextStyle(fontSize: 9, color: Colors.green[700])),
                              ],
                            ),
                          ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(algo.library, style: TextStyle(fontSize: 9)),
                        ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedAlgorithms.remove(algo.id);
                        } else {
                          _selectedAlgorithms.add(algo.id);
                        }
                      });
                    },
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsStep() {
    final taskInfo = _taskTypeInfo[_taskType]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Training Settings
        _buildSectionTitle('Training Configuration', LucideIcons.settings),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSettingCard(
                LucideIcons.clock,
                'Max Training Time',
                '$_maxTime min',
                Slider(
                  value: _maxTime.toDouble(),
                  min: 5,
                  max: 180,
                  divisions: 35,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _maxTime = v.toInt()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSettingCard(
                LucideIcons.layers,
                'CV Folds',
                '$_cvFolds',
                Slider(
                  value: _cvFolds.toDouble(),
                  min: 2,
                  max: 10,
                  divisions: 8,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _cvFolds = v.toInt()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSettingCard(
                LucideIcons.pieChart,
                'Test Split',
                '${(_testSize * 100).toInt()}%',
                Slider(
                  value: _testSize,
                  min: 0.1,
                  max: 0.4,
                  divisions: 6,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _testSize = v),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Summary
        _buildSectionTitle('Experiment Summary', LucideIcons.fileCheck),
        const SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // Experiment name header
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.flaskConical, size: 24, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text.isEmpty ? 'Untitled Experiment' : _nameController.text,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.foreground),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _datasetController.text.isEmpty ? 'No dataset selected' : _datasetController.text.split('/').last,
                            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Summary grid
              Row(
                children: [
                  Expanded(child: _buildSummaryCard('Task Type', _taskType.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '), taskInfo['icon'] as IconData, taskInfo['color'] as Color)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryCard('Target', _targetController.text.isEmpty ? 'Not set' : _targetController.text, LucideIcons.crosshair, Colors.orange)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildSummaryCard('Metric', _optimizationMetric.toUpperCase(), LucideIcons.barChart, Colors.purple)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryCard('Algorithms', _selectedAlgorithms.isEmpty ? 'Auto (all)' : '${_selectedAlgorithms.length} selected', LucideIcons.cpu, Colors.teal)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildSummaryCard('Max Time', '$_maxTime minutes', LucideIcons.clock, Colors.blue)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryCard('Validation', '$_cvFolds-fold CV, ${(_testSize * 100).toInt()}% test', LucideIcons.layers, Colors.indigo)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: AppColors.mutedForeground, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.foreground), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSettingCard(IconData icon, String title, String value, Widget slider) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(value, style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          slider,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0: return _nameController.text.isNotEmpty && _datasetController.text.isNotEmpty && _targetController.text.isNotEmpty;
      case 1: return _taskType.isNotEmpty;
      case 2: return true; // Can proceed with empty selection (will use all)
      default: return true;
    }
  }

  bool _canCreate() {
    return _nameController.text.isNotEmpty && _datasetController.text.isNotEmpty && _targetController.text.isNotEmpty;
  }

  void _createExperiment() {
    Navigator.pop(context, {
      'name': _nameController.text,
      'dataset_path': _datasetController.text,
      'target_column': _targetController.text,
      'task_type': _taskType,
      'optimization_metric': _optimizationMetric,
      'max_time_minutes': _maxTime,
      'cv_folds': _cvFolds,
      'test_size': _testSize,
      'algorithms': _selectedAlgorithms.isEmpty ? null : _selectedAlgorithms,
    });
  }
}
