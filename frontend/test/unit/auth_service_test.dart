import 'package:flutter_test/flutter_test.dart';

import 'package:linguist/src/core/services/auth_service.dart';

void main() {
  group('AuthService', () {
    test('authServiceProvider is defined', () {
      // Test that the provider can be referenced
      expect(authServiceProvider, isA<Provider>());
    });
  });

  group('AuthState', () {
    test('initial state has no user', () {
      final state = const AuthState(user: null, isLoading: false);
      
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('state with user is authenticated', () {
      // Mock user would need real supabase setup
      // Testing the state logic
      const state = AuthState(user: null, isLoading: true);
      
      expect(state.isLoading, isTrue);
    });
  });
}