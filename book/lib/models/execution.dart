enum ExecutionStatus { queued, running, success, error, cancelled }

class ExecutionRequest {
  final String kernelId;
  final String code;
  final String? cellId;
  final bool silent;
  final bool storeHistory;

  ExecutionRequest({
    required this.kernelId,
    required this.code,
    this.cellId,
    this.silent = false,
    this.storeHistory = true,
  });

  Map<String, dynamic> toJson() => {
        'kernel_id': kernelId,
        'code': code,
        if (cellId != null) 'cell_id': cellId,
        'silent': silent,
        'store_history': storeHistory,
      };
}

class ExecutionOutput {
  final String outputType;
  final String? text;
  final Map<String, dynamic>? data;
  final String? ename;
  final String? evalue;
  final List<String>? traceback;

  ExecutionOutput({
    required this.outputType,
    this.text,
    this.data,
    this.ename,
    this.evalue,
    this.traceback,
  });

  factory ExecutionOutput.fromJson(Map<String, dynamic> json) {
    // Handle text field - can be String, List<String>, or null
    String? textValue;
    final rawText = json['text'];
    if (rawText is String) {
      textValue = rawText;
    } else if (rawText is List) {
      textValue = rawText.join('');
    }

    // Handle data field - extract text/plain if available
    Map<String, dynamic>? dataMap;
    final rawData = json['data'];
    if (rawData is Map<String, dynamic>) {
      dataMap = rawData;
      // If no text but data has text/plain, use that
      if (textValue == null && rawData['text/plain'] != null) {
        final plainText = rawData['text/plain'];
        if (plainText is String) {
          textValue = plainText;
        } else if (plainText is List) {
          textValue = plainText.join('');
        }
      }
    }

    return ExecutionOutput(
      outputType: json['output_type'] as String? ?? json['type'] as String? ?? 'stream',
      text: textValue,
      data: dataMap,
      ename: json['ename'] as String?,
      evalue: json['evalue'] as String?,
      traceback: (json['traceback'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }

  bool get isError => outputType == 'error';
  bool get isStream => outputType == 'stream';
  bool get isResult => outputType == 'execute_result';
  bool get isDisplayData => outputType == 'display_data';
}

class ExecutionResult {
  final String executionId;
  final ExecutionStatus status;
  final int? executionCount;
  final List<ExecutionOutput> outputs;
  final String? error;
  final int? durationMs;

  ExecutionResult({
    required this.executionId,
    required this.status,
    this.executionCount,
    this.outputs = const [],
    this.error,
    this.durationMs,
  });

  factory ExecutionResult.fromJson(Map<String, dynamic> json) {
    // Handle error field - can be String, Map, or null
    String? errorValue;
    final rawError = json['error'];
    if (rawError is String) {
      errorValue = rawError;
    } else if (rawError is Map) {
      // If error is a map, try to extract message or convert to string
      errorValue = rawError['message']?.toString() ?? rawError.toString();
    }

    // Handle execution_id - can be String or missing
    String executionId = '';
    if (json['execution_id'] != null) {
      executionId = json['execution_id'].toString();
    }

    return ExecutionResult(
      executionId: executionId,
      status: ExecutionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ExecutionStatus.queued,
      ),
      executionCount: json['execution_count'] as int?,
      outputs: (json['outputs'] as List<dynamic>?)
              ?.map((o) => ExecutionOutput.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
      error: errorValue,
      durationMs: json['duration_ms'] as int?,
    );
  }
}
