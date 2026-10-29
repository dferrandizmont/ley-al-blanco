import 'package:apto_armas/core/theme/app_theme.dart';
import 'package:apto_armas/core/widgets/action_card.dart';
import 'package:apto_armas/core/widgets/app_mark.dart';
import 'package:apto_armas/core/widgets/app_mark_painter.dart';
import 'package:apto_armas/core/widgets/article_chip.dart';
import 'package:apto_armas/core/widgets/explanation_body.dart';
import 'package:apto_armas/core/widgets/mastery_bar.dart';
import 'package:apto_armas/core/widgets/mock_navigator.dart';
import 'package:apto_armas/core/widgets/option_card.dart';
import 'package:apto_armas/core/widgets/overline.dart';
import 'package:apto_armas/core/widgets/pill_bar.dart';
import 'package:apto_armas/core/widgets/progress_header.dart';
import 'package:apto_armas/core/widgets/raised_card.dart';
import 'package:apto_armas/core/widgets/round_icon_button.dart';
import 'package:apto_armas/core/widgets/scroll_edge_fade.dart';
import 'package:apto_armas/core/widgets/buttons.dart';
import 'package:apto_armas/core/widgets/score_ring.dart';
import 'package:apto_armas/core/widgets/tema_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  scrollEdgeFadeTests();

  testWidgets('home cards can be activated by a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    var actionTaps = 0;
    var temaTaps = 0;
    try {
      await pumpApp(
        tester,
        Scaffold(
          body: Column(
            children: [
              ActionCard(
                icon: Icons.timer_rounded,
                title: 'Simulacro',
                onTap: () => actionTaps++,
              ),
              TemaCard(
                tema: 1,
                title: 'Tema',
                mastery: 0,
                mistakes: 0,
                onTap: () => temaTaps++,
              ),
            ],
          ),
        ),
      );
      for (final type in [ActionCard, TemaCard]) {
        final node = tester.getSemantics(find.byType(type));
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        node.owner!.performAction(node.id, SemanticsAction.tap);
      }
      expect(actionTaps, 1);
      expect(temaTaps, 1);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('TemaCard wraps mistakes at 320 dp with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      const Scaffold(
        body: Padding(
          padding: Sp.pageInsets,
          child: TemaCard(tema: 1, title: 'Tema', mastery: 0.4, mistakes: 123),
        ),
      ),
      textScale: 2,
    );
    expect(find.text('123 fallos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('ScoreRing', () {
    ScoreRingPainter painterOf(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(ScoreRing),
                    matching: find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is ScoreRingPainter,
                    ),
                  ),
                )
                .painter!
            as ScoreRingPainter;

    testWidgets('shows the percentage at 116 dp with stroke 8', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: Center(child: ScoreRing(value: 0.547, label: 'Probabilidad')),
        ),
      );
      expect(find.text('55 %'), findsOneWidget);
      // The label is spoken, not drawn (Inicio shows it as an overline).
      expect(find.text('Probabilidad'), findsNothing);
      expect(tester.getSize(find.byType(ScoreRing)), const Size(116, 116));
      final painter = painterOf(tester);
      expect(painter.value, 0.547);
      expect(painter.strokeWidth, 8);
      expect(painter.passMark, isNull);
    });

    testWidgets('null = unknown: empty ring and a dash, no number', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const Scaffold(body: Center(child: ScoreRing(value: null))),
      );
      expect(find.text('–'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(painterOf(tester).value, 0);
    });

    testWidgets('size, stroke, colour, pass mark and centre are configurable', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Scaffold(
          body: Center(
            child: ScoreRing(
              value: 0.85,
              size: 168,
              strokeWidth: 10,
              color: AptoColors.light.correct,
              passMark: 0.8,
              center: const Text('17'),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(ScoreRing)), const Size(168, 168));
      final painter = painterOf(tester);
      expect(painter.strokeWidth, 10);
      expect(painter.color, AptoColors.light.correct);
      expect(painter.trackColor, AptoColors.light.ringTrack);
      expect(painter.passMark, 0.8);
      expect(find.text('17'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('exposes label and percentage to screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Scaffold(
          body: Center(
            child: ScoreRing(value: 0.3, label: 'Probabilidad de aprobar'),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(ScoreRing)).label,
        'Probabilidad de aprobar: 30 %',
      );
      handle.dispose();
    });

    testWidgets('semanticsLabel replaces the spoken text', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Scaffold(
          body: Center(
            child: ScoreRing(
              value: 0.8,
              semanticsLabel: '16 / 20',
              center: Text('16'),
            ),
          ),
        ),
      );
      expect(tester.getSemantics(find.byType(ScoreRing)).label, '16 / 20');
      handle.dispose();
    });
  });

  testWidgets('MasteryBar clamps its value', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: Column(children: [MasteryBar(value: 1.5), MasteryBar(value: -1)]),
      ),
    );
    final bars = tester.widgetList<MasteryBar>(find.byType(MasteryBar));
    expect(bars.map((b) => b.value), [1.5, -1.0]);
    // Drawn clamped: the fill is full / empty.
    final fills = tester.widgetList<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(fills.map((f) => f.widthFactor), [1.0, 0.0]);
  });

  testWidgets('ProgressHeader: counter and bar', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: ProgressHeader(current: 3, total: 20, completed: 2)),
    );
    expect(find.text('3 / 20'), findsOneWidget);
    // The fill follows the answered questions, not the position.
    final fill = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(fill.widthFactor, closeTo(0.1, 1e-12));
    // The bar is 8 dp thick.
    expect(tester.getSize(find.byType(PillBar)).height, 8);
  });

  testWidgets('ProgressHeader puts the leading widget before the bar', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: ProgressHeader(
          current: 5,
          total: 68,
          leading: SizedBox.square(key: Key('lead'), dimension: 44),
        ),
      ),
    );
    final lead = tester.getRect(find.byKey(const Key('lead')));
    final bar = tester.getRect(find.byType(PillBar));
    expect(lead.right, lessThan(bar.left));
    expect(find.text('5 / 68'), findsOneWidget);
  });

  testWidgets('TemaCard: texts, mistakes only when > 0, tap', (tester) async {
    var taps = 0;
    Widget card(int mistakes) => Scaffold(
      body: TemaCard(
        tema: 4,
        title: 'Documentación y licencias',
        mastery: 0.45,
        mistakes: mistakes,
        onTap: () => taps++,
      ),
    );
    await pumpApp(tester, card(0));
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Documentación y licencias'), findsOneWidget);
    expect(find.text('Dominio 45 %'), findsOneWidget);
    expect(find.textContaining('fallo'), findsNothing);
    // The 40 dp mini ring (stroke 4) carries the mastery.
    final ring =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(TemaCard),
                    matching: find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is ScoreRingPainter,
                    ),
                  ),
                )
                .painter!
            as ScoreRingPainter;
    expect(ring.value, 0.45);
    expect(ring.strokeWidth, 4);
    await tester.tap(find.byType(TemaCard));
    expect(taps, 1);

    await pumpApp(tester, card(1));
    expect(find.text('1 fallo'), findsOneWidget);
    await pumpApp(tester, card(3));
    expect(find.text('3 fallos'), findsOneWidget);
  });

  testWidgets('TemaCard: below-chance line with attempts and 0 % mastery', (
    tester,
  ) async {
    Widget card({required bool hasAttempts, double mastery = 0}) => Scaffold(
      body: TemaCard(
        tema: 2,
        title: 'Categorías de armas',
        mastery: mastery,
        mistakes: 0,
        hasAttempts: hasAttempts,
      ),
    );

    // Without attempts the tema was never answered: no line.
    await pumpApp(tester, card(hasAttempts: false));
    expect(find.text('Dominio 0 %'), findsOneWidget);
    expect(find.text('Por debajo del azar: repasa la teoría'), findsNothing);

    // With attempts and 0 %: the line shows under the bar.
    await pumpApp(tester, card(hasAttempts: true));
    expect(find.text('Dominio 0 %'), findsOneWidget);
    expect(find.text('Por debajo del azar: repasa la teoría'), findsOneWidget);

    // With attempts and a real mastery: no line.
    await pumpApp(tester, card(hasAttempts: true, mastery: 0.45));
    expect(find.text('Dominio 45 %'), findsOneWidget);
    expect(find.text('Por debajo del azar: repasa la teoría'), findsNothing);
  });

  testWidgets('TemaCard: the below-chance line follows the rounding', (
    tester,
  ) async {
    Widget card(double mastery) => Scaffold(
      body: TemaCard(
        tema: 2,
        title: 'Categorías de armas',
        mastery: mastery,
        mistakes: 0,
        hasAttempts: true,
      ),
    );

    // 0.4 % is shown as 0 %: the warning shows.
    await pumpApp(tester, card(0.004));
    expect(find.text('Dominio 0 %'), findsOneWidget);
    expect(find.text('Por debajo del azar: repasa la teoría'), findsOneWidget);

    // 0.5 % is shown as 1 %: it does not.
    await pumpApp(tester, card(0.005));
    expect(find.text('Dominio 1 %'), findsOneWidget);
    expect(find.text('Por debajo del azar: repasa la teoría'), findsNothing);
  });

  testWidgets('TemaCard speaks the below-chance line with the mastery', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpApp(
        tester,
        const Scaffold(
          body: TemaCard(
            tema: 2,
            title: 'Categorías de armas',
            mastery: 0,
            mistakes: 0,
            hasAttempts: true,
          ),
        ),
      );
      final label = tester.getSemantics(find.byType(TemaCard)).label;
      expect(label, contains('Dominio 0 %'));
      expect(label, contains('Por debajo del azar: repasa la teoría'));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('TemaCard: the below-chance line fits at 320 dp with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      const Scaffold(
        body: Padding(
          padding: Sp.pageInsets,
          child: TemaCard(
            tema: 1,
            title: 'Funcionamiento y seguridad',
            mastery: 0,
            mistakes: 2,
            hasAttempts: true,
          ),
        ),
      ),
      textScale: 2,
    );
    const line = 'Por debajo del azar: repasa la teoría';
    expect(find.text(line), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The line stays inside the screen, wrapped in more than one line.
    final rect = tester.getRect(find.text(line));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
  });

  testWidgets('ProgressHeader: the pending counter counts the session', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: ProgressHeader(current: 1, total: 67, pending: true),
      ),
    );
    expect(find.text('1 de 67 pendientes'), findsOneWidget);
    expect(find.text('1 / 67'), findsNothing);
    // One pending question: singular.
    await pumpApp(
      tester,
      const Scaffold(body: ProgressHeader(current: 1, total: 1, pending: true)),
    );
    expect(find.text('1 de 1 pendiente'), findsOneWidget);
  });

  testWidgets('ProgressHeader speaks the pending counter', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpApp(
        tester,
        const Scaffold(
          body: ProgressHeader(current: 2, total: 67, pending: true),
        ),
      );
      expect(
        find.bySemanticsLabel('Pregunta 2 de 67 pendientes'),
        findsOneWidget,
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('ProgressHeader: the pending counter fits at 320 dp x2', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      const Scaffold(
        body: Padding(
          padding: Sp.pageInsets,
          child: ProgressHeader(current: 1, total: 67, pending: true),
        ),
      ),
      textScale: 2,
    );
    expect(find.text('1 de 67 pendientes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('ProgressHeader: the layout is decided for the whole session', () {
    /// Width of [text] in the counter style, at the text scale of the app.
    double counterWidth(BuildContext context, String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    /// The style of the counter, read from the rendered one.
    TextStyle counterStyle(WidgetTester tester, String counter) =>
        tester.widget<Text>(find.text(counter)).style!;

    /// Whether the counter sits on the same row as the bar.
    bool besideBar(WidgetTester tester, String counter) {
      final bar = tester.getRect(find.byType(PillBar));
      final text = tester.getRect(find.text(counter));
      return (bar.center.dy - text.center.dy).abs() < 0.5;
    }

    /// Pumps the header at a fixed width, with or without the close button.
    Future<void> pumpHeader(
      WidgetTester tester, {
      required double width,
      required int current,
      int total = 67,
      bool pending = true,
      bool close = false,
      double textScale = 1,
    }) async {
      await pumpApp(
        tester,
        Scaffold(
          body: SizedBox(
            width: width,
            child: ProgressHeader(
              current: current,
              total: total,
              pending: pending,
              leading: close
                  ? RoundIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Cerrar',
                      onPressed: () {},
                    )
                  : null,
            ),
          ),
        ),
        textScale: textScale,
      );
    }

    testWidgets('the counter goes on its own line below the 96 dp bar', (
      tester,
    ) async {
      // The practice by tema ("67 de 67 pendientes") and the plain ratio
      // ("67 / 67") decide the layout the same way.
      for (final (pending, counter) in [
        (true, '67 de 67 pendientes'),
        (false, '67 / 67'),
      ]) {
        await pumpHeader(tester, width: 320, current: 67, pending: pending);
        final context = tester.element(find.byType(ProgressHeader));
        final style = counterStyle(tester, counter);
        // The width that leaves exactly 96 dp to the bar.
        final fits =
            ProgressHeader.minBarWidth +
            Sp.m +
            counterWidth(context, counter, style);

        // Enough room: the counter stays next to the bar, which keeps 96 dp.
        await pumpHeader(
          tester,
          width: fits.ceil().toDouble(),
          current: 67,
          pending: pending,
        );
        expect(besideBar(tester, counter), isTrue, reason: counter);
        expect(
          tester.getSize(find.byType(PillBar)).width,
          greaterThanOrEqualTo(ProgressHeader.minBarWidth),
          reason: counter,
        );

        // One dp less: the counter goes on its own line.
        await pumpHeader(
          tester,
          width: fits.floor().toDouble() - 1,
          current: 67,
          pending: pending,
        );
        expect(besideBar(tester, counter), isFalse, reason: counter);
        expect(tester.takeException(), isNull, reason: counter);
      }
    });

    testWidgets('the layout does not change from question 9 to 10', (
      tester,
    ) async {
      await pumpHeader(tester, width: 320, current: 67);
      final context = tester.element(find.byType(ProgressHeader));
      final style = counterStyle(tester, '67 de 67 pendientes');
      final nine = counterWidth(context, '9 de 67 pendientes', style);
      final ten = counterWidth(context, '10 de 67 pendientes', style);
      final widest = counterWidth(context, '67 de 67 pendientes', style);
      // The index goes from one digit to two: the counter gets wider.
      expect(ten - nine, greaterThanOrEqualTo(1));

      // The width where "9 de 67 pendientes" fits next to the bar but
      // "10 de 67 pendientes" does not: the layout used to change here, in
      // the middle of a session.
      final width = (Sp.touch + Sp.m + Sp.m + ProgressHeader.minBarWidth + nine)
          .ceil()
          .toDouble();
      expect(
        width,
        lessThan(Sp.touch + Sp.m + Sp.m + ProgressHeader.minBarWidth + widest),
      );

      await pumpHeader(tester, width: width, current: 9, close: true);
      final atNine = besideBar(tester, '9 de 67 pendientes');
      expect(tester.takeException(), isNull);

      await pumpHeader(tester, width: width, current: 10, close: true);
      final atTen = besideBar(tester, '10 de 67 pendientes');
      expect(tester.takeException(), isNull);

      // The arrangement is the same in both questions, and it is the one of
      // the widest counter of the session, which does not fit next to the
      // bar at this width.
      expect(atNine, atTen);
      expect(atNine, isFalse);
    });
  });

  group('OptionCard', () {
    Future<void> pump(
      WidgetTester tester,
      OptionState state, {
      VoidCallback? onTap,
    }) => pumpApp(
      tester,
      Scaffold(
        body: OptionCard(
          letter: 'A',
          text: 'Texto',
          state: state,
          onTap: onTap,
        ),
      ),
    );

    Finder icons() => find.descendant(
      of: find.byType(OptionCard),
      matching: find.byType(Icon),
    );
    Finder letter() =>
        find.descendant(of: find.byType(OptionCard), matching: find.text('A'));

    testWidgets('leading circle per state (never colour alone)', (
      tester,
    ) async {
      // At rest and selected: the letter, no icon.
      for (final state in [OptionState.idle, OptionState.selected]) {
        await pump(tester, state);
        expect(icons(), findsNothing, reason: '$state');
        expect(letter(), findsOneWidget, reason: '$state');
      }
      // Judged: a check (right) or a cross (wrong) replaces the letter.
      final expected = {
        OptionState.correct: Icons.check_rounded,
        OptionState.revealedCorrect: Icons.check_rounded,
        OptionState.incorrect: Icons.close_rounded,
      };
      for (final entry in expected.entries) {
        await pump(tester, entry.key);
        expect(
          tester.widget<Icon>(icons()).icon,
          entry.value,
          reason: '${entry.key}',
        );
        expect(letter(), findsNothing, reason: '${entry.key}');
      }
    });

    testWidgets('card fill and border follow the state', (tester) async {
      final c = AptoColors.light;
      Future<(Color?, Color)> look(OptionState state) async {
        await pump(tester, state);
        final card = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(OptionCard),
                matching: find.byType(Material),
              )
              .first,
        );
        final side = (card.shape! as RoundedRectangleBorder).side;
        expect(side.width, 2);
        return (card.color, side.color);
      }

      expect(await look(OptionState.idle), (c.surfaceRaised, c.optionBorder));
      expect(await look(OptionState.selected), (c.primaryContainer, c.primary));
      expect(await look(OptionState.correct), (c.correctContainer, c.correct));
      expect(await look(OptionState.revealedCorrect), (
        c.correctContainer,
        c.correct,
      ));
      expect(await look(OptionState.incorrect), (
        c.incorrectContainer,
        c.incorrect,
      ));
    });

    testWidgets('the leading circle is 26 dp', (tester) async {
      await pump(tester, OptionState.idle);
      expect(
        find.descendant(
          of: find.byType(OptionCard),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 26 && w.height == 26,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('at least 56 dp tall and the whole card is tappable', (
      tester,
    ) async {
      var taps = 0;
      await pump(tester, OptionState.idle, onTap: () => taps++);
      final rect = tester.getRect(find.byType(OptionCard));
      expect(rect.height, greaterThanOrEqualTo(56));
      expect(rect.width, tester.getRect(find.byType(Scaffold)).width);
      // Both ends of the card respond.
      await tester.tapAt(rect.centerLeft + const Offset(2, 0));
      await tester.tapAt(rect.centerRight - const Offset(2, 0));
      expect(taps, 2);
    });

    testWidgets('a null onTap locks the card', (tester) async {
      await pump(tester, OptionState.correct);
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    });
  });

  group('ExplanationBody', () {
    Widget body({
      String? explanation,
      String? article,
      String? notice,
      bool? correct = true,
    }) => Scaffold(
      body: SingleChildScrollView(
        child: ExplanationBody(
          correct: correct,
          correctLetter: 'B',
          correctText: 'Segunda opción',
          explanation: explanation,
          article: article,
          notice: notice,
        ),
      ),
    );

    const noticeText =
        'Ojo: el cuestionario dice X; tras la reforma de 2023 el art. 5 dice Z.';

    /// The amber callout box (a DecoratedBox filled with noticeContainer).
    Finder noticeBox(AptoColors c) => find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == c.noticeContainer,
    );

    testWidgets('no notice, no callout', (tester) async {
      await pumpApp(tester, body(explanation: 'Texto.'));
      expect(find.text('Aviso: cambio en la norma'), findsNothing);
      expect(find.byIcon(Icons.info_rounded), findsNothing);
      expect(noticeBox(AptoColors.light), findsNothing);
      // An empty notice counts as none.
      await pumpApp(tester, body(explanation: 'Texto.', notice: '  '));
      expect(find.text('Aviso: cambio en la norma'), findsNothing);
    });

    testWidgets(
      'the notice is a callout above the explanation, below the answer',
      (tester) async {
        await pumpApp(
          tester,
          body(
            explanation: 'Porque lo dice el reglamento.',
            article: 'Art. 3 RD 137/1993',
            notice: noticeText,
          ),
        );
        expect(find.text('Aviso: cambio en la norma'), findsOneWidget);
        expect(find.text(noticeText), findsOneWidget);
        expect(find.byIcon(Icons.info_rounded), findsOneWidget);
        expect(noticeBox(AptoColors.light), findsOneWidget);

        double top(Finder f) => tester.getTopLeft(f).dy;
        final answer = top(find.text('B. Segunda opción'));
        final callout = top(find.text('Aviso: cambio en la norma'));
        final heading = top(find.text('Explicación'));
        final explanation = top(find.text('Porque lo dice el reglamento.'));
        final chip = top(find.byType(ArticleChip));
        expect(answer, lessThan(callout));
        expect(callout, lessThan(heading));
        expect(heading, lessThan(explanation));
        expect(explanation, lessThan(chip));
        // The official answer is still shown, untouched.
        expect(find.text('Correcto'), findsOneWidget);
      },
    );

    testWidgets('callout colours come from the notice tokens (not red)', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        final c = dark ? AptoColors.dark : AptoColors.light;
        await pumpApp(tester, body(notice: noticeText), dark: dark);
        final title = tester.widget<Text>(
          find.text('Aviso: cambio en la norma'),
        );
        final text = tester.widget<Text>(find.text(noticeText));
        final icon = tester.widget<Icon>(find.byIcon(Icons.info_rounded));
        expect(title.style!.color, c.onNoticeContainer);
        expect(text.style!.color, c.onNoticeContainer);
        expect(icon.color, c.onNoticeContainer);
        expect(noticeBox(c), findsOneWidget);
        expect(c.noticeContainer, isNot(c.incorrectContainer));
      }
    });

    testWidgets('a notice with no explanation keeps the placeholder', (
      tester,
    ) async {
      await pumpApp(tester, body(notice: noticeText));
      expect(find.text(noticeText), findsOneWidget);
      expect(find.text('Explicación en preparación'), findsOneWidget);
      expect(find.byType(ArticleChip), findsNothing);
    });

    testWidgets('the article chip shows only when there is an article', (
      tester,
    ) async {
      await pumpApp(
        tester,
        body(explanation: 'Texto.', notice: noticeText, article: null),
      );
      expect(find.byType(ArticleChip), findsNothing);
      await pumpApp(
        tester,
        body(explanation: 'Texto.', notice: noticeText, article: 'Art. 5'),
      );
      expect(find.byType(ArticleChip), findsOneWidget);
      expect(find.text('Art. 5'), findsOneWidget);
    });

    testWidgets('the callout is a labelled header for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, body(notice: noticeText));
      expect(
        tester.getSemantics(find.text('Aviso: cambio en la norma')),
        matchesSemantics(label: 'Aviso: cambio en la norma', isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('placeholder when there is no explanation, no chip', (
      tester,
    ) async {
      await pumpApp(tester, body());
      expect(find.text('Correcto'), findsOneWidget);
      expect(find.text('B. Segunda opción'), findsOneWidget);
      expect(find.text('Explicación en preparación'), findsOneWidget);
      expect(find.byType(ArticleChip), findsNothing);
      // No button of its own: "Siguiente" floats over the screen.
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets(
      'explanation text and article chip; incorrect verdict with cross',
      (tester) async {
        await pumpApp(
          tester,
          body(
            explanation: 'Porque lo dice el reglamento.',
            article: 'Art. 3 RD 137/1993',
            correct: false,
          ),
        );
        expect(find.text('Incorrecto'), findsOneWidget);
        expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
        expect(find.text('Porque lo dice el reglamento.'), findsOneWidget);
        expect(find.text('Explicación en preparación'), findsNothing);
        expect(find.text('Art. 3 RD 137/1993'), findsOneWidget);
      },
    );

    testWidgets('the verdict uses the text colours of the theme', (
      tester,
    ) async {
      Color verdictColor(String text) =>
          tester.widget<Text>(find.text(text)).style!.color!;
      await pumpApp(tester, body());
      expect(verdictColor('Correcto'), AptoColors.light.correctText);
      await pumpApp(tester, body(correct: false), dark: true);
      expect(verdictColor('Incorrecto'), AptoColors.dark.incorrectText);
    });

    testWidgets('a null verdict hides it (a question left blank)', (
      tester,
    ) async {
      await pumpApp(tester, body(correct: null));
      expect(find.text('Correcto'), findsNothing);
      expect(find.text('Incorrecto'), findsNothing);
    });
  });

  group('Sereno pieces', () {
    testWidgets('RaisedCard: shadow in light, divider border in dark', (
      tester,
    ) async {
      Widget card() => const Scaffold(
        body: Center(child: RaisedCard(child: SizedBox.square(dimension: 40))),
      );
      BoxDecoration decoration() =>
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byType(RaisedCard),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;

      await pumpApp(tester, card());
      var d = decoration();
      expect(d.color, AptoColors.light.surfaceRaised);
      expect(d.borderRadius, BorderRadius.circular(24));
      expect(d.boxShadow, isNotEmpty);
      expect(d.border, isNull);

      await pumpApp(tester, card(), dark: true);
      d = decoration();
      expect(d.color, AptoColors.dark.surfaceRaised);
      expect(d.boxShadow, isEmpty);
      expect(d.border, Border.all(color: AptoColors.dark.divider));
    });

    testWidgets(
      'RoundIconButton is 48 dp (44 drawn), speaks its tooltip and taps',
      (tester) async {
        final handle = tester.ensureSemantics();
        var taps = 0;
        await pumpApp(
          tester,
          Scaffold(
            body: Center(
              child: RoundIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Cerrar',
                onPressed: () => taps++,
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(RoundIconButton)),
          const Size(48, 48),
        );
        // The raised circle is 44 dp, centred in the 48 dp touch area.
        final circle = find.descendant(
          of: find.byType(RoundIconButton),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 44 && w.height == 44,
          ),
        );
        expect(tester.getSize(circle), const Size(44, 44));
        expect(
          tester.getCenter(circle),
          tester.getCenter(find.byType(RoundIconButton)),
        );
        // A tap in the ring around the circle counts too.
        await tester.tapAt(
          tester.getTopLeft(find.byType(RoundIconButton)) + const Offset(1, 24),
        );
        expect(taps, 1);
        expect(find.bySemanticsLabel('Cerrar'), findsOneWidget);
        await tester.tap(find.byType(RoundIconButton));
        expect(taps, 2);
        handle.dispose();
      },
    );

    testWidgets('AppMark scales with its size', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: Center(child: AppMark(size: 64))),
      );
      expect(tester.getSize(find.byType(AppMark)), const Size(64, 64));
      // Drawn by the shared painter (same geometry as the app icon).
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(AppMark),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(paint.painter, isA<AppMarkPainter>());
    });

    for (final dark in [false, true]) {
      testWidgets(
        'AppMark tile is the brand tile (${dark ? 'dark' : 'light'})',
        (tester) async {
          await pumpApp(
            tester,
            const Scaffold(body: Center(child: AppMark(size: 64))),
            dark: dark,
          );
          final c = dark ? AptoColors.dark : AptoColors.light;
          final tile = tester.widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(AppMark),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          expect((tile.decoration as BoxDecoration).color, c.brandTile);
          final painter =
              tester
                      .widget<CustomPaint>(
                        find.descendant(
                          of: find.byType(AppMark),
                          matching: find.byType(CustomPaint),
                        ),
                      )
                      .painter!
                  as AppMarkPainter;
          expect(painter.palette.arc, c.accent);
          expect(painter.palette.background, c.brandTile);
          expect(painter.background, isFalse);
        },
      );
    }

    testWidgets('TextActionButton and SecondaryButton share one icon size', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Scaffold(
          body: Column(
            children: [
              SecondaryButton(
                label: 'Anterior',
                icon: Icons.arrow_back_rounded,
                onPressed: () {},
              ),
              TextActionButton(
                label: 'Preguntas',
                icon: Icons.grid_view_rounded,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(icon.size, IconSize.button);
      }
      expect(find.byType(Icon), findsNWidgets(2));
    });

    testWidgets('Overline writes upper case but is spoken as written', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const Scaffold(body: Overline('Por tema')));
      expect(find.text('POR TEMA'), findsOneWidget);
      expect(find.bySemanticsLabel('Por tema'), findsOneWidget);
      handle.dispose();
    });
  });

  group('MockNavigator', () {
    testWidgets('20 numbered cells; answered and current are announced', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final tapped = <int>[];
      await pumpApp(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: MockNavigator(
              count: 20,
              current: 2,
              answered: const {0, 2},
              onTap: tapped.add,
            ),
          ),
        ),
      );
      for (var i = 1; i <= 20; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
      expect(find.bySemanticsLabel('Pregunta 1, respondida'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Pregunta 2, sin responder'),
        findsOneWidget,
      );
      await tester.tap(find.text('20'));
      await tester.tap(find.text('1'));
      expect(tapped, [19, 0]);
      // Each cell is a 48 dp touch target.
      expect(tester.getSize(find.byType(InkWell).first), const Size(48, 48));
      handle.dispose();
    });

    testWidgets('at 3x text the number shrinks to fit its 48 dp cell', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: MockNavigator(
              count: 20,
              current: 19,
              answered: const {19},
              onTap: (_) {},
            ),
          ),
        ),
        textScale: 3,
      );
      expect(tester.takeException(), isNull);
      // The cell keeps its touch target...
      final cell = find.ancestor(
        of: find.text('20'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(cell), const Size(48, 48));
      // ...and the text, after the FittedBox scale, lies inside it.
      final text = find.text('20');
      final topLeft = tester.getTopLeft(text);
      final bottomRight = tester.getBottomRight(text);
      final bounds = tester.getRect(cell);
      expect(topLeft.dx, greaterThanOrEqualTo(bounds.left));
      expect(topLeft.dy, greaterThanOrEqualTo(bounds.top));
      expect(bottomRight.dx, lessThanOrEqualTo(bounds.right));
      expect(bottomRight.dy, lessThanOrEqualTo(bounds.bottom));
      // The FittedBox is what makes it fit (the text alone would be wider).
      expect(
        find.descendant(of: cell, matching: find.byType(FittedBox)),
        findsOneWidget,
      );
      expect(tester.getSize(text).width, greaterThan(48));
    });
  });
}

