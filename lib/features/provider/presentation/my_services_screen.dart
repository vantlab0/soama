import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/service_provider.dart';
import '../../../../shared/models/user_account.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../providers/presentation/providers/provider_provider.dart';

import '../../storage/presentation/providers/storage_provider.dart';
import '../../storage/presentation/widgets/image_picker_sheet.dart';

class MyServicesScreen extends ConsumerStatefulWidget {
  const MyServicesScreen({super.key});

  @override
  ConsumerState<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends ConsumerState<MyServicesScreen> {
  String get _providerId => UserAccount.current.id;

  void _openAddServiceDialog(BuildContext context, {ProviderServiceOffering? existing, int? index}) {
    final colors = context.soamaColors;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(text: existing?.priceAmount.toString() ?? '');
    final durationCtrl = TextEditingController(text: existing?.duration ?? '1-2 hrs');

    String? currentImageUrl = existing?.imageUrl;
    bool isUploadingImage = false;
    String? imageUploadError;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colors.surface,
          shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusXl),
          title: Text(
            existing != null ? 'Edit Service Listing' : 'Add New Service',
            style: SoamaTypography.titleMedium.copyWith(color: colors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Photo Section
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: isUploadingImage
                            ? null
                            : () async {
                                final payload = await ImagePickerSheet.show(
                                  context,
                                  title: 'Select Service Photo',
                                  hasExistingImage: currentImageUrl != null,
                                  onRemove: () {
                                    setDialogState(() {
                                      currentImageUrl = null;
                                      imageUploadError = null;
                                    });
                                  },
                                );
                                if (payload != null) {
                                  setDialogState(() {
                                    isUploadingImage = true;
                                    imageUploadError = null;
                                  });
                                  try {
                                    final repo = ref.read(storageRepositoryProvider);
                                    final serviceId = existing?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
                                    final url = await repo.uploadServiceImage(
                                      providerId: _providerId,
                                      serviceId: serviceId,
                                      bytes: payload.bytes,
                                      fileName: payload.fileName,
                                    );
                                    setDialogState(() {
                                      currentImageUrl = url;
                                      isUploadingImage = false;
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      isUploadingImage = false;
                                      imageUploadError = e.toString().replaceAll('Exception:', '').trim();
                                    });
                                  }
                                }
                              },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: colors.surfaceSubtle,
                                borderRadius: SoamaRadii.radiusLg,
                                border: Border.all(color: colors.glassBorder, width: 1.2),
                              ),
                              child: ClipRRect(
                                borderRadius: SoamaRadii.radiusLg,
                                child: currentImageUrl != null
                                    ? Image.network(
                                        currentImageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Icon(Icons.broken_image_rounded, color: colors.textTertiary),
                                        ),
                                      )
                                    : Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_a_photo_outlined, size: 24, color: colors.accent),
                                            const SizedBox(height: 4),
                                            Text('Add Photo', style: TextStyle(fontSize: 10, color: colors.textTertiary)),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                            if (isUploadingImage)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: SoamaRadii.radiusLg,
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (imageUploadError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          imageUploadError!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Service Title (e.g. Inverter Installation)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Service Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Base Price (₦)', prefixText: '₦ '),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationCtrl,
                  decoration: const InputDecoration(labelText: 'Estimated Duration (e.g. 2-3 hrs)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploadingImage ? null : () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: isUploadingImage
                  ? null
                  : () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      final priceVal = int.tryParse(priceCtrl.text.trim()) ?? 5000;
                      final durationStr = durationCtrl.text.trim().isNotEmpty ? durationCtrl.text.trim() : '1-2 hrs';

                      final notifier = ref.read(providerServicesProvider(_providerId).notifier);
                      if (existing != null) {
                        await notifier.updateService(
                          existing.id,
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          priceAmount: priceVal,
                          duration: durationStr,
                          imageUrl: currentImageUrl,
                        );
                      } else {
                        await notifier.addService(
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          priceAmount: priceVal,
                          duration: durationStr,
                          imageUrl: currentImageUrl,
                        );
                      }

                      if (context.mounted) {
                        Navigator.of(ctx).pop();
                        setState(() {});
                      }
                    },
              child: Text(
                existing != null ? 'Save Changes' : 'Add Service',
                style: TextStyle(
                  color: isUploadingImage ? colors.textTertiary : colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteService(String serviceId, int index, {String? imageUrl}) async {
    HapticFeedback.lightImpact();
    if (imageUrl != null) {
      try {
        final repo = ref.read(storageRepositoryProvider);
        await repo.deleteServiceImage(
          providerId: _providerId,
          serviceId: serviceId,
          currentUrl: imageUrl,
        );
      } catch (_) {}
    }
    await ref.read(providerServicesProvider(_providerId).notifier).deleteService(serviceId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final account = UserAccount.current;
    final servicesAsync = ref.watch(providerServicesProvider(_providerId));
    final services = servicesAsync.valueOrNull ?? account.providerProfile?.services ?? [];

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'My Offered Services',
          style: SoamaTypography.titleMedium.copyWith(color: colors.textPrimary),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Service'),
        onPressed: () => _openAddServiceDialog(context),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SoamaSpacing.lg),
          children: [
            Text(
              'Manage your service catalog, customize descriptions, and adjust base pricing for clients.',
              style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: SoamaSpacing.md),
            if (services.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: colors.textTertiary),
                      const SizedBox(height: 12),
                      Text('No Services Listed', style: SoamaTypography.titleSmall.copyWith(color: colors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Tap the button below to add your first service offering.', style: SoamaTypography.labelSmall.copyWith(color: colors.textSecondary)),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(services.length, (index) {
                final srv = services[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: SoamaSpacing.md),
                  child: GlassSurface(
                    padding: const EdgeInsets.all(SoamaSpacing.md),
                    borderRadius: SoamaRadii.radiusLg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (srv.imageUrl != null) ...[
                              ClipRRect(
                                borderRadius: SoamaRadii.radiusMd,
                                child: SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: Image.network(
                                    srv.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: colors.surfaceSubtle,
                                      child: Icon(Icons.broken_image_rounded, size: 20, color: colors.textTertiary),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: SoamaSpacing.sm),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          srv.title,
                                          style: SoamaTypography.titleSmall.copyWith(
                                            color: colors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        srv.price,
                                        style: SoamaTypography.titleSmall.copyWith(
                                          color: colors.accent,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Estimated Duration: ${srv.duration}',
                                    style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          srv.description,
                          style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
                        ),
                        const SizedBox(height: SoamaSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _openAddServiceDialog(context, existing: srv, index: index),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit', style: TextStyle(fontSize: 12)),
                            ),
                            TextButton.icon(
                              onPressed: () => _deleteService(srv.id, index, imageUrl: srv.imageUrl),
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                              label: const Text('Remove', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
