import 'dart:convert';

class AppUser {
  final String userId;
  final String username;
  final String email;
  final String branchId;
  final bool isActive;
  final String centlogin; // "YES" or "NO"
  final String profileImage;
  final List<String> allowedMenus;
  final String? createdAt;
  final String? updatedAt;

  AppUser({
    required this.userId,
    required this.username,
    this.email = '',
    this.branchId = '',
    this.isActive = true,
    this.centlogin = 'NO',
    this.profileImage = '',
    this.allowedMenus = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get isCentralLogin => centlogin.trim().toUpperCase() == 'YES';

  bool hasMenuAccess(String menuCode) {
    if (allowedMenus.isEmpty) return false;
    return allowedMenus.contains(menuCode);
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    List<String> parsedMenus = [];
    final rawMenus = json['allowed_menus'];

    if (rawMenus is List) {
      parsedMenus = rawMenus.map((e) => e.toString()).toList();
    } else if (rawMenus is String && rawMenus.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMenus);
        if (decoded is List) {
          parsedMenus = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        parsedMenus = [];
      }
    }

    final rawActive = json['is_active'];
    final bool activeBool = rawActive is bool
        ? rawActive
        : rawActive == 1 || rawActive == '1' || rawActive == 'true';

    return AppUser(
      userId: json['userid']?.toString().trim().toUpperCase() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      branchId: json['branchid']?.toString().trim().toUpperCase() ?? '',
      isActive: activeBool,
      centlogin: json['centlogin']?.toString().trim().toUpperCase() == 'YES' ? 'YES' : 'NO',
      profileImage: json['profile_image']?.toString() ?? '',
      allowedMenus: parsedMenus,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson({String? password}) {
    return {
      'userid': userId,
      'username': username,
      if (password != null && password.isNotEmpty) 'password': password,
      'email': email,
      'branchid': branchId,
      'is_active': isActive ? 1 : 0,
      'centlogin': centlogin,
      'profile_image': profileImage,
      'allowed_menus': allowedMenus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  AppUser copyWith({
    String? userId,
    String? username,
    String? email,
    String? branchId,
    bool? isActive,
    String? centlogin,
    String? profileImage,
    List<String>? allowedMenus,
    String? createdAt,
    String? updatedAt,
  }) {
    return AppUser(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      branchId: branchId ?? this.branchId,
      isActive: isActive ?? this.isActive,
      centlogin: centlogin ?? this.centlogin,
      profileImage: profileImage ?? this.profileImage,
      allowedMenus: allowedMenus ?? this.allowedMenus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
