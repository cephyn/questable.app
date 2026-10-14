import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'auth_gate.dart';

class AuthWidgets {
  static IconButton signOutButton(BuildContext context, auth) {
    return IconButton(
      onPressed: () async {
        try {
          await auth.signOut();
          Future.delayed(const Duration(seconds: 3), () {
            if (!context.mounted) return;
            Navigator.of(
              context,
              rootNavigator: true,
            ).push(MaterialPageRoute(builder: (_) => AuthGate()));
          });
        } on Exception catch (e) {
          if (!context.mounted) return;
          Fluttertoast.showToast(
            msg: e.toString(),
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.SNACKBAR,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surface.withAlpha(220),
            textColor: Theme.of(context).colorScheme.onSurface,
            fontSize: 14.0,
          );
        }
      },
      icon: const Icon(Icons.logout),
    );
  }
}
