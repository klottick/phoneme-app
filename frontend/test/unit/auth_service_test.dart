import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/core/services/auth_service.dart';

void main() {
  group('AuthService', () {
    test('authControllerProvider is defined', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
    });
  });

  group('AppAuthState', () {
    test('initial state has no user', () {
      const state = AppAuthState(user: null, isLoading: false);

      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('state with user is authenticated', () {
      const state = AppAuthState(user: null, isLoading: true);

      expect(state.isLoading, isTrue);
    });
  });
}
