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

  /// When set, the saved session is loaded from SQLite instead of starting a new one.
  final int? sessionId;

  /// Archived view of a finished session: no input, no model.
  final bool readOnly;

  const TeachingTerminalScreen({
    super.key,
    required this.domain,
    this.sessionId,
    this.readOnly = false,
  });

  @override
  State<TeachingTerminalScreen> createState() => _TeachingTerminalScreenState();
}

class _TeachingTerminalScreenState extends State<TeachingTerminalScreen> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  // Not created in read-only mode (no model needed to read an archive).
  LocalLlmService? _llm;
  final LearningEngine _learningEngine = LearningEngine();

  late final ConceptPack _pack = X7Script.packFor(widget.domain);

  final List<_ChatMessage> _messages = [];

  // Student answers, in order. Used by the Mothership Report.
  final List<String> _studentAnswers = [];

  int? _sessionId;
  bool _reportBusy = false;

  bool _modelLoading = true;
  bool _restoring = false;
  bool _generating = false;
  bool _finished = false;
  String? _error;
  String? _dbWarning;

  @override
  void initState() {
    super.initState();

    _sessionId = widget.sessionId;

    if (widget.sessionId != null) {
      _restoring = true;
      _restoreSession(widget.sessionId!);
    } else {
      _messages.add(_openingMessage());
    }

    if (widget.readOnly) {
      _modelLoading = false;
    } else {
      _llm = LocalLlmService();
      _loadModel();
    }
  }

  _ChatMessage _openingMessage() =>
      _ChatMessage(sender: 'X-7', message: _pack.opening, alien: true);

  // ---------------------------------------------------------------------------
  // SQLITE
  // Failures never crash the app, but they are NEVER silent:
  // they print "[DB][ERROR]" in the console and show a warning on screen.
  // ---------------------------------------------------------------------------

  Future<void> _persist(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      debugPrint('[DB][ERROR] $what failed: $e\n$st');
      if (mounted) {
        setState(() => _dbWarning = 'LOCAL LOG WRITE FAILED // $what');
      }
    }
  }

  /// The session row is created on the FIRST accepted answer, so opening a
  /// domain and leaving again never leaves an empty session behind.
  Future<void> _ensureSession() async {
    if (_sessionId != null) return;

    final id = await DatabaseHelper.instance.createSession(
      TeachingSession(
        domain: widget.domain,
        concept: _pack.title,
        startedAt: DateTime.now(),
      ),
    );

    _sessionId = id;
    await _saveMessage('X-7', _pack.opening);
  }

  Future<void> _saveMessage(String sender, String content) async {
    await DatabaseHelper.instance.addMessage(
      Message(
        sessionId: _sessionId!,
        sender: sender,
        content: content,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Rebuilds the chat, the phase and the student answers from SQLite.
  Future<void> _restoreSession(int id) async {
    try {
      final saved = await DatabaseHelper.instance.getMessagesForSession(id);

      final restored = <_ChatMessage>[];
      final answers = <String>[];

      for (final m in saved) {
        final alien = m.sender.startsWith('X-7');
        restored.add(
          _ChatMessage(sender: m.sender, message: m.content, alien: alien),
        );
        if (!alien) answers.add(m.content);
      }

      if (restored.isEmpty) restored.add(_openingMessage());

      // 0 answers = EXPLAIN, 1 = CLARIFY ... 5 = CORRECT. A 6th answer finishes it.
      for (var i = 0; i < answers.length && i < 5; i++) {
        _learningEngine.advance();
      }

      debugPrint(
        '[DB] restored session $id: ${saved.length} messages, '
        '${answers.length} answers, next phase=${_learningEngine.phase.name}',
      );

      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(restored);
        _studentAnswers
          ..clear()
          ..addAll(answers);
        _finished = answers.length >= 6;
        _restoring = false;
      });
      _scrollToBottom();
    } catch (e, st) {
      debugPrint('[DB][ERROR] restore session $id failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        if (_messages.isEmpty) _messages.add(_openingMessage());
        _restoring = false;
        _dbWarning = 'LOCAL LOG READ FAILED // restore session';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // MODEL
  // ---------------------------------------------------------------------------

  Future<void> _loadModel() async {
    final llm = _llm;
    if (llm == null) return;

    try {
      final appDirectory = await getApplicationSupportDirectory();
      final modelPath =
          '${appDirectory.path}/models/qwen2.5-0.5b-instruct-q4_k_m.gguf';

      await llm.loadModel(modelPath);

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
  Future<String?> _generateReaction(
    LocalLlmService llm,
    String studentMessage,
  ) async {
    if (!llm.isLoaded) return null;

    try {
      final buffer = StringBuffer();

      final stream = llm
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
    final llm = _llm;
    final studentMessage = controller.text.trim();

    if (llm == null ||
        studentMessage.isEmpty ||
        _generating ||
        _finished ||
        _restoring ||
        _modelLoading ||
        !llm.isLoaded) {
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

      final raw = await _generateReaction(llm, studentMessage);
      final reply = X7Script.compose(_pack, phase, raw);

      if (!mounted) return;

      setState(() => _replaceLastAlienMessage(reply, label));

      _studentAnswers.add(studentMessage);

      // Save the exchange (in order) before moving on.
      await _persist('save exchange', () async {
        await _ensureSession();
        await _saveMessage('HUMAN', studentMessage);
        await _saveMessage(label, reply);
      });

      if (phase == LearningPhase.correct) {
        if (mounted) setState(() => _finished = true);
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

  /// Loads the saved report for this session, or creates and saves it.
  Future<MothershipReport> _loadOrCreateReport() async {
    final sid = _sessionId;

    if (sid != null) {
      try {
        final existing = await DatabaseHelper.instance.getReportForSession(sid);
        if (existing != null) return existing;
      } catch (e, st) {
        debugPrint('[DB][ERROR] load report failed: $e\n$st');
      }
    }

    final created = MothershipReport(
      sessionId: sid ?? 0,
      reportContent: X7Script.buildReport(_pack, _studentAnswers),
      createdAt: DateTime.now(),
    );

    if (sid != null) {
      await _persist('save report', () async {
        await DatabaseHelper.instance.completeSession(sid);
        await DatabaseHelper.instance.createReport(created);
      });
    }

    return created;
  }

  Future<void> _openReport() async {
    if (_reportBusy) return;
    _reportBusy = true;

    final ready = await _loadOrCreateReport();

    _reportBusy = false;

    if (!mounted) return;

    final transmitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MothershipReportScreen(report: ready, domain: widget.domain),
      ),
    );

    // "Transmit Report" returns true: go back to the Research Terminal.
    if (transmitted == true && mounted) {
      Navigator.pop(context);
    }
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
    _llm?.dispose();
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
              if (_restoring)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: SystemLabel(text: 'RESTORING TRANSMISSION LOG...'),
                ),
              if (_modelLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: SystemLabel(text: 'INITIALIZING X-7 NEURAL CORE...'),
                ),
              if (_dbWarning != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SystemLabel(text: '! $_dbWarning'),
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
              if (widget.readOnly) ...[
                const SystemLabel(text: 'Archived transmission // Read only'),
                const SizedBox(height: 12),
                TerminalButton(
                  label: 'Back to Report',
                  onPressed: () => Navigator.pop(context),
                ),
              ] else if (_finished) ...[
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
                  enabled: !_modelLoading && !_generating && !_restoring,
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
                    if (!_generating && !_modelLoading && !_restoring) {
                      _sendMessage();
                    }
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
