"""
SQLAlchemy database models.
"""
from sqlalchemy import Column, String, Text, Integer, DateTime, ForeignKey, JSON, Enum as SQLEnum
from sqlalchemy.orm import relationship
from datetime import datetime
import enum

from core.database import Base


class CellTypeEnum(str, enum.Enum):
    code = "code"
    markdown = "markdown"


class CellStatusEnum(str, enum.Enum):
    idle = "idle"
    queued = "queued"
    running = "running"
    success = "success"
    error = "error"


class NotebookDB(Base):
    """Notebook table."""
    __tablename__ = "notebooks"

    id = Column(String(36), primary_key=True)
    name = Column(String(255), nullable=False, default="Untitled")
    kernel_id = Column(String(36), nullable=True)
    kernel_name = Column(String(50), default="python3")
    language = Column(String(50), default="python")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    cells = relationship("CellDB", back_populates="notebook", cascade="all, delete-orphan", order_by="CellDB.position")
    chat_messages = relationship("ChatMessageDB", back_populates="notebook", cascade="all, delete-orphan", order_by="ChatMessageDB.created_at")


class CellDB(Base):
    """Cell table."""
    __tablename__ = "cells"

    id = Column(String(36), primary_key=True)
    notebook_id = Column(String(36), ForeignKey("notebooks.id", ondelete="CASCADE"), nullable=False)
    cell_type = Column(String(20), default="code")
    source = Column(Text, default="")
    position = Column(Integer, nullable=False, default=0)
    execution_count = Column(Integer, nullable=True)
    status = Column(String(20), default="idle")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    notebook = relationship("NotebookDB", back_populates="cells")
    outputs = relationship("CellOutputDB", back_populates="cell", cascade="all, delete-orphan", order_by="CellOutputDB.position")


class CellOutputDB(Base):
    """Cell output table."""
    __tablename__ = "cell_outputs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    cell_id = Column(String(36), ForeignKey("cells.id", ondelete="CASCADE"), nullable=False)
    output_type = Column(String(50), default="stream")
    text = Column(Text, nullable=True)
    data = Column(JSON, nullable=True)  # For rich outputs (images, html, etc.)
    ename = Column(String(255), nullable=True)  # Error name
    evalue = Column(Text, nullable=True)  # Error value
    traceback = Column(JSON, nullable=True)  # Error traceback as list
    position = Column(Integer, default=0)

    # Relationships
    cell = relationship("CellDB", back_populates="outputs")


class ChatMessageDB(Base):
    """Chat message table for notebook AI chat."""
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, autoincrement=True)
    notebook_id = Column(String(36), ForeignKey("notebooks.id", ondelete="CASCADE"), nullable=False)
    role = Column(String(20), nullable=False)  # 'user', 'assistant', 'system'
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    notebook = relationship("NotebookDB", back_populates="chat_messages")


class SettingsDB(Base):
    """Application settings table."""
    __tablename__ = "settings"

    key = Column(String(100), primary_key=True)
    value = Column(Text, nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class AutoMLExperimentDB(Base):
    """AutoML experiment table."""
    __tablename__ = "automl_experiments"

    id = Column(String(36), primary_key=True)
    name = Column(String(255), nullable=False)
    task_type = Column(String(50), nullable=False)
    dataset_info = Column(JSON, nullable=True)
    algorithms_to_try = Column(JSON, nullable=True)  # List of algorithm IDs
    optimization_metric = Column(String(50), nullable=True)
    cv_folds = Column(Integer, default=5)
    max_time_minutes = Column(Integer, default=60)
    status = Column(String(20), default="pending")  # pending, running, completed, failed
    best_model_id = Column(String(36), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)

    # Relationships
    models = relationship("TrainedModelDB", back_populates="experiment", cascade="all, delete-orphan")


class TrainedModelDB(Base):
    """Trained model table."""
    __tablename__ = "trained_models"

    id = Column(String(36), primary_key=True)
    experiment_id = Column(String(36), ForeignKey("automl_experiments.id", ondelete="CASCADE"), nullable=False)
    algorithm_id = Column(String(100), nullable=False)
    algorithm_name = Column(String(255), nullable=False)
    hyperparameters = Column(JSON, nullable=True)
    scores = Column(JSON, nullable=True)  # ModelScore as dict
    training_time = Column(Integer, nullable=True)  # in seconds
    recommendations = Column(JSON, nullable=True)  # List of strings
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    experiment = relationship("AutoMLExperimentDB", back_populates="models")
