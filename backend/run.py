#!/usr/bin/env python3
"""
Development server runner.
"""
import uvicorn
from core.config import settings

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=True,
        log_level="debug" if settings.DEBUG else "info",
    )
