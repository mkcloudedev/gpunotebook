# Contributing to GPU Notebook

Thank you for your interest in contributing to GPU Notebook! This document provides guidelines and steps for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/your-username/gpu-notebook/issues)
2. If not, create a new issue with:
   - A clear, descriptive title
   - Steps to reproduce the bug
   - Expected vs actual behavior
   - Screenshots if applicable
   - Your environment details (OS, Python version, Flutter version)

### Suggesting Features

1. Check existing issues for similar suggestions
2. Create a new issue with:
   - A clear description of the feature
   - Use cases and benefits
   - Possible implementation approach

### Pull Requests

1. Fork the repository
2. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes following our coding standards
4. Write or update tests as needed
5. Commit with clear messages:
   ```bash
   git commit -m "Add: description of your changes"
   ```
6. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
7. Open a Pull Request

## Development Setup

### Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install -r requirements-dev.txt  # Development dependencies
```

### Frontend

```bash
cd book
flutter pub get
```

## Coding Standards

### Python (Backend)

- Follow PEP 8 style guide
- Use type hints
- Write docstrings for functions and classes
- Keep functions focused and small
- Use async/await for I/O operations

Example:
```python
async def get_notebook(notebook_id: str) -> Notebook:
    """
    Retrieve a notebook by its ID.

    Args:
        notebook_id: The unique identifier of the notebook

    Returns:
        The notebook object

    Raises:
        NotFoundError: If the notebook doesn't exist
    """
    notebook = await notebook_store.get(notebook_id)
    if not notebook:
        raise NotFoundError(f"Notebook {notebook_id} not found")
    return notebook
```

### Dart (Frontend)

- Follow Dart style guide
- Use meaningful variable and function names
- Keep widgets small and focused
- Separate business logic from UI
- Use const constructors when possible

Example:
```dart
class NotebookCard extends StatelessWidget {
  final Notebook notebook;
  final VoidCallback onTap;

  const NotebookCard({
    super.key,
    required this.notebook,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(notebook.name),
        onTap: onTap,
      ),
    );
  }
}
```

## Testing

### Backend Tests

```bash
cd backend
pytest
```

### Frontend Tests

```bash
cd book
flutter test
```

## Commit Message Format

Use clear, descriptive commit messages:

- `Add: new feature description`
- `Fix: bug description`
- `Update: what was updated`
- `Remove: what was removed`
- `Refactor: what was refactored`
- `Docs: documentation changes`

## Project Structure

When adding new features:

- **Backend API endpoints**: `backend/api/`
- **Backend services**: `backend/services/`
- **Backend models**: `backend/models/`
- **Frontend screens**: `book/lib/screens/`
- **Frontend widgets**: `book/lib/widgets/`
- **Frontend services**: `book/lib/services/`
- **Frontend models**: `book/lib/models/`

## Questions?

Feel free to open an issue for any questions about contributing.

Thank you for contributing!
