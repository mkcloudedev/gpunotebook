"""
Dataset management API endpoints.
Provides data cleaning, transformation, and web scraping capabilities.
"""
import os
import asyncio
from typing import Optional, List, Dict, Any
from pathlib import Path

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, HttpUrl

from core.config import settings

router = APIRouter()


class CleanDataRequest(BaseModel):
    """Request model for data cleaning operation."""
    path: str
    remove_duplicates: bool = False
    remove_nulls: bool = False
    trim_whitespace: bool = False
    normalize_case: bool = False


class CleanDataResponse(BaseModel):
    """Response model for data cleaning operation."""
    success: bool
    message: str
    rows_before: int
    rows_after: int
    rows_removed: int


class WebScrapeRequest(BaseModel):
    """Request model for web scraping operation."""
    url: str
    selector: str = ""
    output_name: str
    use_ai_agent: bool = True
    extract_type: str = "auto"  # auto, table, list, links, text, custom


class WebScrapeResponse(BaseModel):
    """Response model for web scraping operation."""
    success: bool
    message: str
    output_path: str
    rows_extracted: int
    columns_extracted: Optional[List[str]] = None
    ai_analysis: Optional[str] = None


class DatasetPreviewResponse(BaseModel):
    """Response model for dataset preview."""
    columns: List[str]
    rows: List[Dict[str, Any]]
    total_rows: int
    total_columns: int


@router.post("/clean", response_model=CleanDataResponse)
async def clean_dataset(request: CleanDataRequest):
    """
    Clean a dataset by removing duplicates, nulls, trimming whitespace, etc.
    """
    try:
        import pandas as pd

        # Build full path
        file_path = Path(settings.UPLOAD_DIR) / request.path

        if not file_path.exists():
            raise HTTPException(status_code=404, detail=f"File not found: {request.path}")

        # Determine file type and read accordingly
        ext = file_path.suffix.lower()

        if ext == '.csv':
            df = pd.read_csv(file_path)
        elif ext == '.parquet':
            df = pd.read_parquet(file_path)
        elif ext in ['.xlsx', '.xls']:
            df = pd.read_excel(file_path)
        elif ext == '.json':
            df = pd.read_json(file_path)
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported file format: {ext}")

        rows_before = len(df)

        # Apply cleaning operations
        if request.remove_duplicates:
            df = df.drop_duplicates()

        if request.remove_nulls:
            df = df.dropna()

        if request.trim_whitespace:
            # Trim whitespace from string columns
            string_cols = df.select_dtypes(include=['object']).columns
            for col in string_cols:
                df[col] = df[col].apply(lambda x: x.strip() if isinstance(x, str) else x)

        if request.normalize_case:
            # Convert string columns to lowercase
            string_cols = df.select_dtypes(include=['object']).columns
            for col in string_cols:
                df[col] = df[col].apply(lambda x: x.lower() if isinstance(x, str) else x)

        rows_after = len(df)

        # Save cleaned data
        if ext == '.csv':
            df.to_csv(file_path, index=False)
        elif ext == '.parquet':
            df.to_parquet(file_path, index=False)
        elif ext in ['.xlsx', '.xls']:
            df.to_excel(file_path, index=False)
        elif ext == '.json':
            df.to_json(file_path, orient='records')

        return CleanDataResponse(
            success=True,
            message=f"Dataset cleaned successfully",
            rows_before=rows_before,
            rows_after=rows_after,
            rows_removed=rows_before - rows_after
        )

    except HTTPException:
        raise
    except ImportError:
        raise HTTPException(status_code=500, detail="pandas is required for data cleaning")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


async def _ai_analyze_page(html: str, url: str) -> dict:
    """Use AI to analyze the page and determine best extraction strategy."""
    from ai.gateway import ai_gateway
    from models.ai import AIRequest, AIProvider, AIMessage

    # Truncate HTML if too long
    html_sample = html[:15000] if len(html) > 15000 else html

    prompt = f"""Analyze this HTML page and identify the best way to extract structured data.

URL: {url}

HTML (truncated if long):
```html
{html_sample}
```

Respond in JSON format:
{{
    "data_type": "table|list|cards|links|text",
    "selector": "CSS selector to target the data",
    "columns": ["column1", "column2", ...],
    "description": "Brief description of what data was found",
    "extraction_strategy": "Detailed strategy for extraction"
}}

Focus on finding tabular data, product listings, article lists, or any structured repeating content."""

    try:
        response = await ai_gateway.chat(AIRequest(
            provider=AIProvider.CLAUDE,
            messages=[AIMessage(role="user", content=prompt)],
            max_tokens=2000,
            temperature=0.1,
        ))

        import json
        import re
        # Extract JSON from response
        json_match = re.search(r'\{[\s\S]*\}', response.content)
        if json_match:
            return json.loads(json_match.group())
    except Exception as e:
        print(f"AI analysis failed: {e}")

    return {}


