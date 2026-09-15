import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../widgets/system_label.dart';
import '../widgets/terminal_card.dart';
import 'teaching_terminal_screen.dart';

class ResearchTerminalScreen extends StatelessWidget {
  const ResearchTerminalScreen({super.key});

  static const domains = [
    'Programming',
    'Databases',
    'Software Architecture',
    'Networking',
    'Web Development',
    'AI & Machine Learning',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SystemLabel(text: 'EARTH.exe // Research Terminal'),

              const SizedBox(height: 36),

              const Text(
                'What primitive technology will you teach me today?',
                style: AppTextStyles.display,
              ),

              const SizedBox(height: 12),

              const Text(
                'Select a human computing domain.',
                style: AppTextStyles.muted,
              ),

              const SizedBox(height: 32),

              Expanded(
                child: GridView.builder(
                  itemCount: domains.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.25,
                  ),
                  itemBuilder: (context, index) {
                    return TerminalCard(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TeachingTerminalScreen(domain: domains[index]),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SystemLabel(text: '0${index + 1} // Domain'),
                          Text(domains[index], style: AppTextStyles.heading),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
