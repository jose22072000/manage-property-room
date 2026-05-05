import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Saves an image file to the app's documents directory under `cards/<cardId>/`.
/// Returns the relative path stored in [BoardCard.customFields].
Future<String> saveCardImage(String cardId, String sourcePath) async {
  if (kIsWeb) {
    // On web, image_picker returns a blob URL — return as-is
    return sourcePath;
  }
  final docsDir = await getApplicationDocumentsDirectory();
  final cardDir = Directory(p.join(docsDir.path, 'cards', cardId));
  if (!cardDir.existsSync()) cardDir.createSync(recursive: true);

  final ext = p.extension(sourcePath);
  final fileName = '${_uuid.v4()}$ext';
  final dest = p.join(cardDir.path, fileName);
  await File(sourcePath).copy(dest);

  // Return relative path
  return p.join('cards', cardId, fileName);
}

/// Resolves a stored relative path to an absolute File path.
Future<String?> resolveCardImage(String relativePath) async {
  if (kIsWeb) return relativePath;
  if (relativePath.startsWith('/') || relativePath.startsWith('http')) {
    return relativePath;
  }
  final docsDir = await getApplicationDocumentsDirectory();
  final abs = p.join(docsDir.path, relativePath);
  return File(abs).existsSync() ? abs : null;
}

/// Deletes all images associated with a card.
Future<void> deleteCardImages(String cardId) async {
  if (kIsWeb) return;
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    final cardDir = Directory(p.join(docsDir.path, 'cards', cardId));
    if (cardDir.existsSync()) cardDir.deleteSync(recursive: true);
  } catch (_) {}
}
