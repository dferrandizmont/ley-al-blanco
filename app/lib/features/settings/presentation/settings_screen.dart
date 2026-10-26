import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bootstrap/app_bootstrap.dart';
import '../../../core/format/app_date_format.dart';
import '../../../core/format/edition_label.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_setting.dart';
import '../../../core/widgets/apto_app_bar.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/raised_card.dart';
import '../../content/data/content_manifest.dart';
import '../../progress_transfer/presentation/data_transfer_card.dart';
import '../application/settings_providers.dart';

/// Appearance, progress transfer, bank details, help and licenses.
///
/// Every outside link (source, support, privacy policy) opens in an external
/// application through [urlLauncherProvider]; the support and privacy rows
/// exist only when their `--dart-define` is set ([SettingsLinks]).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final manifest = ref.watch(
      bootstrapProvider.select((boot) => boot.value?.manifest),
    );
    final links = ref.watch(settingsLinksProvider);
    return Scaffold(
      appBar: AptoAppBar(title: l10n.settingsTitle),
      body: SafeArea(
        child: PageBody(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Sp.page,
              Sp.s,
              Sp.page,
              Sp.section,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Section(
                  label: l10n.settingsAppearanceSection,
                  child: const _AppearanceCard(),
                ),
                _Section(
                  label: l10n.settingsDataSection,
                  child: const DataTransferCard(),
                ),
                if (manifest != null)
                  _Section(
                    label: l10n.settingsBankSection,
                    child: _BankCard(manifest: manifest),
                  ),
                _Section(
                  label: l10n.settingsHelpSection,
                  child: _HelpCard(links: links),
                ),
                _Footer(manifest: manifest),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "18 oct 2026" from an ISO date; the text itself when it is not one.
String _shortDate(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  return const AppDateFormat().dayMonthYear(date);
}

/// "18/10/2026" from an ISO date (spec §3.2: «consultado el dd/mm/aaaa»); the
/// text itself when it is not one.
String _numericDate(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year.toString().padLeft(4, '0')}';
}

/// Opens [uri] outside the app; a snack bar says so when nothing could.
Future<void> _openExternal(BuildContext context, WidgetRef ref, Uri uri) async {
  final failed = context.l10n.settingsOpenFailed;
  final messenger = ScaffoldMessenger.of(context);
  final opened = await ref.read(urlLauncherProvider).open(uri);
  if (opened) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(failed)));
}

/// An overline and the card below it.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
            child: Overline(label),
          ),
          const SizedBox(height: Sp.s),
          RaisedCard(child: child),
        ],
      ),
    );
  }
}

/// APARIENCIA: Sistema / Claro / Oscuro.
class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(themeModeProvider);
    return Padding(
      padding: const EdgeInsets.all(Sp.l),
      child: _ThemeSegments(
        groupLabel: l10n.settingsThemeGroup,
        selected: mode,
        options: [
          (ThemeMode.system, l10n.settingsThemeSystem),
          (ThemeMode.light, l10n.settingsThemeLight),
          (ThemeMode.dark, l10n.settingsThemeDark),
        ],
        onChanged: (value) => ref.read(themeModeProvider.notifier).set(value),
      ),
    );
  }
}

/// A segmented control on a `ringTrack` track: the chosen segment is a raised
/// pill with a `primary` border. A radio group for screen readers; every
/// segment is at least 48 dp tall ([Sp.touch]).
///
/// When the longest label does not fit on one line in a third of the track
/// (large text, small phones) the three options are stacked as a vertical
/// list, each with a radio icon, instead of shrinking each text on its own.
class _ThemeSegments extends StatelessWidget {
  const _ThemeSegments({
    required this.groupLabel,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String groupLabel;
  final ThemeMode selected;
  final List<(ThemeMode, String)> options;
  final ValueChanged<ThemeMode> onChanged;

  /// Whether every label fits in one line in a segment of [width] dp.
  bool _fitsSideBySide(BuildContext context, double width) {
    final style = _segmentStyle(context, selected: true);
    final scaler = MediaQuery.textScalerOf(context);
    final segment =
        (width - 2 * Sp.xs) / options.length - 2 * (Sp.s + Sp.borderStrong);
    for (final (_, label) in options) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final fits = painter.width <= segment;
      painter.dispose();
      if (!fits) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      role: SemanticsRole.radioGroup,
      container: true,
      label: groupLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = !_fitsSideBySide(context, constraints.maxWidth);
          final segments = [
            for (final (mode, label) in options)
              _Segment(
                label: label,
                selected: mode == selected,
                showRadio: stacked,
                onTap: () => onChanged(mode),
              ),
          ];
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colors.ringTrack,
              borderRadius: stacked ? Rad.optionRadius : Rad.pillRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(Sp.xs),
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: segments,
                    )
                  : Row(
                      children: [
                        for (final segment in segments)
                          Expanded(child: segment),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

TextStyle _segmentStyle(BuildContext context, {required bool selected}) {
  final colors = context.colors;
  return context.typo.chip.copyWith(
    color: selected ? colors.textPrimary : colors.textSecondary,
  );
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.showRadio,
    required this.onTap,
  });

  final String label;
  final bool selected;

  /// Draws a radio icon before the label (the stacked layout).
  final bool showRadio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The chosen segment gets a `primary` border (3:1 against the track in
    // both themes); the others keep a transparent one so nothing shifts.
    final border = Border.all(
      color: selected ? colors.primary : Colors.transparent,
      width: Sp.borderStrong,
    );
    final decoration = selected
        ? raisedDecoration(
            colors,
            borderRadius: Rad.pillRadius,
            shadows: AptoShadows.small(colors),
          ).copyWith(border: border)
        : BoxDecoration(borderRadius: Rad.pillRadius, border: border);
    final text = Text(label, style: _segmentStyle(context, selected: selected));
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.state),
        curve: Motion.curve,
        constraints: const BoxConstraints(minHeight: Sp.touch),
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Sp.s,
                vertical: Sp.s,
              ),
              child: showRadio
                  ? Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: IconSize.base,
                          color: selected
                              ? colors.primary
                              : colors.outlineStrong,
                        ),
                        const SizedBox(width: Sp.m),
                        Expanded(child: text),
                      ],
                    )
                  : Center(child: text),
            ),
          ),
        ),
      ),
    );
  }
}

