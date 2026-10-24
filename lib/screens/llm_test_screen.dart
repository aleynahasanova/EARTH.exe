import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../ai/llm_service.dart';
import '../ai/local_llm_service.dart';
import '../ai/prompt_builder.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/system_label.dart';
import '../widgets/terminal_button.dart';
import '../ai/x7_script.dart';

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

  static const String _concept = 'Database Normalization';

  static const String _openingMessage =
      'Database normalization. Your species even has to '
      '"normalize" its databases? Fascinating.\n\n'
      'Explain it to me.';

  final List<_ChatMessage> _messages = [
    const _ChatMessage(sender: 'X-7', message: _openingMessage, alien: true),
  ];

  final List<LlmMessage> _conversation = [
    const LlmMessage(role: 'assistant', content: _openingMessage),
  ];

  bool _modelLoading = true;
  bool _generating = false;
  String? _error;

  // Later the LearningEngine will control this.
  final LearningPhase _currentPhase = LearningPhase.explain;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      final appDirectory = await getApplicationSupportDirectory();

      final modelPath = '${appDirectory.path}/models/Qwen3-1.7B-Q4_K_M.gguf';

      await _llm.loadModel(modelPath);

      if (!mounted) return;

      setState(() {
        _modelLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _modelLoading = false;
        _error = 'X-7 neural core failed to initialize: $e';
      });
    }
  }

  Future<void> _sendMessage() async {
    final studentMessage = controller.text.trim();

    if (studentMessage.isEmpty ||
        _generating ||
        _modelLoading ||
        !_llm.isLoaded) {
      return;
    }

    controller.clear();

    final prompt = PromptBuilder.buildTeachingPrompt(
      domain: widget.domain,
      concept: _concept,
      studentMessage: studentMessage,
      phase: _currentPhase,
    );

    _conversation.add(LlmMessage(role: 'user', content: prompt));

    setState(() {
      _error = null;

      _messages.add(
        _ChatMessage(sender: 'HUMAN', message: studentMessage, alien: false),
      );

      _messages.add(
        const _ChatMessage(sender: 'X-7', message: '', alien: true),
      );

      _generating = true;
    });

    _scrollToBottom();

    final responseBuffer = StringBuffer();

    try {
      final stream = _llm.generate(
        systemPrompt: X7Script.reactionSystemPrompt,
        conversation: _conversation,
      );

      await for (final token in stream) {
        if (!mounted) return;

        responseBuffer.write(token);

        setState(() {
          final current = _messages.last;

          _messages[_messages.length - 1] = _ChatMessage(
            sender: current.sender,
            message: current.message + token,
            alien: current.alien,
          );
        });

        _scrollToBottom();
      }

      final response = responseBuffer.toString().trim();

      if (response.isNotEmpty) {
        _conversation.add(LlmMessage(role: 'assistant', content: response));
      }
    } catch (e) {
      // Remove the failed user turn from LLM history.
      if (_conversation.isNotEmpty && _conversation.last.role == 'user') {
        _conversation.removeLast();
      }

      if (!mounted) return;

      setState(() {
        if (_messages.isNotEmpty && _messages.last.message.isEmpty) {
          _messages.removeLast();
        }

        _error = 'Transmission error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
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

              const Text(
                'DATABASE NORMALIZATION',
                style: AppTextStyles.heading,
              ),

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
                  if (!_generating && !_modelLoading) {
                    _sendMessage();
                  }
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
