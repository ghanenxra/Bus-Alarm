import math
from dataclasses import dataclass
from typing import Optional, Tuple

EARTH_RADIUS_METERS = 6_371_000.0


def haversine_distance_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate great-circle distance between two GPS coordinates using Haversine formula."""
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(delta_phi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * (math.sin(delta_lambda / 2.0) ** 2)
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return EARTH_RADIUS_METERS * c


def project_to_local_meters(
    lat: float, lon: float, origin_lat: float, origin_lon: float
) -> Tuple[float, float]:
    """Project GPS coordinates to local Cartesian metric plane (x=East, y=North) centered at origin."""
    phi_origin = math.radians(origin_lat)
    x = EARTH_RADIUS_METERS * math.radians(lon - origin_lon) * math.cos(phi_origin)
    y = EARTH_RADIUS_METERS * math.radians(lat - origin_lat)
    return x, y


def min_distance_to_segment_meters(
    seg_a_lat: float,
    seg_a_lon: float,
    seg_b_lat: float,
    seg_b_lon: float,
    target_lat: float,
    target_lon: float,
) -> Tuple[float, float]:
    """
    Calculate minimum distance in meters from target coordinate to segment A-B.
    Returns (min_distance_meters, projected_t_parameter in [0, 1]).
    """
    # Project all points to local metric plane centered at target (0,0)
    ax, ay = project_to_local_meters(seg_a_lat, seg_a_lon, target_lat, target_lon)
    bx, by = project_to_local_meters(seg_b_lat, seg_b_lon, target_lat, target_lon)

    vx = bx - ax
    vy = by - ay
    seg_len_sq = vx * vx + vy * vy

    if seg_len_sq < 1e-6:
        # Segment is degenerate (bus stationary)
        dist = math.sqrt(ax * ax + ay * ay)
        return dist, 0.0

    # Vector from A to Target(0,0) is (-ax, -ay)
    # t = (u dot v) / |v|^2
    t = (-ax * vx - ay * vy) / seg_len_sq
    t_clamped = max(0.0, min(1.0, t))

    # Closest point on segment
    px = ax + t_clamped * vx
    py = ay + t_clamped * vy

    min_dist = math.sqrt(px * px + py * py)
    return min_dist, t_clamped


@dataclass
class GeofenceEvaluationResult:
    is_triggered: bool
    trigger_type: Optional[str] = None  # 'crossing', 'enter', 'approaching'
    distance_meters: float = 0.0
    reason: str = ""


def evaluate_crossing(
    prev_lat: Optional[float],
    prev_lon: Optional[float],
    curr_lat: float,
    curr_lon: float,
    fence_lat: float,
    fence_lon: float,
    radius_meters: float,
    uncertainty_margin_meters: float = 20.0,
) -> GeofenceEvaluationResult:
    """
    Evaluate whether a bus entered or crossed a geofence between consecutive observations.
    Detects pass-through even when both samples A and B fall outside the circle.
    """
    effective_radius = radius_meters + uncertainty_margin_meters
    curr_dist = haversine_distance_meters(curr_lat, curr_lon, fence_lat, fence_lon)

    # Case 1: Latest point is directly inside the circle
    if curr_dist <= effective_radius:
        return GeofenceEvaluationResult(
            is_triggered=True,
            trigger_type="enter",
            distance_meters=curr_dist,
            reason=f"Current position is inside geofence (dist: {curr_dist:.1f}m <= {effective_radius:.1f}m)",
        )

    # Case 2: Segment crossing between prior position and current position
    if prev_lat is not None and prev_lon is not None:
        min_dist, _ = min_distance_to_segment_meters(
            prev_lat, prev_lon, curr_lat, curr_lon, fence_lat, fence_lon
        )
        if min_dist <= effective_radius:
            return GeofenceEvaluationResult(
                is_triggered=True,
                trigger_type="crossing",
                distance_meters=min_dist,
                reason=f"Bus trajectory segment crossed geofence (min dist: {min_dist:.1f}m <= {effective_radius:.1f}m)",
            )

    return GeofenceEvaluationResult(
        is_triggered=False,
        distance_meters=curr_dist,
        reason=f"Outside geofence (dist: {curr_dist:.1f}m > {effective_radius:.1f}m)",
    )

