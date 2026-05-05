# Syncing with upstream fl_chart

This package is a fork of [imaNNeo/fl_chart](https://github.com/imaNNeo/fl_chart). The upstream repo is configured as the `upstream` git remote.

## One-time setup (already done on the original clone)

```bash
git remote add upstream https://github.com/imaNNeo/fl_chart.git
```

## Pulling in upstream changes

```bash
git fetch upstream
git checkout main
git merge upstream/main
# resolve any conflicts (most likely in lib/src/chart/line_chart/line_chart_data.dart
# and lib/src/chart/line_chart/line_chart_painter.dart, where our fork-specific
# changes live)
git push origin main
```

If upstream rewrites history or you prefer a linear log, use `git rebase upstream/main` instead.

## What's different from upstream

The fork-specific changes are deliberately small and localized so rebases stay easy:

- `pubspec.yaml` — package renamed to `better_fl_chart`, repo/homepage URLs point to plug-and-pay
- `lib/better_fl_chart.dart` — entry-point file renamed from `lib/fl_chart.dart`
- All `package:fl_chart/...` imports rewritten to `package:better_fl_chart/...`
- `lib/src/chart/line_chart/line_chart_data.dart` — added `clampCurveToChartBounds` field on `LineChartBarData`
- `lib/src/chart/line_chart/line_chart_painter.dart` — clamping logic in `generateNormalBarPath`
- `example/pubspec.yaml` — local path dep renamed to `better_fl_chart`
- `README.md` — fork notice prepended

## Conflict-resolution tips

When merging upstream, the rename creates predictable conflicts. The painter and data file changes are the only *semantic* fork edits — everything else is mechanical renaming. If a future upstream version moves the curve-generation code, re-port the clamp block (look for `clampCurveToChartBounds` in the painter) into the new location.
