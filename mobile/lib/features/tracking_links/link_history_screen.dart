import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/saved_link.dart';
import '../../data/repositories/link_repository.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/status_badge.dart';
import 'add_link_screen.dart';

class LinkHistoryScreen extends StatefulWidget {
  const LinkHistoryScreen({super.key});

  @override
  State<LinkHistoryScreen> createState() => _LinkHistoryScreenState();
}

class _LinkHistoryScreenState extends State<LinkHistoryScreen> {
  final _linkRepo = LinkRepository();
  final _apiClient = ApiClient();
  List<SavedLink> _links = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    setState(() => _isLoading = true);
    final links = await _linkRepo.getAllLinks();
    setState(() {
      _links = links;
      _isLoading = false;
    });
  }

  Future<void> _handleActivate(SavedLink link) async {
    try {
      await _apiClient.createTrackingSession(
        nickname: link.nickname,
        shareUrl: link.shareUrl,
      );
      final updated = link.copyWith(
        lastKnownStatus: 'active',
        lastActivatedAtUtc: DateTime.now().toUtc(),
      );
      await _linkRepo.updateLink(updated);
      _loadLinks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Activated tracking for "${link.nickname}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to activate: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleDelete(SavedLink link) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Saved Link',
      content: 'Are you sure you want to delete "${link.nickname}"? Any linked geofences will also be removed.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed) {
      await _linkRepo.deleteLink(link.id);
      _loadLinks();
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tracking link copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Tracking Links'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTokens.primary,
        foregroundColor: AppTokens.onPrimary,
        onPressed: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const AddLinkScreen()),
          );
          if (res == true) _loadLinks();
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _links.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.space24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.link_off, size: 64, color: AppTokens.onBackgroundSubtle),
                        const SizedBox(height: AppTokens.space16),
                        const Text('No Saved Links', style: AppTokens.headlineMedium),
                        const SizedBox(height: AppTokens.space8),
                        const Text(
                          'Save past Blackbuck share URLs here to reactivate them quickly for daily trips.',
                          style: AppTokens.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTokens.space24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Tracking Link'),
                          onPressed: () async {
                            final res = await Navigator.of(context).push(
                              MaterialPageRoute(builder: (ctx) => const AddLinkScreen()),
                            );
                            if (res == true) _loadLinks();
                          },
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppTokens.space16),
                  itemCount: _links.length,
                  itemBuilder: (ctx, index) {
                    final link = _links[index];
                    final isExpired = link.tokenExpiryUtc != null &&
                        link.tokenExpiryUtc!.isBefore(DateTime.now().toUtc());

                    return Card(
                      margin: const EdgeInsets.only(bottom: AppTokens.space12),
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
                                    link.nickname,
                                    style: AppTokens.titleMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                StatusBadge(
                                  label: isExpired ? 'Expired' : link.lastKnownStatus,
                                  variant: isExpired
                                      ? BadgeVariant.expired
                                      : (link.lastKnownStatus == 'active'
                                          ? BadgeVariant.active
                                          : BadgeVariant.idle),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTokens.space8),
                            if (link.tokenExpiryUtc != null)
                              Text(
                                'Expires: ${dateFormat.format(link.tokenExpiryUtc!)}',
                                style: AppTokens.bodySmall,
                              ),
                            const SizedBox(height: AppTokens.space16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  tooltip: 'Copy link',
                                  onPressed: () => _copyToClipboard(link.shareUrl),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  tooltip: 'Edit',
                                  onPressed: () async {
                                    final res = await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (c) => AddLinkScreen(existingLink: link),
                                      ),
                                    );
                                    if (res == true) _loadLinks();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: AppTokens.error),
                                  tooltip: 'Delete',
                                  onPressed: () => _handleDelete(link),
                                ),
                                const SizedBox(width: AppTokens.space8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(90, 36),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  onPressed: isExpired ? null : () => _handleActivate(link),
                                  child: const Text('Activate'),
                                ),
                              ],
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
