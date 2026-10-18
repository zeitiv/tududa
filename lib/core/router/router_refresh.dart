import 'package:flutter/foundation.dart';

/// Notifies GoRouter (via `refreshListenable`) to re-run its redirect.
class RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}
