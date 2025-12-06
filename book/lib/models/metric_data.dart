class MetricData {
  final String title;
  final List<String> code;
  final String metric;
  final int? sparkJobs;
  final String? lastUpdated;
  final String status;

  const MetricData({
    required this.title,
    required this.code,
    required this.metric,
    this.sparkJobs,
    this.lastUpdated,
    this.status = 'FINISHED',
  });
}
