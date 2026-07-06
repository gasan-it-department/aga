import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreAnalytics extends StatefulWidget {
  final String sellerId;
  final String storeName;

  const StoreAnalytics({
    super.key,
    required this.sellerId,
    required this.storeName,
  });

  @override
  State<StoreAnalytics> createState() => _StoreAnalyticsState();
}

class _StoreAnalyticsState extends State<StoreAnalytics> {
  final _supabase = Supabase.instance.client;

  static const _bg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF172033);
  static const _muted = Color(0xFF667085);
  static const _border = Color(0xFFE4E7EC);
  static const _blue = Color(0xFF2563EB);
  static const _green = Color(0xFF16A36A);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFE5484D);

  bool _loading = true;
  int _visits = 0;
  int _uniqueVisitors = 0;
  int _orders = 0;
  int _completedOrders = 0;
  num _revenue = 0;
  List<double> _dailyVisits = List.filled(7, 0);
  List<double> _dailyOrders = List.filled(7, 0);
  Map<String, int> _statusCounts = {};
  List<MapEntry<String, num>> _topProducts = [];

  double get _conversion =>
      _uniqueVisitors == 0 ? 0 : (_orders / _uniqueVisitors) * 100;
  num get _averageOrder =>
      _completedOrders == 0 ? 0 : _revenue / _completedOrders;
  int get _visitsLast7Days =>
      _dailyVisits.fold<double>(0, (sum, value) => sum + value).round();
  int get _ordersLast7Days =>
      _dailyOrders.fold<double>(0, (sum, value) => sum + value).round();

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  DateTime? _dateOf(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    return DateTime.tryParse(raw.toString());
  }

  Future<void> _loadAnalytics() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _supabase
            .from('shop_visitor')
            .select()
            .eq('visitor_store_id', widget.sellerId),
        _supabase
            .from('orders')
            .select()
            .eq('order_seller_id', widget.sellerId),
        _supabase
            .from('store_items')
            .select('item_id, item_name')
            .eq('item_seller_id', widget.sellerId),
      ]);

      final visits = List<Map<String, dynamic>>.from(results[0] as List);
      final orderRows = List<Map<String, dynamic>>.from(results[1] as List);
      final items = List<Map<String, dynamic>>.from(results[2] as List);
      final itemNames = {
        for (final item in items)
          item['item_id'].toString(): (item['item_name'] ?? 'Unnamed product')
              .toString(),
      };

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = today.subtract(const Duration(days: 6));
      final dailyVisits = List<double>.filled(7, 0);
      final dailyOrders = List<double>.filled(7, 0);
      final visitors = <String>{};
      final orderIds = <String>{};
      final completedIds = <String>{};
      final statusByOrder = <String, String>{};
      final revenueByOrder = <String, num>{};
      final productSales = <String, num>{};

      for (final visit in visits) {
        final visitor = visit['visitor_id']?.toString();
        if (visitor != null && visitor.isNotEmpty) visitors.add(visitor);
        final date = _dateOf(visit['visitor_visit_date']);
        if (date != null) {
          final day = DateTime(date.year, date.month, date.day);
          final index = day.difference(start).inDays;
          if (index >= 0 && index < 7) dailyVisits[index]++;
        }
      }

      for (final row in orderRows) {
        final orderId = row['order_id']?.toString() ?? '';
        if (orderId.isEmpty) continue;
        orderIds.add(orderId);
        final status =
            row['order_status']?.toString().toLowerCase() ?? 'placed';
        statusByOrder[orderId] = status;
        if (status == 'completed') {
          completedIds.add(orderId);
          revenueByOrder[orderId] =
              (revenueByOrder[orderId] ?? 0) +
              (num.tryParse(row['order_total_price']?.toString() ?? '0') ?? 0);
          final itemId = row['order_item_id']?.toString() ?? '';
          productSales[itemId] =
              (productSales[itemId] ?? 0) +
              (num.tryParse(row['order_quantity']?.toString() ?? '1') ?? 1);
        }
      }

      // Order IDs use a microsecond timestamp suffix in the current checkout flow.
      for (final orderId in orderIds) {
        final micros = int.tryParse(orderId.replaceFirst('ORDER_', ''));
        if (micros == null) continue;
        final date = DateTime.fromMicrosecondsSinceEpoch(micros);
        final day = DateTime(date.year, date.month, date.day);
        final index = day.difference(start).inDays;
        if (index >= 0 && index < 7) dailyOrders[index]++;
      }

      final statuses = <String, int>{};
      for (final status in statusByOrder.values) {
        statuses[status] = (statuses[status] ?? 0) + 1;
      }
      final topProducts =
          productSales.entries
              .map(
                (entry) => MapEntry(
                  itemNames[entry.key] ?? 'Deleted product',
                  entry.value,
                ),
              )
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      if (mounted) {
        setState(() {
          _visits = visits.length;
          _uniqueVisitors = visitors.length;
          _orders = orderIds.length;
          _completedOrders = completedIds.length;
          _revenue = revenueByOrder.values.fold<num>(
            0,
            (sum, value) => sum + value,
          );
          _dailyVisits = dailyVisits;
          _dailyOrders = dailyOrders;
          _statusCounts = statuses;
          _topProducts = topProducts.take(5).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Store analytics error: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to load analytics: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Store Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              widget.storeName,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: LayoutBuilder(
                builder: (context, constraints) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth >= 1000 ? 32 : 16,
                    24,
                    constraints.maxWidth >= 1000 ? 32 : 16,
                    40,
                  ),
                  children: [
                    _buildMetrics(),
                    const SizedBox(height: 16),
                    if (constraints.maxWidth >= 900)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _trafficChart()),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: _statusChart()),
                        ],
                      )
                    else ...[
                      _trafficChart(),
                      const SizedBox(height: 16),
                      _statusChart(),
                    ],
                    const SizedBox(height: 16),
                    _topProductsPanel(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetrics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 540
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metric(
              'Completed Sales',
              'PHP ${Utility().formatPrice(_revenue)}',
              'Total revenue from completed orders',
              Icons.payments_outlined,
              _green,
              width,
            ),
            _metric(
              'Store visits',
              '$_visits',
              '$_visitsLast7Days visits in the last 7 days',
              Icons.visibility_outlined,
              _blue,
              width,
              supportingDetail: '$_uniqueVisitors unique visitors overall',
            ),
            _metric(
              'Orders',
              '$_orders',
              '$_ordersLast7Days orders in the last 7 days',
              Icons.receipt_long_outlined,
              _amber,
              width,
              supportingDetail: '$_completedOrders completed overall',
            ),
            _metric(
              'Visitor conversion',
              '${_conversion.toStringAsFixed(1)}%',
              'Visitors who placed an order',
              Icons.trending_up_rounded,
              const Color(0xFF7F56D9),
              width,
              supportingDetail:
                  'Average completed order: PHP ${Utility().formatPrice(_averageOrder)}',
            ),
          ],
        );
      },
    );
  }

  Widget _metric(
    String title,
    String value,
    String detail,
    IconData icon,
    Color color,
    double width, {
    String? supportingDetail,
  }) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  detail,
                  style: const TextStyle(color: _muted, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                if (supportingDetail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    supportingDetail,
                    style: const TextStyle(color: _muted, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trafficChart() {
    final maxValue = [
      ..._dailyVisits,
      ..._dailyOrders,
    ].fold<double>(1, (max, value) => value > max ? value : max);
    return _panel(
      title: 'Store activity',
      subtitle: 'Daily store visits and placed orders during the last 7 days',
      child: SizedBox(
        height: 260,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxValue + 1,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxValue / 4).clamp(1, double.infinity),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 28),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    final date = DateTime.now().subtract(
                      Duration(days: 6 - index),
                    );
                    const labels = [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ];
                    return index >= 0 && index < 7
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              index == 6 ? 'Today' : labels[date.weekday - 1],
                              style: const TextStyle(
                                fontSize: 9,
                                color: _muted,
                              ),
                            ),
                          )
                        : const SizedBox.shrink();
                  },
                ),
              ),
            ),
            lineBarsData: [
              _line(_dailyVisits, _blue),
              _line(_dailyOrders, _green),
            ],
          ),
        ),
      ),
      footer: const Row(
        children: [
          _Legend(color: _blue, label: 'Visits'),
          SizedBox(width: 18),
          _Legend(color: _green, label: 'Orders'),
        ],
      ),
    );
  }

  LineChartBarData _line(List<double> values, Color color) => LineChartBarData(
    spots: List.generate(
      values.length,
      (index) => FlSpot(index.toDouble(), values[index]),
    ),
    color: color,
    barWidth: 3,
    isCurved: false,
    dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: .08)),
  );

  Widget _statusChart() {
    final entries = _statusCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final colors = [
      _blue,
      _green,
      _amber,
      _red,
      const Color(0xFF7F56D9),
      const Color(0xFF06B6D4),
    ];
    return _panel(
      title: 'Order status',
      subtitle: 'Current order distribution',
      child: SizedBox(
        height: 210,
        child: entries.isEmpty
            ? _empty('No orders yet')
            : PieChart(
                PieChartData(
                  centerSpaceRadius: 48,
                  sectionsSpace: 3,
                  sections: List.generate(entries.length, (index) {
                    final entry = entries[index];
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      color: colors[index % colors.length],
                      radius: 36,
                      title: '${entry.value}',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    );
                  }),
                ),
              ),
      ),
      footer: Wrap(
        spacing: 14,
        runSpacing: 8,
        children: List.generate(
          entries.length,
          (index) => _Legend(
            color: colors[index % colors.length],
            label: entries[index].key.replaceAll('_', ' '),
          ),
        ),
      ),
    );
  }

  Widget _topProductsPanel() {
    return _panel(
      title: 'Top products',
      subtitle: 'Ranked by quantity sold from completed orders',
      child: _topProducts.isEmpty
          ? SizedBox(
              height: 150,
              child: _empty('Completed sales will appear here'),
            )
          : Column(
              children: List.generate(_topProducts.length, (index) {
                final product = _topProducts[index];
                final max = _topProducts.first.value.toDouble();
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _topProducts.length - 1 ? 0 : 16,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    product.key,
                                    style: const TextStyle(
                                      color: _ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${product.value} sold',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            LinearProgressIndicator(
                              value: max == 0
                                  ? 0
                                  : product.value.toDouble() / max,
                              minHeight: 7,
                              borderRadius: BorderRadius.circular(4),
                              backgroundColor: _border,
                              color: _blue,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 20),
          child,
          if (footer != null) ...[const SizedBox(height: 16), footer],
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() => BoxDecoration(
    color: Colors.white,
    border: Border.all(color: _border),
    borderRadius: BorderRadius.circular(8),
  );

  Widget _empty(String text) => Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
    ),
  );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF667085),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
