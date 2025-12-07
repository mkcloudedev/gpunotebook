"""Dataset service for data operations."""

import os
import json
import asyncio
from typing import Optional, List, Dict, Any, Tuple
from pathlib import Path
import pandas as pd
import numpy as np
from datetime import datetime


class DatasetService:
    """Service for dataset operations: preview, transform, split, merge, clean."""

    def __init__(self, workspace_path: str = "/home/ubuntu/workspace"):
        self.workspace_path = Path(workspace_path)
        self.datasets_path = self.workspace_path / "datasets"
        self.datasets_path.mkdir(parents=True, exist_ok=True)

    def _get_full_path(self, path: str) -> Path:
        """Get full path, ensuring it's within workspace."""
        if path.startswith("/"):
            path = path[1:]
        full_path = self.workspace_path / path
        # Security check
        if not str(full_path.resolve()).startswith(str(self.workspace_path.resolve())):
            raise ValueError("Path outside workspace")
        return full_path

    async def list_datasets(self) -> List[Dict[str, Any]]:
        """List all datasets in workspace."""
        datasets = []
        extensions = {'.csv', '.xlsx', '.xls', '.json', '.parquet', '.feather'}

        def scan_dir(path: Path):
            try:
                for item in path.iterdir():
                    if item.is_file() and item.suffix.lower() in extensions:
                        stat = item.stat()
                        datasets.append({
                            "name": item.name,
                            "path": str(item.relative_to(self.workspace_path)),
                            "size": stat.st_size,
                            "format": item.suffix[1:].upper(),
                            "modified_at": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                        })
                    elif item.is_dir() and not item.name.startswith('.'):
                        scan_dir(item)
            except PermissionError:
                pass

        await asyncio.to_thread(scan_dir, self.workspace_path)
        return sorted(datasets, key=lambda x: x['modified_at'], reverse=True)

    async def preview_dataset(
        self,
        path: str,
        rows: int = 100,
        offset: int = 0
    ) -> Dict[str, Any]:
        """Preview a dataset with schema and sample data."""
        full_path = self._get_full_path(path)

        if not full_path.exists():
            raise FileNotFoundError(f"Dataset not found: {path}")

        def read_data():
            ext = full_path.suffix.lower()
            df = None

            if ext == '.csv':
                df = pd.read_csv(full_path, nrows=rows + offset)
            elif ext in ['.xlsx', '.xls']:
                df = pd.read_excel(full_path, nrows=rows + offset)
            elif ext == '.json':
                df = pd.read_json(full_path)
                df = df.head(rows + offset)
            elif ext == '.parquet':
                df = pd.read_parquet(full_path)
                df = df.head(rows + offset)
            elif ext == '.feather':
                df = pd.read_feather(full_path)
                df = df.head(rows + offset)
            else:
                raise ValueError(f"Unsupported format: {ext}")

            # Apply offset
            if offset > 0:
                df = df.iloc[offset:]

            return df

        df = await asyncio.to_thread(read_data)

        # Get schema info
        schema = []
        for col in df.columns:
            dtype = str(df[col].dtype)
            null_count = int(df[col].isnull().sum())
            unique_count = int(df[col].nunique())

            schema.append({
                "name": col,
                "type": dtype,
                "null_count": null_count,
                "unique_count": unique_count,
                "sample_values": df[col].dropna().head(3).tolist(),
            })

        # Convert to records
        records = df.replace({np.nan: None}).to_dict(orient='records')

        return {
            "path": path,
            "rows": len(records),
            "total_rows": len(df) + offset,
            "columns": len(df.columns),
            "schema": schema,
            "data": records,
        }

    async def get_dataset_info(self, path: str) -> Dict[str, Any]:
        """Get dataset metadata and statistics."""
        full_path = self._get_full_path(path)

        if not full_path.exists():
            raise FileNotFoundError(f"Dataset not found: {path}")

        def analyze_data():
            ext = full_path.suffix.lower()
            df = None

            if ext == '.csv':
                df = pd.read_csv(full_path)
            elif ext in ['.xlsx', '.xls']:
                df = pd.read_excel(full_path)
            elif ext == '.json':
                df = pd.read_json(full_path)
            elif ext == '.parquet':
                df = pd.read_parquet(full_path)
            elif ext == '.feather':
                df = pd.read_feather(full_path)
            else:
                raise ValueError(f"Unsupported format: {ext}")

            # Basic stats
            stats = {
                "rows": len(df),
                "columns": len(df.columns),
                "memory_usage": int(df.memory_usage(deep=True).sum()),
                "null_count": int(df.isnull().sum().sum()),
                "duplicate_rows": int(df.duplicated().sum()),
            }

            # Column stats
            column_stats = []
            for col in df.columns:
                col_stat = {
                    "name": col,
                    "type": str(df[col].dtype),
                    "null_count": int(df[col].isnull().sum()),
                    "null_percent": round(df[col].isnull().sum() / len(df) * 100, 2),
                    "unique_count": int(df[col].nunique()),
                }

                if df[col].dtype in ['int64', 'float64']:
                    col_stat.update({
                        "min": float(df[col].min()) if not pd.isna(df[col].min()) else None,
                        "max": float(df[col].max()) if not pd.isna(df[col].max()) else None,
                        "mean": float(df[col].mean()) if not pd.isna(df[col].mean()) else None,
                        "std": float(df[col].std()) if not pd.isna(df[col].std()) else None,
                    })

                column_stats.append(col_stat)

            return stats, column_stats

        stats, column_stats = await asyncio.to_thread(analyze_data)
        stat = full_path.stat()

        return {
            "path": path,
            "name": full_path.name,
            "format": full_path.suffix[1:].upper(),
            "size": stat.st_size,
            "modified_at": datetime.fromtimestamp(stat.st_mtime).isoformat(),
            "stats": stats,
            "columns": column_stats,
        }

    async def clean_dataset(
        self,
        path: str,
        operations: List[str],
        output_path: Optional[str] = None
    ) -> Dict[str, Any]:
        """Clean dataset with specified operations."""
        full_path = self._get_full_path(path)

        if not full_path.exists():
            raise FileNotFoundError(f"Dataset not found: {path}")

        def clean_data():
            ext = full_path.suffix.lower()

            if ext == '.csv':
                df = pd.read_csv(full_path)
            elif ext in ['.xlsx', '.xls']:
                df = pd.read_excel(full_path)
            elif ext == '.json':
                df = pd.read_json(full_path)
            elif ext == '.parquet':
                df = pd.read_parquet(full_path)
            else:
                raise ValueError(f"Unsupported format: {ext}")

            original_rows = len(df)
            changes = []

            for op in operations:
                if op == "remove_duplicates":
                    before = len(df)
                    df = df.drop_duplicates()
                    changes.append(f"Removed {before - len(df)} duplicate rows")

                elif op == "remove_null_rows":
                    before = len(df)
                    df = df.dropna()
                    changes.append(f"Removed {before - len(df)} rows with nulls")

                elif op == "fill_null_mean":
                    numeric_cols = df.select_dtypes(include=[np.number]).columns
                    for col in numeric_cols:
                        null_count = df[col].isnull().sum()
                        if null_count > 0:
                            df[col].fillna(df[col].mean(), inplace=True)
                            changes.append(f"Filled {null_count} nulls in {col} with mean")

                elif op == "fill_null_zero":
                    numeric_cols = df.select_dtypes(include=[np.number]).columns
                    for col in numeric_cols:
                        null_count = df[col].isnull().sum()
                        if null_count > 0:
                            df[col].fillna(0, inplace=True)
                            changes.append(f"Filled {null_count} nulls in {col} with 0")

                elif op == "strip_whitespace":
                    string_cols = df.select_dtypes(include=['object']).columns
                    for col in string_cols:
                        df[col] = df[col].str.strip()
                    changes.append(f"Stripped whitespace from {len(string_cols)} columns")

                elif op == "lowercase":
                    string_cols = df.select_dtypes(include=['object']).columns
                    for col in string_cols:
                        df[col] = df[col].str.lower()
                    changes.append(f"Converted {len(string_cols)} columns to lowercase")

            # Save result
            out_path = self._get_full_path(output_path) if output_path else full_path
            out_ext = out_path.suffix.lower()

            if out_ext == '.csv':
                df.to_csv(out_path, index=False)
            elif out_ext in ['.xlsx', '.xls']:
                df.to_excel(out_path, index=False)
            elif out_ext == '.json':
                df.to_json(out_path, orient='records')
            elif out_ext == '.parquet':
                df.to_parquet(out_path, index=False)

            return {
                "original_rows": original_rows,
                "final_rows": len(df),
                "rows_removed": original_rows - len(df),
                "changes": changes,
                "output_path": str(out_path.relative_to(self.workspace_path)),
            }

        return await asyncio.to_thread(clean_data)

    async def split_dataset(
        self,
        path: str,
        train_ratio: float = 0.8,
        shuffle: bool = True,
        random_state: int = 42
    ) -> Dict[str, Any]:
        """Split dataset into train/test sets."""
        full_path = self._get_full_path(path)

        if not full_path.exists():
            raise FileNotFoundError(f"Dataset not found: {path}")

        def split_data():
            ext = full_path.suffix.lower()

            if ext == '.csv':
                df = pd.read_csv(full_path)
            elif ext in ['.xlsx', '.xls']:
                df = pd.read_excel(full_path)
            elif ext == '.parquet':
                df = pd.read_parquet(full_path)
            else:
                raise ValueError(f"Unsupported format for split: {ext}")

            if shuffle:
                df = df.sample(frac=1, random_state=random_state).reset_index(drop=True)

            split_idx = int(len(df) * train_ratio)
            train_df = df.iloc[:split_idx]
            test_df = df.iloc[split_idx:]

            # Save files
            base_name = full_path.stem
            train_path = full_path.parent / f"{base_name}_train{ext}"
            test_path = full_path.parent / f"{base_name}_test{ext}"

            if ext == '.csv':
                train_df.to_csv(train_path, index=False)
                test_df.to_csv(test_path, index=False)
            elif ext in ['.xlsx', '.xls']:
                train_df.to_excel(train_path, index=False)
                test_df.to_excel(test_path, index=False)
            elif ext == '.parquet':
                train_df.to_parquet(train_path, index=False)
                test_df.to_parquet(test_path, index=False)

            return {
                "train_path": str(train_path.relative_to(self.workspace_path)),
                "test_path": str(test_path.relative_to(self.workspace_path)),
                "train_rows": len(train_df),
                "test_rows": len(test_df),
                "train_ratio": train_ratio,
                "shuffled": shuffle,
            }

        return await asyncio.to_thread(split_data)

    async def merge_datasets(
        self,
        paths: List[str],
        output_path: str,
        merge_type: str = "concat",  # concat, join
        join_on: Optional[str] = None
    ) -> Dict[str, Any]:
        """Merge multiple datasets."""

        def merge_data():
            dfs = []
            for path in paths:
                full_path = self._get_full_path(path)
                ext = full_path.suffix.lower()

                if ext == '.csv':
                    df = pd.read_csv(full_path)
                elif ext in ['.xlsx', '.xls']:
                    df = pd.read_excel(full_path)
                elif ext == '.parquet':
                    df = pd.read_parquet(full_path)
                else:
                    raise ValueError(f"Unsupported format: {ext}")

                dfs.append(df)

            if merge_type == "concat":
                result = pd.concat(dfs, ignore_index=True)
            elif merge_type == "join" and join_on:
                result = dfs[0]
                for df in dfs[1:]:
                    result = result.merge(df, on=join_on, how='outer')
            else:
                raise ValueError(f"Invalid merge type: {merge_type}")

            # Save result
            out_path = self._get_full_path(output_path)
            ext = out_path.suffix.lower()

            if ext == '.csv':
                result.to_csv(out_path, index=False)
            elif ext == '.parquet':
                result.to_parquet(out_path, index=False)
            elif ext == '.json':
                result.to_json(out_path, orient='records')

            return {
                "output_path": str(out_path.relative_to(self.workspace_path)),
                "rows": len(result),
                "columns": len(result.columns),
                "merged_files": len(paths),
            }

        return await asyncio.to_thread(merge_data)

    async def export_dataset(
        self,
        path: str,
        output_format: str,
        output_path: Optional[str] = None
    ) -> Dict[str, Any]:
        """Export dataset to different format."""
        full_path = self._get_full_path(path)

        if not full_path.exists():
            raise FileNotFoundError(f"Dataset not found: {path}")

        def export_data():
            ext = full_path.suffix.lower()

            if ext == '.csv':
                df = pd.read_csv(full_path)
            elif ext in ['.xlsx', '.xls']:
                df = pd.read_excel(full_path)
            elif ext == '.json':
                df = pd.read_json(full_path)
            elif ext == '.parquet':
                df = pd.read_parquet(full_path)
            else:
                raise ValueError(f"Unsupported format: {ext}")

            # Determine output path
            if output_path:
                out_path = self._get_full_path(output_path)
            else:
                out_path = full_path.with_suffix(f".{output_format.lower()}")

            # Export
            if output_format.lower() == 'csv':
                df.to_csv(out_path, index=False)
            elif output_format.lower() in ['xlsx', 'excel']:
                df.to_excel(out_path, index=False)
            elif output_format.lower() == 'json':
                df.to_json(out_path, orient='records', indent=2)
            elif output_format.lower() == 'parquet':
                df.to_parquet(out_path, index=False)
            else:
                raise ValueError(f"Unsupported output format: {output_format}")

            return {
                "output_path": str(out_path.relative_to(self.workspace_path)),
                "format": output_format.upper(),
                "rows": len(df),
                "size": out_path.stat().st_size,
            }

        return await asyncio.to_thread(export_data)


# Global singleton
dataset_service = DatasetService()
