import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/soama_colors.dart';

/// Clean top app bar with solid background and crisp bottom border.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final double height;
  final double blurSigma;

  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.height = 60.0,
    this.blurSigma = 0.0,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Container(
      height: height + statusBarHeight,
      padding: EdgeInsets.only(top: statusBarHeight),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.border,
            width: 0.8,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SoamaSpacing.md),
        child: NavigationToolbar(
          leading: leading,
          middle: title,
          trailing: actions != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!,
                )
              : null,
        ),
      ),
    );
  }
}
