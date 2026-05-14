import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitzz/features/auth/bloc/auth_event.dart';
import 'package:kitzz/features/auth/bloc/auth_state.dart';
import 'package:kitzz/features/auth/data/auth_repository.dart';
import 'package:kitzz/features/auth/data/models/auth_models.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final Future<void> Function()? _afterAuthenticated;
  final Future<void> Function()? _beforeLogout;

  AuthBloc({
    required AuthRepository authRepository,
    Future<void> Function()? afterAuthenticated,
    Future<void> Function()? beforeLogout,
  })  : _authRepository = authRepository,
        _afterAuthenticated = afterAuthenticated,
        _beforeLogout = beforeLogout,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    final isLoggedIn = await _authRepository.isLoggedIn();
    if (isLoggedIn) {
      // For now, emit a placeholder authenticated state
      // In a full implementation, we'd fetch the user profile
      emit(Authenticated(user: _placeholderUser()));
      await _afterAuthenticated?.call();
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoginRequested(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _authRepository.login(event.email, event.password);
      emit(Authenticated(user: response.user));
      await _afterAuthenticated?.call();
    } catch (e) {
      emit(AuthError(message: _extractError(e)));
    }
  }

  Future<void> _onRegisterRequested(AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _authRepository.register(event.name, event.email, event.password);
      emit(Authenticated(user: response.user));
      await _afterAuthenticated?.call();
    } catch (e) {
      emit(AuthError(message: _extractError(e)));
    }
  }

  Future<void> _onLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _beforeLogout?.call();
    await _authRepository.logout();
    emit(Unauthenticated());
  }

  String _extractError(dynamic e) {
    if (e is Exception) {
      return e.toString().replaceFirst('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }

  // Placeholder for when we only have tokens stored but no cached user
  _placeholderUser() {
    return UserModel(id: '', email: '', name: '', createdAt: DateTime.now());
  }
}
