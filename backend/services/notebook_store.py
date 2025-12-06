"""
Notebook storage service using SQLite database.
"""
from typing import Optional, List
from datetime import datetime
from sqlalchemy import select, delete as sql_delete
from sqlalchemy.orm import selectinload

from core.database import async_session, init_db
from models.db_models import NotebookDB, CellDB, CellOutputDB, ChatMessageDB
from models.notebook import Notebook, Cell, CellOutput, NotebookMetadata, CellType, CellStatus, OutputType


class NotebookStore:
    """Stores and retrieves notebooks using SQLite."""

    async def init(self):
        """Initialize database tables."""
        await init_db()

    def _db_to_notebook(self, db_notebook: NotebookDB) -> Notebook:
        """Convert database model to Pydantic model."""
        cells = []
        for db_cell in db_notebook.cells:
            outputs = []
            for db_output in db_cell.outputs:
                try:
                    output_type = OutputType(db_output.output_type)
                except ValueError:
                    output_type = OutputType.STREAM

                outputs.append(CellOutput(
                    output_type=output_type,
                    text=db_output.text,
                    data=db_output.data,
                    ename=db_output.ename,
                    evalue=db_output.evalue,
                    traceback=db_output.traceback,
                ))

            try:
                cell_type = CellType(db_cell.cell_type)
            except ValueError:
                cell_type = CellType.CODE

            try:
                status = CellStatus(db_cell.status)
            except ValueError:
                status = CellStatus.IDLE

            cells.append(Cell(
                id=db_cell.id,
                cell_type=cell_type,
                source=db_cell.source,
                outputs=outputs,
                execution_count=db_cell.execution_count,
                status=status,
            ))

        return Notebook(
            id=db_notebook.id,
            name=db_notebook.name,
            cells=cells,
            kernel_id=db_notebook.kernel_id,
            metadata=NotebookMetadata(
                kernel_name=db_notebook.kernel_name or "python3",
                language=db_notebook.language or "python",
                created_at=db_notebook.created_at,
                modified_at=db_notebook.updated_at,
            ),
        )

    async def save(self, notebook: Notebook) -> None:
        """Save notebook to database."""
        async with async_session() as session:
            # Check if notebook exists
            result = await session.execute(
                select(NotebookDB).where(NotebookDB.id == notebook.id)
            )
            db_notebook = result.scalar_one_or_none()

            if db_notebook:
                # Update existing notebook
                db_notebook.name = notebook.name
                db_notebook.kernel_id = notebook.kernel_id
                db_notebook.updated_at = datetime.utcnow()

                # Delete existing cells and outputs
                await session.execute(
                    sql_delete(CellDB).where(CellDB.notebook_id == notebook.id)
                )
            else:
                # Create new notebook
                db_notebook = NotebookDB(
                    id=notebook.id,
                    name=notebook.name,
                    kernel_id=notebook.kernel_id,
                    kernel_name=notebook.metadata.kernel_name,
                    language=notebook.metadata.language,
                    created_at=notebook.metadata.created_at,
                    updated_at=datetime.utcnow(),
                )
                session.add(db_notebook)

            # Add cells
            for position, cell in enumerate(notebook.cells):
                db_cell = CellDB(
                    id=cell.id,
                    notebook_id=notebook.id,
                    cell_type=cell.cell_type.value,
                    source=cell.source,
                    position=position,
                    execution_count=cell.execution_count,
                    status=cell.status.value if hasattr(cell.status, 'value') else str(cell.status),
                )
                session.add(db_cell)

                # Add outputs
                for out_pos, output in enumerate(cell.outputs):
                    db_output = CellOutputDB(
                        cell_id=cell.id,
                        output_type=output.output_type.value if hasattr(output.output_type, 'value') else str(output.output_type),
                        text=output.text,
                        data=output.data,
                        ename=output.ename,
                        evalue=output.evalue,
                        traceback=output.traceback,
                        position=out_pos,
                    )
                    session.add(db_output)

            await session.commit()

    async def get(self, notebook_id: str) -> Optional[Notebook]:
        """Get notebook by ID."""
        async with async_session() as session:
            result = await session.execute(
                select(NotebookDB)
                .options(
                    selectinload(NotebookDB.cells).selectinload(CellDB.outputs)
                )
                .where(NotebookDB.id == notebook_id)
            )
            db_notebook = result.scalar_one_or_none()

            if not db_notebook:
                return None

            return self._db_to_notebook(db_notebook)

    async def delete(self, notebook_id: str) -> bool:
        """Delete notebook."""
        async with async_session() as session:
            result = await session.execute(
                select(NotebookDB).where(NotebookDB.id == notebook_id)
            )
            db_notebook = result.scalar_one_or_none()

            if not db_notebook:
                return False

            await session.delete(db_notebook)
            await session.commit()
            return True

    async def list_all(self) -> List[Notebook]:
        """List all notebooks."""
        async with async_session() as session:
            result = await session.execute(
                select(NotebookDB)
                .options(
                    selectinload(NotebookDB.cells).selectinload(CellDB.outputs)
                )
                .order_by(NotebookDB.updated_at.desc())
            )
            db_notebooks = result.scalars().all()

            return [self._db_to_notebook(nb) for nb in db_notebooks]

    # =========================================================================
    # CHAT HISTORY
    # =========================================================================

    async def get_chat_history(self, notebook_id: str) -> List[dict]:
        """Get chat history for a notebook."""
        async with async_session() as session:
            result = await session.execute(
                select(ChatMessageDB)
                .where(ChatMessageDB.notebook_id == notebook_id)
                .order_by(ChatMessageDB.created_at)
            )
            messages = result.scalars().all()

            return [
                {
                    "role": msg.role,
                    "content": msg.content,
                    "created_at": msg.created_at.isoformat() if msg.created_at else None,
                }
                for msg in messages
            ]

    async def save_chat_history(self, notebook_id: str, messages: List[dict]) -> None:
        """Save chat history for a notebook."""
        async with async_session() as session:
            # Delete existing messages
            await session.execute(
                sql_delete(ChatMessageDB).where(ChatMessageDB.notebook_id == notebook_id)
            )

            # Add new messages
            for msg in messages:
                db_msg = ChatMessageDB(
                    notebook_id=notebook_id,
                    role=msg.get("role", "user"),
                    content=msg.get("content", ""),
                )
                session.add(db_msg)

            await session.commit()

    async def clear_chat_history(self, notebook_id: str) -> None:
        """Clear chat history for a notebook."""
        async with async_session() as session:
            await session.execute(
                sql_delete(ChatMessageDB).where(ChatMessageDB.notebook_id == notebook_id)
            )
            await session.commit()


notebook_store = NotebookStore()
