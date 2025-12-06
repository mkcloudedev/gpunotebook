import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/cell.dart';

/// Panel for comparing two cells side by side
class SplitViewPanel extends StatefulWidget {
  final Cell? leftCell;
  final Cell? rightCell;
  final List<Cell> availableCells;
  final String? kernelId;
  final Function(String cellId, String source) onCellChange;
  final Function(String cellId) onSelectLeftCell;
  final Function(String cellId) onSelectRightCell;
  final VoidCallback onClose;
  final Function(String cellId)? onRunCell;

  const SplitViewPanel({
    super.key,
    this.leftCell,
    this.rightCell,
    required this.availableCells,
    this.kernelId,
    required this.onCellChange,
    required this.onSelectLeftCell,
    required this.onSelectRightCell,
    required this.onClose,
    this.onRunCell,
  });

  @override
  State<SplitViewPanel> createState() => _SplitViewPanelState();
}

class _SplitViewPanelState extends State<SplitViewPanel> {
  bool _showDiff = false;
  double _splitPosition = 0.5;

  // Python syntax patterns
  static const _patternKeys = <String>[
    r'\b(and|as|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield|True|False|None)\b',
    r'\b(print|len|range|str|int|float|list|dict|set|tuple|type|isinstance|hasattr|getattr|setattr|open|input|abs|all|any|bin|bool|bytes|callable|chr|classmethod|compile|complex|delattr|dir|divmod|enumerate|eval|exec|filter|format|frozenset|globals|hash|help|hex|id|iter|locals|map|max|memoryview|min|next|object|oct|ord|pow|property|repr|reversed|round|slice|sorted|staticmethod|sum|super|vars|zip)\b',
    r'@\w+',
    r'(?<=class\s)\w+',
    r'(?<=def\s)\w+',
    r'\b\w+(?=\s*\()',
    r'"""[\s\S]*?"""|' "'''[\\s\\S]*?'''|" r'"(?:[^"\\]|\\.)*"|' "'(?:[^'\\\\]|\\\\.)*'",
    r'#.*$',
    r'\b\d+\.?\d*([eE][+-]?\d+)?\b',
    r'[+\-*/%=<>!&|^~]+',
  ];

  List<TextStyle> _getPatternStyles() {
    return [
      TextStyle(color: AppColors.syntaxKeyword, fontWeight: FontWeight.w500),
      TextStyle(color: AppColors.syntaxBuiltin),
      TextStyle(color: AppColors.syntaxDecorator),
      TextStyle(color: AppColors.syntaxClassName, fontWeight: FontWeight.w500),
      TextStyle(color: AppColors.syntaxFunction),
      TextStyle(color: AppColors.syntaxFunction),
      TextStyle(color: AppColors.syntaxString),
      TextStyle(color: AppColors.syntaxComment, fontStyle: FontStyle.italic),
      TextStyle(color: AppColors.syntaxNumber),
      TextStyle(color: AppColors.syntaxOperator),
    ];
  }

