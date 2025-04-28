import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/auth/user_context.dart';
import 'purchase_link_backfill_screen.dart';

/// Entry point for the purchase link backfill functionality
/// This widget is accessible via the admin navigation
class PurchaseLinkBackfill extends StatelessWidget {
  const PurchaseLinkBackfill({super.key});

  @override
  Widget build(BuildContext context) {
    final userContext = Provider.of<UserContext>(context);

    // Only accessible to admins
    if (!userContext.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
        ),
        body: const Center(
          child: Text('You must be an admin to access this page.'),
        ),
      );
    }

    // If user is admin, show the backfill screen
    return const PurchaseLinkBackfillScreen();
  }
}
