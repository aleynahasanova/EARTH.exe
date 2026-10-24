import 'package:flutter/material.dart';

import '../ai/x7_script.dart';
import '../database/database_helper.dart';
import '../models/mothership_report.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/system_label.dart';
import '../widgets/terminal_button.dart';
import 'teaching_terminal_screen.dart';

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
  final TextEditingController _correctionController = TextEditingController();

  late final ConceptPack _pack = X7Script.packFor(widget.domain);

  // Starts from the SAVED state, so a verified report reopens as verified.
  late bool _corrected = widget.report.verified;
  late String? _correctionText = widget.report.studentCorrection;

  bool _saving = false;
  String? _hint;
  String? _dbWarning;

  @override
  void dispose() {
    _correctionController.dispose();
    super.dispose();
  }

  Future<void> _submitCorrection() async {
    if (_saving) return;

    final text = _correctionController.text.trim();

    if (text.length < 12) {
      setState(() => _hint = 'Insufficient data. Explain what is wrong.');
      return;
    }

    setState(() {
      _saving = true;
      _hint = null;
    });

    String? warning;
    final sessionId = widget.report.sessionId;

    if (sessionId == 0) {
      warning = 'REPORT IS NOT LINKED TO A SAVED SESSION';
      debugPrint('[DB][ERROR] correction not saved: report has sessionId 0');
    } else {
      try {
        await DatabaseHelper.instance.correctReport(
          sessionId: sessionId,
          correction: text,
        );
      } catch (e, st) {
        warning = 'CORRECTION NOT SAVED';
        debugPrint('[DB][ERROR] correctReport failed: $e\n$st');
      }
    }

    if (!mounted) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _corrected = true;
      _correctionText = text;
      _dbWarning = warning;
      _saving = false;
    });
  }

  void _viewConversation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeachingTerminalScreen(
          domain: widget.domain,
          sessionId: widget.report.sessionId,
          readOnly: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportText = _corrected
        ? X7Script.correctReport(_pack, widget.report.reportContent)
        : widget.report.reportContent;

    final sessionLabel = widget.report.sessionId == 0
        ? 'UNLOGGED'
        : 'LOGGED #${widget.report.sessionId}';

    final correction = _correctionText;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SystemLabel(
                text:
                    'Mothership Report // ${_corrected ? 'Corrected' : 'Awaiting Verification'} // $sessionLabel',
              ),
              const SizedBox(height: 24),
              const Text('REPORT READY.', style: AppTextStyles.display),
              const SizedBox(height: 12),
              Text(
                _corrected
                    ? 'Report verified and saved.'
                    : 'Verify my understanding before transmission. '
                          'Something in this report is wrong.',
                style: AppTextStyles.muted,
              ),
              if (_dbWarning != null) ...[
                const SizedBox(height: 8),
                SystemLabel(text: '! $_dbWarning'),
              ],
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(
                            color: _corrected
                                ? AppColors.accent
                                : AppColors.border,
                          ),
                        ),
                        child: Text(reportText, style: AppTextStyles.body),
                      ),
                      if (_corrected) ...[
                        if (correction != null && correction.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SystemLabel(text: 'Human correction'),
                                const SizedBox(height: 10),
                                Text(correction, style: AppTextStyles.body),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        const Text(
                          '> CORRECTION ACCEPTED.\n\n'
                          'That is annoyingly reasonable.\n'
                          "Humanity's technological reputation remains intact. "
                          'For now.',
                          style: AppTextStyles.body,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_corrected) ...[
                if (_hint != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_hint!, style: AppTextStyles.muted),
                  ),
                TextField(
                  controller: _correctionController,
                  style: AppTextStyles.body,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '> Correct my understanding...',
                  ),
                ),
                const SizedBox(height: 12),
                TerminalButton(
                  label: _saving ? 'Saving...' : 'Submit Correction',
                  onPressed: _submitCorrection,
                ),
              ] else ...[
                if (widget.report.sessionId != 0) ...[
                  TerminalButton(
                    label: 'View Conversation',
                    onPressed: _viewConversation,
                  ),
                  const SizedBox(height: 12),
                ],
                TerminalButton(
                  label: 'Transmit Report',
                  // true = back to the Research Terminal.
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
