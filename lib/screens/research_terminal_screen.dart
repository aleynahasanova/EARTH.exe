import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/mothership_report.dart';
import '../models/teaching_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/system_label.dart';
import '../widgets/terminal_card.dart';
import 'mothership_report_screen.dart';
import 'teaching_terminal_screen.dart';

class ResearchTerminalScreen extends StatefulWidget {
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
  State<ResearchTerminalScreen> createState() => _ResearchTerminalScreenState();
}

class _DomainStatus {
  final TeachingSession session;
  final MothershipReport? report;

  const _DomainStatus(this.session, this.report);

  bool get completed => session.status == 'completed';
}

class _ResearchTerminalScreenState extends State<ResearchTerminalScreen> {
  Map<String, _DomainStatus> _status = {};
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Reads the latest saved session (and its report) of every domain.
  Future<void> _load() async {
    try {
      final latest = await DatabaseHelper.instance.getLatestSessionPerDomain();
      final map = <String, _DomainStatus>{};

      for (final entry in latest.entries) {
        final session = entry.value;
        MothershipReport? report;

        if (session.status == 'completed' && session.id != null) {
          report = await DatabaseHelper.instance.getReportForSession(
            session.id!,
          );
        }

        map[entry.key] = _DomainStatus(session, report);
      }

      await DatabaseHelper.instance.debugDump();

      if (!mounted) return;
      setState(() {
        _status = map;
        _loadError = null;
      });
    } catch (e, st) {
      debugPrint('[DB][ERROR] research terminal load failed: $e\n$st');
      if (!mounted) return;
      setState(() => _loadError = 'LOCAL LOG UNREADABLE // $e');
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    // Refresh saved state whenever we come back.
    _load();
  }

  Future<void> _openDomain(String domain) async {
    final status = _status[domain];

    if (status == null) {
      // Nothing saved yet: new session.
      await _push(TeachingTerminalScreen(domain: domain));
      return;
    }

    if (status.completed && status.report != null) {
      // Completed: open the saved Mothership Report.
      await _push(
        MothershipReportScreen(report: status.report!, domain: domain),
      );
      return;
    }

    // In progress (or completed without a report): resume the saved chat.
    await _push(
      TeachingTerminalScreen(domain: domain, sessionId: status.session.id),
    );
  }

  Future<void> _startNew(String domain) async {
    await _push(TeachingTerminalScreen(domain: domain));
  }

  @override
  Widget build(BuildContext context) {
    const domains = ResearchTerminalScreen.domains;

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

              if (_loadError != null) ...[
                const SizedBox(height: 12),
                Text(_loadError!, style: AppTextStyles.muted),
              ],

              const SizedBox(height: 24),

              Expanded(
                child: GridView.builder(
                  itemCount: domains.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemBuilder: (context, index) {
                    final domain = domains[index];

                    return TerminalCard(
                      onTap: () => _openDomain(domain),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SystemLabel(text: '0${index + 1} // Domain'),
                              const SizedBox(height: 8),
                              Text(
                                domain,
                                style: AppTextStyles.heading.copyWith(
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          _savedInfo(domain),
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

  Widget _savedInfo(String domain) {
    final status = _status[domain];

    if (status == null) {
      return const SystemLabel(text: 'Not started');
    }

    final String stateLine = status.completed ? 'Completed' : 'In progress';

    String? reportLine;
    if (status.completed && status.report != null) {
      reportLine = status.report!.verified
          ? 'Report verified'
          : 'Report available';
    } else if (!status.completed) {
      reportLine = 'Tap to resume';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          status.session.concept.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.systemLabel.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        SystemLabel(text: stateLine),
        if (reportLine != null) SystemLabel(text: reportLine),
        if (status.completed)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _startNew(domain),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '[ NEW SESSION ]',
                style: AppTextStyles.systemLabel.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
