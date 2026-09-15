import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/system_label.dart';
import '../widgets/terminal_button.dart';
import 'mothership_report_screen.dart';

class TeachingTerminalScreen extends StatefulWidget {
  final String domain;

  const TeachingTerminalScreen({super.key, required this.domain});

  @override
  State<TeachingTerminalScreen> createState() => _TeachingTerminalScreenState();
}

class _TeachingTerminalScreenState extends State<TeachingTerminalScreen> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
              const SystemLabel(text: 'Subject Communication Log // 00:00:01'),

              const SizedBox(height: 24),

              SystemLabel(text: 'Domain // ${widget.domain}'),

              const SizedBox(height: 8),

              const Text(
                'DATABASE NORMALIZATION',
                style: AppTextStyles.heading,
              ),

              const SizedBox(height: 32),

              _message(
                'X-7',
                'Database normalization. Your species even has to '
                    '"normalize" its databases? Fascinating.\n\n'
                    'Explain it to me.',
                true,
              ),

              const SizedBox(height: 20),

              _message(
                'HUMAN',
                'It is a way of organizing data to reduce redundancy.',
                false,
              ),

              const SizedBox(height: 20),

              _message(
                'X-7',
                'You used "data" to explain "database". Very efficient.\n\n'
                    'What exactly do you mean by redundancy?',
                true,
              ),

              const Spacer(),

              TextField(
                controller: controller,
                style: AppTextStyles.body,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '> Explain to X-7...',
                ),
              ),

              const SizedBox(height: 12),

              TerminalButton(
                label: 'Send Transmission',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MothershipReportScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _message(String sender, String message, bool alien) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: alien ? AppColors.accent : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SystemLabel(text: sender),
          const SizedBox(height: 10),
          Text(message, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
