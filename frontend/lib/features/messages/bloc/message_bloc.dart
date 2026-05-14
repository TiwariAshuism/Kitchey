import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitzz/features/messages/bloc/message_event.dart';
import 'package:kitzz/features/messages/bloc/message_state.dart';
import 'package:kitzz/features/messages/data/message_repository.dart';

class MessageBloc extends Bloc<MessageEvent, MessageState> {
  final MessageRepository _messageRepository;

  MessageBloc({required MessageRepository messageRepository}) : _messageRepository = messageRepository, super(MessagesInitial()) {
    on<MessagesFetchRequested>(_onFetchRequested);
    on<MessagesLoadMore>(_onLoadMore);
    on<MessageRefreshRequested>(_onRefreshRequested);
  }

  Future<void> _onFetchRequested(MessagesFetchRequested event, Emitter<MessageState> emit) async {
    emit(MessagesLoading());
    try {
      final messages = await _messageRepository.getMessages();
      emit(MessagesLoaded(messages: messages, hasMore: messages.length >= 20));
    } catch (e) {
      emit(MessagesError(message: 'Failed to load messages'));
    }
  }

  Future<void> _onLoadMore(MessagesLoadMore event, Emitter<MessageState> emit) async {
    final currentState = state;
    if (currentState is! MessagesLoaded || !currentState.hasMore) return;

    try {
      final lastMessage = currentState.messages.last;
      final cursor = lastMessage.createdAt.toIso8601String();
      final newMessages = await _messageRepository.getMessages(cursor: cursor);

      emit(MessagesLoaded(messages: [...currentState.messages, ...newMessages], hasMore: newMessages.length >= 20));
    } catch (e) {
      // Keep current state on load-more failure
    }
  }

  Future<void> _onRefreshRequested(MessageRefreshRequested event, Emitter<MessageState> emit) async {
    try {
      final messages = await _messageRepository.getMessages();
      emit(MessagesLoaded(messages: messages, hasMore: messages.length >= 20));
    } catch (e) {
      emit(MessagesError(message: 'Failed to refresh messages'));
    }
  }
}
