class AuthResponse {
  final UserModel user;
  final TokenPair tokens;

  AuthResponse({required this.user, required this.tokens});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(user: UserModel.fromJson(json['user']), tokens: TokenPair.fromJson(json['tokens']));
  }
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;

  UserModel({required this.id, required this.email, required this.name, required this.createdAt});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(id: json['id'], email: json['email'], name: json['name'], createdAt: DateTime.parse(json['created_at']));
  }
}

class TokenPair {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  TokenPair({required this.accessToken, required this.refreshToken, required this.expiresIn});

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(accessToken: json['access_token'], refreshToken: json['refresh_token'], expiresIn: json['expires_in']);
  }
}
