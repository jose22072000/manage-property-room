import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/repositories.dart';
import '../../data/sources/hive_repositories.dart';

// ── Repository providers ─────────────────────────────────────────────────

final userRepoProvider = Provider<UserRepository>((_) => HiveUserRepository());

final propertyRepoProvider = Provider<PropertyRepository>((_) => HivePropertyRepository());

final columnRepoProvider = Provider<ColumnRepository>((_) => HiveColumnRepository());

final cardRepoProvider = Provider<CardRepository>((_) => HiveCardRepository());

final archiveRepoProvider = Provider<ArchiveRepository>((_) => HiveArchiveRepository());

final commentRepoProvider = Provider<CommentRepository>((_) => HiveCommentRepository());

final activityRepoProvider = Provider<ActivityRepository>((_) => HiveActivityRepository());

final fieldRepoProvider = Provider<FieldRepository>((_) => HiveFieldRepository());

final settingsRepoProvider = Provider<SettingsRepository>((_) => HiveSettingsRepository());
