import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'round_icon_button.dart';

/// The app bar of the secondary screens: a round raised back button and the
/// title in 19 / 700, on the sand background; optionally round [actions] on
/// the right.
class AptoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AptoAppBar({super.key, required this.title, this.actions = const []});

  final String title;

  /// Round buttons (44 dp circles) at the right edge, e.g. the search icon.
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(Sp.pillHeight + Sp.s);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: Sp.page + Sp.touch + Sp.s,
      // The 48 dp box starts [Sp.roundButtonInset] before the page margin, so
      // the visible 44 dp circle starts exactly at the margin (16 dp).
      leading: Padding(
        padding: const EdgeInsets.only(left: Sp.page - Sp.roundButtonInset),
        // Aligned left, not centred: in a wider slot the button would drift
        // away from the margin.
        child: Align(
          alignment: Alignment.centerLeft,
          child: RoundIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
        ),
      ),
      title: Text(title),
      actions: [
        ...actions,
        if (actions.isNotEmpty)
          // The last circle ends on the page margin, like the back button.
          const SizedBox(width: Sp.page - Sp.roundButtonInset),
      ],
    );
  }
}
