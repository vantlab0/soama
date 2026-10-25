import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../shared/models/service_category.dart';
import '../../../../shared/widgets/service_category_item.dart';
import '../../../categories/presentation/providers/categories_provider.dart';

class PopularCategories extends ConsumerWidget {
  final String? selectedCategoryId;
  final ValueChanged<ServiceCategory>? onCategoryTap;

  const PopularCategories({
    super.key,
    this.selectedCategoryId,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? ServiceCategory.mockCategories;

    return SizedBox(
      height: 106,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: SoamaSpacing.sm),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat.id == selectedCategoryId;

          return SizedBox(
            width: 82,
            child: ServiceCategoryItem.compact(
              label: cat.title,
              icon: cat.icon,
              isSelected: isSelected,
              onTap: () => onCategoryTap?.call(cat),
            ),
          );
        },
      ),
    );
  }
}
