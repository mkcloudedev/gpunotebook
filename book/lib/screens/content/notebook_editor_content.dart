import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/notebook.dart';
import '../../models/cell.dart';
import '../../models/kernel.dart';
import '../../models/execution.dart';
import '../../services/notebook_service.dart';
import '../../services/kernel_service.dart';
import '../../services/execution_service.dart';
import '../../widgets/notebook/ai_chat_panel.dart';
import '../../widgets/notebook/code_editor.dart';
import '../../widgets/notebook/cell_tags_widget.dart';
import '../../widgets/notebook/package_manager_panel.dart';
import '../../widgets/notebook/split_view_panel.dart';
import '../../widgets/notebook/keyboard_shortcuts_dialog.dart';
import '../../widgets/notebook/execution_log_panel.dart';
import '../../services/keyboard_shortcuts_service.dart';
import '../../models/keyboard_shortcut.dart';

class NotebookEditorContent extends StatefulWidget {
  final String notebookId;

  const NotebookEditorContent({super.key, required this.notebookId});

  @override
  State<NotebookEditorContent> createState() => NotebookEditorContentState();
}

class NotebookEditorContentState extends State<NotebookEditorContent> {
  Notebook? _notebook;
  String? _selectedCellId;
  String _kernelStatus = 'starting';
  bool _isFullscreen = false;
  bool _isLoading = true;
  String? _error;

  // Kernel and execution
  Kernel? _kernel;
  ExecutionService? _executionService;
  StreamSubscription? _executionSubscription;
  int _executionCounter = 0;

  // Variable inspector
  List<Map<String, dynamic>> _variables = [];
  bool _showVariables = false;
  Timer? _variableRefreshTimer;

  // Execution logs
  final List<LogEntry> _executionLogs = [];
  bool _showExecutionLogs = true;
  bool _logsMinimized = true;

  // Command mode (like Jupyter - Esc to enter, Enter to exit)
  bool _isCommandMode = false;

  // Collapsed cells set
  final Set<String> _collapsedCells = {};

  // Find & Replace
  bool _showFindReplace = false;
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  List<_SearchMatch> _searchMatches = [];
  int _currentMatchIndex = -1;

  // Undo/Redo history
  final List<_NotebookState> _undoStack = [];
  final List<_NotebookState> _redoStack = [];
  static const int _maxHistorySize = 50;
  Timer? _historyDebounceTimer;

  // Outline/TOC
  bool _showOutline = false;

  // Package Manager
  bool _showPackages = false;

  // Split View
  bool _showSplitView = false;
  String? _splitLeftCellId;
  String? _splitRightCellId;

  // Public getters for external access
  String get kernelStatus => _kernelStatus;
  Notebook? get notebook => _notebook;

