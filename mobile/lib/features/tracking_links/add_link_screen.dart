import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/jwt_decoder.dart';
import '../../data/models/saved_link.dart';
import '../../data/repositories/link_repository.dart';

class AddLinkScreen extends StatefulWidget {
  final SavedLink? existingLink;

  const AddLinkScreen({super.key, this.existingLink});

  @override
  State<AddLinkScreen> createState() => _AddLinkScreenState();
}

class _AddLinkScreenState extends State<AddLinkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _linkRepo = LinkRepository();
  final _apiClient = ApiClient();

  DateTime? _estimatedExpiry;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.existingLink != null) {
      _urlController.text = widget.existingLink!.shareUrl;
      _nicknameController.text = widget.existingLink!.nickname;
      _estimatedExpiry = widget.existingLink!.tokenExpiryUtc;
    }
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      setState(() => _estimatedExpiry = null);
      return;
    }

    try {
      final uri = Uri.parse(text);
      final token = uri.queryParameters['token'] ?? (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null);
      if (token != null) {
        final expiry = JwtDecoder.getExpiryDate(token);
        setState(() => _estimatedExpiry = expiry);
      }
    } catch (_) {
      setState(() => _estimatedExpiry = null);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      _urlController.text = data.text!.trim();
    }
  }

  Future<void> _handleSave({bool activateImmediately = true}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final now = DateTime.now().toUtc();
    final linkId = widget.existingLink?.id ?? const Uuid().v4();
    final url = _urlController.text.trim();
    final nickname = _nicknameController.text.trim();

    final link = SavedLink(
      id: linkId,
      nickname: nickname,
      shareUrl: url,
      tokenExpiryUtc: _estimatedExpiry,
      addedAtUtc: widget.existingLink?.addedAtUtc ?? now,
      updatedAtUtc: now,
      isFavorite: widget.existingLink?.isFavorite ?? false,
      lastKnownStatus: activateImmediately ? 'active' : 'unknown',
      lastActivatedAtUtc: activateImmediately ? now : null,
    );

    try {
      // 1. Save locally in SQLite
      await _linkRepo.insertLink(link);

      // 2. Sync / activate with backend
      if (activateImmediately) {
        await _apiClient.createTrackingSession(
          nickname: nickname,
          shareUrl: url,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to activate session on backend: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm UTC');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingLink == null ? 'Add Tracking Link' : 'Edit Link'),
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
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTokens.error, fontSize: 13.0),
                  ),
                ),

              // Nickname Field
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  labelText: 'Route Nickname',
                  hintText: 'e.g. Morning College Bus, Return Route',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a route nickname';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTokens.space16),

              // Share URL Field
              TextFormField(
                controller: _urlController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Blackbuck Share URL',
                  hintText: 'https://trackgps.blackbuck.com/location?token=...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste),
                    tooltip: 'Paste from clipboard',
                    onPressed: _pasteFromClipboard,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Tracking link is required';
                  }
                  if (!val.trim().toLowerCase().startsWith('https://')) {
                    return 'URL must use secure HTTPS protocol';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTokens.space16),

              // Token Expiry Preview Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Token Expiration Status',
                        style: AppTokens.titleMedium,
                      ),
                      const SizedBox(height: AppTokens.space8),
                      Text(
                        _estimatedExpiry != null
                            ? 'Estimated Expiry: ${dateFormat.format(_estimatedExpiry!)}'
                            : 'Paste a valid tracking URL to extract token expiry preview.',
                        style: AppTokens.bodySmall,
                      ),
                      if (_estimatedExpiry != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppTokens.space4),
                          child: Text(
                            _estimatedExpiry!.isBefore(DateTime.now().toUtc())
                                ? 'WARNING: This tracking token has expired.'
                                : 'Token valid for approx ${_estimatedExpiry!.difference(DateTime.now().toUtc()).inHours} hours.',
                            style: TextStyle(
                              color: _estimatedExpiry!.isBefore(DateTime.now().toUtc())
                                  ? AppTokens.error
                                  : AppTokens.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.0,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.space24),

              // Save Actions
              ElevatedButton(
                onPressed: _isLoading ? null : () => _handleSave(activateImmediately: true),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.0, color: AppTokens.onPrimary),
                      )
                    : const Text('Save and Activate Tracking'),
              ),
              const SizedBox(height: AppTokens.space12),
              OutlinedButton(
                onPressed: _isLoading ? null : () => _handleSave(activateImmediately: false),
                child: const Text('Save to History Only'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
