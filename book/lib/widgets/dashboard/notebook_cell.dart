import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class NotebookCell extends StatelessWidget {
  const NotebookCell({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCodeHeader(),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildCodeHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      color: AppColors.codeBg,
      child: Text(
        '%md',
        style: AppTheme.monoStyle.copyWith(
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCodeBlock(),
          const SizedBox(height: 16),
          _buildRenderedContent(),
          const SizedBox(height: 16),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildCodeBlock() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.codeBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCodeLine('<h4>', ' Steps to consume this Example Dashboard ', '</h4>'),
          _buildCodeLine('<ol>', '', ''),
          _buildCodeLine('  <li>', 'Clone this example as a Notebook', '</li>'),
          _buildCodeLine('  <li>', 'Delete this paragraph', '</li>'),
          _buildCodeLine('  <li>', 'Create a Dashboard from the Notebook', '</li>'),
          _buildCodeLine('</ol>', '', ''),
        ],
      ),
    );
  }

  Widget _buildCodeLine(String tag1, String content, String tag2) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: tag1, style: AppTheme.codeKeyword),
            TextSpan(text: content, style: AppTheme.monoStyle),
            TextSpan(text: tag2, style: AppTheme.codeKeyword),
          ],
        ),
      ),
    );
  }

  Widget _buildRenderedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Steps to consume this Example Dashboard',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        _buildListItem(1, 'Clone this example as a Notebook'),
        _buildListItem(2, 'Delete this paragraph'),
        _buildListItem(3, 'Create a Dashboard from the Notebook'),
      ],
    );
  }

  Widget _buildListItem(int number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Text(
        '$number. $text',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.foreground,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Took 5 sec. Last updated by dleybzon@qubole.com 21 hours ago. Last run at Thu Jan 04 2018 13:17:27 GMT-0800 (outdated)',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'FINISHED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
