import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/config/api_config.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _loading = true;
  String? _error;

  int _totalUsers = 0;
  int _totalMeters = 0;
  double _totalKwh = 0;
  int _totalTokenPrice = 0;
  int _lowTokenMeters = 0;

  List<Map<String, dynamic>> _recentUsers = [];

  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    try {
      final uri = Uri.parse(ApiConfig.adminDashboardUrl());
      final res = await http.get(uri);

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          _totalUsers = data['totalUsers'] ?? 0;
          _totalMeters = data['totalMeters'] ?? 0;
          _totalKwh = (data['totalKwh'] as num?)?.toDouble() ?? 0.0;
          _totalTokenPrice = data['totalTokenPrice'] ?? 0;
          _lowTokenMeters = data['lowTokenMeters'] ?? 0;
          _recentUsers =
          List<Map<String, dynamic>>.from(data['recentUsers'] ?? []);
          _lastUpdated = DateTime.now();
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Gagal memuat dashboard admin (${res.statusCode})';
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

  String _formatRupiah(int value) {
    final s = value.toString();
    return s.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => "${m[1]}.",
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return "$h:$m:$s";
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

    final double avgKwhPerMeter =
    _totalMeters > 0 ? _totalKwh / _totalMeters : 0.0;
    final double lowTokenRatio =
    _totalMeters > 0 ? _lowTokenMeters / _totalMeters : 0.0;

    return RefreshIndicator(
      onRefresh: _fetchDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Dashboard Admin",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              "Pantau statistik global penggunaan Enerlytix dan kesehatan meter pengguna.",
              style: TextStyle(color: Colors.black54),
            ),
            if (_lastUpdated != null) ...[
              const SizedBox(height: 4),
              Text(
                "Update terakhir: ${_formatTime(_lastUpdated!)}",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],

            const SizedBox(height: 25),

            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statCard(
                    icon: Icons.people,
                    title: "Total User",
                    value: _totalUsers.toString(),
                    color: Colors.blue,
                    subtitle: "Akun terdaftar di sistem.",
                  ),
                  const SizedBox(width: 12),
                  _statCard(
                    icon: Icons.electrical_services,
                    title: "Total Meter",
                    value: _totalMeters.toString(),
                    color: Colors.indigo,
                    subtitle: "Meter terhubung ke Enerlytix.",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statCard(
                    icon: Icons.bolt,
                    title: "Total kWh",
                    value: "${_totalKwh.toStringAsFixed(2)} kWh",
                    color: Colors.orange,
                    subtitle: "Akumulasi seluruh pemakaian.",
                  ),
                  const SizedBox(width: 12),
                  _statCard(
                    icon: Icons.analytics,
                    title: "Rata-rata kWh/Meter",
                    value: "${avgKwhPerMeter.toStringAsFixed(3)} kWh",
                    color: Colors.teal,
                    subtitle: _totalMeters > 0
                        ? "Rata-rata per meter terpasang."
                        : "Belum ada data meter.",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statCard(
                    icon: Icons.payments,
                    title: "Token Terjual",
                    value: "Rp ${_formatRupiah(_totalTokenPrice)}",
                    color: Colors.green,
                    subtitle: "Total penjualan token tercatat.",
                  ),
                  const SizedBox(width: 12),
                  _statCard(
                    icon: Icons.warning,
                    title: "Token Menipis",
                    value: "$_lowTokenMeters Meter",
                    color: Colors.red,
                    subtitle: _totalMeters > 0
                        ? "${(lowTokenRatio * 100).toStringAsFixed(1)}% dari seluruh meter."
                        : "Belum ada data meter.",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Pengguna Terakhir",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            if (_recentUsers.isEmpty)
              const Text(
                "Belum ada data pengguna.",
                style: TextStyle(color: Colors.black54),
              )
            else
              ..._recentUsers.map(
                    (u) {
                  final name = u['name'] ?? 'Unknown';
                  final tokenBalance = (u['tokenBalance'] ?? 0) as int;
                  return _userItem(
                    name,
                    tokenBalance,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        constraints: const BoxConstraints(
          minHeight: 150,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
          mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _userItem(String name, int tokenBalance) {
    final bool safe = tokenBalance >= 10000;
    final String statusText = safe ? "Aman" : "Menipis";
    final Color statusColor = safe ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(
        minHeight: 80,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.blue.shade50,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Token: Rp ${_formatRupiah(tokenBalance)}",
                  style: TextStyle(
                    fontSize: 13,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Icon(
                  safe ? Icons.check_circle : Icons.warning,
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}