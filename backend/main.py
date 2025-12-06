"""
Main FastAPI application entry point.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse

from api import api_v1_router, legacy_api_router
from websocket.handler import router as websocket_router
from core.config import settings
from core.lifespan import lifespan


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.VERSION,
        description="GPU-enabled Notebook API with AI integration",
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Versioned API (recommended)
    app.include_router(api_v1_router)

    # Legacy API (backwards compatibility - will be deprecated)
    app.include_router(legacy_api_router)

    # WebSocket endpoints
    app.include_router(websocket_router, prefix="/ws", tags=["websocket"])

    @app.get("/scalar", include_in_schema=False)
    async def scalar_html():
        return HTMLResponse(
            """
            <!doctype html>
            <html>
            <head>
              <title>API Reference</title>
              <meta charset="utf-8" />
              <meta name="viewport" content="width=device-width, initial-scale=1" />
              <style>
                body {
                  margin: 0;
                }
              </style>
            </head>
            <body>
              <script id="api-reference" data-url="/openapi.json"></script>
              <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
            </body>
            </html>
        """
        )

    return app


app = create_app()
