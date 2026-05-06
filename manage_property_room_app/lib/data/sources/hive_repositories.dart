import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/domain.dart';
import '../repositories/repositories.dart';

// ─────────────────────────────────────────
//  Box names (constants)
// ─────────────────────────────────────────

const _kUsers = 'pmr_users';
const _kProperties = 'pmr_properties';
const _kColumns = 'pmr_columns';
const _kCards = 'pmr_cards';
const _kArchive = 'pmr_archive';
const _kComments = 'pmr_comments';
const _kActivity = 'pmr_activity';
const _kFields = 'pmr_fields';
const _kSettings = 'pmr_settings';

// ─────────────────────────────────────────
//  Initializer — call once in main/bootstrap
// ─────────────────────────────────────────

Future<void> openHiveBoxes() async {
  await Hive.openBox<String>(_kUsers);
  await Hive.openBox<String>(_kProperties);
  await Hive.openBox<String>(_kColumns);
  await Hive.openBox<String>(_kCards);
  await Hive.openBox<String>(_kArchive);
  await Hive.openBox<String>(_kComments);
  await Hive.openBox<String>(_kActivity);
  await Hive.openBox<String>(_kFields);
  await Hive.openBox<String>(_kSettings);
}

// ─────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────

T _decode<T>(String raw, T Function(Map<String, dynamic>) fromJson) {
  return fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
}

String _encode(Map<String, dynamic> json) => jsonEncode(json);

// ─────────────────────────────────────────
//  UserRepository (Hive)
// ─────────────────────────────────────────

class HiveUserRepository implements UserRepository {
  Box<String> get _box => Hive.box<String>(_kUsers);

  @override
  Future<List<AppUser>> getAll() async =>
      _box.values.map((v) => _decode(v, AppUser.fromJson)).toList();

  @override
  Future<AppUser?> getById(String id) async {
    final raw = _box.get(id);
    return raw == null ? null : _decode(raw, AppUser.fromJson);
  }

  @override
  Future<void> save(AppUser user) async =>
      _box.put(user.id, _encode(user.toJson()));

  @override
  Future<void> delete(String id) async => _box.delete(id);

  @override
  Future<void> saveAll(List<AppUser> users) async {
    await _box.putAll({for (final u in users) u.id: _encode(u.toJson())});
  }
}

// ─────────────────────────────────────────
//  PropertyRepository (Hive)
// ─────────────────────────────────────────

class HivePropertyRepository implements PropertyRepository {
  Box<String> get _box => Hive.box<String>(_kProperties);

  @override
  Future<List<Property>> getAll() async =>
      _box.values.map((v) => _decode(v, Property.fromJson)).toList();

  @override
  Future<Property?> getById(String id) async {
    final raw = _box.get(id);
    return raw == null ? null : _decode(raw, Property.fromJson);
  }

  @override
  Future<void> save(Property property) async =>
      _box.put(property.id, _encode(property.toJson()));

  @override
  Future<void> delete(String id) async => _box.delete(id);

  @override
  Future<void> saveAll(List<Property> properties) async {
    await _box.putAll({for (final p in properties) p.id: _encode(p.toJson())});
  }
}

// ─────────────────────────────────────────
//  ColumnRepository (Hive)
// ─────────────────────────────────────────

class HiveColumnRepository implements ColumnRepository {
  Box<String> get _box => Hive.box<String>(_kColumns);

  @override
  Future<List<BoardColumn>> getByProperty(String propertyId) async => _box.values
      .map((v) => _decode(v, BoardColumn.fromJson))
      .where((c) => c.propertyId == propertyId)
      .toList()
    ..sort((a, b) => a.position.compareTo(b.position));

  @override
  Future<BoardColumn?> getById(String id) async {
    final raw = _box.get(id);
    return raw == null ? null : _decode(raw, BoardColumn.fromJson);
  }

  @override
  Future<void> save(BoardColumn column) async =>
      _box.put(column.id, _encode(column.toJson()));

  @override
  Future<void> delete(String id) async => _box.delete(id);

  @override
  Future<void> saveAll(List<BoardColumn> columns) async {
    await _box.putAll({for (final c in columns) c.id: _encode(c.toJson())});
  }

  @override
  Future<void> deleteByProperty(String propertyId) async {
    final keys = _box.keys.where((k) {
      final raw = _box.get(k as String);
      if (raw == null) return false;
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return m['propertyId'] == propertyId;
    }).toList();
    await _box.deleteAll(keys);
  }
}

// ─────────────────────────────────────────
//  CardRepository (Hive)
// ─────────────────────────────────────────

class HiveCardRepository implements CardRepository {
  Box<String> get _box => Hive.box<String>(_kCards);

  @override
  Future<List<BoardCard>> getByColumn(String columnId) async => _box.values
      .map((v) => _decode(v, BoardCard.fromJson))
      .where((c) => c.columnId == columnId)
      .toList()
    ..sort((a, b) => a.position.compareTo(b.position));

  @override
  Future<List<BoardCard>> getByProperty(String propertyId) async => _box.values
      .map((v) => _decode(v, BoardCard.fromJson))
      .where((c) => c.propertyId == propertyId)
      .toList();

