import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';

class DeleteShopConfirmation {
  static const String _expectedPhrase = 'CONFIRM';

  static Future<void> show(
    BuildContext context, {
    required String shopName,
    required Future<void> Function() onConfirmed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => _DeleteShopSheet(
        shopName: shopName,
        expectedPhrase: _expectedPhrase,
        onConfirmed: onConfirmed,
      ),
    );
  }
}

class _DeleteShopSheet extends StatefulWidget {
  final String shopName;
  final String expectedPhrase;
  final Future<void> Function() onConfirmed;

  const _DeleteShopSheet({
    required this.shopName,
    required this.expectedPhrase,
    required this.onConfirmed,
  });

  @override
  State<_DeleteShopSheet> createState() => _DeleteShopSheetState();
}

class _DeleteShopSheetState extends State<_DeleteShopSheet> {
  final TextEditingController _confirmCtrl = TextEditingController();
  bool _acceptedRisk = false;
  bool _isDeleting = false;

  static const Color _danger = Color(0xFFDC2626);
  static const Color _dangerSoft = Color(0xFFFEE2E2);
  static const Color _border = Color(0xFFFCA5A5);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _outline = Color(0xFFE2E8F0);
  static const Color _bg = Color(0xFFF8FAFC);

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _phraseMatches =>
      _confirmCtrl.text.trim().toUpperCase() == widget.expectedPhrase;

  bool get _canDelete => _phraseMatches && _acceptedRisk && !_isDeleting;

  Future<void> _runDelete() async {
    if (!_canDelete) return;
    setState(() => _isDeleting = true);
    try {
      await widget.onConfirmed();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 5,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(color: _outline, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _dangerSoft, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.warning_amber_rounded, color: _danger, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Delete Shop",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _danger),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: _outline),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _dangerSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.dangerous_rounded, color: _danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "You're about to permanently delete \"${widget.shopName.isEmpty ? 'your shop' : widget.shopName}\"",
                                style: const TextStyle(color: _danger, fontWeight: FontWeight.w900, fontSize: 13.5),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          const Text(
                            "This action cannot be undone. Please review what will be removed before continuing.",
                            style: TextStyle(color: _danger, fontSize: 12, height: 1.4, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "WHAT WILL BE PERMANENTLY REMOVED",
                      style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    _bullet(Icons.storefront_rounded, "Your shop profile, logo, cover, permit and store details"),
                    _bullet(Icons.inventory_2_rounded, "All product listings and their images"),
                    _bullet(Icons.local_shipping_rounded, "Saved delivery rates"),
                    _bullet(Icons.qr_code_2_rounded, "Uploaded GCash and Maya QR codes"),
                    _bullet(Icons.history_rounded, "Order history visibility (placed orders may be retained for buyers' records)"),
                    _bullet(Icons.payments_rounded, "Payment preferences (payment first policy, accepted methods)"),
                    const SizedBox(height: 16),
                    const Text(
                      "BEFORE YOU CONTINUE",
                      style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    _caution("Fulfill or cancel any active orders. Buyers waiting on you will be left without a way to contact your shop."),
                    _caution("If you reopen later you'll need to re-upload your business permit and wait for review again."),
                    _caution("Any saved buyer trust or ratings tied to this shop will be lost."),
                    const SizedBox(height: 16),
                    const Text(
                      "TYPE CONFIRM TO PROCEED",
                      style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _confirmCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [LengthLimitingTextInputFormatter(20)],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: "Type CONFIRM",
                        hintStyle: TextStyle(color: _textSecondary.withValues(alpha: 0.7), letterSpacing: 2),
                        filled: true,
                        fillColor: _bg,
                        prefixIcon: Icon(
                          _phraseMatches ? Icons.check_circle_rounded : Icons.keyboard_rounded,
                          color: _phraseMatches ? const Color(0xFF16A34A) : _textSecondary,
                          size: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _outline)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _outline)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _danger, width: 1.5)),
                      ),
                      style: const TextStyle(letterSpacing: 2.4, fontWeight: FontWeight.w900, color: _textPrimary),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _acceptedRisk = !_acceptedRisk),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _acceptedRisk,
                              activeColor: _danger,
                              onChanged: (v) => setState(() => _acceptedRisk = v ?? false),
                            ),
                            const Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text(
                                  "I understand this action is permanent and cannot be undone.",
                                  style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.35),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: _outline)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isDeleting ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textPrimary,
                            side: BorderSide(color: _outline),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _canDelete ? _runDelete : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _danger,
                            disabledBackgroundColor: _danger.withValues(alpha: 0.35),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _isDeleting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.delete_forever_rounded, size: 18),
                          label: Text(_isDeleting ? "Deleting…" : "Delete Shop",
                              style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bullet(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: _textPrimary, fontSize: 12.5, height: 1.45, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _caution(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: const Color(0xFF7C2D12), fontSize: 12, height: 1.45, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
