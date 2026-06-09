import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../ModernBottomsheet/ModernBottomSheet.dart';

class VehicleGasolineDashboard extends StatefulWidget {
  final String vehicleId;
  final String vehicleName;

  const VehicleGasolineDashboard({
    super.key,
    required this.vehicleId,
    this.vehicleName = "Vehicle",
  });

  @override
  State<VehicleGasolineDashboard> createState() => _VehicleGasolineDashboardState();
}

class _VehicleGasolineDashboardState extends State<VehicleGasolineDashboard> {
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final _loadingDialog = LoadingDialog();
  final _classicDialog = ClassicDialog();

  SupabaseClient? _supabase;

  String _selectedFilter = 'All Time';
  final List<String> _filters = ['All Time', 'This Week', 'This Month', 'This Year', 'Custom'];

  // Custom Date Tracking
  DateTime? _customSelectedDate;

  final ScrollController _scrollController = ScrollController();
  final ScrollController _filterScrollController = ScrollController();

  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 0;
  final int _itemsPerPage = 15;

  List<Map<String, dynamic>> _fuelLogs = [];

  double _totalSpent = 0.0;
  double _totalLiters = 0.0;
  double _avgPricePerLiter = 0.0;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMoreLogs();
      }
    });

    _fetchInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _filterScrollController.dispose();
    super.dispose();
  }

  int _getStartEpoch() {
    final now = DateTime.now();
    DateTime start;

    switch (_selectedFilter) {
      case 'This Week':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'This Year':
        start = DateTime(now.year, 1, 1);
        break;
      case 'Custom':
        if (_customSelectedDate != null) {
          start = DateTime(_customSelectedDate!.year, _customSelectedDate!.month, _customSelectedDate!.day);
        } else {
          return 0;
        }
        break;
      case 'All Time':
      default:
        return 0;
    }
    return start.millisecondsSinceEpoch;
  }

  String _formatNumberWithCommas(double value, {int decimals = 2}) {
    List<String> parts = value.toStringAsFixed(decimals).split('.');
    parts[0] = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},'
    );
    return parts.join('.');
  }

  int? _getEndEpochIfCustom() {
    if (_selectedFilter == 'Custom' && _customSelectedDate != null) {
      final end = DateTime(_customSelectedDate!.year, _customSelectedDate!.month, _customSelectedDate!.day, 23, 59, 59, 999);
      return end.millisecondsSinceEpoch;
    }
    return null;
  }

  Future<void> _fetchInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _fuelLogs.clear();
      });

      final int startEpoch = _getStartEpoch();
      final int? endEpoch = _getEndEpochIfCustom();

      final statsResponse = await _supabase!
          .rpc(
        'get_vehicle_fuel_stats',
        params: {
          'v_id': widget.vehicleId,
          'start_epoch': startEpoch
        },
      );

      var query = _supabase!
          .from('gasoline')
          .select()
          .eq('vehicle_id', widget.vehicleId)
          .gte('date_filled', startEpoch);

      if (endEpoch != null) {
        query = query.lte('date_filled', endEpoch);
      }

      final logsResponse = await query
          .order('date_filled', ascending: false)
          .range(0, _itemsPerPage - 1);

      final List<Map<String, dynamic>> fetchedLogs = List<Map<String, dynamic>>.from(logsResponse);

      if (mounted) {
        setState(() {
          if (_selectedFilter == 'Custom') {
            double tempSpent = 0.0;
            double tempLiters = 0.0;
            for (var log in fetchedLogs) {
              final double l = double.tryParse(log['litters_filled']?.toString() ?? '0') ?? 0.0;
              final double p = double.tryParse(log['price_per_litter']?.toString() ?? '0') ?? 0.0;
              tempLiters += l;
              tempSpent += (l * p);
            }
            _totalLiters = tempLiters;
            _totalSpent = tempSpent;
            _avgPricePerLiter = tempLiters > 0 ? (tempSpent / tempLiters) : 0.0;
          } else {
            _totalLiters = double.tryParse(statsResponse['total_liters']?.toString() ?? '0') ?? 0.0;
            _totalSpent = double.tryParse(statsResponse['total_spent']?.toString() ?? '0') ?? 0.0;
            _avgPricePerLiter = double.tryParse(statsResponse['avg_price']?.toString() ?? '0') ?? 0.0;
          }

          _fuelLogs = fetchedLogs;
          _hasMoreData = fetchedLogs.length == _itemsPerPage;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching initial data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Failed to load fuel history.");
      }
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_isFetchingMore || !_hasMoreData || _isLoading) return;

    try {
      setState(() => _isFetchingMore = true);

      _currentPage++;
      final int from = _currentPage * _itemsPerPage;
      final int to = from + _itemsPerPage - 1;

      final int startEpoch = _getStartEpoch();
      final int? endEpoch = _getEndEpochIfCustom();

      var query = _supabase!
          .from('gasoline')
          .select()
          .eq('vehicle_id', widget.vehicleId)
          .gte('date_filled', startEpoch);

      if (endEpoch != null) {
        query = query.lte('date_filled', endEpoch);
      }

      final response = await query
          .order('date_filled', ascending: false)
          .range(from, to);

      final List<Map<String, dynamic>> newLogs = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _fuelLogs.addAll(newLogs);
          _hasMoreData = newLogs.length == _itemsPerPage;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching more logs: $e");
      if (mounted) {
        setState(() => _isFetchingMore = false);
      }
    }
  }

  void _showFuelLogOptions(Map<String, dynamic> log) {
    ModernBottomSheet.show(
      context: context,
      title: "Fuel Record Options",
      options: [
        SheetOption(
          icon: Icons.delete_forever_rounded,
          title: "Delete Record",
          isDestructive: true,
          onTap: () {
            _deleteFuelLog(log);
          },
        ),
      ],
    );
  }

  Future<void> _deleteFuelLog(Map<String, dynamic> log) async {
    _classicDialog.setTitle("Delete Record?");
    _classicDialog.setMessage("Are you sure you want to delete this record? This cannot be undone.");
    _classicDialog.setPositiveMessage("Delete");
    _classicDialog.setNegativeMessage("Cancel");
    if(mounted){
      _classicDialog.showTwoButtonDialog(context, (negativeClick){
        _classicDialog.dismissDialog();

      }, (positiveClicked) async {
        _classicDialog.dismissDialog();
        try {
          _loadingDialog.showLoadingDialog(context);

          await _supabase!
              .from('gasoline')
              .delete()
              .eq('gasoline_id', log['gasoline_id']);

          if (mounted) {
            _loadingDialog.dismiss();
            SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, "Record deleted successfully.");
            _fetchInitialData();
          }
        } catch (e) {
          if (mounted) {
            _loadingDialog.dismiss();
            SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Error deleting: $e");
          }
        }
      });
    }
  }

  // --- UI FORMATTING ---
  String _formatDateForInput(DateTime date) {
    int hour12 = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    String amPm = date.hour >= 12 ? 'PM' : 'AM';
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} at $hour12:${date.minute.toString().padLeft(2, '0')} $amPm";
  }

  String _formatCustomDatePill(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  void _showAddFuelSheet() {
    final formKey = GlobalKey<FormState>();
    final litersController = TextEditingController();
    final priceController = TextEditingController();

    DateTime selectedDate = DateTime.now();
    final dateController = TextEditingController(text: _formatDateForInput(selectedDate));

    ModernBottomSheet.show(
      context: context,
      title: "Log Fuel Receipt",
      subtitle: widget.vehicleName,
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: dateController,
                readOnly: true,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                decoration: InputDecoration(
                  labelText: "Date & Time Filled",
                  prefixIcon: Icon(Icons.calendar_month_rounded, color: textSecondary, size: 20),
                  filled: true,
                  fillColor: bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryDark, width: 2)),
                ),
                onTap: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(primary: primaryDark),
                        ),
                        child: child!,
                      );
                    },
                  );

                  if (pickedDate != null) {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selectedDate),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(primary: primaryDark),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (pickedTime != null) {
                      selectedDate = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                      dateController.text = _formatDateForInput(selectedDate);
                    }
                  }
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: litersController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                decoration: InputDecoration(
                  labelText: "Liters Filled",
                  prefixIcon: Icon(Icons.water_drop_rounded, color: textSecondary, size: 20),
                  filled: true,
                  fillColor: bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryDark, width: 2)),
                ),
                validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                decoration: InputDecoration(
                  labelText: "Price per Liter (₱)",
                  prefixIcon: Icon(Icons.payments_rounded, color: textSecondary, size: 20),
                  filled: true,
                  fillColor: bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryDark, width: 2)),
                ),
                validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final double liters = double.tryParse(litersController.text.trim()) ?? 0.0;
                    final double price = double.tryParse(priceController.text.trim()) ?? 0.0;
                    final int epochMs = selectedDate.millisecondsSinceEpoch;

                    Navigator.pop(context);
                    _saveFuelLog(liters, price, epochMs);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Save Fuel Record", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveFuelLog(double liters, double pricePerLiter, int dateFilledEpoch) async {
    try {
      _loadingDialog.showLoadingDialog(context);

      await _supabase!
          .from('gasoline')
          .insert({
        'vehicle_id': widget.vehicleId,
        'date_filled': dateFilledEpoch,
        'litters_filled': liters,
        'price_per_litter': pricePerLiter,
        'gasoline_id': Utility().generateUniqueID(),
      });

      if (mounted) {
        _loadingDialog.dismiss();
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, "Fuel record saved successfully.");
        _fetchInitialData();
      }
    } catch (e) {
      if (mounted) {
        _loadingDialog.dismiss();
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Fuel Dashboard", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
            Text(widget.vehicleName, style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_gas_station_rounded),
            tooltip: 'Add Fuel Log',
            onPressed: _showAddFuelSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
          child: Column(
            children: [
              _buildDashboardStats(),

              _buildFilters(),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF0A2E5C)))
                    : ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          if (_fuelLogs.isNotEmpty) ...[
                            _buildFuelSpendingChart(),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 12),
                              child: Text("Recent Records", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: textPrimary, letterSpacing: -0.5)),
                            ),
                          ],
                          if (_fuelLogs.isEmpty)
                            SizedBox(
                              height: 400,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long_rounded, size: 48, color: borderColor),
                                    const SizedBox(height: 16),
                                    Text(
                                      "No fuel records found for $_selectedFilter.",
                                      style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...List.generate(_fuelLogs.length, (index) => _buildFuelCard(_fuelLogs[index])),
                          if (_isFetchingMore)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator(color: Color(0xFF0A2E5C))),
                            ),
                          const SizedBox(height: 40),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardStats() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          _buildStatCard("Total Spent", "₱${_formatNumberWithCommas(_totalSpent, decimals: 2)}", const Color(0xFFEF4444), Icons.account_balance_wallet_rounded),
          const SizedBox(width: 12),
          _buildStatCard("Total Liters", "${_formatNumberWithCommas(_totalLiters, decimals: 1)} L", const Color(0xFF10B981), Icons.water_drop_rounded),
          const SizedBox(width: 12),
          _buildStatCard("Avg Price/L", "₱${_formatNumberWithCommas(_avgPricePerLiter, decimals: 2)}", const Color(0xFFF59E0B), Icons.price_change_rounded),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
              ],
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 54,
      color: bgColor,
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            final targetOffset = _filterScrollController.offset + pointerSignal.scrollDelta.dy;
            _filterScrollController.jumpTo(
                targetOffset.clamp(0.0, _filterScrollController.position.maxScrollExtent)
            );
          }
        },
        child: ListView.builder(
          controller: _filterScrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: _filters.length,
          itemBuilder: (context, index) {
            final filter = _filters[index];
            final isSelected = _selectedFilter == filter;

            String displayText = filter;
            if (filter == 'Custom' && _customSelectedDate != null) {
              displayText = _formatCustomDatePill(_customSelectedDate!);
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (filter == 'Custom') ...[
                      Icon(Icons.calendar_month_rounded, size: 14, color: isSelected ? Colors.white : textSecondary),
                      const SizedBox(width: 4),
                    ],
                    Text(displayText, style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: isSelected ? Colors.white : textSecondary,
                    )),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) async {
                  if (filter == 'Custom') {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _customSelectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(primary: primaryDark),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (pickedDate != null) {
                      setState(() {
                        _selectedFilter = 'Custom';
                        _customSelectedDate = pickedDate;
                      });
                      _fetchInitialData();
                    }
                  } else if (!isSelected) {
                    setState(() {
                      _selectedFilter = filter;
                      _customSelectedDate = null;
                    });
                    _fetchInitialData();
                  }
                },
                backgroundColor: Colors.white,
                selectedColor: primaryDark,
                side: BorderSide(color: isSelected ? primaryDark : borderColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFuelSpendingChart() {
    final List<FlSpot> spots = [];
    final List<Map<String, dynamic>> reversedLogs = List.from(_fuelLogs.reversed);
    
    double maxY = 0;
    for (int i = 0; i < reversedLogs.length; i++) {
      final double liters = double.tryParse(reversedLogs[i]['litters_filled']?.toString() ?? '0') ?? 0.0;
      final double price = double.tryParse(reversedLogs[i]['price_per_litter']?.toString() ?? '0') ?? 0.0;
      final double total = liters * price;
      if (total > maxY) maxY = total;
      spots.add(FlSpot(i.toDouble(), total));
    }

    maxY = (maxY / 500).ceil() * 500.0;
    if (maxY == 0) maxY = 1000;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 24, 24, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 20),
            child: Row(
              children: [
                Icon(Icons.auto_graph_rounded, size: 16, color: primaryDark),
                const SizedBox(width: 8),
                Text("Spending Trend (PHP)", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: textPrimary)),
              ],
            ),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(color: borderColor.withValues(alpha: 0.5), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(value.toInt().toString(), style: TextStyle(color: textSecondary, fontWeight: FontWeight.w700, fontSize: 9));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFFEF4444),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelCard(Map<String, dynamic> log) {
    final double liters = double.tryParse(log['litters_filled']?.toString() ?? '0') ?? 0.0;
    final double price = double.tryParse(log['price_per_litter']?.toString() ?? '0') ?? 0.0;
    final double total = liters * price;

    final int epochMs = int.tryParse(log['date_filled']?.toString() ?? '0') ?? 0;
    final int epochSeconds = epochMs;
    final String formattedDate = Utility().formatEpochToTime(epochSeconds);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(color: primaryDark.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))
          ]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showFuelLogOptions(log),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_gas_station_rounded, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          formattedDate,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textPrimary)
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text("${liters.toStringAsFixed(2)} Liters", style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w600)),
                          Text(" • ", style: TextStyle(fontSize: 13, color: borderColor, fontWeight: FontWeight.w900)),
                          Text("₱${_formatNumberWithCommas(price, decimals: 2)}/L", style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                        "₱${_formatNumberWithCommas(total, decimals: 2)}",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFEF4444), letterSpacing: -0.5)
                    ),
                    const SizedBox(height: 2),
                    Text("Total", style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.more_vert_rounded, size: 20, color: textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