/// BANCO DE PREGUNTAS: edition, real question count, date and the source.
class _BankCard extends ConsumerWidget {
  const _BankCard({required this.manifest});

  final ContentManifest manifest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final source = Uri.tryParse(manifest.sourceUrl);
    return Column(
      children: [
        _InfoRow(
          label: l10n.settingsBankEdition,
          value: l10n.settingsBankEditionValue(editionLabel(manifest.edition)),
        ),
        const CardDivider(),
        _InfoRow(
          label: l10n.settingsBankQuestions,
          value: '${manifest.questionCount}',
        ),
        const CardDivider(),
        _InfoRow(
          label: l10n.settingsBankRetrieved,
          value: _shortDate(manifest.retrieved),
        ),
        if (source != null && source.hasAuthority) ...[
          const CardDivider(),
          _LinkRow(
            title: l10n.settingsBankSource,
            icon: Icons.open_in_new_rounded,
            onTap: () => _openExternal(context, ref, source),
          ),
        ],
      ],
    );
  }
}

/// A label on the left and its value on the right (it wraps on a narrow
/// screen or a big text size).
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sp.touch + Sp.s),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.m),
          child: Row(
            children: [
              Text(label, style: typo.rowTitle),
              const SizedBox(width: Sp.l),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: AptoTypography.tabular(
                    typo.body.copyWith(color: context.colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AYUDA: support e-mail and privacy policy; each row only with its value.
class _HelpCard extends ConsumerWidget {
  const _HelpCard({required this.links});

  final SettingsLinks links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final support = links.support;
    final privacy = links.privacy;
    final version = ref.watch(appInfoProvider).value?.label ?? '';
    return Column(
      children: [
        if (support != null)
          _LinkRow(
            title: l10n.settingsSupportTitle,
            subtitle: l10n.settingsSupportSubtitle,
            icon: Icons.chevron_right_rounded,
            onTap: () => _writeToSupport(context, ref, support),
          ),
        if (support != null && privacy != null) const CardDivider(),
        if (privacy != null)
          _LinkRow(
            title: l10n.settingsPrivacyPolicy,
            icon: Icons.open_in_new_rounded,
            onTap: () => _openExternal(context, ref, privacy),
          ),
        if (support != null || privacy != null) const CardDivider(),
        _LinkRow(
          title: l10n.settingsOpenSourceLicenses,
          icon: Icons.chevron_right_rounded,
          onTap: () => showLicensePage(
            context: context,
            applicationName: l10n.appTitle,
            applicationVersion: version,
          ),
        ),
      ],
    );
  }

  /// Opens the mail app with the app version and the system and its version
  /// prefilled (and nothing else: no phone model, no identifiers, no
  /// progress).
  Future<void> _writeToSupport(
    BuildContext context,
    WidgetRef ref,
    String address,
  ) async {
    final l10n = context.l10n;
    var version = '';
    try {
      version = (await ref.read(appInfoProvider.future)).label;
    } on Object {
      // No version known: the mail still opens.
    }
    if (!context.mounted) return;
    final system = await readSystemLabel(ref);
    if (!context.mounted) return;
    final uri = supportMailUri(
      address,
      subject: l10n.settingsSupportMailSubject(version),
      body: l10n.settingsSupportMailBody(version, system),
    );
    await _openExternal(context, ref, uri);
  }
}

/// A tappable row that opens something outside the app.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;
    final subtitle = this.subtitle;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sp.touch + Sp.s),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.l,
              vertical: Sp.m,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: typo.rowTitle),
                      if (subtitle != null) ...[
                        const SizedBox(height: Sp.xxs),
                        Text(subtitle, style: typo.subtitle),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Sp.m),
                Icon(
                  icon,
                  size: IconSize.base,
                  color: context.colors.outlineStrong,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The fixed legal notice (spec §3.2) and the app version.
class _Footer extends ConsumerWidget {
  const _Footer({required this.manifest});

  final ContentManifest? manifest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final caption = context.typo.caption.copyWith(
      color: context.colors.textPrimary,
      fontWeight: context.typo.rowTitle.fontWeight,
    );
    final manifest = this.manifest;
    final version = ref.watch(appInfoProvider).value?.label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.l),
      child: Column(
        children: [
          if (manifest != null)
            Text(
              l10n.settingsLegal(_numericDate(manifest.retrieved)),
              style: caption,
              textAlign: TextAlign.center,
            ),
          if (version != null) ...[
            const SizedBox(height: Sp.m),
            Text(
              l10n.settingsVersion(version),
              style: AptoTypography.tabular(caption),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
