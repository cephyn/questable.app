class QuestCard {
  int? id;
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
      this.summary});

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
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['gameSystem'] = gameSystem;
    data['edition'] = edition;
    data['level'] = level;
    data['pageLength'] = pageLength;
    data['authors'] = authors;
    data['publisher'] = publisher;
    data['publicationYear'] = publicationYear;
    data['setting'] = setting;
    data['environments'] = environments;
    data['link'] = link;
    data['bossVillains'] = bossVillains;
    data['commonMonsters'] = commonMonsters;
    data['notableItems'] = notableItems;
    data['summary'] = summary;
    return data;
  }

  static const sampleJson = '''{"quests": [
    {
  "id": 1,
  "title": "Shadows of the Forgotten Realm",
  "gameSystem": "Fantasy Legends",
  "edition": "3rd Edition",
  "level": "Intermediate",
  "pageLength": 45,
  "authors": ["John Doe", "Jane Smith"],
  "publisher": "Epic Quests Publishing",
  "publicationYear": "2024",
  "setting": "Ancient Ruins of Eldoria",
  "environments": ["Dungeon", "Forest", "Cave"],
  "link": "https://example.com/adventure",
  "bossVillains": ["Zarok the Destroyer", "Lady Seraphine"],
  "commonMonsters": ["Goblins", "Skeletons", "Wolves"],
  "notableItems": ["Sword of Destiny", "Amulet of Power", "Healing Potion"],
  "summary": "The once-thriving kingdom of Eldoria is shrouded in darkness as ancient shadows reawaken to reclaim their lost power. Heroes must delve into forgotten ruins, uncovering long-buried secrets and battling sinister forces to restore light to the realm."
},
{
  "id": 2,
  "title": "Quest for the Crimson Crown",
  "gameSystem": "Mythic Realms",
  "edition": "1st Edition",
  "level": "Advanced",
  "pageLength": 60,
  "authors": ["Alice Johnson", "Mark Lee"],
  "publisher": "Legends & Lore Press",
  "publicationYear": "2023",
  "setting": "Frozen Wastes of Arktoria",
  "environments": ["Snowy Mountains", "Ice Caves"],
  "link": "https://example.com/frozen-wastes",
  "bossVillains": ["Frost King Icelar", "Ice Witch Freya"],
  "commonMonsters": ["Ice Elementals", "Frost Giants"],
  "notableItems": ["Frostfire Blade", "Amulet of Warmth"],
  "summary": "In the heart of the Emerald Empire, a mythical Crimson Crown holds the power to unite or destroy. As rival factions vie for control, brave adventurers embark on a perilous journey to retrieve the crown and decide the empire's fate."
},
{
  "id": 3,
  "title": "Secrets of the Enchanted Isle",
  "gameSystem": "Epic Quests",
  "edition": "2nd Edition",
  "level": "Beginner",
  "pageLength": 30,
  "authors": ["Emily Carter", "David Brown"],
  "publisher": "Heroic Adventures Co.",
  "publicationYear": "2024",
  "setting": "Sunken City of Atlantis",
  "environments": ["Underwater Ruins", "Coral Reefs"],
  "link": "https://example.com/sunken-city",
  "bossVillains": ["Kraken", "Sea Sorcerer Malgar"],
  "commonMonsters": ["Merfolk Warriors", "Giant Squids"],
  "notableItems": ["Trident of the Depths", "Pearl of Wisdom"],
  "summary": "Legends speak of an isle where magic flows freely and ancient creatures dwell. Explorers set sail to uncover the isle's secrets, facing enchanted forests, mystical beings, and the island's guardians in a quest to harness its magical treasures."
},
{
  "id": 4,
  "title": "Legends of the Arcane Citadel",
  "gameSystem": "Dark Realms",
  "edition": "4th Edition",
  "level": "Expert",
  "pageLength": 75,
  "authors": ["Jessica Green", "Thomas White"],
  "publisher": "Shadowlands Publishing",
  "publicationYear": "2022",
  "setting": "Haunted Forest of Eldergloom",
  "environments": ["Dark Forest", "Ancient Ruins"],
  "link": "https://example.com/haunted-forest",
  "bossVillains": ["Lich King Valthor", "Witch Queen Morgana"],
  "commonMonsters": ["Undead Soldiers", "Dark Spirits"],
  "notableItems": ["Shadowblade", "Ring of Necromancy"],
  "summary": "The Arcane Citadel, a fortress of unparalleled magic, stands at the center of a war between rival sorcerers. Heroes must navigate treacherous landscapes, forge alliances, and unlock the citadel's hidden powers to tip the scales in this epic battle."
},
{
  "id": 5,
  "title": "The Dragon's Hoard: A Tale of Valor",
  "gameSystem": "Arcane Realms",
  "edition": "3rd Edition",
  "level": "Intermediate",
  "pageLength": 50,
  "authors": ["Michael Black", "Sarah Adams"],
  "publisher": "Mystic Quests Ltd.",
  "publicationYear": "2021",
  "setting": "Mystic Isle of Avalon",
  "environments": ["Enchanted Forest", "Crystal Caves"],
  "link": "https://example.com/mystic-isle",
  "bossVillains": ["Dragon Lord Draconis", "Sorceress Elara"],
  "commonMonsters": ["Magic Wolves", "Elemental Spirits"],
  "notableItems": ["Crystal Staff", "Elixir of Life"],
  "summary": "A legendary dragon guards a hoard of untold riches, but obtaining its treasure requires more than just bravery. Adventurers must solve ancient puzzles, overcome deadly traps, and face the dragon's wrath in a tale of valor and cunning."
},
{
  "id": 6,
  "title": "Mysteries of the Eldritch Forest",
  "gameSystem": "Hero's Journey",
  "edition": "5th Edition",
  "level": "Beginner",
  "pageLength": 35,
  "authors": ["Anna Wilson", "Robert King"],
  "publisher": "Quest Masters Inc.",
  "publicationYear": "2023",
  "setting": "Ancient Kingdom of Thrania",
  "environments": ["Royal Palace", "Desert Wastes"],
  "link": "https://example.com/ancient-kingdom",
  "bossVillains": ["Emperor Zarak", "Sand Warlord Khalid"],
  "commonMonsters": ["Sand Golems", "Desert Bandits"],
  "notableItems": ["Scimitar of the Sands", "Pharaoh's Necklace"],
  "summary": "The Eldritch Forest, a place of eerie beauty and haunting secrets, calls to those seeking adventure. Heroes must brave the forest's twisted paths, encounter mystical creatures, and unveil the dark truth behind the forest's enchantment."
}
  ]}
  ''';

  static String getMockJsonData() {
    return sampleJson;
  }

  static String getMockSingleJsonData() {
    return '''
    {
  "id": 6,
  "title": "Mysteries of the Eldritch Forest",
  "gameSystem": "Hero's Journey",
  "edition": "5th Edition",
  "level": "Beginner",
  "pageLength": 35,
  "authors": ["Anna Wilson", "Robert King"],
  "publisher": "Quest Masters Inc.",
  "publicationYear": "2023",
  "setting": "Ancient Kingdom of Thrania",
  "environments": ["Royal Palace", "Desert Wastes"],
  "link": "https://example.com/ancient-kingdom",
  "bossVillains": ["Emperor Zarak", "Sand Warlord Khalid"],
  "commonMonsters": ["Sand Golems", "Desert Bandits"],
  "notableItems": ["Scimitar of the Sands", "Pharaoh's Necklace"],
  "summary": "The Eldritch Forest, a place of eerie beauty and haunting secrets, calls to those seeking adventure. Heroes must brave the forest's twisted paths, encounter mystical creatures, and unveil the dark truth behind the forest's enchantment."
}
''';
  }
}
