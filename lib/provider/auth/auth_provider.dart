import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';

const _tokenKey = 'sb-access-token';
const _refreshKey = 'sb-refresh-token';
const _phoneKey = 'sb-phone';
const _userIdKey = 'sb-user-id';

class AuthState {
  final bool authenticated;
  final String? userId;
  final String? phone;
  final String? accessToken;
  final String? refreshToken;
  final bool loading;
  final String? error;
  final bool initializing;

  const AuthState({
    this.authenticated = false,
    this.userId,
    this.phone,
    this.accessToken,
    this.refreshToken,
    this.loading = false,
    this.error,
    this.initializing = true,
  });

  AuthState copyWith({
    bool? authenticated,
    String? userId,
    String? phone,
    String? accessToken,
    String? refreshToken,
    bool? loading,
    String? error,
    bool? initializing,
  }) {
    return AuthState(
      authenticated: authenticated ?? this.authenticated,
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      loading: loading ?? this.loading,
      error: error,
      initializing: initializing ?? this.initializing,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  AuthNotifier(this.ref) : super(const AuthState(initializing: true)) {
    _restoreSession();
  }

  String get _baseUrl => 'http://127.0.0.1:${SangeetMedia.serverPort}';

  Future<void> _restoreSession() async {
    try {
      final accessToken = await _secureStorage.read(key: _tokenKey);
      final userId = await _secureStorage.read(key: _userIdKey);
      final phone = await _secureStorage.read(key: _phoneKey);
      if (accessToken != null && userId != null) {
        final refreshToken = await _secureStorage.read(key: _refreshKey);
        state = AuthState(
          authenticated: true,
          userId: userId,
          phone: phone,
          accessToken: accessToken,
          refreshToken: refreshToken,
          initializing: false,
        );
        return;
      }
    } catch (_) {}
    state = const AuthState(initializing: false);
  }

  Future<void> _persistSession(AuthState s) async {
    await _secureStorage.write(key: _tokenKey, value: s.accessToken);
    await _secureStorage.write(key: _refreshKey, value: s.refreshToken);
    await _secureStorage.write(key: _phoneKey, value: s.phone);
    await _secureStorage.write(key: _userIdKey, value: s.userId);
  }

  Future<void> _clearSession() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshKey);
    await _secureStorage.delete(key: _phoneKey);
    await _secureStorage.delete(key: _userIdKey);
  }

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final dio = Dio();
      final response = await dio.post(
        '$_baseUrl/supabase/auth/send-otp',
        data: {'phone': phone},
      );
      if (response.statusCode == 200) {
        state = state.copyWith(loading: false, phone: phone);
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<bool> verifyOtp(String token) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final dio = Dio();
      final response = await dio.post(
        '$_baseUrl/supabase/auth/verify-otp',
        data: {'phone': state.phone, 'token': token},
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['authenticated'] == true) {
          final newState = AuthState(
            authenticated: true,
            userId: data['userId'],
            phone: data['phone'],
            accessToken: data['accessToken'],
            refreshToken: data['refreshToken'],
          );
          await _persistSession(newState);
          state = newState;
          return true;
        }
      }
      state = state.copyWith(loading: false, error: 'Invalid OTP');
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _clearSession();
    state = const AuthState(initializing: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