/// Opacity of the top (`top: true`) or bottom fade of a [ScrollEdgeFade].
double _fadeOpacity(WidgetTester tester, {required bool top}) {
  final fades = find.descendant(
    of: find.byType(ScrollEdgeFade),
    matching: find.byType(AnimatedOpacity),
  );
  expect(fades, findsNWidgets(2));
  // Declared top first, bottom second.
  return tester.widget<AnimatedOpacity>(top ? fades.first : fades.last).opacity;
}

void scrollEdgeFadeTests() {
  group('ScrollEdgeFade', () {
    Widget scroller({double itemHeight = 100, int count = 20}) => Scaffold(
      body: SizedBox(
        height: 300,
        child: ScrollEdgeFade(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var i = 0; i < count; i++)
                  SizedBox(height: itemHeight, child: Text('row $i')),
              ],
            ),
          ),
        ),
      ),
    );

    testWidgets('at rest only the bottom fades; scrolled, both; at the end, '
        'only the top', (tester) async {
      await pumpApp(tester, scroller());
      expect(_fadeOpacity(tester, top: true), 0);
      expect(_fadeOpacity(tester, top: false), 1);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(_fadeOpacity(tester, top: true), 1);
      expect(_fadeOpacity(tester, top: false), 1);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -5000),
      );
      await tester.pumpAndSettle();
      expect(_fadeOpacity(tester, top: true), 1);
      expect(_fadeOpacity(tester, top: false), 0);
    });

    testWidgets('short content that fits shows no fade', (tester) async {
      await pumpApp(tester, scroller(count: 2));
      expect(_fadeOpacity(tester, top: true), 0);
      expect(_fadeOpacity(tester, top: false), 0);
    });

    testWidgets('the fades fade to the background and never take touches', (
      tester,
    ) async {
      await pumpApp(tester, scroller());
      final c = AptoColors.light;
      final boxes = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(ScrollEdgeFade),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((b) => (b.decoration as BoxDecoration).gradient)
          .whereType<LinearGradient>()
          .toList();
      expect(boxes, hasLength(2));
      expect(boxes[0].colors.first, c.background); // top: solid at the edge
      expect(boxes[0].colors.last.a, 0);
      expect(boxes[1].colors.last, c.background); // bottom: solid at the edge
      expect(boxes[1].colors.first.a, 0);
      expect(
        find.descendant(
          of: find.byType(ScrollEdgeFade),
          matching: find.byType(IgnorePointer),
        ),
        findsAtLeastNWidgets(2),
      );
    });
  });
}
