import 'dart:math' as math;

import 'package:better_fl_chart/src/chart/base/axis_chart/axis_chart_scaffold_widget.dart';
import 'package:better_fl_chart/src/chart/base/axis_chart/scale_axis.dart';
import 'package:better_fl_chart/src/chart/base/axis_chart/transformation_config.dart';
import 'package:better_fl_chart/src/chart/base/base_chart/base_chart_data.dart';
import 'package:better_fl_chart/src/chart/base/base_chart/fl_touch_event.dart';
import 'package:better_fl_chart/src/chart/line_chart/line_chart_data.dart';
import 'package:better_fl_chart/src/chart/line_chart/line_chart_helper.dart';
import 'package:better_fl_chart/src/chart/line_chart/line_chart_renderer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Renders a line chart as a widget, using provided [LineChartData].
class LineChart extends ImplicitlyAnimatedWidget {
  /// [data] determines how the [LineChart] should be look like,
  /// when you make any change in the [LineChartData], it updates
  /// new values with animation, and duration is [duration].
  /// also you can change the [curve]
  /// which default is [Curves.linear].
  const LineChart(
    this.data, {
    this.chartRendererKey,
    super.key,
    super.duration = const Duration(milliseconds: 150),
    super.curve = Curves.linear,
    this.transformationConfig = const FlTransformationConfig(),
  });

  /// Determines how the [LineChart] should be look like.
  final LineChartData data;

  /// {@macro fl_chart.AxisChartScaffoldWidget.transformationConfig}
  final FlTransformationConfig transformationConfig;

  /// We pass this key to our renderers which are supposed to
  /// render the chart itself (without anything around the chart).
  final Key? chartRendererKey;

  /// Creates a [_LineChartState]
  @override
  _LineChartState createState() => _LineChartState();
}

class _LineChartState extends AnimatedWidgetBaseState<LineChart> {
  /// we handle under the hood animations (implicit animations) via this tween,
  /// it lerps between the old [LineChartData] to the new one.
  LineChartDataTween? _lineChartDataTween;

  /// If [LineTouchData.handleBuiltInTouches] is true, we override the callback to handle touches internally,
  /// but we need to keep the provided callback to notify it too.
  BaseTouchCallback<LineTouchResponse>? _providedTouchCallback;

  final List<ShowingTooltipIndicators> _showingTouchedTooltips = [];

  final Map<int, List<int>> _showingTouchedIndicators = {};

  /// Per-bar target spot in DATA space (FlSpot.x, FlSpot.y) — the position
  /// the glow should slide to. Updated whenever the selected spot
  /// changes (touch or programmatic [LineChartBarData.showingIndicators]).
  final Map<int, Offset> _glowDataTarget = {};

  /// Per-bar eased glow position in DATA space. A single value (no
  /// head/tail split) that smoothly translates toward [_glowDataTarget],
  /// so the rendered glow keeps its size and just moves between spots.
  final Map<int, Offset> _glowData = {};

  /// Whether a glow trail frame callback is already queued — guards against
  /// scheduling more than one callback per frame.
  bool _glowFrameScheduled = false;

  /// Timestamp of the previous trail frame; used to compute the per-frame
  /// blend factor from real elapsed time.
  Duration? _glowLastFrameTime;

  /// Target data-space x for the touch crosshair. Set on every touch
  /// event; null when no touch is active.
  double? _crosshairTargetX;

  /// Eased data-space x for the touch crosshair. Translates toward
  /// [_crosshairTargetX] over [TouchCrosshair.followDuration]. The
  /// painter reads this via [LineChartData.crosshairAnchorX].
  double? _crosshairCurrentX;

  /// Whether a crosshair-easing frame callback is already queued.
  bool _crosshairFrameScheduled = false;

  /// Timestamp of the previous crosshair-ease frame; used for dt.
  Duration? _crosshairLastFrameTime;

  final _lineChartHelper = LineChartHelper();

