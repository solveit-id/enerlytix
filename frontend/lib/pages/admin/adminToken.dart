import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/config/api_config.dart';

class AdminTokenPage extends StatefulWidget {
  const AdminTokenPage({super.key});

  @override
  State<AdminTokenPage> createState() => _AdminTokenPageState();
}

class _AdminTokenPageState extends State<AdminTokenPage> {
  List<Map<String, dynamic>> users = [];
  bool loading = true;
  String? error;

  static const int tokenThresholdCritical = 5000;
  static const int tokenThresholdWarning = 20000;

  static const int tariffPerKwh = 1000;

  final List<Color> avatarColors = [
    Colors.deepOrange,
    Colors.blue,
    Colors.purple,
    Colors.green,
    Colors.teal,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _fetchTokens();
  }

  Future<void> _fetchTokens() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final uri = Uri.parse(ApiConfig.adminTokensUrl());
      final res = await http.get(uri);

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = List<Map<String, dynamic>>.from(data['data'] ?? []);

        list.sort(
              (a, b) => ((a['token'] ?? 0) as int).compareTo(
            (b['token'] ?? 0) as int,
          ),
        );

        setState(() {
          users = list;
          loading = false;
        });
      } else {
        setState(() {
          error = 'Gagal memuat data token (${res.statusCode})';
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

  void showTopUpDialog(Map<String, dynamic> user) {
    final TextEditingController amountC = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _buildDialog(
          icon: Icons.payments,
          title: "Top-Up Token",
          subtitle: "Untuk: ${user["name"]}",
          controller: amountC,
          label: "Jumlah Token (Rp)",
          buttonText: "Top-Up",
          onSubmit: () async {
            final raw = amountC.text.trim();
            final amount = int.tryParse(raw);

            if (amount == null || amount <= 0) {
              _showSnack("Jumlah token tidak valid", false);
              return;
            }

            await _topUpToken(user, amount);
            if (mounted) Navigator.pop(context);
          },
        );
      },
    );
  }

  void showKwhDialog(Map<String, dynamic> user) {
    final TextEditingController kwhC = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _buildDialog(
          icon: Icons.bolt,
          title: "Atur Pemakaian KWH",
          subtitle: "Untuk: ${user["name"]}",
          controller: kwhC,
          label: "Tambah KWH",
          buttonText: "Update",
          onSubmit: () async {
            final raw = kwhC.text.trim();
            final deltaKwh = double.tryParse(raw);

            if (deltaKwh == null) {
              _showSnack("KWH tidak valid", false);
              return;
            }

            await _updateKwh(user, deltaKwh);
            if (mounted) Navigator.pop(context);
          },
        );
      },
    );
  }

  Future<void> _topUpToken(Map<String, dynamic> user, int amount) async {
    final meterId = user['meterId'];

    try {
      final uri = Uri.parse(ApiConfig.adminTopupUrl());
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'meterId': meterId,
          'amount': amount,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          user['token'] = data['meter']['tokenBalance'];
          user['kwh'] = data['meter']['currentKwh'];
        });
        _showSnack('Token berhasil ditambahkan!', true);
      } else {
        _showSnack('Gagal top-up token (${res.statusCode})', false);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', false);
    }
  }

  Future<void> _updateKwh(Map<String, dynamic> user, double deltaKwh) async {
    final meterId = user['meterId'];

    try {
      final uri = Uri.parse(ApiConfig.adminUpdateKwhUrl());
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'meterId': meterId,
          'deltaKwh': deltaKwh,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          user['kwh'] = data['meter']['currentKwh'];
        });
        _showSnack('KWH berhasil diperbarui!', true);
      } else {
        _showSnack('Gagal update KWH (${res.statusCode})', false);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', false);
    }
  }

  void _showSnack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  String _formatRupiah(int value) {
    final s = value.toString();
    return s.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => "${m[1]}.",
    );
  }

  String _formatKwh(num value) {
    return value.toStringAsFixed(3);
  }

  String _tokenStatusText(int token) {
    if (token <= tokenThresholdCritical) return "KRITIS";
    if (token <= tokenThresholdWarning) return "WASPADA";
    return "AMAN";
  }

  Color _tokenStatusColor(int token) {
    if (token <= tokenThresholdCritical) return Colors.red;
    if (token <= tokenThresholdWarning) return Colors.orange;
    return Colors.green;
  }

  Widget _buildDialog({
    required IconData icon,
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required String label,
    required String buttonText,
    required VoidCallback onSubmit,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 50, color: Colors.orange),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  child: const Text(
                    "Batal",
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onSubmit,
                  child: Text(
                    buttonText,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

    final totalUsers = users.length;
    final totalToken = users.fold<int>(
      0,
          (sum, u) => sum + ((u['token'] ?? 0) as int),
    );
    final avgToken = totalUsers > 0 ? totalToken / totalUsers : 0.0;
    final criticalCount = users
        .where((u) => ((u['token'] ?? 0) as int) <= tokenThresholdCritical)
        .length;
    final double criticalRatio =
    totalUsers > 0 ? (criticalCount / totalUsers) : 0.0;

    return RefreshIndicator(
      onRefresh: _fetchTokens,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: users.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _summaryHeader(
              totalUsers: totalUsers,
              avgToken: avgToken,
              criticalCount: criticalCount,
              criticalRatio: criticalRatio,
            );
          }

          final user = users[index - 1];
          final int token = (user["token"] ?? 0) as int;
          final double kwh = (user["kwh"] ?? 0.0) is num
              ? (user["kwh"] as num).toDouble()
              : 0.0;
          final bool isCritical = token <= tokenThresholdCritical;
          final String statusText = _tokenStatusText(token);
          final Color statusColor = _tokenStatusColor(token);
          final double estimatedKwh = token / tariffPerKwh;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isCritical ? Colors.red.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(
                color: statusColor.withOpacity(isCritical ? 0.7 : 0.3),
                width: isCritical ? 1.3 : 0.8,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                      avatarColors[index % avatarColors.length],
                      child: Text(
                        (user["name"] ?? "U")[0].toUpperCase(),
                        style:
                        const TextStyle(fontSize: 20, color: Colors.white),
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
                                  user["name"] ?? '',
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
                                  children: [
                                    Icon(
                                      statusText == "AMAN"
                                          ? Icons.check_circle
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
                          Text(
                            user["email"] ?? '',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _badge(
                                    text:
                                    "Token: Rp ${_formatRupiah(token)}",
                                    color: statusColor,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: _badge(
                                      text:
                                      "KWH Total: ${_formatKwh(kwh)} kWh",
                                      color: Colors.blue.shade400,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: _badge(
                                      text:
                                      "Perkiraan sisa: ${estimatedKwh.toStringAsFixed(3)} kWh",
                                      color: Colors.deepPurple.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.orange.shade700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.bolt, color: Colors.orange),
                      label: const Text(
                        "Atur KWH",
                        style: TextStyle(color: Colors.orange),
                      ),
                      onPressed: () => showKwhDialog(user),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 11,
                        ),
                      ),
                      onPressed: () => showTopUpDialog(user),
                      child: const Text(
                        "Top-Up",
                        style: TextStyle(fontSize: 15, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryHeader({
    required int totalUsers,
    required double avgToken,
    required int criticalCount,
    required double criticalRatio,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.blueGrey.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Ringkasan Token Pengguna",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _summaryChip(
                icon: Icons.people,
                label: "Total User",
                value: totalUsers.toString(),
              ),
              _summaryChip(
                icon: Icons.payments,
                label: "Rata-rata Token",
                value: "Rp ${_formatRupiah(avgToken.round())}",
              ),
              _summaryChip(
                icon: Icons.warning_amber_rounded,
                label: "Token Kritis",
                value:
                "$criticalCount (${(criticalRatio * 100).toStringAsFixed(1)}%)",
              ),
            ],
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

  Widget _badge({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
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