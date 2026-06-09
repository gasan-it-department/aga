import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gasan_port_tracker/Activities/UserOrders.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';

class OrderPlaced extends StatelessWidget {
  final String orderId;
  final String sellerName;
  final List<Map<String, dynamic>> items; // {name, qty, unit_price, line_total}
  final num total;
  final String paymentChannel;
  final String deliveryType; // "Delivery" / "Pickup"
  final Map<String, dynamic> deliveryAddress;
  final String notes;
  final DateTime placedAt;

  const OrderPlaced({
    super.key,
    required this.orderId,
    required this.sellerName,
    required this.items,
    required this.total,
    required this.paymentChannel,
    required this.deliveryType,
    required this.deliveryAddress,
    required this.notes,
    required this.placedAt,
  });

  static const Color _primaryDark = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF10B981);
  static const Color _accent = Color(0xFF2563EB);
  static const Color _orange = Color(0xFFEE4D2D);

  String get _buyerName {
    final parts = [
      (deliveryAddress['first_name'] ?? '').toString().trim(),
      (deliveryAddress['middle_name'] ?? '').toString().trim(),
      (deliveryAddress['last_name'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty);
    return parts.join(' ');
  }

  String get _addressLine {
    final parts = [
      (deliveryAddress['street'] ?? '').toString().trim(),
      (deliveryAddress['barangay'] ?? '').toString().trim(),
      (deliveryAddress['municipality'] ?? '').toString().trim(),
      (deliveryAddress['province'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty);
    return parts.join(', ');
  }

  String _money(num v) => "PHP ${Utility().formatPrice(v)}";

  Future<Uint8List?> _renderReceiptPng() async {
    final pdfBytes = await _buildReceiptPdf();
    await for (final page in Printing.raster(pdfBytes, pages: [0], dpi: 220)) {
      return await page.toPng();
    }
    return null;
  }

  Future<void> _saveReceiptImage(BuildContext context) async {
    try {
      final pngBytes = await _renderReceiptPng();
      if (pngBytes == null) throw Exception("Empty receipt");

      final filename = 'Receipt-$orderId.png';

      if (kIsWeb) {
        // On web, hand the PNG to the system share/save sheet.
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(pngBytes, mimeType: 'image/png', name: filename)],
          fileNameOverrides: [filename],
          subject: 'Order Receipt $orderId',
        ));
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(pngBytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png', name: filename)],
        subject: 'Order Receipt $orderId',
      ));
    } catch (e) {
      if (context.mounted) {
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Could not save receipt: $e");
      }
    }
  }

  Future<Uint8List> _buildReceiptPdf() async {
    final doc = pw.Document();
    final df = "${placedAt.year}-${placedAt.month.toString().padLeft(2, '0')}-${placedAt.day.toString().padLeft(2, '0')} "
        "${placedAt.hour.toString().padLeft(2, '0')}:${placedAt.minute.toString().padLeft(2, '0')}";

    final buyerName = _buyerName.isEmpty ? '—' : _buyerName;
    final contact = (deliveryAddress['contact_number'] ?? '').toString();
    final email = (deliveryAddress['email'] ?? '').toString();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF0F172A),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("AGA Gasan App",
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text("Order Receipt",
                          style: pw.TextStyle(color: PdfColor.fromInt(0xFFCBD5E1), fontSize: 11)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(orderId,
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text(df, style: pw.TextStyle(color: PdfColor.fromInt(0xFFCBD5E1), fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _pdfBlock("Shop", [sellerName.isEmpty ? '—' : sellerName]),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _pdfBlock("Buyer", [
                    buyerName,
                    if (contact.isNotEmpty) "Contact: $contact",
                    if (email.isNotEmpty) "Email: $email",
                  ]),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            _pdfBlock("Fulfillment", [
              deliveryType,
              if (_addressLine.isNotEmpty) _addressLine,
              if (notes.isNotEmpty) "Note: $notes",
            ]),
            pw.SizedBox(height: 12),
            _pdfBlock("Payment", [paymentChannel]),
            pw.SizedBox(height: 18),
            pw.Text("ITEMS",
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF64748B), letterSpacing: 1.2)),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF2563EB)),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              columnWidths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              headers: const ['Item', 'Qty', 'Unit Price', 'Line Total'],
              data: items.map((it) {
                return [
                  (it['name'] ?? '').toString(),
                  (it['qty'] ?? 1).toString(),
                  _money((it['unit_price'] as num?) ?? 0),
                  _money((it['line_total'] as num?) ?? 0),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 18),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFEE4D2D),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    "TOTAL  ${_money(total)}",
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              "This receipt was generated automatically by the AGA Gasan App. Keep it for your records.",
              style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B)),
            ),
          ];
        },
      ),
    );
    return doc.save();
  }

  pw.Widget _pdfBlock(String label, List<String> lines) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label.toUpperCase(),
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF64748B), letterSpacing: 1.2)),
          pw.SizedBox(height: 4),
          ...lines.where((l) => l.trim().isNotEmpty).map(
                (l) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(l, style: const pw.TextStyle(fontSize: 10)),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: _primaryDark),
                    onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                  ),
                ),
                const SizedBox(height: 8),
                // --- HERO ---
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_success.withValues(alpha: 0.12), _accent.withValues(alpha: 0.06)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _success.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeOutBack,
                        builder: (_, v, child) => Transform.scale(scale: v, child: child),
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(color: _success, shape: BoxShape.circle, boxShadow: [
                            BoxShadow(color: _success.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 8)),
                          ]),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text("Order Placed",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _primaryDark, letterSpacing: -0.4)),
                      const SizedBox(height: 6),
                      Text(
                        "Thanks for ordering from ${sellerName.isEmpty ? 'this shop' : sellerName}. We've notified the seller — you'll get updates as it progresses.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.45, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _border),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.tag_rounded, size: 14, color: _accent),
                          const SizedBox(width: 6),
                          Text(orderId,
                              style: TextStyle(color: _primaryDark, fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 0.3)),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // --- SUMMARY CARD ---
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("ORDER SUMMARY",
                          style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w900, fontSize: 10.5, letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      for (final it in items) _summaryRow(it),
                      const Divider(height: 22, color: _border),
                      Row(children: [
                        const Text("Total",
                            style: TextStyle(color: _primaryDark, fontWeight: FontWeight.w900, fontSize: 14)),
                        const Spacer(),
                        Text(_money(total),
                            style: const TextStyle(color: _orange, fontWeight: FontWeight.w900, fontSize: 18)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // --- DETAILS CARD ---
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("DETAILS",
                          style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w900, fontSize: 10.5, letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      _kv(Icons.local_shipping_rounded, "Fulfillment", deliveryType),
                      if (_addressLine.isNotEmpty) _kv(Icons.location_on_rounded, "Address", _addressLine),
                      if (_buyerName.isNotEmpty) _kv(Icons.person_rounded, "Buyer", _buyerName),
                      if ((deliveryAddress['contact_number'] ?? '').toString().isNotEmpty)
                        _kv(Icons.call_rounded, "Contact", deliveryAddress['contact_number'].toString()),
                      _kv(Icons.payments_rounded, "Payment", paymentChannel),
                      if (notes.isNotEmpty) _kv(Icons.notes_rounded, "Notes", notes),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // --- ACTIONS ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _saveReceiptImage(context),
                    icon: const Icon(Icons.image_rounded, size: 18),
                    label: const Text("Save Receipt as Image", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.popUntil(context, (r) => r.isFirst);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const UserOrders()));
                    },
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text("View My Orders", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                  icon: Icon(Icons.home_rounded, color: _textSecondary, size: 18),
                  label: Text("Back to Home",
                      style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(Map<String, dynamic> it) {
    final qty = (it['qty'] as num?) ?? 1;
    final unit = (it['unit_price'] as num?) ?? 0;
    final line = (it['line_total'] as num?) ?? (unit * qty);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text("×$qty",
                style: const TextStyle(color: _accent, fontWeight: FontWeight.w900, fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((it['name'] ?? 'Item').toString(),
                    style: const TextStyle(color: _primaryDark, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 2),
                Text("${_money(unit)} each",
                    style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w600, fontSize: 11)),
              ],
            ),
          ),
          Text(_money(line),
              style: const TextStyle(color: _primaryDark, fontWeight: FontWeight.w900, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _kv(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: _accent),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 86,
            child: Text(label,
                style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w800, fontSize: 11.5)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: _primaryDark, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