  // Public methods for toolbar actions
  void runAllCells() => _runAllCells();
  void stopExecution() => _stopExecution();
  void restartKernel() => _restartKernel();
  void clearAllOutputs() => _clearOutputs();
  Future<void> saveNotebook() => _saveNotebook();
  void addCodeCell() => _addCell(CellType.code);
  void addMarkdownCell() => _addCell(CellType.markdown);
  void toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
  }
  void toggleVariables() {
    setState(() => _showVariables = !_showVariables);
    if (_showVariables) _refreshVariables();
  }
  bool get showVariables => _showVariables;
  List<Map<String, dynamic>> get variables => _variables;

  // Find & Replace methods
  void toggleFindReplace() {
    setState(() {
      _showFindReplace = !_showFindReplace;
      if (!_showFindReplace) {
        _searchMatches = [];
        _currentMatchIndex = -1;
      }
    });
  }

  void _performSearch() {
    final query = _findController.text;
    if (query.isEmpty || _notebook == null) {
      setState(() {
        _searchMatches = [];
        _currentMatchIndex = -1;
      });
      return;
    }

    final matches = <_SearchMatch>[];
    for (final cell in _notebook!.cells) {
      final source = cell.source.toLowerCase();
      final queryLower = query.toLowerCase();
      int index = 0;
      while ((index = source.indexOf(queryLower, index)) != -1) {
        matches.add(_SearchMatch(cellId: cell.id, startIndex: index, length: query.length));
        index += query.length;
      }
    }

    setState(() {
      _searchMatches = matches;
      _currentMatchIndex = matches.isNotEmpty ? 0 : -1;
      if (matches.isNotEmpty) {
        _selectedCellId = matches[0].cellId;
      }
    });
  }

  void _goToNextMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
      _selectedCellId = _searchMatches[_currentMatchIndex].cellId;
    });
  }

  void _goToPreviousMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _searchMatches.length) % _searchMatches.length;
      _selectedCellId = _searchMatches[_currentMatchIndex].cellId;
    });
  }

  void _replaceCurrentMatch() {
    if (_searchMatches.isEmpty || _currentMatchIndex < 0) return;

    final match = _searchMatches[_currentMatchIndex];
    final cellIndex = _notebook!.cells.indexWhere((c) => c.id == match.cellId);
    if (cellIndex < 0) return;

    final cell = _notebook!.cells[cellIndex];
    final newSource = cell.source.substring(0, match.startIndex) +
        _replaceController.text +
        cell.source.substring(match.startIndex + match.length);

    _updateCellSource(cell.id, newSource);
    _performSearch(); // Re-search after replacement
  }

  void _replaceAllMatches() {
    if (_searchMatches.isEmpty) return;

    final query = _findController.text;
    final replacement = _replaceController.text;

    for (final cell in _notebook!.cells) {
      if (cell.source.toLowerCase().contains(query.toLowerCase())) {
        final newSource = cell.source.replaceAll(
          RegExp(RegExp.escape(query), caseSensitive: false),
          replacement,
        );
        _updateCellSource(cell.id, newSource);
      }
    }

    setState(() {
      _searchMatches = [];
      _currentMatchIndex = -1;
    });
  }

  // Undo/Redo methods
  void _saveToHistory() {
    if (_notebook == null) return;

    // Debounce history saves
    _historyDebounceTimer?.cancel();
    _historyDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _pushToHistory();
    });
  }

  void _pushToHistory() {
    if (_notebook == null) return;

    final state = _NotebookState(
      cells: _notebook!.cells.map((c) => c.copyWith()).toList(),
      selectedCellId: _selectedCellId,
    );

    _undoStack.add(state);
    _redoStack.clear(); // Clear redo stack on new change

    // Limit history size
    if (_undoStack.length > _maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }

  void undo() {
    if (_undoStack.isEmpty || _notebook == null) return;

    // Save current state to redo stack
    final currentState = _NotebookState(
      cells: _notebook!.cells.map((c) => c.copyWith()).toList(),
      selectedCellId: _selectedCellId,
    );
    _redoStack.add(currentState);

    // Restore previous state
    final previousState = _undoStack.removeLast();
    setState(() {
      _notebook = _notebook!.copyWith(cells: previousState.cells);
      _selectedCellId = previousState.selectedCellId;
    });
  }

  void redo() {
    if (_redoStack.isEmpty || _notebook == null) return;

    // Save current state to undo stack
    final currentState = _NotebookState(
      cells: _notebook!.cells.map((c) => c.copyWith()).toList(),
      selectedCellId: _selectedCellId,
    );
    _undoStack.add(currentState);

    // Restore next state
    final nextState = _redoStack.removeLast();
    setState(() {
      _notebook = _notebook!.copyWith(cells: nextState.cells);
      _selectedCellId = nextState.selectedCellId;
    });
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  // Outline methods
  void toggleOutline() {
    setState(() => _showOutline = !_showOutline);
  }

  bool get showOutline => _showOutline;
  bool get showPackages => _showPackages;
  bool get showSplitView => _showSplitView;
  bool get showExecutionLogs => _showExecutionLogs;

  void togglePackages() {
    setState(() => _showPackages = !_showPackages);
  }

  void toggleExecutionLogs() {
    setState(() {
      if (_showExecutionLogs && _logsMinimized) {
        _logsMinimized = false;
      } else if (_showExecutionLogs && !_logsMinimized) {
        _showExecutionLogs = false;
      } else {
        _showExecutionLogs = true;
        _logsMinimized = false;
      }
    });
  }

  void toggleSplitView() {
    setState(() {
      _showSplitView = !_showSplitView;
      if (_showSplitView && _notebook != null && _notebook!.cells.length >= 2) {
        // Auto-select first two cells
        _splitLeftCellId = _notebook!.cells.first.id;
        _splitRightCellId = _notebook!.cells.length > 1
            ? _notebook!.cells[1].id
            : null;
      }
    });
  }

  void showKeyboardShortcuts() {
    KeyboardShortcutsDialog.show(context);
  }

  void openSplitViewWithCells(String leftCellId, String? rightCellId) {
    setState(() {
      _showSplitView = true;
      _splitLeftCellId = leftCellId;
      _splitRightCellId = rightCellId;
    });
  }

  void _addCellToSplitView(String cellId) {
    setState(() {
      if (!_showSplitView) {
        // Open split view with this cell on the left
        _showSplitView = true;
        _splitLeftCellId = cellId;
        _splitRightCellId = null;
      } else if (_splitLeftCellId == null) {
        _splitLeftCellId = cellId;
      } else if (_splitRightCellId == null) {
        _splitRightCellId = cellId;
      } else {
        // Both cells are set, replace right cell
        _splitRightCellId = cellId;
      }
    });
  }

  List<_OutlineItem> _getOutlineItems() {
    if (_notebook == null) return [];

    final items = <_OutlineItem>[];

    for (final cell in _notebook!.cells) {
      if (cell.cellType == CellType.markdown) {
        final lines = cell.source.split('\n');
        for (final line in lines) {
          if (line.startsWith('# ')) {
            items.add(_OutlineItem(
              title: line.substring(2).trim(),
              level: 1,
              cellId: cell.id,
            ));
          } else if (line.startsWith('## ')) {
            items.add(_OutlineItem(
              title: line.substring(3).trim(),
              level: 2,
              cellId: cell.id,
            ));
          } else if (line.startsWith('### ')) {
            items.add(_OutlineItem(
              title: line.substring(4).trim(),
              level: 3,
              cellId: cell.id,
            ));
          }
        }
      }
    }

    return items;
  }

  void _scrollToCell(String cellId) {
    setState(() {
      _selectedCellId = cellId;
    });
    // The cell will be highlighted when selected
  }

  @override
  void initState() {
    super.initState();
    _loadNotebook();
  }

  @override
  void dispose() {
    _executionSubscription?.cancel();
    _executionService?.dispose();
    _variableRefreshTimer?.cancel();
    _historyDebounceTimer?.cancel();
    _findController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  Future<void> _refreshVariables() async {
    if (_kernel == null) return;
    try {
      final response = await kernelService.getVariables(_kernel!.id);
      if (mounted && response != null) {
        setState(() => _variables = List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _loadNotebook() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load notebook from backend
      final notebook = await notebookService.get(widget.notebookId);
      if (notebook == null) {
        // Create a new notebook if it doesn't exist
        final newNotebook = await notebookService.create('New Notebook');
        if (newNotebook != null) {
          setState(() {
            _notebook = newNotebook;
            _isLoading = false;
          });
        } else {
          // Fallback to empty notebook
          setState(() {
            _notebook = Notebook(
              id: widget.notebookId,
              name: 'New Notebook',
              cells: [
                Cell(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  cellType: CellType.code,
                  source: '# Start coding here\nprint("Hello, GPU Notebook!")',
                ),
              ],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _notebook = notebook;
          _isLoading = false;
        });
      }

      // Initialize kernel
      await _initKernel();
    } catch (e) {
      setState(() {
        _error = 'Failed to load notebook: $e';
        _isLoading = false;
        // Fallback to empty notebook
        _notebook = Notebook(
          id: widget.notebookId,
          name: 'New Notebook',
          cells: [
            Cell(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              cellType: CellType.code,
              source: '# Start coding here\nprint("Hello, GPU Notebook!")',
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      });
      await _initKernel();
    }
  }

  Future<void> _initKernel() async {
    setState(() => _kernelStatus = 'starting');

    try {
      // Try to get existing kernels or create new one
      final kernels = await kernelService.list();
      if (kernels.isNotEmpty) {
        _kernel = kernels.first;
      } else {
        _kernel = await kernelService.create('python3', notebookId: widget.notebookId);
      }

      if (_kernel != null) {
        // Setup execution service
        _executionService = ExecutionService();
        await _executionService!.connectToKernel(_kernel!.id);

        // Listen to execution events
        _executionSubscription = _executionService!.events.listen(_handleExecutionEvent);

        setState(() => _kernelStatus = 'idle');
      }
    } catch (e) {
      setState(() => _kernelStatus = 'error');
    }
  }

  void _handleExecutionEvent(ExecutionEvent event) {
    if (!mounted || _notebook == null) return;

    setState(() {
      switch (event.type) {
        case ExecutionEventType.started:
          _kernelStatus = 'busy';
          _logsMinimized = false; // Auto-expand logs when execution starts
          _addLog('info', 'Execution started', cellId: event.cellId);
          if (event.cellId != null) {
            _updateCellStatus(event.cellId!, CellStatus.running);
          }
          break;

        case ExecutionEventType.output:
          if (event.cellId != null && event.output != null) {
            _appendCellOutput(event.cellId!, event.output!);
            // Add to execution logs
            final output = event.output!;
            String logType = 'stdout';
            String? message = output.text;

            if (output.outputType == 'error') {
              logType = 'error';
              message = output.text ?? '${output.ename}: ${output.evalue}';
              if (output.traceback != null && output.traceback!.isNotEmpty) {
                message = output.traceback!.join('\n');
              }
            } else if (output.outputType == 'stream') {
              logType = output.text?.contains('Error') == true ? 'stderr' : 'stdout';
            }

            if (message != null && message.isNotEmpty) {
              _addLog(logType, message, cellId: event.cellId);
            }
          }
          break;

        case ExecutionEventType.completed:
          _kernelStatus = 'idle';
          if (event.cellId != null) {
            final isError = event.status == 'error';
            _updateCellStatus(
              event.cellId!,
              isError ? CellStatus.error : CellStatus.success,
              executionCount: event.executionCount,
            );
            _addLog(
              isError ? 'error' : 'success',
              isError ? 'Execution failed' : 'Execution completed',
              cellId: event.cellId,
            );
          }
          break;

        case ExecutionEventType.interrupted:
          _kernelStatus = 'idle';
          _addLog('warning', 'Execution interrupted', cellId: event.cellId);
          if (event.cellId != null) {
            _updateCellStatus(event.cellId!, CellStatus.idle);
          }
          break;

        case ExecutionEventType.error:
          _kernelStatus = 'idle';
          if (event.cellId != null) {
            _updateCellStatus(event.cellId!, CellStatus.error);
            _addLog('error', event.error ?? 'Unknown error', cellId: event.cellId);
            if (event.error != null) {
              _appendCellOutput(event.cellId!, ExecutionOutput(
                outputType: 'error',
                text: event.error,
              ));
            }
          }
          break;
      }
    });
  }

  void _addLog(String type, String message, {String? cellId}) {
    _executionLogs.add(LogEntry(
      type: type,
      message: message,
      cellId: cellId,
    ));
    // Keep max 500 logs
    if (_executionLogs.length > 500) {
      _executionLogs.removeAt(0);
    }
  }

  void _updateCellStatus(String cellId, CellStatus status, {int? executionCount}) {
    if (_notebook == null) return;
    final cells = _notebook!.cells.map((cell) {
      if (cell.id == cellId) {
        return cell.copyWith(
          status: status,
          executionCount: executionCount ?? cell.executionCount,
        );
      }
      return cell;
    }).toList();
    _notebook = _notebook!.copyWith(cells: cells);
  }

  void _appendCellOutput(String cellId, ExecutionOutput output) {
    if (_notebook == null) return;
    final cells = _notebook!.cells.map((cell) {
      if (cell.id == cellId) {
        final outputs = List<CellOutput>.from(cell.outputs);
        outputs.add(CellOutput(
          outputType: output.outputType,
          text: output.text,
          data: output.data,
        ));
        return cell.copyWith(outputs: outputs);
      }
      return cell;
    }).toList();
    _notebook = _notebook!.copyWith(cells: cells);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading notebook...', style: TextStyle(color: AppColors.mutedForeground)),
          ],
        ),
      );
    }

    if (_notebook == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.fileX, size: 48, color: AppColors.mutedForeground),
            const SizedBox(height: 16),
            Text(_error ?? 'Failed to load notebook', style: TextStyle(color: AppColors.mutedForeground)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadNotebook,
              icon: Icon(LucideIcons.refreshCw, size: 16),
              label: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        children: [
          Column(
            children: [
              // Find & Replace Panel
              if (_showFindReplace)
                _FindReplacePanel(
                  findController: _findController,
                  replaceController: _replaceController,
                  matchCount: _searchMatches.length,
                  currentMatch: _currentMatchIndex + 1,
                  onSearch: _performSearch,
                  onNext: _goToNextMatch,
                  onPrevious: _goToPreviousMatch,
                  onReplace: _replaceCurrentMatch,
                  onReplaceAll: _replaceAllMatches,
                  onClose: () => setState(() => _showFindReplace = false),
                ),
              Expanded(
                child: Row(
                  children: [
                    // Outline panel (left side)
                    if (_showOutline)
                      _OutlinePanel(
                        items: _getOutlineItems(),
                        onItemTap: _scrollToCell,
                        onClose: () => setState(() => _showOutline = false),
                      ),
                    // Main notebook area with drag & drop
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: Column(
                              children: [
                                ReorderableListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  buildDefaultDragHandles: false,
                                  itemCount: _notebook!.cells.length,
                                  onReorder: _reorderCells,
                                  itemBuilder: (context, index) {
                                    final cell = _notebook!.cells[index];
                                return ReorderableDragStartListener(
                                  key: ValueKey(cell.id),
                                  index: index,
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 16),
                                    child: _CellWidget(
                                      cell: cell,
                                      index: index,
                                      isSelected: cell.id == _selectedCellId,
                                      isCommandMode: _isCommandMode,
                                      kernelId: _kernel?.id,
                                      onSelect: () => setState(() => _selectedCellId = cell.id),
                                      onRun: () => _runCell(cell.id),
                                      onRunAndAdvance: () => _runCellAndAdvance(cell.id, index),
                                      onChange: (source) => _updateCellSource(cell.id, source),
                                      onDelete: () => _deleteCell(cell.id),
                                      onMoveUp: () => _moveCell(cell.id, -1),
                                      onMoveDown: () => _moveCell(cell.id, 1),
                                      onClearOutput: () => _clearCellOutput(cell.id),
                                      onToggleType: () => _toggleCellType(cell.id),
                                      onCopy: () => _copyCell(cell.id),
                                      isCollapsed: _collapsedCells.contains(cell.id),
                                      onToggleCollapse: () => _toggleCellCollapse(cell.id),
                                      onAddTag: (tag) => _addTagToCell(cell.id, tag),
                                      onRemoveTag: (tag) => _removeTagFromCell(cell.id, tag),
                                      onUpdateMetadata: (metadata) => _updateCellMetadata(cell.id, metadata),
                                      onAddToSplitView: () => _addCellToSplitView(cell.id),
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildAddCellButtons(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Variable inspector panel
                if (_showVariables)
                  _VariableInspectorPanel(
                    variables: _variables,
                    onRefresh: _refreshVariables,
                    onClose: () => setState(() => _showVariables = false),
                  ),
                // Package manager panel
                if (_showPackages)
                  PackageManagerPanel(
                    onClose: () => setState(() => _showPackages = false),
                  ),
              ],
            ),
          ),
          // Split view panel
          if (_showSplitView && _notebook != null)
            Container(
              height: 400,
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: SplitViewPanel(
                leftCell: _splitLeftCellId != null
                    ? _notebook!.cells.cast<Cell?>().firstWhere(
                        (c) => c?.id == _splitLeftCellId,
                        orElse: () => null,
                      )
                    : null,
                rightCell: _splitRightCellId != null
                    ? _notebook!.cells.cast<Cell?>().firstWhere(
                        (c) => c?.id == _splitRightCellId,
                        orElse: () => null,
                      )
                    : null,
                availableCells: _notebook!.cells,
                kernelId: _kernel?.id,
                onCellChange: _updateCellSource,
                onSelectLeftCell: (id) => setState(() => _splitLeftCellId = id),
                onSelectRightCell: (id) => setState(() => _splitRightCellId = id),
                onClose: () => setState(() => _showSplitView = false),
                onRunCell: _runCell,
              ),
            ),
          _NotebookCLI(onExecute: _executeCommand),
            ],
          ),
          // Floating Execution Log Panel
          if (_showExecutionLogs)
            ExecutionLogPanel(
              logs: _executionLogs,
              isExecuting: _kernelStatus == 'busy',
              isMinimized: _logsMinimized,
              onClear: () => setState(() => _executionLogs.clear()),
              onClose: () => setState(() => _showExecutionLogs = false),
              onMinimize: () => setState(() => _logsMinimized = !_logsMinimized),
            ),
        ],
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;

    // Ctrl+/: Show keyboard shortcuts
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.slash) {
      showKeyboardShortcuts();
      return;
    }

    // Ctrl+Alt+V: Toggle variables panel
    if (isCtrl && isAlt && event.logicalKey == LogicalKeyboardKey.keyV) {
      toggleVariables();
      return;
    }

    // Ctrl+Alt+P: Toggle packages panel
    if (isCtrl && isAlt && event.logicalKey == LogicalKeyboardKey.keyP) {
      togglePackages();
      return;
    }

    // Ctrl+Alt+O: Toggle outline panel
    if (isCtrl && isAlt && event.logicalKey == LogicalKeyboardKey.keyO) {
      toggleOutline();
      return;
    }

    // Ctrl+Alt+L: Toggle execution logs
    if (isCtrl && isAlt && event.logicalKey == LogicalKeyboardKey.keyL) {
      toggleExecutionLogs();
      return;
    }

    // Ctrl+\: Toggle split view
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.backslash) {
      toggleSplitView();
      return;
    }

    // Ctrl+Enter: Run current cell
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedCellId != null) {
        _runCell(_selectedCellId!);
      }
      return;
    }

    // Shift+Enter: Run current cell and advance
    if (isShift && event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedCellId != null && _notebook != null) {
        final index = _notebook!.cells.indexWhere((c) => c.id == _selectedCellId);
        if (index != -1) {
          _runCellAndAdvance(_selectedCellId!, index);
        }
      }
      return;
    }

    // Ctrl+S: Save notebook
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyS) {
      _saveNotebook();
      return;
    }

    // Ctrl+F: Find & Replace
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyF) {
      toggleFindReplace();
      return;
    }

    // Ctrl+Z: Undo
    if (isCtrl && !isShift && event.logicalKey == LogicalKeyboardKey.keyZ) {
      undo();
      return;
    }

    // Ctrl+Shift+Z or Ctrl+Y: Redo
    if ((isCtrl && isShift && event.logicalKey == LogicalKeyboardKey.keyZ) ||
        (isCtrl && event.logicalKey == LogicalKeyboardKey.keyY)) {
      redo();
      return;
    }

    // Escape: Close Find & Replace or enter command mode
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_showFindReplace) {
        setState(() => _showFindReplace = false);
      } else {
        setState(() => _isCommandMode = true);
      }
      return;
    }

    // Command mode shortcuts
    if (_isCommandMode && _selectedCellId != null) {
      final index = _notebook?.cells.indexWhere((c) => c.id == _selectedCellId) ?? -1;

      switch (event.logicalKey) {
        // Enter: Exit command mode (edit mode)
        case LogicalKeyboardKey.enter:
          setState(() => _isCommandMode = false);
          break;

        // A: Insert cell above
        case LogicalKeyboardKey.keyA:
          _insertCell(index, CellType.code);
          break;

        // B: Insert cell below
        case LogicalKeyboardKey.keyB:
          _insertCell(index + 1, CellType.code);
          break;

        // D+D: Delete cell (simplified - single D)
        case LogicalKeyboardKey.keyX:
          _deleteCell(_selectedCellId!);
          break;

        // M: Change to markdown
        case LogicalKeyboardKey.keyM:
          _changeCellType(_selectedCellId!, CellType.markdown);
          break;

        // Y: Change to code
        case LogicalKeyboardKey.keyY:
          _changeCellType(_selectedCellId!, CellType.code);
          break;

        // C: Copy cell
        case LogicalKeyboardKey.keyC:
          _copyCell(_selectedCellId!);
          break;

        // O: Toggle cell collapse
        case LogicalKeyboardKey.keyO:
          _toggleCellCollapse(_selectedCellId!);
          break;

        // T: Add tag (shows quick tag menu)
        case LogicalKeyboardKey.keyT:
          _showQuickTagMenu(_selectedCellId!);
          break;

        // Arrow Up: Select previous cell
        case LogicalKeyboardKey.arrowUp:
        case LogicalKeyboardKey.keyK:
          if (index > 0) {
            setState(() => _selectedCellId = _notebook!.cells[index - 1].id);
          }
          break;

        // Arrow Down: Select next cell
        case LogicalKeyboardKey.arrowDown:
        case LogicalKeyboardKey.keyJ:
          if (_notebook != null && index < _notebook!.cells.length - 1) {
            setState(() => _selectedCellId = _notebook!.cells[index + 1].id);
          }
          break;
      }
    }
  }

  void _runCellAndAdvance(String cellId, int index) {
    _runCell(cellId);
    // Move to next cell or create new one
    if (_notebook != null) {
      if (index < _notebook!.cells.length - 1) {
        setState(() => _selectedCellId = _notebook!.cells[index + 1].id);
      } else {
        // Create new cell at the end
        _addCell(CellType.code);
      }
    }
  }

  void _insertCell(int position, CellType type) {
    if (_notebook == null) return;
    final newCell = Cell(id: DateTime.now().millisecondsSinceEpoch.toString(), cellType: type, source: '');
    setState(() {
      final cells = List<Cell>.from(_notebook!.cells);
      if (position >= 0 && position <= cells.length) {
        cells.insert(position, newCell);
      } else {
        cells.add(newCell);
      }
      _notebook = _notebook!.copyWith(cells: cells);
      _selectedCellId = newCell.id;
    });
  }

  void _changeCellType(String cellId, CellType type) {
    if (_notebook == null) return;
    setState(() {
      final cells = _notebook!.cells.map((cell) {
        if (cell.id == cellId) {
          return cell.copyWith(cellType: type);
        }
        return cell;
      }).toList();
      _notebook = _notebook!.copyWith(cells: cells);
    });
  }

  void _clearCellOutput(String cellId) {
    if (_notebook == null) return;
    setState(() {
      final cells = _notebook!.cells.map((cell) {
        if (cell.id == cellId) {
          return cell.copyWith(outputs: [], status: CellStatus.idle);
        }
        return cell;
      }).toList();
      _notebook = _notebook!.copyWith(cells: cells);
    });
  }

  void _toggleCellType(String cellId) {
    if (_notebook == null) return;
    setState(() {
      final cells = _notebook!.cells.map((cell) {
        if (cell.id == cellId) {
          return cell.copyWith(
            cellType: cell.cellType == CellType.code ? CellType.markdown : CellType.code,
          );
        }
        return cell;
      }).toList();
      _notebook = _notebook!.copyWith(cells: cells);
    });
  }

  void _copyCell(String cellId) {
    if (_notebook == null) return;
    final cell = _notebook!.cells.firstWhere((c) => c.id == cellId, orElse: () => const Cell(id: '', cellType: CellType.code, source: ''));
    if (cell.id.isEmpty) return;

    final newCell = Cell(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      cellType: cell.cellType,
      source: cell.source,
    );

    setState(() {
      final index = _notebook!.cells.indexWhere((c) => c.id == cellId);
      final cells = List<Cell>.from(_notebook!.cells);
      cells.insert(index + 1, newCell);
      _notebook = _notebook!.copyWith(cells: cells);
      _selectedCellId = newCell.id;
    });
  }

  void _toggleCellCollapse(String cellId) {
    setState(() {
      if (_collapsedCells.contains(cellId)) {
        _collapsedCells.remove(cellId);
      } else {
        _collapsedCells.add(cellId);
      }
    });
  }

  // Tag management methods
  void _addTagToCell(String cellId, CellTag tag) {
    if (_notebook == null) return;
    setState(() {
      final cells = _notebook!.cells.map((cell) {
        if (cell.id == cellId) {
          // Don't add duplicate tags
          if (cell.tags.any((t) => t.type == tag.type && t.label == tag.label)) {
            return cell;
          }
          return cell.copyWith(tags: [...cell.tags, tag]);
        }
        return cell;
      }).toList();
      _notebook = _notebook!.copyWith(cells: cells);
    });
  }

  void _removeTagFromCell(String cellId, CellTag tag) {
    if (_notebook == null) return;
    setState(() {
      final cells = _notebook!.cells.map((cell) {
        if (cell.id == cellId) {
          return cell.copyWith(
            tags: cell.tags.where((t) =>
              !(t.type == tag.type && t.label == tag.label)
            ).toList(),
          );
        }
        return cell;
      }).toList();
      _notebook = _notebook!.copyWith(cells: cells);
    });
  }

  void _updateCellMetadata(String cellId, CellMetadata metadata) {
    if (_notebook == null) return;
    setState(() {
      final cells = _notebook!.cells.map((cell) {
        if (cell.id == cellId) {
          return cell.copyWith(metadata: metadata);
        }
        return cell;
      }).toList();
      _notebook = _notebook!.copyWith(cells: cells);
    });
  }

  void _showQuickTagMenu(String cellId) {
    final cell = _notebook?.cells.firstWhere((c) => c.id == cellId, orElse: () => const Cell(id: '', cellType: CellType.code, source: ''));
    if (cell == null || cell.id.isEmpty) return;

    // Get common tags not already added
    final availableTags = <CellTag>[];
    for (final type in [
      CellTagType.important,
      CellTagType.todo,
      CellTagType.skip,
      CellTagType.setup,
      CellTagType.visualization,
      CellTagType.model,
    ]) {
      if (!cell.tags.any((t) => t.type == type)) {
        availableTags.add(CellTag.predefined(type));
      }
    }

    if (availableTags.isEmpty) return;

    // Show a quick selection dialog
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.border),
        ),
        child: Container(
          width: 240,
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Add Tag',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: availableTags.map((tag) {
                  return GestureDetector(
                    onTap: () {
                      _addTagToCell(cellId, tag);
                      Navigator.of(ctx).pop();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(tag.color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Color(tag.color).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getTagIconForType(tag.type), size: 12, color: Color(tag.color)),
                          const SizedBox(width: 4),
                          Text(
                            tag.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(tag.color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTagIconForType(CellTagType type) {
    switch (type) {
      case CellTagType.important:
        return LucideIcons.alertCircle;
      case CellTagType.todo:
        return LucideIcons.checkSquare;
      case CellTagType.skip:
        return LucideIcons.skipForward;
      case CellTagType.slow:
        return LucideIcons.clock;
      case CellTagType.test:
        return LucideIcons.testTube2;
      case CellTagType.setup:
        return LucideIcons.settings;
      case CellTagType.cleanup:
        return LucideIcons.trash2;
      case CellTagType.visualization:
        return LucideIcons.lineChart;
      case CellTagType.dataLoad:
        return LucideIcons.database;
      case CellTagType.model:
        return LucideIcons.brain;
      case CellTagType.custom:
        return LucideIcons.tag;
    }
  }

  void _reorderCells(int oldIndex, int newIndex) {
    if (_notebook == null) return;
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final cells = List<Cell>.from(_notebook!.cells);
      final cell = cells.removeAt(oldIndex);
      cells.insert(newIndex, cell);
      _notebook = _notebook!.copyWith(cells: cells);
    });
  }

  // Public methods for AI Chat Panel
  void addCellWithCode(String code, int? position) => _addCellWithCode(code, position);
  void updateCellSource(String cellId, String source) => _updateCellSource(cellId, source);
  void deleteCellById(String cellId) => _deleteCell(cellId);
  Future<void> runCellById(String cellId) => _runCell(cellId);
  String? get selectedCellId => _selectedCellId;

  void _executeCommand(String command) {
    if (_notebook == null) return;
    // Add a new cell with the command and run it
    final cellId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _notebook = _notebook!.copyWith(
        cells: [
          ..._notebook!.cells,
          Cell(
            id: cellId,
            cellType: CellType.code,
            source: command,
            status: CellStatus.running,
          ),
        ],
      );
      _selectedCellId = cellId;
    });
    _runCell(cellId);
  }

  Widget _buildAddCellButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AddCellButton(label: '+ Code', onTap: () => _addCell(CellType.code)),
          const SizedBox(width: 12),
          _AddCellButton(label: '+ Markdown', onTap: () => _addCell(CellType.markdown)),
        ],
      ),
    );
  }

  void _addCell(CellType type) {
    if (_notebook == null) return;
    final newCell = Cell(id: DateTime.now().millisecondsSinceEpoch.toString(), cellType: type, source: '');
    setState(() {
      final cells = List<Cell>.from(_notebook!.cells)..add(newCell);
      _notebook = _notebook!.copyWith(cells: cells);
      _selectedCellId = newCell.id;
    });
  }

  void _addCellWithCode(String code, int? position) {
    if (_notebook == null) return;
    final newCell = Cell(id: DateTime.now().millisecondsSinceEpoch.toString(), cellType: CellType.code, source: code);
    setState(() {
      final cells = List<Cell>.from(_notebook!.cells);
      if (position != null && position >= 0 && position <= cells.length) {
        cells.insert(position, newCell);
      } else {
        cells.add(newCell);
      }
      _notebook = _notebook!.copyWith(cells: cells);
      _selectedCellId = newCell.id;
    });
  }

  void _deleteCell(String cellId) {
    if (_notebook == null) return;
    setState(() {
      final cells = _notebook!.cells.where((c) => c.id != cellId).toList();
      _notebook = _notebook!.copyWith(cells: cells);
      if (_selectedCellId == cellId) _selectedCellId = null;
    });
  }

  void _moveCell(String cellId, int direction) {
    if (_notebook == null) return;
    setState(() {
      final cells = List<Cell>.from(_notebook!.cells);
      final index = cells.indexWhere((c) => c.id == cellId);
      if (index == -1) return;
      final newIndex = index + direction;
      if (newIndex < 0 || newIndex >= cells.length) return;
      final cell = cells.removeAt(index);
      cells.insert(newIndex, cell);
      _notebook = _notebook!.copyWith(cells: cells);
    });
  }

  void _updateCellSource(String cellId, String source) {
    if (_notebook == null) return;
    _saveToHistory(); // Save state before modification
    setState(() {
      final cells = _notebook!.cells.map((cell) => cell.id == cellId ? cell.copyWith(source: source) : cell).toList();
      _notebook = _notebook!.copyWith(cells: cells);
    });
  }

  Future<void> _runCell(String cellId) async {
    if (_notebook == null) return;

    // Find the cell
    final cell = _notebook!.cells.firstWhere(
      (c) => c.id == cellId,
      orElse: () => const Cell(id: '', cellType: CellType.code, source: ''),
    );
    if (cell.id.isEmpty || cell.source.trim().isEmpty) return;

    // Clear previous outputs and set running
    setState(() {
      _kernelStatus = 'busy';
      _executionCounter++;
      final cells = _notebook!.cells.map((c) {
        if (c.id == cellId) {
          return c.copyWith(status: CellStatus.running, outputs: []);
        }
        return c;
      }).toList();
      _notebook = _notebook!.copyWith(cells: cells);
    });

    try {
      if (_executionService != null && _kernel != null) {
        // Use WebSocket for real-time output
        _executionService!.executeViaWebSocket(_kernel!.id, cell.source, cellId);
      } else {
        // Fallback to HTTP execution
        final request = ExecutionRequest(
          kernelId: _kernel?.id ?? 'default',
          code: cell.source,
          cellId: cellId,
        );
        final result = await executionService.execute(request);

        if (mounted) {
          setState(() {
            _kernelStatus = 'idle';
            final cells = _notebook!.cells.map((c) {
              if (c.id == cellId) {
                return c.copyWith(
                  status: result.error != null ? CellStatus.error : CellStatus.success,
                  executionCount: _executionCounter,
                  outputs: result.outputs.map((o) => CellOutput(
                    outputType: o.outputType,
                    text: o.text,
                    data: o.data,
                  )).toList(),
                );
              }
              return c;
            }).toList();
            _notebook = _notebook!.copyWith(cells: cells);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _kernelStatus = 'idle';
          final cells = _notebook!.cells.map((c) {
            if (c.id == cellId) {
              return c.copyWith(
                status: CellStatus.error,
                outputs: [CellOutput(outputType: 'error', text: 'Execution error: $e')],
              );
            }
            return c;
          }).toList();
          _notebook = _notebook!.copyWith(cells: cells);
        });
      }
    }
  }

  void _runAllCells() {
    if (_notebook == null) return;
    for (final cell in _notebook!.cells) {
      if (cell.cellType == CellType.code) _runCell(cell.id);
    }
  }

  void _clearOutputs() {
    if (_notebook == null) return;
    setState(() {
      final cells = _notebook!.cells.map((cell) => cell.copyWith(outputs: [], executionCount: null, status: CellStatus.idle)).toList();
      _notebook = _notebook!.copyWith(cells: cells);
    });
  }

  Future<void> _restartKernel() async {
    if (_kernel == null) return;

    setState(() => _kernelStatus = 'restarting');

    try {
      _kernel = await kernelService.restart(_kernel!.id);

      // Reconnect execution service
      _executionSubscription?.cancel();
      _executionService?.disconnectFromKernel();

      if (_kernel != null) {
        _executionService = ExecutionService();
        await _executionService!.connectToKernel(_kernel!.id);
        _executionSubscription = _executionService!.events.listen(_handleExecutionEvent);
      }

      if (mounted) setState(() => _kernelStatus = 'idle');
    } catch (e) {
      if (mounted) setState(() => _kernelStatus = 'error');
    }
  }

  Future<void> _stopExecution() async {
    if (_notebook == null) return;

    try {
      if (_kernel != null) {
        if (_executionService != null) {
          _executionService!.interruptViaWebSocket(_kernel!.id);
        } else {
          await kernelService.interrupt(_kernel!.id);
        }
      }
    } catch (e) {
      // Ignore interrupt errors
    }

    setState(() {
      _kernelStatus = 'idle';
      final cells = _notebook!.cells.map((cell) {
        if (cell.status == CellStatus.running) {
          return cell.copyWith(status: CellStatus.idle);
        }
        return cell;
      }).toList();
      _notebook = _notebook!.copyWith(cells: cells);
    });
  }

  Future<void> _saveNotebook() async {
    if (_notebook == null) return;

    final result = await notebookService.update(
      widget.notebookId,
      name: _notebook!.name,
      cells: _notebook!.cells,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result != null ? 'Notebook saved successfully' : 'Failed to save notebook'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: result != null ? AppColors.success : AppColors.destructive,
        ),
      );
    }
  }
}

