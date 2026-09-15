import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/system_label.dart';
import '../widgets/terminal_button.dart';
import 'research_terminal_screen.dart';

class FirstContactScreen extends StatelessWidget {
  const FirstContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SystemLabel(text: 'EARTH.exe • RESEARCH LOG #001'),

              const SizedBox(height: 48),

              const SystemLabel(
                text: '> Briefing Doc // Classification: Critical',
              ),

              const SizedBox(height: 24),

              const Text('We have a situation.', style: AppTextStyles.heading),

              const SizedBox(height: 20),

              const Text(
                'An extraterrestrial researcher has arrived on Earth.\n\n'
                'Their civilization is approximately 14,000 years '
                'ahead of ours technologically.\n\n'
                'Unfortunately, they\'ve been assigned to study...',
                style: AppTextStyles.body,
              ),

              const SizedBox(height: 32),

              const Text('human\ncomputing.', style: AppTextStyles.display),

              const SizedBox(height: 12),

              const Text(
                '█',
                style: TextStyle(color: AppColors.accent, fontSize: 20),
              ),

              const Spacer(),

              TerminalButton(
                label: 'Continue',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResearchTerminalScreen(),
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
}