  @override
  Widget build(BuildContext context) {
    final showingData = _getData();
    _syncGlowTargetsFromWidgetData(showingData);

    return AxisChartScaffoldWidget(
      transformationConfig: widget.transformationConfig,
      chartBuilder: (context, chartVirtualRect) => LineChartLeaf(
        data: _withTouchedIndicators(
          _lineChartDataTween!.evaluate(animation),
        ),
        targetData: _withTouchedIndicators(showingData),
        key: widget.chartRendererKey,
        chartVirtualRect: chartVirtualRect,
        canBeScaled: widget.transformationConfig.scaleAxis != FlScaleAxis.none,
      ),
      data: showingData,
    );
  }

  LineChartData _withTouchedIndicators(LineChartData lineChartData) {
    final touchEnabled = lineChartData.lineTouchData.enabled &&
        lineChartData.lineTouchData.handleBuiltInTouches;

    return lineChartData.copyWith(
      showingTooltipIndicators: touchEnabled ? _showingTouchedTooltips : null,
      crosshairAnchorX: _crosshairCurrentX,
      lineBarsData: List.generate(lineChartData.lineBarsData.length, (i) {
        final barData = lineChartData.lineBarsData[i];
        final touchedIndicators = touchEnabled
            ? (_showingTouchedIndicators[i] ?? const <int>[])
            : null;
        return barData.copyWith(
          showingIndicators: touchedIndicators,
          glowAnchor: _glowData[i],
        );
      }),
    );
  }

  LineChartData _getData() {
    var newData = widget.data;

    /// Calculate minX, maxX, minY, maxY for [LineChartData] if they are null,
    /// it is necessary to render the chart correctly.
    if (newData.minX.isNaN ||
        newData.maxX.isNaN ||
        newData.minY.isNaN ||
        newData.maxY.isNaN) {
      final (minX, maxX, minY, maxY) = _lineChartHelper.calculateMaxAxisValues(
        newData.lineBarsData,
      );
      newData = newData.copyWith(
        minX: newData.minX.isNaN ? minX : newData.minX,
        maxX: newData.maxX.isNaN ? maxX : newData.maxX,
        minY: newData.minY.isNaN ? minY : newData.minY,
        maxY: newData.maxY.isNaN ? maxY : newData.maxY,
      );
    }

    final lineTouchData = newData.lineTouchData;
    if (lineTouchData.enabled && lineTouchData.handleBuiltInTouches) {
      _providedTouchCallback = lineTouchData.touchCallback;
      newData = newData.copyWith(
        lineTouchData:
            newData.lineTouchData.copyWith(touchCallback: _handleBuiltInTouch),
      );
    }

    return newData;
  }

  void _handleBuiltInTouch(
    FlTouchEvent event,
    LineTouchResponse? touchResponse,
  ) {
    if (!mounted) {
      return;
    }
    _providedTouchCallback?.call(event, touchResponse);

    // Touch end: clear the tooltip/indicator state. Glow head/tail intentionally
    // persist so the next selection can animate from where the snake came to
    // rest, instead of snapping to the new spot from nothing.
    if (!event.isInterestedForInteractions) {
      setState(() {
        _showingTouchedTooltips.clear();
        _showingTouchedIndicators.clear();
        // Crosshair disappears immediately on release — no fade-out.
        _crosshairTargetX = null;
        _crosshairCurrentX = null;
        _crosshairLastFrameTime = null;
      });
      return;
    }

    final spots = touchResponse?.lineBarSpots;
    if (spots == null || spots.isEmpty) {
      setState(() {
        _showingTouchedTooltips.clear();
        _showingTouchedIndicators.clear();
        _crosshairTargetX = null;
        _crosshairCurrentX = null;
        _crosshairLastFrameTime = null;
      });
      return;
    }

    setState(() {
      final sortedLineSpots = List.of(spots)
        ..sort((spot1, spot2) => spot2.y.compareTo(spot1.y));

      _showingTouchedIndicators.clear();
      for (final touched in spots) {
        _showingTouchedIndicators[touched.barIndex] = [touched.spotIndex];
        _setGlowTargetForBar(touched.barIndex, Offset(touched.x, touched.y));
      }
      // Use the first touched spot's x as the crosshair anchor. Spots
      // across bars typically share x for a given touch, so this is
      // representative.
      _setCrosshairTarget(spots.first.x);

      _showingTouchedTooltips
        ..clear()
        ..add(ShowingTooltipIndicators(sortedLineSpots));
    });
  }