class _AddCellButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _AddCellButton({required this.label, required this.onTap});

  @override
  State<_AddCellButton> createState() => _AddCellButtonState();
}

class _AddCellButtonState extends State<_AddCellButton> {
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
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.muted : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _isHovered ? AppColors.border : AppColors.muted),
          ),
          child: Text(widget.label, style: TextStyle(fontSize: 13, color: _isHovered ? AppColors.foreground : AppColors.mutedForeground)),
        ),
      ),
    );
  }
}

// New unified Cell Widget with markdown support
class _CellWidget extends StatefulWidget {
  final Cell cell;
  final int index;
  final bool isSelected;
  final bool isCommandMode;
  final String? kernelId;
  final VoidCallback onSelect;
  final VoidCallback onRun;
  final VoidCallback onRunAndAdvance;
  final Function(String) onChange;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onClearOutput;
  final VoidCallback onToggleType;
  final VoidCallback onCopy;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final Function(CellTag) onAddTag;
  final Function(CellTag) onRemoveTag;
  final Function(CellMetadata) onUpdateMetadata;
  final VoidCallback? onAddToSplitView;

  const _CellWidget({
    required this.cell,
    required this.index,
    required this.isSelected,
    required this.isCommandMode,
    this.kernelId,
    required this.onSelect,
    required this.onRun,
    required this.onRunAndAdvance,
    required this.onChange,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onClearOutput,
    required this.onToggleType,
    required this.onCopy,
    this.isCollapsed = false,
    required this.onToggleCollapse,
    required this.onAddTag,
    required this.onRemoveTag,
    required this.onUpdateMetadata,
    this.onAddToSplitView,
  });

