import 'package:flutter/material.dart';

import '../ai/x7_script.dart';
import '../models/mothership_report.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/system_label.dart';
import '../widgets/terminal_button.dart';

class MothershipReportScreen extends StatefulWidget {
  final MothershipReport report;
  final String domain;

  const MothershipReportScreen({
    super.key,
    required this.report,
    required this.domain,
  });

  @override
  State<MothershipReportScreen> createState() => _MothershipReportScreenState();
}

class _MothershipReportScreenState extends State<MothershipReportScreen> {
  bool corrected = false;

  late final ConceptPack _pack = X7Script.packFor(widget.domain);

  String get _reportContent {
    if (corrected) {
      return X7Script.correctReport(_pack, widget.report.reportContent);
    }

    return widget.report.reportContent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SystemLabel(
                text: corrected
                    ? 'Mothership Report // Corrected'
                    : 'Mothership Report // Awaiting Verification',
              ),

              const SizedBox(height: 32),

              const Text('REPORT READY.', style: AppTextStyles.display),

              const SizedBox(height: 12),

              const Text(
                'Verify my understanding before transmission.',
                style: AppTextStyles.muted,
              ),

              const SizedBox(height: 32),

              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(
                        color: corrected ? AppColors.accent : AppColors.border,
                      ),
                    ),
                    child: Text(_reportContent, style: AppTextStyles.body),
                  ),
                ),
              ),

              const SizedBox(height: 24),

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
