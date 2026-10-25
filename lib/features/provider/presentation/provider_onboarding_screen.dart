import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/service_category.dart';
import '../../../../shared/models/service_provider.dart';
import '../../../../shared/models/user_account.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../../../shared/widgets/soama_buttons.dart';
import '../../categories/presentation/providers/categories_provider.dart';
import '../../providers/presentation/providers/provider_provider.dart';
import '../../storage/presentation/providers/storage_provider.dart';
import '../../storage/presentation/widgets/image_picker_sheet.dart';

class ProviderOnboardingScreen extends ConsumerStatefulWidget {
  const ProviderOnboardingScreen({super.key});

  @override
  ConsumerState<ProviderOnboardingScreen> createState() => _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState extends ConsumerState<ProviderOnboardingScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  late TextEditingController _businessNameCtrl;
  late TextEditingController _professionCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _serviceTitleCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _serviceAreaCtrl;
  late TextEditingController _workingHoursCtrl;

  String _selectedCategory = 'electrical';
  bool _supportsVisitCustomer = true;
  bool _supportsReceiveCustomer = true;
  String _workingDays = 'Mon – Sat';

  // KYC Verification Document Upload State
  String? _uploadedDocName;
  String? _uploadedDocUrl;
  bool _isUploadingDoc = false;

  Future<void> _pickAndUploadKycDoc() async {
    HapticFeedback.lightImpact();
    final payload = await ImagePickerSheet.show(
      context,
      title: 'Upload Government ID or CAC License',
    );

    if (payload == null) return;

    setState(() => _isUploadingDoc = true);
    final userId = UserAccount.current.id;

    try {
      final storageRepo = ref.read(storageRepositoryProvider);
      final signedUrl = await storageRepo.uploadVerificationDocument(
        providerId: userId,
        bytes: payload.bytes,
        fileName: payload.fileName,
        documentType: 'id_cac_license',
      );

      if (mounted) {
        setState(() {
          _uploadedDocName = payload.fileName;
          _uploadedDocUrl = signedUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification document securely uploaded to private storage.'),
            backgroundColor: Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document upload failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingDoc = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final account = UserAccount.current;
    final initialName = account.providerProfile?.businessName ??
        '${account.fullName.split(' ').first} Precision Services';

    _businessNameCtrl = TextEditingController(text: initialName);
    _professionCtrl = TextEditingController(
      text: account.providerProfile?.profession ?? 'Certified Electrician & Inverter Specialist',
    );
    _bioCtrl = TextEditingController(
      text: account.providerProfile?.bio ??
          'Professional technician providing reliable installations, diagnostic troubleshooting, and preventive maintenance across Delta State.',
    );
    _serviceTitleCtrl = TextEditingController(
      text: account.providerProfile?.services.firstOrNull?.title ?? 'Emergency Diagnostic & Circuit Repair',
    );
    _priceCtrl = TextEditingController(
      text: account.providerProfile?.services.firstOrNull?.priceAmount.toString() ?? '8500',
    );
    _serviceAreaCtrl = TextEditingController(
      text: account.providerProfile?.serviceArea ?? 'Warri, Effurun, & Uvwie Metros',
    );
    _workingHoursCtrl = TextEditingController(
      text: account.providerProfile?.workingHours ?? '8:00 AM – 6:00 PM',
    );

    if (account.providerProfile != null) {
      _selectedCategory = account.providerProfile!.categoryId;
      _supportsVisitCustomer = account.providerProfile!.supportsVisitCustomer;
      _supportsReceiveCustomer = account.providerProfile!.supportsReceiveCustomer;
      _workingDays = account.providerProfile!.workingDays;
    }
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _professionCtrl.dispose();
    _bioCtrl.dispose();
    _serviceTitleCtrl.dispose();
    _priceCtrl.dispose();
    _serviceAreaCtrl.dispose();
    _workingHoursCtrl.dispose();
    super.dispose();
  }

  void _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    final priceAmount = int.tryParse(_priceCtrl.text.trim()) ?? 8500;

    final primaryService = ProviderServiceOffering(
      id: 'pro-srv-${DateTime.now().millisecondsSinceEpoch}',
      title: _serviceTitleCtrl.text.trim().isNotEmpty
          ? _serviceTitleCtrl.text.trim()
          : 'Standard Service Diagnostic',
      description: 'Standard diagnostic assessment and troubleshooting work.',
      price: '₦${priceAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
      priceAmount: priceAmount,
      duration: '1-3 hrs',
    );

    final categories = ref.read(categoriesProvider).valueOrNull ?? ServiceCategory.mockCategories;
    final categoryObj = categories.firstWhere(
      (c) => c.id == _selectedCategory,
      orElse: () => categories.first,
    );

    final userId = UserAccount.current.id;
    final newProfile = ProviderProfileData(
      providerId: userId,
      businessName: _businessNameCtrl.text.trim().isNotEmpty
          ? _businessNameCtrl.text.trim()
          : 'Precision Services',
      profession: _professionCtrl.text.trim().isNotEmpty
          ? _professionCtrl.text.trim()
          : 'Service Specialist',
      categoryId: _selectedCategory,
      categoryTitle: categoryObj.title,
      bio: _bioCtrl.text.trim(),
      serviceArea: _serviceAreaCtrl.text.trim(),
      supportsVisitCustomer: _supportsVisitCustomer,
      supportsReceiveCustomer: _supportsReceiveCustomer,
      workingDays: _workingDays,
      workingHours: _workingHoursCtrl.text.trim(),
      verificationStatus: ProviderVerificationStatus.pending,
      verificationDocumentUrl: _uploadedDocUrl,
      services: [primaryService],
    );

    final repo = ref.read(providerRepositoryProvider);
    try {
      await repo.upsertProviderProfile(newProfile, userId);
      await repo.addService(
        providerId: userId,
        service: primaryService,
        categoryId: _selectedCategory,
      );
    } catch (e) {
      debugPrint('ℹ️ [ProviderOnboarding] Repository persist note: $e');
    }

    UserAccount.enableProviderCapability(newProfile);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Provider profile created! Welcome to Provider Mode.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF15803D),
          duration: Duration(seconds: 3),
        ),
      );
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'Become a Service Provider',
          style: SoamaTypography.titleMedium.copyWith(color: colors.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SoamaSpacing.lg, vertical: SoamaSpacing.md),
              child: Row(
                children: List.generate(4, (index) {
                  final isActive = index <= _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: isActive ? colors.accent : colors.surfaceSecondary,
                        borderRadius: SoamaRadii.radiusFull,
                      ),
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: SoamaSpacing.lg, vertical: SoamaSpacing.sm),
                child: Form(
                  key: _formKey,
                  child: _buildCurrentStep(colors),
                ),
              ),
            ),

