import 'dart:async';
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

  /// Live pointer position (in chart-local pixels) — updated on every touch
  /// event. The glow does not render at this position directly; instead
  /// [_glowDisplayed] eases toward it, producing the trailing "snake" effect.
  Offset? _glowTarget;

  /// Displayed glow position — what the painter actually renders. Eased
  /// toward [_glowTarget] each frame by [_glowTicker].
  Offset? _glowDisplayed;

  /// Ticker that drives the trailing animation while [_glowTarget] differs
  /// from [_glowDisplayed]. Stops itself once they converge.
  Ticker? _glowTicker;
  Duration _glowLastElapsed = Duration.zero;

  final _lineChartHelper = LineChartHelper();

  @override
  void dispose() {
    _glowTicker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showingData = _getData();

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
    if (!lineChartData.lineTouchData.enabled ||
        !lineChartData.lineTouchData.handleBuiltInTouches) {
      return lineChartData;
    }

    return lineChartData.copyWith(
      showingTooltipIndicators: _showingTouchedTooltips,
      lineBarsData: lineChartData.lineBarsData.map((barData) {
        final index = lineChartData.lineBarsData.indexOf(barData);
        return barData.copyWith(
          showingIndicators: _showingTouchedIndicators[index] ?? [],
          glowAnchor: _glowDisplayed,
        );
      }).toList(),
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

    if (!event.isInterestedForInteractions ||
        touchResponse?.lineBarSpots == null ||
        touchResponse!.lineBarSpots!.isEmpty) {
      setState(() {
        _showingTouchedTooltips.clear();
        _showingTouchedIndicators.clear();
      });
      _setGlowTarget(null);
      return;
    }

    setState(() {
      final sortedLineSpots = List.of(touchResponse.lineBarSpots!)
        ..sort((spot1, spot2) => spot2.y.compareTo(spot1.y));

      _showingTouchedIndicators.clear();
      for (var i = 0; i < touchResponse.lineBarSpots!.length; i++) {
        final touchedBarSpot = touchResponse.lineBarSpots![i];
        final barPos = touchedBarSpot.barIndex;
        _showingTouchedIndicators[barPos] = [touchedBarSpot.spotIndex];
      }

      _showingTouchedTooltips
        ..clear()
        ..add(ShowingTooltipIndicators(sortedLineSpots));
    });
    _setGlowTarget(event.localPosition ?? touchResponse.touchLocation);
  }

  /// Updates the live pointer target for the glow trail and ensures the
  /// ticker is running while [_glowDisplayed] hasn't converged on it yet.
  void _setGlowTarget(Offset? target) {
    _glowTarget = target;
    if (target == null) {
      // Touch ended: snap glow off so it doesn't drift toward (0,0).
      if (_glowDisplayed != null) {
        setState(() => _glowDisplayed = null);
      }
      _glowTicker?.stop();
      _glowLastElapsed = Duration.zero;
      return;
    }
    if (_glowDisplayed == null) {
      // First appearance: place the glow under the finger immediately.
      setState(() => _glowDisplayed = target);
      return;
    }
    _glowTicker ??= Ticker(_onGlowTick);
    if (!_glowTicker!.isActive) {
      _glowLastElapsed = Duration.zero;
      unawaited(_glowTicker!.start());
    }
  }

  /// Eases [_glowDisplayed] toward [_glowTarget] using exponential decay
  /// with the per-bar [LineGlowData.followDuration] as time constant.
  /// Stops the ticker once the displayed position is close enough.
  void _onGlowTick(Duration elapsed) {
    if (_glowDisplayed == null || _glowTarget == null) {
      _glowTicker?.stop();
      return;
    }
    final dt = _glowLastElapsed == Duration.zero
        ? 1 / 60
        : (elapsed - _glowLastElapsed).inMicroseconds / 1e6;
    _glowLastElapsed = elapsed;

    final tau = _glowFollowDurationSeconds();
    if (tau <= 0) {
      setState(() => _glowDisplayed = _glowTarget);
      _glowTicker?.stop();
      return;
    }
    final blend = (1 - math.exp(-dt / tau)).clamp(0.0, 1.0);
    final next = Offset.lerp(_glowDisplayed, _glowTarget, blend)!;

    final delta = (next - _glowTarget!).distance;
    if (delta < 0.5) {
      setState(() => _glowDisplayed = _glowTarget);
      _glowTicker?.stop();
    } else {
      setState(() => _glowDisplayed = next);
    }
  }

  /// Reads the trail time constant from the first bar with a visible glow,
  /// in seconds. Falls back to 220ms when nothing is configured.
  double _glowFollowDurationSeconds() {
    for (final bar in widget.data.lineBarsData) {
      if (bar.glowData.show) {
        return bar.glowData.followDuration.inMicroseconds / 1e6;
      }
    }
    return 0.22;
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
