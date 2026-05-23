import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _brandGreen = Color(0xFF12B76A);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF6B7280);
const _pageBackground = Color(0xFFF5F7F6);
const _deepSeekApiKey = String.fromEnvironment('DEEPSEEK_API_KEY');
const _deepSeekBaseUrl = String.fromEnvironment(
  'DEEPSEEK_BASE_URL',
  defaultValue: 'https://api.deepseek.com',
);
const _uuid = Uuid();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalRecordStore.create();
  runApp(VoiceLogApp(store: store));
}

class VoiceLogApp extends StatelessWidget {
  const VoiceLogApp({
    super.key,
    required this.store,
    DeepSeekSplitter? splitter,
  }) : splitter = splitter ?? const DeepSeekSplitter();

  final LocalRecordStore store;
  final DeepSeekSplitter splitter;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceLog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _pageBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brandGreen,
          primary: _brandGreen,
          surface: Colors.white,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: _ink,
          displayColor: _ink,
          fontFamily: 'Roboto',
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: VoiceLogHome(store: store, splitter: splitter),
    );
  }
}

enum RecordCategory {
  done('已完成', Color(0xFF12B76A), Icons.check_circle_outline),
  progress('进行中', Color(0xFF1E88E5), Icons.radio_button_unchecked),
  issue('问题', Color(0xFFF97316), Icons.error_outline),
  meeting('会议', Color(0xFF7C3AED), Icons.groups_outlined),
  next('后续计划', Color(0xFFEAB308), Icons.event_note_outlined),
  other('其他', Color(0xFF64748B), Icons.label_outline);

