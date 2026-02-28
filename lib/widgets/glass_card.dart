import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color backgroundColor;
  final Color borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.width = double.infinity,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24.0, // Siz tashlagan rasmdagidek ko'proq aylanasi silliq
    this.backgroundColor = const Color(0x15FFFFFF), // Juda nozik, qariyb sezilmas oq fon
    this.borderColor = const Color(0x33FFFFFF), // Juda yupqa oq chegara
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0), // Xira oyna (Blur) darajasi (qanchalik yuqori bo'lsa shuncha xira)
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor,
              width: 0.5, // 0.5px qalinlikdagi oq chegara - ajoyib effekt beradi
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
