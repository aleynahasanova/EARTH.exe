class LlmMessage {
  final String role;
  final String content;

  const LlmMessage({required this.role, required this.content});
}

abstract class LlmService {
  bool get isLoaded;

  Future<void> loadModel(String modelPath);

  Stream<String> generate({
    required String systemPrompt,
    required List<LlmMessage> conversation,
    int maxTokens = 48,
    double temperature = 0.6,
    double repeatPenalty = 1.2,
  });

  Future<void> dispose();
}