            // Bottom Navigation Buttons
            Container(
              padding: const EdgeInsets.all(SoamaSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.glassBorder, width: 0.8)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(right: SoamaSpacing.sm),
                        child: OutlinedButton(
                          onPressed: () => setState(() => _currentStep--),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: _currentStep == 3 ? 'Launch Provider Mode' : 'Continue',
                      onPressed: () {
                        if (_currentStep < 3) {
                          setState(() => _currentStep++);
                        } else {
                          _completeOnboarding();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep(SoamaThemeColors colors) {
    switch (_currentStep) {
      case 0:
        return _buildStep1BusinessProfile(colors);
      case 1:
        return _buildStep2Services(colors);
      case 2:
        return _buildStep3Availability(colors);
      case 3:
      default:
        return _buildStep4Review(colors);
    }
  }

  Widget _buildStep1BusinessProfile(SoamaThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 1: Professional Profile',
          style: SoamaTypography.headlineSmall.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: SoamaSpacing.xs),
        Text(
          'Tell customers who you are and what business name you operate under in Delta State.',
          style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: SoamaSpacing.lg),

        // Business Name
        Text('Business or Trading Name', style: SoamaTypography.labelMedium.copyWith(color: colors.textPrimary)),
        const SizedBox(height: SoamaSpacing.xs),
        TextFormField(
          controller: _businessNameCtrl,
          decoration: InputDecoration(
            hintText: 'e.g. Delta Flow Precision Services',
            filled: true,
            fillColor: colors.surfaceSecondary,
            border: const OutlineInputBorder(borderRadius: SoamaRadii.radiusMd, borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: SoamaSpacing.md),

        // Profession Title
        Text('Professional Title', style: SoamaTypography.labelMedium.copyWith(color: colors.textPrimary)),
        const SizedBox(height: SoamaSpacing.xs),
        TextFormField(
          controller: _professionCtrl,
          decoration: InputDecoration(
            hintText: 'e.g. Certified Electrician & Inverter Specialist',
            filled: true,
            fillColor: colors.surfaceSecondary,
            border: const OutlineInputBorder(borderRadius: SoamaRadii.radiusMd, borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: SoamaSpacing.md),

        // Biography
        Text('About & Experience', style: SoamaTypography.labelMedium.copyWith(color: colors.textPrimary)),
        const SizedBox(height: SoamaSpacing.xs),
        TextFormField(
          controller: _bioCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Brief summary of your field experience and track record...',
            filled: true,
            fillColor: colors.surfaceSecondary,
            border: const OutlineInputBorder(borderRadius: SoamaRadii.radiusMd, borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Services(SoamaThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 2: Service & Pricing',
          style: SoamaTypography.headlineSmall.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: SoamaSpacing.xs),
        Text(
          'Select your primary trade category and define your starting service offering.',
          style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: SoamaSpacing.lg),

        // Category Selection Chips
        Text('Primary Category', style: SoamaTypography.labelMedium.copyWith(color: colors.textPrimary)),
        const SizedBox(height: SoamaSpacing.xs),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (ref.watch(categoriesProvider).valueOrNull ?? ServiceCategory.mockCategories).map((cat) {
            final isSelected = cat.id == _selectedCategory;
            return ChoiceChip(
              label: Text(cat.title),
              selected: isSelected,
              selectedColor: colors.accent.withAlpha(50),
              backgroundColor: colors.surfaceSecondary,
              labelStyle: TextStyle(
                color: isSelected ? colors.accent : colors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              onSelected: (val) {
                if (val) setState(() => _selectedCategory = cat.id);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: SoamaSpacing.md),

        // Primary Service Title
        Text('Primary Service Title', style: SoamaTypography.labelMedium.copyWith(color: colors.textPrimary)),
        const SizedBox(height: SoamaSpacing.xs),
        TextFormField(
          controller: _serviceTitleCtrl,
          decoration: InputDecoration(
            hintText: 'e.g. Distribution Box Overhaul & Wiring',
            filled: true,
            fillColor: colors.surfaceSecondary,
            border: const OutlineInputBorder(borderRadius: SoamaRadii.radiusMd, borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: SoamaSpacing.md),

        // Indicative Price
        Text('Indicative Base Price (₦)', style: SoamaTypography.labelMedium.copyWith(color: colors.textPrimary)),
        const SizedBox(height: SoamaSpacing.xs),
        TextFormField(
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: '₦ ',
            hintText: '8,500',
            filled: true,
            fillColor: colors.surfaceSecondary,
            border: const OutlineInputBorder(borderRadius: SoamaRadii.radiusMd, borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Availability(SoamaThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 3: Location & Availability',
          style: SoamaTypography.headlineSmall.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: SoamaSpacing.xs),
        Text(
          'Define where you serve clients in Delta State and how you fulfill jobs.',
          style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: SoamaSpacing.lg),

        // Service Area
        Text('Service Area / Coverage', style: SoamaTypography.labelMedium.copyWith(color: colors.textPrimary)),
        const SizedBox(height: SoamaSpacing.xs),
        TextFormField(
          controller: _serviceAreaCtrl,
          decoration: InputDecoration(
            hintText: 'e.g. Warri, Effurun, & Uvwie Metros',
            filled: true,
            fillColor: colors.surfaceSecondary,
            border: const OutlineInputBorder(borderRadius: SoamaRadii.radiusMd, borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: SoamaSpacing.md),

        // Delivery Mode Switches
        Text('Delivery Options', style: SoamaTypography.labelMedium.copyWith(color: colors.textPrimary)),
        const SizedBox(height: SoamaSpacing.xs),
        Material(
          color: Colors.transparent,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text('I visit customer on-site', style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary)),
                subtitle: Text('Travel to customer homes, stores, or offices', style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary)),
                activeThumbColor: colors.accent,
                value: _supportsVisitCustomer,
                onChanged: (val) => setState(() => _supportsVisitCustomer = val),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text('Customers visit my workshop', style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary)),
                subtitle: Text('Receive clients or equipment drop-offs at my address', style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary)),
                activeThumbColor: colors.accent,
                value: _supportsReceiveCustomer,
                onChanged: (val) => setState(() => _supportsReceiveCustomer = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: SoamaSpacing.md),

        // Working Hours
        Text('Working Days & Hours', style: SoamaTypography.labelMedium.copyWith(color: colors.textPrimary)),
        const SizedBox(height: SoamaSpacing.xs),
        TextFormField(
          controller: _workingHoursCtrl,
          decoration: InputDecoration(
            hintText: 'e.g. Mon – Sat: 8:00 AM – 6:00 PM',
            filled: true,
            fillColor: colors.surfaceSecondary,
            border: const OutlineInputBorder(borderRadius: SoamaRadii.radiusMd, borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildStep4Review(SoamaThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 4: Review & Launch',
          style: SoamaTypography.headlineSmall.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: SoamaSpacing.xs),
        Text(
          'Review your local provider profile details before enabling Provider Mode.',
          style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: SoamaSpacing.lg),

        // KYC Verification Document Upload Section
        Container(
          padding: const EdgeInsets.all(SoamaSpacing.md),
          decoration: BoxDecoration(
            color: _uploadedDocUrl != null
                ? const Color(0xFF15803D).withAlpha(25)
                : const Color(0xFFFBBF24).withAlpha(30),
            borderRadius: SoamaRadii.radiusMd,
            border: Border.all(
              color: _uploadedDocUrl != null
                  ? const Color(0xFF15803D).withAlpha(120)
                  : const Color(0xFFFBBF24).withAlpha(120),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _uploadedDocUrl != null ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                    color: _uploadedDocUrl != null ? const Color(0xFF15803D) : const Color(0xFFD97706),
                    size: 22,
                  ),
                  const SizedBox(width: SoamaSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _uploadedDocUrl != null
                              ? 'KYC Verification Document Attached'
                              : 'Mock Verification Status: Pending Review',
                          style: SoamaTypography.titleSmall.copyWith(
                            color: _uploadedDocUrl != null ? const Color(0xFF15803D) : const Color(0xFFD97706),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _uploadedDocUrl != null
                              ? 'Document: ${_uploadedDocName ?? 'ID / CAC Certificate'} (Securely stored in Supabase private storage)'
                              : 'Upload your National ID (NIN), Voter\'s Card, or CAC Certificate to get your Verified Provider badge faster.',
                          style: SoamaTypography.labelSmall.copyWith(
                            color: colors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SoamaSpacing.md),
              OutlinedButton.icon(
                onPressed: _isUploadingDoc ? null : _pickAndUploadKycDoc,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.accent,
                  side: BorderSide(color: colors.accent.withAlpha(150)),
                  shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
                ),
                icon: _isUploadingDoc
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_uploadedDocUrl != null ? Icons.refresh_rounded : Icons.cloud_upload_outlined, size: 18),
                label: Text(
                  _isUploadingDoc
                      ? 'Uploading...'
                      : (_uploadedDocUrl != null ? 'Replace Document' : 'Upload ID or CAC Document'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SoamaSpacing.md),

        // Summary Card
        GlassSurface(
          padding: const EdgeInsets.all(SoamaSpacing.md),
          borderRadius: SoamaRadii.radiusLg,
          child: Column(
            children: [
              _summaryRow(colors, 'Business Name', _businessNameCtrl.text.trim()),
              const Divider(height: 16),
              _summaryRow(colors, 'Profession', _professionCtrl.text.trim()),
              const Divider(height: 16),
              _summaryRow(colors, 'Category', _selectedCategory.toUpperCase()),
              const Divider(height: 16),
              _summaryRow(colors, 'Base Service', _serviceTitleCtrl.text.trim()),
              const Divider(height: 16),
              _summaryRow(colors, 'Starting Price', '₦${_priceCtrl.text.trim()}'),
              const Divider(height: 16),
              _summaryRow(colors, 'Coverage Area', _serviceAreaCtrl.text.trim()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(SoamaThemeColors colors, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: SoamaTypography.labelMedium.copyWith(color: colors.textTertiary)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: SoamaTypography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
