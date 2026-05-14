import 'package:equatable/equatable.dart';

abstract class MessageEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class MessagesFetchRequested extends MessageEvent {}

class MessagesLoadMore extends MessageEvent {}

class MessageRefreshRequested extends MessageEvent {}
