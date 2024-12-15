import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';

class QuestCard {
  String? id;
  String? title;
  String? gameSystem;
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

  QuestCard(
      {this.id,
      this.title,
      this.gameSystem,
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
      this.uploadedBy});

  QuestCard.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    gameSystem = json['gameSystem'];
    edition = json['edition'];
    level = json['level'];
    pageLength = json['pageLength'];
    authors = json['authors'].cast<String>();
    publisher = json['publisher'];
    publicationYear = json['publicationYear'];
    setting = json['setting'];
    environments = json['environments'].cast<String>();
    link = json['link'];
    bossVillains = json['bossVillains'].cast<String>();
    commonMonsters = json['commonMonsters'].cast<String>();
    notableItems = json['notableItems'].cast<String>();
    summary = json['summary'];
    genre = json['genre'];
    classification = json['classification'];
    uploadedBy = json['uploadedBy'];
  }

  QuestCard.fromSearchJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    gameSystem = json['gameSystem'];
    edition = json['edition'];
    level = json['level'];
    pageLength = json['pageLength'];
    authors = json['authors'].cast<String>();
    publisher = json['publisher'];
    publicationYear = json['publicationYear'];
    setting = json['setting'];
    environments = json['environments'].cast<String>();
    link = json['link'];
    bossVillains = json['bossVillains'].cast<String>();
    commonMonsters = json['commonMonsters'].cast<String>();
    notableItems = json['notableItems'].cast<String>();
    summary = json['summary'];
    genre = json['genre'];
    classification = json['classification'];
    objectId = json['objectID'];
    uploadedBy = json['uploadedBy'];
  }

  String generateUniqueHash() {
    var bytes = utf8.encode(toJson().toString());
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'gameSystem': gameSystem,
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
      'uploadedBy': uploadedBy
    };
  }

  static Schema aiJsonSchema() {
    return Schema.object(properties: {
      'id': Schema.string(
          description: 'Will be set by system at time of storage'),
      'title': Schema.string(description: 'Title of the adventure.'),
      'classification': Schema.enumString(
          enumValues: ['Adventure', 'Rulebook', 'Supplement', 'Other'],
          description:
              'Classify the file as an RPG Adventure meant to be played at the table, a Rulebook describing how to play an RPG system, a Supplement of new features for an RPG system, or Other if it cannot be determined.'),
      'gameSystem': Schema.string(
          description:
              'The role-playing game system name adventure is intended for.'),
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
          format: 'uri',
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
    });
  }
}