  @override
  Future<BoardCard?> getById(String id) async {
    final raw = _box.get(id);
    return raw == null ? null : _decode(raw, BoardCard.fromJson);
  }

  @override
  Future<void> save(BoardCard card) async =>
      _box.put(card.id, _encode(card.toJson()));

  @override
  Future<void> delete(String id) async => _box.delete(id);

  @override
  Future<void> saveAll(List<BoardCard> cards) async {
    await _box.putAll({for (final c in cards) c.id: _encode(c.toJson())});
  }

  @override
  Future<void> deleteByColumn(String columnId) async {
    final keys = _box.keys.where((k) {
      final raw = _box.get(k as String);
      if (raw == null) return false;
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return m['columnId'] == columnId;
    }).toList();
    await _box.deleteAll(keys);
  }

  @override
  Future<void> deleteByProperty(String propertyId) async {
    final keys = _box.keys.where((k) {
      final raw = _box.get(k as String);
      if (raw == null) return false;
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return m['propertyId'] == propertyId;
    }).toList();
    await _box.deleteAll(keys);
  }
}

// ─────────────────────────────────────────
//  ArchiveRepository (Hive)
// ─────────────────────────────────────────

class HiveArchiveRepository implements ArchiveRepository {
  Box<String> get _box => Hive.box<String>(_kArchive);

  @override
  Future<List<ArchivedCard>> getAll() async =>
      _box.values.map((v) => _decode(v, ArchivedCard.fromJson)).toList()
        ..sort((a, b) => b.archivedAt.compareTo(a.archivedAt));

  @override
  Future<List<ArchivedCard>> getByProperty(String propertyId) async =>
      (await getAll()).where((c) => c.propertyId == propertyId).toList();

  @override
  Future<void> save(ArchivedCard card) async =>
      _box.put(card.id, _encode(card.toJson()));

  @override
  Future<void> delete(String id) async => _box.delete(id);

  @override
  Future<void> clear() async => _box.clear();
}

// ─────────────────────────────────────────
//  CommentRepository (Hive)
// ─────────────────────────────────────────

class HiveCommentRepository implements CommentRepository {
  Box<String> get _box => Hive.box<String>(_kComments);

  @override
  Future<List<Comment>> getByCard(String cardId) async => _box.values
      .map((v) => _decode(v, Comment.fromJson))
      .where((c) => c.cardId == cardId)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<void> save(Comment comment) async =>
      _box.put(comment.id, _encode(comment.toJson()));

  @override
  Future<void> delete(String id) async => _box.delete(id);

  @override
  Future<void> deleteByCard(String cardId) async {
    final keys = _box.keys.where((k) {
      final raw = _box.get(k as String);
      if (raw == null) return false;
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return m['cardId'] == cardId;
    }).toList();
    await _box.deleteAll(keys);
  }
}

// ─────────────────────────────────────────
//  ActivityRepository (Hive)
// ─────────────────────────────────────────

class HiveActivityRepository implements ActivityRepository {
  Box<String> get _box => Hive.box<String>(_kActivity);

  @override
  Future<List<ActivityEvent>> getByCard(String cardId) async => _box.values
      .map((v) => _decode(v, ActivityEvent.fromJson))
      .where((e) => e.cardId == cardId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> save(ActivityEvent event) async =>
      _box.put(event.id, _encode(event.toJson()));

  @override
  Future<void> deleteByCard(String cardId) async {
    final keys = _box.keys.where((k) {
      final raw = _box.get(k as String);
      if (raw == null) return false;
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return m['cardId'] == cardId;
    }).toList();
    await _box.deleteAll(keys);
  }
}

// ─────────────────────────────────────────
//  FieldRepository (Hive)
// ─────────────────────────────────────────

class HiveFieldRepository implements FieldRepository {
  Box<String> get _box => Hive.box<String>(_kFields);

  static const _listKey = '__fields__';

  @override
  Future<List<FieldDef>> getAll() async {
    final raw = _box.get(_listKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => FieldDef.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  @override
  Future<void> saveAll(List<FieldDef> fields) async {
    await _box.put(_listKey, jsonEncode(fields.map((f) => f.toJson()).toList()));
  }
}

// ─────────────────────────────────────────
//  SettingsRepository (Hive)
// ─────────────────────────────────────────

class HiveSettingsRepository implements SettingsRepository {
  Box<String> get _box => Hive.box<String>(_kSettings);

  static const _currentUser = 'currentUserId';
  static const _seedVersion = 'seedVersion';
  static const _tokenKey = 'jwt_token';

  @override
  Future<String?> getCurrentUserId() async => _box.get(_currentUser);

  @override
  Future<void> setCurrentUserId(String id) async => _box.put(_currentUser, id);

  @override
  Future<int> getSeedVersion() async {
    final v = _box.get(_seedVersion);
    return v != null ? int.tryParse(v) ?? 0 : 0;
  }

  @override
  Future<void> setSeedVersion(int version) async =>
      _box.put(_seedVersion, version.toString());

  @override
  Future<String?> getToken() async => _box.get(_tokenKey);

  @override
  Future<void> saveToken(String token) async => _box.put(_tokenKey, token);

  @override
  Future<void> clearToken() async => _box.delete(_tokenKey);
}
