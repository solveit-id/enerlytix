import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/config/api_config.dart';

class UserMonitoringPage extends StatefulWidget {
  final Map<String, dynamic>? user;

  const UserMonitoringPage({super.key, this.user});

  @override
  State<UserMonitoringPage> createState() => _UserMonitoringPageState();
}

class _UserMonitoringPageState extends State<UserMonitoringPage> {
  bool _loading = true;
  String? _error;

  int token = 0;
  double kwhToday = 0;
  int wattNow = 0;
  int daya = 0;

  List<Map<String, dynamic>> history = [];

  bool lampOn = false;
  bool fanOn = false;
  bool laptopOn = false;

  Timer? _timer;

  DateTime? _lastUpdated;

  static const int _tariffPerKwh = 1000;

  @override
  void initState() {
    super.initState();
    _fetchMonitoring();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchMonitoring(silent: true);
    });
  }

  Future<void> _fetchMonitoring({bool silent = false}) async {
    try {
      final userId = widget.user?['id'];
      if (userId == null) {
        setState(() {
          _error = 'User ID tidak ditemukan';
          _loading = false;
        });
        return;
      }

      if (!silent) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }

      final uri = Uri.parse(ApiConfig.userMonitoringUrl(userId));
      final res = await http.get(uri);

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final meter = data['meter'];
        final List<dynamic> hist = data['history'] ?? [];

        setState(() {
          token = meter['tokenBalance'] as int;
          daya = meter['powerLimitVa'] as int;
          wattNow = meter['currentWatt'] as int;
          kwhToday = (data['kwhToday'] as num).toDouble();

          history = hist.cast<Map<String, dynamic>>();

          _lastUpdated = DateTime.now();
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Gagal memuat monitoring (${res.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _updateMeterWatt(int totalWatt) async {
    final userId = widget.user?['id'];
    if (userId == null) {
      _showSnack('User tidak valid, silakan login ulang.');
      return;
    }

    try {
      final uri = Uri.parse(ApiConfig.userSetWattUrl());
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'watt': totalWatt,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          wattNow = (data['meter']['currentWatt'] as num).toInt();
          token = (data['meter']['tokenBalance'] as num).toInt();
          _lastUpdated = DateTime.now();
        });
      } else {
        _showSnack('Gagal update beban (${res.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.redAccent,
      ),
    );
  }

  void _onToggleDevice({
    bool? lamp,
    bool? fan,
    bool? laptop,
  }) {
    setState(() {
      if (lamp != null) lampOn = lamp;
      if (fan != null) fanOn = fan;
      if (laptop != null) laptopOn = laptop;
    });

    const lampW = 60;
    const fanW = 80;
    const laptopW = 65;

    final totalWatt = (lampOn ? lampW : 0) +
        (fanOn ? fanW : 0) +
        (laptopOn ? laptopW : 0);

    _updateMeterWatt(totalWatt);
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  String _formatRupiah(int value) {
    final s = value.toString();
    return s.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => "${m[1]}.",
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final bool lowToken = token < 10000;
    final bool highKwh = kwhToday > 4.0;

    final double estimatedKwhLeft =
    token <= 0 ? 0.0 : token / _tariffPerKwh.toDouble();
    final int estimatedCostToday = (kwhToday * _tariffPerKwh).round();

    return RefreshIndicator(
      onRefresh: () => _fetchMonitoring(silent: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Monitoring Listrik Anda",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              "Pantau penggunaan listrik dan kontrol perangkat.",
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (_lastUpdated != null) ...[
              const SizedBox(height: 4),
              Text(
                "Update terakhir: ${_formatTime(_lastUpdated!)}",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],

            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip(
                  icon: Icons.payments,
                  label: "Tarif Simulasi",
                  value: "Rp ${_formatRupiah(_tariffPerKwh)} / kWh",
                ),
                _chip(
                  icon: Icons.energy_savings_leaf,
                  label: "Perkiraan sisa energi",
                  value: "${estimatedKwhLeft.toStringAsFixed(3)} kWh",
                ),
                _chip(
                  icon: Icons.receipt_long,
                  label: "Perkiraan biaya hari ini",
                  value: "Rp ${_formatRupiah(estimatedCostToday)}",
                ),
              ],
            ),

            const SizedBox(height: 20),

            _mainCard(
              icon: Icons.payments,
              title: "Token Anda",
              value: "Rp ${_formatRupiah(token)}",
              color: Colors.blue,
              progress: (token / 100000).clamp(0.0, 1.0),
              status: lowToken ? "Token Menipis" : "Aman",
              statusColor: lowToken ? Colors.red : Colors.green,
              extraInfo:
              "Perkiraan sisa energi: ${estimatedKwhLeft.toStringAsFixed(3)} kWh",
            ),

            const SizedBox(height: 18),

            _mainCard(
              icon: Icons.bolt,
              title: "Pemakaian Hari Ini",
              value: "${kwhToday.toStringAsFixed(4)} kWh",
              color: Colors.orange,
              progress: (kwhToday / 10).clamp(0.0, 1.0),
              status: highKwh ? "Pemakaian Tinggi" : "Normal",
              statusColor: highKwh ? Colors.orange : Colors.green,
              extraInfo:
              "Perkiraan biaya hari ini: Rp ${_formatRupiah(estimatedCostToday)}",
            ),

            const SizedBox(height: 18),

            _wattCard(),

            const SizedBox(height: 25),

            const Text(
              "Perangkat Listrik",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text("Lampu Kamar (60W)"),
                    secondary: const Icon(Icons.lightbulb_outline),
                    value: lampOn,
                    onChanged: (v) => _onToggleDevice(lamp: v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text("Kipas Angin (80W)"),
                    secondary: const Icon(Icons.wind_power),
                    value: fanOn,
                    onChanged: (v) => _onToggleDevice(fan: v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text("Charger Laptop (65W)"),
                    secondary: const Icon(Icons.laptop_mac),
                    value: laptopOn,
                    onChanged: (v) => _onToggleDevice(laptop: v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              "Riwayat Pemakaian",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),
            ..._buildHistory(),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueGrey.shade700),
          const SizedBox(width: 4),
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 11,
              color: Colors.blueGrey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required double progress,
    required String status,
    required Color statusColor,
    String? extraInfo,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (extraInfo != null) ...[
            const SizedBox(height: 4),
            Text(
              extraInfo,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            minHeight: 8,
            borderRadius: BorderRadius.circular(20),
            color: color,
          ),
        ],
      ),
    );
  }

  Widget _wattCard() {
    final double wattPercentage =
    daya == 0 ? 0 : (wattNow / daya).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Beban Saat Ini",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.flash_on, size: 32, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "$wattNow Watt",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: wattPercentage,
            backgroundColor: Colors.grey.shade300,
            minHeight: 8,
            color: wattPercentage > 0.8 ? Colors.red : Colors.green,
            borderRadius: BorderRadius.circular(20),
          ),
          const SizedBox(height: 8),
          Text(
            wattPercentage > 0.8 ? "⚠ Beban Tinggi" : "Aman",
            style: TextStyle(
              color: wattPercentage > 0.8 ? Colors.red : Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHistory() {
    if (history.isEmpty) {
      return [
        Text(
          "Belum ada riwayat pemakaian.",
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ];
    }

    final now = DateTime.now();

    return List.generate(history.length, (i) {
      final item = history[i];

      final dateStr = item['date']?.toString() ?? '';
      final kwh = (item['kwhUsed'] as num?)?.toDouble() ?? 0.0;

      DateTime? dt;
      try {
        dt = DateTime.parse(dateStr).toLocal();
      } catch (_) {
        dt = null;
      }

      String label;
      if (dt == null) {
        label = "Tanggal tidak diketahui";
      } else {
        final dateOnly = DateTime(dt.year, dt.month, dt.day);
        final todayOnly = DateTime(now.year, now.month, now.day);
        final diffDays = todayOnly.difference(dateOnly).inDays;

        if (diffDays == 0) {
          label = "Hari ini";
        } else if (diffDays == 1) {
          label = "Kemarin";
        } else {
          label = "$diffDays hari lalu";
        }
      }

      final dateText = dt != null
          ? "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}"
          : "";

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (dateText.isNotEmpty)
                    Text(
                      dateText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              "${kwh.toStringAsFixed(4)} kWh",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    });
  }
}