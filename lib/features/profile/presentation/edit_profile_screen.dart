import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/theme/soama_colors.dart';
import '../../../shared/models/customer_profile.dart';
import '../../../shared/models/user_account.dart';
import '../../../shared/widgets/soama_buttons.dart';
import '../../storage/domain/storage_file_payload.dart';
import '../../storage/presentation/providers/storage_provider.dart';
import '../../storage/presentation/widgets/image_picker_sheet.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;

  String? _selectedAvatarUrl;
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  bool _isUploading = false;
  String? _uploadError;
  StorageFilePayload? _lastFailedPayload;

  final List<String> _sampleAvatars = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
  ];

  @override
  void initState() {
    super.initState();
    final profile = CustomerProfile.current;
    _nameController = TextEditingController(text: profile.fullName);
    _emailController = TextEditingController(text: profile.email);
    _phoneController = TextEditingController(text: profile.phoneNumber);
    _locationController = TextEditingController(text: profile.locationArea);
    _selectedAvatarUrl = profile.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool get _isDirty {
    final profile = CustomerProfile.current;
    return _nameController.text.trim() != profile.fullName ||
        _emailController.text.trim() != profile.email ||
        _phoneController.text.trim() != profile.phoneNumber ||
        _locationController.text.trim() != profile.locationArea ||
        _selectedAvatarUrl != profile.avatarUrl;
  }

  void _saveProfile() {
    setState(() {
      _nameError = null;
      _emailError = null;
      _phoneError = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final loc = _locationController.text.trim();

    bool hasError = false;

    if (name.isEmpty) {
      setState(() => _nameError = 'Full name is required.');
      hasError = true;
    } else if (name.length < 3) {
      setState(() => _nameError = 'Full name must be at least 3 characters.');
      hasError = true;
    }

    if (email.isEmpty) {
      setState(() => _emailError = 'Email address is required.');
      hasError = true;
    } else if (!email.contains('@') || !email.contains('.')) {
      setState(() => _emailError = 'Please enter a valid email address.');
      hasError = true;
    }

    if (phone.isEmpty) {
      setState(() => _phoneError = 'Phone number is required.');
      hasError = true;
    } else if (phone.length < 8) {
      setState(() => _phoneError = 'Please enter a valid phone number.');
      hasError = true;
    }

    if (hasError) {
      HapticFeedback.vibrate();
      return;
    }

    HapticFeedback.mediumImpact();

    CustomerProfile.current = CustomerProfile.current.copyWith(
      fullName: name,
      email: email,
      phoneNumber: phone,
      locationArea: loc.isNotEmpty ? loc : CustomerProfile.current.locationArea,
      avatarUrl: _selectedAvatarUrl,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF15803D),
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.of(context).pop(true);
  }

  Future<void> _pickAndUploadPhoto() async {
    HapticFeedback.lightImpact();
    final payload = await ImagePickerSheet.show(
      context,
      title: 'Update Profile Photo',
      hasExistingImage: _selectedAvatarUrl != null,
      onRemove: () {
        setState(() {
          _selectedAvatarUrl = null;
          _uploadError = null;
        });
      },
    );

    if (payload != null) {
      await _uploadPhotoPayload(payload);
    }
  }

  Future<void> _uploadPhotoPayload(StorageFilePayload payload) async {
    setState(() {
      _isUploading = true;
      _uploadError = null;
      _lastFailedPayload = null;
    });

    try {
      final repo = ref.read(storageRepositoryProvider);
      final userId = UserAccount.current.id.isNotEmpty
          ? UserAccount.current.id
          : CustomerProfile.current.id;

      final publicUrl = await repo.uploadProfilePhoto(
        userId: userId,
        bytes: payload.bytes,
        fileName: payload.fileName,
      );

      if (mounted) {
        setState(() {
          _selectedAvatarUrl = publicUrl;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo uploaded to Supabase Storage.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF15803D),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadError = e.toString().replaceAll('Exception:', '').trim();
          _lastFailedPayload = payload;
        });
      }
    }
  }

  void _selectAvatar(String? url) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedAvatarUrl = url;
      _uploadError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;

    return PopScope(
      canPop: !_isDirty && !_isUploading,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: colors.surface,
            shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusXl),
            title: Text('Discard Changes?', style: SoamaTypography.titleLarge.copyWith(color: colors.textPrimary)),
            content: Text('You have unsaved profile changes.', style: SoamaTypography.bodyMedium.copyWith(color: colors.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Keep Editing', style: TextStyle(color: colors.textSecondary))),
              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Discard', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700))),
            ],
          ),
        );
        if (shouldDiscard == true && context.mounted) {
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
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: colors.textPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Edit Profile',
            style: SoamaTypography.titleMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _isUploading ? null : _saveProfile,
              child: Text(
                'Save',
                style: TextStyle(
                  color: _isUploading ? colors.textTertiary : colors.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Preview & Selector
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _isUploading ? null : _pickAndUploadPhoto,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: colors.accent,
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.accent.withOpacity(0.6), width: 2.5),
                              ),
                              child: ClipOval(
                                child: _selectedAvatarUrl != null
                                    ? Image.network(
                                        _selectedAvatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            CustomerProfile.current.initials,
                                            style: TextStyle(color: colors.onAccent, fontSize: 28, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          CustomerProfile.current.initials,
                                          style: TextStyle(color: colors.onAccent, fontSize: 28, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                              ),
                            ),
                            // Upload loading spinner overlay
                            if (_isUploading)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: colors.accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Camera action button pill
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colors.surface, width: 2),
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 16,
                                  color: colors.onAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: SoamaSpacing.sm),
                      Text(
                        'Select Profile Photo',
                        style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
                      ),
                      const SizedBox(height: SoamaSpacing.xs),
                      // Upload Photo trigger text button
                      TextButton.icon(
                        onPressed: _isUploading ? null : _pickAndUploadPhoto,
                        icon: Icon(Icons.cloud_upload_outlined, size: 16, color: colors.accent),
                        label: Text(
                          _selectedAvatarUrl != null ? 'Change Photo' : 'Upload Photo',
                          style: TextStyle(
                            color: colors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      // Error banner & retry
                      if (_uploadError != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.12),
                            borderRadius: SoamaRadii.radiusMd,
                            border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _uploadError!,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                ),
                              ),
                              if (_lastFailedPayload != null) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _uploadPhotoPayload(_lastFailedPayload!),
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: SoamaSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _selectAvatar(null),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _selectedAvatarUrl == null ? colors.accent.withOpacity(0.2) : colors.surfaceSubtle,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedAvatarUrl == null ? colors.accent : colors.glassBorder,
                                ),
                              ),
                              child: Text(
                                CustomerProfile.current.initials,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
                              ),
                            ),
                          ),
                          ..._sampleAvatars.map((url) {
                            final isSelected = _selectedAvatarUrl == url;
                            return GestureDetector(
                              onTap: () => _selectAvatar(url),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? colors.accent : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.network(url, fit: BoxFit.cover),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: SoamaSpacing.xl),

                // Full Name
                _buildFieldLabel(context, 'Full Name'),
                TextField(
                  controller: _nameController,
                  style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
                  decoration: _buildInputDecoration(context, 'Enter your full name', errorText: _nameError),
                ),

                const SizedBox(height: SoamaSpacing.md),

                // Email Address
                _buildFieldLabel(context, 'Email Address'),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
                  decoration: _buildInputDecoration(context, 'Enter your email address', errorText: _emailError),
                ),

                const SizedBox(height: SoamaSpacing.md),

                // Phone Number
                _buildFieldLabel(context, 'Phone Number'),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
                  decoration: _buildInputDecoration(context, 'e.g. +234 803 123 4567', errorText: _phoneError),
                ),

                const SizedBox(height: SoamaSpacing.md),

                // Location / Area
                _buildFieldLabel(context, 'Primary Service Area'),
                TextField(
                  controller: _locationController,
                  style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
                  decoration: _buildInputDecoration(context, 'e.g. Airport Road, Warri'),
                ),

                const SizedBox(height: SoamaSpacing.xl),

                // Save Action
                PrimaryButton(
                  label: 'Save Profile Changes',
                  size: ButtonSize.large,
                  onPressed: _saveProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: SoamaTypography.labelMedium.copyWith(
          color: context.soamaColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(BuildContext context, String hint, {String? errorText}) {
    final colors = context.soamaColors;
    return InputDecoration(
      hintText: hint,
      hintStyle: SoamaTypography.bodySmall.copyWith(color: colors.textTertiary),
      errorText: errorText,
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
      filled: true,
      fillColor: colors.surfaceSubtle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      border: OutlineInputBorder(borderRadius: SoamaRadii.radiusLg, borderSide: BorderSide(color: colors.glassBorder, width: 0.8)),
      enabledBorder: OutlineInputBorder(borderRadius: SoamaRadii.radiusLg, borderSide: BorderSide(color: colors.glassBorder, width: 0.8)),
      focusedBorder: OutlineInputBorder(borderRadius: SoamaRadii.radiusLg, borderSide: BorderSide(color: colors.accent, width: 1.4)),
    );
  }
}
