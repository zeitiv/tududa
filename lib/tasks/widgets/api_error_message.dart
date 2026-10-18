import '../../core/api/api_error.dart';

/// A short, user-facing line for [error]. Not localized yet.
String apiErrorMessage(Object error) {
  if (error is! ApiError) return 'Something went wrong';
  return switch (error) {
    NetworkError() => 'No connection to the server',
    TimeoutError() => 'The server took too long to respond',
    CancelledError() => 'Cancelled',
    UnauthorizedError() => 'Session expired. Please sign in again.',
    InvalidCredentialsError() => 'Invalid email or password',
    EmailNotVerifiedError() => 'Email address not verified',
    PasswordLoginDisabledError() => 'Password login is disabled',
    CsrfError() => 'Security check failed. Please try again.',
    ForbiddenError() => 'You are not allowed to do that',
    NotFoundError() => 'Task not found',
    ValidationError(:final message) => message,
    RateLimitedError() => 'Too many requests. Try again in a moment.',
    ServerError(:final statusCode) => 'Server error ($statusCode)',
    DecodingError() => 'Unexpected response from the server',
  };
}
