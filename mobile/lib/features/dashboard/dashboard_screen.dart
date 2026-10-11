import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/local_geofence.dart';
import '../../data/models/saved_link.dart';
import '../../data/repositories/geofence_repository.dart';
import '../../data/repositories/link_repository.dart';
import '../../shared/widgets/status_badge.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../geofences/add_geofence_screen.dart';
import '../geofences/geofence_list_screen.dart';
import '../settings/settings_screen.dart';
import '../tracking_links/add_link_screen.dart';
import '../tracking_links/link_history_screen.dart';

enum BackendStatus { online, waking, offline }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _apiClient = ApiClient();
  final _linkRepo = LinkRepository();
  final _geofenceRepo = GeofenceRepository();

  BackendStatus _backendStatus = BackendStatus.offline;
  bool _isWaking = false;
  int _wakeTimerSeconds = 0;
  Timer? _wakeTimer;
  Timer? _refreshTimer;

  SavedLink? _activeLink;
  Map<String, dynamic>? _activeBackendSession;
  Map<String, dynamic>? _latestPosition;
  List<LocalGeofence> _geofences = [];

  @override
  void initState() {
    super.initState();
    _initialLoad();
    // Periodic dashboard telemetry refresh every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollTelemetry());
  }

  @override
  void dispose() {
    _wakeTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    await _checkBackendHealth();
    await _loadActiveLinkAndGeofences();
    await _pollTelemetry();
  }

  Future<void> _checkBackendHealth() async {
    final online = await _apiClient.checkHealth();
    setState(() {
      _backendStatus = online ? BackendStatus.online : BackendStatus.offline;
    });
  }

  Future<void> _loadActiveLinkAndGeofences() async {
    final links = await _linkRepo.getAllLinks();
    final active = links.cast<SavedLink?>().firstWhere(
      (l) => l?.lastKnownStatus == 'active',
      orElse: () => links.isNotEmpty ? links.first : null,
    );
    final fences = await _geofenceRepo.getAllGeofences();

    setState(() {
      _activeLink = active;
      _geofences = fences;
    });
  }

  Future<void> _pollTelemetry() async {
    if (_activeLink == null) return;
    try {
      final sessions = await _apiClient.listTrackingSessions();
      if (sessions.isNotEmpty) {
        final current = sessions.first;
        setState(() => _activeBackendSession = current);

        final pos = await _apiClient.getLatestPosition(current['id']);
        if (pos != null) {
          setState(() => _latestPosition = pos);
        }
      }
    } catch (_) {}
  }

  Future<void> _wakeBackend() async {
    if (_isWaking) return;
    setState(() {
      _isWaking = true;
      _backendStatus = BackendStatus.waking;
      _wakeTimerSeconds = 0;
    });

    _wakeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _wakeTimerSeconds++);
    });

    int attempts = 0;
    const maxAttempts = 12; // 60 seconds bounded retry
    bool resolved = false;

    while (attempts < maxAttempts && !resolved) {
      attempts++;
      final ready = await _apiClient.checkReadiness();
      if (ready != null && ready['status'] == 'ready') {
        resolved = true;
        break;
      }
      await Future.delayed(const Duration(seconds: 5));
    }

    _wakeTimer?.cancel();
    setState(() {
      _isWaking = false;
      _backendStatus = resolved ? BackendStatus.online : BackendStatus.offline;
    });

    if (resolved) {
      await _pollTelemetry();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backend service is online and ready.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backend wake-up timed out. Please retry.')),
        );
      }
    }
  }

  Future<void> _toggleTrackingState() async {
    if (_activeBackendSession == null) return;
    final sessionId = _activeBackendSession!['id'];
    final isPaused = _activeBackendSession!['status'] == 'paused';

    if (isPaused) {
      await _apiClient.activateSession(sessionId);
    } else {
      await _apiClient.pauseSession(sessionId);
    }
    await _pollTelemetry();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('HH:mm:ss UTC');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Alarm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Saved Links',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LinkHistoryScreen()),
              );
              _initialLoad();
            },
          ),
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            tooltip: 'Bus Stops',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GeofenceListScreen()),
              );
              _initialLoad();
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Diagnostics',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _initialLoad,
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.space16),
          children: [
            // 1. Backend Service Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.space16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Backend Service', style: AppTokens.bodySmall),
                        const SizedBox(height: AppTokens.space4),
                        StatusBadge(
                          label: _isWaking
                              ? 'Waking (${_wakeTimerSeconds}s)'
                              : (_backendStatus == BackendStatus.online ? 'Online' : 'Sleeping / Offline'),
                          variant: _isWaking
                              ? BadgeVariant.waking
                              : (_backendStatus == BackendStatus.online
                                  ? BadgeVariant.online
                                  : BadgeVariant.offline),
                        ),
                      ],
                    ),
                    if (_backendStatus != BackendStatus.online || _isWaking)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(120, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: _isWaking ? null : _wakeBackend,
                        child: _isWaking
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTokens.onPrimary),
                              )
                            : const Text('Wake Backend'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTokens.space12),

            // 2. Active Tracking Route Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _activeLink?.nickname ?? 'No Active Tracking Link',
                            style: AppTokens.headlineMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_activeBackendSession != null)
                          StatusBadge(
                            label: _activeBackendSession!['status'],
                            variant: _activeBackendSession!['status'] == 'active'
                                ? BadgeVariant.active
                                : BadgeVariant.idle,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space8),
                    if (_activeLink?.tokenExpiryUtc != null)
                      Text(
                        'Estimated Expiry: ${DateFormat('dd MMM, HH:mm').format(_activeLink!.tokenExpiryUtc!)}',
                        style: AppTokens.bodySmall,
                      ),
                    const SizedBox(height: AppTokens.space16),
                    Row(
                      children: [
                        if (_activeBackendSession != null)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _toggleTrackingState,
                              child: Text(
                                _activeBackendSession!['status'] == 'paused'
                                    ? 'Resume Tracking'
                                    : 'Pause Tracking',
                              ),
                            ),
                          ),
                        if (_activeBackendSession != null) const SizedBox(width: AppTokens.space8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final res = await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const AddLinkScreen()),
                              );
                              if (res == true) _initialLoad();
                            },
                            child: const Text('Update Link'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTokens.space12),

            // 3. Live Bus Position & Freshness
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Vehicle Telemetry', style: AppTokens.titleMedium),
                        if (_latestPosition != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (_latestPosition!['freshness_seconds'] as int) > 60
                                  ? AppTokens.warning.withValues(alpha: 0.2)
                                  : AppTokens.success.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                            ),
                            child: Text(
                              (_latestPosition!['freshness_seconds'] as int) > 60
                                  ? 'STALE (${_latestPosition!['freshness_seconds']}s old)'
                                  : 'LIVE (${_latestPosition!['freshness_seconds']}s ago)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: (_latestPosition!['freshness_seconds'] as int) > 60
                                    ? AppTokens.warning
                                    : AppTokens.success,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space12),
                    if (_latestPosition != null) ...[
                      Text(
                        'Coordinates: ${_latestPosition!['latitude']}, ${_latestPosition!['longitude']}',
                        style: AppTokens.bodyMedium,
                      ),
                      const SizedBox(height: AppTokens.space4),
                      Text(
                        'Speed: ${_latestPosition!['speed_mps'] ?? 0.0} m/s | Observed: ${dateFormat.format(DateTime.parse(_latestPosition!['observed_at']))}',
                        style: AppTokens.bodySmall,
                      ),
                    ] else
                      const Text(
                        'Waiting for incoming location updates from provider adapter.',
                        style: AppTokens.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTokens.space12),

            // 4. Configured Stops Overview
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Active Bus Stops', style: AppTokens.titleMedium),
                        Text('${_geofences.where((f) => f.enabled).length} enabled', style: AppTokens.bodySmall),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space12),
                    if (_geofences.isEmpty)
                      const Text(
                        'No geofence stops added yet. Add stops to trigger proximity alerts.',
                        style: AppTokens.bodySmall,
                      )
                    else
                      ..._geofences.take(3).map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(bottom: AppTokens.space8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(f.name, style: AppTokens.bodyMedium),
                                  Text('Radius ${f.radiusMeters}m', style: AppTokens.bodySmall),
                                ],
                              ),
                            ),
                          ),
                    const SizedBox(height: AppTokens.space12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Add Stop Geofence'),
                      onPressed: () async {
                        final res = await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddGeofenceScreen()),
                        );
                        if (res == true) _initialLoad();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

