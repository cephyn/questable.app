import 'package:flutter/material.dart';

class QuestableMark extends StatelessWidget {
  final double size;
  final String semanticLabel;
  final String assetName;

  const QuestableMark({
    super.key,
    this.size = 28,
    this.semanticLabel = 'Questable icon',
    this.assetName = 'samples/questable_ico_256.png',
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetName,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
    );
  }
}

/// Small branding widget that displays the app logo and title.
class BrandingTitle extends StatelessWidget {
  final double height;

  const BrandingTitle({super.key, this.height = 28});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        QuestableMark(size: height),
        const SizedBox(width: 8),
        Text('Questable', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
