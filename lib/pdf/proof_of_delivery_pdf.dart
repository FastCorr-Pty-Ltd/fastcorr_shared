import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Shared Proof of Delivery PDF — identical output for user app, admin app, and downloads.
Future<Uint8List> generateProofOfDeliveryPdf({
  required String contactName,
  required String contactAddress,
  required String contactPhone,
  required DateTime deliveryDateTime,
  String? signatureUrl,
  String? photoUrl,
  Uint8List? brandLogoBytes,
}) async {
  pw.MemoryImage? signatureImage;
  pw.MemoryImage? photoImage;

  if (signatureUrl != null && signatureUrl.isNotEmpty) {
    try {
      final res = await http.get(Uri.parse(signatureUrl));
      if (res.statusCode == 200) {
        signatureImage = pw.MemoryImage(res.bodyBytes);
      }
    } catch (_) {}
  }

  if (photoUrl != null && photoUrl.isNotEmpty) {
    try {
      final res = await http.get(Uri.parse(photoUrl));
      if (res.statusCode == 200) {
        photoImage = pw.MemoryImage(res.bodyBytes);
      }
    } catch (_) {}
  }

  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context pdfContext) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.blue200, width: 2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PROOF OF DELIVERY',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Generated: ${DateFormat('MMMM dd, yyyy - HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DELIVERY INFORMATION',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  _pdfDetailRow('Recipient Name', contactName),
                  _pdfDetailRow('Address', contactAddress),
                  _pdfDetailRow('Phone', contactPhone),
                  _pdfDetailRow(
                    'Delivery Date & Time',
                    DateFormat('MMMM dd, yyyy at HH:mm').format(deliveryDateTime),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            if (signatureImage != null) ...[
              pw.Text(
                'RECIPIENT SIGNATURE',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                width: double.infinity,
                height: 150,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                  color: PdfColors.grey100,
                ),
                child: pw.Center(
                  child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                ),
              ),
              pw.SizedBox(height: 20),
            ] else ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.red200),
                ),
                child: pw.Text(
                  'No signature captured',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.red700,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
            ],
            if (photoImage != null) ...[
              pw.Text(
                'DELIVERY PHOTO',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                width: double.infinity,
                height: 200,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                  color: PdfColors.grey100,
                ),
                child: pw.Center(
                  child: pw.Image(photoImage, fit: pw.BoxFit.contain),
                ),
              ),
            ] else ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.orange200),
                ),
                child: pw.Text(
                  'No delivery photo captured',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.orange700,
                  ),
                ),
              ),
            ],
            pw.SizedBox(height: 30),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'This is a computer-generated proof of delivery document.',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  if (brandLogoBytes != null && brandLogoBytes.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Image(
                        pw.MemoryImage(brandLogoBytes),
                        height: 40,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  pw.Text(
                    'Generated by FastCorr • © ${DateTime.now().year}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  final bytes = await pdf.save();
  return Uint8List.fromList(bytes);
}

pw.Widget _pdfDetailRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
