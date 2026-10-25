import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_repository.dart';

final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>((Ref ref) {
  return TokenStore(const FlutterSecureStorage());
});

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  return ApiClient(
    http.Client(),
    ref.watch(tokenStoreProvider),
    onSessionExpired: () => ref.read(authStateProvider.notifier).signOut(),
  );
});

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  );
});

class AuthNotifier extends StateNotifier<AsyncValue<bool>> {
  AuthNotifier(this._repository) : super(const AsyncValue.loading()) {
    checkStatus();
  }

  final AuthRepository _repository;

  Future<void> checkStatus() async {
    try {
      final loggedIn = await _repository.isLoggedIn();
      state = AsyncValue.data(loggedIn);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _repository.login(email, password);
      state = const AsyncValue.data(true);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> register(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _repository.register(email, password);
      state = const AsyncValue.data(true);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _repository.logout();
    state = const AsyncValue.data(false);
  }
}

final StateNotifierProvider<AuthNotifier, AsyncValue<bool>> authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<bool>>((Ref ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
