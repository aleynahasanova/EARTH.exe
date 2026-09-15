import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const TextStyle display = TextStyle(
    fontFamily: 'monospace',
    fontSize: 30,
    height: 1.2,
    fontWeight: FontWeight.bold,
    color: AppColors.accent,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: 'monospace',
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'monospace',
    fontSize: 15,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle muted = TextStyle(
    fontFamily: 'monospace',
    fontSize: 14,
    height: 1.5,
    color: AppColors.textMuted,
  );

  static const TextStyle systemLabel = TextStyle(
    fontFamily: 'monospace',
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 2,
    color: AppColors.textMuted,
  );

  static const TextStyle button = TextStyle(
    fontFamily: 'monospace',
    fontSize: 15,
    fontWeight: FontWeight.bold,
    color: AppColors.background,
  );
}
