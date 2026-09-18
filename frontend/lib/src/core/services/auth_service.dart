import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../course/backend.dart';

class AppAuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AppAuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;
}

class AuthController extends StateNotifier<AppAuthState> {
  final SupabaseClient? _client;
  StreamSubscription? _authSubscription;

  AuthController(this._client) : super(const AppAuthState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    final user = _client?.auth.currentUser;
    if (user != null) {
      state = AppAuthState(user: user, isLoading: false);
    } else {
      state = const AppAuthState(isLoading: false);
    }

    _authSubscription = _client?.auth.onAuthStateChange.listen((event) {
      if (event.session != null) {
        state = AppAuthState(user: event.session!.user, isLoading: false);
      } else {
        state = const AppAuthState(user: null, isLoading: false);
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    if (_client == null) {
      state = const AppAuthState(
          error: 'This is the offline demo. Configure Supabase to sign in.');
      return;
    }
    state = AppAuthState(user: state.user, isLoading: true, error: null);

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        state = AppAuthState(user: response.user, isLoading: false);
      } else {
        state = const AppAuthState(
          user: null,
          isLoading: false,
          error: 'Sign in failed',
        );
      }
    } catch (e) {
      state = AppAuthState(
        user: null,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> signUp(String email, String password) async {
    if (_client == null) {
      state = const AppAuthState(
          error:
              'This is the offline demo. Configure Supabase to create an account.');
      return;
    }
    state = AppAuthState(user: state.user, isLoading: true, error: null);

    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      if (response.session != null) {
        state = AppAuthState(user: response.session!.user, isLoading: false);
      } else {
        state = const AppAuthState(
          user: null,
          isLoading: false,
          error: 'Check your email to confirm account',
        );
      }
    } catch (e) {
      state = AppAuthState(
        user: null,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    state = AppAuthState(user: state.user, isLoading: true);
    await _client?.auth.signOut();
    state = const AppAuthState(user: null, isLoading: false);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AppAuthState>((ref) {
  return AuthController(courseBackend);
});
