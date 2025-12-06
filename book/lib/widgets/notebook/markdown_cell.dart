import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/cell.dart';

class MarkdownCell extends StatefulWidget {
  final Cell cell;
  final bool isSelected;
  final bool isEditing;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onDelete;
  final void Function(String)? onSourceChange;

  const MarkdownCell({
    super.key,
    required this.cell,
    this.isSelected = false,
    this.isEditing = false,
    this.onTap,
    this.onDoubleTap,
    this.onDelete,
    this.onSourceChange,
  });

  @override
  State<MarkdownCell> createState() => _MarkdownCellState();
}

class _MarkdownCellState extends State<MarkdownCell> {
  late TextEditingController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.cell.source);
  }

  @override
  void didUpdateWidget(MarkdownCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cell.source != widget.cell.source) {
      _controller.text = widget.cell.source;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.primary
                  : _isHovered
                      ? AppColors.primary.withOpacity(0.3)
                      : AppColors.border,
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              widget.isEditing ? _buildEditor() : _buildRenderedContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(7),
          topRight: Radius.circular(7),
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.type,
            size: 14,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(width: 8),
          Text(
            'Markdown',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
          const Spacer(),
          if (_isHovered || widget.isSelected)
            _ActionButton(
              icon: LucideIcons.trash2,
              onTap: widget.onDelete,
              tooltip: 'Delete cell',
              isDestructive: true,
            ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      color: AppColors.codeBg,
      child: TextField(
        controller: _controller,
        maxLines: null,
        style: AppTheme.monoStyle,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: 'Enter markdown...',
          hintStyle: TextStyle(color: AppColors.mutedForeground),
        ),
        onChanged: widget.onSourceChange,
      ),
    );
  }

  Widget _buildRenderedContent() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      child: _parseMarkdown(widget.cell.source),
    );
  }

  Widget _parseMarkdown(String source) {
    final widgets = <Widget>[];

    // First, handle block LaTeX ($$...$$) - these can span multiple lines
    final blockLatexPattern = RegExp(r'\$\$([\s\S]*?)\$\$');
    final parts = source.split(blockLatexPattern);
    final blockMatches = blockLatexPattern.allMatches(source).toList();

    int matchIndex = 0;
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];

      // Parse regular markdown content
      if (part.isNotEmpty) {
        final lines = part.split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) continue;

          if (line.startsWith('# ')) {
            widgets.add(Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _parseInlineContent(
                line.substring(2),
                TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ));
          } else if (line.startsWith('## ')) {
            widgets.add(Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: _parseInlineContent(
                line.substring(3),
                TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
            ));
          } else if (line.startsWith('### ')) {
            widgets.add(Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: _parseInlineContent(
                line.substring(4),
                TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
            ));
          } else if (line.startsWith('- ') || line.startsWith('* ')) {
            widgets.add(Padding(
              padding: EdgeInsets.only(left: 8, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(color: AppColors.foreground),
                  ),
                  Expanded(
                    child: _parseInlineContent(
                      line.substring(2),
                      TextStyle(
                        fontSize: 14,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ));
          } else if (line.startsWith('```')) {
            // Code block - just show as monospace for now
            continue;
          } else {
            widgets.add(Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: _parseInlineContent(
                line,
                TextStyle(
                  fontSize: 14,
                  color: AppColors.foreground,
                ),
              ),
            ));
          }
        }
      }

      // Add block LaTeX if there's a match after this part
      if (matchIndex < blockMatches.length && i < parts.length - 1) {
        final latex = blockMatches[matchIndex].group(1)?.trim() ?? '';
        widgets.add(Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: _buildLatexWidget(latex, isBlock: true),
          ),
        ));
        matchIndex++;
      }
    }

    if (widgets.isEmpty) {
      return Text(
        'Double-click to edit',
        style: TextStyle(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: AppColors.mutedForeground,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Parse inline content with LaTeX, bold, italic, code, etc.
  Widget _parseInlineContent(String text, TextStyle baseStyle) {
    // Check for inline LaTeX ($...$), bold (**...**), italic (*...*), code (`...`)
    final inlineLatexPattern = RegExp(r'\$([^\$]+)\$');
    final boldPattern = RegExp(r'\*\*(.+?)\*\*');
    final italicPattern = RegExp(r'\*([^\*]+)\*');
    final codePattern = RegExp(r'`([^`]+)`');

    // If no special patterns, return plain text
    if (!text.contains(r'$') &&
        !text.contains('**') &&
        !text.contains('*') &&
        !text.contains('`')) {
      return Text(text, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    int currentIndex = 0;

    // Find all matches and sort by position
    final allMatches = <_MatchInfo>[];

    for (final match in inlineLatexPattern.allMatches(text)) {
      allMatches.add(_MatchInfo(match.start, match.end, 'latex', match.group(1) ?? ''));
    }
    for (final match in boldPattern.allMatches(text)) {
      // Check if this overlaps with an existing match
      final overlaps = allMatches.any((m) =>
        (match.start >= m.start && match.start < m.end) ||
        (match.end > m.start && match.end <= m.end)
      );
      if (!overlaps) {
        allMatches.add(_MatchInfo(match.start, match.end, 'bold', match.group(1) ?? ''));
      }
    }
    for (final match in italicPattern.allMatches(text)) {
      final overlaps = allMatches.any((m) =>
        (match.start >= m.start && match.start < m.end) ||
        (match.end > m.start && match.end <= m.end)
      );
      if (!overlaps) {
        allMatches.add(_MatchInfo(match.start, match.end, 'italic', match.group(1) ?? ''));
      }
    }
    for (final match in codePattern.allMatches(text)) {
      final overlaps = allMatches.any((m) =>
        (match.start >= m.start && match.start < m.end) ||
        (match.end > m.start && match.end <= m.end)
      );
      if (!overlaps) {
        allMatches.add(_MatchInfo(match.start, match.end, 'code', match.group(1) ?? ''));
      }
    }

    // Sort by start position
    allMatches.sort((a, b) => a.start.compareTo(b.start));

    // Build spans
    for (final match in allMatches) {
      // Add text before this match
      if (match.start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, match.start), style: baseStyle));
      }

      // Add the matched content
      switch (match.type) {
        case 'latex':
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _buildLatexWidget(match.content, isBlock: false),
          ));
          break;
        case 'bold':
          spans.add(TextSpan(
            text: match.content,
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ));
          break;
        case 'italic':
          spans.add(TextSpan(
            text: match.content,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ));
          break;
        case 'code':
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.codeBg,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                match.content,
                style: baseStyle.copyWith(
                  fontFamily: 'monospace',
                  fontSize: baseStyle.fontSize != null ? baseStyle.fontSize! - 1 : 13,
                ),
              ),
            ),
          ));
          break;
      }

      currentIndex = match.end;
    }

    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex), style: baseStyle));
    }

    if (spans.isEmpty) {
      return Text(text, style: baseStyle);
    }

    return Text.rich(TextSpan(children: spans));
  }

  /// Build a LaTeX widget with error handling
  Widget _buildLatexWidget(String latex, {required bool isBlock}) {
    try {
      return Math.tex(
        latex,
        textStyle: TextStyle(
          fontSize: isBlock ? 18 : 14,
          color: AppColors.foreground,
        ),
        onErrorFallback: (error) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.destructive.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.destructive.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.alertTriangle, size: 12, color: AppColors.destructive),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    latex,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: AppColors.destructive,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.destructive.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          latex,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: AppColors.destructive,
          ),
        ),
      );
    }
  }
}

/// Helper class to store match information
class _MatchInfo {
  final int start;
  final int end;
  final String type;
  final String content;

  _MatchInfo(this.start, this.end, this.type, this.content);
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    this.onTap,
    required this.tooltip,
    this.isDestructive = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive ? AppColors.destructive : AppColors.foreground;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isHovered ? color.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _isHovered ? color : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
