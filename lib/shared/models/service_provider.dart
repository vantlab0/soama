class ProviderServiceOffering {
  final String id;
  final String title;
  final String description;
  final String price;
  final int priceAmount;
  final String duration;
  final String? imageUrl;

  const ProviderServiceOffering({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.priceAmount,
    required this.duration,
    this.imageUrl,
  });

  ProviderServiceOffering copyWith({
    String? id,
    String? title,
    String? description,
    String? price,
    int? priceAmount,
    String? duration,
    String? imageUrl,
  }) {
    return ProviderServiceOffering(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      priceAmount: priceAmount ?? this.priceAmount,
      duration: duration ?? this.duration,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class ProviderReview {
  final String id;
  final String? bookingId;
  final String? customerId;
  final String? providerId;
  final String userName;
  final String userAvatarUrl;
  final double rating;
  final String date;
  final String comment;
  final String? providerReply;
  final String? providerReplyDate;
  final DateTime? createdAt;

  const ProviderReview({
    required this.id,
    this.bookingId,
    this.customerId,
    this.providerId,
    required this.userName,
    required this.userAvatarUrl,
    required this.rating,
    required this.date,
    required this.comment,
    this.providerReply,
    this.providerReplyDate,
    this.createdAt,
  });

  factory ProviderReview.fromSupabase(Map<String, dynamic> json) {
    final ratingNum = json['rating'] as num? ?? 5;
    final createdAtStr = json['created_at']?.toString();
    final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

    String dateFormatted = 'Recently';
    if (createdAt != null) {
      final diff = DateTime.now().difference(createdAt);
      if (diff.inDays == 0) {
        dateFormatted = 'Today';
      } else if (diff.inDays == 1) {
        dateFormatted = 'Yesterday';
      } else if (diff.inDays < 30) {
        dateFormatted = '${diff.inDays} days ago';
      } else {
        dateFormatted = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
      }
    }

    final replyAtStr = json['provider_reply_at']?.toString();
    final replyAt = replyAtStr != null ? DateTime.tryParse(replyAtStr) : null;
    String? replyDateFormatted;
    if (replyAt != null) {
      replyDateFormatted = '${replyAt.day}/${replyAt.month}/${replyAt.year}';
    }

    return ProviderReview(
      id: json['id']?.toString() ?? '',
      bookingId: json['booking_id']?.toString(),
      customerId: json['customer_id']?.toString(),
      providerId: json['provider_id']?.toString(),
      userName: json['reviewer_name']?.toString() ?? json['user_name']?.toString() ?? 'Verified Customer',
      userAvatarUrl: json['reviewer_avatar_url']?.toString() ??
          json['user_avatar_url']?.toString() ??
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
      rating: ratingNum.toDouble(),
      date: dateFormatted,
      comment: json['comment']?.toString() ?? '',
      providerReply: json['provider_reply']?.toString(),
      providerReplyDate: replyDateFormatted,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      if (bookingId != null) 'booking_id': bookingId,
      if (customerId != null) 'customer_id': customerId,
      if (providerId != null) 'provider_id': providerId,
      'rating': rating.toInt(),
      'comment': comment,
      if (providerReply != null) 'provider_reply': providerReply,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  ProviderReview copyWith({
    String? id,
    String? bookingId,
    String? customerId,
    String? providerId,
    String? userName,
    String? userAvatarUrl,
    double? rating,
    String? date,
    String? comment,
    String? providerReply,
    String? providerReplyDate,
    DateTime? createdAt,
  }) {
    return ProviderReview(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      customerId: customerId ?? this.customerId,
      providerId: providerId ?? this.providerId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      rating: rating ?? this.rating,
      date: date ?? this.date,
      comment: comment ?? this.comment,
      providerReply: providerReply ?? this.providerReply,
      providerReplyDate: providerReplyDate ?? this.providerReplyDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}


class ServiceProvider {
  final String id;
  final String name;
  final String businessName;
  final String profession;
  final String categoryId;
  final double rating;
  final int reviewCount;
  final double distanceKm;
  final String approximateDistance;
  final int? startingPriceAmount;
  final String startingPrice;
  final String location;
  final String avatarUrl;
  final String coverUrl;
  final bool isVerified;
  final String badgeTitle;
  final String bio;
  final String workingHours;
  final String availability;
  final List<ProviderServiceOffering> services;
  final List<String> gallery;
  final List<ProviderReview> reviews;

  const ServiceProvider({
    required this.id,
    required this.name,
    required this.businessName,
    required this.profession,
    required this.categoryId,
    required this.rating,
    required this.reviewCount,
    required this.distanceKm,
    required this.approximateDistance,
    required this.startingPriceAmount,
    required this.startingPrice,
    required this.location,
    required this.avatarUrl,
    this.coverUrl = 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=900&q=80',
    required this.isVerified,
    required this.badgeTitle,
    this.bio = 'Experienced and certified professional delivering top-tier service standards across residential and commercial properties in Delta State.',
    this.workingHours = 'Mon – Sat: 8:00 AM – 6:00 PM',
    this.availability = 'Available Today',
    this.services = const [],
    this.gallery = const [],
    this.reviews = const [],
  });

  String get formattedRatingLabel =>
      reviewCount > 0 ? '${rating.toStringAsFixed(1)} ($reviewCount)' : 'New';

  bool get hasReviews => reviewCount > 0;

  ServiceProvider copyWith({
    String? id,
    String? name,
    String? businessName,
    String? profession,
    String? categoryId,
    double? rating,
    int? reviewCount,
    double? distanceKm,
    String? approximateDistance,
    int? startingPriceAmount,
    String? startingPrice,
    String? location,
    String? avatarUrl,
    String? coverUrl,
    bool? isVerified,
    String? badgeTitle,
    String? bio,
    String? workingHours,
    String? availability,
    List<ProviderServiceOffering>? services,
    List<String>? gallery,
    List<ProviderReview>? reviews,
  }) {
    return ServiceProvider(
      id: id ?? this.id,
      name: name ?? this.name,
      businessName: businessName ?? this.businessName,
      profession: profession ?? this.profession,
      categoryId: categoryId ?? this.categoryId,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      distanceKm: distanceKm ?? this.distanceKm,
      approximateDistance: approximateDistance ?? this.approximateDistance,
      startingPriceAmount: startingPriceAmount ?? this.startingPriceAmount,
      startingPrice: startingPrice ?? this.startingPrice,
      location: location ?? this.location,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      isVerified: isVerified ?? this.isVerified,
      badgeTitle: badgeTitle ?? this.badgeTitle,
      bio: bio ?? this.bio,
      workingHours: workingHours ?? this.workingHours,
      availability: availability ?? this.availability,
      services: services ?? this.services,
      gallery: gallery ?? this.gallery,
      reviews: reviews ?? this.reviews,
    );
  }

  static ServiceProvider? findById(String id) {
    try {
      return nearbyPros.firstWhere((p) => p.id == id);
    } catch (_) {
      return nearbyPros.isNotEmpty ? nearbyPros.first : null;
    }
  }

  static const List<ServiceProvider> nearbyPros = [
    ServiceProvider(
      id: 'pro-warri-1',
      name: 'Ochuko Efe',
      businessName: 'Delta Flow Precision Plumbing',
      profession: 'Piping & Water Pump Specialist',
      categoryId: 'plumbing',
      rating: 4.94,
      reviewCount: 88,
      distanceKm: 1.2,
      approximateDistance: '1.2 km away',
      startingPriceAmount: 12000,
      startingPrice: 'From ₦12,000',
      location: 'Airport Rd, Warri',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
      coverUrl: 'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?auto=format&fit=crop&w=900&q=80',
      isVerified: true,
      badgeTitle: 'Verified Pro',
      bio: 'Over 11 years of field experience handling industrial piping, borehole pump automation, and residential leak diagnostics across Warri and Effurun. Certified by Delta State Artisans Board.',
      workingHours: 'Mon – Sat: 7:30 AM – 6:30 PM',
      availability: 'Available Today',
      services: [
        ProviderServiceOffering(
          id: 's-1',
          title: 'Borehole Submersible Pump Repair',
          description: 'Diagnosis and replacement of pump impellers, control boxes, and water flow test.',
          price: '₦15,000',
          priceAmount: 15000,
          duration: '2 - 3 hrs',
        ),
        ProviderServiceOffering(
          id: 's-2',
          title: 'Complete Bathroom Leak Remediation',
          description: 'PPR pipe welding, pressure leak detection, and valve replacements.',
          price: '₦12,000',
          priceAmount: 12000,
          duration: '1 - 2 hrs',
        ),
        ProviderServiceOffering(
          id: 's-3',
          title: 'Overhead Tank Cleaning & Float Valve Setup',
          description: 'High-pressure wash of plastic/steel reservoirs and automatic shutoff sensor calibration.',
          price: '₦18,000',
          priceAmount: 18000,
          duration: '3 - 4 hrs',
        ),
      ],
      gallery: [
        'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=600&q=80',
      ],
      reviews: [
        ProviderReview(
          id: 'r-1',
          userName: 'Dr. Tariye Briggs',
          userAvatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
          rating: 5.0,
          date: '3 days ago',
          comment: 'Ochuko arrived at Airport Road within 45 minutes of booking. Fixed our borehole controller seamlessly with zero leaks.',
        ),
        ProviderReview(
          id: 'r-2',
          userName: 'Chief Victor Okon',
          userAvatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
          rating: 4.9,
          date: '2 weeks ago',
          comment: 'Very professional artisan. Transparent pricing and warranty-backed pipe replacements.',
        ),
      ],
    ),
    ServiceProvider(
      id: 'pro-warri-2',
      name: 'Eseoghene Clark',
      businessName: 'Apex Cold HVAC Services',
      profession: 'Inverter AC & Refrigeration Expert',
      categoryId: 'repairs',
      rating: 4.91,
      reviewCount: 64,
      distanceKm: 2.1,
      approximateDistance: '2.1 km away',
      startingPriceAmount: 15000,
      startingPrice: 'From ₦15,000',
      location: 'Effurun, Warri',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
      coverUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=900&q=80',
      isVerified: true,
      badgeTitle: 'Insured Pro',
      bio: 'HVAC technician specializing in modern inverter air conditioning units, refrigerant R410A charging, compressor replacement, and industrial walk-in chillers.',
      workingHours: 'Mon – Sat: 8:00 AM – 7:00 PM',
      availability: 'Available Today',
      services: [
        ProviderServiceOffering(
          id: 's-4',
          title: 'Inverter Split AC Full Chemical Wash',
          description: 'Deep blower wheel clean, evaporator sanitization, and antibacterial coil treatment.',
          price: '₦15,000',
          priceAmount: 15000,
          duration: '1.5 hrs',
        ),
        ProviderServiceOffering(
          id: 's-5',
          title: 'R410A / R32 Gas Top-Up & Pressure Check',
          description: 'Electronic leak test on copper joints and pure refrigerant gas charge.',
          price: '₦20,000',
          priceAmount: 20000,
          duration: '1 hr',
        ),
      ],
      gallery: [
        'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=600&q=80',
      ],
      reviews: [
        ProviderReview(
          id: 'r-3',
          userName: 'Barrister Nneka Eze',
          userAvatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=200&q=80',
          rating: 5.0,
          date: 'Yesterday',
          comment: 'Diagnosed an inverter error code that two previous technicians could not resolve. Cools like brand new now.',
        ),
      ],
    ),
    ServiceProvider(
      id: 'pro-warri-3',
      name: 'Blessing Igbinoba',
      businessName: 'SparkleClean Prestige Care',
      profession: 'Deep Cleaning & Sanitization',
      categoryId: 'cleaning',
      rating: 4.97,
      reviewCount: 120,
      distanceKm: 0.85,
      approximateDistance: '850 m away',
      startingPriceAmount: 10000,
      startingPrice: 'From ₦10,000',
      location: 'GRA, Warri',
      avatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=400&q=80',
      coverUrl: 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=900&q=80',
      isVerified: true,
      badgeTitle: 'Top Rated',
      bio: 'Eco-certified luxury cleaning provider. Trained team equipped with industrial steam extractors, HEPA filtration vacuums, and non-toxic sanitizing solutions.',
      workingHours: 'Mon – Sun: 7:00 AM – 6:00 PM',
      availability: 'Available Today',
      services: [
        ProviderServiceOffering(
          id: 's-6',
          title: '3-Bedroom Apartment Deep Sanitization',
          description: 'Detailed steam clean of kitchens, bathrooms, tiles, baseboards, and window tracks.',
          price: '₦25,000',
          priceAmount: 25000,
          duration: '4 - 5 hrs',
        ),
        ProviderServiceOffering(
          id: 's-7',
          title: 'Upholstery & Mattress Steam Extraction',
          description: 'Fabric stain removal, dust mite extraction, and freshness deodorizing.',
          price: '₦10,000',
          priceAmount: 10000,
          duration: '2 hrs',
        ),
      ],
      gallery: [
        'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1527515637462-cff94eecc1ac?auto=format&fit=crop&w=600&q=80',
      ],
      reviews: [
        ProviderReview(
          id: 'r-4',
          userName: 'Engr. Femi Adeyemi',
          userAvatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
          rating: 5.0,
          date: '5 days ago',
          comment: 'SparkleClean handled our GRA residence post-painting clean. Impeccable attention to detail.',
        ),
      ],
    ),
    ServiceProvider(
      id: 'pro-warri-4',
      name: 'Godwin Akpevwe',
      businessName: 'PowerShield Electrical & Solar',
      profession: 'Inverter & Generator Changeover',
      categoryId: 'electrical',
      rating: 4.88,
      reviewCount: 47,
      distanceKm: 3.4,
      approximateDistance: '3.4 km away',
      startingPriceAmount: null,
      startingPrice: 'Price on request',
      location: 'Enerhen, Warri',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
      coverUrl: 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&w=900&q=80',
      isVerified: true,
      badgeTitle: 'Certified Tech',
      bio: 'Licensed electrical technician handling automatic generator changeover switches (ATS), surge protection, and commercial DB rewiring.',
      workingHours: 'Mon – Sat: 8:00 AM – 6:00 PM',
      availability: 'Available Today',
      services: [
        ProviderServiceOffering(
          id: 's-8',
          title: 'Automatic Generator Changeover Switch (ATS) Setup',
          description: 'Installation of motorized ATS unit with phase failure protection.',
          price: 'Price on request',
          priceAmount: 30000,
          duration: '3 hrs',
        ),
      ],
      gallery: [
        'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&w=600&q=80',
      ],
      reviews: [
        ProviderReview(
          id: 'r-5',
          userName: 'Kome Uduaghan',
          userAvatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=200&q=80',
          rating: 4.9,
          date: '1 week ago',
          comment: 'Godwin rewired our distribution board safely. Highly competent technician.',
        ),
      ],
    ),
    ServiceProvider(
      id: 'pro-warri-5',
      name: 'Babatunde Ojo',
      businessName: 'Mikano & Heavy Diesel Engineering',
      profession: 'Mikano & Perkins Generator Specialist',
      categoryId: 'repairs',
      rating: 4.96,
      reviewCount: 142,
      distanceKm: 1.8,
      approximateDistance: '1.8 km away',
      startingPriceAmount: 20000,
      startingPrice: 'From ₦20,000',
      location: 'Deco Rd, Warri',
      avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80',
      coverUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=900&q=80',
      isVerified: true,
      badgeTitle: 'Master Engineer',
      bio: 'Specialist in Perkins, Cummins, and Mikano soundproof diesel power generators (20kVA to 250kVA). Routine preventive servicing, fuel injector calibration, and alternator repairs.',
      workingHours: '24/7 Emergency Dispatch',
      availability: 'Available Today',
      services: [
        ProviderServiceOffering(
          id: 's-9',
          title: 'Comprehensive Diesel Generator Servicing (Oil & Filters)',
          description: 'Mobil Delvac oil drain, genuine Perkins oil/fuel/water separator filter renewal, and radiator flush.',
          price: '₦20,000',
          priceAmount: 20000,
          duration: '2 - 3 hrs',
        ),
        ProviderServiceOffering(
          id: 's-10',
          title: 'AVR & Alternator Diagnostic Tuning',
          description: 'Voltage output stabilization, exciter diode testing, and frequency calibration (50Hz).',
          price: '₦25,000',
          priceAmount: 25000,
          duration: '2 hrs',
        ),
      ],
      gallery: [
        'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=600&q=80',
      ],
      reviews: [
        ProviderReview(
          id: 'r-6',
          userName: 'Mr. Jude Dafinone',
          userAvatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
          rating: 5.0,
          date: '4 days ago',
          comment: 'Babatunde arrived with genuine filters and serviced our 30kVA Perkins smoothly. Runs whisper quiet now.',
        ),
      ],
    ),
    ServiceProvider(
      id: 'pro-warri-6',
      name: 'Amaka Eze',
      businessName: 'GlowUp Luxury Hair & Bridal',
      profession: 'Mobile Hair Stylist & Makeup Artist',
      categoryId: 'beauty',
      rating: 4.93,
      reviewCount: 79,
      distanceKm: 2.8,
      approximateDistance: '2.8 km away',
      startingPriceAmount: 18000,
      startingPrice: 'From ₦18,000',
      location: 'Pugba Rd, Warri',
      avatarUrl: 'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?auto=format&fit=crop&w=400&q=80',
      coverUrl: 'https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=900&q=80',
      isVerified: true,
      badgeTitle: 'Celebrity Stylist',
      bio: 'Mobile luxury hair artist, knotless braids specialist, and bridal glam makeup artist. Delivers studio-level pampering in the comfort of your home.',
      workingHours: 'Tue – Sun: 9:00 AM – 7:00 PM',
      availability: 'Available Today',
      services: [
        ProviderServiceOffering(
          id: 's-11',
          title: 'Knotless Box Braids (Mid-Back Length)',
          description: 'Painless gentle scalp parting with clean finishing and hot water dip.',
          price: '₦18,000',
          priceAmount: 18000,
          duration: '4 hrs',
        ),
      ],
      gallery: [
        'https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=600&q=80',
      ],
      reviews: [
        ProviderReview(
          id: 'r-7',
          userName: 'Sandra Osawaru',
          userAvatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
          rating: 5.0,
          date: '1 week ago',
          comment: 'Amaka did my traditional wedding bridal glam. Everyone complimented my hair and makeup!',
        ),
      ],
    ),
    ServiceProvider(
      id: 'pro-warri-7',
      name: 'Kelvin Osagie',
      businessName: 'Delta Swift Relocations',
      profession: 'Home & Office Moving Hauler',
      categoryId: 'moving',
      rating: 4.85,
      reviewCount: 52,
      distanceKm: 4.2,
      approximateDistance: '4.2 km away',
      startingPriceAmount: 35000,
      startingPrice: 'From ₦35,000',
      location: 'NPA Expressway, Warri',
      avatarUrl: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=400&q=80',
      coverUrl: 'https://images.unsplash.com/photo-1600518464441-9154a4dea21b?auto=format&fit=crop&w=900&q=80',
      isVerified: true,
      badgeTitle: 'Insured Hauler',
      bio: 'Professional interstate and local mover equipped with enclosed box trucks, furniture blankets, and trained loaders.',
      workingHours: 'Mon – Sat: 7:00 AM – 7:00 PM',
      availability: 'Available Today',
      services: [
        ProviderServiceOffering(
          id: 's-12',
          title: 'Standard 2-Bedroom Moving Truck & 2 Loaders',
          description: 'Enclosed 3-ton truck with safe packaging, loading, transit, and unloading.',
          price: '₦35,000',
          priceAmount: 35000,
          duration: 'Half day',
        ),
      ],
      gallery: [
        'https://images.unsplash.com/photo-1600518464441-9154a4dea21b?auto=format&fit=crop&w=600&q=80',
      ],
      reviews: [
        ProviderReview(
          id: 'r-8',
          userName: 'Osita Nwosu',
          userAvatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
          rating: 4.9,
          date: '2 weeks ago',
          comment: 'Moved our duplex contents without a single scratch on any glass or electronics.',
        ),
      ],
    ),
    ServiceProvider(
      id: 'pro-warri-8',
      name: 'Tariye Johnson',
      businessName: 'Helios Smart Energy',
      profession: 'Solar Inverter & Lithium Battery Tech',
      categoryId: 'electrical',
      rating: 4.98,
      reviewCount: 93,
      distanceKm: 1.5,
      approximateDistance: '1.5 km away',
      startingPriceAmount: 25000,
      startingPrice: 'From ₦25,000',
      location: 'Ogunu Rd, Warri',
      avatarUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&w=400&q=80',
      coverUrl: 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&w=900&q=80',
      isVerified: true,
      badgeTitle: 'Solar Certified',
      bio: 'Renewable energy engineer certified in Felicity, Growatt, and Deye hybrid solar inverter setups and lithium iron phosphate (LiFePO4) battery balancing.',
      workingHours: 'Mon – Sat: 8:00 AM – 6:00 PM',
      availability: 'Available Today',
      services: [
        ProviderServiceOffering(
          id: 's-13',
          title: '5kVA Hybrid Solar Inverter Installation & Balancing',
          description: 'DC circuit breaker box, surge protection device (SPD), and load segregation wiring.',
          price: '₦25,000',
          priceAmount: 25000,
          duration: '3 - 4 hrs',
        ),
      ],
      gallery: [
        'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&w=600&q=80',
      ],
      reviews: [
        ProviderReview(
          id: 'r-9',
          userName: 'Madam Ejiro',
          userAvatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=200&q=80',
          rating: 5.0,
          date: '3 weeks ago',
          comment: 'Tariye upgraded our home to a 24V solar inverter. Clear energy audit and neat trunking.',
        ),
      ],
    ),
    ServiceProvider(
      id: 'pro-warri-9',
      name: 'Fatima Bello',
      businessName: 'PrimeClean Facility Managers',
      profession: 'Post-Construction & Commercial Janitorial',
      categoryId: 'cleaning',
      rating: 4.90,
      reviewCount: 68,
      distanceKm: 3.1,
      approximateDistance: '3.1 km away',
      startingPriceAmount: 15000,
      startingPrice: 'From ₦15,000',
      location: 'Edjeba, Warri',
      avatarUrl: 'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=400&q=80',
      coverUrl: 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=900&q=80',
      isVerified: true,
      badgeTitle: 'Eco Partner',
      bio: 'Post-construction deburring, paint spatter scraping, floor buffing, and commercial deep cleaning specialist.',
      workingHours: 'Mon – Sat: 7:00 AM – 6:00 PM',
      availability: 'Available Today',
      services: [
        ProviderServiceOffering(
          id: 's-14',
          title: 'Post-Construction Deep Wash & Scrub',
          description: 'Industrial tile scrubber machine treatment, cement/grout haze removal, and glass polish.',
          price: '₦20,000',
          priceAmount: 20000,
          duration: 'Full day',
        ),
      ],
      gallery: [
        'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=600&q=80',
      ],
      reviews: [
        ProviderReview(
          id: 'r-10',
          userName: 'Arc. Roland Boyo',
          userAvatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
          rating: 4.9,
          date: '1 month ago',
          comment: 'Handled post-construction cleanup for our newly completed office annex in Edjeba.',
        ),
      ],
    ),
    ServiceProvider(
      id: 'pro-warri-10',
      name: 'Emeka Okafor',
      businessName: 'Okafor Borehole & Industrial Piping',
      profession: 'Borehole Submersible Pumps & Filtration',
      categoryId: 'plumbing',
      rating: 4.86,
      reviewCount: 41,
      distanceKm: 4.8,
      approximateDistance: '4.8 km away',
      startingPriceAmount: 14000,
      startingPrice: 'From ₦14,000',
      location: 'Udu Rd, Warri',
      avatarUrl: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=400&q=80',
      coverUrl: 'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?auto=format&fit=crop&w=900&q=80',
      isVerified: false,
      badgeTitle: 'Experienced Pro',
      bio: 'Borehole casing inspection, water filtration media replacement (activated carbon & sand filters), and high-head submersible pump recovery.',
      workingHours: 'Mon – Sat: 8:00 AM – 6:00 PM',
      availability: 'Available Today',
      services: [
        ProviderServiceOffering(
          id: 's-15',
          title: 'Water Treatment Media Replacement',
          description: 'Silica sand, manganese greensand, and granular activated carbon replenishment.',
          price: '₦14,000',
          priceAmount: 14000,
          duration: '3 hrs',
        ),
      ],
      gallery: [
        'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?auto=format&fit=crop&w=600&q=80',
      ],
      reviews: [
        ProviderReview(
          id: 'r-11',
          userName: 'Mr. Ken Omatsola',
          userAvatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=200&q=80',
          rating: 4.8,
          date: '2 months ago',
          comment: 'Emeka restored clean water to our compound by replacing the iron-removal filtration media.',
        ),
      ],
    ),
  ];
}
