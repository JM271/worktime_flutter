import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const excelMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

Future<OpenResult> openMonthlyWorkbook(String path) =>
    OpenFilex.open(path, type: excelMimeType);

class MonthlyReportDialog extends StatefulWidget {
  const MonthlyReportDialog({
    super.key,
    required this.report,
    required this.filename,
    required this.bytes,
    this.openFile = openMonthlyWorkbook,
  });

  final String report;
  final String filename;
  final Uint8List bytes;
  final Future<OpenResult> Function(String path) openFile;

  @override
  State<MonthlyReportDialog> createState() => _MonthlyReportDialogState();
}

class _MonthlyReportDialogState extends State<MonthlyReportDialog> {
  bool busy = false;
  String? error;
  String? savedPath;

  XFile get workbook => XFile.fromData(widget.bytes, mimeType: excelMimeType);

  Future<void> openExcel() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (savedPath == null) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/${widget.filename}';
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Monthly report'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.filename),
          const SizedBox(height: 16),
          SelectableText(widget.report),
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
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Done'),
      ),
      OutlinedButton.icon(
        onPressed: busy ? null : shareExcel,
        icon: const Icon(Icons.ios_share),
        label: const Text('Share Excel'),
      ),
      FilledButton.icon(
        onPressed: busy ? null : openExcel,
        icon: const Icon(Icons.open_in_new),
        label: const Text('Open Excel'),
      ),
    ],
  );
}
