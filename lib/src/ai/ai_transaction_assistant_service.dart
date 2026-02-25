import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/models/account.dart';
import '../data/models/finance_category.dart';
import '../tour/models/tour.dart';

enum AiAssistantMode { main, tour, clarify }

enum AiAssistantEntryPoint { mainDashboard, tourDashboard }

class AiConversationMessage {
  const AiConversationMessage({required this.role, required this.text});

  final String role;
  final String text;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role,
    'text': text,
  };
}

class AiMainDraft {
  const AiMainDraft({
    required this.amount,
    required this.type,
    required this.accountName,
    required this.categoryName,
    required this.dateIso,
    required this.note,
  });

  final double? amount;
  final String? type;
  final String? accountName;
  final String? categoryName;
  final String? dateIso;
  final String? note;

  factory AiMainDraft.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const AiMainDraft(
        amount: null,
        type: null,
        accountName: null,
        categoryName: null,
        dateIso: null,
        note: null,
      );
    }
    return AiMainDraft(
      amount: _toDoubleAny(map['amount']),
      type: _toStringOrNull(map['type']),
      accountName: _toStringOrNull(map['accountName']),
      categoryName: _toStringOrNull(map['categoryName']),
      dateIso: _toStringOrNull(map['dateIso']),
      note: _toStringOrNull(map['note']),
    );
  }
}

class AiTourDraft {
  const AiTourDraft({
    required this.amount,
    required this.tourId,
    required this.tourName,
    required this.contributorName,
    required this.sharerNames,
    required this.dateIso,
    required this.note,
  });

  final double? amount;
  final String? tourId;
  final String? tourName;
  final String? contributorName;
  final List<String> sharerNames;
  final String? dateIso;
  final String? note;

  factory AiTourDraft.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const AiTourDraft(
        amount: null,
        tourId: null,
        tourName: null,
        contributorName: null,
        sharerNames: <String>[],
        dateIso: null,
        note: null,
      );
    }

    final rawSharers = map['sharerNames'];
    final sharers = rawSharers is List
        ? rawSharers
              .whereType<Object>()
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    return AiTourDraft(
      amount: _toDoubleAny(map['amount']),
      tourId: _toStringOrNull(map['tourId']),
      tourName: _toStringOrNull(map['tourName']),
      contributorName: _toStringOrNull(map['contributorName']),
      sharerNames: sharers,
      dateIso: _toStringOrNull(map['dateIso']),
      note: _toStringOrNull(map['note']),
    );
  }
}

class AiDecision {
  const AiDecision({
    required this.mode,
    required this.confidence,
    required this.missingFields,
    required this.clarificationQuestion,
    required this.assistantMessage,
    required this.main,
    required this.tour,
  });

  final AiAssistantMode mode;
  final double confidence;
  final List<String> missingFields;
  final String? clarificationQuestion;
  final String? assistantMessage;
  final AiMainDraft main;
  final AiTourDraft tour;

  factory AiDecision.fromMap(Map<String, dynamic> map) {
    final modeRaw = _toStringOrNull(map['mode'])?.toLowerCase() ?? 'clarify';
    final mode = switch (modeRaw) {
      'main' => AiAssistantMode.main,
      'tour' => AiAssistantMode.tour,
      _ => AiAssistantMode.clarify,
    };

    final missingRaw = map['missingFields'];
    final missingFields = missingRaw is List
        ? missingRaw
              .whereType<Object>()
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    return AiDecision(
      mode: mode,
      confidence: _toDoubleAny(map['confidence']) ?? 0,
      missingFields: missingFields,
      clarificationQuestion: _toStringOrNull(map['clarificationQuestion']),
      assistantMessage: _toStringOrNull(map['assistantMessage']),
      main: AiMainDraft.fromMap(_toMap(map['main'])),
      tour: AiTourDraft.fromMap(_toMap(map['tour'])),
    );
  }
}

class AiDecisionRequest {
  const AiDecisionRequest({
    required this.userText,
    required this.entryPoint,
    required this.currentTourId,
    required this.accounts,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.tours,
    required this.history,
  });

