import '../../core/api/api_error.dart';
import 'server_config.dart';

/// User-facing text for sign-in and server-setup failures. Strings stay
/// inline until localisation (milestone 4).
String describeAuthError(Object error) {
  switch (error) {
    case InvalidCredentialsError():
      return 'Incorrect email or password.';
    case EmailNotVerifiedError():
      return 'Your email address is not verified yet. Check your inbox for '
          'the verification link.';
    case PasswordLoginDisabledError():
      return 'Password sign-in is disabled for this account. It uses '
          'single sign-on (SSO), which this app does not support yet.';
    case RateLimitedError(:final retryAfter):
      if (retryAfter == null) return 'Too many attempts. Try again later.';
      final minutes = (retryAfter.inSeconds / 60).ceil().clamp(1, 1 << 30);
      return 'Too many attempts. Try again in $minutes '
          '${minutes == 1 ? 'minute' : 'minutes'}.';
    case NetworkError() || TimeoutError():
      return 'Could not reach the server. Check your connection and the '
          'server address.';
    case ServerError(:final statusCode):
      return 'The server had a problem (${statusCode ?? '?'}). Try again '
          'later.';
    case InvalidServerUrlError(:final message):
      return message;
    case InsecureServerError():
      return 'Plain HTTP connections are not encrypted.';
    case ApiError(:final message):
      return message;
    default:
      return 'Something went wrong.';
  }
}
