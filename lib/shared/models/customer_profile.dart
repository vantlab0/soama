class SavedAddress {
  final String id;
  final String label;
  final String address;
  final bool isDefault;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    this.isDefault = false,
  });

  SavedAddress copyWith({
    String? label,
    String? address,
    bool? isDefault,
  }) {
    return SavedAddress(
      id: id,
      label: label ?? this.label,
      address: address ?? this.address,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class CustomerNotificationPreferences {
  final bool bookingAlerts;
  final bool chatAlerts;
  final bool priceOfferUpdates;
  final bool smsReminders;

  const CustomerNotificationPreferences({
    this.bookingAlerts = true,
    this.chatAlerts = true,
    this.priceOfferUpdates = true,
    this.smsReminders = true,
  });

  CustomerNotificationPreferences copyWith({
    bool? bookingAlerts,
    bool? chatAlerts,
    bool? priceOfferUpdates,
    bool? smsReminders,
  }) {
    return CustomerNotificationPreferences(
      bookingAlerts: bookingAlerts ?? this.bookingAlerts,
      chatAlerts: chatAlerts ?? this.chatAlerts,
      priceOfferUpdates: priceOfferUpdates ?? this.priceOfferUpdates,
      smsReminders: smsReminders ?? this.smsReminders,
    );
  }
}

class CustomerProfile {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? avatarUrl;
  final String locationArea;
  final List<SavedAddress> savedAddresses;
  final CustomerNotificationPreferences notificationPreferences;

  const CustomerProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.avatarUrl,
    required this.locationArea,
    required this.savedAddresses,
    required this.notificationPreferences,
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'CU';
  }

  CustomerProfile copyWith({
    String? fullName,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
    String? locationArea,
    List<SavedAddress>? savedAddresses,
    CustomerNotificationPreferences? notificationPreferences,
  }) {
    return CustomerProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      locationArea: locationArea ?? this.locationArea,
      savedAddresses: savedAddresses ?? this.savedAddresses,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
    );
  }

  static CustomerProfile current = const CustomerProfile(
    id: 'cust-warri-01',
    fullName: 'Kolawole Adams',
    email: 'kolawole.adams@soama.ng',
    phoneNumber: '+234 803 123 4567',
    avatarUrl: null,
    locationArea: 'Airport Road, Warri',
    savedAddresses: [
      SavedAddress(
        id: 'addr-1',
        label: 'Home',
        address: '14 Airport Road, Effurun, Warri, Delta State',
        isDefault: true,
      ),
      SavedAddress(
        id: 'addr-2',
        label: 'Office',
        address: 'Plot 8, NPA Expressway, Warri, Delta State',
        isDefault: false,
      ),
    ],
    notificationPreferences: CustomerNotificationPreferences(),
  );
}
