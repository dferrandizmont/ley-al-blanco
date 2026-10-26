import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The search field of the app: a pill with a magnifier and, once there is
/// text, a clear button (48 dp), on the same surface as the cards. Used by the
/// glossary and by the question search.
class AptoSearchField extends StatelessWidget {
  const AptoSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.hintText,
    required this.clearTooltip,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  /// Hint shown while the field is empty (also its spoken label).
  final String hintText;

  /// Spoken label and tooltip of the clear button.
  final String clearTooltip;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final border = OutlineInputBorder(
      borderRadius: Rad.pillRadius,
      borderSide: BorderSide(color: colors.optionBorder, width: Sp.border),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      style: typo.body,
      cursorColor: colors.primary,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: typo.body.copyWith(color: colors.textSecondary),
        filled: true,
        fillColor: colors.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Sp.xl,
          vertical: Sp.m,
        ),
        prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: clearTooltip,
                icon: const Icon(Icons.close_rounded),
                onPressed: onClear,
              ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.primary, width: Sp.borderStrong),
        ),
      ),
    );
  }
}
