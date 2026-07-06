import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/WeatherForecasting/AgaAppWeatherForecast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class WeatherForecastScreen extends StatefulWidget {
  final String userName;

  const WeatherForecastScreen({super.key, required this.userName});

  @override
  State<WeatherForecastScreen> createState() => _WeatherForecastScreenState();
}

class _WeatherForecastScreenState extends State<WeatherForecastScreen> {
  final AgaAppWeatherForecast _weatherService = AgaAppWeatherForecast();

  bool _loading = true;
  Map<String, dynamic>? _current;
  List<Map<String, dynamic>> _forecast = [];
  String _status = 'Loading weather...';

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _loading = true;
      _status = 'Loading weather...';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setError('Turn on location to load local weather.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setError('Location permission is required for local forecast.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final current = await _weatherService.getCurrentWeather(
        position.latitude,
        position.longitude,
      );
      final forecast = await _weatherService.getForecast(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _current = current;
        _forecast = forecast;
        _loading = false;
        _status = current == null ? 'Weather unavailable' : '';
      });
    } catch (e) {
      Utility().printLog('Forecast screen error: $e');
      _setError('Weather forecast is unavailable.');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _status = message;
    });
  }

  String _backgroundAsset(int? code) {
    final hour = DateTime.now().hour;
    final isNight = hour < 6 || hour >= 18;
    if (code == null) {
      return isNight
          ? 'assets/weather_backgrounds/night.png'
          : 'assets/weather_backgrounds/weather_cloudy.png';
    }
    if (code >= 200 && code < 300) {
      return 'assets/weather_backgrounds/weather_thunder_storm.png';
    }
    if (code >= 300 && code < 600) {
      return 'assets/weather_backgrounds/weather_rainy.png';
    }
    if (code == 800) {
      return isNight
          ? 'assets/weather_backgrounds/night.png'
          : 'assets/weather_backgrounds/weather_sunny.png';
    }
    return isNight
        ? 'assets/weather_backgrounds/night.png'
        : 'assets/weather_backgrounds/weather_cloudy.png';
  }

  IconData _weatherIcon(int? code) {
    if (code == null) return Icons.cloud_outlined;
    if (code >= 200 && code < 300) return Icons.thunderstorm_rounded;
    if (code >= 300 && code < 600) return Icons.water_drop_rounded;
    if (code >= 600 && code < 700) return Icons.ac_unit_rounded;
    if (code >= 700 && code < 800) return Icons.foggy;
    if (code == 800) return Icons.wb_sunny_rounded;
    return Icons.cloud_rounded;
  }

  List<Map<String, dynamic>> get _dailyForecast {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in _forecast) {
      final date = item['dateTime'] as DateTime;
      final key = DateFormat('yyyy-MM-dd').format(date);
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return grouped.entries.take(5).map((entry) {
      final items = entry.value;
      final temps = items.map((e) => e['temp'] as double).toList();
      final noon = items.reduce((a, b) {
        final ad = ((a['dateTime'] as DateTime).hour - 12).abs();
        final bd = ((b['dateTime'] as DateTime).hour - 12).abs();
        return ad <= bd ? a : b;
      });
      return {
        'dateTime': items.first['dateTime'],
        'min': temps.reduce((a, b) => a < b ? a : b),
        'max': temps.reduce((a, b) => a > b ? a : b),
        'condition': noon['condition'],
        'conditionId': noon['conditionId'],
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentCode = _current?['conditionId'] as int?;
    final bg = _backgroundAsset(currentCode);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: _loadWeather,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: 330,
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              title: const Text(
                'Weather Forecast',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _hero(bg, currentCode),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_current == null)
              SliverFillRemaining(hasScrollBody: false, child: _emptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _metricsGrid(),
                    const SizedBox(height: 18),
                    _hourlyTrend(),
                    const SizedBox(height: 18),
                    _dailyCards(),
                    const SizedBox(height: 18),
                    _comfortCard(),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hero(String bg, int? currentCode) {
    final parts = widget.userName.trim().split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first
        : 'Citizen';

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(bg, fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.72),
                Colors.black.withValues(alpha: 0.16),
                Colors.black.withValues(alpha: 0.64),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 80, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Magandang araw, $firstName',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_current?['temp'] ?? '--'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        height: 0.9,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'C',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.26),
                        ),
                      ),
                      child: Icon(
                        _weatherIcon(currentCode),
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_current?['condition'] ?? 'Weather'} near ${_current?['cityName'] ?? 'your location'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Feels like ${_current?['feelsLike'] ?? '--'}C',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 760 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth > 760 ? 2.2 : 1.55,
          children: [
            _metricCard(
              Icons.thermostat_rounded,
              'Feels Like',
              '${_current?['feelsLike'] ?? '--'}C',
              const Color(0xFFEA580C),
            ),
            _metricCard(
              Icons.water_drop_rounded,
              'Humidity',
              '${_current?['humidity'] ?? '--'}%',
              const Color(0xFF0284C7),
            ),
            _metricCard(
              Icons.air_rounded,
              'Wind',
              '${((_current?['windSpeed'] ?? 0) as num).toStringAsFixed(1)} m/s',
              const Color(0xFF0F766E),
            ),
            _metricCard(
              Icons.place_rounded,
              'Location',
              '${_current?['cityName'] ?? 'Nearby'}',
              const Color(0xFF7C3AED),
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hourlyTrend() {
    final points = _forecast.take(8).toList();
    return _sectionCard(
      title: 'Next 24 Hours',
      child: SizedBox(
        height: 230,
        child: points.isEmpty
            ? const Center(child: Text('No forecast data available.'))
            : LineChart(
                LineChartData(
                  minY:
                      points
                          .map((e) => e['temp'] as double)
                          .reduce((a, b) => a < b ? a : b) -
                      2,
                  maxY:
                      points
                          .map((e) => e['temp'] as double)
                          .reduce((a, b) => a > b ? a : b) +
                      2,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          final dt = points[index]['dateTime'] as DateTime;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('ha').format(dt).toLowerCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i]['temp'] as double),
                      ],
                      isCurved: true,
                      preventCurveOverShooting: true,
                      barWidth: 4,
                      color: const Color(0xFF0F766E),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                      ),
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _dailyCards() {
    final days = _dailyForecast;
    return _sectionCard(
      title: '5-Day Forecast',
      child: Column(
        children: [
          for (final day in days)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    _weatherIcon(day['conditionId'] as int?),
                    color: const Color(0xFF0F766E),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE').format(day['dateTime']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          day['condition'].toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(day['max'] as double).round()} / ${(day['min'] as double).round()}C',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _comfortCard() {
    final humidity = (_current?['humidity'] ?? 0) as num;
    final wind = (_current?['windSpeed'] ?? 0) as num;
    final condition = humidity > 80
        ? 'Humid'
        : wind > 8
        ? 'Windy'
        : 'Comfortable';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  condition,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Check the forecast before travel, outdoor work, or island trips.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 54,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          Text(
            _status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loadWeather,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
