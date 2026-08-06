import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

Future<File> buildReceiptPdf({
  required String billId,
  required double total,
  required List<Map<String, dynamic>> orders,
  required List<Map<String, dynamic>> payments,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('ROS Receipt',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Bill ${billId.substring(0, 8)}…'),
            pw.SizedBox(height: 16),
            for (final o in orders) ...[
              pw.Text(
                'Token #${o['token_no'] ?? '—'} · ${o['status']}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              for (final item in (o['order_item'] as List? ?? const []))
                pw.Text(
                  '  ${item['name']} × ${item['qty']}  ₹${item['line_total']}',
                ),
              pw.SizedBox(height: 8),
            ],
            pw.Divider(),
            pw.Text('Total ₹${total.toStringAsFixed(2)}',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            for (final p in payments)
              pw.Text('${p['method']}: ₹${p['amount']}'),
          ],
        );
      },
    ),
  );

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/receipt_${billId.substring(0, 8)}.pdf');
  await file.writeAsBytes(await doc.save());
  return file;
}

Future<void> shareReceiptPdf(File file) async {
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: 'Your receipt'),
  );
}
