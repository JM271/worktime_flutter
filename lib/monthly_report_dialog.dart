import 'expenses.dart';
import 'monthly_pdf.dart';

import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_style.dart';
import 'report_analysis.dart';
import 'bank_details.dart';

const excelMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

Future<OpenResult> openMonthlyWorkbook(String path) =>
    OpenFilex.open(path, type: excelMimeType);

Future<OpenResult> openMonthlyPdf(String path) =>
    OpenFilex.open(path, type: 'application/pdf');

class MonthlyReportDialog extends StatefulWidget {
  const MonthlyReportDialog({
    super.key,
    required this.report,
    required this.filename,
    required this.bytes,
    this.analysis,
    this.expenses = const [],
    this.bankDetails = const BankDetails(),
    this.openFile = openMonthlyWorkbook,
    this.openPdfFile = openMonthlyPdf,
  });

  final List<Expense> expenses;
  final String report;
  final String filename;
  final Uint8List bytes;
  final MonthlyAnalysis? analysis;
  final BankDetails bankDetails;
  final Future<OpenResult> Function(String path) openFile;
  final Future<OpenResult> Function(String path) openPdfFile;

  @override
  State<MonthlyReportDialog> createState() => _MonthlyReportDialogState();
}

class _MonthlyReportDialogState extends State<MonthlyReportDialog> {
  bool busy = false;
  String? error;
  String? savedPath;
  String? savedPdfPath;
  Uint8List? pdfBytes;

  String get pdfFilename =>
      widget.filename.replaceFirst(RegExp(r'\.xlsx$'), '.pdf');

  XFile get workbook => XFile.fromData(widget.bytes, mimeType: excelMimeType);

