import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class TerminalCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const TerminalCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}
