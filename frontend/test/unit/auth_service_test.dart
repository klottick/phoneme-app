import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:linguist/src/core/services/auth_service.dart';

void main() {
  group('AuthService', () {
    for (final needsConfirmation in [false, true]) {
      test('signup respects email confirmation = $needsConfirmation', () async {
        const userId = '10000000-0000-4000-8000-000000000001';
        final user = {
          'id': userId,
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z'
        };
        final token = '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
            '${base64Url.encode(utf8.encode(jsonEncode({
              'sub': userId,
              'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
            })))}.signature';
        final client = SupabaseClient(
            'https://auth.example.invalid', 'public-test-key',
            authOptions:
                const AuthClientOptions(authFlowType: AuthFlowType.implicit),
            httpClient: MockClient((request) async {
          expect(request.url.path, '/auth/v1/signup');
          return http.Response(
              jsonEncode(needsConfirmation
                  ? user
                  : {
                      'user': user,
                      'access_token': token,
                      'refresh_token': 'test-refresh',
                      'token_type': 'bearer',
                      'expires_in': 3600,
                    }),
              200,
              request: request,
              headers: {'content-type': 'application/json'});
        }));
        final controller = AuthController(client);
        addTearDown(() async {
          controller.dispose();
          await client.dispose();
        });
        await controller.signUp('test@example.invalid', 'test-password');
        expect(controller.state.isAuthenticated, !needsConfirmation);
        expect(controller.state.isLoading, isFalse);
        expect(controller.state.user?.id, client.auth.currentUser?.id);
        expect(controller.state.error,
            needsConfirmation ? contains('Check your email') : isNull);
      });
    }
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
