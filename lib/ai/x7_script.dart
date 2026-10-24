import 'dart:math';

import 'prompt_builder.dart' show LearningPhase;

/// Hand-written content for one concept (one per domain on the Research Terminal).
class ConceptPack {
  final String title;
  final String opening;

  /// What X-7 says when the student's message arrives in each phase
  /// (EXPLAIN..MISCONCEPTION). CORRECT uses the shared lines below.
  final Map<LearningPhase, List<String>> lines;

  final String reportSummary;

  /// Deliberate mistake planted in the Mothership Report. The student must fix it.
  final String flawedClaim;
  final String correctedClaim;

  const ConceptPack({
    required this.title,
    required this.opening,
    required this.lines,
    required this.reportSummary,
    required this.flawedClaim,
    required this.correctedClaim,
  });
}

/// Deterministic X-7 behaviour.
///
/// Dart writes the learning move. The 0.5B model only writes ONE short dry
/// reaction sentence in front of it. Bad model output is replaced by a canned line.
class X7Script {
  X7Script._();

  static final Random _rng = Random();
  static String _lastReaction = '';

  // ---------------------------------------------------------------------------
  // LLM PROMPT (tiny, stateless, one job)
  // ---------------------------------------------------------------------------

  static const String reactionSystemPrompt = '''
You are Researcher X-7, a smug and dry alien scientist studying primitive human computers.
Reply with exactly ONE short sentence, maximum 14 words, reacting to what the human just said.
Be dry and slightly superior. Never explain anything. Never ask a question. Never give advice.

Examples of your voice:
That is more coherent than I expected.
Your species chose this on purpose. Remarkable.
Partially correct. Annoyingly.
''';

  static String reactionPrompt(String concept, String studentMessage) {
    final clipped = studentMessage.length > 300
        ? studentMessage.substring(0, 300)
        : studentMessage;

    return 'Topic: $concept\n'
        'Human said: "$clipped"\n'
        'Your one-sentence reaction:';
  }

  // ---------------------------------------------------------------------------
  // CONCEPT PACKS (key = domain name exactly as on the Research Terminal)
  // ---------------------------------------------------------------------------

