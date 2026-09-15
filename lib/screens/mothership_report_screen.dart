import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/system_label.dart';
import '../widgets/terminal_button.dart';

class MothershipReportScreen extends StatefulWidget {
  const MothershipReportScreen({super.key});

  @override
  State<MothershipReportScreen> createState() => _MothershipReportScreenState();
}

class _MothershipReportScreenState extends State<MothershipReportScreen> {
  bool corrected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SystemLabel(
                text: 'Mothership Report // Awaiting Verification',
              ),

              const SizedBox(height: 32),

              const Text('REPORT READY.', style: AppTextStyles.display),

              const SizedBox(height: 12),

              const Text(
                'Verify my understanding before transmission.',
                style: AppTextStyles.muted,
              ),

              const SizedBox(height: 32),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  corrected
                      ? 'Database normalization organizes related '
                            'information into appropriate tables to reduce '
                            'unnecessary redundancy.\n\n'
                            'Third Normal Form is a normalization rule. '
                            'It does not mean that a database must contain '
                            'exactly three tables.'
                      : 'Database normalization organizes information '
                            'into tables to reduce unnecessary redundancy.\n\n'
                            'Third Normal Form means a database must '
                            'contain exactly three tables.',
                  style: AppTextStyles.body,
                ),
              ),

              const Spacer(),

              if (!corrected)
                TerminalButton(
                  label: 'You Messed Up',
                  onPressed: () {
                    setState(() {
                      corrected = true;
                    });
                  },
                ),

              if (corrected) ...[
                const Text(
                  '> CORRECTION ACCEPTED.\n\n'
                  'That is annoyingly reasonable.\n'
                  'Humanity\'s technological reputation remains intact. '
                  'For now.',
                  style: AppTextStyles.body,
                ),

                const SizedBox(height: 24),

                TerminalButton(
                  label: 'Transmit Report',
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
