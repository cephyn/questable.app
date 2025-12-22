import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:quest_cards/src/util/browser.dart' as browser;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Utils {
  static void setBrowserTabTitle(String title) {
    if (kIsWeb) {
      browser.setDocumentTitle(title);
    }
  }

  static String generateRandomString(int length) {
    const characters =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(
            length, (index) => characters[random.nextInt(characters.length)])
        .join();
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

  static String capitalizeTitle(String? title) {
    if (title == null) return '';
    return title.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static TextSpan createHyperlink(String url, String linkText) {
    return TextSpan(
      text: linkText,
      style:
          TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
      recognizer: TapGestureRecognizer()
        ..onTap = () async {
          await launchUrl(Uri.parse(url));
        },
    );
  }

  static String formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final now = DateTime.now();

    // Format date differently based on how recent it is
    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      // Today - just show time
      return 'Today at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(dateTime).inDays < 7) {
      // Within the last week - show day name and time
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      final weekday = weekdays[dateTime.weekday - 1];
      return '$weekday at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // Older - show full date
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
  }
}
