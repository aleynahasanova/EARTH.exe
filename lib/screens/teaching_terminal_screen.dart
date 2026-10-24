import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../ai/llm_service.dart';
import '../ai/local_llm_service.dart';
import '../ai/prompt_builder.dart' show LearningPhase;
import '../ai/x7_script.dart';
import '../database/database_helper.dart';
import '../learning/learning_engine.dart';
import '../models/message.dart';
import '../models/mothership_report.dart';
import '../models/teaching_session.dart';
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
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final LocalLlmService _llm = LocalLlmService();
  final LearningEngine _learningEngine = LearningEngine();

  late final ConceptPack _pack = X7Script.packFor(widget.domain);

  final List<_ChatMessage> _messages = [];

  // Student answers, in order. Used by the Mothership Report.
  final List<String> _studentAnswers = [];

  int? _sessionId;
  MothershipReport? _report;
  bool _reportBusy = false;

  bool _modelLoading = true;
  bool _generating = false;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(sender: 'X-7', message: _pack.opening, alien: true),
    );
    _startSession();
    _loadModel();
  }

  // ---------------------------------------------------------------------------
  // SQLITE (every call is wrapped: a database problem must never break the demo)
  // ---------------------------------------------------------------------------

  Future<void> _startSession() async {
    try {
      final id = await DatabaseHelper.instance.createSession(
        TeachingSession(
          domain: widget.domain,
          concept: _pack.title,
          startedAt: DateTime.now(),
        ),
      );
      _sessionId = id;
      await _log('X-7', _pack.opening);
    } catch (e) {
      debugPrint('DB startSession failed: $e');
    }
  }

  Future<void> _log(String sender, String content) async {
    final id = _sessionId;
    if (id == null) return;

    try {
      await DatabaseHelper.instance.addMessage(
        Message(
          sessionId: id,
          sender: sender,
          content: content,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('DB addMessage failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // MODEL
  // ---------------------------------------------------------------------------

  Future<void> _loadModel() async {
    try {
      final appDirectory = await getApplicationSupportDirectory();
      final modelPath =
          '${appDirectory.path}/models/qwen2.5-0.5b-instruct-q4_k_m.gguf';

      await _llm.loadModel(modelPath);

      if (!mounted) return;
      setState(() => _modelLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _modelLoading = false;
        _error = 'X-7 neural core failed to initialize: $e';
      });
    }
  }

  /// One tiny stateless LLM call: a single dry reaction sentence.
  /// Returns null on any failure/timeout so the template still works.
  Future<String?> _generateReaction(String studentMessage) async {
    if (!_llm.isLoaded) return null;

    try {
      final buffer = StringBuffer();

      final stream = _llm
          .generate(
            systemPrompt: X7Script.reactionSystemPrompt,
            conversation: [
              LlmMessage(
                role: 'user',
                content: X7Script.reactionPrompt(_pack.title, studentMessage),
              ),
            ],
            maxTokens: 30,
            temperature: 0.7,
            repeatPenalty: 1.1,
          )
          .timeout(
            const Duration(seconds: 8),
            onTimeout: (sink) => sink.close(),
          );

      await for (final token in stream) {
        buffer.write(token);
      }

      return buffer.toString();
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CONVERSATION
  // ---------------------------------------------------------------------------

  void _replaceLastAlienMessage(String text, String label) {
    _messages[_messages.length - 1] = _ChatMessage(
      sender: label,
      message: text,
      alien: true,
    );
  }

  Future<void> _sendMessage() async {
    final studentMessage = controller.text.trim();

    if (studentMessage.isEmpty ||
        _generating ||
        _finished ||
        _modelLoading ||
        !_llm.isLoaded) {
      return;
    }

    controller.clear();

    final phase = _learningEngine.phase;
    final label = 'X-7 // ${phase.name.toUpperCase()}';

    setState(() {
      _error = null;
      _generating = true;
      _messages.add(
        _ChatMessage(sender: 'HUMAN', message: studentMessage, alien: false),
      );
      _messages.add(
        const _ChatMessage(sender: 'X-7', message: '', alien: true),
      );
    });
    _scrollToBottom();

    try {
      // Too short to count as an explanation: nudge, do NOT advance the phase.
      if (studentMessage.length < 12) {
        if (!mounted) return;
        setState(() => _replaceLastAlienMessage(X7Script.tooShort(), 'X-7'));
        return;
      }

      final raw = await _generateReaction(studentMessage);
      final reply = X7Script.compose(_pack, phase, raw);

      if (!mounted) return;

      setState(() => _replaceLastAlienMessage(reply, label));

      _studentAnswers.add(studentMessage);
      _log('HUMAN', studentMessage);
      _log('X-7', reply);

      if (phase == LearningPhase.correct) {
        setState(() => _finished = true);
      } else {
        _learningEngine.advance();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_messages.last.alien && _messages.last.message.isEmpty) {
          _messages.removeLast();
        }
        _error = 'Transmission error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _generating = false);
        _scrollToBottom();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // REPORT
  // ---------------------------------------------------------------------------

  Future<void> _openReport() async {
    if (_reportBusy) return;
    _reportBusy = true;

    var report = _report;

    if (report == null) {
      final sessionId = _sessionId ?? 0;

      report = MothershipReport(
        sessionId: sessionId,
        reportContent: X7Script.buildReport(_pack, _studentAnswers),
        createdAt: DateTime.now(),
      );

      if (_sessionId != null) {
        try {
          await DatabaseHelper.instance.completeSession(sessionId);
          await DatabaseHelper.instance.createReport(report);
        } catch (e) {
          debugPrint('DB report save failed: $e');
        }
      }

      _report = report;
    }

    final MothershipReport ready = report;
    _reportBusy = false;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MothershipReportScreen(report: ready, domain: widget.domain),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    _llm.dispose();
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
              Text(_pack.title.toUpperCase(), style: AppTextStyles.heading),
              const SizedBox(height: 24),
              if (_modelLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: SystemLabel(text: 'INITIALIZING X-7 NEURAL CORE...'),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: AppTextStyles.body),
                ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: _messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _message(
                      message.sender,
                      message.message.isEmpty ? 'THINKING █' : message.message,
                      message.alien,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (_finished) ...[
                const SystemLabel(text: 'TRANSMISSION COMPLETE'),
                const SizedBox(height: 12),
                TerminalButton(
                  label: 'Generate Mothership Report',
                  onPressed: _openReport,
                ),
              ] else ...[
                TextField(
                  controller: controller,
                  style: AppTextStyles.body,
                  maxLines: 3,
                  enabled: !_modelLoading && !_generating,
                  decoration: const InputDecoration(
                    hintText: '> Explain to X-7...',
                  ),
                ),
                const SizedBox(height: 12),
                TerminalButton(
                  label: _generating
                      ? 'Receiving Transmission...'
                      : 'Send Transmission',
                  onPressed: () {
                    if (!_generating && !_modelLoading) _sendMessage();
                  },
                ),
              ],
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

class _ChatMessage {
  final String sender;
  final String message;
  final bool alien;

  const _ChatMessage({
    required this.sender,
    required this.message,
    required this.alien,
  });
}
