import 'dart:math';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart_app/presentation/resources/app_resources.dart';
import 'package:flutter/material.dart';

class GaugeChartSample1 extends StatefulWidget {
  const GaugeChartSample1({super.key});

  @override
  State<StatefulWidget> createState() => GaugeChartSample1State();
}

class GaugeChartSample1State extends State<GaugeChartSample1> {
  double _value = 0.5;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              children: [
                GaugeChart(
                  GaugeChartData.progress(
                    value: _value,
                    color: AppColors.contentColorPurple,
                    width: 30,
                    backgroundColor:
                    AppColors.contentColorPurple.withValues(alpha: 0.2),
                    startDegreeOffset: -200,
                    sweepAngle: 220,
                    touchData: GaugeTouchData(enabled: true),
                    ticks: GaugeTicks(
                      position: GaugeTickPosition.center,
                      count: 11,
                      offset: 0,
                      painter: _MyCustomGaugeMinMaxTickPainter(
                        color: AppColors.contentColorWhite,
                        radius: 5,
                        minIndex: 2,
                        maxIndex: 8,
                        minMaxLineLength: 40,
                        minMaxLineStrokeWidth: 4,
                      ),
                      checkToShowTick: GaugeTicks.hideEndpoints,
                    ),
                    pointers: [
                      // Needle extending from center toward the current value.
                      GaugePointer(
                        value: _value,
                        painter: GaugePointerNeedlePainter(
                          length: 88,
                          width: 20,
                          tailLength: 40,
                          color: AppColors.contentColorWhite,
                        ),
                      ),
                      // Pivot cap sitting at the gauge center, on top of the
                      // needle's base — just a second pointer with a small
                      // circle painter (anchorRadius: 0).
                      GaugePointer(
                        value: 0.3,
                        painter: GaugePointerCirclePainter(
                          radius: 24,
                          color: AppColors.contentColorBlack,
                          strokeWidth: 2,
                          strokeColor: AppColors.contentColorWhite,
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: Text(
                    "${(_value * 100).toInt()}",
                    style: TextStyle(
                      color: AppColors.contentColorWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ],
            ),
          ),
          Slider(value: _value, onChanged: (v) => setState(() => _value = v)),
        ],
      ),
    );
  }
}

class _MyCustomGaugeMinMaxTickPainter extends GaugeTickCirclePainter {
  _MyCustomGaugeMinMaxTickPainter({
    super.color,
    super.radius,
    required this.minIndex,
    required this.maxIndex,
    required this.minMaxLineLength,
    required this.minMaxLineStrokeWidth,
    this.textOffset = 6,
    this.minTextStyle = const TextStyle(
      color: Colors.green,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    ),
    this.maxTextStyle = const TextStyle(
      color: Colors.red,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    ),
  }) : super();

  final int minIndex;
  final int maxIndex;
  final double minMaxLineLength;
  final double minMaxLineStrokeWidth;
  final double textOffset;
  final TextStyle minTextStyle;
  final TextStyle maxTextStyle;

  final _paint = Paint();

  @override
  void draw(Canvas canvas, GaugeTickInfo tickInfo) {
    super.draw(canvas, tickInfo);

    if (tickInfo.index != minIndex && tickInfo.index != maxIndex) {
      return;
    }
    final isMin = tickInfo.index == minIndex;
    final text = isMin ? "Min" : "Max";
    final textStyle = isMin ? minTextStyle : maxTextStyle;
    final rotation = isMin ? pi : 0.0;
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    // 180 degrees
    canvas.rotate(rotation);
    final offsetX = isMin
        ? 0 + textPainter.width + textOffset
        : 0 - textPainter.width - minMaxLineLength / 2 - textOffset;
    textPainter.paint(canvas, Offset(offsetX, 0 - textPainter.height / 2));
    _paint.color = textStyle.color!;
    _paint.strokeWidth = minMaxLineStrokeWidth;
    canvas.drawLine(
      Offset(0 - minMaxLineLength / 2, 0),
      Offset(0 + minMaxLineLength / 2, 0),
      _paint,
    );
  }

  @override
  GaugeTickPainter lerp(GaugeTickPainter b, double t) {
    if (b is! _MyCustomGaugeMinMaxTickPainter) {
      return b;
    }
    return _MyCustomGaugeMinMaxTickPainter(
      color: Color.lerp(color, b.color, t)!,
      radius: lerpDouble(radius, b.radius, t)!,
      minIndex: minIndex,
      maxIndex: maxIndex,
      minMaxLineLength: lerpDouble(minMaxLineLength, b.minMaxLineLength, t)!,
      minMaxLineStrokeWidth:
      lerpDouble(minMaxLineStrokeWidth, b.minMaxLineStrokeWidth, t)!,
      textOffset: lerpDouble(textOffset, b.textOffset, t)!,
      minTextStyle: TextStyle.lerp(minTextStyle, b.minTextStyle, t)!,
      maxTextStyle: TextStyle.lerp(maxTextStyle, b.maxTextStyle, t)!,
    );
  }

  @override
  List<Object?> get props =>
      [
        super.props,
        minIndex,
        maxIndex,
        minMaxLineLength,
        minMaxLineStrokeWidth,
        textOffset,
        minTextStyle,
        maxTextStyle,
      ];
}
