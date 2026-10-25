import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../shared/models/service_provider.dart';
import '../../../../shared/widgets/provider_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../providers/presentation/providers/provider_provider.dart';

class NearbyProfessionals extends ConsumerWidget {
  final VoidCallback? onSeeAllTap;
  final ValueChanged<ServiceProvider>? onProviderTap;
  final ValueChanged<ServiceProvider>? onBookTap;

  const NearbyProfessionals({
    super.key,
    this.onSeeAllTap,
    this.onProviderTap,
    this.onBookTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prosAsync = ref.watch(
      marketplaceProvidersProvider(const ProviderQueryParams()),
    );
    final pros = prosAsync.valueOrNull ?? ServiceProvider.nearbyPros;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Near you',
          actionText: 'See all',
          onActionTap: onSeeAllTap,
        ),
        const SizedBox(height: SoamaSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: pros.map((pro) {
              return Padding(
                padding: const EdgeInsets.only(bottom: SoamaSpacing.sm),
                child: ProviderCard(
                  provider: pro,
                  onTap: () => onProviderTap?.call(pro),
                  onBookTap: () => onBookTap?.call(pro),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
