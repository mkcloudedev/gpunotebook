import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/kernel_service.dart';

/// Python syntax highlighting colors (dynamic based on theme)
class PythonSyntaxColors {
  static Color get keyword => AppColors.syntaxKeyword;
  static Color get builtin => AppColors.syntaxBuiltin;
  static Color get string => AppColors.syntaxString;
  static Color get comment => AppColors.syntaxComment;
  static Color get number => AppColors.syntaxNumber;
  static Color get function => AppColors.syntaxFunction;
  static Color get decorator => AppColors.syntaxDecorator;
  static Color get className => AppColors.syntaxClassName;
  static Color get operator => AppColors.syntaxOperator;
  static Color get normal => AppColors.foreground;
}

/// Represents a foldable code region
class FoldableRegion {
  final int startLine;  // 0-indexed
  final int endLine;    // 0-indexed, inclusive
  final String type;    // 'def', 'class', 'if', 'for', etc.
  bool isCollapsed;

  FoldableRegion({
    required this.startLine,
    required this.endLine,
    required this.type,
    this.isCollapsed = false,
  });

  int get lineCount => endLine - startLine + 1;
}

/// A code editor widget with autocomplete, syntax highlighting, and code folding
class CodeEditor extends StatefulWidget {
  final String initialValue;
  final String? kernelId;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final String hintText;
  final bool showLineNumbers;
  final bool enableFolding;

  const CodeEditor({
    super.key,
    required this.initialValue,
    this.kernelId,
    this.onChanged,
    this.onTap,
    this.focusNode,
    this.hintText = '# Enter Python code...',
    this.showLineNumbers = true,
    this.enableFolding = true,
  });

  @override
  State<CodeEditor> createState() => CodeEditorState();
}

