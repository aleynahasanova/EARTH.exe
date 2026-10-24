import 'package:llama_flutter_android/llama_flutter_android.dart';

import 'llm_service.dart';

class LocalLlmService implements LlmService {
  final LlamaController _controller = LlamaController();

  bool _isLoaded = false;
  bool _isGenerating = false;

  @override
  bool get isLoaded => _isLoaded;

  @override
  Future<void> loadModel(String modelPath) async {
    if (_isLoaded) {
      return;
    }

    await _controller.loadModel(
      modelPath: modelPath,
      threads: 4,

      // The prompts are now tiny (no conversation history),
      // so a smaller context is faster and uses less memory.
      contextSize: 1024,
    );

    _isLoaded = true;
  }

  @override
  Stream<String> generate({
    required String systemPrompt,
    required List<LlmMessage> conversation,
    int maxTokens = 48,
    double temperature = 0.6,
    double repeatPenalty = 1.2,
  }) async* {
    if (!_isLoaded) {
      throw StateError('The local LLM has not been loaded.');
    }

    if (_isGenerating) {
      throw StateError('X-7 is already generating a response.');
    }

    _isGenerating = true;

    try {
      final messages = <ChatMessage>[
        ChatMessage(role: 'system', content: systemPrompt),
        ...conversation.map(
          (message) =>
              ChatMessage(role: message.role, content: message.content),
        ),
      ];

      final stream = _controller.generateChat(
        messages: messages,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: 0.85,
        topK: 30,
        repeatPenalty: repeatPenalty,
      );

      bool insideThinking = false;
      String buffer = '';

      // Used to detect degenerate output such as:
      // "instancetypeinstancetypeinstancetype..."
      String visibleOutput = '';

      await for (final token in stream) {
        buffer += token;

        while (buffer.isNotEmpty) {
          if (insideThinking) {
            final endIndex = buffer.indexOf('</think>');

            if (endIndex == -1) {
              if (buffer.length > 8) {
                buffer = buffer.substring(buffer.length - 8);
              }

              break;
            }

            buffer = buffer.substring(endIndex + '</think>'.length);

            insideThinking = false;
            continue;
          }

          final startIndex = buffer.indexOf('<think>');

          if (startIndex == -1) {
            if (buffer.length > 7) {
              final safeLength = buffer.length - 7;
              final visibleChunk = buffer.substring(0, safeLength);

              visibleOutput += visibleChunk;

              if (_looksDegenerate(visibleOutput)) {
                await _controller.stop();

                throw StateError('X-7 entered an invalid repetition loop.');
              }

              yield visibleChunk;

              buffer = buffer.substring(safeLength);
            }

            break;
          }

          if (startIndex > 0) {
            final visibleChunk = buffer.substring(0, startIndex);

            visibleOutput += visibleChunk;

            if (_looksDegenerate(visibleOutput)) {
              await _controller.stop();

              throw StateError('X-7 entered an invalid repetition loop.');
            }

            yield visibleChunk;
          }

          buffer = buffer.substring(startIndex + '<think>'.length);

          insideThinking = true;
        }
      }

      if (!insideThinking && buffer.isNotEmpty) {
        visibleOutput += buffer;

        if (_looksDegenerate(visibleOutput)) {
          throw StateError('X-7 entered an invalid repetition loop.');
        }

        yield buffer;
      }
    } finally {
      try {
        await _controller.stop();
      } catch (_) {
        // Generation may already have stopped naturally.
      }

      _isGenerating = false;
    }
  }

  bool _looksDegenerate(String text) {
    final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    // Don't judge very short output.
    if (normalized.length < 40) {
      return false;
    }

    // Detect a short character sequence being repeated
    // many times, such as:
    //
    // instancetypeinstancetypeinstancetype...
    //
    // We intentionally keep this conservative so normal
    // repeated words in conversation do not trigger it.
    for (var patternLength = 4; patternLength <= 20; patternLength++) {
      if (normalized.length < patternLength * 4) {
        continue;
      }

      final pattern = normalized.substring(normalized.length - patternLength);

      var repetitions = 1;
      var cursor = normalized.length - (patternLength * 2);

      while (cursor >= 0) {
        final candidate = normalized.substring(cursor, cursor + patternLength);

        if (candidate != pattern) {
          break;
        }

        repetitions++;

        if (repetitions >= 4) {
          return true;
        }

        cursor -= patternLength;
      }
    }

    return false;
  }

  @override
  Future<void> dispose() async {
    if (_isGenerating) {
      try {
        await _controller.stop();
      } catch (_) {
        // Ignore shutdown errors while disposing.
      }
    }

    await _controller.dispose();

    _isGenerating = false;
    _isLoaded = false;
  }
}
