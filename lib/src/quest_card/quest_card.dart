import 'package:cloud_firestore/cloud_firestore.dart'; // Added Firestore import for Timestamp type
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_ai/firebase_ai.dart';

class QuestCard {
  String? id;
  String? productTitle;
  String? title;
  String? gameSystem;
  String? standardizedGameSystem; // New field for standardized game system name
  String? edition;
  String? level;
  int? pageLength;
  List<String>? authors;
  String? publisher;
  String? publicationYear;
  String? setting;
  List<String>? environments;
  String? link;
  List<String>? bossVillains;
  List<String>? commonMonsters;
  List<String>? notableItems;
  String? summary;
  String? genre;
  String? objectId;
  String? classification;
  String? uploadedBy;
  bool isPublic = true; // Default to true for public access
  String? systemMigrationStatus; // New field to track migration status
  DateTime?
      systemMigrationTimestamp; // New field to track when migration occurred
  String? uploaderEmail; // Added field for uploader's email
  DateTime? uploadedTimestamp; // Added field for upload timestamp

  QuestCard(
      {this.id,
      this.productTitle,
      this.title,
      this.gameSystem,
      this.standardizedGameSystem,
      this.edition,
      this.level,
      this.pageLength,
      this.authors,
      this.publisher,
      this.publicationYear,
      this.setting,
      this.environments,
      this.link,
      this.bossVillains,
      this.commonMonsters,
      this.notableItems,
      this.summary,
      this.genre,
      this.classification,
      this.uploadedBy,
      this.isPublic = true,
      this.systemMigrationStatus,
      this.systemMigrationTimestamp,
      this.uploaderEmail, // Added to constructor
      this.uploadedTimestamp}); // Added to constructor // Default to true for public access

  QuestCard.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    productTitle = json['productTitle'];
    title = json['title'];
    gameSystem = json['gameSystem'];
    standardizedGameSystem = json['standardizedGameSystem'];
    edition = json['edition'];
    level = json['level'];
    pageLength = json['pageLength'];
    authors = json['authors']?.cast<String>();
    publisher = json['publisher'];
    publicationYear = json['publicationYear'];
    setting = json['setting'];
    environments = json['environments']?.cast<String>();
    link = json['link'];
    bossVillains = json['bossVillains']?.cast<String>();
    commonMonsters = json['commonMonsters']?.cast<String>();
    notableItems = json['notableItems']?.cast<String>();
    summary = json['summary'];
    genre = json['genre'];
    classification = json['classification'];
    uploadedBy = json['uploadedBy'];
    // Handle isPublic with fallback to true if not present in document
    isPublic = json['isPublic'] ?? true;
    // Migration status fields
    systemMigrationStatus = json['systemMigrationStatus'];

    // Updated timestamp parsing for systemMigrationTimestamp
    final smtValue = json['systemMigrationTimestamp'];
    if (smtValue != null) {
      if (smtValue is Timestamp) {
        // Check if it's a Firestore Timestamp
        systemMigrationTimestamp = smtValue.toDate();
      } else if (smtValue is String) {
        // Check if it's a String
        systemMigrationTimestamp = DateTime.tryParse(smtValue);
      } else {
        // Log or handle other unexpected types
        print(
            'Warning: systemMigrationTimestamp in fromJson has unexpected type: \${smtValue.runtimeType}');
        systemMigrationTimestamp = null;
      }
    } else {
      systemMigrationTimestamp = null;
    }

    uploaderEmail = json['uploaderEmail'];

