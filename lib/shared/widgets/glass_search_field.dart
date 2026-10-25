import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/soama_colors.dart';
import 'glass_surface.dart';

class GlassSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onTrailingActionTap;
  final IconData? trailingIcon;
  final String? trailingTooltip;
  final String hintText;
  final bool readOnly;
  final bool autofocus;
  final FocusNode? focusNode;

  const GlassSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onTrailingActionTap,
    this.trailingIcon = Icons.tune_rounded,
    this.trailingTooltip = 'Filter services',
    this.hintText = 'What service do you need?',
    this.readOnly = false,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<GlassSearchField> createState() => _GlassSearchFieldState();
}

class _GlassSearchFieldState extends State<GlassSearchField> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;
  bool _isFocused = false;
  bool _internalFocusNode = false;
  bool _internalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _internalFocusNode = true;
    } else {
      _focusNode = widget.focusNode!;
    }

    if (widget.controller == null) {
      _controller = TextEditingController();
      _internalController = true;
    } else {
      _controller = widget.controller!;
    }

    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleTextChange);
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _handleTextChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.removeListener(_handleTextChange);
    if (_internalFocusNode) _focusNode.dispose();
    if (_internalController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;
    final isReducedMotion = SoamaMotion.isReducedMotion(context);

    return AnimatedScale(
      scale: _isFocused && !isReducedMotion ? 1.01 : 1.0,
      duration: SoamaMotion.standard,
      curve: SoamaMotion.easeOutSpring,
      child: GlassSurface(
        borderRadius: SoamaRadii.radiusPill,
        blurIntensity: GlassBlurIntensity.heavy,
        borderWidth: _isFocused ? 1.4 : 1.0,
        borderColor: _isFocused
            ? colors.accent.withOpacity(0.85)
            : colors.glassBorder,
        backgroundColor: isDark
            ? const Color(0xFF1B1D24).withOpacity(_isFocused ? 0.95 : 0.82)
            : Colors.white.withOpacity(_isFocused ? 0.98 : 0.88),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
        child: Semantics(
          textField: true,
          label: widget.hintText,
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 20,
                color: _isFocused ? colors.accent : colors.textSecondary,
              ),
              const SizedBox(width: SoamaSpacing.xs),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  readOnly: widget.readOnly,
                  autofocus: widget.autofocus,
                  textInputAction: TextInputAction.search,
                  onTap: widget.onTap,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: SoamaTypography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: SoamaTypography.bodyMedium.copyWith(
                      color: colors.textTertiary,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search query',
                  icon: Icon(
                    Icons.cancel_rounded,
                    size: 18,
                    color: colors.textTertiary,
                  ),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged?.call('');
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              if (widget.trailingIcon != null && widget.onTrailingActionTap != null) ...[
                Container(
                  height: 20,
                  width: 1,
                  color: colors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 6.0),
                ),
                IconButton(
                  tooltip: widget.trailingTooltip,
                  icon: Icon(
                    widget.trailingIcon,
                    size: 19,
                    color: _isFocused ? colors.accent : colors.textPrimary,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onTrailingActionTap?.call();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
