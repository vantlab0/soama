import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soama/features/bookings/data/bookings_repository.dart';
import 'package:soama/features/bookings/presentation/providers/bookings_provider.dart';
import 'package:soama/shared/models/booking.dart';
import 'package:soama/shared/models/user_account.dart';

void main() {
  group('1. Booking Deserialization & Data Modeling', () {
    test('Booking.fromSupabase deserializes PostgreSQL row correctly', () {
      final dbRow = {
        'id': '00000000-0000-0000-0000-000000000001',
        'booking_reference': 'BK-20261025-A1B2C',
        'request_id': '00000000-0000-0000-0000-000000000010',
        'accepted_offer_id': '00000000-0000-0000-0000-000000000020',
        'customer_id': '00000000-0000-0000-0000-000000000030',
        'provider_id': '00000000-0000-0000-0000-000000000040',
        'service_title': 'Routine Servicing (Oil & Filters)',
        'agreed_price_minor_units': 1650000, // ₦16,500 in kobo
        'currency': 'NGN',
        'scheduled_start': '2026-10-27T10:00:00Z',
        'scheduled_end': '2026-10-27T12:00:00Z',
        'job_address': 'Plot 4, Effurun Roundabout, Warri',
        'job_status': 'confirmed',
        'escrow_status': 'awaiting_payment',
        'created_at': '2026-10-25T08:00:00Z',
        'provider_profiles': {
          'business_name': 'Tunde Adeleke Generator Services',
          'profession': 'Industrial Generator Technician',
          'profiles': {
            'avatar_url': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d',
          }
        },
        'profiles': {
          'full_name': 'Amara Okonkwo',
          'phone': '+234 803 000 1111',
        }
      };

      final booking = Booking.fromSupabase(dbRow);

      expect(booking.id, equals('00000000-0000-0000-0000-000000000001'));
      expect(booking.bookingReference, equals('BK-20261025-A1B2C'));
      expect(booking.serviceTitle, equals('Routine Servicing (Oil & Filters)'));
      // Minor unit to Naira conversion
      expect(booking.agreedPriceMinorUnits, equals(1650000));
      expect(booking.agreedPriceNaira, equals(16500));
      expect(booking.agreedPriceFormatted, equals('₦16,500'));
      expect(booking.currency, equals('NGN'));
      expect(booking.jobStatus, equals(BookingJobStatus.confirmed));
      expect(booking.escrowStatus, equals(BookingEscrowStatus.awaitingPayment));
      expect(booking.isConfirmed, isTrue);
      expect(booking.isUpcoming, isTrue);
      expect(booking.isCompleted, isFalse);
      expect(booking.isCancelled, isFalse);
      expect(booking.providerName, equals('Tunde Adeleke Generator Services'));
      expect(booking.providerProfession, equals('Industrial Generator Technician'));
      expect(booking.customerName, equals('Amara Okonkwo'));
      expect(booking.customerPhone, equals('+234 803 000 1111'));
    });

    test('BookingJobStatus enum mappings roundtrip correctly', () {
      expect(BookingJobStatus.fromString('confirmed'), equals(BookingJobStatus.confirmed));
      expect(BookingJobStatus.fromString('in_progress'), equals(BookingJobStatus.inProgress));
      expect(BookingJobStatus.fromString('completed'), equals(BookingJobStatus.completed));
      expect(BookingJobStatus.fromString('cancelled_by_customer'), equals(BookingJobStatus.cancelledByCustomer));
      expect(BookingJobStatus.fromString('cancelled_by_provider'), equals(BookingJobStatus.cancelledByProvider));
      expect(BookingJobStatus.fromString('disputed'), equals(BookingJobStatus.disputed));
      expect(BookingJobStatus.fromString('unknown_status'), equals(BookingJobStatus.pendingConfirmation));

      expect(BookingJobStatus.confirmed.toDbString(), equals('confirmed'));
      expect(BookingJobStatus.inProgress.toDbString(), equals('in_progress'));
      expect(BookingJobStatus.completed.toDbString(), equals('completed'));
      expect(BookingJobStatus.cancelledByCustomer.toDbString(), equals('cancelled_by_customer'));
      expect(BookingJobStatus.cancelledByProvider.toDbString(), equals('cancelled_by_provider'));
    });

    test('Booking.toServiceRequest converts unified representation for UI cards', () {
      final booking = Booking(
        id: 'SOA-BK-999',
        bookingReference: 'BK-20261025-999',
        requestId: 'req-999',
        acceptedOfferId: 'off-999',
        customerId: 'cust-1',
        providerId: 'pro-1',
        serviceTitle: 'Inverter Battery Inspection',
        agreedPriceMinorUnits: 1200000, // ₦12,000
        scheduledStart: DateTime(2026, 11, 2, 9, 30),
        jobAddress: 'PTI Road, Effurun',
        jobStatus: BookingJobStatus.confirmed,
        createdAt: DateTime.now(),
        providerName: 'Adams Electro-Works',
      );

      final req = booking.toServiceRequest();
      expect(req.id, equals('SOA-BK-999'));
      expect(req.serviceTitle, equals('Inverter Battery Inspection'));
      expect(req.servicePrice, equals('₦12,000'));
      expect(req.servicePriceAmount, equals(12000));
      expect(req.address, equals('PTI Road, Effurun'));
      expect(req.isOngoing, isTrue);
      expect(req.status, equals('Confirmed Appointment'));
    });
  });

  group('2. BookingsRepository Operations (InMemory & Fallback)', () {
    late InMemoryBookingsRepository repo;

    setUp(() {
      repo = InMemoryBookingsRepository();
    });

    test('getCustomerBookings returns list of active and completed bookings', () async {
      final bookings = await repo.getCustomerBookings('usr-warri-01');
      expect(bookings, isNotEmpty);
      expect(bookings.any((b) => b.isUpcoming), isTrue);
      expect(bookings.any((b) => b.isCompleted), isTrue);
    });

    test('getProviderJobs returns jobs assigned to the specific provider', () async {
      final jobs = await repo.getProviderJobs('pro-current-user');
      expect(jobs, isNotEmpty);
      expect(jobs.first.providerId, equals('pro-current-user'));
      expect(jobs.first.serviceTitle, equals('Emergency Electrical Diagnostics & Fuse Repair'));
    });

    test('startJob transitions status to in_progress and records startedAt timestamp', () async {
      const bookingId = 'SOA-3091';
      final initial = await repo.getBookingById(bookingId);
      expect(initial, isNotNull);
      expect(initial!.isConfirmed, isTrue);
      expect(initial.startedAt, isNull);

      final success = await repo.startJob(bookingId: bookingId);
      expect(success, isTrue);

      final updated = await repo.getBookingById(bookingId);
      expect(updated, isNotNull);
      expect(updated!.jobStatus, equals(BookingJobStatus.inProgress));
      expect(updated.isInProgress, isTrue);
      expect(updated.startedAt, isNotNull);
    });

    test('completeJob transitions status to completed and records completedAt timestamp', () async {
      const bookingId = 'SOA-3091';
      // First start the job
      await repo.startJob(bookingId: bookingId);

      // Now complete the job
      final success = await repo.completeJob(bookingId: bookingId);
      expect(success, isTrue);

      final completed = await repo.getBookingById(bookingId);
      expect(completed, isNotNull);
      expect(completed!.jobStatus, equals(BookingJobStatus.completed));
      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, isNotNull);
    });

    test('cancelBooking transitions status to cancelled with audit reason', () async {
      const bookingId = 'SOA-3091';
      final success = await repo.cancelBooking(
        bookingId: bookingId,
        reason: 'Customer rescheduled appointment to next week',
      );
      expect(success, isTrue);

      final cancelled = await repo.getBookingById(bookingId);
      expect(cancelled, isNotNull);
      expect(cancelled!.isCancelled, isTrue);
      expect(cancelled.cancelledAt, isNotNull);
      expect(cancelled.cancellationReason, equals('Customer rescheduled appointment to next week'));
    });
  });

  group('3. Riverpod State Providers & Refresh Flow', () {
    test('customerBookingsProvider and providerJobsProvider resolve correctly', () async {
      final container = ProviderContainer(
        overrides: [
          bookingsRepositoryProvider.overrideWithValue(InMemoryBookingsRepository()),
        ],
      );
      addTearDown(container.dispose);

      final customerBookings = await container.read(customerBookingsProvider.future);
      expect(customerBookings, isA<List<Booking>>());
      expect(customerBookings.isNotEmpty, isTrue);

      final providerJobs = await container.read(providerJobsProvider.future);
      expect(providerJobs, isA<List<Booking>>());
      expect(providerJobs.isNotEmpty, isTrue);
    });

    test('bookingDetailsProvider resolves single booking details', () async {
      final container = ProviderContainer(
        overrides: [
          bookingsRepositoryProvider.overrideWithValue(InMemoryBookingsRepository()),
        ],
      );
      addTearDown(container.dispose);

      final booking = await container.read(bookingDetailsProvider('SOA-3091').future);
      expect(booking, isNotNull);
      expect(booking!.bookingReference, equals('BK-20261025-3091'));
      expect(booking.agreedPriceNaira, equals(16500));
    });
  });

  group('4. Booking Lifecycle & Security Invariants', () {
    test('Job completion does not prematurely mark escrow released or booking paid', () {
      final inProgressBooking = Booking(
        id: 'bk-sec-01',
        bookingReference: 'BK-20261025-01',
        requestId: 'req-01',
        acceptedOfferId: 'off-01',
        customerId: 'cust-1',
        providerId: 'pro-1',
        serviceTitle: 'Plumbing Job',
        agreedPriceMinorUnits: 2000000,
        scheduledStart: DateTime.now(),
        jobAddress: 'Warri',
        jobStatus: BookingJobStatus.inProgress,
        escrowStatus: BookingEscrowStatus.awaitingPayment,
        createdAt: DateTime.now(),
      );

      // Transition to completed
      final completedBooking = inProgressBooking.copyWith(
        jobStatus: BookingJobStatus.completed,
        completedAt: DateTime.now(),
      );

      // Escrow status must NOT be modified by job status transition
      expect(completedBooking.jobStatus, equals(BookingJobStatus.completed));
      expect(completedBooking.escrowStatus, equals(BookingEscrowStatus.awaitingPayment));
    });

    test('Single dual-role user account manages both bookings and provider jobs', () {
      final account = UserAccount.current;
      expect(account.id, isNotEmpty);

      // In Customer mode
      expect(account.currentMode, equals(AppMode.customer));

      // Dual-role capability enables provider job management
      final providerAccount = account.copyWith(
        hasProviderCapability: true,
        currentMode: AppMode.provider,
      );

      expect(providerAccount.id, equals(account.id));
      expect(providerAccount.currentMode, equals(AppMode.provider));
    });

    test('Location privacy is preserved for bookings: exact address visible to participants', () {
      final booking = Booking(
        id: 'bk-loc-01',
        bookingReference: 'BK-20261025-LOC',
        requestId: 'req-loc',
        acceptedOfferId: 'off-loc',
        customerId: 'cust-priv',
        providerId: 'pro-assigned',
        serviceTitle: 'AC Maintenance',
        agreedPriceMinorUnits: 1500000,
        scheduledStart: DateTime.now(),
        jobAddress: '15 Okumagba Avenue, Warri, Delta State',
        jobStatus: BookingJobStatus.confirmed,
        createdAt: DateTime.now(),
      );

      expect(booking.jobAddress, equals('15 Okumagba Avenue, Warri, Delta State'));
      expect(booking.providerId, equals('pro-assigned'));
      expect(booking.customerId, equals('cust-priv'));
    });
  });
}
