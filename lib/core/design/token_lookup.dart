import 'package:flutter/painting.dart';

import 'tokens.dart';

/// Maps the server's priority / status identifiers onto design tokens.
extension AppTokenLookup on AppTokens {
  /// Numeric task/project priority: 0 low, 1 medium, 2 high.
  Color priorityFor(int code) => switch (code) {
    2 => priorityHigh,
    1 => priorityMedium,
    _ => priorityLow,
  };

  /// String priority as used by projects ('low' | 'medium' | 'high' | 'urgent').
  Color priorityForName(String? name) => switch (name) {
    'high' || 'urgent' => priorityHigh,
    'medium' => priorityMedium,
    _ => priorityLow,
  };

  /// Project status key, e.g. 'in_progress'.
  Color projectStatusFor(String status) => switch (status) {
    'in_progress' => statusInProgress,
    'done' => statusDone,
    'waiting' => statusWaiting,
    'cancelled' => statusCancelled,
    'planned' => statusPlanned,
    'archived' => statusArchived,
    _ => statusNotStarted,
  };
}
