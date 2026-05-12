import 'package:better_fl_chart/better_fl_chart.dart';
import 'package:fl_chart_app/presentation/resources/app_resources.dart';
import 'package:flutter/material.dart';

/// Demonstrates [LineChartBarData.clipProgress] — the line draws itself in
/// like a pencil from left to right when the sample mounts. The fill area,
/// shadow, and dots reveal in lockstep with the moving pencil tip.
class LineChartSample14 extends StatefulWidget {
  const LineChartSample14({super.key});

  @override
  State<LineChartSample14> createState() => _LineChartSample14State();
}

class _LineChartSample14State extends State<LineChartSample14> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _progress = 1);
    });
  }

  void _replay() {
    setState(() => _progress = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _progress = 1);
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
                    clipProgress: _progress,
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
        ElevatedButton.icon(
          onPressed: _replay,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Replay'),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
