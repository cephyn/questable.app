import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'auth_gate.dart';

class AuthWidgets {
  static IconButton signOutButton(context, auth) {
    return IconButton(
      onPressed: () async {
        try {
          await auth.signOut();
          Future.delayed(const Duration(seconds: 3), () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => AuthGate(),
              ),
            );
          });
        } on Exception catch (e) {
          Fluttertoast.showToast(
            msg: e.toString(),
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.SNACKBAR,
            backgroundColor: Colors.black54,
            textColor: Colors.white,
            fontSize: 14.0,
          );
        }
      },
      icon: const Icon(Icons.logout),
    );
  }
}
