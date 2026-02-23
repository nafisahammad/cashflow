import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
      amount: _toDouble(map['amount']),
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
      amount: _toDouble(map['amount']),
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
      confidence: _toDouble(map['confidence']) ?? 0,
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

class RemoteAiTransactionAssistantService
    implements AiTransactionAssistantService {
  static const endpoint = String.fromEnvironment('CASHFLOW_AI_ENDPOINT');

  final http.Client _client = http.Client();

  @override
  Future<AiDecision> decide(AiDecisionRequest request) async {
    if (endpoint.trim().isEmpty) {
      return _fallbackDecision(request.userText);
    }

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
      throw StateError('AI request failed (${response.statusCode}).');
    }

    final raw = jsonDecode(response.body);
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('AI response must be a JSON object.');
    }

    final decisionMap = _toMap(raw['decision']) ?? raw;
    return AiDecision.fromMap(decisionMap);
  }

  AiDecision _fallbackDecision(String text) {
    final normalized = text.toLowerCase();
    final amount = _extractFirstAmount(normalized);

    if (normalized.contains('tour') ||
        normalized.contains('trip') ||
        normalized.contains('split') ||
        normalized.contains('shared')) {
      return AiDecision(
        mode: AiAssistantMode.tour,
        confidence: 0.55,
        missingFields: amount == null
            ? const <String>['amount']
            : const <String>[],
        clarificationQuestion: amount == null
            ? 'What was the amount for this tour transaction?'
            : null,
        assistantMessage: amount == null
            ? 'I detected this as a tour transaction but still need the amount.'
            : 'I detected this as a tour transaction.',
        main: const AiMainDraft(
          amount: null,
          type: null,
          accountName: null,
          categoryName: null,
          dateIso: null,
          note: null,
        ),
        tour: AiTourDraft(
          amount: amount,
          tourId: null,
          tourName: null,
          contributorName: null,
          sharerNames: const <String>[],
          dateIso: null,
          note: text.trim(),
        ),
      );
    }

    if (normalized.contains('income') ||
        normalized.contains('salary') ||
        normalized.contains('bonus') ||
        normalized.contains('earned')) {
      return AiDecision(
        mode: AiAssistantMode.main,
        confidence: 0.55,
        missingFields: const <String>['account', 'category'],
        clarificationQuestion:
            'Which account and category should I use for this income?',
        assistantMessage:
            'I detected an income transaction but need account and category.',
        main: AiMainDraft(
          amount: amount,
          type: 'income',
          accountName: null,
          categoryName: null,
          dateIso: null,
          note: text.trim(),
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

    if (normalized.contains('spent') ||
        normalized.contains('expense') ||
        normalized.contains('bought') ||
        normalized.contains('paid')) {
      return AiDecision(
        mode: AiAssistantMode.main,
        confidence: 0.55,
        missingFields: const <String>['account', 'category'],
        clarificationQuestion:
            'Which account and category should I use for this expense?',
        assistantMessage:
            'I detected an expense transaction but need account and category.',
        main: AiMainDraft(
          amount: amount,
          type: 'expense',
          accountName: null,
          categoryName: null,
          dateIso: null,
          note: text.trim(),
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

    return const AiDecision(
      mode: AiAssistantMode.clarify,
      confidence: 0,
      missingFields: <String>['mode'],
      clarificationQuestion:
          'Should this be saved as a personal transaction or a tour transaction?',
      assistantMessage: 'I could not clearly determine the mode.',
      main: AiMainDraft(
        amount: null,
        type: null,
        accountName: null,
        categoryName: null,
        dateIso: null,
        note: null,
      ),
      tour: AiTourDraft(
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
}

double? _extractFirstAmount(String text) {
  final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
  if (match == null) {
    return null;
  }
  return double.tryParse(match.group(1) ?? '');
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

double? _toDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

final aiTransactionAssistantServiceProvider =
    Provider<AiTransactionAssistantService>((ref) {
      return RemoteAiTransactionAssistantService();
    });

String aiAssistantHelpText() {
  if (kReleaseMode &&
      RemoteAiTransactionAssistantService.endpoint.trim().isEmpty) {
    return 'AI endpoint is not configured.';
  }
  return 'Describe your transaction and I will classify it.';
}