class CodeEditorState extends State<CodeEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  List<String> _suggestions = [];
  int _selectedIndex = 0;
  bool _isLoadingSuggestions = false;
  Timer? _debounceTimer;

  // For tracking cursor position
  int _cursorPosition = 0;

  // Code folding state
  List<FoldableRegion> _foldableRegions = [];

  // Keywords that start foldable blocks in Python
  static final _foldableKeywords = RegExp(
    r'^(\s*)(def|class|if|elif|else|for|while|with|try|except|finally|async\s+def|async\s+for|async\s+with)\b'
  );

  // Python syntax pattern keys
  static const _patternKeys = <String>[
    // Keywords
    r'\b(and|as|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield|True|False|None)\b',
    // Built-in functions
    r'\b(print|len|range|str|int|float|list|dict|set|tuple|type|isinstance|hasattr|getattr|setattr|open|input|abs|all|any|bin|bool|bytes|callable|chr|classmethod|compile|complex|delattr|dir|divmod|enumerate|eval|exec|filter|format|frozenset|globals|hash|help|hex|id|iter|locals|map|max|memoryview|min|next|object|oct|ord|pow|property|repr|reversed|round|slice|sorted|staticmethod|sum|super|vars|zip)\b',
    // Decorators
    r'@\w+',
    // Class names (after class keyword)
    r'(?<=class\s)\w+',
    // Function definitions
    r'(?<=def\s)\w+',
    // Function calls
    r'\b\w+(?=\s*\()',
    // Strings (single and double quotes, including multi-line)
    r'"""[\s\S]*?"""|' "'''[\\s\\S]*?'''|" r'"(?:[^"\\]|\\.)*"|' "'(?:[^'\\\\]|\\\\.)*'",
    // Comments
    r'#.*$',
    // Numbers
    r'\b\d+\.?\d*([eE][+-]?\d+)?\b',
    // Operators
    r'[+\-*/%=<>!&|^~]+',
  ];

  // Get pattern styles (dynamic for theme support)
  static List<TextStyle> _getPatternStyles() {
    return [
      TextStyle(color: PythonSyntaxColors.keyword, fontWeight: FontWeight.w500),
      TextStyle(color: PythonSyntaxColors.builtin),
      TextStyle(color: PythonSyntaxColors.decorator),
      TextStyle(color: PythonSyntaxColors.className, fontWeight: FontWeight.w500),
      TextStyle(color: PythonSyntaxColors.function),
      TextStyle(color: PythonSyntaxColors.function),
      TextStyle(color: PythonSyntaxColors.string),
      TextStyle(color: PythonSyntaxColors.comment, fontStyle: FontStyle.italic),
      TextStyle(color: PythonSyntaxColors.number),
      TextStyle(color: PythonSyntaxColors.operator),
    ];
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = widget.focusNode ?? FocusNode();
    _controller.addListener(_onTextChanged);
    _detectFoldableRegions();
  }

  @override
  void didUpdateWidget(CodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
      _detectFoldableRegions();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    // Remove overlay without setState since we're disposing
    _overlayEntry?.remove();
    _overlayEntry = null;
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    _cursorPosition = _controller.selection.baseOffset;
    widget.onChanged?.call(_controller.text);
    _detectFoldableRegions();
    setState(() {}); // Trigger rebuild for syntax highlighting

    // Debounce autocomplete requests
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions();
    });
  }

  /// Detect foldable regions in the code
  void _detectFoldableRegions() {
    if (!widget.enableFolding) return;

    final lines = _controller.text.split('\n');
    final newRegions = <FoldableRegion>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = _foldableKeywords.firstMatch(line);

      if (match != null) {
        final indent = match.group(1)?.length ?? 0;
        final keyword = match.group(2) ?? '';

        // Find the end of this block
        int endLine = i;
        for (int j = i + 1; j < lines.length; j++) {
          final nextLine = lines[j];

          // Skip empty lines
          if (nextLine.trim().isEmpty) {
            endLine = j;
            continue;
          }

          // Calculate indentation of next non-empty line
          final nextIndent = nextLine.length - nextLine.trimLeft().length;

          // If indentation is less than or equal to block start, block ends
          if (nextIndent <= indent) {
            break;
          }

          endLine = j;
        }

        // Only create region if block has content
        if (endLine > i) {
          // Check if this region was previously collapsed
          final existingRegion = _foldableRegions.firstWhere(
            (r) => r.startLine == i,
            orElse: () => FoldableRegion(startLine: i, endLine: endLine, type: keyword),
          );

          newRegions.add(FoldableRegion(
            startLine: i,
            endLine: endLine,
            type: keyword,
            isCollapsed: existingRegion.isCollapsed,
          ));
        }
      }
    }

    _foldableRegions = newRegions;
  }

  /// Toggle fold state for a region starting at the given line
  void toggleFold(int lineIndex) {
    setState(() {
      for (final region in _foldableRegions) {
        if (region.startLine == lineIndex) {
          region.isCollapsed = !region.isCollapsed;
          break;
        }
      }
    });
  }

  /// Collapse all foldable regions
  void collapseAll() {
    setState(() {
      for (final region in _foldableRegions) {
        region.isCollapsed = true;
      }
    });
  }

  /// Expand all foldable regions
  void expandAll() {
    setState(() {
      for (final region in _foldableRegions) {
        region.isCollapsed = false;
      }
    });
  }

  /// Check if a line is the start of a foldable region
  FoldableRegion? _getRegionAtLine(int lineIndex) {
    for (final region in _foldableRegions) {
      if (region.startLine == lineIndex) {
        return region;
      }
    }
    return null;
  }

  /// Check if a line should be hidden (inside a collapsed region)
  bool _isLineHidden(int lineIndex) {
    for (final region in _foldableRegions) {
      if (region.isCollapsed &&
          lineIndex > region.startLine &&
          lineIndex <= region.endLine) {
        return true;
      }
    }
    return false;
  }

  /// Get visible lines considering folded regions
  List<_VisibleLine> _getVisibleLines() {
    final lines = _controller.text.split('\n');
    final visibleLines = <_VisibleLine>[];

    for (int i = 0; i < lines.length; i++) {
      if (_isLineHidden(i)) continue;

      final region = _getRegionAtLine(i);
      visibleLines.add(_VisibleLine(
        lineNumber: i + 1,
        content: lines[i],
        foldableRegion: region,
      ));
    }

    return visibleLines;
  }

  Future<void> _fetchSuggestions() async {
    if (widget.kernelId == null || !_focusNode.hasFocus) {
      _hideOverlay();
      return;
    }

    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;

    if (cursorPos < 0 || text.isEmpty) {
      _hideOverlay();
      return;
    }

    // Check if we should show suggestions
    final beforeCursor = text.substring(0, cursorPos);
    final wordMatch = RegExp(r'[\w.]+$').firstMatch(beforeCursor);
    final currentWord = wordMatch?.group(0) ?? '';

    if (currentWord.isEmpty) {
      _hideOverlay();
      return;
    }

    setState(() => _isLoadingSuggestions = true);

    try {
      final result = await kernelService.complete(widget.kernelId!, text, cursorPos);

      if (result != null && mounted) {
        final matches = result['matches'] as List<dynamic>? ?? [];
        final suggestions = matches.map((m) => m.toString()).toList();

        if (suggestions.isNotEmpty) {
          setState(() {
            _suggestions = suggestions.take(10).toList();
            _selectedIndex = 0;
            _isLoadingSuggestions = false;
          });
          _showOverlay();
        } else {
          _hideOverlay();
          setState(() => _isLoadingSuggestions = false);
        }
      } else {
        _hideOverlay();
        setState(() => _isLoadingSuggestions = false);
      }
    } catch (e) {
      _hideOverlay();
      setState(() => _isLoadingSuggestions = false);
    }
  }

  void _showOverlay() {
    _hideOverlay();

    if (_suggestions.isEmpty || !mounted) return;

    // Ensure we have a valid overlay context
    final overlay = Overlay.of(context, rootOverlay: false);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        // Safety check - don't render if not mounted
        if (!mounted) return const SizedBox.shrink();

        return Positioned(
          width: 300,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 24),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              color: AppColors.card,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    final isSelected = index == _selectedIndex;

                    return InkWell(
                      onTap: () => _applySuggestion(suggestion),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        color: isSelected ? AppColors.primary.withOpacity(0.2) : null,
                        child: Row(
                          children: [
                            Icon(
                              _getIconForSuggestion(suggestion),
                              size: 14,
                              color: _getColorForSuggestion(suggestion),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                suggestion,
                                style: AppTheme.monoStyle.copyWith(
                                  fontSize: 13,
                                  color: isSelected ? AppColors.primary : AppColors.foreground,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    try {
      _overlayEntry?.remove();
    } catch (e) {
      // Ignore errors when removing overlay (widget might be disposed)
    }
    _overlayEntry = null;
    if (mounted) {
      setState(() => _suggestions = []);
    }
  }

  IconData _getIconForSuggestion(String suggestion) {
    if (suggestion.contains('(')) return LucideIcons.code;
    if (suggestion.startsWith('_')) return LucideIcons.lock;
    if (suggestion == suggestion.toUpperCase() && suggestion.length > 1) {
      return LucideIcons.hash;
    }
    return LucideIcons.box;
  }

  Color _getColorForSuggestion(String suggestion) {
    if (suggestion.contains('(')) return AppColors.warning;
    if (suggestion.startsWith('_')) return AppColors.mutedForeground;
    if (suggestion == suggestion.toUpperCase() && suggestion.length > 1) {
      return AppColors.success;
    }
    return AppColors.primary;
  }

  void _applySuggestion(String suggestion) {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;

    if (cursorPos < 0) return;

    final beforeCursor = text.substring(0, cursorPos);
    final wordMatch = RegExp(r'[\w]*$').firstMatch(beforeCursor);
    final wordStart = wordMatch?.start ?? cursorPos;

    final newText = text.substring(0, wordStart) + suggestion + text.substring(cursorPos);
    _controller.text = newText;

    final newCursorPos = wordStart + suggestion.length;
    _controller.selection = TextSelection.collapsed(offset: newCursorPos);

    _hideOverlay();
    widget.onChanged?.call(newText);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (_suggestions.isEmpty) return;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _suggestions.length;
        });
        _showOverlay();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1 + _suggestions.length) % _suggestions.length;
        });
        _showOverlay();
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
                 event.logicalKey == LogicalKeyboardKey.tab) {
        if (_suggestions.isNotEmpty) {
          _applySuggestion(_suggestions[_selectedIndex]);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _hideOverlay();
      }
    }
  }

  int get lineCount => '\n'.allMatches(_controller.text).length + 1;

  /// Build syntax highlighted text spans
  List<TextSpan> _buildHighlightedSpans(String text) {
    if (text.isEmpty) return [];

    final spans = <TextSpan>[];
    final matches = <_SyntaxMatch>[];
    final styles = _getPatternStyles();

    // Find all pattern matches
    for (int i = 0; i < _patternKeys.length; i++) {
      final regex = RegExp(_patternKeys[i], multiLine: true);
      for (final match in regex.allMatches(text)) {
        matches.add(_SyntaxMatch(
          start: match.start,
          end: match.end,
          style: styles[i],
        ));
      }
    }

    // Sort by start position
    matches.sort((a, b) => a.start.compareTo(b.start));

    // Remove overlapping matches (keep first one)
    final filteredMatches = <_SyntaxMatch>[];
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start >= lastEnd) {
        filteredMatches.add(match);
        lastEnd = match.end;
      }
    }

    // Build spans
    int currentIndex = 0;
    for (final match in filteredMatches) {
      // Add normal text before this match
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: TextStyle(color: PythonSyntaxColors.normal),
        ));
      }
      // Add highlighted text
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: match.style,
      ));
      currentIndex = match.end;
    }

    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: TextStyle(color: PythonSyntaxColors.normal),
      ));
    }

    return spans;
  }

  /// Build the display text considering folded regions
  String _buildDisplayText() {
    if (!widget.enableFolding) return _controller.text;

    final lines = _controller.text.split('\n');
    final displayLines = <String>[];

    for (int i = 0; i < lines.length; i++) {
      if (_isLineHidden(i)) continue;

      final region = _getRegionAtLine(i);
      if (region != null && region.isCollapsed) {
        // Add the first line with collapse indicator
        displayLines.add('${lines[i]} ... (${region.endLine - region.startLine} lines)');
      } else {
        displayLines.add(lines[i]);
      }
    }

    return displayLines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final visibleLines = _getVisibleLines();
    final lineHeight = 20.0;
    final hasCollapsedRegions = _foldableRegions.any((r) => r.isCollapsed);

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line numbers with fold indicators
            if (widget.showLineNumbers)
              SizedBox(
                width: widget.enableFolding ? 56 : 40,
                child: Padding(
                  padding: EdgeInsets.only(top: 12, right: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: visibleLines.map((line) {
                      final region = line.foldableRegion;
                      final hasFoldIndicator = region != null;

                      return SizedBox(
                        height: lineHeight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Fold indicator
                            if (widget.enableFolding)
                              SizedBox(
                                width: 16,
                                child: hasFoldIndicator
                                    ? MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: GestureDetector(
                                          onTap: () => toggleFold(region.startLine),
                                          child: Icon(
                                            region.isCollapsed
                                                ? LucideIcons.chevronRight
                                                : LucideIcons.chevronDown,
                                            size: 12,
                                            color: AppColors.mutedForeground,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            // Line number
                            Expanded(
                              child: Text(
                                '${line.lineNumber}',
                                textAlign: TextAlign.right,
                                style: AppTheme.monoStyle.copyWith(
                                  color: AppColors.mutedForeground,
                                  fontSize: 12,
                                  height: 1.43,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            // Code editor with syntax highlighting
            Expanded(
              child: CompositedTransformTarget(
                link: _layerLink,
                child: hasCollapsedRegions
                    ? _buildFoldedView(visibleLines, lineHeight)
                    : _buildNormalView(),
              ),
            ),
            // Fold controls
            if (widget.enableFolding && _foldableRegions.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8, right: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FoldButton(
                      icon: LucideIcons.foldVertical,
                      tooltip: 'Collapse all',
                      onTap: collapseAll,
                    ),
                    const SizedBox(height: 4),
                    _FoldButton(
                      icon: LucideIcons.unfoldVertical,
                      tooltip: 'Expand all',
                      onTap: expandAll,
                    ),
                  ],
                ),
              ),
            // Loading indicator
            if (_isLoadingSuggestions)
              Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build normal view without folding
  Widget _buildNormalView() {
    final baseStyle = AppTheme.monoStyle.copyWith(
      height: 1.43,
      fontSize: 14,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Stack(
        children: [
          // RichText for syntax highlighting
          Positioned.fill(
            child: IgnorePointer(
              child: RichText(
                text: TextSpan(
                  style: baseStyle,
                  children: _buildHighlightedSpans(_controller.text),
                ),
              ),
            ),
          ),
          // Editable text with transparent color
          EditableText(
            controller: _controller,
            focusNode: _focusNode,
            style: baseStyle.copyWith(color: Colors.transparent),
            cursorColor: AppColors.primary,
            backgroundCursorColor: Colors.grey,
            maxLines: null,
            onChanged: (text) {
              widget.onChanged?.call(text);
            },
            onTap: widget.onTap,
          ),
        ],
      ),
    );
  }

  /// Build folded view - uses per-line layout
  Widget _buildFoldedView(List<_VisibleLine> visibleLines, double lineHeight) {
    return GestureDetector(
      onTap: () {
        widget.onTap?.call();
        _focusNode.requestFocus();
      },
      onDoubleTap: () {
        // Double tap expands all
        expandAll();
      },
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: visibleLines.map((line) {
            final region = line.foldableRegion;
            String displayContent = line.content;

            if (region != null && region.isCollapsed) {
              displayContent = '${line.content} ...';
            }

            return SizedBox(
              height: lineHeight,
              child: Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: AppTheme.monoStyle.copyWith(
                          height: 1.43,
                          fontSize: 14,
                        ),
                        children: _buildHighlightedSpans(displayContent),
                      ),
                      overflow: TextOverflow.clip,
                    ),
                  ),
                  // Collapsed indicator badge
                  if (region != null && region.isCollapsed)
                    Container(
                      margin: EdgeInsets.only(left: 4),
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '${region.endLine - region.startLine} lines',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Fold/Unfold button widget
class _FoldButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _FoldButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_FoldButton> createState() => _FoldButtonState();
}

class _FoldButtonState extends State<_FoldButton> {
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
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _isHovered ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _isHovered ? AppColors.primary : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

/// Represents a visible line in the editor
class _VisibleLine {
  final int lineNumber;
  final String content;
  final FoldableRegion? foldableRegion;

  _VisibleLine({
    required this.lineNumber,
    required this.content,
    this.foldableRegion,
  });
}

class _SyntaxMatch {
  final int start;
  final int end;
  final TextStyle style;

  _SyntaxMatch({required this.start, required this.end, required this.style});
}

/// Custom painter for syntax highlighting that paints behind the TextField
class _SyntaxHighlightPainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final List<TextSpan> Function(String) buildSpans;

  _SyntaxHighlightPainter({
    required this.text,
    required this.style,
    required this.buildSpans,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    final textSpan = TextSpan(
      style: style,
      children: buildSpans(text),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: size.width);

    // Paint at offset to match TextField padding
    textPainter.paint(canvas, const Offset(0, 12));
  }

  @override
  bool shouldRepaint(_SyntaxHighlightPainter oldDelegate) {
    return text != oldDelegate.text;
  }
}
