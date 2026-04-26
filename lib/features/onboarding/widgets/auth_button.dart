import 'package:flutter/material.dart';

/// Pill-shaped wide button used across the auth screens (Welcome / Login /
/// Register / Google / Apple). Centralised so visual changes only happen
/// in one file.
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.onPressed,
    required this.backgroundColor,
    required this.child,
    this.foregroundColor,
  });

  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color? foregroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: child,
      ),
    );
  }
}
