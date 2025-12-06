import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../models/notebook.dart';
import '../../models/cell.dart';
import '../../models/kernel.dart';
import '../../services/notebook_service.dart';
import '../../services/kernel_service.dart';

class NotebooksContent extends StatefulWidget {
  final void Function(String) onOpenNotebook;

  const NotebooksContent({super.key, required this.onOpenNotebook});

  @override
  State<NotebooksContent> createState() => NotebooksContentState();
}

class NotebooksContentState extends State<NotebooksContent> {
  List<Notebook> _notebooks = [];
  List<Kernel> _kernels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        notebookService.list(),
        kernelService.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _notebooks = results[0] as List<Notebook>;
        _kernels = results[1] as List<Kernel>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void createNewNotebook() {
    _createNotebookQuick();
  }

  Future<void> _createNotebookQuick() async {
    // Generate a generic name with timestamp
    final now = DateTime.now();
    final name = 'Notebook ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    final notebook = await notebookService.create(name);
    if (!mounted) return;
    if (notebook != null) {
      widget.onOpenNotebook(notebook.id);
    }
  }

  void importNotebook() {
    _importNotebookFile();
  }

  int get _activeKernelCount => _kernels.where((k) => k.status == KernelStatus.idle || k.status == KernelStatus.busy).length;

