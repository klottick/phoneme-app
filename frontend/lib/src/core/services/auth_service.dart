import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  User? get currentUser => _client.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(Supabase.instance.client);
});

class AppAuthState {
  const AppAuthState({
    required this.user,
    required this.isLoading,
    this.error,
  });

  final User? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;
}

class AuthController extends StateNotifier<AppAuthState> {
  final AuthService _authService;

  AuthController(this._authService)
      : super(AppAuthState(user: _authService.currentUser, isLoading: false)) {
    _authService.authStateChanges.listen((event) {
      if (event.event == AuthChangeEvent.signedIn) {
        state = AppAuthState(user: event.session?.user, isLoading: false);
      } else if (event.event == AuthChangeEvent.signedOut) {
        state = const AppAuthState(user: null, isLoading: false);
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    state = AppAuthState(user: state.user, isLoading: true, error: null);

    try {
      final response = await _authService.signIn(
        email: email,
        password: password,
      );

      if (response.session != null) {
        state = AppAuthState(user: response.user, isLoading: false);
      } else {
        state = const AppAuthState(
          user: null,
          isLoading: false,
          error: 'Sign up successful. Please check your email.',
        );
      }
    } catch (e) {
      state = AppAuthState(
        user: state.user,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> signUp(String email, String password) async {
    state = AppAuthState(user: state.user, isLoading: true, error: null);

    try {
      final response = await _authService.signUp(
        email: email,
        password: password,
      );

      if (response.session != null) {
        state = AppAuthState(user: response.user, isLoading: false);
      } else {
        state = const AppAuthState(
          user: null,
          isLoading: false,
          error: 'Check your email to confirm account.',
        );
      }
    } catch (e) {
      state = AppAuthState(
        user: state.user,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AppAuthState(user: null, isLoading: false);
  }

  void clearError() {
    state = AppAuthState(user: state.user, isLoading: false);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AppAuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthController(authService);
});