  Future<void> openExcel() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (savedPath == null) {
        final directory = await getApplicationDocumentsDirectory();
        // A distinct path prevents spreadsheet apps from reusing an older
        // workbook that is still open under the monthly filename.
        final stem = widget.filename.replaceFirst(RegExp(r'\.xlsx$'), '');
        final path =
            '${directory.path}/$stem-${DateTime.now().microsecondsSinceEpoch}.xlsx';
        await workbook.saveTo(path);
        savedPath = path;
      }
      if (!mounted) return;
      final result = await widget.openFile(savedPath!);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        setState(() {
          error = result.type == ResultType.noAppToOpen
              ? 'No spreadsheet app is available. Install Excel or another spreadsheet app, or use Share Excel.'
              : 'The Excel sheet could not be opened. Try again or use Share Excel.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'The Excel sheet could not be opened. Try again or use Share Excel.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> shareExcel() async {
    final box = context.findRenderObject() as RenderBox?;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [workbook],
          fileNameOverrides: [widget.filename],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'The share menu could not be opened. Try again or use Open Excel.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> exportPdf({required bool share}) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      pdfBytes ??= await monthlyPdfFromAnalysis(
        widget.analysis!,
        bankDetails: widget.bankDetails,
        expenses: widget.expenses,
      );
      if (!mounted) return;
      final file = XFile.fromData(pdfBytes!, mimeType: 'application/pdf');
      if (share) {
        await SharePlus.instance.share(
          ShareParams(
            files: [file],
            fileNameOverrides: [pdfFilename],
            sharePositionOrigin: origin,
          ),
        );
      } else {
        if (savedPdfPath == null) {
          final directory = await getApplicationDocumentsDirectory();
          final stem = pdfFilename.replaceFirst(RegExp(r'\.pdf$'), '');
          final path =
              '${directory.path}/$stem-${DateTime.now().microsecondsSinceEpoch}.pdf';
          await file.saveTo(path);
          savedPdfPath = path;
        }
        if (!mounted) return;
        final result = await widget.openPdfFile(savedPdfPath!);
        if (mounted && result.type != ResultType.done) {
          setState(
            () => error = result.type == ResultType.noAppToOpen
                ? 'Keine PDF-App verfügbar. Bitte PDF teilen verwenden.'
                : 'PDF konnte nicht geöffnet werden. Bitte erneut versuchen oder PDF teilen verwenden.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = share
              ? 'PDF konnte nicht geteilt werden. Bitte erneut versuchen.'
              : 'PDF konnte nicht geöffnet werden. Bitte erneut versuchen oder PDF teilen verwenden.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final structured = widget.analysis != null;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      title: const Text('Monthly report'),
      content: SizedBox(
        width: math.min(720, math.max(1, size.width - 84)),
        height: structured ? math.max(120, size.height * 0.52) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.filename,
                      style: structured
                          ? const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    if (widget.analysis != null &&
                        expensesForMonth(
                          widget.expenses,
                          widget.analysis!.month,
                        ).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spesen',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            for (final expense in expensesForMonth(
                              widget.expenses,
                              widget.analysis!.month,
                            ))
                              Text(
                                '${MaterialLocalizations.of(context).formatShortDate(expense.date)} · ${expense.description} · ${expenseAmount(expense.cents)}',
                              ),
                            Text(
                              'Total: ${expenseAmount(expensesForMonth(widget.expenses, widget.analysis!.month).fold<int>(0, (sum, e) => sum + e.cents))}',
                            ),
                          ],
                        ),
                      ),
                    if (widget.analysis case final analysis?)
                      _MonthlyAnalysisView(
                        analysis: analysis,
                        bankDetails: widget.bankDetails,
                      )
                    else
                      SelectableText(widget.report),
                  ],
                ),
              ),
            ),
            if (busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (error != null) ...[
              const SizedBox(height: 16),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actionsOverflowButtonSpacing: 8,
      actions: [
        SizedBox(
          width: 720,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: busy ? null : shareExcel,
                      icon: const Icon(Icons.ios_share, size: 16),
                      label: const Text(
                        'Share Excel',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: busy ? null : openExcel,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text(
                        'Open Excel',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              if (structured) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: busy ? null : () => exportPdf(share: true),
                        icon: const Icon(Icons.ios_share, size: 16),
                        label: const Text(
                          'PDF teilen',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: busy ? null : () => exportPdf(share: false),
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 16,
                        ),
                        label: const Text(
                          'PDF ansehen',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _durationLabel(Duration duration) {
  final minutes = duration.inMinutes;
  return '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';
}

class _MonthlyAnalysisView extends StatelessWidget {
  const _MonthlyAnalysisView({
    required this.analysis,
    required this.bankDetails,
  });

  final MonthlyAnalysis analysis;
  final BankDetails bankDetails;

  @override
  Widget build(BuildContext context) {
    final change = analysis.comparisonChangePercent;
    final qualityFlags =
        analysis.missingCategoryCount > 0 ||
        analysis.invalidEntryCount > 0 ||
        analysis.longSessionCount > 0 ||
        analysis.futureEntryCount > 0 ||
        analysis.overlapDuration > Duration.zero;
    final goalActual = analysis.isCurrentMonth
        ? analysis.comparisonTotal
        : analysis.total;
    final busiestDay = analysis.busiestDay;
    final largestWeek = analysis.weeks.fold<Duration>(
      Duration.zero,
      (largest, week) => week.total > largest ? week.total : largest,
    );
    final reviewCount =
        analysis.rows.where((row) => row.flags.isNotEmpty).length +
        analysis.invalidEntryCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              MaterialLocalizations.of(context).formatMonthYear(analysis.month),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            _ReportBadge(
              label: analysis.isCurrentMonth
                  ? 'Month to date'
                  : analysis.isFutureMonth
                  ? 'Future month'
                  : 'Full month',
              color: AppColors.cyan,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cyan.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cyan.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'COMPLETED WORK',
                style: TextStyle(
                  color: AppColors.cyan,
                  fontSize: 10,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 9),
              SelectableText(
                'Total time worked: ${_durationLabel(analysis.total)}',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Running timers are excluded until stopped.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _MetricGrid(
          metrics: [
            _ReportMetric('Sessions', '${analysis.sessionCount}'),
            _ReportMetric('Active days', '${analysis.activeDays}'),
            _ReportMetric(
              'Average active day',
              _durationLabel(analysis.averageActiveDay),
            ),
          ],
        ),
        const SizedBox(height: 26),
        _ReportSection(
          eyebrow: 'PERIOD COMPARISON',
          title: 'How this month compares',
          icon: Icons.compare_arrows_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                analysis.comparisonLabel,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              _MetricGrid(
                metrics: [
                  _ReportMetric(
                    'Selected period',
                    _durationLabel(analysis.comparisonTotal),
                  ),
                  _ReportMetric(
                    'Previous period',
                    _durationLabel(analysis.comparisonPreviousTotal),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                change == null
                    ? analysis.isFutureMonth
                          ? 'Comparison starts when the selected month begins.'
                          : analysis.comparisonPreviousTotal == Duration.zero &&
                                analysis.comparisonTotal == Duration.zero
                          ? 'No completed time in either comparison period.'
                          : 'No previous time recorded to calculate a percentage change.'
                    : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% time compared with the previous period.',
                style: const TextStyle(color: AppColors.cyan, fontSize: 12),
              ),
              if (analysis.goal > Duration.zero) ...[
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text(
                  analysis.goalLabel,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  analysis.isFutureMonth
                      ? 'Planned target: ${_durationLabel(analysis.goal)}'
                      : '${_durationLabel(goalActual)} / ${_durationLabel(analysis.goal)} · ${(analysis.goalProgress * 100).round()}%',
                  style: const TextStyle(color: AppColors.lime, fontSize: 12),
                ),
                if (!analysis.isFutureMonth) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: analysis.goalProgress.clamp(0.0, 1.0),
                    minHeight: 6,
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ReportSection(
          eyebrow: 'DAILY & WEEKLY RHYTHM',
          title: 'Your working rhythm',
          icon: Icons.bar_chart_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                busiestDay == null
                    ? 'No active days in this month yet.'
                    : 'Busiest day: ${MaterialLocalizations.of(context).formatShortDate(busiestDay.date)} · ${_durationLabel(busiestDay.total)}',
                style: const TextStyle(color: AppColors.cyan, fontSize: 12),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < analysis.weeks.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _WeeklyBar(week: analysis.weeks[i], largest: largestWeek),
              ],
              const SizedBox(height: 12),
              const Text(
                'Weeks start on Monday and are limited to this month. Bars compare recorded weekly totals.',
                style: TextStyle(color: AppColors.muted, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ReportSection(
          eyebrow: 'WORK MIX',
          title: 'Where your time went',
          icon: Icons.donut_large_rounded,
          child: analysis.categories.isEmpty
              ? const Text(
                  'No completed work in this month yet.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < analysis.categories.length; i++) ...[
                      if (i > 0) const SizedBox(height: 18),
                      _CategoryBar(
                        category: analysis.categories[i],
                        color: i.isEven ? AppColors.cyan : AppColors.lime,
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _ReportSection(
          eyebrow: 'INSIGHTS',
          title: 'Patterns worth knowing',
          icon: Icons.auto_awesome_outlined,
          child: _ReportNotes(notes: analysis.insights, color: AppColors.cyan),
        ),
        const SizedBox(height: 16),
        _ReportSection(
          eyebrow: 'DATA QUALITY',
          title: qualityFlags ? 'Entries to review' : 'Recording checks',
          icon: qualityFlags
              ? Icons.fact_check_outlined
              : Icons.verified_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (reviewCount > 0 || analysis.activeTimerCount > 0) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (reviewCount > 0)
                      _ReportBadge(
                        label:
                            '$reviewCount ${reviewCount == 1 ? 'entry' : 'entries'} to review',
                        color: const Color(0xffffd08b),
                      ),
                    if (analysis.activeTimerCount > 0)
                      _ReportBadge(
                        label:
                            '${analysis.activeTimerCount} running ${analysis.activeTimerCount == 1 ? 'timer' : 'timers'} excluded',
                        color: AppColors.cyan,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              _ReportNotes(
                notes: analysis.checks,
                color: qualityFlags ? const Color(0xffffd08b) : AppColors.lime,
              ),
            ],
          ),
        ),
        if (!bankDetails.isEmpty) ...[
          const SizedBox(height: 16),
          _ReportSection(
            eyebrow: 'BANK DETAILS',
            title: 'Account information',
            icon: Icons.account_balance_outlined,
            child: SelectableText(
              bankDetails.fields
                  .map((field) => '${field.$1}: ${field.$2}')
                  .join('\n\n'),
              style: const TextStyle(fontSize: 12, color: AppColors.text),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Open Excel for the full entry list, category totals and bank details.',
          style: TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _ReportMetric {
  const _ReportMetric(this.label, this.value);

  final String label;
  final String value;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_ReportMetric> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 480 ? metrics.length : 1;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final metric in metrics)
            Container(
              width: width,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metric.value,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _ReportBadge extends StatelessWidget {
  const _ReportBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.25)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 10)),
  );
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.eyebrow,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.background.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.cyan),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 9,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.category, required this.color});

  final CategoryTotal category;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        category.category,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 6),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(
            '${_durationLabel(category.total)} · ${category.sessionCount} ${category.sessionCount == 1 ? 'session' : 'sessions'}',
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          Text(
            '${(category.share * 100).toStringAsFixed(1)}%',
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
      const SizedBox(height: 8),
      LinearProgressIndicator(
        value: category.share.clamp(0.0, 1.0),
        color: color,
        minHeight: 6,
        borderRadius: BorderRadius.circular(6),
      ),
    ],
  );
}

class _WeeklyBar extends StatelessWidget {
  const _WeeklyBar({required this.week, required this.largest});

  final WeeklyTotal week;
  final Duration largest;

  @override
  Widget build(BuildContext context) {
    final lastDay = DateTime(week.end.year, week.end.month, week.end.day - 1);
    final localizations = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 10,
          runSpacing: 4,
          children: [
            Text(
              '${localizations.formatShortDate(week.start)} – ${localizations.formatShortDate(lastDay)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 10),
            ),
            Text(
              _durationLabel(week.total),
              style: const TextStyle(color: AppColors.text, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: largest == Duration.zero
              ? 0
              : (week.total.inMicroseconds / largest.inMicroseconds).clamp(
                  0.0,
                  1.0,
                ),
          color: AppColors.cyan,
          minHeight: 4,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _ReportNotes extends StatelessWidget {
  const _ReportNotes({required this.notes, required this.color});

  final List<String> notes;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < notes.length; i++) ...[
        if (i > 0) const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Icon(Icons.circle, size: 5, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                notes[i],
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    ],
  );
}
