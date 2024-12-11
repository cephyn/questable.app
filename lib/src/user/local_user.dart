import 'dart:convert';

import 'package:flutter/foundation.dart';

class LocalUser {
  String uid;
  List<String> roles;
  LocalUser({
    required this.uid,
    required this.roles,
  });

  LocalUser copyWith({
    String? uid,
    List<String>? roles,
  }) {
    return LocalUser(
      uid: uid ?? this.uid,
      roles: roles ?? this.roles,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'roles': roles,
    };
  }

  factory LocalUser.fromMap(Map<String, dynamic> map) {
    return LocalUser(
      uid: map['uid'] ?? '',
      roles: List<String>.from(map['roles']),
    );
  }

  String toJson() => json.encode(toMap());

  factory LocalUser.fromJson(String source) =>
      LocalUser.fromMap(json.decode(source));

  @override
  String toString() => 'User(uid: $uid, roles: $roles)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LocalUser &&
        other.uid == uid &&
        listEquals(other.roles, roles);
  }

  @override
  int get hashCode => uid.hashCode ^ roles.hashCode;
}
