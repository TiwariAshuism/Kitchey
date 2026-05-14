import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:kitzz/core/api/api_client.dart';
import 'package:kitzz/core/push/app_notifications_cubit.dart';
import 'package:kitzz/core/push/fcm_background_handler.dart';
import 'package:kitzz/core/push/fcm_service.dart';
import 'package:kitzz/core/router/app_router.dart';
import 'package:kitzz/core/router/go_router_refresh.dart';
import 'package:kitzz/core/theme/app_theme.dart';
import 'package:kitzz/features/auth/bloc/auth_bloc.dart';
import 'package:kitzz/features/auth/bloc/auth_event.dart';
import 'package:kitzz/features/auth/data/auth_repository.dart';
import 'package:kitzz/features/devices/data/device_repository.dart';
import 'package:kitzz/features/messages/bloc/message_bloc.dart';
import 'package:kitzz/features/messages/bloc/message_event.dart';
import 'package:kitzz/features/messages/data/message_repository.dart';
import 'package:kitzz/features/replies/data/reply_repository.dart';
import 'package:kitzz/features/subscription/data/subscription_repository.dart';
import 'package:kitzz/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const KitzzApp());
}

class KitzzApp extends StatefulWidget {
  const KitzzApp({super.key});

  @override
  State<KitzzApp> createState() => _KitzzAppState();
}

class _KitzzAppState extends State<KitzzApp> {
  final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  late final FlutterSecureStorage _storage;
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final MessageRepository _messageRepository;
  late final ReplyRepository _replyRepository;
  late final DeviceRepository _deviceRepository;
  late final SubscriptionRepository _subscriptionRepository;
  late final MessageBloc _messageBloc;
  late final AppNotificationsCubit _appNotificationsCubit;
  late final FcmService _fcmService;
  late final AuthBloc _authBloc;
  late final GoRouterRefreshStream _authRefresh;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _storage = const FlutterSecureStorage();
    _apiClient = ApiClient(storage: _storage);
    _authRepository = AuthRepository(apiClient: _apiClient, storage: _storage);
    _messageRepository = MessageRepository(apiClient: _apiClient);
    _replyRepository = ReplyRepository(apiClient: _apiClient);
    _deviceRepository = DeviceRepository(apiClient: _apiClient);
    _subscriptionRepository = SubscriptionRepository(apiClient: _apiClient);
    _messageBloc = MessageBloc(messageRepository: _messageRepository);
    _appNotificationsCubit = AppNotificationsCubit();
    _fcmService = FcmService(
      authRepository: _authRepository,
      notificationsCubit: _appNotificationsCubit,
      onInboxShouldRefresh: () {
        _messageBloc.add(MessageRefreshRequested());
      },
    );
    _authBloc = AuthBloc(
      authRepository: _authRepository,
      afterAuthenticated: () => _fcmService.syncTokenIfLoggedIn(),
      beforeLogout: () async {
        await _fcmService.clearDevicePushRegistration();
        _appNotificationsCubit.clear();
      },
    )..add(AuthCheckRequested());
    _authRefresh = GoRouterRefreshStream(_authBloc.stream);
    _router = createRouter(
      _authBloc,
      navigatorKey: _rootNavigatorKey,
      refreshListenable: _authRefresh,
    );
    _fcmService.attachRouter(_router);
    _fcmService.configureMessaging();
  }

  @override
  void dispose() {
    _fcmService.dispose();
    _authRefresh.dispose();
    _authBloc.close();
    _messageBloc.close();
    _appNotificationsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _authRepository),
        RepositoryProvider.value(value: _messageRepository),
        RepositoryProvider.value(value: _replyRepository),
        RepositoryProvider.value(value: _deviceRepository),
        RepositoryProvider.value(value: _subscriptionRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _authBloc),
          BlocProvider.value(value: _messageBloc),
          BlocProvider.value(value: _appNotificationsCubit),
        ],
        child: MaterialApp.router(
          title: 'Rasoi',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          scaffoldMessengerKey: _scaffoldMessengerKey,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
