import 'dart:async';
import '../models/notebook.dart';
import '../models/cell.dart';
import '../models/kernel.dart';
import '../models/execution.dart';
import 'notebook_service.dart';
import 'kernel_service.dart';
import 'api_client.dart';

/// Tools available for AI to execute
enum AIToolType {
  executeCode,
  createNotebook,
  addCellToNotebook,
  trainModel,
  listNotebooks,
}

/// Result of an AI tool execution
class AIToolResult {
  final AIToolType tool;
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;
  final String? error;
  final List<ExecutionOutput>? outputs;

  AIToolResult({
    required this.tool,
    required this.success,
    this.message,
    this.data,
    this.error,
    this.outputs,
  });

  Map<String, dynamic> toJson() => {
    'tool': tool.name,
    'success': success,
    if (message != null) 'message': message,
    if (data != null) 'data': data,
    if (error != null) 'error': error,
    if (outputs != null) 'outputs': outputs!.map((o) => {
      'type': o.outputType.toString(),
      'text': o.text,
      'data': o.data,
    }).toList(),
  };
}

/// Service for AI to execute tools/actions
class AIToolsService {
  String? _defaultKernelId;

  AIToolsService();

  /// Get or create a default kernel for AI execution
  Future<String> _getOrCreateKernel() async {
    if (_defaultKernelId != null) {
      try {
        final status = await kernelService.getStatus(_defaultKernelId!);
        if (status != KernelStatus.dead) {
          return _defaultKernelId!;
        }
      } catch (_) {}
    }

    // Create a new kernel for AI
    final kernel = await kernelService.create('python3', notebookId: 'ai_assistant');
    _defaultKernelId = kernel.id;
    return kernel.id;
  }

