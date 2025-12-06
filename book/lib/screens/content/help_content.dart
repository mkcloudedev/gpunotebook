import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';

class HelpContent extends StatelessWidget {
  final VoidCallback? onClose;

  const HelpContent({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildSection(
                        'Getting Started',
                        LucideIcons.rocket,
                        const Color(0xFF3B82F6),
                        [
                          _HelpItem(
                            title: 'Create a Notebook',
                            description: 'Go to Notebooks page and click "New" button or use a template from "From Template".',
                            icon: LucideIcons.filePlus,
                          ),
                          _HelpItem(
                            title: 'Run Code',
                            description: 'Click the play button on a cell or press Shift+Enter to execute code.',
                            icon: LucideIcons.play,
                          ),
                          _HelpItem(
                            title: 'Use the CLI',
                            description: 'Type Python code in the footer CLI and press Enter for quick execution.',
                            icon: LucideIcons.terminal,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        'Notebooks',
                        LucideIcons.fileCode,
                        const Color(0xFF8B5CF6),
                        [
                          _HelpItem(
                            title: 'Add Cells',
                            description: 'Click "+ Code" or "+ Markdown" buttons to add new cells to your notebook.',
                            icon: LucideIcons.plus,
                          ),
                          _HelpItem(
                            title: 'Cell Actions',
                            description: 'Hover over a cell to see actions: Run, Move Up/Down, Copy, Delete.',
                            icon: LucideIcons.mousePointer,
                          ),
                          _HelpItem(
                            title: 'Import Notebooks',
                            description: 'Import existing .ipynb files using the "Import" button on the Notebooks page.',
                            icon: LucideIcons.upload,
                          ),
                          _HelpItem(
                            title: 'Templates',
                            description: 'Use pre-built templates for Machine Learning, Data Analysis, or Computer Vision projects.',
                            icon: LucideIcons.layoutTemplate,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        'AI Assistant',
                        LucideIcons.bot,
                        const Color(0xFF10B981),
                        [
                          _HelpItem(
                            title: 'Chat with AI',
                            description: 'Use the AI panel on the right side of the notebook editor to get coding help.',
                            icon: LucideIcons.messageSquare,
                          ),
                          _HelpItem(
                            title: 'Code Generation',
                            description: 'Ask AI to generate code, fix errors, or explain concepts.',
                            icon: LucideIcons.sparkles,
                          ),
                          _HelpItem(
                            title: 'Context Aware',
                            description: 'AI can see your notebook cells and provide relevant suggestions.',
                            icon: LucideIcons.eye,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        'GPU Monitoring',
                        LucideIcons.cpu,
                        const Color(0xFFF59E0B),
                        [
                          _HelpItem(
                            title: 'Real-time Stats',
                            description: 'Monitor GPU utilization, memory usage, temperature, and power draw.',
                            icon: LucideIcons.activity,
                          ),
                          _HelpItem(
                            title: 'Process List',
                            description: 'View all processes running on your GPU and their memory usage.',
                            icon: LucideIcons.list,
                          ),
                          _HelpItem(
                            title: 'Header Status',
                            description: 'GPU status is always visible in the header bar for quick reference.',
                            icon: LucideIcons.monitor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        'File Management',
                        LucideIcons.folderOpen,
                        const Color(0xFFEC4899),
                        [
                          _HelpItem(
                            title: 'Upload Files',
                            description: 'Click "Upload" to add files to your workspace for use in notebooks.',
                            icon: LucideIcons.uploadCloud,
                          ),
                          _HelpItem(
                            title: 'Create Folders',
                            description: 'Organize your files by creating folders with "New Folder" button.',
                            icon: LucideIcons.folderPlus,
                          ),
                          _HelpItem(
                            title: 'Storage Info',
                            description: 'View storage usage in the side panel of the Files page.',
                            icon: LucideIcons.hardDrive,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        'Keyboard Shortcuts',
                        LucideIcons.keyboard,
                        const Color(0xFF6366F1),
                        [
                          _ShortcutItem(shortcut: 'Shift + Enter', description: 'Run current cell'),
                          _ShortcutItem(shortcut: 'Ctrl + Enter', description: 'Run cell and stay'),
                          _ShortcutItem(shortcut: 'Ctrl + S', description: 'Save notebook'),
                          _ShortcutItem(shortcut: 'Arrow Up/Down', description: 'Navigate command history in CLI'),
                          _ShortcutItem(shortcut: 'Escape', description: 'Deselect current cell'),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildQuickLinks(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(LucideIcons.helpCircle, size: 32, color: AppColors.primary),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GPU Notebook Help',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.foreground),
                ),
                const SizedBox(height: 8),
                Text(
                  'Learn how to use the GPU Notebook application to run Python code with GPU acceleration, manage notebooks, and use AI assistance.',
                  style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: items),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinks() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.bookmark, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Quick Links', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.foreground)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  _QuickLink(icon: LucideIcons.rocket, title: 'Getting Started', color: const Color(0xFF3B82F6)),
                  _QuickLink(icon: LucideIcons.fileCode, title: 'Notebooks', color: const Color(0xFF8B5CF6)),
                  _QuickLink(icon: LucideIcons.bot, title: 'AI Assistant', color: const Color(0xFF10B981)),
                  _QuickLink(icon: LucideIcons.cpu, title: 'GPU Monitoring', color: const Color(0xFFF59E0B)),
                  _QuickLink(icon: LucideIcons.folderOpen, title: 'File Management', color: const Color(0xFFEC4899)),
                  _QuickLink(icon: LucideIcons.keyboard, title: 'Keyboard Shortcuts', color: const Color(0xFF6366F1)),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Icon(LucideIcons.messageCircle, size: 24, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text('Need more help?', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.foreground)),
                  const SizedBox(height: 4),
                  Text('Ask the AI Assistant', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: 20, color: AppColors.mutedForeground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GPU Notebook v1.0', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.foreground)),
                const SizedBox(height: 4),
                Text('Built with Flutter & Python FastAPI', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _HelpItem({required this.title, required this.description, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: AppColors.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.foreground)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  final String shortcut;
  final String description;

  const _ShortcutItem({required this.shortcut, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.codeBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              shortcut,
              style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.foreground),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(description, style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
          ),
        ],
      ),
    );
  }
}

class _QuickLink extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _QuickLink({required this.icon, required this.title, required this.color});

  @override
  State<_QuickLink> createState() => _QuickLinkState();
}

class _QuickLinkState extends State<_QuickLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isHovered ? widget.color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _isHovered ? widget.color.withOpacity(0.3) : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 16, color: widget.color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 14,
                  color: _isHovered ? widget.color : AppColors.foreground,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 14, color: _isHovered ? widget.color : AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}