  /// Updates the crosshair target. Snaps the eased current to target on
  /// the first set (so the crosshair appears at the touched x without a
  /// glide-in from nowhere). Otherwise schedules an easing frame.
  void _setCrosshairTarget(double target) {
    _crosshairTargetX = target;
    if (_crosshairCurrentX == null) {
      _crosshairCurrentX = target;
      return;
    }
    if (_crosshairCurrentX != target) {
      _scheduleCrosshairFrame();
    }
  }

  void _scheduleCrosshairFrame() {
    if (_crosshairFrameScheduled || !mounted) {
      return;
    }
    if (_crosshairTargetX == null) {
      return;
    }
    _crosshairFrameScheduled = true;
    SchedulerBinding.instance
      ..scheduleFrameCallback((timestamp) {
        _crosshairFrameScheduled = false;
        if (!mounted) {
          return;
        }
        _onCrosshairFrame(timestamp);
      })
      ..scheduleFrame();
  }

  /// Eases [_crosshairCurrentX] toward [_crosshairTargetX] using an
  /// exponential blend so the glide is frame-rate independent.
  void _onCrosshairFrame(Duration timestamp) {
    final target = _crosshairTargetX;
    final current = _crosshairCurrentX;
    if (target == null || current == null) {
      _crosshairLastFrameTime = null;
      return;
    }

    final dt = _crosshairLastFrameTime == null
        ? 1 / 60
        : (timestamp - _crosshairLastFrameTime!).inMicroseconds / 1e6;
    _crosshairLastFrameTime = timestamp;

    final tau = _crosshairFollowDurationSeconds();
    if (tau <= 0) {
      setState(() => _crosshairCurrentX = target);
      _crosshairLastFrameTime = null;
      return;
    }

    final blend = (1 - math.exp(-dt / tau)).clamp(0.0, 1.0);
    final next = current + (target - current) * blend;
    setState(() => _crosshairCurrentX = next);

    final range = _dataRange();
    final epsilon = range * 1e-4;
    if ((target - next).abs() > epsilon) {
      _scheduleCrosshairFrame();
    } else {
      // Snap to target to settle exactly on the spot's x.
      setState(() => _crosshairCurrentX = target);
      _crosshairLastFrameTime = null;
    }
  }

  double _crosshairFollowDurationSeconds() {
    final crosshair = widget.data.lineTouchData.crosshair;
    if (crosshair == null) return 0;
    return crosshair.followDuration.inMicroseconds / 1e6;
  }

  /// Reads programmatic [LineChartBarData.showingIndicators] and updates
  /// [_glowDataTarget] for any bar whose selected spot changed since the
  /// last build. Lets the snake animation also fire when callers drive
  /// the selection through widget data instead of touch events.
  void _syncGlowTargetsFromWidgetData(LineChartData data) {
    final touchEnabled =
        data.lineTouchData.enabled && data.lineTouchData.handleBuiltInTouches;
    for (var i = 0; i < data.lineBarsData.length; i++) {
      // Skip bars that are currently being driven by touch — those targets
      // are already maintained in [_handleBuiltInTouch], and overriding
      // them here would fight live drags.
      if (touchEnabled && _showingTouchedIndicators.containsKey(i)) {
        continue;
      }
      final bar = data.lineBarsData[i];
      if (bar.showingIndicators.isEmpty) {
        // Selection cleared — let head/tail decay to nothing on the next
        // frame by removing the bar from the active maps.
        _glowDataTarget.remove(i);
        continue;
      }
      final spotIndex = bar.showingIndicators.first;
      if (spotIndex < 0 || spotIndex >= bar.spots.length) {
        continue;
      }
      final spot = bar.spots[spotIndex];
      if (spot.isNull()) {
        continue;
      }
      _setGlowTargetForBar(i, Offset(spot.x, spot.y));
    }
  }

