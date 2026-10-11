import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health_liveness(client: AsyncClient):
    """Liveness probe must return 200 OK immediately with version info."""
    response = await client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "version" in data
    assert "service" in data
    assert "X-Request-ID" in response.headers


@pytest.mark.asyncio
async def test_health_readiness(client: AsyncClient):
    """Readiness probe must verify DB connectivity and return 200 OK."""
    response = await client.get("/health/ready")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ready"
    assert data["database"] == "connected"
    assert "timestamp" in data


@pytest.mark.asyncio
async def test_system_status(client: AsyncClient):
    """Status probe must return operational stats."""
    response = await client.get("/api/v1/status")
    assert response.status_code == 200
    data = response.json()
    assert data["backend_status"] == "online"
    assert "active_sessions_count" in data

