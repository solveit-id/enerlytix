import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool loading = false;
  final AuthService _authService = AuthService();

  Future<void> _handleRegister() async {
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password tidak sama!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final response = await _authService.register(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;

      if (!response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registrasi berhasil! Silakan login."),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "Daftar Akun",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text(
              "Buat Akun Baru 🔐",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "Isi data di bawah untuk membuat akun Enerlytix.",
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 30),

            _inputField(
              controller: nameController,
              label: "Nama Lengkap",
              icon: Icons.person_rounded,
            ),
            const SizedBox(height: 20),

            _inputField(
              controller: emailController,
              label: "Email",
              icon: Icons.email_rounded,
            ),
            const SizedBox(height: 20),

            _inputField(
              controller: passwordController,
              label: "Password",
              icon: Icons.lock_rounded,
              isPassword: true,
            ),
            const SizedBox(height: 20),

            _inputField(
              controller: confirmPasswordController,
              label: "Konfirmasi Password",
              icon: Icons.lock_clock_rounded,
              isPassword: true,
            ),

            const SizedBox(height: 35),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 5,
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Daftar",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                child: const Text(
                  "Sudah punya akun? Login di sini",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue.shade700),
          labelStyle: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }
}
