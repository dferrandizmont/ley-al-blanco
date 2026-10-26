import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// Soft top / bottom edges for a vertical scroll view that ends against a bar
/// or a header: instead of cutting a line of text in half, the content fades
/// into [AptoColors.background].
///
/// The top fade shows only once the content has scrolled (at rest the first
/// card starts below it); the bottom one only while there is more content
/// below. The fades are painted over the child and ignore touches, so they
/// never take a tap. Wrap the scroll view itself:
///
/// ```dart
/// ScrollEdgeFade(child: SingleChildScrollView(...))
/// ```
///
/// Only the vertical scrollable directly below counts (horizontal ones, like
/// the filter chips, are ignored).
class ScrollEdgeFade extends StatefulWidget {
  const ScrollEdgeFade({
    super.key,
    required this.child,
    this.height = defaultHeight,
    this.top = true,
    this.bottom = true,
  });

  /// Height of each fade: one [Sp.l] step, enough to cover a line of text.
  static const double defaultHeight = Sp.l;

  final Widget child;
  final double height;

  /// Whether to fade the top / bottom edge at all.
  final bool top;
  final bool bottom;

  @override
  State<ScrollEdgeFade> createState() => _ScrollEdgeFadeState();
}

class _ScrollEdgeFadeState extends State<ScrollEdgeFade> {
  bool _scrolledFromTop = false;
  bool _moreBelow = false;

  bool _onNotification(Notification notification) {
    final ScrollMetrics? metrics = switch (notification) {
      ScrollNotification(:final metrics) => metrics,
      ScrollMetricsNotification(:final metrics) => metrics,
      _ => null,
    };
    if (metrics == null || metrics.axis != Axis.vertical) return false;
    final scrolled = metrics.extentBefore > 0.5;
    final more = metrics.extentAfter > 0.5;
    if (scrolled != _scrolledFromTop || more != _moreBelow) {
      // Notifications can arrive during layout: update after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _scrolledFromTop = scrolled;
          _moreBelow = more;
        });
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final background = context.colors.background;
    final clear = background.withValues(alpha: 0);
    Widget edge({required bool visible, required bool top}) => Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      height: widget.height,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Motion.of(context, Motion.state),
          curve: Motion.curve,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: top ? [background, clear] : [clear, background],
              ),
            ),
          ),
        ),
      ),
    );
    return NotificationListener<Notification>(
      onNotification: _onNotification,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          if (widget.top) edge(visible: _scrolledFromTop, top: true),
          if (widget.bottom) edge(visible: _moreBelow, top: false),
        ],
      ),
    );
  }
}
