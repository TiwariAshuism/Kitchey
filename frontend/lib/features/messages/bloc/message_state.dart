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

  MessagesLoaded({required this.messages, this.hasMore = true});

  @override
  List<Object?> get props => [messages.length, hasMore];
}

class MessagesError extends MessageState {
  final String message;

  MessagesError({required this.message});

  @override
  List<Object?> get props => [message];
}
