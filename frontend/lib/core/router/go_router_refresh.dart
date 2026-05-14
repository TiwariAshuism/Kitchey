import 'dart:async';

import 'package:flutter/foundation.dart';

/// Drives [GoRouter.refreshListenable] from a [Stream] (e.g. [Bloc.stream]).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
