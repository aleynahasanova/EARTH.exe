import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

class SystemLabel extends StatelessWidget {
  final String text;

  const SystemLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: AppTextStyles.systemLabel);
  }
}
