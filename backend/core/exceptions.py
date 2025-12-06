"""
Custom exceptions for the application.
"""


class NotebookException(Exception):
    """Base exception for notebook operations."""
    pass


class KernelException(Exception):
    """Exception for kernel operations."""
    pass


class KernelNotFoundError(KernelException):
    """Kernel not found."""
    pass


class KernelBusyError(KernelException):
    """Kernel is busy executing."""
    pass


class KernelStartError(KernelException):
    """Failed to start kernel."""
    pass


class ExecutionError(Exception):
    """Exception during code execution."""
    pass


class ExecutionTimeoutError(ExecutionError):
    """Execution timed out."""
    pass


class AIProviderError(Exception):
    """Exception for AI provider operations."""
    pass


class FileOperationError(Exception):
    """Exception for file operations."""
    pass


class GPUError(Exception):
    """Exception for GPU operations."""
    pass
