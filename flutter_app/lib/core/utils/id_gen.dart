import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generate a new v4 UUID. Centralized factory so the project has a single
/// entry point for id generation (makes it possible to later inject a seeded
/// generator for deterministic tests without changing call sites).
String newId() => _uuid.v4();
