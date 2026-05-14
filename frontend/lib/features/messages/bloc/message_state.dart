import 'package:equatable/equatable.dart';
import 'package:kitzz/features/messages/data/models/message_model.dart';

abstract class MessageState extends Equatable {
  @override
  List<Object?> get props => [];
}

class MessagesInitial extends MessageState {}

class MessagesLoading extends MessageState {}

class MessagesLoaded extends MessageState {
  final List<MessageModel> messages;
  final bool hasMore;
  final String? paginationError;

  MessagesLoaded({
    required this.messages,
    this.hasMore = true,
    this.paginationError,
  });

  MessagesLoaded copyWith({
    List<MessageModel>? messages,
    bool? hasMore,
    String? paginationError,
    bool clearPaginationError = false,
  }) {
    return MessagesLoaded(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      paginationError: clearPaginationError
          ? null
          : (paginationError ?? this.paginationError),
    );
  }

  @override
  List<Object?> get props => [messages, hasMore, paginationError];
}

class MessagesError extends MessageState {
  final String message;

  MessagesError({required this.message});

  @override
  List<Object?> get props => [message];
}
