import 'package:flutter/material.dart';


/// Displays detailed information about a SampleItem.
class QuestCardDetailsView extends StatelessWidget {
  const QuestCardDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> id = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;


    return Scaffold(
      appBar: AppBar(
        title: Text(id['docId'].toString()),
      ),
      body: Center(
        child: Text(id['docId'].toString()),
      ),
    );
  }
}