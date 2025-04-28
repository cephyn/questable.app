import 'package:cloud_firestore/cloud_firestore.dart';

/// Model class for standardized game systems
///
/// This model represents a standardized game system with official naming
/// and metadata. It includes support for aliases and editions.
class StandardGameSystem {
  String? id;
  String standardName;
  List<String> aliases;
  String? icon;
  List<GameSystemEdition> editions;
  String? publisher;
  String? description;
  DateTime? createdAt;
  DateTime? updatedAt;

  StandardGameSystem({
    this.id,
    required this.standardName,
    this.aliases = const [],
    this.icon,
    this.editions = const [],
    this.publisher,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  /// Create a StandardGameSystem from a Firestore document
  factory StandardGameSystem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Document data was null');
    }

    return StandardGameSystem(
      id: snapshot.id,
      standardName: data['standardName'] ?? '',
      aliases: List<String>.from(data['aliases'] ?? []),
      icon: data['icon'],
      editions: (data['editions'] as List<dynamic>?)
              ?.map((e) => GameSystemEdition.fromMap(e))
              .toList() ??
          [],
      publisher: data['publisher'],
      description: data['description'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert a StandardGameSystem to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'standardName': standardName,
      'aliases': aliases,
      if (icon != null) 'icon': icon,
      'editions': editions.map((e) => e.toMap()).toList(),
      if (publisher != null) 'publisher': publisher,
      if (description != null) 'description': description,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Check if a given name matches this standard system or any of its aliases
  bool matches(String name) {
    final normalizedName = name.trim().toLowerCase();

    // Check the standard name
    if (standardName.toLowerCase() == normalizedName) {
      return true;
    }

    // Check aliases
    for (final alias in aliases) {
      if (alias.toLowerCase() == normalizedName) {
        return true;
      }
    }

    return false;
  }

  /// Add an alias if it doesn't already exist
  void addAlias(String alias) {
    final normalizedAlias = alias.trim();
    if (normalizedAlias.isNotEmpty &&
        !aliases.any((a) => a.toLowerCase() == normalizedAlias.toLowerCase())) {
      aliases.add(normalizedAlias);
    }
  }

  /// Create a copy of this StandardGameSystem with updated fields
  StandardGameSystem copyWith({
    String? id,
    String? standardName,
    List<String>? aliases,
    String? icon,
    List<GameSystemEdition>? editions,
    String? publisher,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StandardGameSystem(
      id: id ?? this.id,
      standardName: standardName ?? this.standardName,
      aliases: aliases ?? this.aliases,
      icon: icon ?? this.icon,
      editions: editions ?? this.editions,
      publisher: publisher ?? this.publisher,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Model class for game system editions
class GameSystemEdition {
  String name;
  String? description;
  int? year;

  GameSystemEdition({
    required this.name,
    this.description,
    this.year,
  });

  factory GameSystemEdition.fromMap(Map<String, dynamic> map) {
    return GameSystemEdition(
      name: map['name'] ?? '',
      description: map['description'],
      year: map['year'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (year != null) 'year': year,
    };
  }
}