  /// Execute code and return the results
  Future<AIToolResult> executeCode(String code) async {
    try {
      final kernelId = await _getOrCreateKernel();

      final request = ExecutionRequest(
        kernelId: kernelId,
        code: code,
        cellId: 'ai_exec_${DateTime.now().millisecondsSinceEpoch}',
      );

      final result = await apiClient.post('/api/execute', request.toJson());
      final execResult = ExecutionResult.fromJson(result);

      return AIToolResult(
        tool: AIToolType.executeCode,
        success: execResult.status == 'success',
        message: execResult.status == 'success'
            ? 'Code executed successfully'
            : 'Execution failed',
        outputs: execResult.outputs,
        error: execResult.error,
        data: {
          'execution_count': execResult.executionCount,
          'status': execResult.status,
        },
      );
    } catch (e) {
      return AIToolResult(
        tool: AIToolType.executeCode,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Create a new notebook
  Future<AIToolResult> createNotebook(String name, {List<String>? initialCells}) async {
    try {
      final notebook = await notebookService.create(name);
      if (notebook == null) {
        return AIToolResult(
          tool: AIToolType.createNotebook,
          success: false,
          error: 'Failed to create notebook',
        );
      }

      // Add initial cells if provided
      if (initialCells != null && initialCells.isNotEmpty) {
        for (final code in initialCells) {
          await notebookService.addCell(notebook.id, CellType.code, code);
        }
      }

      return AIToolResult(
        tool: AIToolType.createNotebook,
        success: true,
        message: 'Created notebook "$name"',
        data: {
          'notebook_id': notebook.id,
          'name': notebook.name,
        },
      );
    } catch (e) {
      return AIToolResult(
        tool: AIToolType.createNotebook,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Add a cell to an existing notebook
  Future<AIToolResult> addCellToNotebook(String notebookId, String code, {CellType type = CellType.code}) async {
    try {
      final cell = await notebookService.addCell(notebookId, type, code);
      if (cell == null) {
        return AIToolResult(
          tool: AIToolType.addCellToNotebook,
          success: false,
          error: 'Failed to add cell to notebook',
        );
      }

      return AIToolResult(
        tool: AIToolType.addCellToNotebook,
        success: true,
        message: 'Added cell to notebook',
        data: {
          'cell_id': cell.id,
          'notebook_id': notebookId,
        },
      );
    } catch (e) {
      return AIToolResult(
        tool: AIToolType.addCellToNotebook,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// List available notebooks
  Future<AIToolResult> listNotebooks() async {
    try {
      final notebooks = await notebookService.list();
      return AIToolResult(
        tool: AIToolType.listNotebooks,
        success: true,
        message: 'Found ${notebooks.length} notebooks',
        data: {
          'notebooks': notebooks.map((n) => {
            'id': n.id,
            'name': n.name,
            'cells_count': n.cells.length,
          }).toList(),
        },
      );
    } catch (e) {
      return AIToolResult(
        tool: AIToolType.listNotebooks,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Train a model (creates notebook with training code and executes it)
  Future<AIToolResult> trainModel({
    required String modelType,
    required String datasetPath,
    required String targetColumn,
    Map<String, dynamic>? hyperparameters,
  }) async {
    try {
      // Generate training code based on model type
      final trainingCode = _generateTrainingCode(
        modelType: modelType,
        datasetPath: datasetPath,
        targetColumn: targetColumn,
        hyperparameters: hyperparameters,
      );

      // Execute the training code
      final result = await executeCode(trainingCode);

      return AIToolResult(
        tool: AIToolType.trainModel,
        success: result.success,
        message: result.success
            ? 'Model training completed'
            : 'Model training failed',
        outputs: result.outputs,
        error: result.error,
        data: {
          'model_type': modelType,
          'dataset': datasetPath,
          'target': targetColumn,
        },
      );
    } catch (e) {
      return AIToolResult(
        tool: AIToolType.trainModel,
        success: false,
        error: e.toString(),
      );
    }
  }

  String _generateTrainingCode({
    required String modelType,
    required String datasetPath,
    required String targetColumn,
    Map<String, dynamic>? hyperparameters,
  }) {
    final hp = hyperparameters ?? {};

    switch (modelType.toLowerCase()) {
      case 'random_forest':
      case 'randomforest':
        return '''
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report

# Load data
df = pd.read_csv("$datasetPath")
X = df.drop("$targetColumn", axis=1)
y = df["$targetColumn"]

# Split data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=${hp['test_size'] ?? 0.2}, random_state=42)

# Train model
model = RandomForestClassifier(
    n_estimators=${hp['n_estimators'] ?? 100},
    max_depth=${hp['max_depth'] ?? 'None'},
    random_state=42
)
model.fit(X_train, y_train)

# Evaluate
y_pred = model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)
print(f"Accuracy: {accuracy:.4f}")
print("\\nClassification Report:")
print(classification_report(y_test, y_pred))
''';

      case 'xgboost':
        return '''
import pandas as pd
from sklearn.model_selection import train_test_split
from xgboost import XGBClassifier
from sklearn.metrics import accuracy_score, classification_report

# Load data
df = pd.read_csv("$datasetPath")
X = df.drop("$targetColumn", axis=1)
y = df["$targetColumn"]

# Split data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=${hp['test_size'] ?? 0.2}, random_state=42)

# Train model
model = XGBClassifier(
    n_estimators=${hp['n_estimators'] ?? 100},
    max_depth=${hp['max_depth'] ?? 6},
    learning_rate=${hp['learning_rate'] ?? 0.1},
    random_state=42
)
model.fit(X_train, y_train)

# Evaluate
y_pred = model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)
print(f"Accuracy: {accuracy:.4f}")
print("\\nClassification Report:")
print(classification_report(y_test, y_pred))
''';

      case 'neural_network':
      case 'pytorch':
        return '''
import pandas as pd
import torch
import torch.nn as nn
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

# Load data
df = pd.read_csv("$datasetPath")
X = df.drop("$targetColumn", axis=1).values
y = df["$targetColumn"].values

# Split and scale
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=${hp['test_size'] ?? 0.2}, random_state=42)
scaler = StandardScaler()
X_train = scaler.fit_transform(X_train)
X_test = scaler.transform(X_test)

# Convert to tensors
X_train = torch.FloatTensor(X_train).cuda()
X_test = torch.FloatTensor(X_test).cuda()
y_train = torch.LongTensor(y_train).cuda()
y_test = torch.LongTensor(y_test).cuda()

# Define model
class Net(nn.Module):
    def __init__(self, input_size, num_classes):
        super().__init__()
        self.fc1 = nn.Linear(input_size, 128)
        self.fc2 = nn.Linear(128, 64)
        self.fc3 = nn.Linear(64, num_classes)
        self.relu = nn.ReLU()
        self.dropout = nn.Dropout(0.2)

    def forward(self, x):
        x = self.relu(self.fc1(x))
        x = self.dropout(x)
        x = self.relu(self.fc2(x))
        x = self.fc3(x)
        return x

model = Net(X_train.shape[1], len(torch.unique(y_train))).cuda()
criterion = nn.CrossEntropyLoss()
optimizer = torch.optim.Adam(model.parameters(), lr=${hp['learning_rate'] ?? 0.001})

# Train
epochs = ${hp['epochs'] ?? 100}
for epoch in range(epochs):
    optimizer.zero_grad()
    outputs = model(X_train)
    loss = criterion(outputs, y_train)
    loss.backward()
    optimizer.step()
    if (epoch + 1) % 20 == 0:
        print(f"Epoch {epoch+1}/{epochs}, Loss: {loss.item():.4f}")

# Evaluate
model.eval()
with torch.no_grad():
    outputs = model(X_test)
    _, predicted = torch.max(outputs, 1)
    accuracy = (predicted == y_test).sum().item() / len(y_test)
    print(f"\\nTest Accuracy: {accuracy:.4f}")
''';

      default:
        return '''
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score

# Load data
df = pd.read_csv("$datasetPath")
X = df.drop("$targetColumn", axis=1)
y = df["$targetColumn"]

# Split data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Train model
model = LogisticRegression(max_iter=1000)
model.fit(X_train, y_train)

# Evaluate
accuracy = model.score(X_test, y_test)
print(f"Accuracy: {accuracy:.4f}")
''';
    }
  }

  void dispose() {
    // Cleanup kernel if needed
    if (_defaultKernelId != null) {
      kernelService.shutdown(_defaultKernelId!).catchError((_) {});
    }
  }
}

final aiToolsService = AIToolsService();
