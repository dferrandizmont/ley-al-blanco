import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The search field of the app: a pill with a magnifier and, once there is
/// text, a clear button (48 dp), on the same surface as the cards. Used by the
/// glossary and by the question search.
class AptoSearchField extends StatefulWidget {
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
  State<AptoSearchField> createState() => _AptoSearchFieldState();
}

class _AptoSearchFieldState extends State<AptoSearchField> {
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final hintText = widget.hintText;
    final colors = context.colors;
    final typo = context.typo;
    final border = OutlineInputBorder(
      borderRadius: Rad.pillRadius,
      borderSide: BorderSide(color: colors.optionBorder, width: Sp.border),
    );
    return Semantics(
      label: hintText,
      child: TextField(
        controller: controller,
        focusNode: _focus,
        onChanged: widget.onChanged,
        autofocus: widget.autofocus,
        style: typo.body,
        cursorColor: colors.primary,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          // The explicit semantics label also survives a non-empty field.
          hint: ExcludeSemantics(
            child: Text(
              hintText,
              style: typo.body.copyWith(color: colors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
                  tooltip: widget.clearTooltip,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    widget.onClear();
                    _focus.requestFocus();
                  },
                ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(
              color: colors.primary,
              width: Sp.borderStrong,
            ),
          ),
        ),
      ),
    );
  }
}