  @override
  State<_CellWidget> createState() => _CellWidgetState();
}

class _CellWidgetState extends State<_CellWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isHovered = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.cell.source);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (widget.cell.cellType == CellType.markdown) {
      setState(() => _isEditing = _focusNode.hasFocus);
    }
  }

  @override
  void didUpdateWidget(_CellWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cell.source != widget.cell.source) {
      _controller.text = widget.cell.source;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.cell.status) {
      case CellStatus.running: return AppColors.warning;
      case CellStatus.success: return AppColors.success;
      case CellStatus.error: return AppColors.destructive;
      default: return AppColors.mutedForeground;
    }
  }

  Color get _cellTypeColor {
    return widget.cell.cellType == CellType.code ? AppColors.primary : AppColors.success;
  }

  void _showTagMenu(BuildContext context) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset offset = box.localToGlobal(Offset.zero);

    showMenu<CellTag>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + box.size.width - 200,
        offset.dy,
        offset.dx + box.size.width,
        offset.dy + 200,
      ),
      items: _buildTagMenuItems(),
      elevation: 8,
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
    ).then((selectedTag) {
      if (selectedTag != null) {
        widget.onAddTag(selectedTag);
      }
    });
  }

  List<PopupMenuEntry<CellTag>> _buildTagMenuItems() {
    final items = <PopupMenuEntry<CellTag>>[];

    items.add(
      PopupMenuItem<CellTag>(
        enabled: false,
        height: 24,
        child: Text(
          'ADD TAG',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.mutedForeground,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );

    for (final type in CellTagType.values) {
      if (type == CellTagType.custom) continue;

      final tag = CellTag.predefined(type);
      final isAlreadyAdded = widget.cell.tags.any((t) => t.type == type);

      items.add(
        PopupMenuItem<CellTag>(
          value: isAlreadyAdded ? null : tag,
          enabled: !isAlreadyAdded,
          height: 36,
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Color(tag.color).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  _getTagIcon(tag.type),
                  size: 10,
                  color: Color(tag.color),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tag.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isAlreadyAdded ? AppColors.mutedForeground : AppColors.foreground,
                  ),
                ),
              ),
              if (isAlreadyAdded)
                Icon(LucideIcons.check, size: 14, color: AppColors.success),
            ],
          ),
        ),
      );
    }

    return items;
  }

  IconData _getTagIcon(CellTagType type) {
    switch (type) {
      case CellTagType.important:
        return LucideIcons.alertCircle;
      case CellTagType.todo:
        return LucideIcons.checkSquare;
      case CellTagType.skip:
        return LucideIcons.skipForward;
      case CellTagType.slow:
        return LucideIcons.clock;
      case CellTagType.test:
        return LucideIcons.testTube2;
      case CellTagType.setup:
        return LucideIcons.settings;
      case CellTagType.cleanup:
        return LucideIcons.trash2;
      case CellTagType.visualization:
        return LucideIcons.lineChart;
      case CellTagType.dataLoad:
        return LucideIcons.database;
      case CellTagType.model:
        return LucideIcons.brain;
      case CellTagType.custom:
        return LucideIcons.tag;
    }
  }

  void _showMetadataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CellMetadataDialog(
        cell: widget.cell,
        onSave: widget.onUpdateMetadata,
      ),
    );
  }

  Widget _buildOutput(CellOutput output) {
    if (output.outputType == 'error') {
      return _buildErrorOutput(output);
    }

    if (output.data != null) {
      if (output.data!.containsKey('image/png')) {
        return _buildImageOutput(output.data!['image/png'], 'png');
      }
      if (output.data!.containsKey('image/jpeg')) {
        return _buildImageOutput(output.data!['image/jpeg'], 'jpeg');
      }
      if (output.data!.containsKey('image/svg+xml')) {
        return _buildSvgOutput(output.data!['image/svg+xml']);
      }
      if (output.data!.containsKey('text/html')) {
        return _buildHtmlOutput(output.data!['text/html']);
      }
      if (output.data!.containsKey('text/plain')) {
        final text = output.data!['text/plain'];
        return _buildTextOutput(text is List ? text.join('') : text.toString());
      }
    }

    if (output.text != null && output.text!.isNotEmpty) {
      return _buildTextOutput(output.text!);
    }

    return SizedBox.shrink();
  }

  Widget _buildTextOutput(String text) {
    // Check for tqdm progress bar pattern
    final tqdmPattern = RegExp(r'(\d+)%\|([█▏▎▍▌▋▊▉ ]+)\|\s*(\d+)/(\d+)');
    final match = tqdmPattern.firstMatch(text);

    if (match != null) {
      final percentage = int.tryParse(match.group(1) ?? '0') ?? 0;
      final current = int.tryParse(match.group(3) ?? '0') ?? 0;
      final total = int.tryParse(match.group(4) ?? '100') ?? 100;

      // Extract timing info if present
      final timingMatch = RegExp(r'\[([^\]]+)\]').firstMatch(text);
      final timing = timingMatch?.group(1) ?? '';

      return Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress bar
            Row(
              children: [
                Text(
                  '$percentage%',
                  style: AppTheme.monoStyle.copyWith(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage / 100,
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$current/$total',
                  style: AppTheme.monoStyle.copyWith(
                    color: AppColors.mutedForeground,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            if (timing.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  timing,
                  style: AppTheme.monoStyle.copyWith(
                    color: AppColors.mutedForeground,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Regular text output
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: SelectableText(
        text,
        style: AppTheme.monoStyle.copyWith(color: AppColors.foreground, fontSize: 13),
      ),
    );
  }

  Widget _buildErrorOutput(CellOutput output) {
    final errorName = output.ename ?? 'Error';
    final errorValue = output.evalue ?? output.text ?? 'Unknown error';
    final traceback = output.traceback;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.destructive.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.destructive.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.alertCircle, size: 16, color: AppColors.destructive),
              const SizedBox(width: 8),
              Text(errorName, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.destructive, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(errorValue, style: AppTheme.monoStyle.copyWith(color: AppColors.destructive, fontSize: 12)),
          if (traceback != null && traceback.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.codeBg, borderRadius: BorderRadius.circular(4)),
              child: SelectableText(
                traceback.join('\n'),
                style: AppTheme.monoStyle.copyWith(color: AppColors.destructive.withOpacity(0.8), fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageOutput(dynamic imageData, String format) {
    try {
      String base64String;
      if (imageData is List) {
        base64String = imageData.join('');
      } else {
        base64String = imageData.toString();
      }
      base64String = base64String.replaceAll(RegExp(r'\s'), '');

      final bytes = base64Decode(base64String);
      return Container(
        margin: EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      );
    } catch (e) {
      return _buildTextOutput('[Image decode error: $e]');
    }
  }

  Widget _buildSvgOutput(dynamic svgData) {
    String svgString = svgData is List ? svgData.join('') : svgData.toString();
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.image, size: 16, color: AppColors.mutedForeground),
              const SizedBox(width: 8),
              Text('SVG Image', style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: SelectableText(
                svgString.length > 500 ? '${svgString.substring(0, 500)}...' : svgString,
                style: AppTheme.monoStyle.copyWith(fontSize: 10, color: AppColors.mutedForeground),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHtmlOutput(dynamic htmlData) {
    String htmlString = htmlData is List ? htmlData.join('') : htmlData.toString();

    if (htmlString.contains('<table') || htmlString.contains('<div')) {
      return Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.table, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('DataFrame / Table', style: TextStyle(color: AppColors.foreground, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: _parseHtmlTable(htmlString),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(4)),
      child: SelectableText(_stripHtml(htmlString), style: AppTheme.monoStyle.copyWith(fontSize: 12)),
    );
  }

  Widget _parseHtmlTable(String html) {
    try {
      final rows = <List<String>>[];
      final rowMatches = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true).allMatches(html);

      for (final rowMatch in rowMatches) {
        final rowHtml = rowMatch.group(1) ?? '';
        final cells = <String>[];
        final cellMatches = RegExp(r'<t[hd][^>]*>(.*?)</t[hd]>', dotAll: true).allMatches(rowHtml);
        for (final cellMatch in cellMatches) {
          cells.add(_stripHtml(cellMatch.group(1) ?? '').trim());
        }
        if (cells.isNotEmpty) rows.add(cells);
      }

      if (rows.isEmpty) {
        return SelectableText(_stripHtml(html), style: AppTheme.monoStyle.copyWith(fontSize: 12));
      }

      return Table(
        border: TableBorder.all(color: AppColors.border, width: 1),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: rows.asMap().entries.map((entry) {
          final isHeader = entry.key == 0;
          return TableRow(
            decoration: BoxDecoration(color: isHeader ? AppColors.muted : null),
            children: entry.value.map((cell) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  cell,
                  style: TextStyle(fontSize: 12, fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, color: AppColors.foreground),
                ),
              );
            }).toList(),
          );
        }).toList(),
      );
    } catch (e) {
      return SelectableText(_stripHtml(html), style: AppTheme.monoStyle.copyWith(fontSize: 12));
    }
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .trim();
  }

  Widget _buildMarkdownPreview() {
    final source = widget.cell.source;
    if (source.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(12),
        child: Text('Empty markdown cell. Click to edit.', style: TextStyle(color: AppColors.mutedForeground, fontStyle: FontStyle.italic)),
      );
    }

    // Simple markdown rendering
    final lines = source.split('\n');
    return Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          // Headers
          if (line.startsWith('# ')) {
            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(line.substring(2), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.foreground)),
            );
          }
          if (line.startsWith('## ')) {
            return Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(line.substring(3), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.foreground)),
            );
          }
          if (line.startsWith('### ')) {
            return Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(line.substring(4), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.foreground)),
            );
          }
          // Bold
          if (line.contains('**')) {
            return Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text.rich(_parseInlineMarkdown(line)),
            );
          }
          // List items
          if (line.startsWith('- ') || line.startsWith('* ')) {
            return Padding(
              padding: EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: AppColors.foreground)),
                  Expanded(child: Text(line.substring(2), style: TextStyle(color: AppColors.foreground))),
                ],
              ),
            );
          }
          // Regular text
          return line.isEmpty
              ? const SizedBox(height: 8)
              : Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(line, style: TextStyle(color: AppColors.foreground)),
                );
        }).toList(),
      ),
    );
  }

  TextSpan _parseInlineMarkdown(String text) {
    final spans = <InlineSpan>[];
    final boldPattern = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in boldPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: TextStyle(color: AppColors.foreground)));
      }
      spans.add(TextSpan(text: match.group(1), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.foreground)));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: TextStyle(color: AppColors.foreground)));
    }

    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final isCode = widget.cell.cellType == CellType.code;
    final showEditor = isCode || _isEditing || widget.cell.source.isEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        onDoubleTap: () {
          if (!isCode) setState(() => _isEditing = true);
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isSelected
                  ? (widget.isCommandMode ? AppColors.warning : AppColors.primary)
                  : AppColors.border,
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cell header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.cell.status == CellStatus.running
                      ? AppColors.warning.withOpacity(0.15)
                      : AppColors.secondary.withOpacity(0.5),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5)),
                ),
                child: Row(
                  children: [
                    // Execution count / Cell type indicator
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _cellTypeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCode ? LucideIcons.code : LucideIcons.fileText,
                            size: 12,
                            color: _cellTypeColor,
                          ),
                          const SizedBox(width: 4),
                          if (isCode)
                            Text(
                              widget.cell.status == CellStatus.running
                                  ? '[*]'
                                  : widget.cell.executionCount != null
                                      ? '[${widget.cell.executionCount}]'
                                      : '[ ]',
                              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: _statusColor, fontWeight: FontWeight.bold),
                            )
                          else
                            Text('MD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _cellTypeColor)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status indicator
                    if (widget.cell.status == CellStatus.running)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
                      )
                    else if (isCode)
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
                    if (widget.cell.status == CellStatus.running)
                      Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text('Running...', style: TextStyle(fontSize: 11, color: AppColors.warning, fontStyle: FontStyle.italic)),
                      ),
                    // Command mode indicator
                    if (widget.isSelected && widget.isCommandMode)
                      Container(
                        margin: EdgeInsets.only(left: 8),
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('CMD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning)),
                      ),
                    // Cell name from metadata
                    if (widget.cell.metadata.name != null && widget.cell.metadata.name!.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(left: 8),
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.bookmark, size: 10, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              widget.cell.metadata.name!,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    // Cell tags
                    if (widget.cell.tags.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: CellTagsWidget(
                          tags: widget.cell.tags,
                          onAddTag: widget.onAddTag,
                          onRemoveTag: widget.onRemoveTag,
                          isEditable: _isHovered || widget.isSelected,
                        ),
                      ),
                    const Spacer(),
                    // Collapse/Expand button
                    _CellAction(
                      icon: widget.isCollapsed ? LucideIcons.chevronRight : LucideIcons.chevronDown,
                      onTap: widget.onToggleCollapse,
                      tooltip: widget.isCollapsed ? 'Expand' : 'Collapse',
                    ),
                    // Actions
                    if (_isHovered || widget.isSelected) ...[
                      if (isCode) ...[
                        if (widget.cell.status == CellStatus.running)
                          _CellAction(icon: LucideIcons.square, onTap: widget.onRun, color: AppColors.destructive, tooltip: 'Stop')
                        else
                          _CellAction(icon: LucideIcons.play, onTap: widget.onRun, color: AppColors.success, tooltip: 'Run (Ctrl+Enter)'),
                        _CellAction(icon: LucideIcons.skipForward, onTap: widget.onRunAndAdvance, tooltip: 'Run & Advance (Shift+Enter)'),
                      ],
                      _CellAction(icon: LucideIcons.chevronUp, onTap: widget.onMoveUp, tooltip: 'Move Up'),
                      _CellAction(icon: LucideIcons.chevronDown, onTap: widget.onMoveDown, tooltip: 'Move Down'),
                      _CellAction(icon: LucideIcons.copy, onTap: widget.onCopy, tooltip: 'Copy (C)'),
                      _CellAction(
                        icon: isCode ? LucideIcons.fileText : LucideIcons.code,
                        onTap: widget.onToggleType,
                        tooltip: isCode ? 'To Markdown (M)' : 'To Code (Y)',
                      ),
                      // Add tag button (when no tags shown inline)
                      if (widget.cell.tags.isEmpty)
                        _CellAction(
                          icon: LucideIcons.tag,
                          onTap: () => _showTagMenu(context),
                          tooltip: 'Add Tag (T)',
                        ),
                      // Metadata/info button
                      _CellAction(
                        icon: LucideIcons.info,
                        onTap: () => _showMetadataDialog(context),
                        tooltip: 'Cell Metadata',
                      ),
                      // Compare in split view
                      if (widget.onAddToSplitView != null)
                        _CellAction(
                          icon: LucideIcons.columns,
                          onTap: widget.onAddToSplitView!,
                          tooltip: 'Compare in Split View',
                        ),
                      if (widget.cell.outputs.isNotEmpty)
                        _CellAction(icon: LucideIcons.eraser, onTap: widget.onClearOutput, tooltip: 'Clear Output'),
                      _CellAction(icon: LucideIcons.trash2, onTap: widget.onDelete, tooltip: 'Delete (X)'),
                    ],
                  ],
                ),
              ),
              // Cell content (collapsible)
              if (!widget.isCollapsed) ...[
                if (showEditor)
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 60),
                    color: isCode ? AppColors.codeBg : AppColors.card,
                    child: isCode
                        ? CodeEditor(
                            initialValue: widget.cell.source,
                            kernelId: widget.kernelId,
                            onChanged: widget.onChange,
                            focusNode: _focusNode,
                            showLineNumbers: true,
                          )
                        : Padding(
                            padding: EdgeInsets.all(12),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              maxLines: null,
                              style: TextStyle(color: AppColors.foreground),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'Enter markdown text...',
                                hintStyle: TextStyle(color: AppColors.mutedForeground),
                              ),
                              onChanged: widget.onChange,
                              onTap: () {
                                setState(() => _isEditing = true);
                              },
                            ),
                          ),
                  )
                else
                  GestureDetector(
                    onTap: () => setState(() => _isEditing = true),
                    child: _buildMarkdownPreview(),
                  ),
                // Outputs with max height and scroll
                if (widget.cell.outputs.isNotEmpty)
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 400),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.cell.outputs.map((output) => _buildOutput(output)).toList(),
                      ),
                    ),
                  ),
              ] else
                // Collapsed preview
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: AppColors.muted.withOpacity(0.3),
                  child: Text(
                    widget.cell.source.split('\n').first.substring(0, widget.cell.source.split('\n').first.length.clamp(0, 50)) +
                        (widget.cell.source.length > 50 ? '...' : ''),
                    style: AppTheme.monoStyle.copyWith(color: AppColors.mutedForeground, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CellAction extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final String? tooltip;

  const _CellAction({required this.icon, required this.onTap, this.color, this.tooltip});

  @override
  State<_CellAction> createState() => _CellActionState();
}

class _CellActionState extends State<_CellAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? AppColors.mutedForeground;
    final hoverColor = widget.color ?? AppColors.foreground;

    final child = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(widget.icon, size: 14, color: _isHovered ? hoverColor : baseColor),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }
}

