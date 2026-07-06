import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';

class OrderDetails extends StatelessWidget {
  const OrderDetails({super.key, required this.order, this.sellerView = false});

  final Map<String, dynamic> order;
  final bool sellerView;

  static const _bg = Color(0xFFF6F8FB);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);
  static const _blue = Color(0xFF2563EB);
  static const _orange = Color(0xFFEA580C);

  @override
  Widget build(BuildContext context) {
    final status = (order['order_status'] ?? 'placed').toString().toLowerCase();
    final items = List<Map<String, dynamic>>.from(order['_items'] ?? const []);
    final address = _asMap(order['order_delivery_address']);
    final payment = _asMap(order['order_payment_details']);
    final deliveryType = _deliveryType(address);
    final subtotal =
        _number(order['_subtotal']) ??
        items.fold<num>(
          0,
          (sum, item) => sum + (_number(item['line_total']) ?? 0),
        );
    final deliveryFee = _number(order['_delivery_fee']) ?? _deliveryFee(order);
    final total = _number(order['_total']) ?? subtotal + deliveryFee;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Order Details',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
            children: [
              _header(status, deliveryType, items),
              const SizedBox(height: 12),
              _progress(status, deliveryType),
              const SizedBox(height: 12),
              _section(
                title: 'Items',
                icon: Icons.shopping_bag_outlined,
                child: Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      _item(items[i]),
                      if (i != items.length - 1)
                        const Divider(height: 20, color: _line),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _section(
                title: deliveryType == 'Pickup'
                    ? 'Pickup Information'
                    : 'Delivery Information',
                icon: deliveryType == 'Pickup'
                    ? Icons.storefront_outlined
                    : Icons.local_shipping_outlined,
                child: Column(
                  children: [
                    if (sellerView) ..._buyerRows(address),
                    _detailRow(
                      Icons.location_on_outlined,
                      deliveryType == 'Pickup' ? 'Pickup location' : 'Address',
                      _addressLine(address),
                    ),
                    _detailRow(
                      Icons.payments_outlined,
                      'Payment',
                      _paymentLabel(payment),
                    ),
                    if ((order['order_notes'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty)
                      _detailRow(
                        Icons.notes_rounded,
                        'Order note',
                        order['order_notes'].toString(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _section(
                title: 'Payment Summary',
                icon: Icons.receipt_long_outlined,
                child: Column(
                  children: [
                    _amountRow('Items subtotal', subtotal),
                    if (deliveryFee > 0)
                      _amountRow('Delivery fee', deliveryFee),
                    const SizedBox(height: 8),
                    _amountRow('Voucher discount', 0),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: _line),
                    ),
                    _amountRow('Total', total, total: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    String status,
    String deliveryType,
    List<Map<String, dynamic>> items,
  ) {
    final id = order['order_id']?.toString() ?? 'Order';
    final quantity = items.fold<num>(
      0,
      (sum, item) => sum + (_number(item['qty']) ?? 0),
    );
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF123B68),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF123B68).withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(status).toUpperCase(),
                  style: TextStyle(
                    color: color == const Color(0xFFF8FAFC)
                        ? _ink
                        : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                deliveryType == 'Pickup'
                    ? Icons.storefront_rounded
                    : Icons.local_shipping_rounded,
                color: Colors.white70,
                size: 17,
              ),
              const SizedBox(width: 6),
              Text(
                deliveryType,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'ORDER NUMBER',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            id,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${quantity.toInt()} item${quantity == 1 ? '' : 's'} in this order',
            style: const TextStyle(
              color: Color(0xFFD7E3F0),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progress(String status, String deliveryType) {
    final steps = deliveryType == 'Pickup'
        ? ['placed', 'preparing', 'ready for pickup', 'completed']
        : ['placed', 'preparing', 'out for delivery', 'completed'];
    final cancelled = status == 'cancelled' || status == 'canceled';
    final activeIndex = steps.indexOf(status);
    return _section(
      title: 'Order Progress',
      icon: Icons.route_outlined,
      child: cancelled
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cancel_rounded, color: Color(0xFFDC2626)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This order was cancelled',
                      style: TextStyle(
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 480) {
                  return Column(
                    children: List.generate(
                      steps.length,
                      (index) => _verticalProgressStep(
                        steps[index],
                        reached: activeIndex >= index,
                        current: activeIndex == index,
                        last: index == steps.length - 1,
                      ),
                    ),
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    steps.length,
                    (index) => Expanded(
                      child: _horizontalProgressStep(
                        steps[index],
                        reached: activeIndex >= index,
                        current: activeIndex == index,
                        first: index == 0,
                        last: index == steps.length - 1,
                        lineBeforeReached: activeIndex >= index,
                        lineAfterReached: activeIndex > index,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _horizontalProgressStep(
    String status, {
    required bool reached,
    required bool current,
    required bool first,
    required bool last,
    required bool lineBeforeReached,
    required bool lineAfterReached,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 2,
                color: first
                    ? Colors.transparent
                    : lineBeforeReached
                    ? _blue
                    : _line,
              ),
            ),
            _progressMarker(status, reached: reached, current: current),
            Expanded(
              child: Container(
                height: 2,
                color: last
                    ? Colors.transparent
                    : lineAfterReached
                    ? _blue
                    : _line,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _progressLabel(status),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            color: current
                ? _blue
                : reached
                ? _ink
                : _muted,
            fontSize: 11,
            fontWeight: current ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _verticalProgressStep(
    String status, {
    required bool reached,
    required bool current,
    required bool last,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Column(
            children: [
              _progressMarker(status, reached: reached, current: current),
              if (!last)
                Container(
                  width: 2,
                  height: 34,
                  color: reached && !current ? _blue : _line,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 4, bottom: last ? 0 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _progressLabel(status),
                  style: TextStyle(
                    color: current
                        ? _blue
                        : reached
                        ? _ink
                        : _muted,
                    fontSize: 13,
                    fontWeight: current ? FontWeight.w900 : FontWeight.w800,
                  ),
                ),
                if (current) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Current order status',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _progressMarker(
    String status, {
    required bool reached,
    required bool current,
  }) {
    return Container(
      width: current ? 34 : 30,
      height: current ? 34 : 30,
      decoration: BoxDecoration(
        color: reached ? _blue : const Color(0xFFF8FAFC),
        shape: BoxShape.circle,
        border: Border.all(
          color: reached ? _blue : _line,
          width: current ? 3 : 1.5,
        ),
        boxShadow: current
            ? [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.22),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Icon(
        reached ? Icons.check_rounded : _stepIcon(status),
        color: reached ? Colors.white : _muted,
        size: 16,
      ),
    );
  }

  String _progressLabel(String status) => switch (status) {
    'placed' => 'Order Placed',
    'preparing' => 'Preparing',
    'ready for pickup' => 'Ready for Pickup',
    'out for delivery' => 'Out for Delivery',
    'completed' => 'Completed',
    _ => _statusLabel(status),
  };

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _blue, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _item(Map<String, dynamic> item) {
    final storeItem = _asMap(item['store_item']);
    final name =
        storeItem['item_name']?.toString() ??
        item['order_item_id']?.toString() ??
        'Item';
    final image = _firstImage(storeItem['item_images']);
    final variation = _asMap(item['variation'] ?? item['order_variation']);
    final qty = _number(item['qty'] ?? item['order_quantity']) ?? 1;
    final lineTotal =
        _number(item['line_total'] ?? item['order_total_price']) ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 58,
            height: 58,
            child: image == null
                ? _imageFallback()
                : Image(
                    image: image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _imageFallback(),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (variation.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'Variant: ${variation['label'] ?? '-'}',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 5),
              Text(
                'Qty ${qty.toInt()}',
                style: const TextStyle(
                  color: _blue,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '\u20B1${Utility().formatPrice(lineTotal)}',
          style: const TextStyle(
            color: _ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _muted, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buyerRows(Map<String, dynamic> address) {
    final name =
        [address['first_name'], address['middle_name'], address['last_name']]
            .where(
              (value) => value != null && value.toString().trim().isNotEmpty,
            )
            .join(' ');
    return [
      if (name.isNotEmpty) _detailRow(Icons.person_outline, 'Customer', name),
      if ((address['contact_number'] ?? '').toString().isNotEmpty)
        _detailRow(
          Icons.phone_outlined,
          'Contact number',
          address['contact_number'].toString(),
        ),
    ];
  }

  Widget _amountRow(String label, num value, {bool total = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: total ? _ink : _muted,
            fontSize: total ? 14 : 12.5,
            fontWeight: total ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          '\u20B1${Utility().formatPrice(value)}',
          style: TextStyle(
            color: total ? _orange : _ink,
            fontSize: total ? 19 : 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  String _deliveryType(Map<String, dynamic> address) {
    final type = (address['delivery_type'] ?? address['type'] ?? '').toString();
    return type.toLowerCase().contains('pickup') ? 'Pickup' : 'Delivery';
  }

  String _addressLine(Map<String, dynamic> address) {
    final direct = address['formatted_address'] ?? address['address'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString();
    }
    return [
          address['street'],
          address['barangay'],
          address['municipality'],
          address['province'],
          address['zip_code'],
        ]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .join(', ');
  }

  String _paymentLabel(Map<String, dynamic> payment) {
    return (payment['channel'] ??
            payment['payment_method'] ??
            payment['method'] ??
            'Not specified')
        .toString();
  }

  num _deliveryFee(Map<String, dynamic> source) {
    for (final raw in [
      source['order_meta_data'],
      source['order_delivery_address'],
    ]) {
      final data = _asMap(raw);
      final value = _number(
        data['delivery_fee'] ??
            data['shipping_fee'] ??
            data['fee'] ??
            data['rate_amount'],
      );
      if (value != null && value > 0) return value;
    }
    return 0;
  }

  num? _number(dynamic value) => num.tryParse(value?.toString() ?? '');

  ImageProvider? _firstImage(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    final value = raw.first?.toString() ?? '';
    if (value.startsWith('http')) return NetworkImage(value);
    final bytes = Utility.decodeHexImage(value);
    return bytes == null ? null : MemoryImage(bytes);
  }

  Widget _imageFallback() => Container(
    color: const Color(0xFFF1F5F9),
    child: const Icon(Icons.image_outlined, color: _muted),
  );

  Color _statusColor(String status) => switch (status) {
    'completed' => const Color(0xFF22C55E),
    'cancelled' || 'canceled' => const Color(0xFFF87171),
    'preparing' => const Color(0xFFF59E0B),
    'ready for pickup' || 'out for delivery' => const Color(0xFF38BDF8),
    _ => const Color(0xFFF8FAFC),
  };

  String _statusLabel(String status) => switch (status) {
    'ready for pickup' => 'Ready for Pickup',
    'out for delivery' => 'Out for Delivery',
    _ => status.replaceAll('_', ' '),
  };

  IconData _stepIcon(String status) => switch (status) {
    'placed' => Icons.receipt_outlined,
    'preparing' => Icons.inventory_2_outlined,
    'ready for pickup' => Icons.storefront_outlined,
    'out for delivery' => Icons.local_shipping_outlined,
    _ => Icons.check_rounded,
  };
}
