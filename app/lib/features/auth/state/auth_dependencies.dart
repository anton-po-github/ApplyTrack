import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:apply_track/core/api/api_client.dart';
import 'package:apply_track/core/api/dio_api_client.dart';
import 'package:apply_track/core/api/token_reader.dart';
import 'package:apply_track/core/config/app_config.dart';
import 'package:apply_track/features/auth/data/auth_api.dart';
import 'package:apply_track/features/auth/data/auth_repository.dart';
import 'package:apply_track/features/auth/data/storage_token_reader.dart';
import 'package:apply_track/features/auth/data/token_storage.dart';

// Wiring of the real objects. Tests override these providers.
//
// The HTTP layer must tell the controller about a 401, but the controller
// depends on the HTTP layer. To avoid a cycle, the 401 goes through a small
// signal provider. The controller listens to it.

typedef Clock = DateTime Function();

final Provider<Clock> clockProvider = Provider<Clock>(
  (Ref ref) => DateTime.now,
);

final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (Ref ref) => AppConfig.fromEnvironment(),
);

final Provider<TokenStorage> tokenStorageProvider = Provider<TokenStorage>(
  (Ref ref) => SecureTokenStorage(),
);

final Provider<TokenReader> tokenReaderProvider = Provider<TokenReader>(
  (Ref ref) => StorageTokenReader(
    storage: ref.watch(tokenStorageProvider),
    now: ref.watch(clockProvider),
  ),
);

/// Counts the 401 answers of protected calls. Only the change matters.
final NotifierProvider<UnauthorizedSignal, int> unauthorizedSignalProvider =
    NotifierProvider<UnauthorizedSignal, int>(UnauthorizedSignal.new);

class UnauthorizedSignal extends Notifier<int> {
  @override
  int build() => 0;

  void notify() => state++;
}

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>(
  (Ref ref) => DioApiClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
    tokenReader: ref.watch(tokenReaderProvider),
    onUnauthorized: () {
      if (ref.mounted) ref.read(unauthorizedSignalProvider.notifier).notify();
    },
  ),
);

final Provider<AuthApi> authApiProvider = Provider<AuthApi>(
  (Ref ref) => HttpAuthApi(ref.watch(apiClientProvider)),
);

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (Ref ref) => DefaultAuthRepository(
        api: ref.watch(authApiProvider),
        storage: ref.watch(tokenStorageProvider),
      ),
    );
