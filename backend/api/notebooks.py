"""
Notebooks API endpoints.
"""
import uuid
import json
from typing import List
from fastapi import APIRouter, HTTPException, status, UploadFile, File

from models.notebook import (
    Notebook,
    NotebookCreate,
    NotebookUpdate,
    NotebookMetadata,
    Cell,
    CellCreate,
    CellUpdate,
    CellOutput,
)
from services.notebook_store import notebook_store

router = APIRouter()


@router.get("", response_model=List[Notebook])
async def list_notebooks():
    """List all notebooks."""
    return await notebook_store.list_all()


@router.post("", response_model=Notebook, status_code=status.HTTP_201_CREATED)
async def create_notebook(request: NotebookCreate):
    """Create a new notebook."""
    notebook = Notebook(
        id=str(uuid.uuid4()),
        name=request.name,
        cells=[],
        metadata=NotebookMetadata(kernel_name=request.kernel_name),
    )
    await notebook_store.save(notebook)
    return notebook


@router.post("/import", response_model=Notebook, status_code=status.HTTP_201_CREATED)
async def import_notebook(file: UploadFile = File(...)):
    """Import a Jupyter notebook (.ipynb) file."""
    if not file.filename or not file.filename.endswith('.ipynb'):
        raise HTTPException(
            status_code=400,
            detail="File must be a Jupyter notebook (.ipynb)"
        )

    try:
        content = await file.read()
        ipynb_data = json.loads(content)
    except json.JSONDecodeError:
        raise HTTPException(
            status_code=400,
            detail="Invalid JSON in notebook file"
        )

    # Extract notebook name from filename (without extension)
    name = file.filename.rsplit('.', 1)[0] if file.filename else "Imported Notebook"

    # Parse cells from ipynb format
    cells = []
    for ipynb_cell in ipynb_data.get("cells", []):
        # Get source - can be string or list of strings
        source = ipynb_cell.get("source", "")
        if isinstance(source, list):
            source = "".join(source)

        # Map cell type
        cell_type = ipynb_cell.get("cell_type", "code")
        if cell_type not in ["code", "markdown"]:
            cell_type = "code"  # Default to code for raw, etc.

        # Parse outputs for code cells
        outputs = []
        if cell_type == "code":
            for ipynb_output in ipynb_cell.get("outputs", []):
                output_type = ipynb_output.get("output_type", "stream")

                # Map output types
                if output_type == "execute_result":
                    output_type = "execute_result"
                elif output_type == "display_data":
                    output_type = "display_data"
                elif output_type == "error":
                    output_type = "error"
                else:
                    output_type = "stream"

                # Get text (can be string or list)
                text = ipynb_output.get("text", "")
                if isinstance(text, list):
                    text = "".join(text)

                output = CellOutput(
                    output_type=output_type,
                    text=text if text else None,
                    data=ipynb_output.get("data"),
                    ename=ipynb_output.get("ename"),
                    evalue=ipynb_output.get("evalue"),
                    traceback=ipynb_output.get("traceback"),
                )
                outputs.append(output)

        cell = Cell(
            id=ipynb_cell.get("id") or str(uuid.uuid4()),
            cell_type=cell_type,
            source=source,
            outputs=outputs,
            execution_count=ipynb_cell.get("execution_count"),
        )
        cells.append(cell)

    # Create the notebook
    notebook = Notebook(
        id=str(uuid.uuid4()),
        name=name,
        cells=cells,
        metadata=NotebookMetadata(
            kernel_name=ipynb_data.get("metadata", {}).get("kernelspec", {}).get("name", "python3"),
            language=ipynb_data.get("metadata", {}).get("language_info", {}).get("name", "python"),
        ),
    )

    await notebook_store.save(notebook)
    return notebook


@router.get("/{notebook_id}", response_model=Notebook)
async def get_notebook(notebook_id: str):
    """Get a notebook by ID."""
    notebook = await notebook_store.get(notebook_id)
    if not notebook:
        raise HTTPException(status_code=404, detail="Notebook not found")
    return notebook


