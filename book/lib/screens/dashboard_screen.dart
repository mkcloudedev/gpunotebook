import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/metric_data.dart';
import '../widgets/dashboard/sidebar.dart';
import '../widgets/dashboard/header.dart';
import '../widgets/dashboard/breadcrumb.dart';
import '../widgets/dashboard/notebook_cell.dart';
import '../widgets/dashboard/metric_card.dart';
import '../widgets/dashboard/dashboards_panel.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const List<MetricData> _metricsData = [
    MetricData(
      title: 'Booking',
      code: [
        'var actualRevenue = spark',
        '.sql("select sum(revenue_act',
        'ual) from sales_table")',
        '.collect',
        'var expectedRevenue = spark',
        '.sql("select sum(revenue_exp',
      ],
      metric: '117%',
      sparkJobs: 2,
    ),
    MetricData(
      title: 'Forcast',
      code: [
        'var result = spark.sql',
        '("select sum(revenue_expecte',
      ],
      metric: '\$570000',
      sparkJobs: 1,
      lastUpdated: 'Took 4 sec. Last updated by dleybzon@qubole.com 21 hours ago. Last run at Thu Jan 04 2018 13:17:37 GMT-0800 (outdated)',
    ),
    MetricData(
      title: 'Booking',
      code: [
        'var result = spark.sql',
        '("select sum(revenue_actual)',
      ],
      metric: '\$671500',
      sparkJobs: 1,
      lastUpdated: 'Took 2 sec. Last updated by dleybzon@qubole.com 21 hours ago. Last run at Thu Jan 04 2018 13:17:40 GMT-0800 (outdated)',
    ),
    MetricData(
      title: 'Average',
      code: [
        'var totalRevenue = spark.sql',
        '("select sum(revenue_actual)',
        'from sales_table").collect',
        'var totalCustomers = spark',
        '.sql("select sum(customers_c',
        'losed) from sales_table"',
      ],
      metric: '\$20984',
      sparkJobs: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          const Sidebar(),
          Expanded(
            child: Column(
              children: [
                const Header(),
                const Breadcrumb(),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildMainContent()),
                      const DashboardsPanel(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1024),
          child: Column(
            children: [
              const NotebookCell(),
              const SizedBox(height: 16),
              _buildMetricsGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: _metricsData.length,
          itemBuilder: (context, index) {
            return MetricCard(data: _metricsData[index]);
          },
        );
      },
    );
  }
}
