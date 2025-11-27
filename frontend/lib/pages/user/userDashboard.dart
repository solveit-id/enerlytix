import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/config/api_config.dart';

class UserDashboardPage extends StatefulWidget {
  final Map<String, dynamic>? user;

  const UserDashboardPage({super.key, this.user});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  bool _loading = true;
  String? _error;

  late String _name;
  int _daya = 0;
  double _kwhToday = 0;
  int _tokenBalance = 0;

  DateTime? _lastUpdated;

  static const int _tariffPerKwh = 1000;

  @override
  void initState() {
    super.initState();
    _name = widget.user?['name'] ?? 'Pengguna';
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    try {
      final userId = widget.user?['id'];
      if (userId == null) {
        setState(() {
          _error = 'User ID tidak ditemukan';
          _loading = false;
        });
        return;
      }

      final uri = Uri.parse(ApiConfig.userDashboardUrl(userId));
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        final meter = data['meter'];
        setState(() {
          _name = data['user']['name'] ?? _name;
          _daya = meter['powerLimitVa'] as int;
          _kwhToday = (meter['kwhToday'] as num).toDouble();
          _tokenBalance = meter['tokenBalance'] as int;
          _lastUpdated = DateTime.now();
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Gagal memuat dashboard (${res.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
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

    final bool lowToken = _tokenBalance < 10000;
    final bool highKwh = _kwhToday > 4.0;

    final double estimatedKwhLeft =
    _tokenBalance <= 0 ? 0.0 : _tokenBalance / _tariffPerKwh.toDouble();
    final int estimatedCostToday = (_kwhToday * _tariffPerKwh).round();

    return RefreshIndicator(
      onRefresh: _fetchDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Halo, $_name 👋",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              "Ringkasan cepat saldo token dan penggunaan listrik harian.",
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            if (_lastUpdated != null) ...[
              const SizedBox(height: 4),
              Text(
                "Update terakhir: ${_formatTime(_lastUpdated!)}",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip(
                  icon: Icons.payments,
                  label: "Tarif simulasi",
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

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100,
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.electric_bolt, color: Colors.white, size: 40),
                  const SizedBox(height: 10),
                  const Text(
                    "Saldo Token",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Rp ${_formatRupiah(_tokenBalance)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Perkiraan sisa energi: ${estimatedKwhLeft.toStringAsFixed(3)} kWh",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        lowToken
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle,
                        color: lowToken
                            ? Colors.yellowAccent
                            : Colors.lightGreenAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        lowToken
                            ? "Token menipis, disarankan isi ulang."
                            : "Token masih aman untuk sementara.",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (lowToken) _lowTokenAlert(),

            const SizedBox(height: 20),

            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _statusCard(
                      title: "Status Daya",
                      value: "$_daya VA",
                      icon: Icons.bolt,
                      color: Colors.orange,
                      status: "Aktif",
                      statusColor: Colors.orange,
                      description:
                      "Daya terpasang pada meter kamu. Sesuaikan beban agar tidak melebihi kapasitas.",
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statusCard(
                      title: "Pemakaian Hari Ini",
                      value: "${_kwhToday.toStringAsFixed(4)} kWh",
                      icon: Icons.show_chart,
                      color: Colors.green,
                      status: highKwh ? "Pemakaian Tinggi" : "Normal",
                      statusColor: highKwh ? Colors.orange : Colors.green,
                      description:
                      "Perkiraan biaya hari ini: Rp ${_formatRupiah(estimatedCostToday)}.",
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info, color: Colors.blue, size: 30),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Gunakan daya secara efisien untuk menghemat pengeluaran listrik harian. "
                          "Untuk melihat detail beban perangkat, grafik pemakaian, dan riwayat kWh per hari, buka menu Monitoring.",
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _lowTokenAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Token listrik kamu menipis. Segera isi ulang agar listrik tidak terputus.",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? status,
    Color? statusColor,
    String? description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(
        minHeight: 160,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor ?? Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}