  final String userText;
  final AiAssistantEntryPoint entryPoint;
  final String? currentTourId;
  final List<Account> accounts;
  final List<FinanceCategory> expenseCategories;
  final List<FinanceCategory> incomeCategories;
  final List<Tour> tours;
  final List<AiConversationMessage> history;

  Map<String, dynamic> toPayload() {
    return <String, dynamic>{
      'text': userText,
      'history': history.map((item) => item.toJson()).toList(growable: false),
      'context': <String, dynamic>{
        'entryPoint': entryPoint.name,
        'currentTourId': currentTourId,
        'accounts': accounts
            .map((item) => <String, dynamic>{'id': item.id, 'name': item.name})
            .toList(growable: false),
        'categories': <String, dynamic>{
          'expense': expenseCategories
              .map(
                (item) => <String, dynamic>{
                  'id': item.id,
                  'name': item.name,
                  'type': item.type,
                },
              )
              .toList(growable: false),
          'income': incomeCategories
              .map(
                (item) => <String, dynamic>{
                  'id': item.id,
                  'name': item.name,
                  'type': item.type,
                },
              )
              .toList(growable: false),
        },
        'tours': tours
            .map((item) => <String, dynamic>{'id': item.id, 'name': item.name})
            .toList(growable: false),
      },
    };
  }
}

abstract class AiTransactionAssistantService {
  Future<AiDecision> decide(AiDecisionRequest request);
}

class HybridAiTransactionAssistantService
    implements AiTransactionAssistantService {
  HybridAiTransactionAssistantService(this._offline);

  static const endpointOverride = String.fromEnvironment(
    'CASHFLOW_AI_ENDPOINT',
  );
  static const _secretsAssetPath = 'secrets/firebase.secrets.json';
  static String? _cachedEndpoint;
  static bool _endpointLoaded = false;

  final OfflineAiTransactionAssistantService _offline;
  final http.Client _client = http.Client();

  @override
  Future<AiDecision> decide(AiDecisionRequest request) async {
    final endpoint = await _resolveEndpoint();
    if (endpoint == null) {
      return _offline.decide(request);
    }

    try {
      final uri = Uri.parse(endpoint);
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await _client
          .post(uri, headers: headers, body: jsonEncode(request.toPayload()))
          .timeout(const Duration(seconds: 25));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _offline.decide(request);
      }

      final raw = jsonDecode(response.body);
      if (raw is! Map<String, dynamic>) {
        return _offline.decide(request);
      }
      final decisionMap = _toMap(raw['decision']) ?? raw;
      return AiDecision.fromMap(decisionMap);
    } catch (_) {
      return _offline.decide(request);
    }
  }

  Future<String?> _resolveEndpoint() async {
    if (endpointOverride.trim().isNotEmpty) {
      return endpointOverride.trim();
    }
    if (_endpointLoaded) {
      return _cachedEndpoint;
    }
    _endpointLoaded = true;

    try {
      final raw = await rootBundle.loadString(_secretsAssetPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final value = decoded['AI_ASSISTANT_ENDPOINT']?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          _cachedEndpoint = value;
          return _cachedEndpoint;
        }
      }
    } catch (_) {
      // Ignore when local file/key is absent.
    }

    if (Firebase.apps.isNotEmpty) {
      final projectId = Firebase.app().options.projectId.trim();
      if (projectId.isNotEmpty) {
        _cachedEndpoint =
            'https://us-central1-$projectId.cloudfunctions.net/aiTransactionDecision';
        return _cachedEndpoint;
      }
    }

    return _cachedEndpoint;
  }
}

