import '../../core/api/api_error.dart';
import '../../l10n/l10n_ext.dart';
import 'server_config.dart';

/// User-facing, localised text for sign-in and server-setup failures.
/// [error] is an [ApiError], a [ServerConfigError] or anything else.
String authErrorMessage(AppLocalizations l, Object error) {
  switch (error) {
    case InvalidCredentialsError():
      return l.authErrorInvalidCredentials;
    case EmailNotVerifiedError():
      return l.authErrorEmailNotVerified;
    case PasswordLoginDisabledError():
      return l.authErrorPasswordLoginDisabled;
    case RateLimitedError(:final retryAfter):
      if (retryAfter == null) return l.authErrorRateLimited;
      final minutes = (retryAfter.inSeconds / 60).ceil().clamp(1, 1 << 30);
      return l.authErrorRateLimitedMinutes(minutes);
    case NetworkError() || TimeoutError():
      return l.authErrorNetwork;
    case ServerError(:final statusCode):
      return l.authErrorServer(statusCode?.toString() ?? '?');
    case InvalidServerUrlError(:final isEmpty):
      return isEmpty ? l.authErrorEnterServerUrl : l.authErrorInvalidServerUrl;
    case InsecureServerError():
      return l.authErrorInsecure;
    case ApiError(:final message):
      // Server-provided text; not translatable.
      return message;
    default:
      return l.authErrorGeneric;
  }
}

/// Untranslated description for diagnostics (e.g. `AuthState.error`), where
/// no `BuildContext` is available.
String authErrorDebugText(Object error) => switch (error) {
  ApiError(:final message) || ServerConfigError(:final message) => message,
  _ => error.toString(),
};