  List<TextSpan> _buildHighlightedSpans(String text) {
    if (text.isEmpty) return [TextSpan(text: ' ', style: TextStyle(color: AppColors.foreground))];

    final spans = <TextSpan>[];
    final matches = <_SyntaxMatch>[];
    final styles = _getPatternStyles();

    for (int i = 0; i < _patternKeys.length; i++) {
      final regex = RegExp(_patternKeys[i], multiLine: true);
      for (final match in regex.allMatches(text)) {
        matches.add(_SyntaxMatch(start: match.start, end: match.end, style: styles[i]));
      }
    }

    matches.sort((a, b) => a.start.compareTo(b.start));

    final filteredMatches = <_SyntaxMatch>[];
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start >= lastEnd) {
        filteredMatches.add(match);
        lastEnd = match.end;
      }
    }

    int currentIndex = 0;
    for (final match in filteredMatches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: TextStyle(color: AppColors.foreground),
        ));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: match.style,
      ));
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: TextStyle(color: AppColors.foreground),
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          // Split content
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final leftWidth = constraints.maxWidth * _splitPosition;
                final rightWidth = constraints.maxWidth * (1 - _splitPosition);

                return Row(
                  children: [
                    // Left panel
                    SizedBox(
                      width: leftWidth - 4,
                      child: _buildCellPanel(
                        cell: widget.leftCell,
                        isLeft: true,
                        onSelect: widget.onSelectLeftCell,
                      ),
                    ),
                    // Resizable divider
                    GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _splitPosition += details.delta.dx / constraints.maxWidth;
                          _splitPosition = _splitPosition.clamp(0.2, 0.8);
                        });
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: Container(
                          width: 8,
                          color: AppColors.border,
                          child: Center(
                            child: Container(
                              width: 4,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.mutedForeground,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Right panel
                    SizedBox(
                      width: rightWidth - 4,
                      child: _buildCellPanel(
                        cell: widget.rightCell,
                        isLeft: false,
                        onSelect: widget.onSelectRightCell,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Diff view (optional)
          if (_showDiff && widget.leftCell != null && widget.rightCell != null)
            _buildDiffView(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(7),
          topRight: Radius.circular(7),
        ),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              LucideIcons.columns,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Split View',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
          const Spacer(),
          // Toggle diff view
          _ToggleButton(
            icon: LucideIcons.gitCompare,
            label: 'Diff',
            isActive: _showDiff,
            onTap: () => setState(() => _showDiff = !_showDiff),
          ),
          const SizedBox(width: 8),
          // Swap cells
          _ActionButton(
            icon: LucideIcons.arrowLeftRight,
            tooltip: 'Swap Cells',
            onTap: _swapCells,
          ),
          const SizedBox(width: 8),
          // Reset split
          _ActionButton(
            icon: LucideIcons.maximize2,
            tooltip: 'Reset Split',
            onTap: () => setState(() => _splitPosition = 0.5),
          ),
          const SizedBox(width: 8),
          // Close
          _ActionButton(
            icon: LucideIcons.x,
            tooltip: 'Close Split View',
            onTap: widget.onClose,
          ),
        ],
      ),
    );
  }

  void _swapCells() {
    if (widget.leftCell != null && widget.rightCell != null) {
      widget.onSelectLeftCell(widget.rightCell!.id);
      widget.onSelectRightCell(widget.leftCell!.id);
    }
  }

  Widget _buildCellPanel({
    required Cell? cell,
    required bool isLeft,
    required Function(String) onSelect,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          left: isLeft ? BorderSide.none : BorderSide(color: AppColors.border),
          right: isLeft ? BorderSide(color: AppColors.border) : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          // Cell selector
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.muted.withOpacity(0.5),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLeft
                        ? AppColors.primary.withOpacity(0.15)
                        : AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isLeft ? 'LEFT' : 'RIGHT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isLeft ? AppColors.primary : AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CellDropdown(
                    selectedCell: cell,
                    cells: widget.availableCells,
                    onSelect: onSelect,
                  ),
                ),
                if (cell != null && widget.onRunCell != null)
                  IconButton(
                    icon: Icon(LucideIcons.play, size: 14),
                    onPressed: () => widget.onRunCell!(cell.id),
                    tooltip: 'Run Cell',
                    color: AppColors.success,
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
              ],
            ),
          ),
          // Cell content
          Expanded(
            child: cell == null
                ? _buildEmptyCellPlaceholder(isLeft)
                : _buildCellContent(cell),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCellPlaceholder(bool isLeft) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.fileCode,
            size: 48,
            color: AppColors.mutedForeground.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a cell',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a cell from the dropdown above',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCellContent(Cell cell) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cell info bar
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: AppColors.codeBg,
          child: Row(
            children: [
              Icon(
                cell.cellType == CellType.code
                    ? LucideIcons.code
                    : LucideIcons.fileText,
                size: 12,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Text(
                cell.cellType == CellType.code ? 'Code' : 'Markdown',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
              if (cell.executionCount != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '[${cell.executionCount}]',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '${cell.source.split('\n').length} lines',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        // Code/Markdown content - scrollable with syntax highlighting
        Expanded(
          child: Container(
            width: double.infinity,
            color: cell.cellType == CellType.code ? AppColors.codeBg : AppColors.card,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: cell.cellType == CellType.code
                  ? SelectableText.rich(
                      TextSpan(
                        style: AppTheme.monoStyle.copyWith(fontSize: 12, height: 1.5),
                        children: _buildHighlightedSpans(cell.source.isEmpty ? '# empty' : cell.source),
                      ),
                    )
                  : SelectableText(
                      cell.source.isEmpty ? '(empty)' : cell.source,
                      style: TextStyle(fontSize: 13, color: AppColors.foreground, height: 1.5),
                    ),
            ),
          ),
        ),
        // Output (if any)
        if (cell.outputs.isNotEmpty)
          Container(
            constraints: BoxConstraints(maxHeight: 100),
            decoration: BoxDecoration(
              color: AppColors.muted.withOpacity(0.3),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: cell.outputs.map((output) {
                  if (output.outputType == 'error') {
                    return Text(
                      output.evalue ?? output.text ?? 'Error',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.destructive,
                      ),
                    );
                  }
                  return Text(
                    output.text ?? '',
                    style: AppTheme.monoStyle.copyWith(fontSize: 11),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }


  Widget _buildDiffView() {
    if (widget.leftCell == null || widget.rightCell == null) {
      return SizedBox.shrink();
    }

    final leftLines = widget.leftCell!.source.split('\n');
    final rightLines = widget.rightCell!.source.split('\n');
    final maxLines = leftLines.length > rightLines.length
        ? leftLines.length
        : rightLines.length;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.codeBg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Diff header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.muted.withOpacity(0.5),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.gitCompare, size: 14, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                Text(
                  'Diff View',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground,
                  ),
                ),
                const Spacer(),
                _DiffStat(
                  additions: _countDifferences(leftLines, rightLines, true),
                  deletions: _countDifferences(leftLines, rightLines, false),
                ),
              ],
            ),
          ),
          // Diff content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(maxLines, (index) {
                  final leftLine = index < leftLines.length ? leftLines[index] : '';
                  final rightLine = index < rightLines.length ? rightLines[index] : '';
                  final isDifferent = leftLine != rightLine;

                  if (!isDifferent) {
                    return _DiffLine(
                      lineNumber: index + 1,
                      content: leftLine,
                      type: DiffLineType.unchanged,
                    );
                  }

                  return Column(
                    children: [
                      if (leftLine.isNotEmpty)
                        _DiffLine(
                          lineNumber: index + 1,
                          content: leftLine,
                          type: DiffLineType.removed,
                        ),
                      if (rightLine.isNotEmpty)
                        _DiffLine(
                          lineNumber: index + 1,
                          content: rightLine,
                          type: DiffLineType.added,
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _countDifferences(List<String> left, List<String> right, bool additions) {
    int count = 0;
    final maxLines = left.length > right.length ? left.length : right.length;

    for (int i = 0; i < maxLines; i++) {
      final leftLine = i < left.length ? left[i] : '';
      final rightLine = i < right.length ? right[i] : '';

      if (leftLine != rightLine) {
        if (additions && rightLine.isNotEmpty) {
          count++;
        } else if (!additions && leftLine.isNotEmpty) {
          count++;
        }
      }
    }

    return count;
  }
}

class _CellDropdown extends StatelessWidget {
  final Cell? selectedCell;
  final List<Cell> cells;
  final Function(String) onSelect;

  const _CellDropdown({
    required this.selectedCell,
    required this.cells,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCell?.id,
          isExpanded: true,
          icon: Icon(LucideIcons.chevronDown, size: 14, color: AppColors.mutedForeground),
          dropdownColor: AppColors.card,
          style: TextStyle(fontSize: 12, color: AppColors.foreground),
          hint: Text(
            'Select cell...',
            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          ),
          items: cells.map((cell) {
            final preview = cell.source.split('\n').first;
            final truncated = preview.length > 30
                ? '${preview.substring(0, 30)}...'
                : preview;
            final index = cells.indexOf(cell) + 1;

            return DropdownMenuItem<String>(
              value: cell.id,
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: cell.cellType == CellType.code
                          ? AppColors.primary.withOpacity(0.15)
                          : AppColors.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '$index',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: cell.cellType == CellType.code
                              ? AppColors.primary
                              : AppColors.success,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      truncated.isEmpty ? '(empty)' : truncated,
                      style: TextStyle(
                        fontSize: 12,
                        color: truncated.isEmpty
                            ? AppColors.mutedForeground
                            : AppColors.foreground,
                        fontStyle: truncated.isEmpty ? FontStyle.italic : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onSelect(value);
            }
          },
        ),
      ),
    );
  }
}

class _ToggleButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.primary.withOpacity(0.15)
                : _isHovered
                    ? AppColors.muted
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isActive
                  ? AppColors.primary.withOpacity(0.3)
                  : _isHovered
                      ? AppColors.border
                      : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.isActive
                    ? AppColors.primary
                    : AppColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isActive
                      ? AppColors.primary
                      : AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _isHovered ? AppColors.muted : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _isHovered ? AppColors.foreground : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiffStat extends StatelessWidget {
  final int additions;
  final int deletions;

  const _DiffStat({
    required this.additions,
    required this.deletions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '+$additions',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.destructive.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '-$deletions',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.destructive,
            ),
          ),
        ),
      ],
    );
  }
}

enum DiffLineType { added, removed, unchanged }

class _DiffLine extends StatelessWidget {
  final int lineNumber;
  final String content;
  final DiffLineType type;

  const _DiffLine({
    required this.lineNumber,
    required this.content,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String prefix;

    switch (type) {
      case DiffLineType.added:
        bgColor = AppColors.success.withOpacity(0.1);
        textColor = AppColors.success;
        prefix = '+';
        break;
      case DiffLineType.removed:
        bgColor = AppColors.destructive.withOpacity(0.1);
        textColor = AppColors.destructive;
        prefix = '-';
        break;
      case DiffLineType.unchanged:
        bgColor = Colors.transparent;
        textColor = AppColors.foreground;
        prefix = ' ';
        break;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      color: bgColor,
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$lineNumber',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Text(
            prefix,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              content,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper class for syntax highlighting matches
class _SyntaxMatch {
  final int start;
  final int end;
  final TextStyle style;

  _SyntaxMatch({required this.start, required this.end, required this.style});
}
