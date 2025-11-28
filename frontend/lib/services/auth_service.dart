import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AuthResponse {
  final bool success;
  final String message;
  final String? token;
  final Map<String, dynamic>? user;

  AuthResponse({
    required this.success,
    required this.message,
    this.token,
    this.user,
  });

  factory AuthResponse.fromLoginJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;

    return AuthResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      token: data != null ? data['token'] as String? : null,
      user: data != null ? data['user'] as Map<String, dynamic>? : null,
    );
  }
}

class AuthService {
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(ApiConfig.loginUrl());

    try {
      final response = await http
          .post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> bodyJson = {};
      try {
        if (response.body.isNotEmpty) {
          bodyJson = jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (_) {
        // kalau respons bukan JSON valid, biarkan bodyJson kosong
      }

      if (response.statusCode != 200 ||
          (bodyJson['success'] is bool && bodyJson['success'] == false)) {
        return AuthResponse(
          success: false,
          message: bodyJson['message'] as String? ?? 'Login gagal',
          token: null,
          user: null,
        );
      }

      if (bodyJson.isNotEmpty) {
        return AuthResponse.fromLoginJson(bodyJson);
      }

      return AuthResponse(
        success: true,
        message: 'Login berhasil',
        token: null,
        user: null,
      );
    } on TimeoutException {
      return AuthResponse(
        success: false,
        message: 'Koneksi ke server timeout. Coba lagi.',
        token: null,
        user: null,
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Gagal terhubung ke server: $e',
        token: null,
        user: null,
      );
    }
  }

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(ApiConfig.registerUrl());

    try {
      final response = await http
          .post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> bodyJson = {};
      try {
        if (response.body.isNotEmpty) {
          bodyJson = jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (_) {
        // respons bukan JSON valid
      }

      final bool isSuccess = response.statusCode == 201 &&
          (bodyJson['success'] as bool? ?? true);

      return AuthResponse(
        success: isSuccess,
        message: bodyJson['message'] as String? ??
            (isSuccess ? 'Register berhasil' : 'Register gagal'),
        token: null,
        user: bodyJson['user'] as Map<String, dynamic>?,
      );
    } on TimeoutException {
      return AuthResponse(
        success: false,
        message: 'Koneksi ke server timeout. Coba lagi.',
        token: null,
        user: null,
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Gagal terhubung ke server: $e',
        token: null,
        user: null,
      );
    }
  }
}