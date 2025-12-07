"""Web scraper service with configurable agents."""

import os
import re
import json
import asyncio
import aiohttp
from typing import Optional, List, Dict, Any
from pathlib import Path
from datetime import datetime
from urllib.parse import urljoin, urlparse
from bs4 import BeautifulSoup
import pandas as pd


class ScraperAgent:
    """Base scraper agent."""

    def __init__(self, config: Dict[str, Any] = None):
        self.config = config or {}
        self.timeout = self.config.get("timeout", 30)
        self.headers = self.config.get("headers", {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        })

    async def fetch(self, url: str) -> str:
        """Fetch URL content."""
        raise NotImplementedError


class BasicAgent(ScraperAgent):
    """Basic HTTP agent using aiohttp."""

    async def fetch(self, url: str) -> str:
        """Fetch URL using simple HTTP request."""
        async with aiohttp.ClientSession() as session:
            async with session.get(
                url,
                headers=self.headers,
                timeout=aiohttp.ClientTimeout(total=self.timeout)
            ) as response:
                response.raise_for_status()
                return await response.text()


class PlaywrightAgent(ScraperAgent):
    """Browser agent using Playwright for JavaScript-heavy sites."""

    async def fetch(self, url: str) -> str:
        """Fetch URL using headless browser."""
        try:
            from playwright.async_api import async_playwright
        except ImportError:
            raise ImportError("Playwright not installed. Run: pip install playwright && playwright install chromium")

        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=True,
                args=['--no-sandbox', '--disable-dev-shm-usage']
            )
            try:
                context = await browser.new_context(
                    user_agent=self.headers.get("User-Agent"),
                    viewport={"width": 1920, "height": 1080}
                )
                page = await context.new_page()

                # Navigate and wait for network idle
                await page.goto(url, wait_until="networkidle", timeout=self.timeout * 1000)

                # Optional: wait for specific selector
                wait_selector = self.config.get("wait_for_selector")
                if wait_selector:
                    await page.wait_for_selector(wait_selector, timeout=10000)

                # Optional: scroll to load lazy content
                if self.config.get("scroll_page", False):
                    await page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
                    await asyncio.sleep(1)

                content = await page.content()
                return content
            finally:
                await browser.close()


class SeleniumAgent(ScraperAgent):
    """Browser agent using Selenium for complex interactions."""

    async def fetch(self, url: str) -> str:
        """Fetch URL using Selenium browser."""
        try:
            from selenium import webdriver
            from selenium.webdriver.chrome.options import Options
            from selenium.webdriver.chrome.service import Service
            from selenium.webdriver.common.by import By
            from selenium.webdriver.support.ui import WebDriverWait
            from selenium.webdriver.support import expected_conditions as EC
        except ImportError:
            raise ImportError("Selenium not installed. Run: pip install selenium webdriver-manager")

        def run_selenium():
            options = Options()
            options.add_argument("--headless")
            options.add_argument("--no-sandbox")
            options.add_argument("--disable-dev-shm-usage")
            options.add_argument(f"user-agent={self.headers.get('User-Agent')}")

            driver = webdriver.Chrome(options=options)
            try:
                driver.get(url)

                # Wait for page load
                wait_selector = self.config.get("wait_for_selector")
                if wait_selector:
                    WebDriverWait(driver, 10).until(
                        EC.presence_of_element_located((By.CSS_SELECTOR, wait_selector))
                    )

                # Optional scroll
                if self.config.get("scroll_page", False):
                    driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
                    import time
                    time.sleep(1)

                return driver.page_source
            finally:
                driver.quit()

        return await asyncio.to_thread(run_selenium)