  const RecordCategory(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  static RecordCategory fromLabel(String value) {
    if (value == '下周计划') {
      return RecordCategory.next;
    }
    return RecordCategory.values.firstWhere(
      (category) => category.label == value || category.name == value,
      orElse: () => RecordCategory.other,
    );
  }
}

class WorkRecord {
  const WorkRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.progress,
    required this.recordDate,
    required this.sourceText,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final RecordCategory category;
  final int progress;
  final DateTime recordDate;
  final String sourceText;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkRecord copyWith({
    String? title,
    RecordCategory? category,
    int? progress,
    DateTime? recordDate,
    String? sourceText,
  }) {
    return WorkRecord(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      progress: progress ?? this.progress,
      recordDate: recordDate ?? this.recordDate,
      sourceText: sourceText ?? this.sourceText,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory WorkRecord.create({
    required String title,
    required RecordCategory category,
    required int progress,
    required DateTime recordDate,
    required String sourceText,
  }) {
    final now = DateTime.now();
    return WorkRecord(
      id: _uuid.v4(),
      title: title,
      category: category,
      progress: progress.clamp(0, 100),
      recordDate: DateUtils.dateOnly(recordDate),
      sourceText: sourceText,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category.label,
      'progress': progress,
      'recordDate': recordDate.toIso8601String(),
      'sourceText': sourceText,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory WorkRecord.fromJson(Map<String, dynamic> json) {
    return WorkRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      category: RecordCategory.fromLabel(json['category'] as String? ?? ''),
      progress: (json['progress'] as num? ?? 0).round().clamp(0, 100),
      recordDate: DateTime.parse(json['recordDate'] as String),
      sourceText: json['sourceText'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class DailyTodo {
  const DailyTodo({
    required this.id,
    required this.title,
    required this.scheduledAt,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime scheduledAt;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyTodo copyWith({String? title, DateTime? scheduledAt, bool? completed}) {
    return DailyTodo(
      id: id,
      title: title ?? this.title,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      completed: completed ?? this.completed,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory DailyTodo.create({
    required String title,
    required DateTime scheduledAt,
    bool completed = false,
  }) {
    final now = DateTime.now();
    return DailyTodo(
      id: _uuid.v4(),
      title: title,
      scheduledAt: scheduledAt,
      completed: completed,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'scheduledAt': scheduledAt.toIso8601String(),
      'completed': completed,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DailyTodo.fromJson(Map<String, dynamic> json) {
    return DailyTodo(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      completed: json['completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class TodoWindow {
  const TodoWindow({required this.today, required this.tomorrow});

  final List<DailyTodo> today;
  final List<DailyTodo> tomorrow;

  int get totalCount => today.length + tomorrow.length;

  int get doneCount =>
      today.where((todo) => todo.completed).length +
      tomorrow.where((todo) => todo.completed).length;

  bool get isEmpty => today.isEmpty && tomorrow.isEmpty;
}

class SplitDraft {
  SplitDraft({
    required this.title,
    required this.category,
    required this.progress,
  });

  String title;
  RecordCategory category;
  int progress;
}

class ParsedTodoSchedule {
  const ParsedTodoSchedule({
    required this.title,
    required this.scheduledAt,
    required this.hasExplicitDate,
  });

  final String title;
  final DateTime scheduledAt;
  final bool hasExplicitDate;
}

class TodoDateParser {
  const TodoDateParser._();

  static ParsedTodoSchedule parse(
    String text, {
    DateTime? baseDate,
    DateTime? now,
    String? fallbackTitle,
  }) {
    final clock = now ?? DateTime.now();
    final anchorDay = DateUtils.dateOnly(baseDate ?? clock);
    final datePhrase = _parseDatePhrase(text, anchorDay);
    final scheduledDay = datePhrase?.day ?? anchorDay;
    final timePhrase = _parseTimePhrase(text);
    final scheduledAt = DateTime(
      scheduledDay.year,
      scheduledDay.month,
      scheduledDay.day,
      timePhrase?.hour ?? _defaultHour(scheduledDay, clock),
      timePhrase?.minute ?? _defaultMinute(scheduledDay, clock),
    );
    final title = _cleanTitle(text, [
      if (datePhrase != null) datePhrase.range,
      if (timePhrase != null) timePhrase.range,
    ]);

    return ParsedTodoSchedule(
      title: title.isEmpty
          ? (fallbackTitle?.trim().isNotEmpty == true
                ? fallbackTitle!.trim()
                : text.trim())
          : title,
      scheduledAt: scheduledAt,
      hasExplicitDate: datePhrase != null,
    );
  }

  static _DatePhrase? _parseDatePhrase(String text, DateTime anchorDay) {
    final relative = <String, int>{
      '大后天': 3,
      '后天': 2,
      '明天': 1,
      '明日': 1,
      '今天': 0,
      '今日': 0,
    };
    for (final entry in relative.entries) {
      final index = text.indexOf(entry.key);
      if (index >= 0) {
        return _DatePhrase(
          day: anchorDay.add(Duration(days: entry.value)),
          range: _TextRange(index, index + entry.key.length),
        );
      }
    }

    final weekdayMatch = RegExp(
      r'(下下周|下下星期|下下礼拜|下个周|下个星期|下个礼拜|下周|下星期|下礼拜|本周|这周|这个周|这星期|这个星期|这礼拜|这个礼拜|周|星期|礼拜)([一二三四五六日天1234567])',
    ).firstMatch(text);
    if (weekdayMatch != null) {
      final prefix = weekdayMatch.group(1)!;
      final weekday = _weekdayFromText(weekdayMatch.group(2)!);
      if (weekday != null) {
        final startOfWeek = anchorDay.subtract(
          Duration(days: anchorDay.weekday - DateTime.monday),
        );
        var candidate = startOfWeek.add(Duration(days: weekday - 1));
        if (prefix.startsWith('下下')) {
          candidate = candidate.add(const Duration(days: 14));
        } else if (prefix.startsWith('下')) {
          candidate = candidate.add(const Duration(days: 7));
        } else if (!prefix.startsWith('本') &&
            !prefix.startsWith('这') &&
            candidate.isBefore(anchorDay)) {
          candidate = candidate.add(const Duration(days: 7));
        }
        return _DatePhrase(
          day: candidate,
          range: _TextRange(weekdayMatch.start, weekdayMatch.end),
        );
      }
    }

    final monthDayMatch = RegExp(
      r'(?:(\d{4})年)?(\d{1,2})月(\d{1,2})(?:日|号)?',
    ).firstMatch(text);
    if (monthDayMatch != null) {
      final yearText = monthDayMatch.group(1);
      var year = yearText == null ? anchorDay.year : int.parse(yearText);
      final month = int.parse(monthDayMatch.group(2)!);
      final day = int.parse(monthDayMatch.group(3)!);
      var candidate = DateTime(year, month, day);
      if (yearText == null && candidate.isBefore(anchorDay)) {
        year += 1;
        candidate = DateTime(year, month, day);
      }
      return _DatePhrase(
        day: candidate,
        range: _TextRange(monthDayMatch.start, monthDayMatch.end),
      );
    }

    final dayOnlyMatch = RegExp(r'(\d{1,2})(?:日|号)').firstMatch(text);
    if (dayOnlyMatch != null) {
      final day = int.parse(dayOnlyMatch.group(1)!);
      var candidate = DateTime(anchorDay.year, anchorDay.month, day);
      if (candidate.isBefore(anchorDay)) {
        candidate = DateTime(anchorDay.year, anchorDay.month + 1, day);
      }
      return _DatePhrase(
        day: candidate,
        range: _TextRange(dayOnlyMatch.start, dayOnlyMatch.end),
      );
    }

    return null;
  }

  static _TimePhrase? _parseTimePhrase(String text) {
    final clockMatch = RegExp(r'(\d{1,2})[:：](\d{1,2})').firstMatch(text);
    if (clockMatch != null) {
      return _TimePhrase(
        hour: int.parse(clockMatch.group(1)!).clamp(0, 23),
        minute: int.parse(clockMatch.group(2)!).clamp(0, 59),
        range: _TextRange(clockMatch.start, clockMatch.end),
      );
    }

    final timeMatch = RegExp(
      r'(凌晨|早上|上午|中午|下午|晚上|傍晚)?\s*(\d{1,2})(?:点|时)(半|[:：](\d{1,2})|(\d{1,2})分?)?',
    ).firstMatch(text);
    if (timeMatch == null) return null;

    final period = timeMatch.group(1) ?? '';
    var hour = int.parse(timeMatch.group(2)!);
    final minute = timeMatch.group(3) == '半'
        ? 30
        : int.parse(
            timeMatch.group(4) ?? timeMatch.group(5) ?? '0',
          ).clamp(0, 59);
    if ((period == '下午' || period == '晚上' || period == '傍晚') && hour < 12) {
      hour += 12;
    } else if (period == '中午' && hour < 11) {
      hour += 12;
    } else if (period == '凌晨' && hour == 12) {
      hour = 0;
    }

    return _TimePhrase(
      hour: hour.clamp(0, 23),
      minute: minute,
      range: _TextRange(timeMatch.start, timeMatch.end),
    );
  }

  static int? _weekdayFromText(String value) {
    return switch (value) {
      '一' || '1' => DateTime.monday,
      '二' || '2' => DateTime.tuesday,
      '三' || '3' => DateTime.wednesday,
      '四' || '4' => DateTime.thursday,
      '五' || '5' => DateTime.friday,
      '六' || '6' => DateTime.saturday,
      '日' || '天' || '7' => DateTime.sunday,
      _ => null,
    };
  }

  static String _cleanTitle(String text, List<_TextRange> ranges) {
    var cleaned = text.trim();
    final sorted = ranges.toList()..sort((a, b) => b.start.compareTo(a.start));
    for (final range in sorted) {
      cleaned = cleaned.replaceRange(range.start, range.end, '');
    }
    cleaned = cleaned
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[，,。；;、\s]+|[，,。；;、\s]+$'), '')
        .replaceFirst(RegExp(r'^(在|到|于)\s*'), '')
        .trim();
    return cleaned;
  }

  static int _defaultHour(DateTime scheduledDay, DateTime clock) {
    return 6;
  }

  static int _defaultMinute(DateTime scheduledDay, DateTime clock) {
    return 0;
  }
}

class _DatePhrase {
  const _DatePhrase({required this.day, required this.range});

  final DateTime day;
  final _TextRange range;
}

class _TimePhrase {
  const _TimePhrase({
    required this.hour,
    required this.minute,
    required this.range,
  });

  final int hour;
  final int minute;
  final _TextRange range;
}

class _TextRange {
  const _TextRange(this.start, this.end);

  final int start;
  final int end;
}

class VoiceRecognitionResult {
  const VoiceRecognitionResult({required this.text, required this.isFinal});

  final String text;
  final bool isFinal;
}

class VoiceRecognitionError {
  const VoiceRecognitionError({
    required this.code,
    required this.message,
    required this.permanent,
  });

  final String code;
  final String message;
  final bool permanent;
}

class VoiceRecognitionService {
  VoiceRecognitionService() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const _channel = MethodChannel('com.voicelog.voicelog/speech');

  final _results = StreamController<VoiceRecognitionResult>.broadcast();
  final _statuses = StreamController<String>.broadcast();
  final _errors = StreamController<VoiceRecognitionError>.broadcast();

  Stream<VoiceRecognitionResult> get results => _results.stream;
  Stream<String> get statuses => _statuses.stream;
  Stream<VoiceRecognitionError> get errors => _errors.stream;

  Future<bool> isAvailable() async {
    return await _channel.invokeMethod<bool>('isAvailable') ?? false;
  }

  Future<void> startListening() async {
    await _channel.invokeMethod<void>('startListening');
  }

  Future<void> stopListening() async {
    await _channel.invokeMethod<void>('stopListening');
  }

  Future<void> cancelListening() async {
    await _channel.invokeMethod<void>('cancelListening');
  }

  Future<void> openSpeechServiceSettings() async {
    await _channel.invokeMethod<void>('openSpeechServiceSettings');
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    final args = (call.arguments as Map?)?.cast<String, Object?>();
    switch (call.method) {
      case 'onSpeechStatus':
        final status = args?['status'] as String? ?? '';
        if (status.isNotEmpty) {
          _statuses.add(status);
        }
        break;
      case 'onSpeechResult':
        _results.add(
          VoiceRecognitionResult(
            text: args?['text'] as String? ?? '',
            isFinal: args?['isFinal'] as bool? ?? false,
          ),
        );
        break;
      case 'onSpeechError':
        _errors.add(
          VoiceRecognitionError(
            code: args?['code'] as String? ?? 'unknown',
            message: args?['message'] as String? ?? '语音识别失败',
            permanent: args?['permanent'] as bool? ?? false,
          ),
        );
        break;
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _results.close();
    _statuses.close();
    _errors.close();
  }
}

class LocalRecordStore extends ChangeNotifier {
  LocalRecordStore._(this._prefs, this._records, this._todos);

  static const _storageKey = 'voicelog.records.v1';
  static const _todoStorageKey = 'voicelog.todos.v1';

  final SharedPreferences? _prefs;
  final List<WorkRecord> _records;
  final List<DailyTodo> _todos;

  static Future<LocalRecordStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final records = raw == null || raw.isEmpty
        ? _seedRecords()
        : (jsonDecode(raw) as List<dynamic>)
              .map((item) => WorkRecord.fromJson(item as Map<String, dynamic>))
              .toList();
    final todoRaw = prefs.getString(_todoStorageKey);
    final todos = todoRaw == null || todoRaw.isEmpty
        ? _seedTodos()
        : (jsonDecode(todoRaw) as List<dynamic>)
              .map((item) => DailyTodo.fromJson(item as Map<String, dynamic>))
              .where((todo) => todo.title.trim().isNotEmpty)
              .toList();
    return LocalRecordStore._(prefs, records, todos);
  }

  factory LocalRecordStore.inMemory([
    List<WorkRecord>? records,
    List<DailyTodo>? todos,
  ]) {
    return LocalRecordStore._(
      null,
      records ?? _seedRecords(),
      todos ?? _seedTodos(),
    );
  }

  List<WorkRecord> get records {
    final copy = List<WorkRecord>.from(_records);
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  List<WorkRecord> forDay(DateTime day) {
    final target = DateUtils.dateOnly(day);
    return records
        .where((record) => DateUtils.isSameDay(record.recordDate, target))
        .toList();
  }

  List<DailyTodo> todosForDay(DateTime day) {
    final target = DateUtils.dateOnly(day);
    final copy = _todos
        .where((todo) => DateUtils.isSameDay(todo.scheduledAt, target))
        .toList();
    _sortTodos(copy);
    return copy;
  }

  Future<TodoWindow> todosForTodayAndTomorrow() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    await _rollOverIncompleteTodos(today);

    final todayTodos = _todos
        .where(
          (todo) =>
              !todo.completed && DateUtils.isSameDay(todo.scheduledAt, today),
        )
        .toList();
    final tomorrowTodos = _todos
        .where(
          (todo) =>
              !todo.completed &&
              DateUtils.isSameDay(todo.scheduledAt, tomorrow),
        )
        .toList();
    _sortTodos(todayTodos);
    _sortTodos(tomorrowTodos);
    return TodoWindow(today: todayTodos, tomorrow: tomorrowTodos);
  }

  List<WorkRecord> forThisWeek() {
    final now = DateTime.now();
    final start = DateUtils.dateOnly(
      now.subtract(Duration(days: now.weekday - 1)),
    );
    final end = start.add(const Duration(days: 7));
    return records
        .where(
          (record) =>
              !record.recordDate.isBefore(start) &&
              record.recordDate.isBefore(end),
        )
        .toList();
  }

  Future<void> addAll(List<WorkRecord> records) async {
    _records.addAll(records);
    await _persist();
  }

  Future<void> add(WorkRecord record) async {
    _records.add(record);
    await _persist();
  }

  Future<void> clear() async {
    _records.clear();
    await _persist();
  }

  Future<void> addTodo(DailyTodo todo) async {
    _todos.add(todo);
    notifyListeners();
    await _persistTodos();
  }

  Future<void> updateTodoCompleted(String id, bool completed) async {
    final index = _todos.indexWhere((todo) => todo.id == id);
    if (index == -1) return;
    _todos[index] = _todos[index].copyWith(completed: completed);
    notifyListeners();
    await _persistTodos();
  }

  Future<void> _persist() async {
    await _prefs?.setString(
      _storageKey,
      jsonEncode(_records.map((record) => record.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> _persistTodos() async {
    await _prefs?.setString(
      _todoStorageKey,
      jsonEncode(_todos.map((todo) => todo.toJson()).toList()),
    );
  }

  Future<void> _rollOverIncompleteTodos(DateTime today) async {
    var changed = false;
    for (var index = 0; index < _todos.length; index += 1) {
      final todo = _todos[index];
      final scheduledDay = DateUtils.dateOnly(todo.scheduledAt);
      if (todo.completed || !scheduledDay.isBefore(today)) {
        continue;
      }
      _todos[index] = todo.copyWith(
        scheduledAt: DateTime(
          today.year,
          today.month,
          today.day,
          todo.scheduledAt.hour,
          todo.scheduledAt.minute,
        ),
      );
      changed = true;
    }
    if (!changed) return;
    await _persistTodos();
  }

  void _sortTodos(List<DailyTodo> todos) {
    todos.sort((a, b) {
      final timeCompare = a.scheduledAt.compareTo(b.scheduledAt);
      if (timeCompare != 0) return timeCompare;
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  static List<WorkRecord> _seedRecords() {
    final now = DateTime.now();
    return [
      WorkRecord.create(
        title: '完成安全风险主题数据核验达到70%',
        category: RecordCategory.progress,
        progress: 70,
        recordDate: now,
        sourceText: '示例记录',
      ),
      WorkRecord.create(
        title: '明天准备核对人资数据主体',
        category: RecordCategory.next,
        progress: 0,
        recordDate: now,
        sourceText: '示例记录',
      ),
      WorkRecord.create(
        title: '信息部会议',
        category: RecordCategory.meeting,
        progress: 0,
        recordDate: now,
        sourceText: '示例记录',
      ),
    ];
  }

  static List<DailyTodo> _seedTodos() {
    final now = DateTime.now();
    DateTime at(int hour, int minute) {
      return DateTime(now.year, now.month, now.day, hour, minute);
    }

    return [
      DailyTodo.create(title: '核对人资数据主体', scheduledAt: at(9, 30)),
      DailyTodo.create(title: '整理安全风险主题进度', scheduledAt: at(14, 0)),
      DailyTodo.create(title: '信息部会议纪要补充', scheduledAt: at(16, 30)),
    ];
  }
}

class DeepSeekSplitter {
  const DeepSeekSplitter({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<List<SplitDraft>> split(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return [];
    }
    if (_deepSeekApiKey.isEmpty) {
      return _heuristicSplit(trimmed);
    }

    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('$_deepSeekBaseUrl/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_deepSeekApiKey',
            },
            body: jsonEncode({
              'model': 'deepseek-v4-flash',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      '你是工作记录拆分助手。只输出JSON，格式为{"items":[{"title":"...","category":"已完成|进行中|问题|会议|后续计划|其他","progress":0}]}。不要解释。',
                },
                {'role': 'user', 'content': trimmed},
              ],
              'thinking': {'type': 'disabled'},
              'response_format': {'type': 'json_object'},
              'temperature': 0.2,
              'max_tokens': 1000,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _heuristicSplit(trimmed);
      }
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final message = decoded['choices']?[0]?['message']?['content'] as String?;
      if (message == null || message.trim().isEmpty) {
        return _heuristicSplit(trimmed);
      }
      return _parseDrafts(message);
    } on Object {
      return _heuristicSplit(trimmed);
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  List<SplitDraft> _parseDrafts(String content) {
    final cleaned = content
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*```$', multiLine: true), '')
        .trim();
    final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
    final items = decoded['items'] as List<dynamic>? ?? [];
    return items
        .map((item) {
          final map = item as Map<String, dynamic>;
          return SplitDraft(
            title: (map['title'] as String? ?? '').trim(),
            category: RecordCategory.fromLabel(
              map['category'] as String? ?? '',
            ),
            progress: (map['progress'] as num? ?? 0).round().clamp(0, 100),
          );
        })
        .where((draft) => draft.title.isNotEmpty)
        .toList();
  }

  List<SplitDraft> _heuristicSplit(String text) {
    final chunks = text
        .split(RegExp(r'[，,。；;\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final source = chunks.isEmpty ? [text] : chunks;
    return source.map((chunk) {
      final percent = RegExp(r'(\d{1,3})\s*%').firstMatch(chunk);
      final progress = percent == null
          ? 0
          : int.parse(percent.group(1)!).clamp(0, 100);
      return SplitDraft(
        title: chunk,
        category: _guessCategory(chunk, progress),
        progress: progress,
      );
    }).toList();
  }

  RecordCategory _guessCategory(String text, int progress) {
    if (text.contains('会议') || text.contains('会')) {
      return RecordCategory.meeting;
    }
    if (text.contains('问题') || text.contains('风险') || text.contains('阻塞')) {
      return RecordCategory.issue;
    }
    if (text.contains('明天') || text.contains('下周') || text.contains('准备')) {
      return RecordCategory.next;
    }
    if (progress > 0 && progress < 100) {
      return RecordCategory.progress;
    }
    if (text.contains('完成') || progress >= 100) {
      return RecordCategory.done;
    }
    return RecordCategory.other;
  }
}

class VoiceLogHome extends StatefulWidget {
  const VoiceLogHome({super.key, required this.store, required this.splitter});

  final LocalRecordStore store;
  final DeepSeekSplitter splitter;

  @override
  State<VoiceLogHome> createState() => _VoiceLogHomeState();
}

class _VoiceLogHomeState extends State<VoiceLogHome> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      RecordPage(store: widget.store, splitter: widget.splitter),
      OverviewPage(store: widget.store),
      ReportPage(store: widget.store),
      ProfilePage(store: widget.store),
    ];

    return Scaffold(
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _tabIndex,
        indicatorColor: _brandGreen.withValues(alpha: 0.12),
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: '记录',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '总览',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '周报',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

class RecordPage extends StatefulWidget {
  const RecordPage({super.key, required this.store, required this.splitter});

  final LocalRecordStore store;
  final DeepSeekSplitter splitter;

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  late final VoiceRecognitionService _voice;
  late final StreamSubscription<VoiceRecognitionResult> _voiceResultSub;
  late final StreamSubscription<String> _voiceStatusSub;
  late final StreamSubscription<VoiceRecognitionError> _voiceErrorSub;
  final DateTime _recordDate = DateUtils.dateOnly(DateTime.now());
  RecordCategory? _filter;
  bool _isRecording = false;
  bool _isSplitting = false;
  bool _isConsumingVoiceText = false;
  bool _isVoicePressActive = false;
  bool _isStartingVoice = false;
  bool _isStoppingVoice = false;
  String _recognizedText = '';
  String _speechStatus = '';
  TodoWindow _todoWindow = const TodoWindow(today: [], tomorrow: []);
  bool _isTodoWindowLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTodoWindow(showLoading: true));
    _voice = VoiceRecognitionService();
    _voiceResultSub = _voice.results.listen(_handleVoiceResult);
    _voiceStatusSub = _voice.statuses.listen(_handleVoiceStatus);
    _voiceErrorSub = _voice.errors.listen(_handleVoiceError);
  }

  @override
  void dispose() {
    unawaited(_voice.cancelListening());
    unawaited(_voiceResultSub.cancel());
    unawaited(_voiceStatusSub.cancel());
    unawaited(_voiceErrorSub.cancel());
    _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todayRecords = widget.store.forDay(DateTime.now());
    final filtered = _filter == null
        ? todayRecords
        : todayRecords.where((record) => record.category == _filter).toList();

    return SafeArea(
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 170),
                sliver: SliverList.list(
                  children: [
                    _TodayTodoTable(
                      todoWindow: _todoWindow,
                      isLoading: _isTodoWindowLoading,
                      onCompletedChanged: _updateTodoCompleted,
                      onDismissCompleted: () => unawaited(_loadTodoWindow()),
                      onAdd: _showAddTodoDialog,
                    ),
                    _CategoryChips(
                      selected: _filter,
                      onSelected: (category) => setState(() {
                        _filter = _filter == category ? null : category;
                      }),
                    ),
                    const SizedBox(height: 24),
                    _TodayRecords(records: filtered),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: _VoiceDock(
              isRecording: _isRecording,
              isBusy: _isSplitting,
              statusText: _speechStatus,
              onPressStart: _startVoiceHold,
              onPressEnd: _stopVoiceHold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTodoDialog() async {
    final result = await showDialog<DailyTodo>(
      context: context,
      builder: (context) => _AddTodoDialog(initialDate: DateTime.now()),
    );
    if (result == null) return;
    await widget.store.addTodo(result);
    await _loadTodoWindow();
  }

  Future<void> _updateTodoCompleted(String id, bool completed) async {
    await widget.store.updateTodoCompleted(id, completed);
    if (completed) return;
    await _loadTodoWindow();
  }

  Future<void> _loadTodoWindow({bool showLoading = false}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() => _isTodoWindowLoading = true);
    }
    final todoWindow = await widget.store.todosForTodayAndTomorrow();
    if (!mounted) return;
    setState(() {
      _todoWindow = todoWindow;
      _isTodoWindowLoading = false;
    });
  }

  Future<void> _saveRecognizedText(String text) async {
    if (text.isEmpty) return;

    setState(() => _isSplitting = true);
    final drafts = await widget.splitter.split(text);
    if (!mounted) return;
    setState(() => _isSplitting = false);
    await _showSplitSheet(text, drafts);
  }

  Future<void> _startVoiceHold() async {
    if (_isRecording || _isSplitting || _isStartingVoice) {
      return;
    }
    _isVoicePressActive = true;

    try {
      _isStartingVoice = true;
      final available = await _voice.isAvailable();
      if (!available) {
        _isStartingVoice = false;
        _isVoicePressActive = false;
        _showVoiceMessage('没有检测到系统语音识别服务。你的小米 13 若仍显示已安装小爱识别服务，请重启系统语音服务后再试。');
        return;
      }

      setState(() {
        _isRecording = true;
        _speechStatus = '正在听你说...';
        _recognizedText = '';
      });
      await _voice.startListening();
      _isStartingVoice = false;
      if (!_isVoicePressActive) {
        await _stopVoiceHold();
      }
    } on PlatformException catch (error) {
      _isStartingVoice = false;
      _isVoicePressActive = false;
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _speechStatus = '';
      });
      if (error.code == 'service_permission_denied') {
        _showSpeechServicePermissionMessage(
          error.message ?? '小爱语音引擎没有麦克风权限。请在系统设置中打开“小爱语音引擎”的麦克风权限后重试。',
        );
        return;
      }
      _showVoiceMessage(
        '语音启动失败（${error.code}）：${error.message ?? '系统识别服务没有响应'}。可重试一次，若持续失败再接入云端 ASR 兜底。',
      );
    }
  }

  Future<void> _stopVoiceHold() async {
    if (!_isVoicePressActive && !_isStartingVoice && !_isRecording) {
      return;
    }
    _isVoicePressActive = false;
    if (_isStartingVoice) {
      return;
    }
    await _stopVoiceAndUseText();
  }

  Future<void> _stopVoiceAndUseText() async {
    if (_isStoppingVoice) {
      return;
    }
    _isStoppingVoice = true;
    await _voice.stopListening();
    if (mounted) {
      setState(() => _speechStatus = '正在整理...');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _isRecording = false;
    });
    if (_recognizedText.trim().isEmpty) {
      _isStoppingVoice = false;
      _isConsumingVoiceText = false;
      setState(() => _speechStatus = '');
      _showVoiceMessage('没有识别到内容，请按住后再说一遍。');
      return;
    }
    await _consumeRecognizedText();
  }

  void _handleVoiceResult(VoiceRecognitionResult result) {
    if (!mounted || result.text.trim().isEmpty) return;
    setState(() {
      _recognizedText = result.text.trim();
      _speechStatus = result.isFinal ? '识别完成' : '识别中';
    });
    if (result.isFinal && !_isVoicePressActive && !_isStoppingVoice) {
      unawaited(_consumeRecognizedText(stopListening: true));
    }
  }

  Future<void> _consumeRecognizedText({bool stopListening = false}) async {
    if (_isConsumingVoiceText) return;
    final text = _recognizedText.trim();
    if (text.isEmpty) {
      _isStoppingVoice = false;
      if (mounted) {
        setState(() => _speechStatus = '');
      }
      return;
    }
    _isConsumingVoiceText = true;
    _recognizedText = '';
    if (!mounted) return;
    if (stopListening && _isRecording) {
      await _voice.stopListening();
    }
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _speechStatus = '正在拆分...';
    });
    await _saveRecognizedText(text);
    if (!mounted) return;
    setState(() {
      _speechStatus = '';
      _isConsumingVoiceText = false;
    });
    _isStoppingVoice = false;
  }

  void _handleVoiceStatus(String status) {
    if (!mounted) return;
    setState(() {
      switch (status) {
        case 'listening':
          _isRecording = true;
          _speechStatus = '正在听你说...';
          break;
        case 'processing':
          _speechStatus = '正在整理...';
          break;
        case 'done':
          _isRecording = false;
          _speechStatus = _recognizedText.trim().isEmpty ? '' : '识别完成';
          break;
        case 'unavailable':
          _isRecording = false;
          _speechStatus = '';
          break;
      }
    });
  }

  void _handleVoiceError(VoiceRecognitionError error) {
    if (!mounted) return;
    if (_shouldIgnoreVoiceError(error)) {
      unawaited(_consumeRecognizedText());
      return;
    }
    setState(() {
      _isRecording = false;
      _speechStatus = '';
    });
    _isVoicePressActive = false;
    _isStartingVoice = false;
    _isStoppingVoice = false;
    _isConsumingVoiceText = false;
    final hint = error.permanent
        ? '系统语音服务已被调用但返回失败，可重试或后续接入云端 ASR。'
        : '识别被中断，请再试一次。';
    if (error.code == 'ERROR_INSUFFICIENT_PERMISSIONS' &&
        error.message.contains('小爱语音引擎')) {
      _showSpeechServicePermissionMessage(
        '小爱语音引擎没有麦克风权限。请在系统设置中打开“小爱语音引擎”的麦克风权限后重试。',
      );
      return;
    }
    _showVoiceMessage('语音识别失败（${error.code}）：${error.message}。$hint');
  }

  bool _shouldIgnoreVoiceError(VoiceRecognitionError error) {
    final hasUsableText = _recognizedText.trim().isNotEmpty;
    final isDisconnectNoise =
        error.code == 'ERROR_SERVER_DISCONNECTED' || error.code == 'ERROR_11';
    return isDisconnectNoise && (hasUsableText || _isConsumingVoiceText);
  }

  void _showSpeechServicePermissionMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '去设置',
          onPressed: () => unawaited(_voice.openSpeechServiceSettings()),
        ),
      ),
    );
  }

  void _showVoiceMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showSplitSheet(String source, List<SplitDraft> drafts) async {
    final result = await showModalBottomSheet<List<SplitDraft>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartSplitSheet(
        sourceText: source,
        initialDrafts: drafts.isEmpty
            ? [
                SplitDraft(
                  title: source,
                  category: RecordCategory.other,
                  progress: 0,
                ),
              ]
            : drafts,
      ),
    );
    if (result == null || result.isEmpty) return;
    final cleanDrafts = result
        .where((draft) => draft.title.trim().isNotEmpty)
        .toList();
    if (cleanDrafts.isEmpty) return;

    await widget.store.addAll(
      cleanDrafts.map((draft) {
        return WorkRecord.create(
          title: draft.title.trim(),
          category: draft.category,
          progress: draft.progress,
          recordDate: _recordDate,
          sourceText: source,
        );
      }).toList(),
    );
    for (final draft in cleanDrafts) {
      final todoSchedule = _scheduleTodoFromDraft(draft.title, source);
      await widget.store.addTodo(
        DailyTodo.create(
          title: todoSchedule.title,
          scheduledAt: todoSchedule.scheduledAt,
        ),
      );
    }
    await _loadTodoWindow();
  }

  ParsedTodoSchedule _scheduleTodoFromDraft(String draftTitle, String source) {
    final draftSchedule = TodoDateParser.parse(
      draftTitle,
      baseDate: _recordDate,
    );
    if (draftSchedule.hasExplicitDate) {
      return draftSchedule;
    }

    final sourceSchedule = TodoDateParser.parse(
      source,
      baseDate: _recordDate,
      fallbackTitle: draftSchedule.title,
    );
    if (!sourceSchedule.hasExplicitDate) {
      return draftSchedule;
    }
    return ParsedTodoSchedule(
      title: draftSchedule.title,
      scheduledAt: sourceSchedule.scheduledAt,
      hasExplicitDate: true,
    );
  }
}

// ignore: unused_element
class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VoiceLog',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '每天记一记，周五一键生成周报',
                style: TextStyle(
                  color: _muted,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(Icons.mic_none, color: _muted),
                SizedBox(width: 12),
                Icon(Icons.radio_button_checked, color: _ink),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayTodoTable extends StatelessWidget {
  const _TodayTodoTable({
    required this.todoWindow,
    required this.isLoading,
    required this.onCompletedChanged,
    required this.onDismissCompleted,
    required this.onAdd,
  });

  final TodoWindow todoWindow;
  final bool isLoading;
  final Future<void> Function(String id, bool completed) onCompletedChanged;
  final VoidCallback onDismissCompleted;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '待办',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '${todoWindow.totalCount}',
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  tooltip: '添加待办',
                  style: IconButton.styleFrom(
                    backgroundColor: _brandGreen.withValues(alpha: 0.1),
                    foregroundColor: _brandGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _TodoHeaderRow(),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                ),
              )
            else if (todoWindow.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Center(
                  child: Text(
                    '今天和明天还没有待办。',
                    style: TextStyle(color: _muted, fontSize: 15),
                  ),
                ),
              )
            else ...[
              if (todoWindow.today.isNotEmpty)
                _TodoDaySection(
                  label: '今天',
                  todos: todoWindow.today,
                  onCompletedChanged: onCompletedChanged,
                  onDismissCompleted: onDismissCompleted,
                ),
              if (todoWindow.tomorrow.isNotEmpty)
                _TodoDaySection(
                  label: '明天',
                  todos: todoWindow.tomorrow,
                  onCompletedChanged: onCompletedChanged,
                  onDismissCompleted: onDismissCompleted,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodoDaySection extends StatelessWidget {
  const _TodoDaySection({
    required this.label,
    required this.todos,
    required this.onCompletedChanged,
    required this.onDismissCompleted,
  });

  final String label;
  final List<DailyTodo> todos;
  final Future<void> Function(String id, bool completed) onCompletedChanged;
  final VoidCallback onDismissCompleted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _brandGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          ...todos.map((todo) {
            return _TodoTableRow(
              key: ValueKey(todo.id),
              todo: todo,
              dismissOnComplete: true,
              onChanged: (value) => onCompletedChanged(todo.id, value ?? false),
              onDismissCompleted: onDismissCompleted,
            );
          }),
        ],
      ),
    );
  }
}

class _TodoHeaderRow extends StatelessWidget {
  const _TodoHeaderRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '时间',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              '待办事项',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            width: 58,
            child: Center(
              child: Text(
                '完成',
                style: TextStyle(color: _muted, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoTableRow extends StatefulWidget {
  const _TodoTableRow({
    super.key,
    required this.todo,
    required this.onChanged,
    this.dismissOnComplete = false,
    this.onDismissCompleted,
  });

  final DailyTodo todo;
  final bool dismissOnComplete;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onDismissCompleted;

  @override
  State<_TodoTableRow> createState() => _TodoTableRowState();
}

class _TodoTableRowState extends State<_TodoTableRow> {
  static const _dismissDuration = Duration(milliseconds: 260);

  late bool _checked;
  bool _isDismissing = false;
  bool _didSubmitDismiss = false;

  @override
  void initState() {
    super.initState();
    _checked = widget.todo.completed;
  }

  @override
  void didUpdateWidget(covariant _TodoTableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todo.completed != widget.todo.completed) {
      _checked = widget.todo.completed;
    }
    if (oldWidget.todo.id != widget.todo.id) {
      _isDismissing = false;
      _didSubmitDismiss = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: _checked ? _muted : _ink,
      fontSize: 15,
      fontWeight: FontWeight.w800,
      decoration: _checked ? TextDecoration.lineThrough : null,
    );
    final row = DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F2F4))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 0, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              child: Text(
                DateFormat('HH:mm').format(widget.todo.scheduledAt),
                style: const TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(child: Text(widget.todo.title, style: titleStyle)),
            SizedBox(
              width: 58,
              child: Checkbox(
                value: _checked,
                onChanged: _isDismissing ? null : _handleChanged,
                activeColor: _brandGreen,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      duration: _dismissDuration,
      curve: Curves.easeInOut,
      tween: Tween<double>(begin: 1, end: _isDismissing ? 0 : 1),
      onEnd: () {
        if (_isDismissing && !_didSubmitDismiss) {
          _didSubmitDismiss = true;
          widget.onDismissCompleted?.call();
        }
      },
      builder: (context, value, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: value,
            child: Opacity(opacity: value, child: child),
          ),
        );
      },
      child: row,
    );
  }

  void _handleChanged(bool? value) {
    final next = value ?? false;
    setState(() {
      _checked = next;
      _isDismissing = widget.dismissOnComplete && next;
      if (!_isDismissing) {
        _didSubmitDismiss = false;
      }
    });

    widget.onChanged(next);
  }
}

class _AddTodoDialog extends StatefulWidget {
  const _AddTodoDialog({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_AddTodoDialog> createState() => _AddTodoDialogState();
}

class _AddTodoDialogState extends State<_AddTodoDialog> {
  final _controller = TextEditingController();
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    _time = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加待办'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: '待办事项',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule_rounded),
              label: Text('时间 ${_time.format(context)}'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(backgroundColor: _brandGreen),
          child: const Text('添加'),
        ),
      ],
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    final base = DateUtils.dateOnly(widget.initialDate);
    final scheduledAt = DateTime(
      base.year,
      base.month,
      base.day,
      _time.hour,
      _time.minute,
    );
    Navigator.of(
      context,
    ).pop(DailyTodo.create(title: title, scheduledAt: scheduledAt));
  }
}

// ignore: unused_element
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.records});

  final List<WorkRecord> records;

  @override
  Widget build(BuildContext context) {
    final doneCount = records
        .where((record) => record.category == RecordCategory.done)
        .length;
    final completion = records.isEmpty
        ? 0
        : ((doneCount / records.length) * 100).round();
    final last = records.isEmpty
        ? '--:--'
        : DateFormat('HH:mm').format(records.first.createdAt);
    final friday = _nextFriday();
    final daysLeft = friday
        .difference(DateUtils.dateOnly(DateTime.now()))
        .inDays
        .clamp(0, 7);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 340;
            return Flex(
              direction: compact ? Axis.vertical : Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Metric(
                  icon: Icons.assignment_turned_in,
                  label: '本周已记录',
                  value: '${records.length}',
                  suffix: '条',
                ),
                if (!compact) _DividerLine(),
                _Metric(icon: Icons.schedule, label: '上次记录', value: last),
                if (!compact) _DividerLine(),
                Expanded(
                  flex: compact ? 0 : 1,
                  child: Padding(
                    padding: EdgeInsets.only(top: compact ? 16 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '距周报生成（周五）',
                          style: TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$daysLeft',
                                style: const TextStyle(
                                  color: _brandGreen,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const TextSpan(
                                text: ' 天',
                                style: TextStyle(
                                  color: _brandGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: completion / 100,
                            color: _brandGreen,
                            backgroundColor: const Color(0xFFE5E7EB),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '完成 $completion% · 还差 ${20 - records.length > 0 ? 20 - records.length : 0} 条',
                          style: const TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  DateTime _nextFriday() {
    final today = DateUtils.dateOnly(DateTime.now());
    final offset = (DateTime.friday - today.weekday) % 7;
    return today.add(Duration(days: offset == 0 ? 0 : offset));
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.suffix = '',
  });

  final IconData icon;
  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: _brandGreen.withValues(alpha: 0.1),
            foregroundColor: _brandGreen,
            child: Icon(icon),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                TextSpan(
                  text: suffix,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _brandGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 74,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFFE5E7EB),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final RecordCategory? selected;
  final ValueChanged<RecordCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: RecordCategory.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = RecordCategory.values[index];
          final active = selected == category;
          return ChoiceChip(
            selected: active,
            onSelected: (_) => onSelected(category),
            showCheckmark: false,
            avatar: Icon(category.icon, color: category.color, size: 20),
            label: Text(category.label),
            labelStyle: TextStyle(
              color: active ? category.color : _muted,
              fontWeight: FontWeight.w800,
            ),
            backgroundColor: Colors.white,
            selectedColor: category.color.withValues(alpha: 0.1),
            side: BorderSide(color: active ? category.color : Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );
        },
      ),
    );
  }
}

class _TodayRecords extends StatelessWidget {
  const _TodayRecords({required this.records});

  final List<WorkRecord> records;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    '今天已记录',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '查看全部',
                  style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (records.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 42),
                child: Center(
                  child: Text(
                    '今天还没有记录，写一句就开始积累。',
                    style: TextStyle(color: _muted, fontSize: 16),
                  ),
                ),
              )
            else
              ...records.asMap().entries.map((entry) {
                final record = entry.value;
                return _RecordTile(
                  record: record,
                  index: records.length - entry.key,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.index});

  final WorkRecord record;
  final int index;

  @override
  Widget build(BuildContext context) {
    final category = record.category;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: category.color,
            foregroundColor: Colors.white,
            child: Text(
              '$index',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(record.createdAt),
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _Tag(category: category, progress: record.progress),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.category, required this.progress});

  final RecordCategory category;
  final int progress;

  @override
  Widget build(BuildContext context) {
    final label = category == RecordCategory.progress && progress > 0
        ? '${category.label} $progress%'
        : category.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: category.color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _VoiceDock extends StatelessWidget {
  const _VoiceDock({
    required this.isRecording,
    required this.isBusy,
    required this.statusText,
    required this.onPressStart,
    required this.onPressEnd,
  });

  final bool isRecording;
  final bool isBusy;
  final String statusText;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (statusText.isNotEmpty) ...[
          Text(
            statusText,
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
        ],
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: isBusy ? null : (_) => onPressStart(),
          onPointerUp: isBusy ? null : (_) => onPressEnd(),
          onPointerCancel: isBusy ? null : (_) => onPressEnd(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: isRecording ? 310 : 76,
            height: 76,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: _brandGreen.withValues(
                    alpha: isRecording ? 0.2 : 0.12,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isRecording) const _WaveBars(),
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isBusy ? _muted : _brandGreen,
                    foregroundColor: Colors.white,
                    child: isBusy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.mic_none_rounded, size: 34),
                  ),
                  if (isRecording) const _WaveBars(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WaveBars extends StatelessWidget {
  const _WaveBars();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        return Container(
          width: 5,
          height: 14 + (index.isEven ? 16 : 28),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: _brandGreen.withValues(alpha: 0.2 + index * 0.16),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}

class SmartSplitSheet extends StatefulWidget {
  const SmartSplitSheet({
    super.key,
    required this.sourceText,
    required this.initialDrafts,
  });

  final String sourceText;
  final List<SplitDraft> initialDrafts;

  @override
  State<SmartSplitSheet> createState() => _SmartSplitSheetState();
}

class _SmartSplitSheetState extends State<SmartSplitSheet> {
  late final List<SplitDraft> _drafts;

  @override
  void initState() {
    super.initState();
    _drafts = widget.initialDrafts
        .map(
          (draft) => SplitDraft(
            title: draft.title,
            category: draft.category,
            progress: draft.progress,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.54,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '智能拆分记录',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                '保存到 今天',
                                style: TextStyle(
                                  color: _muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          widget.sourceText,
                          style: const TextStyle(
                            color: Color(0xFF4B5563),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ..._drafts.asMap().entries.map(
                      (entry) => _DraftEditor(
                        key: ValueKey('${entry.key}-${entry.value.title}'),
                        index: entry.key + 1,
                        draft: entry.value,
                        onDelete: () =>
                            setState(() => _drafts.removeAt(entry.key)),
                        onChanged: () => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20 + MediaQuery.of(context).padding.bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '取消',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton(
                        onPressed: _drafts.isEmpty
                            ? null
                            : () => Navigator.pop(context, _drafts),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: _brandGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '确认保存',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DraftEditor extends StatelessWidget {
  const _DraftEditor({
    super.key,
    required this.index,
    required this.draft,
    required this.onDelete,
    required this.onChanged,
  });

  final int index;
  final SplitDraft draft;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: const Color(0xFFFCFCFD),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: _brandGreen,
                  foregroundColor: Colors.white,
                  child: Text(
                    '$index',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<RecordCategory>(
                  value: draft.category,
                  borderRadius: BorderRadius.circular(8),
                  underline: const SizedBox.shrink(),
                  items: RecordCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: _Tag(category: category, progress: draft.progress),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    draft.category = value;
                    onChanged();
                  },
                ),
                const Spacer(),
                TextButton(
                  onPressed: onDelete,
                  child: const Text(
                    '删除',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: draft.title,
              minLines: 2,
              maxLines: 3,
              onChanged: (value) => draft.title = value.trim(),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.store});

  final LocalRecordStore store;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  late DateTime _selectedDay;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _selectedDay = today;
    _visibleMonth = DateTime(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final selectedTodos = widget.store.todosForDay(_selectedDay);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
            children: [
              const Text(
                '任务总览',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                '点击日历中的某一天，查看这一天有什么任务待办',
                style: TextStyle(color: _muted, fontSize: 16),
              ),
              const SizedBox(height: 20),
              _TaskCalendar(
                visibleMonth: _visibleMonth,
                selectedDay: _selectedDay,
                todoCountForDay: (day) => widget.store.todosForDay(day).length,
                onPreviousMonth: () => setState(() {
                  _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month - 1,
                  );
                }),
                onNextMonth: () => setState(() {
                  _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month + 1,
                  );
                }),
                onDaySelected: (day) => setState(() {
                  _selectedDay = DateUtils.dateOnly(day);
                  _visibleMonth = DateTime(day.year, day.month);
                }),
              ),
              const SizedBox(height: 16),
              _SelectedDayTodoCard(
                selectedDay: _selectedDay,
                todos: selectedTodos,
                onCompletedChanged: (id, completed) async {
                  await widget.store.updateTodoCompleted(id, completed);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskCalendar extends StatelessWidget {
  const _TaskCalendar({
    required this.visibleMonth,
    required this.selectedDay,
    required this.todoCountForDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDaySelected,
  });

  final DateTime visibleMonth;
  final DateTime selectedDay;
  final int Function(DateTime day) todoCountForDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final days = _calendarDaysForMonth(visibleMonth);
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '上个月',
                  onPressed: onPreviousMonth,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    DateFormat('yyyy年M月').format(visibleMonth),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '下个月',
                  onPressed: onNextMonth,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: weekdays
                  .map(
                    (weekday) => Expanded(
                      child: Center(
                        child: Text(
                          weekday,
                          style: const TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 6,
              ),
              itemBuilder: (context, index) {
                final day = days[index];
                return _CalendarDayCell(
                  day: day,
                  isInVisibleMonth: day.month == visibleMonth.month,
                  isToday: DateUtils.isSameDay(day, DateTime.now()),
                  isSelected: DateUtils.isSameDay(day, selectedDay),
                  todoCount: todoCountForDay(day),
                  onTap: () => onDaySelected(day),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<DateTime> _calendarDaysForMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month);
    final startDay = firstDay.subtract(Duration(days: firstDay.weekday - 1));
    return List.generate(42, (index) => startDay.add(Duration(days: index)));
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isInVisibleMonth,
    required this.isToday,
    required this.isSelected,
    required this.todoCount,
    required this.onTap,
  });

  final DateTime day;
  final bool isInVisibleMonth;
  final bool isToday;
  final bool isSelected;
  final int todoCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isSelected
        ? Colors.white
        : isInVisibleMonth
        ? _ink
        : _muted.withValues(alpha: 0.48);
    final borderColor = isToday && !isSelected
        ? _brandGreen
        : Colors.transparent;

    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${DateFormat('yyyy年M月d日').format(day)}${todoCount > 0 ? '，$todoCount 个待办' : '，没有待办'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: isSelected ? _brandGreen : Colors.transparent,
            border: Border.all(color: borderColor, width: 1.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w900
                      : FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: todoCount > 0 ? 18 : 4,
                height: 4,
                decoration: BoxDecoration(
                  color: todoCount > 0
                      ? (isSelected ? Colors.white : _brandGreen)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedDayTodoCard extends StatelessWidget {
  const _SelectedDayTodoCard({
    required this.selectedDay,
    required this.todos,
    required this.onCompletedChanged,
  });

  final DateTime selectedDay;
  final List<DailyTodo> todos;
  final Future<void> Function(String id, bool completed) onCompletedChanged;

  @override
  Widget build(BuildContext context) {
    final doneCount = todos.where((todo) => todo.completed).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('M月d日 EEEE').format(selectedDay),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '$doneCount/${todos.length}',
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _TodoHeaderRow(),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            if (todos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Center(
                  child: Text(
                    '这一天还没有待办。',
                    style: TextStyle(color: _muted, fontSize: 15),
                  ),
                ),
              )
            else
              ...todos.map(
                (todo) => _TodoTableRow(
                  key: ValueKey(todo.id),
                  todo: todo,
                  onChanged: (value) =>
                      onCompletedChanged(todo.id, value ?? false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ReportPage extends StatelessWidget {
  const ReportPage({super.key, required this.store});

  final LocalRecordStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final records = store.forThisWeek();
        final report = _buildReport(records);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
            children: [
              const Text(
                '周报',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                '由本周记录自动整理，可复制后继续润色',
                style: TextStyle(color: _muted, fontSize: 16),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: SelectableText(
                    report,
                    style: const TextStyle(fontSize: 16, height: 1.65),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildReport(List<WorkRecord> records) {
    if (records.isEmpty) {
      return '本周暂无记录。\n\n建议每天用语音记录 3-5 条工作进展，周五再生成周报草稿。';
    }
    String section(String title, RecordCategory category) {
      final items = records
          .where((record) => record.category == category)
          .toList();
      if (items.isEmpty) return '$title\n- 暂无\n';
      return '$title\n${items.map((record) => '- ${record.title}').join('\n')}\n';
    }

    return [
      section('一、本周完成', RecordCategory.done),
      section('二、进行中事项', RecordCategory.progress),
      section('三、问题与风险', RecordCategory.issue),
      section('四、会议纪要', RecordCategory.meeting),
      section('五、后续计划', RecordCategory.next),
    ].join('\n');
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.store});

  final LocalRecordStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
            children: [
              const Text(
                '我的',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.storage_outlined,
                        title: '本地记录',
                        detail: '${store.records.length} 条',
                      ),
                      const Divider(height: 28),
                      _SettingsRow(
                        icon: Icons.psychology_alt_outlined,
                        title: '智能模型',
                        detail: _deepSeekApiKey.isEmpty
                            ? '未配置，使用本地拆分'
                            : 'DeepSeek V4 Flash',
                      ),
                      const Divider(height: 28),
                      const _SettingsRow(
                        icon: Icons.verified_outlined,
                        title: '版本',
                        detail: 'MVP 0.1.0',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _brandGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        Text(
          detail,
          style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(color: _muted, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
