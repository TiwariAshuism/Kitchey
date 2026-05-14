import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitzz/features/messages/bloc/message_bloc.dart';
import 'package:kitzz/features/messages/bloc/message_event.dart';
import 'package:kitzz/features/messages/bloc/message_state.dart';
import 'package:kitzz/features/messages/data/message_repository.dart';
import 'package:kitzz/features/messages/data/models/message_model.dart';
import 'package:mocktail/mocktail.dart';

class MockMessageRepository extends Mock implements MessageRepository {}

MessageModel _message(int second) {
  final id = '00000000-0000-4000-8000-${second.toString().padLeft(12, '0')}';
  return MessageModel(
    id: id,
    senderDeviceId: 'device',
    recipientUserId: 'user',
    transcript: 'Hello $second',
    senderNickname: 'Kitchen',
    createdAt: DateTime.utc(2024, 6, 1, 10, 0, second),
  );
}

void main() {
  late MockMessageRepository repo;

  setUp(() {
    repo = MockMessageRepository();
  });

  blocTest<MessageBloc, MessageState>(
    'loads messages',
    build: () {
      when(() => repo.getMessages()).thenAnswer((_) async => [_message(0)]);
      return MessageBloc(messageRepository: repo);
    },
    act: (bloc) => bloc.add(MessagesFetchRequested()),
    expect: () => [
      MessagesLoading(),
      predicate<MessageState>((s) {
        if (s is! MessagesLoaded) return false;
        return s.messages.length == 1 && !s.hasMore && s.paginationError == null;
      }),
    ],
  );

  blocTest<MessageBloc, MessageState>(
    'load more failure sets paginationError',
    build: () {
      final batch = List<MessageModel>.generate(20, _message);
      when(() => repo.getMessages()).thenAnswer((_) async => batch);
      when(() => repo.getMessages(cursor: any(named: 'cursor'))).thenThrow(Exception('network'));
      return MessageBloc(messageRepository: repo);
    },
    act: (bloc) async {
      bloc.add(MessagesFetchRequested());
      await bloc.stream.firstWhere((s) => s is MessagesLoaded);
      bloc.add(MessagesLoadMore());
    },
    expect: () => [
      MessagesLoading(),
      predicate<MessageState>((s) {
        if (s is! MessagesLoaded) return false;
        return s.messages.length == 20 && s.hasMore && s.paginationError == null;
      }),
      predicate<MessageState>((s) {
        if (s is! MessagesLoaded) return false;
        return s.messages.length == 20 && s.paginationError != null;
      }),
    ],
  );

  blocTest<MessageBloc, MessageState>(
    'MessagePaginationErrorConsumed clears paginationError',
    build: () {
      final batch = List<MessageModel>.generate(20, _message);
      when(() => repo.getMessages()).thenAnswer((_) async => batch);
      when(() => repo.getMessages(cursor: any(named: 'cursor'))).thenThrow(Exception('network'));
      return MessageBloc(messageRepository: repo);
    },
    act: (bloc) async {
      bloc.add(MessagesFetchRequested());
      await bloc.stream.firstWhere((s) => s is MessagesLoaded);
      bloc.add(MessagesLoadMore());
      await bloc.stream.firstWhere(
        (s) => s is MessagesLoaded && s.paginationError != null,
      );
      bloc.add(MessagePaginationErrorConsumed());
    },
    expect: () => [
      MessagesLoading(),
      predicate<MessageState>((s) {
        if (s is! MessagesLoaded) return false;
        return s.messages.length == 20 && s.hasMore && s.paginationError == null;
      }),
      predicate<MessageState>((s) {
        if (s is! MessagesLoaded) return false;
        return s.messages.length == 20 && s.paginationError != null;
      }),
      predicate<MessageState>((s) {
        if (s is! MessagesLoaded) return false;
        return s.messages.length == 20 && s.paginationError == null;
      }),
    ],
  );
}
