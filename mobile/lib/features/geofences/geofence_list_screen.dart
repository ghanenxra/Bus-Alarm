import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/local_geofence.dart';
import '../../data/repositories/geofence_repository.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import 'add_geofence_screen.dart';

class GeofenceListScreen extends StatefulWidget {
  const GeofenceListScreen({super.key});

  @override
  State<GeofenceListScreen> createState() => _GeofenceListScreenState();
}

class _GeofenceListScreenState extends State<GeofenceListScreen> {
  final _geofenceRepo = GeofenceRepository();
  List<LocalGeofence> _fences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFences();
  }

  Future<void> _loadFences() async {
    setState(() => _isLoading = true);
    final list = await _geofenceRepo.getAllGeofences();
    setState(() {
      _fences = list;
      _isLoading = false;
    });
  }

  Future<void> _toggleEnable(LocalGeofence fence) async {
    final updated = fence.copyWith(enabled: !fence.enabled);
    await _geofenceRepo.updateGeofence(updated);
    _loadFences();
  }

  Future<void> _deleteFence(LocalGeofence fence) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Bus Stop',
      content: 'Are you sure you want to delete stop "${fence.name}"?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed) {
      await _geofenceRepo.deleteGeofence(fence.id);
      _loadFences();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Bus Stops'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTokens.primary,
        foregroundColor: AppTokens.onPrimary,
        onPressed: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const AddGeofenceScreen()),
          );
          if (res == true) _loadFences();
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fences.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.space24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_off_outlined, size: 64, color: AppTokens.onBackgroundSubtle),
                        const SizedBox(height: AppTokens.space16),
                        const Text('No Stops Configured', style: AppTokens.headlineMedium),
                        const SizedBox(height: AppTokens.space8),
                        const Text(
                          'Add your bus stops on the map to trigger alarms when your bus approaches.',
                          style: AppTokens.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTokens.space24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_location_alt),
                          label: const Text('Add Bus Stop'),
                          onPressed: () async {
                            final res = await Navigator.of(context).push(
                              MaterialPageRoute(builder: (ctx) => const AddGeofenceScreen()),
                            );
                            if (res == true) _loadFences();
                          },
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppTokens.space16),
                  itemCount: _fences.length,
                  itemBuilder: (ctx, index) {
                    final fence = _fences[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppTokens.space12),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTokens.space16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_pin,
                              color: fence.enabled ? AppTokens.primary : AppTokens.onBackgroundSubtle,
                              size: 28,
                            ),
                            const SizedBox(width: AppTokens.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(fence.name, style: AppTokens.titleMedium),
                                  const SizedBox(height: AppTokens.space4),
                                  Text(
                                    'Radius: ${fence.radiusMeters}m | Cooldown: ${fence.cooldownSeconds ~/ 60}m',
                                    style: AppTokens.bodySmall,
                                  ),
                                  Text(
                                    'Lat: ${fence.latitude.toStringAsFixed(4)}, Lon: ${fence.longitude.toStringAsFixed(4)}',
                                    style: AppTokens.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: fence.enabled,
                              activeThumbColor: AppTokens.primary,
                              onChanged: (_) => _toggleEnable(fence),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTokens.error, size: 20),
                              tooltip: 'Delete',
                              onPressed: () => _deleteFence(fence),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

