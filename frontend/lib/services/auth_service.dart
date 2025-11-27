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
  // ================== LOGIN ==================
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(ApiConfig.loginUrl());

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final Map<String, dynamic> bodyJson = jsonDecode(response.body);

    if (response.statusCode != 200) {
      return AuthResponse(
        success: false,
        message: bodyJson['message'] as String? ?? 'Login gagal',
        token: null,
        user: null,
      );
    }

    return AuthResponse.fromLoginJson(bodyJson);
  }

  // ================== REGISTER ==================
  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(ApiConfig.registerUrl());

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    final Map<String, dynamic> bodyJson = jsonDecode(response.body);

    final bool isSuccess = response.statusCode == 201;

    return AuthResponse(
      success: isSuccess,
      message: bodyJson['message'] as String? ??
          (isSuccess ? 'Register berhasil' : 'Register gagal'),
      token: null,
      user: bodyJson['user'] as Map<String, dynamic>?,
    );
  }
}