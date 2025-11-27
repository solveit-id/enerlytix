import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/config/api_config.dart';

class UserTokenPage extends StatefulWidget {
  final Map<String, dynamic>? user;

  const UserTokenPage({super.key, this.user});

  @override
  State<UserTokenPage> createState() => _UserTokenPageState();
}

class _UserTokenPageState extends State<UserTokenPage> {
  final TextEditingController _amountController = TextEditingController();
  bool isLoading = false;

  static const int _tariffPerKwh = 1000;
  static const int _recommendedMin = 10000;

  int _inputAmount = 0;
  double _estimatedKwh = 0.0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String formatRupiahString(String value) {
    if (value.isEmpty) return "";
    final number = int.parse(value.replaceAll(".", ""));
    return number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => "${m[1]}.",
    );
  }

  void _updatePreviewFromText(String raw) {
    final cleaned = raw.replaceAll(".", "");
    int amount = 0;
    try {
      amount = int.parse(cleaned);
    } catch (_) {
      amount = 0;
    }

    setState(() {
      _inputAmount = amount;
      _estimatedKwh =
      amount > 0 ? amount / _tariffPerKwh.toDouble() : 0.0;
    });
  }

  void _setQuickAmount(int amount) {
    final formatted = formatRupiahString(amount.toString());
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _updatePreviewFromText(formatted);
  }

  Future<void> buyToken() async {
    if (_amountController.text.isEmpty) {
      showSnack("Masukkan jumlah token!");
      return;
    }

    final rawAmount = _amountController.text.replaceAll(".", "");
    final amount = int.tryParse(rawAmount);

    if (amount == null || amount <= 0) {
      showSnack("Jumlah token tidak valid!");
      return;
    }

    if (widget.user?["id"] == null) {
      showSnack("User tidak valid, silakan login ulang.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final uri = Uri.parse(ApiConfig.buyTokenUrl());

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.user!["id"],
          "amount": amount,
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final tokenCode = body['token']?.toString();
        final kwhAdded = (body['kwhAdded'] as num?)?.toDouble() ?? 0.0;
        final meter = body['meter'] as Map<String, dynamic>?;
        final newTokenBalance = meter?['tokenBalance'] as int?;

        String msg = "Token berhasil dibeli!";
        if (tokenCode != null) {
          msg =
          "Token $tokenCode berhasil (+${kwhAdded.toStringAsFixed(2)} kWh)";
        }

        if (newTokenBalance != null) {
          msg +=
          "\nSaldo: Rp ${formatRupiahString(newTokenBalance.toString())}";
        }

        showSnack(msg, success: true);
        _amountController.clear();
        setState(() {
          _inputAmount = 0;
          _estimatedKwh = 0.0;
        });
      } else {
        showSnack("Gagal membeli token (${response.statusCode})");
      }
    } catch (e) {
      setState(() => isLoading = false);
      showSnack("Error: $e");
    }
  }

  void showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool belowRecommended =
        _inputAmount > 0 && _inputAmount < _recommendedMin;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.electric_bolt, color: Colors.blue, size: 80),
              const SizedBox(height: 15),

              const Text(
                "Pembelian Token",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "Isi jumlah token dalam rupiah untuk menambah saldo listrik prabayar.\n"
                    "Nilai token otomatis dikonversi menjadi kWh sesuai tarif simulasi.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),

              const SizedBox(height: 16),

              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Colors.blueGrey),
                    const SizedBox(width: 6),
                    Text(
                      "Tarif simulasi: Rp ${formatRupiahString(_tariffPerKwh.toString())} / kWh",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(20),
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
                  children: [
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final newValue =
                        formatRupiahString(value.replaceAll(".", ""));
                        _amountController.value = TextEditingValue(
                          text: newValue,
                          selection: TextSelection.collapsed(
                            offset: newValue.length,
                          ),
                        );
                        _updatePreviewFromText(newValue);
                      },
                      decoration: InputDecoration(
                        labelText: "Jumlah Token (Rp)",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        prefixIcon: const Icon(Icons.payments),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Pilih nominal cepat:",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _quickAmountChip(10000),
                        _quickAmountChip(20000),
                        _quickAmountChip(50000),
                        _quickAmountChip(100000),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.energy_savings_leaf,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Perkiraan energi yang didapat",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _inputAmount <= 0
                                      ? "- kWh"
                                      : "${_estimatedKwh.toStringAsFixed(3)} kWh",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_inputAmount > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    "Perhitungan: Rp $_inputAmount ÷ Rp $_tariffPerKwh per kWh",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (belowRecommended) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Nominal cukup kecil, pertimbangkan isi ulang minimal "
                            "Rp ${formatRupiahString(_recommendedMin.toString())} "
                            "agar lebih awet.",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : buyToken,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                            : const Text(
                          "Beli Token",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Text(
                "Setelah pembelian berhasil, saldo token dan kWh akan otomatis tercatat di sistem.\n"
                    "Kamu bisa melihat ringkasan di menu Dashboard dan detail pemakaian di menu Monitoring.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAmountChip(int amount) {
    final isSelected = _inputAmount == amount;
    return ChoiceChip(
      label: Text("Rp ${formatRupiahString(amount.toString())}"),
      selected: isSelected,
      onSelected: (_) => _setQuickAmount(amount),
      selectedColor: Colors.blue.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade900 : Colors.black87,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}