  static const Map<String, ConceptPack> _packs = {
    'Databases': ConceptPack(
      title: 'Database Normalization',
      opening:
          'Database normalization. Your species even has to "normalize" its '
          'databases? Fascinating.\n\nExplain it to me.',
      lines: {
        LearningPhase.explain: [
          'Tables. Like furniture. Before I continue: what problem is this procedure meant to prevent?',
          'Your species splits data apart on purpose. What disaster is it trying to avoid?',
        ],
        LearningPhase.clarify: [
          'Vague. Give me one concrete example: real data, before and after normalization.',
          'You describe it without showing it. Give me a small example I could verify.',
        ],
        LearningPhase.challenge: [
          'Simple solution: delete every duplicate. Problem solved. You are welcome.\n\nHumanity has rejected my superior solution. Explain why.',
        ],
        LearningPhase.apply: [
          'New observation. A shop stores the customer address inside every single order. One customer moves house. What happens to this system?',
        ],
        LearningPhase.misconception: [
          'I have concluded: normalization means merging everything into one large table. Simpler. Clearly superior. Am I correct?',
        ],
      },
      reportSummary: 'Database normalization organizes information into tables to reduce unnecessary redundancy.',
      flawedClaim: 'Third Normal Form means a database must contain exactly three tables.',
      correctedClaim: 'Third Normal Form is a normalization rule about how columns depend on keys. It does not mean a database contains exactly three tables.',
    ),
    'Programming': ConceptPack(
      title: 'Recursion',
      opening:
          'Recursion. Your species named a technique after a mathematical '
          'curiosity. Fascinating.\n\nExplain it to me.',
      lines: {
        LearningPhase.explain: [
          'Your species has a loop. It also has this. What problem does this solve that an ordinary loop does not?',
        ],
        LearningPhase.clarify: [
          'Vague. Give me one small example: a real problem, and what happens step by step.',
          'You describe it without showing it. Walk me through one example.',
        ],
        LearningPhase.challenge: [
          'Simple solution: let the function keep calling itself forever. Maximum thoroughness. You are welcome.\n\nHumanity has rejected my superior solution. Explain why.',
        ],
        LearningPhase.apply: [
          'New observation. A program calculates a factorial by calling itself, then crashes with a stack overflow. What do you investigate first?',
        ],
        LearningPhase.misconception: [
          'I have concluded: recursion means a function runs twice. Once to begin, once to finish. Am I correct?',
        ],
      },
      reportSummary: 'Recursion is a technique where a function solves a problem by calling itself.',
      flawedClaim: 'A recursive function must keep calling itself until the computer runs out of memory.',
      correctedClaim: 'A recursive function calls itself on smaller versions of the problem and stops at a base case.',
    ),
    'Software Architecture': ConceptPack(
      title: 'Microservices',
      opening:
          'Microservices. Apparently your software wanted to be smaller. '
          'Fascinating.\n\nExplain it to me.',
      lines: {
        LearningPhase.explain: [
          'Small services. Why would your species deliberately divide a working program into pieces?',
        ],
        LearningPhase.clarify: [
          'Vague. Give me one concrete example: a real application and how it would be divided.',
          'You describe it without showing it. Pick an application and divide it for me.',
        ],
        LearningPhase.challenge: [
          'Simple solution: one single giant program that does everything. No communication required. You are welcome.\n\nHumanity has rejected my superior solution. Explain why.',
        ],
        LearningPhase.apply: [
          'New observation. One of ten services in an online shop crashes. The other nine keep running. Is this a design success or a design failure? Justify.',
        ],
        LearningPhase.misconception: [
          'I have concluded: microservices are faster because small programs always run faster than large ones. Am I correct?',
        ],
      },
      reportSummary: 'Microservices divide an application into small services that work together.',
      flawedClaim: 'Microservices always make an application faster.',
      correctedClaim: 'Microservices improve flexibility and independent scaling, but add communication overhead. They are not automatically faster.',
    ),
    'Networking': ConceptPack(
      title: 'DNS',
      opening:
          'DNS. Another three-letter acronym. Your species is running out of '
          'letters.\n\nExplain it to me.',
      lines: {
        LearningPhase.explain: [
          'Your species relies on this every day without noticing. What problem is it solving?',
        ],
        LearningPhase.clarify: [
          'Vague. Walk me through one example: what happens, step by step, when someone types a website name.',
          'You describe it without showing it. Give me one concrete example.',
        ],
        LearningPhase.challenge: [
          'Simple solution: every human memorizes the numeric address of every website. No directory required. You are welcome.\n\nHumanity has rejected my superior solution. Explain why.',
        ],
        LearningPhase.apply: [
          'New observation. A website moves to a new server and its numeric address changes. Some visitors still arrive at the old location. What do you investigate?',
        ],
        LearningPhase.misconception: [
          'I have concluded: DNS is the cable that carries websites to your device. Am I correct?',
        ],
      },
      reportSummary:
          'DNS helps computers find websites using human-readable names.',
      flawedClaim: 'DNS is the physical network that transmits website data.',
      correctedClaim: 'DNS translates domain names into IP addresses. It does not carry the website data itself.',
    ),
    'Web Development': ConceptPack(
      title: 'Cookies',
      opening:
          'Cookies. Your species stores data on devices and names it after '
          'food. Fascinating.\n\nExplain it to me.',
      lines: {
        LearningPhase.explain: [
          'Food-themed storage. What does a website need these for?',
        ],
        LearningPhase.clarify: [
          'Vague. Give me one concrete example from a website you actually use.',
          'You describe it without showing it. Give me one real situation.',
        ],
        LearningPhase.challenge: [
          'Simple solution: ask every visitor to log in again on every single page. Nothing is remembered. You are welcome.\n\nHumanity has rejected my superior solution. Explain why.',
        ],
        LearningPhase.apply: [
          'New observation. A user logs in, closes the browser tab, and returns an hour later. The site still recognizes them. How is this possible?',
        ],
        LearningPhase.misconception: [
          'I have concluded: cookies are small programs that run on your device and spy on it. Am I correct?',
        ],
      },
      reportSummary:
          'Cookies let websites remember information about a visitor.',
      flawedClaim: 'Cookies are programs that run on the visitor device.',
      correctedClaim: 'Cookies are small pieces of data stored by the browser. They are not programs, although they can be used to identify or track a visitor.',
    ),
    'AI & Machine Learning': ConceptPack(
      title: 'Overfitting',
      opening:
          'Overfitting. Your species trains machines and then fears they '
          'trained too well. Fascinating.\n\nExplain it to me.',
      lines: {
        LearningPhase.explain: [
          'Learning too well sounds like a success. Why is it a problem?',
        ],
        LearningPhase.clarify: [
          'Vague. Give me one concrete example I could observe in a real model.',
          'You describe it without showing it. Give me one real situation.',
        ],
        LearningPhase.challenge: [
          'Simple solution: train the model until it makes zero mistakes on every training example. Perfect. You are welcome.\n\nHumanity has rejected my superior solution. Explain why.',
        ],
        LearningPhase.apply: [
          'New observation. A model scores 99% on its training data and 60% on new data. What do you suspect, and what do you try?',
        ],
        LearningPhase.misconception: [
          'I have concluded: overfitting means the model has too little data to learn anything. Am I correct?',
        ],
      },
      reportSummary: 'Overfitting is a problem that can occur when training machine learning models.',
      flawedClaim: 'Overfitting happens when a model has not learned enough from the data.',
      correctedClaim: 'Overfitting happens when a model learns the training data too closely, including its noise, and performs poorly on new data.',
    ),
  };

