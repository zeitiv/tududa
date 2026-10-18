import '../../core/api/api_error.dart';
import '../../l10n/gen/app_localizations.dart';

/// A short, user-facing, localized line for [error].
String apiErrorMessage(AppLocalizations l, Object error) {
  if (error is! ApiError) return l.taskErrorGeneric;
  return switch (error) {
    NetworkError() => l.taskErrorNetwork,
    TimeoutError() => l.taskErrorTimeout,
    CancelledError() => l.taskErrorCancelled,
    UnauthorizedError() => l.taskErrorUnauthorized,
    InvalidCredentialsError() => l.taskErrorInvalidCredentials,
    EmailNotVerifiedError() => l.taskErrorEmailNotVerified,
    PasswordLoginDisabledError() => l.taskErrorPasswordLoginDisabled,
    CsrfError() => l.taskErrorCsrf,
    ForbiddenError() => l.taskErrorForbidden,
    NotFoundError() => l.taskErrorNotFound,
    ValidationError(:final message) => message,
    RateLimitedError() => l.taskErrorRateLimited,
    ServerError(:final statusCode?) => l.taskErrorServer(statusCode),
    ServerError() => l.taskErrorGeneric,
    DecodingError() => l.taskErrorDecoding,
  };
}
