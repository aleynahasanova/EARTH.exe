import '../ai/prompt_builder.dart';

class LearningEngine {
  LearningPhase _phase = LearningPhase.explain;

  LearningPhase get phase => _phase;

  void advance() {
    switch (_phase) {
      case LearningPhase.explain:
        _phase = LearningPhase.clarify;
        break;

      case LearningPhase.clarify:
        _phase = LearningPhase.challenge;
        break;

      case LearningPhase.challenge:
        _phase = LearningPhase.apply;
        break;

      case LearningPhase.apply:
        _phase = LearningPhase.misconception;
        break;

      case LearningPhase.misconception:
        _phase = LearningPhase.correct;
        break;

      case LearningPhase.correct:
        break;
    }
  }

  bool get isComplete => _phase == LearningPhase.correct;
}
