import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/soama_colors.dart';
import 'glass_container.dart';

class SoamaSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onFilterTap;
  final String hintText;
  final bool readOnly;
  final bool showFilter;

  const SoamaSearchBar({
    super.key,
    this.controller,
    this.onChanged,
    this.onTap,
    this.onFilterTap,
    this.hintText = 'Search AC repair, generator tech, plumbers...',
    this.readOnly = false,
    this.showFilter = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;

    return GlassContainer(
      borderRadius: SoamaRadii.radiusPill,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: colors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: SoamaSpacing.xs),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              onTap: onTap,
              onChanged: onChanged,
              style: SoamaTypography.bodyMedium.copyWith(
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: SoamaTypography.bodyMedium.copyWith(
                  color: colors.textTertiary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
              ),
            ),
          ),
          if (showFilter) ...[
            Container(
              height: 20,
              width: 1,
              color: colors.border,
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
            ),
            IconButton(
              onPressed: onFilterTap,
              icon: Icon(
                Icons.tune_rounded,
                size: 18,
                color: colors.textPrimary,
              ),
              tooltip: 'Filter results',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }
}
