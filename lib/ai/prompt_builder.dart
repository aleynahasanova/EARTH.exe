enum LearningPhase {
  explain,
  clarify,
  challenge,
  apply,
  misconception,
  correct,
}

class PromptBuilder {
  PromptBuilder._();

  static String buildTeachingPrompt({
    required String domain,
    required String concept,
    required String studentMessage,
    required LearningPhase phase,
  }) {
    return '''
TOPIC: $domain — $concept
CURRENT PHASE: ${phase.name}
STUDENT: $studentMessage

${_instructionsFor(phase)}

GLOBAL RULES:
- The student teaches you. Never teach the student.
- Never give the correct answer yourself.
- Never repeat a previous question.
- Respond as X-7.
- Maximum 35 words.
- Output only X-7's response.
''';
  }

  static String _instructionsFor(LearningPhase phase) {
    switch (phase) {
      case LearningPhase.explain:
        return '''
EXPLAIN MODE:
The student's first explanation is incomplete.
React briefly.
Ask ONE question about an important missing idea.
''';

      case LearningPhase.clarify:
        return '''
CLARIFY MODE:
Ask ONE new how-or-why question about the student's reasoning.
Do not ask for a definition.
Do not repeat the previous question.
''';

      case LearningPhase.challenge:
        return '''
CHALLENGE MODE:
STOP asking normal clarification questions.

You MUST:
1. State ONE confident but flawed alien solution.
2. Ask the student why your solution fails.

Style example:
"Then simply delete every duplicate. Problem solved. Why would that fail?"
''';

      case LearningPhase.apply:
        return '''
APPLY MODE:
STOP discussing the explanation abstractly.

Give ONE tiny practical scenario about the topic.
Ask the student what they would do.

Do not solve it.
''';

      case LearningPhase.misconception:
        return '''
MISCONCEPTION MODE:
STOP asking normal questions.

State ONE believable but WRONG conclusion about the topic.
Act confident that you finally understand.

End by asking if your conclusion is correct.
''';

      case LearningPhase.correct:
        return '''
CORRECT MODE:
The student is correcting your misconception.

Do not introduce another misconception.
React to their correction.

If their reasoning is convincing, reluctantly admit they corrected you.
Keep it brief and in character.
''';
    }
  }
}
