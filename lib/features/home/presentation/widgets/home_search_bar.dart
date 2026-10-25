import 'package:flutter/material.dart';
import '../../../../shared/widgets/glass_search_field.dart';

class HomeSearchBar extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final VoidCallback? onTap;

  const HomeSearchBar({
    super.key,
    this.onChanged,
    this.onFilterTap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GlassSearchField(
        onChanged: onChanged,
        onTap: onTap,
        onTrailingActionTap: onFilterTap,
        trailingTooltip: 'Filter services',
        hintText: 'What service do you need?',
      ),
    );
  }
}