    // Updated timestamp parsing for uploadedTimestamp
    final utValue = json['uploadedTimestamp'];
    if (utValue != null) {
      if (utValue is Timestamp) {
        // Check if it's a Firestore Timestamp
        uploadedTimestamp = utValue.toDate();
      } else if (utValue is String) {
        // Check if it's a String
        uploadedTimestamp = DateTime.tryParse(utValue);
      } else {
        // Log or handle other unexpected types
        print(
            'Warning: uploadedTimestamp in fromJson has unexpected type: \${utValue.runtimeType}');
        uploadedTimestamp = null;
      }
    } else {
      uploadedTimestamp = null;
    }
  }

  QuestCard.fromSearchJson(Map<String, dynamic> json) {
    id = json['id'];
    productTitle = json['productTitle'];
    title = json['title'];
    gameSystem = json['gameSystem'];
    standardizedGameSystem = json['standardizedGameSystem'];
    edition = json['edition'];
    level = json['level'];
    pageLength = json['pageLength'];
    authors = json['authors']?.cast<String>();
    publisher = json['publisher'];
    publicationYear = json['publicationYear'];
    setting = json['setting'];
    environments = json['environments']?.cast<String>();
    link = json['link'];
    bossVillains = json['bossVillains']?.cast<String>();
    commonMonsters = json['commonMonsters']?.cast<String>();
    notableItems = json['notableItems']?.cast<String>();
    summary = json['summary'];
    genre = json['genre'];
    classification = json['classification'];
    objectId = json['objectID'];
    uploadedBy = json['uploadedBy'];
    // Handle isPublic with fallback to true if not present in document
    isPublic = json['isPublic'] ?? true;
    // Migration status fields
    systemMigrationStatus = json['systemMigrationStatus'];
    // Handle timestamps
    final timestampValue = json['systemMigrationTimestamp'];
    if (timestampValue != null) {
      if (timestampValue is int) {
        systemMigrationTimestamp =
            DateTime.fromMillisecondsSinceEpoch(timestampValue);
      } else if (timestampValue is double) {
        systemMigrationTimestamp =
            DateTime.fromMillisecondsSinceEpoch(timestampValue.toInt());
      } else if (timestampValue is String) {
        systemMigrationTimestamp = DateTime.tryParse(timestampValue);
      } else {
        final type = timestampValue.runtimeType;
        print(
            'Warning: systemMigrationTimestamp has unexpected type: $type. Value: $timestampValue');
        systemMigrationTimestamp = null;
      }
    } else {
      systemMigrationTimestamp = null;
    }
    uploaderEmail = json['uploaderEmail'];
    // Handle uploadedTimestamp
    final uploadedTimestampValue = json['uploadedTimestamp'];
    if (uploadedTimestampValue != null) {
      if (uploadedTimestampValue is int) {
        uploadedTimestamp =
            DateTime.fromMillisecondsSinceEpoch(uploadedTimestampValue);
      } else if (uploadedTimestampValue is double) {
        uploadedTimestamp = DateTime.fromMillisecondsSinceEpoch(
            uploadedTimestampValue.toInt());
      } else if (uploadedTimestampValue is String) {
        uploadedTimestamp = DateTime.tryParse(uploadedTimestampValue);
      } else {
        final type = uploadedTimestampValue.runtimeType;
        print(
            'Warning: uploadedTimestamp has unexpected type: $type. Value: $uploadedTimestampValue');
        uploadedTimestamp = null;
      }
    } else {
      uploadedTimestamp = null;
    }
  }

  String generateUniqueHash() {
    var bytes = utf8.encode(toJson().toString());
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productTitle': productTitle,
      'title': title,
      'gameSystem': gameSystem,
      'standardizedGameSystem': standardizedGameSystem,
      'edition': edition,
      'level': level,
      'pageLength': pageLength,
      'authors': authors,
      'publisher': publisher,
      'publicationYear': publicationYear,
      'setting': setting,
      'environments': environments,
      'link': link,
      'bossVillains': bossVillains,
      'commonMonsters': commonMonsters,
      'notableItems': notableItems,
      'summary': summary,
      'genre': genre,
      'classification': classification,
      'objectId': objectId,
      'uploadedBy': uploadedBy,
      'isPublic': isPublic, // Include in JSON output
      'systemMigrationStatus': systemMigrationStatus,
      'systemMigrationTimestamp': systemMigrationTimestamp,
      'uploaderEmail': uploaderEmail, // Added to toJson
      'uploadedTimestamp': uploadedTimestamp, // Added to toJson
    };
  }

  static Schema aiJsonSchema() {
    return Schema.object(properties: {
      'id': Schema.string(
          description: 'Will be set by system at time of storage'),
      'productTitle': Schema.string(
          description: 'Title of the book containing the adventure.'),
      'title': Schema.string(description: 'Title of the adventure.'),
      'classification': Schema.enumString(
          enumValues: ['Adventure', 'Rulebook', 'Supplement', 'Other'],
          description:
              'Classify the file as an RPG Adventure meant to be played at the table, a Rulebook describing how to play an RPG system, a Supplement of new features for an RPG system, or Other if it cannot be determined.'),
      'gameSystem': Schema.string(
          description:
              'The role-playing game system name adventure is intended for.'),
      'standardizedGameSystem': Schema.string(
          description: 'Standardized name of the game system.'), // New field
      'edition': Schema.string(description: 'The edition of the game system.'),
      'level': Schema.string(
          description:
              'The character level or tier the adventure is intended to support.'),
      'pageLength':
          Schema.integer(description: 'The number of pages in the adventure.'),
      'authors': Schema.array(
          items: Schema.string(),
          description: 'A list of authors who wrote the adventure.'),
      'publisher': Schema.string(description: 'The publisher of the adventure.'),
      'publicationYear':
          Schema.string(description: 'The year the adventure was published.'),
      'setting': Schema.string(
          description:
              'The game world or setting the adventure takes place in.'),
      'environments': Schema.array(
          items: Schema.string(),
          description:
              'A list of typical environments featured in the adventure (e.g., dungeon, forest, city).'),
      'link': Schema.string(
          description: 'A URL link to where the adventure can be found.'),
      'bossVillains': Schema.array(
          items: Schema.string(),
          description: 'A list of major villains or bosses in the adventure.'),
      'commonMonsters': Schema.array(
          items: Schema.string(),
          description:
              'A list of common monsters or enemies found in the adventure.'),
      'notableItems': Schema.array(
          items: Schema.string(),
          description:
              'A list of notable magic items or important objects in the adventure.'),
      'summary': Schema.string(description: 'A brief summary of the adventure.'),
      'genre': Schema.string(description: 'The genre of the adventure.'),
      'uploadedBy': Schema.string(
          description: 'The user ID of the person who uploaded the quest card.'),
      'uploaderEmail': Schema.string(
          description: "The email of the user who uploaded the quest card."), // Added to AI Schema
      'uploadedTimestamp': Schema.string( // Representing as String for schema, will be DateTime in Dart
          format: 'date-time',
          description: "The timestamp when the quest card was uploaded."), // Added to AI Schema
      'isPublic': Schema.boolean(
          description: 'Indicates if the quest card is publicly visible.'),
      'systemMigrationStatus': Schema.string(
          description: 'The migration status of the quest card, if applicable.'),
      'systemMigrationTimestamp': Schema.string(
          format: 'date-time',
          description:
              'The timestamp when the quest card was migrated to the new system, if applicable.'),
    });
  }

  static Schema adventureTypeSchema() {
    return Schema.object(properties: {
      'adventureType': Schema.enumString(
          enumValues: ['Single', 'Multi'],
          description:
              'Classify the file as a single adventure or a collection of adventures.')
    });
  }

  static Schema globalQuestData() {
    return Schema.object(properties: {
      'id': Schema.string(
          description: 'Will be set by system at time of storage'),
      'productTitle': Schema.string(
          description: 'Title of the book containing the adventure.'),
      'gameSystem': Schema.string(
          description:
              'The role-playing game system name adventure is intended for.'),
      'standardizedGameSystem': Schema.string(
          description: 'Standardized name of the game system.'), // New field
      'edition': Schema.string(description: 'The edition of the game system.'),
      'publisher':
          Schema.string(description: 'The publisher of the adventure.'),
      'publicationYear': Schema.string(
          description: 'The year in which the adventure was published.'),
      'link': Schema.string(
          //format: 'uri',
          description: 'The URL or web address of the document, if available.'),
      'authors': Schema.array(
          items: Schema.string(),
          description: 'The author(s) of the adventure.'),
    });
  }

  static Schema individualQuestData() {
    return Schema.object(properties: {
      'classification': Schema.enumString(
          enumValues: ['Adventure', 'Rulebook', 'Supplement', 'Other'],
          description:
              'Classify the file as an RPG Adventure meant to be played at the table, a Rulebook describing how to play an RPG system, a Supplement of new features for an RPG system, or Other if it cannot be determined.'),
      'level': Schema.string(
          description:
              'The character level or tier the adventure is intended to support.'),
      'pageLength':
          Schema.integer(description: 'The number of pages in the adventure.'),
      'authors': Schema.array(
          items: Schema.string(),
          description: 'The author(s) of the adventure.'),
      'genre': Schema.string(
          description:
              'The genre the adventure best fits in. Examples include fantasy, science fiction, etc.'),
      'setting': Schema.string(
          description:
              'The fictional world the adventure is set in, or the type of fictional world if one is not declared.'),
      'environments': Schema.array(
          items: Schema.string(),
          description:
              'The environment(s), biomes, structures in which the adventure takes place, both outdoor and indoor.'),
      'bossVillains': Schema.array(
          items: Schema.string(),
          description:
              'The final adversary (or adversaries) that must be overcome in the adventure.'),
      'commonMonsters': Schema.array(
          items: Schema.string(),
          description:
              'The common foes found throughout the adventure that can often be found in any adventure in the genre.'),
      'notableItems': Schema.array(
          items: Schema.string(),
          description:
              'Any unique or notable item(s) that could be acquired as treasure in the adventure.'),
      'summary': Schema.string(
          description:
              'A short summary of the adventure, without spoilers. Limit to around 100 words.'),
    });
  }

  static Schema aiJsonSchemaMulti() {
    return Schema.array(
        items: Schema.object(properties: {
      'id': Schema.string(
          description: 'Will be set by system at time of storage'),
      'productTitle': Schema.string(
          description: 'Title of the book containing the adventure.'),
      'title': Schema.string(description: 'Title of the specific adventure.'),
      'classification': Schema.enumString(
          enumValues: ['Adventure', 'Rulebook', 'Supplement', 'Other'],
          description:
              'Classify the file as an RPG Adventure meant to be played at the table, a Rulebook describing how to play an RPG system, a Supplement of new features for an RPG system, or Other if it cannot be determined.'),
      'gameSystem': Schema.string(
          description:
              'The role-playing game system name adventure is intended for.'),
      'standardizedGameSystem': Schema.string(
          description: 'Standardized name of the game system.'), // New field
      'edition': Schema.string(description: 'The edition of the game system.'),
      'level': Schema.string(
          description:
              'The character level or tier the adventure is intended to support.'),
      'pageLength':
          Schema.integer(description: 'The number of pages in the adventure.'),
      'authors': Schema.array(
          items: Schema.string(),
          description: 'The author(s) of the adventure.'),
      'publisher':
          Schema.string(description: 'The publisher of the adventure.'),
      'publicationYear': Schema.string(
          description: 'The year in which the adventure was published.'),
      'genre': Schema.string(
          description:
              'The genre the adventure best fits in. Examples include fantasy, science fiction, etc.'),
      'setting': Schema.string(
          description:
              'The fictional world the adventure is set in, or the type of fictional world if one is not declared.'),
      'environments': Schema.array(
          items: Schema.string(),
          description:
              'The environment(s), biomes, structures in which the adventure takes place, both outdoor and indoor.'),
      'link': Schema.string(
          //format: 'uri',
          description:
              'A web link to where the adventure may be purchased or downloaded. Validate the web site exists, otherwise generate an empty string.'),
      'bossVillains': Schema.array(
          items: Schema.string(),
          description:
              'The final adversary (or adversaries) that must be overcome in the adventure.'),
      'commonMonsters': Schema.array(
          items: Schema.string(),
          description:
              'The common foes found throughout the adventure that can often be found in any adventure in the genre.'),
      'notableItems': Schema.array(
          items: Schema.string(),
          description:
              'Any unique or notable item(s) that could be acquired as treasure in the adventure.'),
      'summary': Schema.string(
          description:
              'A short summary of the adventure, without spoilers. Limit to around 100 words.'),
    }));
  }
}
