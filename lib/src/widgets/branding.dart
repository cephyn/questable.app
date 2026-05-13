import 'package:flutter/material.dart';

/// Small branding widget that displays the app logo and title.
class BrandingTitle extends StatelessWidget {
  final double height;

  const BrandingTitle({super.key, this.height = 36});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'samples/questable_logo.png',
          height: height,
          fit: BoxFit.contain,
          semanticLabel: 'Questable logo',
        ),
        const SizedBox(width: 8),
        Text('Questable', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