async def _ai_extract_data(html: str, url: str, analysis: dict) -> List[Dict[str, Any]]:
    """Use AI to extract structured data from the page."""
    from ai.gateway import ai_gateway
    from models.ai import AIRequest, AIProvider, AIMessage

    html_sample = html[:20000] if len(html) > 20000 else html
    columns = analysis.get('columns', [])

    prompt = f"""Extract structured data from this HTML page.

URL: {url}
Expected columns: {columns}
Data type: {analysis.get('data_type', 'unknown')}
Selector hint: {analysis.get('selector', 'none')}

HTML:
```html
{html_sample}
```

Extract ALL rows of data you can find. Return as a JSON array:
[
    {{"column1": "value1", "column2": "value2", ...}},
    ...
]

Rules:
- Extract every row/item you can find
- Use consistent column names
- Clean the data (remove extra whitespace, newlines)
- If a value is missing, use null
- Return ONLY the JSON array, no explanation"""

    try:
        response = await ai_gateway.chat(AIRequest(
            provider=AIProvider.CLAUDE,
            messages=[AIMessage(role="user", content=prompt)],
            max_tokens=4000,
            temperature=0.0,
        ))

        import json
        import re
        # Extract JSON array from response
        json_match = re.search(r'\[[\s\S]*\]', response.content)
        if json_match:
            return json.loads(json_match.group())
    except Exception as e:
        print(f"AI extraction failed: {e}")

    return []