// Variable Inspector Panel
class _VariableInspectorPanel extends StatefulWidget {
  final List<Map<String, dynamic>> variables;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  const _VariableInspectorPanel({
    required this.variables,
    required this.onRefresh,
    required this.onClose,
  });

  @override
  State<_VariableInspectorPanel> createState() => _VariableInspectorPanelState();
}

class _VariableInspectorPanelState extends State<_VariableInspectorPanel> {
  final Set<String> _expandedVariables = {};
  String _searchQuery = '';
  String _filterType = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredVariables {
    var filtered = widget.variables;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((v) {
        final name = (v['name'] as String? ?? '').toLowerCase();
        final type = (v['type'] as String? ?? '').toLowerCase();
        return name.contains(_searchQuery.toLowerCase()) ||
               type.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filter by type
    if (_filterType != 'all') {
      filtered = filtered.where((v) {
        final type = (v['type'] as String? ?? '').toLowerCase();
        switch (_filterType) {
          case 'numeric':
            return type == 'int' || type == 'float' || type == 'complex';
          case 'text':
            return type == 'str';
          case 'collection':
            return type == 'list' || type == 'tuple' || type == 'set' || type == 'dict';
          case 'data':
            return type == 'dataframe' || type == 'series' || type == 'ndarray' || type == 'tensor';
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'int':
      case 'float':
      case 'complex':
        return AppColors.primary;
      case 'str':
        return AppColors.success;
      case 'list':
      case 'tuple':
      case 'set':
        return AppColors.warning;
      case 'dict':
        return Colors.purple;
      case 'dataframe':
      case 'series':
        return Colors.orange;
      case 'ndarray':
      case 'tensor':
        return Colors.cyan;
      case 'bool':
        return AppColors.destructive;
      default:
        return AppColors.mutedForeground;
    }
  }

  void _toggleExpand(String name) {
    setState(() {
      if (_expandedVariables.contains(name)) {
        _expandedVariables.remove(name);
      } else {
        _expandedVariables.add(name);
      }
    });
  }

  void _copyToClipboard(String text, BuildContext context) {
    // Copy text to clipboard
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
        backgroundColor: AppColors.success,
      ),
    );
  }

  bool _isExpandable(String type) {
    final t = type.toLowerCase();
    return t == 'dict' || t == 'list' || t == 'tuple' ||
           t == 'dataframe' || t == 'series' || t == 'ndarray' ||
           t == 'tensor' || t == 'object';
  }

  @override
  Widget build(BuildContext context) {
    final filteredVars = _filteredVariables;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.5),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.variable, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Variables', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.foreground)),
                const SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.variables.length}',
                    style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(LucideIcons.refreshCw, size: 14, color: AppColors.mutedForeground),
                  onPressed: widget.onRefresh,
                  tooltip: 'Refresh',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
                IconButton(
                  icon: Icon(LucideIcons.x, size: 14, color: AppColors.mutedForeground),
                  onPressed: widget.onClose,
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
          // Search bar
          Container(
            padding: EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 12, color: AppColors.foreground),
              decoration: InputDecoration(
                hintText: 'Search variables...',
                hintStyle: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                prefixIcon: Icon(LucideIcons.search, size: 14, color: AppColors.mutedForeground),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(LucideIcons.x, size: 12),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        padding: EdgeInsets.zero,
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Type filters
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: 'All', value: 'all', selected: _filterType, onSelect: (v) => setState(() => _filterType = v)),
                  _FilterChip(label: 'Numeric', value: 'numeric', selected: _filterType, onSelect: (v) => setState(() => _filterType = v)),
                  _FilterChip(label: 'Text', value: 'text', selected: _filterType, onSelect: (v) => setState(() => _filterType = v)),
                  _FilterChip(label: 'Collection', value: 'collection', selected: _filterType, onSelect: (v) => setState(() => _filterType = v)),
                  _FilterChip(label: 'Data', value: 'data', selected: _filterType, onSelect: (v) => setState(() => _filterType = v)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Variables list
          Expanded(
            child: filteredVars.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.inbox, size: 32, color: AppColors.mutedForeground),
                        const SizedBox(height: 8),
                        Text(
                          widget.variables.isEmpty ? 'No variables' : 'No matches',
                          style: TextStyle(color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.variables.isEmpty
                              ? 'Execute code to see variables'
                              : 'Try a different search',
                          style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredVars.length,
                    itemBuilder: (context, index) {
                      final variable = filteredVars[index];
                      final name = variable['name'] as String? ?? '';
                      final type = variable['type'] as String? ?? '';
                      final shape = variable['shape'] as String? ?? '';
                      final preview = variable['preview'] as String? ?? '';
                      final size = variable['size'] as int? ?? 0;
                      final children = variable['children'] as List<dynamic>?;
                      final isExpanded = _expandedVariables.contains(name);
                      final canExpand = _isExpandable(type) || (children != null && children.isNotEmpty);

                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main row
                            InkWell(
                              onTap: canExpand ? () => _toggleExpand(name) : null,
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // Expand icon
                                        if (canExpand)
                                          Icon(
                                            isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                                            size: 14,
                                            color: AppColors.mutedForeground,
                                          )
                                        else
                                          SizedBox(width: 14),
                                        const SizedBox(width: 4),
                                        // Variable name
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: AppTheme.monoStyle.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.foreground,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        // Type badge
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getTypeColor(type).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            type,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _getTypeColor(type),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (shape.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          SizedBox(width: 18),
                                          Icon(LucideIcons.box, size: 10, color: AppColors.mutedForeground),
                                          const SizedBox(width: 4),
                                          Text(
                                            shape,
                                            style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    // Preview
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.codeBg,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        preview.length > 150 ? '${preview.substring(0, 150)}...' : preview,
                                        style: AppTheme.monoStyle.copyWith(fontSize: 11, color: AppColors.mutedForeground),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Size row
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(LucideIcons.hardDrive, size: 10, color: AppColors.mutedForeground),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatSize(size),
                                          style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
                                        ),
                                        const Spacer(),
                                        // Copy button
                                        InkWell(
                                          onTap: () => _copyToClipboard(preview, context),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(LucideIcons.copy, size: 12, color: AppColors.mutedForeground),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Expanded content (children)
                            if (isExpanded && children != null && children.isNotEmpty)
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.codeBg,
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(6),
                                    bottomRight: Radius.circular(6),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Divider(height: 1, color: AppColors.border),
                                    ...children.take(20).map((child) {
                                      final childMap = child as Map<String, dynamic>;
                                      final childName = childMap['name'] as String? ?? '';
                                      final childType = childMap['type'] as String? ?? '';
                                      final childValue = childMap['value'] as String? ?? '';

                                      return Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(width: 12),
                                            Text(
                                              childName,
                                              style: AppTheme.monoStyle.copyWith(
                                                fontSize: 11,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            Text(
                                              ': ',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.mutedForeground,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                childValue.length > 80
                                                    ? '${childValue.substring(0, 80)}...'
                                                    : childValue,
                                                style: AppTheme.monoStyle.copyWith(
                                                  fontSize: 11,
                                                  color: _getTypeColor(childType),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: _getTypeColor(childType).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                childType,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: _getTypeColor(childType),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    if (children.length > 20)
                                      Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Text(
                                          '... and ${children.length - 20} more items',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic,
                                            color: AppColors.mutedForeground,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Filter chip for variable types
class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Function(String) onSelect;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;

    return Padding(
      padding: EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => onSelect(value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.muted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary.withOpacity(0.3) : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? AppColors.primary : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotebookCLI extends StatefulWidget {
  final void Function(String) onExecute;

  const _NotebookCLI({required this.onExecute});

  @override
  State<_NotebookCLI> createState() => _NotebookCLIState();
}

class _NotebookCLIState extends State<_NotebookCLI> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _history = [];
  int _historyIndex = -1;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final command = _controller.text.trim();
    if (command.isEmpty) return;

    _history.insert(0, command);
    _historyIndex = -1;
    widget.onExecute(command);
    _controller.clear();
  }

  void _navigateHistory(int direction) {
    if (_history.isEmpty) return;

    final newIndex = _historyIndex + direction;
    if (newIndex < -1 || newIndex >= _history.length) return;

    setState(() {
      _historyIndex = newIndex;
      if (_historyIndex == -1) {
        _controller.clear();
      } else {
        _controller.text = _history[_historyIndex];
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.codeBg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Text(
              '>>>',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          Expanded(
            child: RawKeyboardListener(
              focusNode: FocusNode(),
              onKey: (event) {
                if (event.runtimeType.toString() == 'RawKeyDownEvent') {
                  if (event.logicalKey.keyLabel == 'Arrow Up') {
                    _navigateHistory(1);
                  } else if (event.logicalKey.keyLabel == 'Arrow Down') {
                    _navigateHistory(-1);
                  }
                }
              },
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: AppTheme.monoStyle.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter Python code and press Enter to execute...',
                  hintStyle: TextStyle(color: AppColors.mutedForeground, fontFamily: 'monospace', fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                ),
                onSubmitted: (_) => _handleSubmit(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.play, size: 18),
            color: AppColors.primary,
            onPressed: _handleSubmit,
            tooltip: 'Execute (Enter)',
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// Find & Replace Panel
class _FindReplacePanel extends StatelessWidget {
  final TextEditingController findController;
  final TextEditingController replaceController;
  final int matchCount;
  final int currentMatch;
  final VoidCallback onSearch;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onReplace;
  final VoidCallback onReplaceAll;
  final VoidCallback onClose;

  const _FindReplacePanel({
    required this.findController,
    required this.replaceController,
    required this.matchCount,
    required this.currentMatch,
    required this.onSearch,
    required this.onNext,
    required this.onPrevious,
    required this.onReplace,
    required this.onReplaceAll,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Find input
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: findController,
                style: TextStyle(fontSize: 13, color: AppColors.foreground),
                decoration: InputDecoration(
                  hintText: 'Find...',
                  hintStyle: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
                  prefixIcon: Icon(LucideIcons.search, size: 14, color: AppColors.mutedForeground),
                  suffixIcon: matchCount > 0
                      ? Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              '$currentMatch/$matchCount',
                              style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                            ),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primary)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                ),
                onChanged: (_) => onSearch(),
                onSubmitted: (_) => onNext(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Navigation buttons
          IconButton(
            icon: Icon(LucideIcons.chevronUp, size: 16),
            onPressed: matchCount > 0 ? onPrevious : null,
            tooltip: 'Previous (Shift+Enter)',
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            icon: Icon(LucideIcons.chevronDown, size: 16),
            onPressed: matchCount > 0 ? onNext : null,
            tooltip: 'Next (Enter)',
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          Container(width: 1, height: 20, color: AppColors.border, margin: EdgeInsets.symmetric(horizontal: 8)),
          // Replace input
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: replaceController,
                style: TextStyle(fontSize: 13, color: AppColors.foreground),
                decoration: InputDecoration(
                  hintText: 'Replace...',
                  hintStyle: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
                  prefixIcon: Icon(LucideIcons.replace, size: 14, color: AppColors.mutedForeground),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primary)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Replace buttons
          TextButton(
            onPressed: matchCount > 0 ? onReplace : null,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: Text('Replace', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: matchCount > 0 ? onReplaceAll : null,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: Text('Replace All', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          // Close button
          IconButton(
            icon: Icon(LucideIcons.x, size: 16),
            onPressed: onClose,
            tooltip: 'Close (Esc)',
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

// Search match model
class _SearchMatch {
  final String cellId;
  final int startIndex;
  final int length;

  _SearchMatch({
    required this.cellId,
    required this.startIndex,
    required this.length,
  });
}

// Notebook state for undo/redo
class _NotebookState {
  final List<Cell> cells;
  final String? selectedCellId;

  _NotebookState({
    required this.cells,
    this.selectedCellId,
  });
}

// Outline item model
class _OutlineItem {
  final String title;
  final int level; // 1, 2, or 3
  final String cellId;

  _OutlineItem({
    required this.title,
    required this.level,
    required this.cellId,
  });
}

// Outline panel widget
class _OutlinePanel extends StatelessWidget {
  final List<_OutlineItem> items;
  final void Function(String cellId) onItemTap;
  final VoidCallback onClose;

  const _OutlinePanel({
    required this.items,
    required this.onItemTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.list, size: 16, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                Text(
                  'Outline',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(LucideIcons.x, size: 14),
                  onPressed: onClose,
                  splashRadius: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
          // Items
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No headers found.\nAdd # headers in markdown cells.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final indent = (item.level - 1) * 16.0;

                      return InkWell(
                        onTap: () => onItemTap(item.cellId),
                        child: Container(
                          padding: EdgeInsets.only(
                            left: 12 + indent,
                            right: 12,
                            top: 8,
                            bottom: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.level == 1
                                    ? LucideIcons.heading1
                                    : item.level == 2
                                        ? LucideIcons.heading2
                                        : LucideIcons.heading3,
                                size: 14,
                                color: item.level == 1
                                    ? AppColors.primary
                                    : AppColors.mutedForeground,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: item.level == 1 ? 13 : 12,
                                    fontWeight: item.level == 1
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: item.level == 1
                                        ? AppColors.foreground
                                        : AppColors.mutedForeground,
                                  ),
                                  maxLines: 1,
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
        ],
      ),
    );
  }
}
