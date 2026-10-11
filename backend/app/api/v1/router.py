from fastapi import APIRouter
from app.api.v1.endpoints import alerts, devices, geofences, health, sessions

api_router = APIRouter()

api_router.include_router(health.router)
api_router.include_router(devices.router)
api_router.include_router(sessions.router)
api_router.include_router(geofences.router)
api_router.include_router(alerts.router)