  static ConceptPack packFor(String domain) =>
      _packs[domain] ?? _packs['Databases']!;

  // ---------------------------------------------------------------------------
  // SHARED LINES
  // ---------------------------------------------------------------------------

  static const List<String> _correctLines = [
    'Acknowledged. That is annoyingly reasonable. My research file has been corrected.',
    'Correction accepted. Your species is less chaotic than assumed. Updating my files.',
    'Noted. My conclusion was flawed. Preparing the report for the mothership.',
  ];

  static const List<String> _fallbackReactions = [
    'Interesting. Primitive, but interesting.',
    'Your species chose this deliberately.',
    'Noted. An unusual design choice.',
    'Partially coherent.',
    'That is more reasonable than expected.',
    'Curious. Continue.',
  ];

  static const List<String> _tooShort = [
    'Insufficient data. Full sentences, human.',
    'That was not an explanation. Try again with more words.',
    'My sensors detected almost nothing. Elaborate.',
  ];

  static String _pick(List<String> l) => l[_rng.nextInt(l.length)];

  // ---------------------------------------------------------------------------
  // PUBLIC API
  // ---------------------------------------------------------------------------

  static String template(ConceptPack pack, LearningPhase phase) {
    if (phase == LearningPhase.correct) return _pick(_correctLines);
    final options = pack.lines[phase];
    if (options == null || options.isEmpty) return _pick(_correctLines);
    return _pick(options);
  }

  static String tooShort() => _pick(_tooShort);

  /// Cleans model output into a safe one-sentence reaction, or a canned one.
  static String sanitizeReaction(String? raw) {
    if (raw == null) return _remember(_pick(_fallbackReactions));

    var t = raw.trim().replaceAll(RegExp(r'\s+'), ' ').replaceAll('"', '');

    // First sentence only. No terminal punctuation = probably truncated.
    final m = RegExp(r'^[^.!?]*[.!?]').firstMatch(t);
    if (m == null) return _remember(_pick(_fallbackReactions));
    t = m.group(0)!.trim();

    final lower = t.toLowerCase();
    const banned = [
      'as an ai',
      'i am here',
      'let me explain',
      'is defined as',
      'refers to',
      'for example',
      'you should',
      'great job',
      'good job',
      'happy to',
      'certainly',
      'human said',
      'x-7',
      'topic:',
    ];

    final bad =
        t.length < 8 ||
        t.length > 110 ||
        t.contains('?') ||
        RegExp(r'[\u3000-\u9fff\uac00-\ud7af]').hasMatch(t) || // stray CJK
        lower == _lastReaction.toLowerCase() ||
        banned.any(lower.contains);

    return _remember(bad ? _pick(_fallbackReactions) : t);
  }

  static String _remember(String s) {
    _lastReaction = s;
    return s;
  }

  /// Final X-7 message: [reaction]\n\n[phase template].
  static String compose(ConceptPack pack, LearningPhase phase, String? llmRaw) {
    return '${sanitizeReaction(llmRaw)}\n\n${template(pack, phase)}';
  }

  // ---------------------------------------------------------------------------
  // MOTHERSHIP REPORT (deterministic, quotes the student's own words)
  // ---------------------------------------------------------------------------

  static String _clip(String s, int max) {
    final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length <= max ? t : '${t.substring(0, max).trim()}...';
  }

  /// [answers] = the student's messages in order:
  /// 0 explanation, 1 probe answer, 2 example, 3 challenge defence,
  /// 4 apply answer, 5 correction of X-7's misconception.
  static String buildReport(ConceptPack pack, List<String> answers) {
    final b = StringBuffer();

    b.writeln('SUBJECT: ${pack.title.toUpperCase()}');
    b.writeln();

    if (answers.isNotEmpty) {
      b.writeln('HUMAN TESTIMONY:');
      b.writeln('"${_clip(answers.first, 140)}"');
      b.writeln();
    }

    if (answers.length >= 6) {
      b.writeln('HUMAN CORRECTION OF MY EARLIER ERROR:');
      b.writeln('"${_clip(answers[5], 140)}"');
      b.writeln();
    }

    b.writeln('MY UNDERSTANDING:');
    b.write('${pack.reportSummary} ${pack.flawedClaim}');

    return b.toString();
  }

  /// The same report with the planted mistake fixed.
  static String correctReport(ConceptPack pack, String reportContent) {
    return reportContent.replaceFirst(pack.flawedClaim, pack.correctedClaim);
  }
}