@router.put("/{notebook_id}", response_model=Notebook)
async def update_notebook(notebook_id: str, request: NotebookUpdate):
    """Update a notebook."""
    notebook = await notebook_store.get(notebook_id)
    if not notebook:
        raise HTTPException(status_code=404, detail="Notebook not found")

    if request.name is not None:
        notebook.name = request.name
    if request.cells is not None:
        notebook.cells = request.cells

    await notebook_store.save(notebook)
    return notebook


@router.delete("/{notebook_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_notebook(notebook_id: str):
    """Delete a notebook."""
    success = await notebook_store.delete(notebook_id)
    if not success:
        raise HTTPException(status_code=404, detail="Notebook not found")


@router.post("/{notebook_id}/cells", response_model=Cell, status_code=status.HTTP_201_CREATED)
async def add_cell(notebook_id: str, request: CellCreate):
    """Add a cell to a notebook."""
    notebook = await notebook_store.get(notebook_id)
    if not notebook:
        raise HTTPException(status_code=404, detail="Notebook not found")

    cell = Cell(
        id=str(uuid.uuid4()),
        cell_type=request.cell_type,
        source=request.source,
    )

    if request.position is not None and 0 <= request.position <= len(notebook.cells):
        notebook.cells.insert(request.position, cell)
    else:
        notebook.cells.append(cell)

    await notebook_store.save(notebook)
    return cell


@router.put("/{notebook_id}/cells/{cell_id}", response_model=Cell)
async def update_cell(notebook_id: str, cell_id: str, request: CellUpdate):
    """Update a cell in a notebook."""
    notebook = await notebook_store.get(notebook_id)
    if not notebook:
        raise HTTPException(status_code=404, detail="Notebook not found")

    cell = next((c for c in notebook.cells if c.id == cell_id), None)
    if not cell:
        raise HTTPException(status_code=404, detail="Cell not found")

    if request.source is not None:
        cell.source = request.source
    if request.cell_type is not None:
        cell.cell_type = request.cell_type

    await notebook_store.save(notebook)
    return cell


@router.delete("/{notebook_id}/cells/{cell_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_cell(notebook_id: str, cell_id: str):
    """Delete a cell from a notebook."""
    notebook = await notebook_store.get(notebook_id)
    if not notebook:
        raise HTTPException(status_code=404, detail="Notebook not found")

    notebook.cells = [c for c in notebook.cells if c.id != cell_id]
    await notebook_store.save(notebook)


# ============================================================================
# CHAT HISTORY
# ============================================================================

@router.get("/{notebook_id}/chat")
async def get_chat_history(notebook_id: str):
    """Get chat history for a notebook."""
    history = await notebook_store.get_chat_history(notebook_id)
    return {"messages": history}


@router.post("/{notebook_id}/chat")
async def save_chat_history(notebook_id: str, request: dict):
    """Save chat history for a notebook."""
    messages = request.get("messages", [])
    await notebook_store.save_chat_history(notebook_id, messages)
    return {"status": "ok"}


@router.delete("/{notebook_id}/chat", status_code=status.HTTP_204_NO_CONTENT)
async def clear_chat_history(notebook_id: str):
    """Clear chat history for a notebook."""
    await notebook_store.clear_chat_history(notebook_id)


# ============================================================================
# EXPORT
# ============================================================================

from fastapi.responses import PlainTextResponse, Response

@router.get("/{notebook_id}/export/python", response_class=PlainTextResponse)
async def export_to_python(notebook_id: str):
    """Export notebook to Python script."""
    notebook = await notebook_store.get(notebook_id)
    if not notebook:
        raise HTTPException(status_code=404, detail="Notebook not found")

    lines = [
        f"# {notebook.name}",
        f"# Exported from GPU Notebook",
        f"# Created: {notebook.created_at}",
        "",
    ]

    for i, cell in enumerate(notebook.cells):
        if cell.cell_type == "markdown":
            # Convert markdown to comments
            for line in cell.source.split('\n'):
                lines.append(f"# {line}")
            lines.append("")
        else:
            # Code cell
            lines.append(f"# In[{i + 1}]:")
            lines.append(cell.source)
            lines.append("")

    return "\n".join(lines)


@router.get("/{notebook_id}/export/ipynb")
async def export_to_ipynb(notebook_id: str):
    """Export notebook to Jupyter .ipynb format."""
    notebook = await notebook_store.get(notebook_id)
    if not notebook:
        raise HTTPException(status_code=404, detail="Notebook not found")

    import json

    ipynb = {
        "nbformat": 4,
        "nbformat_minor": 5,
        "metadata": {
            "kernelspec": {
                "display_name": "Python 3",
                "language": "python",
                "name": "python3"
            },
            "language_info": {
                "name": "python",
                "version": "3.11.0"
            }
        },
        "cells": []
    }

    for cell in notebook.cells:
        ipynb_cell = {
            "id": cell.id,
            "cell_type": cell.cell_type if cell.cell_type == "markdown" else "code",
            "source": cell.source.split('\n') if cell.source else [],
            "metadata": {}
        }

        if cell.cell_type == "code":
            ipynb_cell["execution_count"] = cell.execution_count
            ipynb_cell["outputs"] = []
            if cell.outputs:
                for output in cell.outputs:
                    ipynb_output = {"output_type": output.output_type}
                    if output.text:
                        ipynb_output["text"] = output.text.split('\n')
                    if output.data:
                        ipynb_output["data"] = output.data
                    if output.ename:
                        ipynb_output["ename"] = output.ename
                        ipynb_output["evalue"] = output.evalue or ""
                        ipynb_output["traceback"] = output.traceback or []
                    ipynb_cell["outputs"].append(ipynb_output)

        ipynb["cells"].append(ipynb_cell)

    content = json.dumps(ipynb, indent=2)
    return Response(
        content=content,
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="{notebook.name}.ipynb"'}
    )


from fastapi.responses import HTMLResponse
import html as html_lib
import base64

@router.get("/{notebook_id}/export/html", response_class=HTMLResponse)
async def export_to_html(notebook_id: str):
    """Export notebook to HTML format."""
    notebook = await notebook_store.get(notebook_id)
    if not notebook:
        raise HTTPException(status_code=404, detail="Notebook not found")

    # Build HTML document
    html_parts = [f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{html_lib.escape(notebook.name)}</title>
    <style>
        * {{ box-sizing: border-box; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 900px;
            margin: 0 auto;
            padding: 20px;
            background: #1a1a2e;
            color: #e0e0e0;
        }}
        h1 {{ color: #a78bfa; border-bottom: 2px solid #a78bfa; padding-bottom: 10px; }}
        .cell {{
            margin: 16px 0;
            border: 1px solid #2d2d44;
            border-radius: 8px;
            overflow: hidden;
        }}
        .cell-header {{
            background: #2d2d44;
            padding: 8px 12px;
            font-size: 12px;
            color: #888;
            display: flex;
            align-items: center;
            gap: 8px;
        }}
        .cell-type {{
            background: #a78bfa33;
            color: #a78bfa;
            padding: 2px 8px;
            border-radius: 4px;
            font-weight: bold;
        }}
        .cell-type.markdown {{
            background: #22c55e33;
            color: #22c55e;
        }}
        .execution-count {{
            font-family: monospace;
            color: #888;
        }}
        .cell-content {{
            padding: 16px;
            background: #16162a;
        }}
        .code-cell .cell-content {{
            font-family: 'Monaco', 'Menlo', monospace;
            font-size: 13px;
            white-space: pre-wrap;
            line-height: 1.5;
        }}
        .markdown-cell .cell-content {{
            line-height: 1.6;
        }}
        .markdown-cell h1, .markdown-cell h2, .markdown-cell h3 {{
            color: #a78bfa;
            margin-top: 0;
        }}
        .output {{
            border-top: 1px solid #2d2d44;
            padding: 12px 16px;
            background: #0d0d1a;
        }}
        .output-text {{
            font-family: monospace;
            font-size: 13px;
            white-space: pre-wrap;
            color: #e0e0e0;
        }}
        .output-error {{
            background: #dc262633;
            border-left: 3px solid #dc2626;
            padding: 12px;
            color: #fca5a5;
        }}
        .output-image {{
            max-width: 100%;
            border-radius: 4px;
        }}
        .output-table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }}
        .output-table th, .output-table td {{
            border: 1px solid #2d2d44;
            padding: 8px 12px;
            text-align: left;
        }}
        .output-table th {{
            background: #2d2d44;
        }}
        code {{
            background: #2d2d44;
            padding: 2px 6px;
            border-radius: 4px;
            font-family: monospace;
        }}
        .footer {{
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #2d2d44;
            color: #666;
            font-size: 12px;
        }}
    </style>
</head>
<body>
    <h1>{html_lib.escape(notebook.name)}</h1>
    <p style="color: #888; font-size: 14px;">Exported from GPU Notebook • {notebook.created_at.strftime('%Y-%m-%d %H:%M')}</p>
"""]

    for i, cell in enumerate(notebook.cells):
        is_code = cell.cell_type == "code"
        cell_class = "code-cell" if is_code else "markdown-cell"
        type_class = "" if is_code else "markdown"

        html_parts.append(f"""
    <div class="cell {cell_class}">
        <div class="cell-header">
            <span class="cell-type {type_class}">{'Code' if is_code else 'Markdown'}</span>
            {'<span class="execution-count">[' + str(cell.execution_count or i+1) + ']</span>' if is_code else ''}
        </div>
        <div class="cell-content">""")

        if is_code:
            html_parts.append(html_lib.escape(cell.source))
        else:
            # Simple markdown to HTML conversion
            md_html = cell.source
            # Headers
            md_html = md_html.replace('### ', '<h3>').replace('\n', '</h3>\n', 1) if '### ' in md_html else md_html
            md_html = md_html.replace('## ', '<h2>').replace('\n', '</h2>\n', 1) if '## ' in md_html else md_html
            md_html = md_html.replace('# ', '<h1>').replace('\n', '</h1>\n', 1) if '# ' in md_html else md_html
            # Bold
            import re
            md_html = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', md_html)
            # Code
            md_html = re.sub(r'`([^`]+)`', r'<code>\1</code>', md_html)
            # Line breaks
            md_html = md_html.replace('\n', '<br>\n')
            html_parts.append(md_html)

        html_parts.append("</div>")

        # Outputs for code cells
        if is_code and cell.outputs:
            for output in cell.outputs:
                html_parts.append('<div class="output">')

                if output.output_type == "error":
                    html_parts.append(f"""
                <div class="output-error">
                    <strong>{html_lib.escape(output.ename or 'Error')}</strong>: {html_lib.escape(output.evalue or '')}
                    {'<pre>' + html_lib.escape(chr(10).join(output.traceback or [])) + '</pre>' if output.traceback else ''}
                </div>""")
                elif output.data:
                    if 'image/png' in output.data:
                        img_data = output.data['image/png']
                        if isinstance(img_data, list):
                            img_data = ''.join(img_data)
                        html_parts.append(f'<img class="output-image" src="data:image/png;base64,{img_data}" />')
                    elif 'text/html' in output.data:
                        html_content = output.data['text/html']
                        if isinstance(html_content, list):
                            html_content = ''.join(html_content)
                        html_parts.append(html_content)
                    elif 'text/plain' in output.data:
                        text = output.data['text/plain']
                        if isinstance(text, list):
                            text = ''.join(text)
                        html_parts.append(f'<pre class="output-text">{html_lib.escape(text)}</pre>')
                elif output.text:
                    html_parts.append(f'<pre class="output-text">{html_lib.escape(output.text)}</pre>')

                html_parts.append('</div>')

        html_parts.append("</div>")

    html_parts.append("""
    <div class="footer">
        Generated by GPU Notebook
    </div>
</body>
</html>""")

    return ''.join(html_parts)
