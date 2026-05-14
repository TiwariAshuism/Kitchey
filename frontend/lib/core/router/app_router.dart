import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:kitzz/features/auth/bloc/auth_bloc.dart';
import 'package:kitzz/features/auth/bloc/auth_state.dart';
import 'package:kitzz/features/auth/ui/login_screen.dart';
import 'package:kitzz/features/auth/ui/register_screen.dart';
import 'package:kitzz/features/devices/ui/device_list_screen.dart';
import 'package:kitzz/features/messages/ui/inbox_screen.dart';
import 'package:kitzz/features/messages/ui/message_detail_screen.dart';
import 'package:kitzz/features/settings/ui/settings_screen.dart';

GoRouter createRouter(
  AuthBloc authBloc, {
  GlobalKey<NavigatorState>? navigatorKey,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    navigatorKey: navigatorKey,
    refreshListenable: refreshListenable,
    initialLocation: '/login',
    redirect: (context, state) {
      final authState = authBloc.state;
      final isAuth = authState is Authenticated;
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/inbox';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/inbox', builder: (context, state) => const InboxScreen()),
      GoRoute(
        path: '/messages/:id',
        builder: (context, state) => MessageDetailScreen(messageId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/devices', builder: (context, state) => const DeviceListScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
}
