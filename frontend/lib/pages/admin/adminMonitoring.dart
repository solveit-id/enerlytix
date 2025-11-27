import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/config/api_config.dart';

class AdminMonitoringPage extends StatefulWidget {
  const AdminMonitoringPage({super.key});

  @override
  State<AdminMonitoringPage> createState() => _AdminMonitoringPageState();
}

class _AdminMonitoringPageState extends State<AdminMonitoringPage> {
  bool loading = true;
  String? error;

  double totalKwhToday = 0;
  int activeUsers = 0;
  List<Map<String, dynamic>> users = [];

  static const int tokenThreshold = 5000;
  static const double highUsageThreshold = 3.0;

  static const int tariffPerKwh = 1000;

  @override
  void initState() {
    super.initState();
    _fetchMonitoring();
  }

  Future<void> _fetchMonitoring() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final uri = Uri.parse(ApiConfig.adminMonitoringUrl());
      final res = await http.get(uri);

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          totalKwhToday = (data['totalKwhToday'] as num?)?.toDouble() ?? 0.0;
          activeUsers = data['activeUsers'] ?? 0;
          users = List<Map<String, dynamic>>.from(data['list'] ?? []);
          loading = false;
        });
      } else {
        setState(() {
          error = 'Gagal memuat monitoring admin (${res.statusCode})';
          loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Error: $e';
        loading = false;
      });
    }
  }

  String _formatKwh(num value) => value.toStringAsFixed(3);
  String _formatKwhShort(num value) => value.toStringAsFixed(1);

  String _formatRupiah(int value) {
    final s = value.toString();
    return s.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => "${m[1]}.",
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(error!),
        ),
      );
    }

    final int totalUsers = users.length;
    final int lowTokenCount =
        users.where((u) => ((u['token'] ?? 0) as int) < tokenThreshold).length;
    final int highUsageCount = users
        .where((u) => ((u['kwh'] ?? 0.0) as num).toDouble() > highUsageThreshold)
        .length;
    final double avgKwhPerUser =
    totalUsers > 0 ? totalKwhToday / totalUsers : 0.0;

    final List<Map<String, dynamic>> sortedUsers = [...users]
      ..sort((a, b) {
        final ka = ((a['kwh'] ?? 0.0) as num).toDouble();
        final kb = ((b['kwh'] ?? 0.0) as num).toDouble();
        return kb.compareTo(ka);
      });

    return RefreshIndicator(
      onRefresh: _fetchMonitoring,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Monitoring Penggunaan",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Pantau aktivitas konsumsi listrik seluruh pengguna.",
              style: TextStyle(color: Colors.black54),
            ),

            const SizedBox(height: 20),

            _summaryHeader(
              totalUsers: totalUsers,
              avgKwhPerUser: avgKwhPerUser,
              lowTokenCount: lowTokenCount,
              highUsageCount: highUsageCount,
            ),

            const SizedBox(height: 18),

            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statCard(
                    title: "Total KWH Hari Ini",
                    value: "${_formatKwhShort(totalKwhToday)} kWh",
                    icon: Icons.bolt,
                    color: Colors.orange,
                    subtitle: "Akumulasi seluruh pemakaian harian.",
                  ),
                  const SizedBox(width: 15),
                  _statCard(
                    title: "User Aktif",
                    value: "$activeUsers",
                    icon: Icons.people,
                    color: Colors.blue,
                    subtitle: "User yang tercatat memakai listrik.",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              "Daftar Pemakaian User",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            if (sortedUsers.isEmpty)
              const Text(
                "Belum ada data pemakaian.",
                style: TextStyle(color: Colors.black54),
              )
            else
              ...sortedUsers.map((u) => _userCard(u)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _summaryHeader({
    required int totalUsers,
    required double avgKwhPerUser,
    required int lowTokenCount,
    required int highUsageCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Wrap(
        runSpacing: 6,
        spacing: 18,
        children: [
          _summaryChip(
            icon: Icons.people_alt,
            label: "Total User",
            value: totalUsers.toString(),
          ),
          _summaryChip(
            icon: Icons.analytics,
            label: "Rata-rata kWh/User",
            value: "${_formatKwh(avgKwhPerUser)} kWh",
          ),
          _summaryChip(
            icon: Icons.warning_amber_rounded,
            label: "Token Menipis",
            value: "$lowTokenCount user",
          ),
          _summaryChip(
            icon: Icons.bolt,
            label: "Pemakaian Tinggi",
            value: "$highUsageCount user",
          ),
        ],
      ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey.shade600),
        const SizedBox(width: 4),
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: 13,
            color: Colors.blueGrey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey.shade900,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        constraints: const BoxConstraints(
          minHeight: 140,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

  Widget _userCard(Map<String, dynamic> user) {
    final name = (user['name'] ?? '') as String;
    final token = (user['token'] ?? 0) as int;
    final kwh = (user['kwh'] as num?)?.toDouble() ?? 0.0;
    final watt = (user['watt'] as num?)?.toDouble() ?? 0.0;

    final bool lowToken = token < tokenThreshold;
    final bool highUsage = kwh > highUsageThreshold;
    final bool isActiveNow = watt > 0;

    final double estimatedKwhLeft = token / tariffPerKwh;

    Color statusColor;
    String statusText;
    if (lowToken && highUsage) {
      statusColor = Colors.red;
      statusText = "KRITIS";
    } else if (highUsage) {
      statusColor = Colors.orange;
      statusText = "Pemakaian Tinggi";
    } else if (lowToken) {
      statusColor = Colors.red;
      statusText = "Token Menipis";
    } else {
      statusColor = Colors.green;
      statusText = isActiveNow ? "Aktif" : "Standby";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: lowToken ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: statusColor.withOpacity(lowToken ? 0.7 : 0.3),
          width: lowToken ? 1.1 : 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.deepOrange,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 22, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (statusText == "Aktif" ||
                                    statusText == "Standby")
                                    ? Icons.power_settings_new
                                    : Icons.warning_amber_rounded,
                                size: 14,
                                color: statusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _badge(
                          text: "Token: Rp ${_formatRupiah(token)}",
                          color: lowToken ? Colors.red : Colors.green,
                        ),
                        _badge(
                          text: "KWH Hari ini: ${_formatKwh(kwh)}",
                          color: highUsage ? Colors.orange : Colors.blue,
                        ),
                        _badge(
                          text: "Watt Saat ini: ${watt.toStringAsFixed(0)} W",
                          color: isActiveNow
                              ? Colors.purple
                              : Colors.grey.shade600,
                        ),
                        _badge(
                          text:
                          "Perkiraan sisa: ${_formatKwh(estimatedKwhLeft)} kWh",
                          color: Colors.deepPurple,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            highUsage
                ? "⚡ Penggunaan mendekati/di atas ambang tinggi. Perlu dipantau."
                : (isActiveNow
                ? "• Pemakaian dalam batas aman."
                : "• Tidak ada beban aktif saat ini."),
            style: TextStyle(
              color: highUsage ? Colors.orange : Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}