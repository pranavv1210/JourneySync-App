import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Premium text input with glass styling, animated borders, and consistent design.
class PremiumInput extends StatefulWidget {
  const PremiumInput({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.validator,
    this.onChanged,
    this.autofocus = false,
    this.enabled = true,
    this.suffix,
    this.prefix,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? minLines;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool autofocus;
  final bool enabled;
  final Widget? suffix;
  final Widget? prefix;

  @override
  State<PremiumInput> createState() => _PremiumInputState();
}

class _PremiumInputState extends State<PremiumInput> {
  bool _obscured = false;
  bool _hasFocus = false;
  String? _errorText;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscure;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  void _validate(String value) {
    if (widget.validator != null) {
      setState(() => _errorText = widget.validator!(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor =
        _hasFocus
            ? AppColors.primary
            : _errorText != null
            ? AppColors.error
            : AppColors.divider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            widget.label.toUpperCase(),
            style: AppTypography.labelMedium.copyWith(
              color: _hasFocus ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
        // Input Container
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: borderColor, width: _hasFocus ? 2 : 1.5),
            boxShadow:
                _hasFocus
                    ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : AppShadows.sm,
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                const SizedBox(width: AppSpacing.lg),
                Icon(
                  widget.icon,
                  color: _hasFocus ? AppColors.primary : AppColors.textTertiary,
                  size: 20,
                ),
              ],
              if (widget.prefix != null) widget.prefix!,
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: _obscured,
                  keyboardType: widget.keyboardType,
                  maxLines: widget.obscure ? 1 : widget.maxLines,
                  minLines: widget.minLines,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  onChanged: (value) {
                    _validate(value);
                    widget.onChanged?.call(value);
                  },
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: widget.icon != null ? 12 : 16,
                    ),
                  ),
                ),
              ),
              if (widget.obscure)
                IconButton(
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscured = !_obscured),
                ),
              if (widget.suffix != null) widget.suffix!,
              if (widget.suffix == null && !widget.obscure)
                const SizedBox(width: AppSpacing.md),
            ],
          ),
        ),
        // Error text
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              _errorText!,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