class ScraperService:
    """Web scraper service with multiple agent types."""

    AGENT_TYPES = {
        "basic": BasicAgent,
        "playwright": PlaywrightAgent,
        "selenium": SeleniumAgent,
    }

    USER_AGENTS = {
        "chrome_windows": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "chrome_mac": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "firefox_windows": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
        "safari_mac": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
        "googlebot": "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
        "mobile_android": "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        "mobile_iphone": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1",
    }

    def __init__(self, workspace_path: str = "/home/ubuntu/workspace"):
        self.workspace_path = Path(workspace_path)
        self.output_path = self.workspace_path / "scraped_data"
        self.output_path.mkdir(parents=True, exist_ok=True)

    def get_agent(self, agent_type: str, config: Dict[str, Any] = None) -> ScraperAgent:
        """Get scraper agent by type."""
        agent_class = self.AGENT_TYPES.get(agent_type)
        if not agent_class:
            raise ValueError(f"Unknown agent type: {agent_type}. Available: {list(self.AGENT_TYPES.keys())}")
        return agent_class(config)

    def get_user_agents(self) -> Dict[str, str]:
        """Get available user agents."""
        return self.USER_AGENTS

    async def scrape_url(
        self,
        url: str,
        agent_type: str = "basic",
        config: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Scrape a single URL."""
        config = config or {}

        # Apply user agent if specified
        if "user_agent" in config:
            ua_key = config["user_agent"]
            if ua_key in self.USER_AGENTS:
                config.setdefault("headers", {})["User-Agent"] = self.USER_AGENTS[ua_key]

        agent = self.get_agent(agent_type, config)

        start_time = datetime.now()
        html = await agent.fetch(url)
        fetch_time = (datetime.now() - start_time).total_seconds()

        soup = BeautifulSoup(html, 'html.parser')

        # Extract metadata
        title = soup.title.string if soup.title else None
        description = None
        desc_tag = soup.find("meta", attrs={"name": "description"})
        if desc_tag:
            description = desc_tag.get("content")

        return {
            "url": url,
            "title": title,
            "description": description,
            "html_length": len(html),
            "fetch_time": fetch_time,
            "agent_type": agent_type,
            "html": html,
        }

    async def extract_data(
        self,
        html: str,
        selectors: Dict[str, str],
        extract_type: str = "text"  # text, html, attr
    ) -> List[Dict[str, Any]]:
        """Extract data from HTML using CSS selectors."""
        soup = BeautifulSoup(html, 'html.parser')
        results = []

        # Find the container if specified
        container_selector = selectors.get("_container")
        if container_selector:
            containers = soup.select(container_selector)
        else:
            containers = [soup]

        for container in containers:
            item = {}
            for key, selector in selectors.items():
                if key.startswith("_"):
                    continue

                # Parse selector with optional attribute
                attr_match = re.match(r'(.+?)@(\w+)$', selector)
                if attr_match:
                    sel, attr = attr_match.groups()
                    element = container.select_one(sel)
                    if element:
                        item[key] = element.get(attr)
                else:
                    element = container.select_one(selector)
                    if element:
                        if extract_type == "html":
                            item[key] = str(element)
                        else:
                            item[key] = element.get_text(strip=True)

            if item:
                results.append(item)

        return results

    async def extract_links(
        self,
        html: str,
        base_url: str,
        filter_pattern: Optional[str] = None
    ) -> List[Dict[str, str]]:
        """Extract all links from HTML."""
        soup = BeautifulSoup(html, 'html.parser')
        links = []

        for a in soup.find_all('a', href=True):
            href = a['href']
            # Make absolute URL
            absolute_url = urljoin(base_url, href)

            # Filter if pattern specified
            if filter_pattern and not re.search(filter_pattern, absolute_url):
                continue

            links.append({
                "url": absolute_url,
                "text": a.get_text(strip=True),
                "title": a.get("title"),
            })

        return links

    async def extract_tables(self, html: str) -> List[Dict[str, Any]]:
        """Extract all tables from HTML."""
        soup = BeautifulSoup(html, 'html.parser')
        tables = []

        for idx, table in enumerate(soup.find_all('table')):
            rows = []
            headers = []

            # Get headers
            header_row = table.find('thead')
            if header_row:
                for th in header_row.find_all(['th', 'td']):
                    headers.append(th.get_text(strip=True))

            # Get rows
            tbody = table.find('tbody') or table
            for tr in tbody.find_all('tr'):
                cells = [td.get_text(strip=True) for td in tr.find_all(['td', 'th'])]
                if cells:
                    if not headers and len(rows) == 0:
                        headers = cells
                    else:
                        rows.append(cells)

            tables.append({
                "index": idx,
                "headers": headers,
                "rows": rows,
                "row_count": len(rows),
            })

        return tables

    async def scrape_and_save(
        self,
        url: str,
        selectors: Dict[str, str],
        output_name: str,
        output_format: str = "csv",
        agent_type: str = "basic",
        config: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Scrape URL, extract data, and save to file."""
        # Scrape
        result = await self.scrape_url(url, agent_type, config)

        # Extract
        data = await self.extract_data(result["html"], selectors)

        if not data:
            return {
                "success": False,
                "error": "No data extracted with given selectors",
                "url": url,
            }

        # Convert to DataFrame
        df = pd.DataFrame(data)

        # Save
        output_file = self.output_path / f"{output_name}.{output_format}"

        if output_format == "csv":
            df.to_csv(output_file, index=False)
        elif output_format == "json":
            df.to_json(output_file, orient="records", indent=2)
        elif output_format == "parquet":
            df.to_parquet(output_file, index=False)

        return {
            "success": True,
            "url": url,
            "rows_extracted": len(data),
            "columns": list(df.columns),
            "output_path": str(output_file.relative_to(self.workspace_path)),
            "fetch_time": result["fetch_time"],
        }

    async def scrape_multiple(
        self,
        urls: List[str],
        selectors: Dict[str, str],
        output_name: str,
        output_format: str = "csv",
        agent_type: str = "basic",
        config: Optional[Dict[str, Any]] = None,
        delay: float = 1.0
    ) -> Dict[str, Any]:
        """Scrape multiple URLs and combine results."""
        all_data = []
        errors = []

        for i, url in enumerate(urls):
            try:
                result = await self.scrape_url(url, agent_type, config)
                data = await self.extract_data(result["html"], selectors)
                for item in data:
                    item["_source_url"] = url
                all_data.extend(data)
            except Exception as e:
                errors.append({"url": url, "error": str(e)})

            # Delay between requests
            if i < len(urls) - 1:
                await asyncio.sleep(delay)

        if not all_data:
            return {
                "success": False,
                "error": "No data extracted from any URL",
                "errors": errors,
            }

        # Save combined results
        df = pd.DataFrame(all_data)
        output_file = self.output_path / f"{output_name}.{output_format}"

        if output_format == "csv":
            df.to_csv(output_file, index=False)
        elif output_format == "json":
            df.to_json(output_file, orient="records", indent=2)

        return {
            "success": True,
            "urls_scraped": len(urls) - len(errors),
            "urls_failed": len(errors),
            "rows_extracted": len(all_data),
            "columns": list(df.columns),
            "output_path": str(output_file.relative_to(self.workspace_path)),
            "errors": errors,
        }

    async def crawl_site(
        self,
        start_url: str,
        max_pages: int = 10,
        url_pattern: Optional[str] = None,
        selectors: Optional[Dict[str, str]] = None,
        agent_type: str = "basic",
        config: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Crawl a website following links."""
        visited = set()
        to_visit = [start_url]
        all_data = []
        parsed_start = urlparse(start_url)
        base_domain = parsed_start.netloc

        while to_visit and len(visited) < max_pages:
            url = to_visit.pop(0)
            if url in visited:
                continue

            try:
                result = await self.scrape_url(url, agent_type, config)
                visited.add(url)

                # Extract data if selectors provided
                if selectors:
                    data = await self.extract_data(result["html"], selectors)
                    for item in data:
                        item["_source_url"] = url
                    all_data.extend(data)

                # Find more links
                links = await self.extract_links(result["html"], url, url_pattern)
                for link in links:
                    link_url = link["url"]
                    parsed = urlparse(link_url)
                    # Only follow same domain
                    if parsed.netloc == base_domain and link_url not in visited:
                        to_visit.append(link_url)

                await asyncio.sleep(0.5)  # Be nice to servers

            except Exception as e:
                visited.add(url)  # Don't retry

        return {
            "pages_crawled": len(visited),
            "data_extracted": len(all_data),
            "urls_visited": list(visited),
        }


# Global singleton
scraper_service = ScraperService()