  void _showCreateDialog() {
    final nameController = TextEditingController(text: 'Untitled Notebook');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('New Notebook', style: TextStyle(color: AppColors.foreground)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: TextStyle(color: AppColors.foreground),
              decoration: InputDecoration(
                labelText: 'Notebook name',
                labelStyle: TextStyle(color: AppColors.mutedForeground),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primary)),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  Navigator.pop(context);
                  _createNotebook(value);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context);
                _createNotebook(nameController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createNotebook(String name) async {
    final notebook = await notebookService.create(name);
    if (!mounted) return;
    if (notebook != null) {
      widget.onOpenNotebook(notebook.id);
    }
    _loadData();
  }

  void _importNotebookFile() {
    final input = html.FileUploadInputElement()..accept = '.ipynb';
    input.click();

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) return;

      final file = files.first;
      final reader = html.FileReader();
      reader.readAsText(file);

      await reader.onLoadEnd.first;
      final content = reader.result as String;

      try {
        final json = jsonDecode(content) as Map<String, dynamic>;
        final name = file.name.replaceAll('.ipynb', '');

        // Create notebook and import cells
        final notebook = await notebookService.create(name);
        if (notebook != null) {
          // TODO: Import cells from ipynb format
          widget.onOpenNotebook(notebook.id);
        }
        _loadData();
      } catch (e) {
        // Invalid notebook file
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid notebook file'), backgroundColor: AppColors.destructive),
          );
        }
      }
    });
  }

  void _showTemplateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Create from Template', style: TextStyle(color: AppColors.foreground)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TemplateOption(
                icon: LucideIcons.brain,
                color: const Color(0xFF8B5CF6),
                title: 'Machine Learning',
                description: 'PyTorch, model training, evaluation',
                onTap: () {
                  Navigator.pop(context);
                  _createFromTemplate('ML Notebook', _mlTemplate);
                },
              ),
              const SizedBox(height: 8),
              _TemplateOption(
                icon: LucideIcons.barChart3,
                color: const Color(0xFF3B82F6),
                title: 'Data Analysis',
                description: 'Pandas, NumPy, visualization',
                onTap: () {
                  Navigator.pop(context);
                  _createFromTemplate('Data Analysis', _dataAnalysisTemplate);
                },
              ),
              const SizedBox(height: 8),
              _TemplateOption(
                icon: LucideIcons.image,
                color: const Color(0xFF10B981),
                title: 'Computer Vision',
                description: 'Image processing, OpenCV, PIL',
                onTap: () {
                  Navigator.pop(context);
                  _createFromTemplate('Computer Vision', _cvTemplate);
                },
              ),
              const SizedBox(height: 8),
              _TemplateOption(
                icon: LucideIcons.fileText,
                color: const Color(0xFFF59E0B),
                title: 'Blank Notebook',
                description: 'Start from scratch',
                onTap: () {
                  Navigator.pop(context);
                  _createNotebook('Untitled Notebook');
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFromTemplate(String name, List<String> cells) async {
    final notebook = await notebookService.create(name);
    if (!mounted) return;
    if (notebook != null) {
      // Add template cells
      for (final code in cells) {
        await notebookService.addCell(notebook.id, CellType.code, code);
        if (!mounted) return;
      }
      widget.onOpenNotebook(notebook.id);
    }
    _loadData();
  }

  // ===== MACHINE LEARNING TEMPLATE =====
  static const List<String> _mlTemplate = [
    // Cell 1: Environment Setup
    '''# Machine Learning with PyTorch
# ================================

import torch
import torch.nn as nn
import torch.optim as optim
import torch.nn.functional as F
from torch.utils.data import DataLoader, TensorDataset, random_split
import numpy as np
import matplotlib.pyplot as plt
from tqdm import tqdm

# Check GPU availability
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"PyTorch version: {torch.__version__}")
print(f"Device: {device}")
if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print(f"Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")''',

    // Cell 2: Create Sample Dataset
    '''# Create Sample Dataset
# =====================

# Generate synthetic classification data
np.random.seed(42)
n_samples = 1000
n_features = 20
n_classes = 3

X = np.random.randn(n_samples, n_features).astype(np.float32)
y = np.random.randint(0, n_classes, n_samples)

# Convert to PyTorch tensors
X_tensor = torch.from_numpy(X)
y_tensor = torch.from_numpy(y).long()

# Create dataset and split
dataset = TensorDataset(X_tensor, y_tensor)
train_size = int(0.8 * len(dataset))
val_size = len(dataset) - train_size
train_dataset, val_dataset = random_split(dataset, [train_size, val_size])

# Create data loaders
batch_size = 32
train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
val_loader = DataLoader(val_dataset, batch_size=batch_size)

print(f"Training samples: {len(train_dataset)}")
print(f"Validation samples: {len(val_dataset)}")
print(f"Features: {n_features}, Classes: {n_classes}")''',

    // Cell 3: Define Model
    '''# Define Neural Network Model
# ===========================

class NeuralNetwork(nn.Module):
    def __init__(self, input_size, hidden_sizes, num_classes, dropout=0.3):
        super().__init__()

        layers = []
        prev_size = input_size

        for hidden_size in hidden_sizes:
            layers.extend([
                nn.Linear(prev_size, hidden_size),
                nn.BatchNorm1d(hidden_size),
                nn.ReLU(),
                nn.Dropout(dropout)
            ])
            prev_size = hidden_size

        layers.append(nn.Linear(prev_size, num_classes))
        self.network = nn.Sequential(*layers)

    def forward(self, x):
        return self.network(x)

# Initialize model
model = NeuralNetwork(
    input_size=n_features,
    hidden_sizes=[128, 64, 32],
    num_classes=n_classes,
    dropout=0.3
).to(device)

# Count parameters
total_params = sum(p.numel() for p in model.parameters())
trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
print(f"Total parameters: {total_params:,}")
print(f"Trainable parameters: {trainable_params:,}")
print(model)''',

    // Cell 4: Training Function
    '''# Training and Evaluation Functions
# ==================================

def train_epoch(model, loader, optimizer, criterion, device):
    model.train()
    total_loss = 0
    correct = 0
    total = 0

    for X_batch, y_batch in loader:
        X_batch, y_batch = X_batch.to(device), y_batch.to(device)

        optimizer.zero_grad()
        outputs = model(X_batch)
        loss = criterion(outputs, y_batch)
        loss.backward()
        optimizer.step()

        total_loss += loss.item()
        _, predicted = outputs.max(1)
        total += y_batch.size(0)
        correct += predicted.eq(y_batch).sum().item()

    return total_loss / len(loader), 100. * correct / total

def evaluate(model, loader, criterion, device):
    model.eval()
    total_loss = 0
    correct = 0
    total = 0

    with torch.no_grad():
        for X_batch, y_batch in loader:
            X_batch, y_batch = X_batch.to(device), y_batch.to(device)
            outputs = model(X_batch)
            loss = criterion(outputs, y_batch)

            total_loss += loss.item()
            _, predicted = outputs.max(1)
            total += y_batch.size(0)
            correct += predicted.eq(y_batch).sum().item()

    return total_loss / len(loader), 100. * correct / total

print("Training functions defined!")''',

    // Cell 5: Train Model
    '''# Train the Model
# ===============

# Hyperparameters
learning_rate = 0.001
num_epochs = 50
weight_decay = 1e-4

# Loss and optimizer
criterion = nn.CrossEntropyLoss()
optimizer = optim.AdamW(model.parameters(), lr=learning_rate, weight_decay=weight_decay)
scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', patience=5, factor=0.5)

# Training history
history = {"train_loss": [], "train_acc": [], "val_loss": [], "val_acc": []}

# Training loop
best_val_acc = 0
for epoch in tqdm(range(num_epochs), desc="Training"):
    train_loss, train_acc = train_epoch(model, train_loader, optimizer, criterion, device)
    val_loss, val_acc = evaluate(model, val_loader, criterion, device)

    scheduler.step(val_loss)

    history["train_loss"].append(train_loss)
    history["train_acc"].append(train_acc)
    history["val_loss"].append(val_loss)
    history["val_acc"].append(val_acc)

    if val_acc > best_val_acc:
        best_val_acc = val_acc
        torch.save(model.state_dict(), "best_model.pt")

    if (epoch + 1) % 10 == 0:
        print(f"Epoch {epoch+1}: Train Loss={train_loss:.4f}, Train Acc={train_acc:.1f}%, Val Acc={val_acc:.1f}%")

print(f"\\nBest Validation Accuracy: {best_val_acc:.1f}%")''',

    // Cell 6: Visualize Results
    '''# Visualize Training Results
# ==========================

fig, axes = plt.subplots(1, 2, figsize=(14, 5))

# Loss plot
axes[0].plot(history["train_loss"], label="Train Loss", linewidth=2)
axes[0].plot(history["val_loss"], label="Val Loss", linewidth=2)
axes[0].set_xlabel("Epoch")
axes[0].set_ylabel("Loss")
axes[0].set_title("Training & Validation Loss")
axes[0].legend()
axes[0].grid(True, alpha=0.3)

# Accuracy plot
axes[1].plot(history["train_acc"], label="Train Acc", linewidth=2)
axes[1].plot(history["val_acc"], label="Val Acc", linewidth=2)
axes[1].set_xlabel("Epoch")
axes[1].set_ylabel("Accuracy (%)")
axes[1].set_title("Training & Validation Accuracy")
axes[1].legend()
axes[1].grid(True, alpha=0.3)

plt.tight_layout()
plt.show()''',

    // Cell 7: Model Inference
    '''# Model Inference
# ===============

# Load best model
model.load_state_dict(torch.load("best_model.pt"))
model.eval()

# Make predictions on validation set
all_preds = []
all_labels = []

with torch.no_grad():
    for X_batch, y_batch in val_loader:
        X_batch = X_batch.to(device)
        outputs = model(X_batch)
        _, preds = outputs.max(1)
        all_preds.extend(preds.cpu().numpy())
        all_labels.extend(y_batch.numpy())

# Classification report
from sklearn.metrics import classification_report, confusion_matrix
import seaborn as sns

print("Classification Report:")
print(classification_report(all_labels, all_preds))

# Confusion matrix
cm = confusion_matrix(all_labels, all_preds)
plt.figure(figsize=(8, 6))
sns.heatmap(cm, annot=True, fmt="d", cmap="Blues")
plt.xlabel("Predicted")
plt.ylabel("Actual")
plt.title("Confusion Matrix")
plt.show()''',
  ];

  // ===== DATA ANALYSIS TEMPLATE =====
  static const List<String> _dataAnalysisTemplate = [
    // Cell 1: Setup
    '''# Data Analysis with Python
# =========================

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats

# Display settings
pd.set_option("display.max_columns", None)
pd.set_option("display.max_rows", 100)
pd.set_option("display.float_format", "{:.2f}".format)
plt.style.use("seaborn-v0_8-darkgrid")
sns.set_palette("husl")

print("Libraries loaded successfully!")
print(f"Pandas: {pd.__version__}")
print(f"NumPy: {np.__version__}")''',

    // Cell 2: Load/Create Data
    '''# Load or Create Dataset
# ======================

# Option 1: Load from CSV
# df = pd.read_csv("your_data.csv")

# Option 2: Create sample dataset
np.random.seed(42)
n_samples = 500

df = pd.DataFrame({
    "date": pd.date_range("2023-01-01", periods=n_samples, freq="D"),
    "category": np.random.choice(["A", "B", "C", "D"], n_samples),
    "region": np.random.choice(["North", "South", "East", "West"], n_samples),
    "sales": np.random.exponential(1000, n_samples),
    "quantity": np.random.poisson(50, n_samples),
    "price": np.random.uniform(10, 100, n_samples),
    "rating": np.random.uniform(1, 5, n_samples),
    "returns": np.random.binomial(1, 0.1, n_samples),
})

# Add derived columns
df["revenue"] = df["sales"] * df["quantity"]
df["month"] = df["date"].dt.month
df["day_of_week"] = df["date"].dt.day_name()

print(f"Dataset shape: {df.shape}")
df.head(10)''',

    // Cell 3: Data Overview
    '''# Data Overview & Quality Check
# =============================

print("=" * 50)
print("DATA TYPES")
print("=" * 50)
print(df.dtypes)

print("\\n" + "=" * 50)
print("MISSING VALUES")
print("=" * 50)
print(df.isnull().sum())

print("\\n" + "=" * 50)
print("STATISTICAL SUMMARY")
print("=" * 50)
df.describe()''',

    // Cell 4: Exploratory Analysis
    '''# Exploratory Data Analysis
# =========================

fig, axes = plt.subplots(2, 3, figsize=(16, 10))

# 1. Distribution of Sales
axes[0, 0].hist(df["sales"], bins=30, edgecolor="white", alpha=0.7)
axes[0, 0].set_title("Sales Distribution")
axes[0, 0].set_xlabel("Sales")

# 2. Category breakdown
category_counts = df["category"].value_counts()
axes[0, 1].pie(category_counts, labels=category_counts.index, autopct="%1.1f%%")
axes[0, 1].set_title("Sales by Category")

# 3. Region comparison
df.groupby("region")["revenue"].mean().plot(kind="bar", ax=axes[0, 2], color="steelblue")
axes[0, 2].set_title("Average Revenue by Region")
axes[0, 2].set_ylabel("Revenue")

# 4. Sales vs Quantity
axes[1, 0].scatter(df["quantity"], df["sales"], alpha=0.5, c=df["rating"], cmap="viridis")
axes[1, 0].set_xlabel("Quantity")
axes[1, 0].set_ylabel("Sales")
axes[1, 0].set_title("Sales vs Quantity (colored by Rating)")

# 5. Time series
daily_sales = df.groupby("date")["sales"].sum()
axes[1, 1].plot(daily_sales.index, daily_sales.values, linewidth=0.8)
axes[1, 1].set_title("Daily Sales Trend")
axes[1, 1].tick_params(axis="x", rotation=45)

# 6. Correlation heatmap
numeric_cols = df.select_dtypes(include=[np.number]).columns
corr = df[numeric_cols].corr()
sns.heatmap(corr, annot=True, cmap="coolwarm", center=0, ax=axes[1, 2], fmt=".2f")
axes[1, 2].set_title("Correlation Matrix")

plt.tight_layout()
plt.show()''',

    // Cell 5: Group Analysis
    '''# Group Analysis & Aggregations
# =============================

# Sales by category and region
pivot_table = pd.pivot_table(
    df,
    values=["sales", "revenue", "quantity"],
    index="category",
    columns="region",
    aggfunc="mean"
)
print("Pivot Table - Average Metrics by Category & Region:")
display(pivot_table.round(2))

# Top performing combinations
print("\\n" + "=" * 50)
print("TOP 10 Category-Region Combinations by Revenue")
print("=" * 50)
top_combos = df.groupby(["category", "region"]).agg({
    "revenue": "sum",
    "sales": "mean",
    "quantity": "sum"
}).sort_values("revenue", ascending=False).head(10)
display(top_combos.round(2))''',

    // Cell 6: Statistical Tests
    '''# Statistical Analysis
# ====================

# 1. Test if sales differ by category (ANOVA)
categories = [df[df["category"] == cat]["sales"] for cat in df["category"].unique()]
f_stat, p_value = stats.f_oneway(*categories)
print(f"ANOVA Test - Sales by Category:")
print(f"F-statistic: {f_stat:.4f}, p-value: {p_value:.4f}")
print(f"Significant difference: {'Yes' if p_value < 0.05 else 'No'}\\n")

# 2. Correlation test
corr, p_val = stats.pearsonr(df["price"], df["rating"])
print(f"Correlation: Price vs Rating")
print(f"Pearson r: {corr:.4f}, p-value: {p_val:.4f}\\n")

# 3. T-test: Compare two regions
north_sales = df[df["region"] == "North"]["sales"]
south_sales = df[df["region"] == "South"]["sales"]
t_stat, p_value = stats.ttest_ind(north_sales, south_sales)
print(f"T-Test: North vs South Sales")
print(f"t-statistic: {t_stat:.4f}, p-value: {p_value:.4f}")''',

    // Cell 7: Export Results
    '''# Export Analysis Results
# ======================

# Summary statistics by category
summary = df.groupby("category").agg({
    "sales": ["mean", "std", "min", "max"],
    "revenue": ["sum", "mean"],
    "quantity": "sum",
    "rating": "mean"
}).round(2)

# Flatten column names
summary.columns = ["_".join(col).strip() for col in summary.columns]
summary = summary.reset_index()

print("Summary by Category:")
display(summary)

# Save to CSV
# summary.to_csv("analysis_summary.csv", index=False)
# print("\\nResults saved to analysis_summary.csv")''',
  ];

  // ===== COMPUTER VISION TEMPLATE =====
  static const List<String> _cvTemplate = [
    // Cell 1: Setup
    '''# Computer Vision with Python
# ===========================

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import matplotlib.pyplot as plt
from pathlib import Path

# For deep learning (optional)
try:
    import torch
    import torchvision.transforms as transforms
    from torchvision import models
    TORCH_AVAILABLE = True
    print(f"PyTorch: {torch.__version__}")
except ImportError:
    TORCH_AVAILABLE = False
    print("PyTorch not available - deep learning features disabled")

print(f"OpenCV: {cv2.__version__}")
print(f"NumPy: {np.__version__}")
plt.style.use("dark_background")''',

    // Cell 2: Load/Create Image
    '''# Load or Create Test Image
# =========================

# Option 1: Load from file
# img = cv2.imread("your_image.jpg")
# img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

# Option 2: Create synthetic test image
def create_test_image(size=512):
    img = np.zeros((size, size, 3), dtype=np.uint8)

    # Background gradient
    for i in range(size):
        img[:, i] = [int(50 + i * 0.2), int(30 + i * 0.1), int(80 + i * 0.15)]

    # Shapes
    cv2.rectangle(img, (50, 50), (200, 200), (0, 255, 0), 3)
    cv2.circle(img, (350, 150), 80, (255, 0, 0), -1)
    cv2.ellipse(img, (150, 380), (100, 50), 45, 0, 360, (0, 255, 255), -1)
    cv2.line(img, (300, 300), (480, 480), (255, 255, 0), 4)

    # Add text
    cv2.putText(img, "OpenCV Test", (150, 480), cv2.FONT_HERSHEY_SIMPLEX, 1.5, (255, 255, 255), 3)

    return img

img = create_test_image(512)
img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

plt.figure(figsize=(8, 8))
plt.imshow(img_rgb)
plt.title("Test Image")
plt.axis("off")
plt.show()

print(f"Image shape: {img.shape}")
print(f"Data type: {img.dtype}")''',

    // Cell 3: Basic Transformations
    '''# Basic Image Transformations
# ===========================

fig, axes = plt.subplots(2, 3, figsize=(15, 10))

# 1. Grayscale
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
axes[0, 0].imshow(gray, cmap="gray")
axes[0, 0].set_title("Grayscale")

# 2. Blur
blurred = cv2.GaussianBlur(img_rgb, (15, 15), 0)
axes[0, 1].imshow(blurred)
axes[0, 1].set_title("Gaussian Blur")

# 3. Sharpen
kernel = np.array([[-1, -1, -1], [-1, 9, -1], [-1, -1, -1]])
sharpened = cv2.filter2D(img_rgb, -1, kernel)
axes[0, 2].imshow(sharpened)
axes[0, 2].set_title("Sharpened")

# 4. Edge detection
edges = cv2.Canny(gray, 50, 150)
axes[1, 0].imshow(edges, cmap="gray")
axes[1, 0].set_title("Canny Edges")

# 5. Threshold
_, thresh = cv2.threshold(gray, 127, 255, cv2.THRESH_BINARY)
axes[1, 1].imshow(thresh, cmap="gray")
axes[1, 1].set_title("Binary Threshold")

# 6. Morphology
kernel = np.ones((5, 5), np.uint8)
dilated = cv2.dilate(edges, kernel, iterations=1)
axes[1, 2].imshow(dilated, cmap="gray")
axes[1, 2].set_title("Dilated Edges")

for ax in axes.flat:
    ax.axis("off")
plt.tight_layout()
plt.show()''',

    // Cell 4: Color Space Analysis
    '''# Color Space Analysis
# ====================

fig, axes = plt.subplots(2, 4, figsize=(16, 8))

# RGB Channels
axes[0, 0].imshow(img_rgb)
axes[0, 0].set_title("Original RGB")

for i, (color, name) in enumerate(zip(["Reds", "Greens", "Blues"], ["Red", "Green", "Blue"])):
    channel = img_rgb[:, :, i]
    axes[0, i + 1].imshow(channel, cmap=color)
    axes[0, i + 1].set_title(f"{name} Channel")

# HSV Space
hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
axes[1, 0].imshow(cv2.cvtColor(hsv, cv2.COLOR_HSV2RGB))
axes[1, 0].set_title("HSV")

axes[1, 1].imshow(hsv[:, :, 0], cmap="hsv")
axes[1, 1].set_title("Hue")

axes[1, 2].imshow(hsv[:, :, 1], cmap="gray")
axes[1, 2].set_title("Saturation")

axes[1, 3].imshow(hsv[:, :, 2], cmap="gray")
axes[1, 3].set_title("Value")

for ax in axes.flat:
    ax.axis("off")
plt.tight_layout()
plt.show()''',

    // Cell 5: Contour Detection
    '''# Contour Detection & Analysis
# ============================

# Find contours
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
blurred = cv2.GaussianBlur(gray, (5, 5), 0)
edges = cv2.Canny(blurred, 50, 150)
contours, hierarchy = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

# Draw contours
contour_img = img_rgb.copy()
cv2.drawContours(contour_img, contours, -1, (0, 255, 0), 2)

# Analyze contours
fig, axes = plt.subplots(1, 2, figsize=(14, 6))

axes[0].imshow(contour_img)
axes[0].set_title(f"Detected Contours: {len(contours)}")
axes[0].axis("off")

# Draw bounding boxes
bbox_img = img_rgb.copy()
for i, contour in enumerate(contours):
    area = cv2.contourArea(contour)
    if area > 100:  # Filter small contours
        x, y, w, h = cv2.boundingRect(contour)
        cv2.rectangle(bbox_img, (x, y), (x + w, y + h), (255, 0, 0), 2)
        cv2.putText(bbox_img, f"{i}", (x, y - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 0), 2)

axes[1].imshow(bbox_img)
axes[1].set_title("Bounding Boxes")
axes[1].axis("off")

plt.tight_layout()
plt.show()

# Contour statistics
print("Contour Analysis:")
for i, contour in enumerate(contours[:5]):
    area = cv2.contourArea(contour)
    perimeter = cv2.arcLength(contour, True)
    print(f"  Contour {i}: Area={area:.0f}, Perimeter={perimeter:.1f}")''',

    // Cell 6: Image Filters & Effects
    '''# Advanced Filters & Effects
# ==========================

fig, axes = plt.subplots(2, 3, figsize=(15, 10))

# 1. Bilateral filter (edge-preserving smoothing)
bilateral = cv2.bilateralFilter(img_rgb, 9, 75, 75)
axes[0, 0].imshow(bilateral)
axes[0, 0].set_title("Bilateral Filter")

# 2. Histogram equalization
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
equalized = cv2.equalizeHist(gray)
axes[0, 1].imshow(equalized, cmap="gray")
axes[0, 1].set_title("Histogram Equalization")

# 3. Adaptive threshold
adaptive = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2)
axes[0, 2].imshow(adaptive, cmap="gray")
axes[0, 2].set_title("Adaptive Threshold")

# 4. Sobel gradient
sobelx = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
sobely = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
sobel = np.sqrt(sobelx**2 + sobely**2)
axes[1, 0].imshow(sobel, cmap="hot")
axes[1, 0].set_title("Sobel Gradient")

# 5. Laplacian
laplacian = cv2.Laplacian(gray, cv2.CV_64F)
axes[1, 1].imshow(np.abs(laplacian), cmap="hot")
axes[1, 1].set_title("Laplacian")

# 6. Emboss effect
kernel_emboss = np.array([[-2, -1, 0], [-1, 1, 1], [0, 1, 2]])
emboss = cv2.filter2D(gray, -1, kernel_emboss)
axes[1, 2].imshow(emboss, cmap="gray")
axes[1, 2].set_title("Emboss Effect")

for ax in axes.flat:
    ax.axis("off")
plt.tight_layout()
plt.show()''',

    // Cell 7: Deep Learning (Optional)
    '''# Deep Learning Image Classification (if PyTorch available)
# ========================================================

if TORCH_AVAILABLE:
    # Load pretrained model
    model = models.resnet18(pretrained=True)
    model.eval()

    # Image preprocessing
    preprocess = transforms.Compose([
        transforms.ToPILImage(),
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])

    # Prepare image
    input_tensor = preprocess(img_rgb).unsqueeze(0)

    # Inference
    with torch.no_grad():
        output = model(input_tensor)
        probabilities = torch.nn.functional.softmax(output[0], dim=0)

    # Get top 5 predictions
    top5_prob, top5_catid = torch.topk(probabilities, 5)

    # ImageNet class labels (simplified)
    print("Top 5 Predictions (ImageNet):")
    for i in range(5):
        print(f"  Class {top5_catid[i].item()}: {top5_prob[i].item()*100:.1f}%")
else:
    print("PyTorch not available. Install with: pip install torch torchvision")
    print("This cell demonstrates deep learning image classification.")''',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Main content
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [_buildNotebooksList()],
                    ),
                  ),
          ),
        ),
        // Side Panel
        _buildSidePanel(),
      ],
    );
  }

  Widget _buildNotebooksList() {
    if (_notebooks.isEmpty) {
      return Container(
        padding: EdgeInsets.all(48),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Icon(LucideIcons.fileCode, size: 48, color: AppColors.mutedForeground),
            SizedBox(height: 16),
            Text('No notebooks found', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.foreground)),
            SizedBox(height: 4),
            Text('Create your first notebook to get started', style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
          ],
        ),
      );
    }

    return Column(
      children: _notebooks.map((notebook) {
        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _NotebookRow(
            notebook: notebook,
            onTap: () => widget.onOpenNotebook(notebook.id),
            onDuplicate: () => _duplicateNotebook(notebook),
            onDelete: () => _deleteNotebook(notebook),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSidePanel() {
    return Container(
      width: 288,
      decoration: BoxDecoration(color: AppColors.card, border: Border(left: BorderSide(color: AppColors.border))),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(children: [Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.foreground))]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  _QuickActionButton(icon: LucideIcons.plus, iconColor: AppColors.primary, title: 'New Notebook', description: 'Create a blank notebook', onTap: _showCreateDialog),
                  const SizedBox(height: 8),
                  _QuickActionButton(icon: LucideIcons.upload, iconColor: AppColors.success, title: 'Import .ipynb', description: 'Upload Jupyter notebook', onTap: _importNotebookFile),
                  const SizedBox(height: 8),
                  _QuickActionButton(icon: LucideIcons.fileCode, iconColor: const Color(0xFF8B5CF6), title: 'From Template', description: 'ML, Data Science, etc.', onTap: _showTemplateDialog),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kernel Status', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.foreground)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Python 3.11', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: _activeKernelCount > 0 ? AppColors.success : AppColors.mutedForeground, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(_activeKernelCount > 0 ? 'Ready' : 'No kernels', style: TextStyle(fontSize: 12, color: _activeKernelCount > 0 ? AppColors.success : AppColors.mutedForeground)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                      Text('$_activeKernelCount kernels', style: TextStyle(fontSize: 12, color: AppColors.foreground)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _duplicateNotebook(Notebook notebook) async {
    final newNotebook = await notebookService.create('${notebook.name} (Copy)');
    if (!mounted) return;
    if (newNotebook != null) {
      // Copy cells to new notebook
      final updatedNotebook = await notebookService.update(
        newNotebook.id,
        cells: notebook.cells,
      );
      if (!mounted) return;
      setState(() {
        _notebooks.insert(0, updatedNotebook ?? newNotebook);
      });
    }
  }

  Future<void> _deleteNotebook(Notebook notebook) async {
    final success = await notebookService.delete(notebook.id);
    if (!mounted) return;
    if (success) {
      setState(() => _notebooks.removeWhere((n) => n.id == notebook.id));
    }
  }
}

class _NotebookRow extends StatefulWidget {
  final Notebook notebook;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _NotebookRow({required this.notebook, required this.onTap, required this.onDuplicate, required this.onDelete});

  @override
  State<_NotebookRow> createState() => _NotebookRowState();
}

class _NotebookRowState extends State<_NotebookRow> {
  bool _isHovered = false;

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 1) return 'Just now';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Icon(LucideIcons.fileCode, size: 20, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.notebook.name, style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.foreground)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text('Python', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                        const SizedBox(width: 12),
                        Text('${widget.notebook.cells.length} cells', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                        const SizedBox(width: 12),
                        Icon(LucideIcons.clock, size: 12, color: AppColors.mutedForeground),
                        const SizedBox(width: 4),
                        Text(_formatDate(widget.notebook.updatedAt), style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(LucideIcons.moreVertical, size: 18, color: AppColors.mutedForeground),
                color: AppColors.card,
                onSelected: (value) {
                  if (value == 'duplicate') widget.onDuplicate();
                  if (value == 'delete') widget.onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'run', child: Row(children: [Icon(LucideIcons.play, size: 16), SizedBox(width: 8), Text('Run All')])),
                  PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(LucideIcons.copy, size: 16), SizedBox(width: 8), Text('Duplicate')])),
                  PopupMenuItem(value: 'delete', child: Row(children: [Icon(LucideIcons.trash2, size: 16, color: AppColors.destructive), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppColors.destructive))])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _QuickActionButton({required this.icon, required this.iconColor, required this.title, required this.description, required this.onTap});

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
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
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, size: 16, color: widget.iconColor),
                  const SizedBox(width: 8),
                  Text(widget.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                ],
              ),
              const SizedBox(height: 4),
              Text(widget.description, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateOption extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _TemplateOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  State<_TemplateOption> createState() => _TemplateOptionState();
}

class _TemplateOptionState extends State<_TemplateOption> {
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
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isHovered ? widget.color.withOpacity(0.1) : AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _isHovered ? widget.color.withOpacity(0.5) : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, size: 20, color: widget.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.foreground)),
                    const SizedBox(height: 2),
                    Text(widget.description, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: _isHovered ? widget.color : AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}
