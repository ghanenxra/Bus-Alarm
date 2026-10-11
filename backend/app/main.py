import time
import uuid
from contextlib import asynccontextmanager
from typing import AsyncGenerator
from fastapi import FastAPI, HTTPException, Request, Response, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.core.config import settings
from app.core.logging import logger
from app.db.session import engine
from app.db.models import Base
from app.api.v1.endpoints.health import router as health_router
from app.api.v1.router import api_router


from app.workers.poller import TrackingPoller


from app.services.geofence_service import GeofenceService


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Startup and shutdown lifecycle."""
    logger.info("Initializing application...")
    # Create tables if not already present (especially for dev/SQLite)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("Database initialized successfully.")

    # Start poller worker with geofence evaluation hook and FCM dispatcher
    from app.services.fcm_service import FCMService
    fcm_service = FCMService()
    geofence_service = GeofenceService(push_dispatcher=fcm_service)
    poller = TrackingPoller(position_callback=geofence_service.evaluate_session_position)
    app.state.fcm_service = fcm_service
    app.state.poller = poller
    app.state.geofence_service = geofence_service
    poller.start()
    
    yield

    # Clean shutdown
    logger.info("Stopping background poller...")
    await poller.stop()
    logger.info("Shutting down application engine...")
    await engine.dispose()
    logger.info("Application shutdown complete.")


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def request_id_and_logging_middleware(request: Request, call_next) -> Response:
    """Assign X-Request-ID and log request with execution duration."""
    req_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
    request.state.request_id = req_id
    start_time = time.time()
    
    response: Response = await call_next(request)
    
    process_time = (time.time() - start_time) * 1000
    response.headers["X-Request-ID"] = req_id
    logger.info(
        f"{request.method} {request.url.path} status={response.status_code} "
        f"duration={process_time:.2f}ms req_id={req_id}"
    )
    return response


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    req_id = getattr(request.state, "request_id", str(uuid.uuid4()))
    code_map = {
        400: "BAD_REQUEST",
        401: "UNAUTHORIZED",
        403: "FORBIDDEN",
        404: "NOT_FOUND",
        409: "CONFLICT",
        422: "VALIDATION_ERROR",
        429: "RATE_LIMITED",
        502: "PROVIDER_ERROR",
        503: "SERVICE_UNAVAILABLE",
    }
    error_code = code_map.get(exc.status_code, "ERROR")
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "code": error_code,
                "message": exc.detail,
                "request_id": req_id,
            }
        },
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    req_id = getattr(request.state, "request_id", str(uuid.uuid4()))
    return JSONResponse(
        status_code=422,
        content={
            "error": {
                "code": "VALIDATION_ERROR",
                "message": "Malformed request parameters",
                "details": exc.errors(),
                "request_id": req_id,
            }
        },
    )


# Root level health routes for Render probes
app.include_router(health_router)

# Versioned API routes
app.include_router(api_router, prefix=settings.API_V1_PREFIX)