@router.post("/scrape", response_model=WebScrapeResponse)
async def scrape_web_data(request: WebScrapeRequest):
    """
    Scrape data from a web page using AI agents or CSS selectors.
    """
    try:
        import aiohttp
        from bs4 import BeautifulSoup
        import pandas as pd

        # Fetch the page
        async with aiohttp.ClientSession() as session:
            async with session.get(request.url, headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.5',
            }) as response:
                if response.status != 200:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Failed to fetch URL: HTTP {response.status}"
                    )
                html = await response.text()

        soup = BeautifulSoup(html, 'html.parser')

        # Remove scripts and styles for cleaner extraction
        for script in soup(["script", "style", "nav", "footer", "header"]):
            script.decompose()

        data = []
        ai_analysis = None
        columns_extracted = None

        # Use AI agent for intelligent extraction
        if request.use_ai_agent:
            # Step 1: AI analyzes the page structure
            analysis = await _ai_analyze_page(str(soup), request.url)

            if analysis:
                ai_analysis = analysis.get('description', '')
                columns_extracted = analysis.get('columns', [])

                # Step 2: AI extracts the data
                data = await _ai_extract_data(str(soup), request.url, analysis)

                # If AI extraction failed, fall back to selector-based
                if not data and analysis.get('selector'):
                    request.selector = analysis['selector']

        # Fallback: CSS selector based extraction
        if not data:
            if not request.selector:
                # Auto-detect tables
                tables = soup.find_all('table')
                if tables:
                    request.selector = 'table'
                else:
                    # Try common data patterns
                    for selector in ['[class*="item"]', '[class*="card"]', '[class*="row"]', 'article', 'li']:
                        elements = soup.select(selector)
                        if len(elements) >= 3:
                            request.selector = selector
                            break

            if request.selector:
                elements = soup.select(request.selector)

                if elements:
                    # Check if it's a table
                    if elements[0].name == 'table':
                        table = elements[0]
                        headers = [th.get_text(strip=True) for th in table.find_all('th')]

                        if not headers:
                            first_row = table.find('tr')
                            if first_row:
                                headers = [td.get_text(strip=True) for td in first_row.find_all(['td', 'th'])]

                        columns_extracted = headers

                        for row in table.find_all('tr')[1:]:
                            cells = row.find_all(['td', 'th'])
                            if cells:
                                row_data = {
                                    headers[i] if i < len(headers) else f'col_{i}': cell.get_text(strip=True)
                                    for i, cell in enumerate(cells)
                                }
                                data.append(row_data)
                    else:
                        # Extract from generic elements
                        for i, elem in enumerate(elements):
                            item = {'index': i}

                            # Try to extract structured data from element
                            # Look for common patterns
                            title = elem.find(['h1', 'h2', 'h3', 'h4', 'h5', 'h6', '[class*="title"]'])
                            if title:
                                item['title'] = title.get_text(strip=True)

                            price = elem.find(['[class*="price"]', '[class*="cost"]'])
                            if price:
                                item['price'] = price.get_text(strip=True)

                            desc = elem.find(['p', '[class*="desc"]', '[class*="summary"]'])
                            if desc:
                                item['description'] = desc.get_text(strip=True)

                            link = elem.find('a')
                            if link and link.get('href'):
                                item['link'] = link['href']

                            img = elem.find('img')
                            if img and img.get('src'):
                                item['image'] = img['src']

                            # If no structured data found, just get text
                            if len(item) == 1:
                                item['text'] = elem.get_text(strip=True)[:500]

                            data.append(item)

                        if data:
                            columns_extracted = list(data[0].keys())

        if not data:
            raise HTTPException(
                status_code=400,
                detail="Could not extract data from page. Try specifying a CSS selector or check if the page has extractable content."
            )

        # Create DataFrame and save
        df = pd.DataFrame(data)

        # Ensure output name has .csv extension
        output_name = request.output_name
        if not output_name.endswith('.csv'):
            output_name += '.csv'

        # Save to datasets folder
        datasets_dir = Path(settings.UPLOAD_DIR) / 'datasets'
        datasets_dir.mkdir(parents=True, exist_ok=True)

        output_path = datasets_dir / output_name
        df.to_csv(output_path, index=False)

        return WebScrapeResponse(
            success=True,
            message=f"Scraped {len(data)} rows from {request.url}",
            output_path=f"datasets/{output_name}",
            rows_extracted=len(data),
            columns_extracted=columns_extracted,
            ai_analysis=ai_analysis
        )

    except HTTPException:
        raise
    except ImportError as e:
        raise HTTPException(
            status_code=500,
            detail=f"Required packages not installed: {e}. Install with: pip install aiohttp beautifulsoup4 pandas"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/preview/{path:path}", response_model=DatasetPreviewResponse)
async def preview_dataset(path: str, limit: int = 100):
    """
    Preview a dataset's contents.
    """
    try:
        import pandas as pd
        import json as json_lib

        file_path = Path(settings.UPLOAD_DIR) / path

        if not file_path.exists():
            raise HTTPException(status_code=404, detail=f"File not found: {path}")

        ext = file_path.suffix.lower()

        if ext == '.csv':
            df = pd.read_csv(file_path)
        elif ext == '.parquet':
            df = pd.read_parquet(file_path)
        elif ext in ['.xlsx', '.xls']:
            df = pd.read_excel(file_path)
        elif ext == '.json':
            # Check if it's a tabular JSON or notebook format
            with open(file_path, 'r') as f:
                data = json_lib.load(f)
            # If it's a list of dicts, treat as tabular data
            if isinstance(data, list) and len(data) > 0 and isinstance(data[0], dict):
                df = pd.DataFrame(data)
            # If it has cells key, it's a notebook - not a dataset
            elif isinstance(data, dict) and 'cells' in data:
                raise HTTPException(status_code=400, detail="This is a notebook file, not a dataset")
            elif isinstance(data, dict):
                # Try to convert dict to dataframe
                df = pd.DataFrame([data])
            else:
                raise HTTPException(status_code=400, detail="JSON file format not supported as dataset")
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported file format: {ext}")

        total_rows = len(df)
        total_columns = len(df.columns)

        # Limit rows for preview
        preview_df = df.head(limit)

        # Convert to list of dicts, handling NaN values
        rows = preview_df.fillna('').to_dict(orient='records')

        return DatasetPreviewResponse(
            columns=list(df.columns),
            rows=rows,
            total_rows=total_rows,
            total_columns=total_columns
        )

    except HTTPException:
        raise
    except ImportError:
        raise HTTPException(status_code=500, detail="pandas is required for dataset preview")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/info/{path:path}")
async def get_dataset_info(path: str):
    """
    Get detailed information about a dataset.
    """
    try:
        import pandas as pd

        file_path = Path(settings.UPLOAD_DIR) / path

        if not file_path.exists():
            raise HTTPException(status_code=404, detail=f"File not found: {path}")

        ext = file_path.suffix.lower()

        if ext == '.csv':
            df = pd.read_csv(file_path)
        elif ext == '.parquet':
            df = pd.read_parquet(file_path)
        elif ext in ['.xlsx', '.xls']:
            df = pd.read_excel(file_path)
        elif ext == '.json':
            df = pd.read_json(file_path)
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported file format: {ext}")

        # Get column info
        columns_info = []
        for col in df.columns:
            col_info = {
                'name': col,
                'dtype': str(df[col].dtype),
                'null_count': int(df[col].isnull().sum()),
                'unique_count': int(df[col].nunique()),
            }

            if df[col].dtype in ['int64', 'float64']:
                col_info['min'] = float(df[col].min()) if not pd.isna(df[col].min()) else None
                col_info['max'] = float(df[col].max()) if not pd.isna(df[col].max()) else None
                col_info['mean'] = float(df[col].mean()) if not pd.isna(df[col].mean()) else None

            columns_info.append(col_info)

        return {
            'path': path,
            'rows': len(df),
            'columns': len(df.columns),
            'size_bytes': file_path.stat().st_size,
            'format': ext.upper().strip('.'),
            'columns_info': columns_info,
            'memory_usage_bytes': int(df.memory_usage(deep=True).sum()),
            'duplicates_count': int(df.duplicated().sum()),
            'null_count': int(df.isnull().sum().sum()),
        }

    except HTTPException:
        raise
    except ImportError:
        raise HTTPException(status_code=500, detail="pandas is required for dataset info")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# DATASET TOOLS: Split, Merge, Filter, Export
# ============================================================================

class SplitDatasetRequest(BaseModel):
    """Request model for train/test split."""
    path: str
    train_ratio: float = 0.8
    shuffle: bool = True
    random_seed: int = 42


class MergeDatasetRequest(BaseModel):
    """Request model for merging datasets."""
    paths: List[str]
    output_name: str
    merge_type: str = "concat"  # concat, join
    join_column: Optional[str] = None


class FilterDatasetRequest(BaseModel):
    """Request model for filtering dataset."""
    path: str
    output_name: str
    columns: Optional[List[str]] = None  # Columns to keep
    filter_expr: Optional[str] = None  # e.g., "age > 18"
    sort_by: Optional[str] = None
    ascending: bool = True
    limit: Optional[int] = None


class ExportDatasetRequest(BaseModel):
    """Request model for exporting dataset."""
    path: str
    format: str  # csv, xlsx, parquet, json


class AdvancedScrapeRequest(BaseModel):
    """Request model for advanced web scraping with agent config."""
    url: str
    agent_type: str = "basic"  # basic, playwright, selenium
    user_agent: str = "chrome_windows"
    selectors: Optional[Dict[str, str]] = None
    output_name: str
    output_format: str = "csv"
    wait_for_selector: Optional[str] = None
    scroll_page: bool = False
    timeout: int = 30


class CrawlRequest(BaseModel):
    """Request model for website crawling."""
    start_url: str
    max_pages: int = 10
    url_pattern: Optional[str] = None
    selectors: Optional[Dict[str, str]] = None
    agent_type: str = "basic"


# ============================================================================
# ADVANCED WEB SCRAPING WITH AGENTS
# ============================================================================

@router.get("/scraper/agents")
async def get_available_agents():
    """Get available scraper agents and user agents."""
    from services.scraper_service import scraper_service
    return {
        "agent_types": [
            {"id": "basic", "name": "Basic HTTP", "description": "Fast HTTP requests, good for static pages"},
            {"id": "playwright", "name": "Playwright Browser", "description": "Headless Chrome for JavaScript-heavy sites"},
            {"id": "selenium", "name": "Selenium Browser", "description": "Full browser automation for complex sites"},
        ],
        "user_agents": [
            {"id": k, "name": k.replace("_", " ").title(), "value": v[:50] + "..."}
            for k, v in scraper_service.get_user_agents().items()
        ]
    }


@router.post("/scraper/scrape")
async def advanced_scrape(request: AdvancedScrapeRequest):
    """Scrape URL with configurable agent."""
    try:
        from services.scraper_service import scraper_service

        config = {
            "user_agent": request.user_agent,
            "timeout": request.timeout,
            "wait_for_selector": request.wait_for_selector,
            "scroll_page": request.scroll_page,
        }

        if request.selectors:
            result = await scraper_service.scrape_and_save(
                url=request.url,
                selectors=request.selectors,
                output_name=request.output_name,
                output_format=request.output_format,
                agent_type=request.agent_type,
                config=config,
            )
        else:
            # Just fetch and return HTML info
            result = await scraper_service.scrape_url(
                url=request.url,
                agent_type=request.agent_type,
                config=config,
            )
            # Don't return full HTML
            result.pop("html", None)

        return result

    except ImportError as e:
        raise HTTPException(
            status_code=500,
            detail=f"Agent not available: {e}"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/scraper/extract-tables")
async def extract_tables_from_url(
    url: str,
    agent_type: str = "basic",
    user_agent: str = "chrome_windows"
):
    """Extract all tables from a URL."""
    try:
        from services.scraper_service import scraper_service

        config = {"user_agent": user_agent}
        result = await scraper_service.scrape_url(url, agent_type, config)
        tables = await scraper_service.extract_tables(result["html"])

        return {
            "url": url,
            "tables_found": len(tables),
            "tables": tables,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/scraper/extract-links")
async def extract_links_from_url(
    url: str,
    filter_pattern: Optional[str] = None,
    agent_type: str = "basic",
    user_agent: str = "chrome_windows"
):
    """Extract all links from a URL."""
    try:
        from services.scraper_service import scraper_service

        config = {"user_agent": user_agent}
        result = await scraper_service.scrape_url(url, agent_type, config)
        links = await scraper_service.extract_links(result["html"], url, filter_pattern)

        return {
            "url": url,
            "links_found": len(links),
            "links": links[:100],  # Limit to 100 links
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/scraper/crawl")
async def crawl_website(request: CrawlRequest):
    """Crawl a website following links."""
    try:
        from services.scraper_service import scraper_service

        result = await scraper_service.crawl_site(
            start_url=request.start_url,
            max_pages=request.max_pages,
            url_pattern=request.url_pattern,
            selectors=request.selectors,
            agent_type=request.agent_type,
        )

        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/split")
async def split_dataset(request: SplitDatasetRequest):
    """Split dataset into train and test sets."""
    try:
        import pandas as pd
        from sklearn.model_selection import train_test_split

        file_path = Path(settings.UPLOAD_DIR) / request.path
        if not file_path.exists():
            raise HTTPException(status_code=404, detail=f"File not found: {request.path}")

        ext = file_path.suffix.lower()
        if ext == '.csv':
            df = pd.read_csv(file_path)
        elif ext == '.parquet':
            df = pd.read_parquet(file_path)
        elif ext in ['.xlsx', '.xls']:
            df = pd.read_excel(file_path)
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported format: {ext}")

        # Split the data
        train_df, test_df = train_test_split(
            df,
            train_size=request.train_ratio,
            shuffle=request.shuffle,
            random_state=request.random_seed
        )

        # Generate output names
        base_name = file_path.stem
        parent_dir = file_path.parent

        train_path = parent_dir / f"{base_name}_train{ext}"
        test_path = parent_dir / f"{base_name}_test{ext}"

        # Save files
        if ext == '.csv':
            train_df.to_csv(train_path, index=False)
            test_df.to_csv(test_path, index=False)
        elif ext == '.parquet':
            train_df.to_parquet(train_path, index=False)
            test_df.to_parquet(test_path, index=False)
        elif ext in ['.xlsx', '.xls']:
            train_df.to_excel(train_path, index=False)
            test_df.to_excel(test_path, index=False)

        return {
            "success": True,
            "message": f"Split into {len(train_df)} train and {len(test_df)} test rows",
            "train_path": str(train_path.relative_to(settings.UPLOAD_DIR)),
            "test_path": str(test_path.relative_to(settings.UPLOAD_DIR)),
            "train_rows": len(train_df),
            "test_rows": len(test_df)
        }

    except HTTPException:
        raise
    except ImportError as e:
        raise HTTPException(status_code=500, detail=f"Required packages not installed: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/merge")
async def merge_datasets(request: MergeDatasetRequest):
    """Merge multiple datasets into one."""
    try:
        import pandas as pd

        if len(request.paths) < 2:
            raise HTTPException(status_code=400, detail="Need at least 2 datasets to merge")

        dataframes = []
        for path in request.paths:
            file_path = Path(settings.UPLOAD_DIR) / path
            if not file_path.exists():
                raise HTTPException(status_code=404, detail=f"File not found: {path}")

            ext = file_path.suffix.lower()
            if ext == '.csv':
                df = pd.read_csv(file_path)
            elif ext == '.parquet':
                df = pd.read_parquet(file_path)
            elif ext in ['.xlsx', '.xls']:
                df = pd.read_excel(file_path)
            else:
                raise HTTPException(status_code=400, detail=f"Unsupported format: {ext}")
            dataframes.append(df)

        # Merge based on type
        if request.merge_type == "concat":
            result_df = pd.concat(dataframes, ignore_index=True)
        elif request.merge_type == "join":
            if not request.join_column:
                raise HTTPException(status_code=400, detail="join_column required for join merge")
            result_df = dataframes[0]
            for df in dataframes[1:]:
                result_df = result_df.merge(df, on=request.join_column, how='outer')
        else:
            raise HTTPException(status_code=400, detail=f"Unknown merge type: {request.merge_type}")

        # Save result
        output_name = request.output_name
        if not output_name.endswith('.csv'):
            output_name += '.csv'

        datasets_dir = Path(settings.UPLOAD_DIR) / 'datasets'
        datasets_dir.mkdir(parents=True, exist_ok=True)
        output_path = datasets_dir / output_name
        result_df.to_csv(output_path, index=False)

        return {
            "success": True,
            "message": f"Merged {len(request.paths)} datasets into {len(result_df)} rows",
            "output_path": f"datasets/{output_name}",
            "total_rows": len(result_df),
            "total_columns": len(result_df.columns)
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/filter")
async def filter_dataset(request: FilterDatasetRequest):
    """Filter and transform a dataset."""
    try:
        import pandas as pd

        file_path = Path(settings.UPLOAD_DIR) / request.path
        if not file_path.exists():
            raise HTTPException(status_code=404, detail=f"File not found: {request.path}")

        ext = file_path.suffix.lower()
        if ext == '.csv':
            df = pd.read_csv(file_path)
        elif ext == '.parquet':
            df = pd.read_parquet(file_path)
        elif ext in ['.xlsx', '.xls']:
            df = pd.read_excel(file_path)
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported format: {ext}")

        original_rows = len(df)

        # Select columns
        if request.columns:
            valid_cols = [c for c in request.columns if c in df.columns]
            if valid_cols:
                df = df[valid_cols]

        # Apply filter expression
        if request.filter_expr:
            try:
                df = df.query(request.filter_expr)
            except Exception as e:
                raise HTTPException(status_code=400, detail=f"Invalid filter expression: {e}")

        # Sort
        if request.sort_by and request.sort_by in df.columns:
            df = df.sort_values(by=request.sort_by, ascending=request.ascending)

        # Limit
        if request.limit and request.limit > 0:
            df = df.head(request.limit)

        # Save result
        output_name = request.output_name
        if not output_name.endswith('.csv'):
            output_name += '.csv'

        datasets_dir = Path(settings.UPLOAD_DIR) / 'datasets'
        datasets_dir.mkdir(parents=True, exist_ok=True)
        output_path = datasets_dir / output_name
        df.to_csv(output_path, index=False)

        return {
            "success": True,
            "message": f"Filtered from {original_rows} to {len(df)} rows",
            "output_path": f"datasets/{output_name}",
            "original_rows": original_rows,
            "filtered_rows": len(df),
            "columns": list(df.columns)
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/export")
async def export_dataset(request: ExportDatasetRequest):
    """Export dataset to different format."""
    try:
        import pandas as pd

        file_path = Path(settings.UPLOAD_DIR) / request.path
        if not file_path.exists():
            raise HTTPException(status_code=404, detail=f"File not found: {request.path}")

        ext = file_path.suffix.lower()
        if ext == '.csv':
            df = pd.read_csv(file_path)
        elif ext == '.parquet':
            df = pd.read_parquet(file_path)
        elif ext in ['.xlsx', '.xls']:
            df = pd.read_excel(file_path)
        elif ext == '.json':
            df = pd.read_json(file_path)
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported source format: {ext}")

        # Generate output path
        base_name = file_path.stem
        output_format = request.format.lower().strip('.')
        datasets_dir = Path(settings.UPLOAD_DIR) / 'datasets'
        datasets_dir.mkdir(parents=True, exist_ok=True)

        output_path = datasets_dir / f"{base_name}_export.{output_format}"

        # Export
        if output_format == 'csv':
            df.to_csv(output_path, index=False)
        elif output_format == 'xlsx':
            df.to_excel(output_path, index=False)
        elif output_format == 'parquet':
            df.to_parquet(output_path, index=False)
        elif output_format == 'json':
            df.to_json(output_path, orient='records')
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported export format: {output_format}")

        return {
            "success": True,
            "message": f"Exported to {output_format.upper()}",
            "output_path": f"datasets/{base_name}_export.{output_format}",
            "rows": len(df),
            "columns": len(df.columns)
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
