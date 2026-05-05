import '../../domain/domain.dart';

/// Abstract repository contracts — implementations can swap Hive for a remote API.

abstract class UserRepository {
  Future<List<AppUser>> getAll();
  Future<AppUser?> getById(String id);
  Future<void> save(AppUser user);
  Future<void> delete(String id);
  Future<void> saveAll(List<AppUser> users);
}

abstract class PropertyRepository {
  Future<List<Property>> getAll();
  Future<Property?> getById(String id);
  Future<void> save(Property property);
  Future<void> delete(String id);
  Future<void> saveAll(List<Property> properties);
}

abstract class ColumnRepository {
  Future<List<BoardColumn>> getByProperty(String propertyId);
  Future<BoardColumn?> getById(String id);
  Future<void> save(BoardColumn column);
  Future<void> delete(String id);
  Future<void> saveAll(List<BoardColumn> columns);
  Future<void> deleteByProperty(String propertyId);
}

abstract class CardRepository {
  Future<List<BoardCard>> getByColumn(String columnId);
  Future<List<BoardCard>> getByProperty(String propertyId);
  Future<BoardCard?> getById(String id);
  Future<void> save(BoardCard card);
  Future<void> delete(String id);
  Future<void> saveAll(List<BoardCard> cards);
  Future<void> deleteByColumn(String columnId);
  Future<void> deleteByProperty(String propertyId);
}

abstract class ArchiveRepository {
  Future<List<ArchivedCard>> getAll();
  Future<List<ArchivedCard>> getByProperty(String propertyId);
  Future<void> save(ArchivedCard card);
  Future<void> delete(String id);
  Future<void> clear();
}

abstract class CommentRepository {
  Future<List<Comment>> getByCard(String cardId);
  Future<void> save(Comment comment);
  Future<void> delete(String id);
  Future<void> deleteByCard(String cardId);
}

abstract class ActivityRepository {
  Future<List<ActivityEvent>> getByCard(String cardId);
  Future<void> save(ActivityEvent event);
  Future<void> deleteByCard(String cardId);
}

abstract class FieldRepository {
  Future<List<FieldDef>> getAll();
  Future<void> saveAll(List<FieldDef> fields);
}

abstract class SettingsRepository {
  Future<String?> getCurrentUserId();
  Future<void> setCurrentUserId(String id);
  Future<int> getSeedVersion();
  Future<void> setSeedVersion(int version);
}
