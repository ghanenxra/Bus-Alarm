import pytest
from app.services.geo import (
    haversine_distance_meters,
    min_distance_to_segment_meters,
    evaluate_crossing,
)


def test_haversine_known_distance():
    # 1 degree latitude difference along equator is approximately 111,195 meters
    dist = haversine_distance_meters(0.0, 0.0, 1.0, 0.0)
    assert 111_000 < dist < 111_500

    # Same point distance is 0.0
    assert haversine_distance_meters(25.18, 75.83, 25.18, 75.83) == 0.0


def test_segment_crossing_both_samples_outside():
    """
    Critical requirement: Fast moving bus where consecutive polls A and B
    are both OUTSIDE the geofence radius, but the trajectory passes directly through.
    """
    fence_lat = 25.0000
    fence_lon = 75.0000
    radius = 150.0  # 150 meters

    # Sample A is 350m West
    a_lat = 25.0000
    a_lon = 74.9965
    dist_a = haversine_distance_meters(a_lat, a_lon, fence_lat, fence_lon)
    assert dist_a > 300.0  # Outside radius

    # Sample B is 350m East
    b_lat = 25.0000
    b_lon = 75.0035
    dist_b = haversine_distance_meters(b_lat, b_lon, fence_lat, fence_lon)
    assert dist_b > 300.0  # Outside radius

    # Evaluate crossing
    result = evaluate_crossing(
        prev_lat=a_lat,
        prev_lon=a_lon,
        curr_lat=b_lat,
        curr_lon=b_lon,
        fence_lat=fence_lat,
        fence_lon=fence_lon,
        radius_meters=radius,
        uncertainty_margin_meters=20.0,
    )

    assert result.is_triggered is True
    assert result.trigger_type == "crossing"
    assert result.distance_meters < 5.0  # Crosses right through center


def test_point_directly_inside_radius():
    fence_lat = 25.1800
    fence_lon = 75.8300
    radius = 200.0

    # Point 50 meters away
    inside_lat = 25.1804
    inside_lon = 75.8300
    dist = haversine_distance_meters(inside_lat, inside_lon, fence_lat, fence_lon)
    assert dist < radius

    result = evaluate_crossing(
        prev_lat=None,
        prev_lon=None,
        curr_lat=inside_lat,
        curr_lon=inside_lon,
        fence_lat=fence_lat,
        fence_lon=fence_lon,
        radius_meters=radius,
    )
    assert result.is_triggered is True
    assert result.trigger_type == "enter"


def test_segment_passing_outside_radius():
    fence_lat = 25.0000
    fence_lon = 75.0000
    radius = 100.0

    # Segment passes 600m to the north
    a_lat = 25.0060
    a_lon = 74.9950
    b_lat = 25.0060
    b_lon = 75.0050

    result = evaluate_crossing(
        prev_lat=a_lat,
        prev_lon=a_lon,
        curr_lat=b_lat,
        curr_lon=b_lon,
        fence_lat=fence_lat,
        fence_lon=fence_lon,
        radius_meters=radius,
    )
    assert result.is_triggered is False
    assert result.distance_meters > 500.0
