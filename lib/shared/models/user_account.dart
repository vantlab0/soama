import 'package:flutter/material.dart';
import 'customer_profile.dart';
import 'service_provider.dart';

enum AppMode {
  customer('Customer Mode', Icons.person_rounded),
  provider('Provider Mode', Icons.storefront_rounded);

  final String label;
  final IconData icon;
  const AppMode(this.label, this.icon);
}

enum ProviderVerificationStatus {
  unverified('Unverified (Mock)', Icons.shield_outlined, Color(0xFF94A3B8)),
  pending('Verification Pending (Mock)', Icons.hourglass_top_rounded, Color(0xFFFBBF24)),
  verified('Verified Specialist (Mock)', Icons.verified_rounded, Color(0xFF38BDF8));

  final String label;
  final IconData icon;
  final Color color;
  const ProviderVerificationStatus(this.label, this.icon, this.color);
}

class ProviderProfileData {
  final String providerId;
  final String businessName;
  final String profession;
  final String categoryId;
  final String categoryTitle;
  final String bio;
  final String serviceArea;
  final bool supportsVisitCustomer;
  final bool supportsReceiveCustomer;
  final String workingDays;
  final String workingHours;
  final ProviderVerificationStatus verificationStatus;
  final List<ProviderServiceOffering> services;
  final List<String> portfolioImages;
  final double rating;
  final int reviewCount;
  final int completedJobsCount;
  final int totalEarnings;
  final int inEscrowEarnings;

  final String? verificationDocumentUrl;

  const ProviderProfileData({
    required this.providerId,
    required this.businessName,
    required this.profession,
    required this.categoryId,
    required this.categoryTitle,
    required this.bio,
    required this.serviceArea,
    this.supportsVisitCustomer = true,
    this.supportsReceiveCustomer = true,
    this.workingDays = 'Mon – Sat',
    this.workingHours = '8:00 AM – 6:00 PM',
    this.verificationStatus = ProviderVerificationStatus.pending,
    this.verificationDocumentUrl,
    this.services = const [
      ProviderServiceOffering(
        id: 'pro-srv-1',
        title: 'Emergency Electrical Diagnostics & Fuse Repair',
        description: 'Comprehensive troubleshooting of power failure, burnt breakers, and voltage instability.',
        price: '₦7,500',
        priceAmount: 7500,
        duration: '1-2 hrs',
      ),
      ProviderServiceOffering(
        id: 'pro-srv-2',
        title: 'Inverter & Battery Bank Full Installation',
        description: 'Pure sine wave inverter connection, battery rack cabling, and changeover switch integration.',
        price: '₦25,000',
        priceAmount: 25000,
        duration: '3-5 hrs',
      ),
      ProviderServiceOffering(
        id: 'pro-srv-3',
        title: 'AC Point & Heavy Appliance Dedicated Wiring',
        description: '4mm conduit cable pulling, breaker isolation, and 15A socket termination.',
        price: '₦12,000',
        priceAmount: 12000,
        duration: '2-3 hrs',
      ),
    ],
    this.portfolioImages = const [
      'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=600&q=80',
      'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?auto=format&fit=crop&w=600&q=80',
    ],
    this.rating = 4.9,
    this.reviewCount = 18,
    this.completedJobsCount = 14,
    this.totalEarnings = 142500,
    this.inEscrowEarnings = 16500,
  });

  ProviderProfileData copyWith({
    String? businessName,
    String? profession,
    String? categoryId,
    String? categoryTitle,
    String? bio,
    String? serviceArea,
    bool? supportsVisitCustomer,
    bool? supportsReceiveCustomer,
    String? workingDays,
    String? workingHours,
    ProviderVerificationStatus? verificationStatus,
    String? verificationDocumentUrl,
    List<ProviderServiceOffering>? services,
    List<String>? portfolioImages,
    double? rating,
    int? reviewCount,
    int? completedJobsCount,
    int? totalEarnings,
    int? inEscrowEarnings,
  }) {
    return ProviderProfileData(
      providerId: providerId,
      businessName: businessName ?? this.businessName,
      profession: profession ?? this.profession,
      categoryId: categoryId ?? this.categoryId,
      categoryTitle: categoryTitle ?? this.categoryTitle,
      bio: bio ?? this.bio,
      serviceArea: serviceArea ?? this.serviceArea,
      supportsVisitCustomer: supportsVisitCustomer ?? this.supportsVisitCustomer,
      supportsReceiveCustomer: supportsReceiveCustomer ?? this.supportsReceiveCustomer,
      workingDays: workingDays ?? this.workingDays,
      workingHours: workingHours ?? this.workingHours,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationDocumentUrl: verificationDocumentUrl ?? this.verificationDocumentUrl,
      services: services ?? this.services,
      portfolioImages: portfolioImages ?? this.portfolioImages,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      completedJobsCount: completedJobsCount ?? this.completedJobsCount,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      inEscrowEarnings: inEscrowEarnings ?? this.inEscrowEarnings,
    );
  }
}

class UserAccount {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? avatarUrl;
  final bool hasCustomerCapability;
  final bool hasProviderCapability;
  final AppMode currentMode;
  final ProviderProfileData? providerProfile;

  const UserAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.avatarUrl,
    this.hasCustomerCapability = true,
    this.hasProviderCapability = false,
    this.currentMode = AppMode.customer,
    this.providerProfile,
  });

  UserAccount copyWith({
    String? fullName,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
    bool? hasCustomerCapability,
    bool? hasProviderCapability,
    AppMode? currentMode,
    ProviderProfileData? providerProfile,
  }) {
    return UserAccount(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      hasCustomerCapability: hasCustomerCapability ?? this.hasCustomerCapability,
      hasProviderCapability: hasProviderCapability ?? this.hasProviderCapability,
      currentMode: currentMode ?? this.currentMode,
      providerProfile: providerProfile ?? this.providerProfile,
    );
  }

  // ValueNotifier for reactive updates across the entire app
  static final ValueNotifier<UserAccount> notifier = ValueNotifier<UserAccount>(
    UserAccount(
      id: 'usr-warri-01',
      fullName: CustomerProfile.current.fullName,
      email: CustomerProfile.current.email,
      phoneNumber: CustomerProfile.current.phoneNumber,
      avatarUrl: CustomerProfile.current.avatarUrl,
      hasCustomerCapability: true,
      hasProviderCapability: false,
      currentMode: AppMode.customer,
      providerProfile: null,
    ),
  );

  static UserAccount get current => notifier.value;
  static set current(UserAccount updated) {
    notifier.value = updated;
  }

  static void switchMode(AppMode newMode) {
    if (newMode == AppMode.provider && !current.hasProviderCapability) {
      // Must onboard first
      return;
    }
    current = current.copyWith(currentMode: newMode);
  }

  static void enableProviderCapability(ProviderProfileData profile) {
    current = current.copyWith(
      hasProviderCapability: true,
      currentMode: AppMode.provider,
      providerProfile: profile,
    );
  }

  static void reset() {
    notifier.value = UserAccount(
      id: 'usr-warri-01',
      fullName: CustomerProfile.current.fullName,
      email: CustomerProfile.current.email,
      phoneNumber: CustomerProfile.current.phoneNumber,
      avatarUrl: CustomerProfile.current.avatarUrl,
      hasCustomerCapability: true,
      hasProviderCapability: false,
      currentMode: AppMode.customer,
      providerProfile: null,
    );
  }
}
