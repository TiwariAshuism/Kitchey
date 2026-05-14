import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitzz/features/messages/bloc/message_bloc.dart';
import 'package:kitzz/features/messages/bloc/message_event.dart';
import 'package:kitzz/features/messages/data/message_repository.dart';
import 'package:kitzz/features/messages/ui/inbox_screen.dart';
import 'package:kitzz/features/replies/data/reply_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockMessageRepository extends Mock implements MessageRepository {}

class MockReplyRepository extends Mock implements ReplyRepository {}

void main() {
  late MockMessageRepository msgRepo;
  late MockReplyRepository replyRepo;

  setUp(() {
    msgRepo = MockMessageRepository();
    replyRepo = MockReplyRepository();
    when(() => msgRepo.getMessages()).thenAnswer((_) async => []);
  });

  testWidgets('inbox shows empty state when there are no messages', (tester) async {
    final router = GoRouter(
      initialLocation: '/inbox',
      routes: [
        GoRoute(
          path: '/inbox',
          builder: (_, __) => RepositoryProvider<ReplyRepository>.value(
            value: replyRepo,
            child: BlocProvider(
              create: (_) => MessageBloc(messageRepository: msgRepo)..add(MessagesFetchRequested()),
              child: const InboxScreen(),
            ),
          ),
        ),
        GoRoute(
          path: '/devices',
          builder: (_, __) => const Scaffold(body: Text('devices')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('No messages yet'), findsOneWidget);
  });
}