  /// Updates the data-space target for [barIndex]'s glow. If the bar has
  /// no displayed glow yet (first selection), snaps the eased position to
  /// the target so the glow appears at that spot immediately. Otherwise
  /// schedules a frame to ease toward the new target.
  void _setGlowTargetForBar(int barIndex, Offset target) {
    _glowDataTarget[barIndex] = target;
    if (!_glowData.containsKey(barIndex)) {
      _glowData[barIndex] = target;
      return;
    }
    if (_glowData[barIndex] != target) {
      _scheduleGlowFrame();
    }
  }

  void _scheduleGlowFrame() {
    if (_glowFrameScheduled || !mounted) {
      return;
    }
    if (_glowDataTarget.isEmpty) {
      return;
    }
    _glowFrameScheduled = true;
    SchedulerBinding.instance
      ..scheduleFrameCallback((timestamp) {
        _glowFrameScheduled = false;
        if (!mounted) {
          return;
        }
        _onGlowFrame(timestamp);
      })
      ..scheduleFrame();
  }

  /// Eases each bar's glow position toward its data-space target. A
  /// single eased value per bar (no head/tail split), so the rendered
  /// glow keeps a constant size and only its position changes.
  void _onGlowFrame(Duration timestamp) {
    if (_glowDataTarget.isEmpty) {
      _glowLastFrameTime = null;
      return;
    }
    final dt = _glowLastFrameTime == null
        ? 1 / 60
        : (timestamp - _glowLastFrameTime!).inMicroseconds / 1e6;
    _glowLastFrameTime = timestamp;

    final tau = _glowFollowDurationSeconds();
    if (tau <= 0) {
      setState(() {
        for (final i in _glowDataTarget.keys.toList()) {
          _glowData[i] = _glowDataTarget[i]!;
        }
      });
      _glowLastFrameTime = null;
      return;
    }

    final blend = (1 - math.exp(-dt / tau)).clamp(0.0, 1.0);
    final range = _dataRange();
    final epsilon = range * 1e-4;
    final epsilonSq = epsilon * epsilon;

    var anyMoving = false;
    setState(() {
      for (final i in _glowDataTarget.keys.toList()) {
        final target = _glowDataTarget[i]!;
        final current = _glowData[i] ?? target;
        final next = Offset.lerp(current, target, blend)!;
        _glowData[i] = next;
        if ((next - target).distanceSquared > epsilonSq) {
          anyMoving = true;
        }
      }
    });

    if (anyMoving) {
      _scheduleGlowFrame();
    } else {
      _glowLastFrameTime = null;
    }
  }

  /// A characteristic length of the chart's data range, used to scale the
  /// "are we close enough to the target" threshold so it works for any
  /// data magnitude.
  double _dataRange() {
    final data = widget.data;
    final dx = (data.maxX - data.minX).abs();
    final dy = (data.maxY - data.minY).abs();
    final r = math.sqrt(dx * dx + dy * dy);
    return r.isFinite && r > 0 ? r : 1.0;
  }

  /// Reads the trail time constant from the first bar with a visible glow,
  /// in seconds. Falls back to the default when nothing is configured.
  double _glowFollowDurationSeconds() {
    for (final bar in widget.data.lineBarsData) {
      if (bar.glowData.show) {
        return bar.glowData.followDuration.inMicroseconds / 1e6;
      }
    }
    return 0.4;
  }

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _lineChartDataTween = visitor(
      _lineChartDataTween,
      _getData(),
      (dynamic value) =>
          LineChartDataTween(begin: value as LineChartData, end: widget.data),
    ) as LineChartDataTween?;
  }
}