class OfflineAiTransactionAssistantService
    implements AiTransactionAssistantService {
  @override
  Future<AiDecision> decide(AiDecisionRequest request) async {
    final text = request.userText.trim();
    if (text.isEmpty) {
      return _clarify('description', 'Describe the transaction first.');
    }

    final normalized = text.toLowerCase();
    final amount = _extractFirstAmount(text);
    final dateIso = _extractDateIso(normalized);

    final hasTourKeyword = _containsAny(normalized, _tourKeywords);
    final hasMainKeyword =
        _containsAny(normalized, _expenseKeywords) ||
        _containsAny(normalized, _incomeKeywords) ||
        _containsAny(normalized, _mainKeywords);

    final matchedTour = _bestTourMatch(request.tours, normalized);
    final likelyTour = hasTourKeyword || matchedTour != null;
    final likelyMain = hasMainKeyword;

    if (likelyTour && likelyMain && matchedTour == null) {
      return _clarify(
        'mode',
        'Is this a personal transaction or a tour transaction?',
      );
    }

    if (request.entryPoint == AiAssistantEntryPoint.mainDashboard) {
      return _buildMainDecision(
        request: request,
        normalized: normalized,
        originalText: text,
        amount: amount,
        dateIso: dateIso,
      );
    }

    if (likelyTour ||
        (request.entryPoint == AiAssistantEntryPoint.tourDashboard &&
            request.currentTourId != null)) {
      return _buildTourDecision(
        request: request,
        normalized: normalized,
        originalText: text,
        amount: amount,
        dateIso: dateIso,
        matchedTour: matchedTour,
      );
    }

    if (likelyMain ||
        request.entryPoint == AiAssistantEntryPoint.mainDashboard) {
      return _buildMainDecision(
        request: request,
        normalized: normalized,
        originalText: text,
        amount: amount,
        dateIso: dateIso,
      );
    }

    return _clarify(
      'mode',
      'Should I save this as personal or tour transaction?',
    );
  }

  AiDecision _buildMainDecision({
    required AiDecisionRequest request,
    required String normalized,
    required String originalText,
    required double? amount,
    required String? dateIso,
  }) {
    final detectedType = _detectTransactionType(normalized);
    final account = _bestNameMatch(
      request.accounts.map((item) => item.name).toList(growable: false),
      normalized,
    );

    final categoryType = detectedType == 'income'
        ? request.incomeCategories
        : request.expenseCategories;
    final category = _bestNameMatch(
      categoryType.map((item) => item.name).toList(growable: false),
      normalized,
    );

    final missing = <String>[];
    if (amount == null || amount <= 0) {
      missing.add('amount');
    }
    if (detectedType == null) {
      missing.add('type');
    }
    if (account == null) {
      missing.add('account');
    }
    if (category == null) {
      missing.add('category');
    }

    final mainDraft = AiMainDraft(
      amount: amount,
      type: detectedType,
      accountName: account,
      categoryName: category,
      dateIso: dateIso,
      note: originalText,
    );

    if (missing.isNotEmpty) {
      return AiDecision(
        mode: AiAssistantMode.clarify,
        confidence: 0.45,
        missingFields: missing,
        clarificationQuestion: _mainClarificationQuestion(
          missing: missing,
          accounts: request.accounts,
          categories: categoryType,
        ),
        assistantMessage:
            'I need a bit more detail before saving this main transaction.',
        main: mainDraft,
        tour: const AiTourDraft(
          amount: null,
          tourId: null,
          tourName: null,
          contributorName: null,
          sharerNames: <String>[],
          dateIso: null,
          note: null,
        ),
      );
    }

    return AiDecision(
      mode: AiAssistantMode.main,
      confidence: 0.82,
      missingFields: const <String>[],
      clarificationQuestion: null,
      assistantMessage: 'Parsed as a personal transaction.',
      main: mainDraft,
      tour: const AiTourDraft(
        amount: null,
        tourId: null,
        tourName: null,
        contributorName: null,
        sharerNames: <String>[],
        dateIso: null,
        note: null,
      ),
    );
  }

  AiDecision _buildTourDecision({
    required AiDecisionRequest request,
    required String normalized,
    required String originalText,
    required double? amount,
    required String? dateIso,
    required Tour? matchedTour,
  }) {
    Tour? currentTour;
    if (request.currentTourId != null) {
      for (final tour in request.tours) {
        if (tour.id == request.currentTourId) {
          currentTour = tour;
          break;
        }
      }
    }
    final selectedTour =
        matchedTour ??
        currentTour ??
        (request.tours.length == 1 ? request.tours.first : null);
    var sharers = _extractSharers(originalText);
    if (sharers.isEmpty && _mentionsAll(originalText)) {
      sharers = const <String>['__all__'];
    }

    final missing = <String>[];
    if (amount == null || amount <= 0) {
      missing.add('amount');
    }
    if (selectedTour == null) {
      missing.add('tour');
    }
    if (sharers.isEmpty) {
      missing.add('sharers');
    }

    final tourDraft = AiTourDraft(
      amount: amount,
      tourId: selectedTour?.id,
      tourName: selectedTour?.name,
      contributorName: _mentionsPayer(originalText) ? '__me__' : null,
      sharerNames: sharers,
      dateIso: dateIso,
      note: originalText,
    );

    if (missing.isNotEmpty) {
      return AiDecision(
        mode: AiAssistantMode.clarify,
        confidence: 0.45,
        missingFields: missing,
        clarificationQuestion: _tourClarificationQuestion(
          missing: missing,
          tours: request.tours,
        ),
        assistantMessage:
            'I need a bit more detail before saving this tour transaction.',
        main: const AiMainDraft(
          amount: null,
          type: null,
          accountName: null,
          categoryName: null,
          dateIso: null,
          note: null,
        ),
        tour: tourDraft,
      );
    }

    return AiDecision(
      mode: AiAssistantMode.tour,
      confidence: 0.8,
      missingFields: const <String>[],
      clarificationQuestion: null,
      assistantMessage: 'Parsed as a tour transaction.',
      main: const AiMainDraft(
        amount: null,
        type: null,
        accountName: null,
        categoryName: null,
        dateIso: null,
        note: null,
      ),
      tour: tourDraft,
    );
  }

  AiDecision _clarify(String field, String question) {
    return AiDecision(
      mode: AiAssistantMode.clarify,
      confidence: 0,
      missingFields: <String>[field],
      clarificationQuestion: question,
      assistantMessage: 'Need clarification.',
      main: const AiMainDraft(
        amount: null,
        type: null,
        accountName: null,
        categoryName: null,
        dateIso: null,
        note: null,
      ),
      tour: const AiTourDraft(
        amount: null,
        tourId: null,
        tourName: null,
        contributorName: null,
        sharerNames: <String>[],
        dateIso: null,
        note: null,
      ),
    );
  }

  String? _detectTransactionType(String normalized) {
    final income = _containsAny(normalized, _incomeKeywords);
    final expense = _containsAny(normalized, _expenseKeywords);
    if (income && !expense) {
      return 'income';
    }
    if (expense && !income) {
      return 'expense';
    }
    return null;
  }

  Tour? _bestTourMatch(List<Tour> tours, String normalized) {
    if (tours.isEmpty) {
      return null;
    }

    double bestScore = 0;
    Tour? best;
    for (final tour in tours) {
      final score = _scoreName(tour.name, normalized);
      if (score > bestScore) {
        bestScore = score;
        best = tour;
      }
    }
    return bestScore >= 0.65 ? best : null;
  }

  String? _bestNameMatch(List<String> names, String normalized) {
    if (names.isEmpty) {
      return null;
    }

    double bestScore = 0;
    String? best;
    for (final name in names) {
      final score = _scoreName(name, normalized);
      if (score > bestScore) {
        bestScore = score;
        best = name;
      }
    }
    return bestScore >= 0.65 ? best : null;
  }

  String _mainClarificationQuestion({
    required List<String> missing,
    required List<Account> accounts,
    required List<FinanceCategory> categories,
  }) {
    if (missing.contains('amount')) {
      return 'What amount should I save?';
    }
    if (missing.contains('type')) {
      return 'Is this income or expense?';
    }
    if (missing.contains('account')) {
      final top = accounts.take(4).map((item) => item.name).join(', ');
      return top.isEmpty
          ? 'Which account should I use?'
          : 'Which account should I use? ($top)';
    }
    final top = categories.take(4).map((item) => item.name).join(', ');
    return top.isEmpty
        ? 'Which category should I use?'
        : 'Which category should I use? ($top)';
  }

  String _tourClarificationQuestion({
    required List<String> missing,
    required List<Tour> tours,
  }) {
    if (missing.contains('amount')) {
      return 'What amount should I save for this tour transaction?';
    }
    if (missing.contains('tour')) {
      final top = tours.take(4).map((item) => item.name).join(', ');
      return top.isEmpty
          ? 'Which tour is this for?'
          : 'Which tour is this for? ($top)';
    }
    return 'Who are the sharers for this tour transaction?';
  }

  List<String> _extractSharers(String originalText) {
    final lower = originalText.toLowerCase();
    String? segment;
    final patterns = <RegExp>[
      RegExp(r'(?:with|among|between)\s+(.+)$', caseSensitive: false),
      RegExp(r'split\s+with\s+(.+)$', caseSensitive: false),
      RegExp(r'(?:সাথে|সহ|মধ্যে)\s+(.+)$', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(originalText);
      if (match != null) {
        segment = match.group(1);
        break;
      }
    }

    if (segment == null) {
      return const <String>[];
    }

    final cleaned = segment
        .replaceAll(
          RegExp(
            r'\b(for|on|at|today|yesterday|tomorrow)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'(আজ|গতকাল|কাল)', caseSensitive: false), ' ')
        .trim();
    if (cleaned.isEmpty || lower.contains('myself only')) {
      return const <String>[];
    }

    return cleaned
        .split(RegExp(r',|\band\b|&', caseSensitive: false))
        .map((part) => part.trim())
        .where((part) => part.length >= 2)
        .map((part) => _titleCase(part))
        .toSet()
        .toList(growable: false);
  }

  double _scoreName(String name, String text) {
    final normalizedName = name.trim().toLowerCase();
    if (normalizedName.isEmpty) {
      return 0;
    }
    if (text.contains(normalizedName)) {
      return 1.0;
    }

    final nameTokens = _tokens(normalizedName);
    final textTokens = _tokens(text);
    if (nameTokens.isEmpty || textTokens.isEmpty) {
      return 0;
    }

    var overlap = 0;
    for (final token in nameTokens) {
      if (textTokens.contains(token)) {
        overlap += 1;
      }
    }

    final tokenScore = overlap / nameTokens.length;
    if (tokenScore >= 0.75) {
      return tokenScore;
    }

    if (nameTokens.length == 1) {
      final token = nameTokens.first;
      for (final textToken in textTokens) {
        if (_levenshtein(token, textToken) <= 1 && token.length >= 4) {
          return 0.7;
        }
      }
    }

    return tokenScore;
  }
}

bool _containsAny(String text, List<String> needles) {
  for (final needle in needles) {
    if (text.contains(needle)) {
      return true;
    }
  }
  return false;
}

bool _mentionsAll(String text) {
  final lower = text.toLowerCase();
  return lower.contains('everyone') ||
      lower.contains('every member') ||
      lower.contains('all members') ||
      lower.contains('all of us') ||
      lower.contains('sobai') ||
      lower.contains('shobai') ||
      lower.contains('sobar') ||
      lower.contains('shobar') ||
      lower.contains('সবাই') ||
      lower.contains('সবাইকে') ||
      lower.contains('সবার');
}

bool _mentionsPayer(String text) {
  final lower = text.toLowerCase();
  return lower.contains('paid') ||
      lower.contains('payed') ||
      lower.contains('spent') ||
      lower.contains('ami') ||
      lower.contains('ame') ||
      lower.contains('ami e') ||
      lower.contains('আমি') ||
      lower.contains('আমিই') ||
      lower.contains('আমি দিয়েছি') ||
      lower.contains('আমি দিয়েছি');
}

double? _extractFirstAmount(String text) {
  final matches = RegExp(
    r'(\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?)',
  ).allMatches(text);
  for (final match in matches) {
    final raw = (match.group(1) ?? '').replaceAll(',', '');
    final amount = double.tryParse(raw);
    if (amount != null && amount > 0) {
      return amount;
    }
  }
  return null;
}

String? _extractDateIso(String normalized) {
  final now = DateTime.now();
  if (normalized.contains('today')) {
    return DateTime(now.year, now.month, now.day).toIso8601String();
  }
  if (normalized.contains('yesterday')) {
    final d = now.subtract(const Duration(days: 1));
    return DateTime(d.year, d.month, d.day).toIso8601String();
  }
  if (normalized.contains('আজ')) {
    return DateTime(now.year, now.month, now.day).toIso8601String();
  }
  if (normalized.contains('গতকাল')) {
    final d = now.subtract(const Duration(days: 1));
    return DateTime(d.year, d.month, d.day).toIso8601String();
  }

  final slash = RegExp(
    r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b',
  ).firstMatch(normalized);
  if (slash != null) {
    final first = int.tryParse(slash.group(1) ?? '');
    final second = int.tryParse(slash.group(2) ?? '');
    var year = int.tryParse(slash.group(3) ?? '') ?? now.year;
    if (year < 100) {
      year += 2000;
    }
    if (first != null && second != null) {
      final d = DateTime(year, second, first);
      return DateTime(d.year, d.month, d.day).toIso8601String();
    }
  }

  return null;
}

Set<String> _tokens(String text) {
  return text
      .split(RegExp(r'[^a-z0-9]+'))
      .map((item) => item.trim())
      .where((item) => item.length >= 2)
      .toSet();
}

int _levenshtein(String s, String t) {
  if (s == t) {
    return 0;
  }
  if (s.isEmpty) {
    return t.length;
  }
  if (t.isEmpty) {
    return s.length;
  }

  final prev = List<int>.generate(t.length + 1, (i) => i);
  final curr = List<int>.filled(t.length + 1, 0);

  for (var i = 1; i <= s.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= t.length; j++) {
      final cost = s.codeUnitAt(i - 1) == t.codeUnitAt(j - 1) ? 0 : 1;
      curr[j] = [
        curr[j - 1] + 1,
        prev[j] + 1,
        prev[j - 1] + cost,
      ].reduce((a, b) => a < b ? a : b);
    }
    for (var j = 0; j <= t.length; j++) {
      prev[j] = curr[j];
    }
  }

  return prev[t.length];
}

String _titleCase(String input) {
  return input
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}

const _tourKeywords = <String>[
  'tour',
  'trip',
  'group',
  'shared',
  'split',
  'together',
  'friends',
  'ভ্রমণ',
  'ট্যুর',
  'টুর',
  'ট্রিপ',
  'গ্রুপ',
  'দল',
];

const _mainKeywords = <String>['wallet', 'account', 'personal', 'home', 'cash'];

const _incomeKeywords = <String>[
  'salary',
  'income',
  'earned',
  'receive',
  'received',
  'bonus',
  'refund',
  'profit',
  'sold',
  'বেতন',
  'আয়',
  'আয়',
  'রোজগার',
];

const _expenseKeywords = <String>[
  'spent',
  'expense',
  'paid',
  'bought',
  'purchase',
  'bill',
  'rent',
  'grocery',
  'food',
  'ticket',
  'fuel',
  'transport',
  'খরচ',
  'কেনা',
  'পরিশোধ',
  'ভাড়া',
  'ভাড়া',
  'বিল',
];

final aiTransactionAssistantServiceProvider =
    Provider<AiTransactionAssistantService>((ref) {
      return HybridAiTransactionAssistantService(
        OfflineAiTransactionAssistantService(),
      );
    });

String aiAssistantHelpText() {
  return 'Describe your transaction and I will classify it.';
}

Map<String, dynamic>? _toMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, dynamic val) => MapEntry(key.toString(), val));
  }
  return null;
}

String? _toStringOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  final parsed = value.toString().trim();
  return parsed.isEmpty ? null : parsed;
}

double? _toDoubleAny(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}
