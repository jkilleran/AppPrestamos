import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry padding;
  const BrandLogo({
    super.key,
    this.height = 28,
    this.padding = const EdgeInsets.only(right: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Image.asset(
        'assets/brand/logo.png',
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          // Fallback if asset missing
          return Container(
            width: height,
            height: height,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.attach_money,
              size: height * 0.6,
              color: Colors.black,
            ),
          );
        },
      ),
    );
  }
}
