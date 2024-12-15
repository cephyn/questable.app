import 'package:flutter/foundation.dart';
import 'dart:html' as html;

import 'package:flutter/material.dart';

class Utils {
  static void setBrowserTabTitle(String title) {
    if (kIsWeb) {
      html.document.title = title;
    }
  }

  static AssetImage getSystemIcon(String systemName) {
    switch (systemName) {
      case "Pathfinder":
        return AssetImage('assets/icons/pfx48.png');
      case "D&D":
      case "Dungeons and Dragons":
      case "Dungeons & Dragons":
        return AssetImage('assets/icons/dndx48.png');
      case "Cypher System":
        return AssetImage('assets/icons/CSOLxBlackx48.png');
      case "Shadowdark":
      case "Shadowdark RPG":
        return AssetImage('assets/icons/shadowdarkx48.png');
      case "Tales of the Valiant":
        return AssetImage('assets/icons/TVx48.66.png');
      default:
        return AssetImage('assets/icons/d20x48.png');
    }
  }
}
