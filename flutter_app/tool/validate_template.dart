// Template v3 structural validator CLI (master-roadmap §3 "Per-wave review
// gate" / content-convert §Verification). Runs the EXACT same checks the
// responsive Template Editor enforces on Save — both call the Flutter-free
// `validateTemplateCategories` in
// `lib/domain/services/template_migration/template_validator.dart`, so a JIT
// wave PR that edits `assets/templates/dnd5e_srd.template.json` by hand
// dogfoods the editor's validator (roadmap §3 "JIT dogfoods the editor's
// validator").
//
// Run from the Flutter project root (`flutter_app/`):
//
//     dart run tool/validate_template.dart                # the in-memory built-in v3 template
//     dart run tool/validate_template.dart <path.json>    # a template JSON asset on disk
//     dart run tool/validate_template.dart --asset        # the bundled built-in asset on disk
//
// With no path it validates `generateBuiltinDnd5eTemplateV3()` directly, so it
// is useful even before PR-1.3 exports the asset. With a path it parses the
// file via `WorldSchema.fromJson` and validates the parsed categories — the
// same shape the editor and runtime loader consume.
//
// Exit code 0 = well-formed (no blocking errors); 1 = validation errors; 2 =
// usage / IO / parse error. This is a dev/CI script only; it is NOT part of the
// app build.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_template_v3.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/domain/services/template_migration/template_validator.dart';

void main(List<String> args) {
  final WorldSchema schema;
  final String label;

  if (args.isEmpty) {
    // Validate the generator output directly (works before the asset is
    // exported in PR-1.3).
    schema = generateBuiltinDnd5eTemplateV3();
    label = 'built-in v3 template (generateBuiltinDnd5eTemplateV3)';
  } else if (args.length == 1) {
    final path = args.first == '--asset' ? builtinDnd5eTemplateAssetPath : args.first;
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('ABORT: template file not found: $path');
      exitCode = 2;
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      stderr.writeln('ABORT: $path is not valid JSON — $e');
      exitCode = 2;
      return;
    }
    if (decoded is! Map<String, dynamic>) {
      stderr.writeln('ABORT: $path does not contain a JSON object.');
      exitCode = 2;
      return;
    }
    try {
      schema = WorldSchema.fromJson(decoded);
    } catch (e) {
      stderr.writeln('ABORT: $path is not a parseable Template v3 schema — $e');
      exitCode = 2;
      return;
    }
    label = path;
  } else {
    stderr.writeln(
      'Usage: dart run tool/validate_template.dart [<template.json> | --asset]',
    );
    exitCode = 2;
    return;
  }

  final errors = validateTemplateCategories(schema.categories);
  final categories = schema.categories.length;
  final fields =
      schema.categories.fold<int>(0, (sum, c) => sum + c.fields.length);

  print('Validating: $label');
  print('  formatVersion : ${schema.formatVersion}');
  print('  categories    : $categories');
  print('  fields        : $fields');

  if (errors.isEmpty) {
    print('OK — no blocking validation errors.');
    exitCode = 0;
    return;
  }

  stderr.writeln('FAILED — ${errors.length} blocking error(s):');
  for (final e in errors) {
    stderr.writeln('  • $e');
  }
  exitCode = 1;
}
