import 'package:better_fl_chart/better_fl_chart.dart';
import 'package:fl_chart_app/presentation/resources/app_resources.dart';
import 'package:flutter/material.dart';

/// Demonstrates [LineChartBarData.clipStart] and [LineChartBarData.clipProgress]:
/// "Draw in" animates `clipProgress` 0 → 1 for a left-to-right pencil reveal.
/// "Draw out" animates `clipStart` 0 → 1 so the line erases from the left
/// while the right tail stays anchored at the last spot.
class LineChartSample14 extends StatefulWidget {
  const LineChartSample14({super.key});

  @override
  State<LineChartSample14> createState() => _LineChartSample14State();
}

class _LineChartSample14State extends State<LineChartSample14> {
  double _clipStart = 0;
  double _clipProgress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _drawIn());
  }

  void _drawIn() {
    setState(() {
      _clipStart = 0;
      _clipProgress = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _clipProgress = 1);
    });
  }

  void _drawOut() {
    setState(() {
      _clipStart = 0;
      _clipProgress = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _clipStart = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        AspectRatio(
          aspectRatio: 1.6,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 24, top: 12),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 10,
                minY: 0,
                maxY: 6,
                lineTouchData: const LineTouchData(enabled: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    clipStart: _clipStart,
                    clipProgress: _clipProgress,
                    spots: const [
                      FlSpot(0, 1),
                      FlSpot(1.5, 2.5),
                      FlSpot(3, 1.8),
                      FlSpot(4.5, 4.2),
                      FlSpot(6, 3),
                      FlSpot(7.5, 4.6),
                      FlSpot(9, 2.4),
                      FlSpot(10, 3.8),
                    ],
                    isCurved: true,
                    barWidth: 4,
                    color: AppColors.contentColorCyan,
                    isStrokeCapRound: true,
                    isStrokeJoinRound: true,
                    shadow: const Shadow(
                      color: Colors.black54,
                      offset: Offset(0, 6),
                      blurRadius: 8,
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.contentColorCyan.withValues(alpha: 0.45),
                          AppColors.contentColorCyan.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 5,
                        color: Colors.white,
                        strokeColor: AppColors.contentColorCyan,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 2000),
              curve: Curves.easeOutCubic,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _drawIn,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Draw In'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _drawOut,
              icon: const Icon(Icons.swipe_right_rounded),
              label: const Text('Draw Out'),
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
