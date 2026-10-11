import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/local_geofence.dart';
import '../../data/models/saved_link.dart';
import '../../data/repositories/geofence_repository.dart';
import '../../data/repositories/link_repository.dart';

class AddGeofenceScreen extends StatefulWidget {
  final LocalGeofence? existingFence;

  const AddGeofenceScreen({super.key, this.existingFence});

  @override
  State<AddGeofenceScreen> createState() => _AddGeofenceScreenState();
}

class _AddGeofenceScreenState extends State<AddGeofenceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _geofenceRepo = GeofenceRepository();
  final _linkRepo = LinkRepository();
  final _apiClient = ApiClient();

  List<SavedLink> _availableLinks = [];
  SavedLink? _selectedLink;
  double _radiusMeters = 200.0;
  int _cooldownSeconds = 900;
  LatLng _selectedPoint = const LatLng(25.1800, 75.8300);
  final MapController _mapController = MapController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAvailableLinks();
    if (widget.existingFence != null) {
      final f = widget.existingFence!;
      _nameController.text = f.name;
      _latController.text = f.latitude.toString();
      _lonController.text = f.longitude.toString();
      _radiusMeters = f.radiusMeters.toDouble();
      _cooldownSeconds = f.cooldownSeconds;
      _selectedPoint = LatLng(f.latitude, f.longitude);
    } else {
      _latController.text = _selectedPoint.latitude.toString();
      _lonController.text = _selectedPoint.longitude.toString();
    }
  }

  Future<void> _loadAvailableLinks() async {
    final links = await _linkRepo.getAllLinks();
    setState(() {
      _availableLinks = links;
      if (links.isNotEmpty) {
        if (widget.existingFence != null) {
          _selectedLink = links.firstWhere(
            (l) => l.id == widget.existingFence!.linkedSavedLinkId,
            orElse: () => links.first,
          );
        } else {
          _selectedLink = links.first;
        }
      }
    });
  }

  void _onMapTapped(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedPoint = point;
      _latController.text = point.latitude.toStringAsFixed(6);
      _lonController.text = point.longitude.toStringAsFixed(6);
    });
  }

  void _onCoordinateFieldsChanged() {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());
    if (lat != null && lon != null && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
      setState(() {
        _selectedPoint = LatLng(lat, lon);
      });
      _mapController.move(_selectedPoint, _mapController.camera.zoom);
    }
  }

  void _showLinkPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radiusMedium)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(AppTokens.space16),
                child: Text('Select Route Link', style: AppTokens.titleMedium),
              ),
              const Divider(height: 1, color: AppTokens.surfaceBorder),
              ..._availableLinks.map((link) {
                final isSelected = _selectedLink?.id == link.id;
                return ListTile(
                  title: Text(link.nickname, style: AppTokens.bodyMedium),
                  trailing: isSelected ? const Icon(Icons.check, color: AppTokens.primary) : null,
                  onTap: () {
                    setState(() => _selectedLink = link);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLink == null) {
      setState(() => _errorMessage = 'Please save at least one tracking route link first');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final now = DateTime.now().toUtc();
    final fenceId = widget.existingFence?.id ?? const Uuid().v4();
    final name = _nameController.text.trim();
    final lat = double.parse(_latController.text.trim());
    final lon = double.parse(_lonController.text.trim());

    final fence = LocalGeofence(
      id: fenceId,
      name: name,
      latitude: lat,
      longitude: lon,
      radiusMeters: _radiusMeters.toInt(),
      linkedSavedLinkId: _selectedLink!.id,
      cooldownSeconds: _cooldownSeconds,
      createdAtUtc: widget.existingFence?.createdAtUtc ?? now,
      updatedAtUtc: now,
    );

    try {
      await _geofenceRepo.insertGeofence(fence);

      // Best effort sync with backend
      try {
        await _apiClient.createGeofence(
          sessionId: _selectedLink!.id,
          name: name,
          latitude: lat,
          longitude: lon,
          radiusMeters: _radiusMeters.toInt(),
          cooldownSeconds: _cooldownSeconds,
        );
      } catch (_) {
        // Backend offline sync error will resolve on reconnection
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save geofence: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingFence == null ? 'Add Bus Stop' : 'Edit Stop'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(AppTokens.space12),
                  margin: const EdgeInsets.only(bottom: AppTokens.space16),
                  decoration: BoxDecoration(
                    color: AppTokens.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                    border: Border.all(color: AppTokens.error),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppTokens.error, fontSize: 13.0)),
                ),

              // Stop Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Stop Name',
                  hintText: 'e.g. Main Campus Gate, Hostel Roundabout',
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Stop name is required' : null,
              ),
              const SizedBox(height: AppTokens.space16),

              // Linked Route Selector (Non-native custom selector)
              InkWell(
                onTap: _availableLinks.isNotEmpty ? _showLinkPicker : null,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Linked Bus Route',
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    _selectedLink?.nickname ?? 'No routes saved yet',
                    style: TextStyle(
                      color: _selectedLink != null ? AppTokens.onBackground : AppTokens.onBackgroundSubtle,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.space16),

              // Map Pin Placement
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(AppTokens.space12),
                      child: Text('Tap Map to Set Stop Location', style: AppTokens.titleMedium),
                    ),
                    SizedBox(
                      height: 220,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _selectedPoint,
                            initialZoom: 15.0,
                            onTap: _onMapTapped,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.busalarm.app',
                            ),
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: _selectedPoint,
                                  color: AppTokens.primary.withOpacity(0.25),
                                  borderColor: AppTokens.primary,
                                  borderStrokeWidth: 2.0,
                                  radius: _radiusMeters,
                                  useRadiusInMeter: true,
                                ),
                              ],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _selectedPoint,
                                  width: 32,
                                  height: 32,
                                  child: const Icon(Icons.location_pin, color: AppTokens.error, size: 32),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space16),

              // Manual Coordinates
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _onCoordinateFieldsChanged(),
                    ),
                  ),
                  const SizedBox(width: AppTokens.space12),
                  Expanded(
                    child: TextFormField(
                      controller: _lonController,
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _onCoordinateFieldsChanged(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space16),

              // Radius Slider
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Geofence Radius', style: AppTokens.titleMedium),
                          Text(
                            '${_radiusMeters.toInt()} meters',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppTokens.primary),
                          ),
                        ],
                      ),
                      Slider(
                        value: _radiusMeters,
                        min: 30.0,
                        max: 1000.0,
                        divisions: 97,
                        activeColor: AppTokens.primary,
                        onChanged: (val) => setState(() => _radiusMeters = val),
                      ),
                      if (_radiusMeters < 100)
                        const Padding(
                          padding: EdgeInsets.only(top: AppTokens.space4),
                          child: Text(
                            'Notice: Small radii (<100m) may require frequent GPS updates to trigger reliably.',
                            style: TextStyle(color: AppTokens.warning, fontSize: 12.0),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.space24),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTokens.onPrimary),
                      )
                    : const Text('Save Stop Geofence'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

