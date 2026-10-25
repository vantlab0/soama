import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/service_provider.dart';
import '../../../../shared/models/service_request.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../../../shared/widgets/service_badge.dart';
import '../../../../shared/widgets/soama_buttons.dart';
import '../../requests/presentation/providers/requests_provider.dart';

class RequestServiceScreen extends ConsumerStatefulWidget {
  final ServiceProvider? provider;
  final ProviderServiceOffering? selectedService;

  const RequestServiceScreen({
    super.key,
    this.provider,
    this.selectedService,
  });

  @override
  ConsumerState<RequestServiceScreen> createState() => _RequestServiceScreenState();
}

class _RequestServiceScreenState extends ConsumerState<RequestServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  late ServiceProvider _provider;
  late ProviderServiceOffering _activeService;
  late ServiceDeliveryMode _deliveryMode;

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _locationNoteController = TextEditingController();

  late DateTime _preferredDate;
  late String _preferredTimeSlot;
  final List<String> _attachedPhotos = [];

  bool _isSubmitting = false;
  bool _isSubmittedSuccess = false;
  ServiceRequest? _createdRequest;

  // Inline validation error flags
  String? _descriptionError;
  String? _addressError;

  final List<String> _timeSlotOptions = [
    'Morning (8:00 AM – 12:00 PM)',
    'Afternoon (12:00 PM – 3:00 PM)',
    'Late Afternoon (3:00 PM – 6:00 PM)',
  ];

  @override
  void initState() {
    super.initState();
    _provider = widget.provider ?? ServiceProvider.nearbyPros.first;

    // Pick selected service or fallback to first available or default diagnostic
    if (widget.selectedService != null) {
      _activeService = widget.selectedService!;
    } else if (_provider.services.isNotEmpty) {
      _activeService = _provider.services.first;
    } else {
      _activeService = ProviderServiceOffering(
        id: 'srv-diagnostic',
        title: 'Diagnostic & General Service',
        description: 'Initial physical inspection, troubleshooting, and direct repair quote.',
        price: _provider.startingPrice,
        priceAmount: _provider.startingPriceAmount ?? 8000,
        duration: '1 – 2 hours',
      );
    }

    _deliveryMode = ServiceDeliveryMode.onSiteVisit;
    _preferredDate = DateTime.now().add(const Duration(days: 1));
    _preferredTimeSlot = _timeSlotOptions.first;

    // Default Nigerian local address for seamless testing
    _addressController.text = '14 Airport Road, Effurun, Warri, Delta State';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    _locationNoteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    return _descriptionController.text.trim().isNotEmpty ||
        _attachedPhotos.isNotEmpty ||
        _locationNoteController.text.trim().isNotEmpty;
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges || _isSubmittedSuccess) return true;

    final colors = context.soamaColors;
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusXl),
        title: Text(
          'Discard Request?',
          style: SoamaTypography.titleLarge.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'Your entered service request details and photos will not be saved.',
          style: SoamaTypography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Keep Editing',
              style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  void _showPhotoAttachmentSheet() {
    HapticFeedback.lightImpact();
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    final samplePhotos = [
      {
        'title': 'Pipe Joint Fracture',
        'url': 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=400&q=80',
      },
      {
        'title': 'Circuit Breaker Box',
        'url': 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=400&q=80',
      },
      {
        'title': 'AC Compressor Unit',
        'url': 'https://images.unsplash.com/photo-1581092335397-9583fe92d232?auto=format&fit=crop&w=400&q=80',
      },
      {
        'title': 'Generator Exhaust Head',
        'url': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80',
      },
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13151A) : colors.surface,
            borderRadius: SoamaRadii.sheetTopRadius,
            border: Border.all(color: colors.glassBorder, width: 1.0),
          ),
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textTertiary.withOpacity(0.3),
                    borderRadius: SoamaRadii.radiusPill,
                  ),
                ),
              ),
              const SizedBox(height: SoamaSpacing.md),
              Text(
                'Attach Issue Photo',
                style: SoamaTypography.titleMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Photos help the specialist bring the right spare parts on the first visit.',
                style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: SoamaSpacing.md),
              ...samplePhotos.map((item) {
                final photoUrl = item['url']!;
                final isAlreadyAttached = _attachedPhotos.contains(photoUrl);

                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(
                      borderRadius: SoamaRadii.radiusMd,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Image(
                          image: ResizeImage(NetworkImage(photoUrl), width: 100, height: 100),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    title: Text(
                      item['title']!,
                      style: SoamaTypography.labelLarge.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      isAlreadyAttached ? 'Already attached' : 'Tap to attach to request',
                      style: SoamaTypography.labelSmall.copyWith(
                        color: isAlreadyAttached ? colors.accent : colors.textTertiary,
                      ),
                    ),
                    trailing: isAlreadyAttached
                        ? Icon(Icons.check_circle_rounded, color: colors.accent, size: 20)
                        : Icon(Icons.add_circle_outline_rounded, color: colors.textSecondary, size: 20),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(sheetContext).pop();
                      if (!isAlreadyAttached) {
                        setState(() {
                          _attachedPhotos.add(photoUrl);
                        });
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _removePhoto(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _attachedPhotos.removeAt(index);
    });
  }

  Future<void> _pickCustomDate() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: context.soamaColors.accent,
                  onPrimary: context.soamaColors.onAccent,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _preferredDate = picked;
      });
    }
  }

  Future<void> _submitServiceRequest() async {
    if (_isSubmitting) return;

    // Reset error states
    setState(() {
      _descriptionError = null;
      _addressError = null;
    });

    final desc = _descriptionController.text.trim();
    final addr = _addressController.text.trim();
    bool hasError = false;

    if (desc.isEmpty) {
      setState(() {
        _descriptionError = 'Please describe the problem or work needed.';
      });
      hasError = true;
    } else if (desc.length < 10) {
      setState(() {
        _descriptionError = 'Please provide at least 10 characters describing the issue.';
      });
      hasError = true;
    }

    if (_deliveryMode == ServiceDeliveryMode.onSiteVisit && addr.isEmpty) {
      setState(() {
        _addressError = 'Please enter your address for the on-site visit.';
      });
      hasError = true;
    }

    if (hasError) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete the required fields highlighted in red.'),
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
          backgroundColor: Colors.redAccent.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
      _scrollController.animateTo(
        220,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }

    // Begin Submission Simulation
    HapticFeedback.lightImpact();
    setState(() {
      _isSubmitting = true;
    });

    try {
      final newRequest = await ref.read(requestsRepositoryProvider).createServiceRequest(
        categoryId: _provider.categoryId,
        title: _activeService.title,
        description: desc,
        urgency: 'standard',
        deliveryMode: _deliveryMode,
        locationArea: addr,
        exactAddress: addr,
        preferredDate: _preferredDate,
        budgetAmount: _activeService.priceAmount,
        targetProviderId: _provider.id,
        targetProviderName: _provider.name,
        targetProviderProfession: _provider.profession,
        targetProviderAvatar: _provider.avatarUrl,
        initialMessage: 'Service Request: ${_activeService.title} - $desc',
      );

      // Invalidate customer requests provider to trigger background refresh
      ref.invalidate(customerRequestsProvider);

      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isSubmitting = false;
          _isSubmittedSuccess = true;
          _createdRequest = newRequest;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e. Your details have been preserved.'),
            backgroundColor: Colors.redAccent.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    if (_isSubmittedSuccess && _createdRequest != null) {
      return _buildSuccessScreen(context, _createdRequest!);
    }

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.canvas,
        appBar: AppBar(
          backgroundColor: colors.canvas.withOpacity(0.92),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: colors.textPrimary,
            ),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            'Request Service',
            style: SoamaTypography.titleMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, bottomInset > 0 ? bottomInset + 100 : 110),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Provider Compact Summary
                    _buildProviderSummaryCard(context),

                    const SizedBox(height: SoamaSpacing.lg),

                    // 2. Service Selection Dropdown / Selector
                    _buildServiceSelector(context),

                    const SizedBox(height: SoamaSpacing.lg),

                    // 3. Service Delivery Mode (On-site vs Workshop)
                    _buildDeliveryModeSelector(context),

                    const SizedBox(height: SoamaSpacing.lg),

                    // 4. Problem Description Field with Helpful Example
                    _buildDescriptionField(context),

                    const SizedBox(height: SoamaSpacing.lg),

                    // 5. Photo Attachments Section
                    _buildAttachmentsSection(context),

                    const SizedBox(height: SoamaSpacing.lg),

                    // 6. Service Location & Note
                    _buildLocationSection(context),

                    const SizedBox(height: SoamaSpacing.lg),

                    // 7. Preferred Date & Time Selector
                    _buildDateTimeSection(context),

                    const SizedBox(height: SoamaSpacing.lg),

                    // 8. Pricing & Escrow Transparency Breakdown
                    _buildPricingBreakdown(context),

                    const SizedBox(height: SoamaSpacing.md),
                  ],
                ),
              ),
            ),

            // Persistent Bottom Action Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomBar(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSummaryCard(BuildContext context) {
    final colors = context.soamaColors;

    return GlassSurface(
      borderRadius: SoamaRadii.radiusXl,
      padding: const EdgeInsets.all(14.0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: SoamaRadii.radiusLg,
            child: SizedBox(
              width: 58,
              height: 58,
              child: Image(
                image: ResizeImage(
                  NetworkImage(_provider.avatarUrl),
                  width: 150,
                  height: 150,
                ),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: colors.surfaceSubtle,
                  child: Icon(Icons.person_rounded, color: colors.textTertiary),
                ),
              ),
            ),
          ),
          const SizedBox(width: SoamaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _provider.name,
                        style: SoamaTypography.titleMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_provider.isVerified) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.verified_rounded, size: 16, color: colors.accent),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _provider.profession,
                  style: SoamaTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ServiceBadge.rating(
                      label: '${_provider.rating.toStringAsFixed(1)} (${_provider.reviewCount})',
                    ),
                    const SizedBox(width: SoamaSpacing.xs),
                    ServiceBadge(
                      label: _provider.approximateDistance,
                      color: colors.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSelector(BuildContext context) {
    final colors = context.soamaColors;
    final availableServices = _provider.services.isNotEmpty
        ? _provider.services
        : [_activeService];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Service',
          style: SoamaTypography.titleSmall.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Choose the specific task or request an initial inspection',
          style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: SoamaSpacing.sm),
        ...availableServices.map((service) {
          final isSelected = _activeService.id == service.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: SoamaSpacing.xs),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _activeService = service;
                });
              },
              borderRadius: SoamaRadii.radiusLg,
              child: AnimatedContainer(
                duration: SoamaMotion.snappy,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.accent.withOpacity(context.isDarkMode ? 0.16 : 0.12)
                      : colors.surfaceSubtle,
                  borderRadius: SoamaRadii.radiusLg,
                  border: Border.all(
                    color: isSelected ? colors.accent : colors.glassBorder,
                    width: isSelected ? 1.5 : 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? colors.accent : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? colors.accent : colors.textTertiary,
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, size: 12, color: Color(0xFF111215))
                          : null,
                    ),
                    const SizedBox(width: SoamaSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.title,
                            style: SoamaTypography.labelLarge.copyWith(
                              color: colors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                          Text(
                            service.duration,
                            style: SoamaTypography.labelSmall.copyWith(
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      service.price,
                      style: SoamaTypography.titleSmall.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDeliveryModeSelector(BuildContext context) {
    final colors = context.soamaColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Delivery Mode',
          style: SoamaTypography.titleSmall.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: SoamaSpacing.sm),
        Row(
          children: ServiceDeliveryMode.values.map((mode) {
            final isSelected = _deliveryMode == mode;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _deliveryMode = mode);
                },
                child: Container(
                  margin: EdgeInsets.only(
                    right: mode == ServiceDeliveryMode.onSiteVisit ? 6.0 : 0,
                    left: mode == ServiceDeliveryMode.visitProvider ? 6.0 : 0,
                  ),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.accent.withOpacity(context.isDarkMode ? 0.16 : 0.12)
                        : colors.surfaceSubtle,
                    borderRadius: SoamaRadii.radiusLg,
                    border: Border.all(
                      color: isSelected ? colors.accent : colors.glassBorder,
                      width: isSelected ? 1.5 : 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        mode.icon,
                        color: isSelected ? colors.accent : colors.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mode.title,
                        style: SoamaTypography.labelMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mode.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SoamaTypography.labelSmall.copyWith(
                          color: colors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDescriptionField(BuildContext context) {
    final colors = context.soamaColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Describe the Problem',
              style: SoamaTypography.titleSmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Required',
              style: SoamaTypography.labelSmall.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Example: "The pipe beneath the kitchen sink started spraying water this morning. Please bring 3/4-inch PVC couplings and thread seal tape."',
          style: SoamaTypography.bodySmall.copyWith(
            color: colors.textTertiary,
            fontStyle: FontStyle.italic,
            height: 1.35,
          ),
        ),
        const SizedBox(height: SoamaSpacing.xs),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          minLines: 3,
          maxLength: 500,
          onChanged: (text) {
            if (_descriptionError != null && text.trim().length >= 10) {
              setState(() => _descriptionError = null);
            }
          },
          style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Provide details about the issue, equipment brand, symptoms, and urgency...',
            hintStyle: SoamaTypography.bodyMedium.copyWith(
              color: colors.textTertiary.withOpacity(0.6),
            ),
            filled: true,
            fillColor: colors.surfaceSubtle,
            errorText: _descriptionError,
            errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
            contentPadding: const EdgeInsets.all(14.0),
            border: OutlineInputBorder(
              borderRadius: SoamaRadii.radiusLg,
              borderSide: BorderSide(color: colors.glassBorder, width: 0.8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: SoamaRadii.radiusLg,
              borderSide: BorderSide(color: colors.glassBorder, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: SoamaRadii.radiusLg,
              borderSide: BorderSide(color: colors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsSection(BuildContext context) {
    final colors = context.soamaColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Photo Attachments (Optional)',
              style: SoamaTypography.titleSmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${_attachedPhotos.length}/4',
              style: SoamaTypography.labelSmall.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: SoamaSpacing.xs),
        SizedBox(
          height: 78,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              // Add photo button
              if (_attachedPhotos.length < 4)
                GestureDetector(
                  onTap: _showPhotoAttachmentSheet,
                  child: Container(
                    width: 78,
                    height: 78,
                    margin: const EdgeInsets.only(right: SoamaSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: SoamaRadii.radiusLg,
                      border: Border.all(
                        color: colors.accent.withOpacity(0.7),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 22, color: colors.accent),
                        const SizedBox(height: 4),
                        Text(
                          'Add Photo',
                          style: SoamaTypography.labelSmall.copyWith(
                            color: colors.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Attached thumbnails with removal button
              ..._attachedPhotos.asMap().entries.map((entry) {
                final index = entry.key;
                final url = entry.value;

                return Stack(
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      margin: const EdgeInsets.only(right: SoamaSpacing.sm),
                      child: ClipRRect(
                        borderRadius: SoamaRadii.radiusLg,
                        child: Image(
                          image: ResizeImage(NetworkImage(url), width: 160, height: 160),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => _removePhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    final colors = context.soamaColors;

    if (_deliveryMode == ServiceDeliveryMode.visitProvider) {
      return Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: SoamaRadii.radiusLg,
          border: Border.all(color: colors.glassBorder, width: 0.8),
        ),
        child: Row(
          children: [
            Icon(Icons.storefront_rounded, size: 24, color: colors.accent),
            const SizedBox(width: SoamaSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Provider Workshop Address',
                    style: SoamaTypography.titleSmall.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _provider.location,
                    style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Location',
          style: SoamaTypography.titleSmall.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: SoamaSpacing.xs),
        TextField(
          controller: _addressController,
          onChanged: (text) {
            if (_addressError != null && text.trim().isNotEmpty) {
              setState(() => _addressError = null);
            }
          },
          style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter street address, estate, or area in Delta State',
            prefixIcon: Icon(Icons.place_outlined, color: colors.accent, size: 20),
            filled: true,
            fillColor: colors.surfaceSubtle,
            errorText: _addressError,
            errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            border: OutlineInputBorder(
              borderRadius: SoamaRadii.radiusLg,
              borderSide: BorderSide(color: colors.glassBorder, width: 0.8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: SoamaRadii.radiusLg,
              borderSide: BorderSide(color: colors.glassBorder, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: SoamaRadii.radiusLg,
              borderSide: BorderSide(color: colors.accent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: SoamaSpacing.xs),
        TextField(
          controller: _locationNoteController,
          style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Optional landmark or apartment note (e.g., Flat 3B, black gate)',
            prefixIcon: Icon(Icons.notes_rounded, color: colors.textTertiary, size: 18),
            filled: true,
            fillColor: colors.surfaceSubtle,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            border: OutlineInputBorder(
              borderRadius: SoamaRadii.radiusLg,
              borderSide: BorderSide(color: colors.glassBorder, width: 0.8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: SoamaRadii.radiusLg,
              borderSide: BorderSide(color: colors.glassBorder, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: SoamaRadii.radiusLg,
              borderSide: BorderSide(color: colors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeSection(BuildContext context) {
    final colors = context.soamaColors;
    final dateFormatter = DateFormat('EEE, MMM d, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferred Appointment Time',
          style: SoamaTypography.titleSmall.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: SoamaSpacing.xs),
        // Date Selector Row
        InkWell(
          onTap: _pickCustomDate,
          borderRadius: SoamaRadii.radiusLg,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: SoamaRadii.radiusLg,
              border: Border.all(color: colors.glassBorder, width: 0.8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: colors.accent, size: 20),
                const SizedBox(width: SoamaSpacing.sm),
                Expanded(
                  child: Text(
                    dateFormatter.format(_preferredDate),
                    style: SoamaTypography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Change Date',
                  style: SoamaTypography.labelSmall.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: SoamaSpacing.xs),
        // Time Slot Radio Chips
        ..._timeSlotOptions.map((slot) {
          final isSelected = _preferredTimeSlot == slot;
          return Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _preferredTimeSlot = slot);
              },
              borderRadius: SoamaRadii.radiusMd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.accent.withOpacity(context.isDarkMode ? 0.16 : 0.12)
                      : colors.surfaceSubtle.withOpacity(0.5),
                  borderRadius: SoamaRadii.radiusMd,
                  border: Border.all(
                    color: isSelected ? colors.accent : colors.glassBorder,
                    width: isSelected ? 1.4 : 0.6,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      size: 16,
                      color: isSelected ? colors.accent : colors.textTertiary,
                    ),
                    const SizedBox(width: SoamaSpacing.sm),
                    Text(
                      slot,
                      style: SoamaTypography.labelMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPricingBreakdown(BuildContext context) {
    final colors = context.soamaColors;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: SoamaRadii.radiusXl,
        border: Border.all(color: colors.glassBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price Summary',
                style: SoamaTypography.titleSmall.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: colors.accent.withOpacity(0.18),
                  borderRadius: SoamaRadii.radiusPill,
                ),
                child: Text(
                  'Estimated Quote',
                  style: SoamaTypography.labelSmall.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SoamaSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _activeService.title,
                style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
              ),
              Text(
                _activeService.price,
                style: SoamaTypography.labelLarge.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Escrow Protection & Guarantee',
                style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
              ),
              Text(
                'Free',
                style: SoamaTypography.labelLarge.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 0.8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_rounded, color: colors.accent, size: 20),
              const SizedBox(width: SoamaSpacing.sm),
              Expanded(
                child: Text(
                  'This amount is the estimated base fee for ${_provider.name}. Final payment is held safely in escrow and only released after your physical inspection.',
                  style: SoamaTypography.bodySmall.copyWith(
                    color: colors.textTertiary,
                    height: 1.35,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20.0,
        12.0,
        20.0,
        bottomInset > 0 ? bottomInset + 8.0 : 16.0,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13151A) : colors.surface,
        border: Border(
          top: BorderSide(color: colors.border, width: 1.0),
        ),
      ),
      child: PrimaryButton(
        label: _isSubmitting ? 'Sending Request...' : 'Send Service Request',
        size: ButtonSize.large,
        isLoading: _isSubmitting,
        onPressed: _isSubmitting ? () {} : _submitServiceRequest,
      ),
    );
  }

  Widget _buildSuccessScreen(BuildContext context, ServiceRequest request) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;
    final dateFormatter = DateFormat('EEE, MMM d, yyyy');

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Animated Success Icon Circle
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: colors.accent.withOpacity(isDark ? 0.2 : 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.accent, width: 2.0),
                ),
                child: Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 48,
                    color: colors.accent,
                  ),
                ),
              ),

              const SizedBox(height: SoamaSpacing.lg),

              Text(
                'Request Submitted!',
                style: SoamaTypography.displayMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Your service request has been created and dispatched to ${request.providerName}.',
                textAlign: TextAlign.center,
                style: SoamaTypography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: SoamaSpacing.xl),

              // Request Details Card
              GlassSurface(
                borderRadius: SoamaRadii.radiusXl,
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Booking Reference',
                          style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
                        ),
                        Text(
                          request.id,
                          style: SoamaTypography.labelMedium.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Service',
                          style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
                        ),
                        Text(
                          request.serviceTitle,
                          style: SoamaTypography.labelMedium.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Scheduled Time',
                          style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
                        ),
                        Text(
                          '${dateFormatter.format(request.preferredDate)} • ${request.preferredTimeSlot.split('(').first.trim()}',
                          style: SoamaTypography.labelMedium.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estimated Fee',
                          style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
                        ),
                        Text(
                          '${request.servicePrice} (Escrow)',
                          style: SoamaTypography.labelMedium.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Action 1: Negotiate / Discuss Rate
              PrimaryButton(
                label: 'Negotiate / Discuss Rate',
                size: ButtonSize.large,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push(
                    AppRoutes.negotiationPath(request.id),
                    extra: request,
                  );
                },
              ),

              const SizedBox(height: SoamaSpacing.sm),

              // Action 2: View in My Bookings
              SecondaryButton(
                label: 'View in My Bookings',
                size: ButtonSize.large,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.go(AppRoutes.bookings);
                },
              ),

              const SizedBox(height: SoamaSpacing.sm),

              // Action 3: Return to Home
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.go(AppRoutes.home);
                },
                child: Text(
                  'Return to Home',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: SoamaSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}
