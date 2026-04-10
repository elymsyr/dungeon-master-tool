import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../domain/entities/audio/audio_models.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Python core/audio/loader.py portu.
/// Soundpad YAML config'lerini parse eder, tema/library yönetimi sağlar.
class SoundpadLoader {
  static const _audioExtensions = {'.wav', '.mp3', '.ogg', '.flac', '.m4a'};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// soundpad_library.yaml'ı parse eder → SoundpadLibrary.
  static Future<SoundpadLibrary> loadGlobalLibrary(String soundpadRoot) async {
    final libraryFile = File(p.join(soundpadRoot, 'soundpad_library.yaml'));
    if (!await libraryFile.exists()) return const SoundpadLibrary();

    try {
      final raw = await libraryFile.readAsString();
      final data = loadYaml(raw) as YamlMap?;
      if (data == null) return const SoundpadLibrary();

      final ambience = <AmbienceEntry>[];
      for (final item in (data['ambience'] as YamlList? ?? [])) {
        final map = item as YamlMap;
        final id = map['id'] as String? ?? '';
        final name = map['name'] as String? ?? '';
        final fileFrag = map['file'] as String? ?? '';
        final files = _findAudioFiles(fileFrag, soundpadRoot);
        ambience.add(AmbienceEntry(id: id, name: name, files: files));
      }

      final sfx = <SfxEntry>[];
      for (final item in (data['sfx'] as YamlList? ?? [])) {
        final map = item as YamlMap;
        final id = map['id'] as String? ?? '';
        final name = map['name'] as String? ?? '';
        final fileFrag = map['file'] as String? ?? '';
        final files = _findAudioFiles(fileFrag, soundpadRoot);
        sfx.add(SfxEntry(id: id, name: name, files: files));
      }

      final shortcuts = <String, String>{};
      final rawShortcuts = data['shortcuts'] as YamlMap?;
      if (rawShortcuts != null) {
        for (final entry in rawShortcuts.entries) {
          shortcuts[entry.key.toString()] = entry.value.toString();
        }
      }

      return SoundpadLibrary(ambience: ambience, sfx: sfx, shortcuts: shortcuts);
    } catch (e) {
      _log.e('Error loading global sound library: $e');
      return const SoundpadLibrary();
    }
  }

  /// Tüm theme dizinlerini tarar → Map<themeId, SoundpadTheme>.
  static Future<Map<String, SoundpadTheme>> loadAllThemes(String soundpadRoot) async {
    final themes = <String, SoundpadTheme>{};
    final dir = Directory(soundpadRoot);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      return themes;
    }

    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final yamlPath = p.join(entity.path, 'theme.yaml');
      if (!await File(yamlPath).exists()) continue;
      final theme = await _parseThemeFile(yamlPath, entity.path);
      if (theme != null) themes[theme.id] = theme;
    }
    return themes;
  }

  /// Yeni ses dosyasını imported/ dizinine kopyalar ve library YAML'ını günceller.
  static Future<(bool, String)> addToLibrary(
    String soundpadRoot,
    String category,
    String name,
    String filePath,
  ) async {
    if (category != 'ambience' && category != 'sfx') {
      return (false, 'Invalid category');
    }

    // 1. Dosyayı imported/ dizinine kopyala
    final importedDir = Directory(p.join(soundpadRoot, 'imported'));
    if (!await importedDir.exists()) await importedDir.create(recursive: true);

    var destName = p.basename(filePath);
    var destPath = p.join(importedDir.path, destName);
    var counter = 1;
    while (await File(destPath).exists()) {
      final base = p.basenameWithoutExtension(filePath);
      final ext = p.extension(filePath);
      destPath = p.join(importedDir.path, '${base}_$counter$ext');
      counter++;
    }

    try {
      await File(filePath).copy(destPath);
    } catch (e) {
      return (false, 'File copy failed: $e');
    }

    // 2. YAML güncelle
    final relPath = p.relative(destPath, from: soundpadRoot);
    final newId = '${category}_${DateTime.now().millisecondsSinceEpoch}';
    return _updateLibraryYaml(soundpadRoot, category, {
      'id': newId,
      'name': name,
      'file': relPath,
    });
  }

  /// Ses ID'sini library YAML'ından kaldırır.
  static Future<(bool, String)> removeFromLibrary(
    String soundpadRoot,
    String category,
    String soundId,
  ) async {
    if (category != 'ambience' && category != 'sfx') {
      return (false, 'Invalid category');
    }

    final libraryFile = File(p.join(soundpadRoot, 'soundpad_library.yaml'));
    if (!await libraryFile.exists()) return (false, 'Library file not found');

    try {
      final raw = await libraryFile.readAsString();
      final data = loadYaml(raw) as YamlMap?;
      if (data == null) return (false, 'Empty library');

      // YAML immutable olduğu için Map'e çevirip manipüle ediyoruz
      final mutable = _yamlToMap(data);
      final list = (mutable[category] as List?) ?? [];
      final originalLen = list.length;
      mutable[category] = list.where((item) => item['id'] != soundId).toList();

      if ((mutable[category] as List).length == originalLen) {
        return (false, 'Sound ID not found');
      }

      await _writeLibraryYaml(libraryFile, mutable);
      return (true, 'Sound removed');
    } catch (e) {
      return (false, 'Error: $e');
    }
  }

  /// Yeni tema oluşturur — dizin + theme.yaml + dosyaları kopyalar.
  /// [stateMap]: {'normal': {'base': '/abs/path.wav', 'level1': '...'}, 'combat': {...}}
  static Future<(bool, String)> createTheme(
    String soundpadRoot,
    String name,
    String id,
    Map<String, Map<String, String>> stateMap,
  ) async {
    if (name.isEmpty || id.isEmpty || stateMap.isEmpty) {
      return (false, 'Missing theme info');
    }

    final themeDir = Directory(p.join(soundpadRoot, id));
    if (await themeDir.exists()) return (false, 'Theme ID already exists');

    try {
      await themeDir.create(recursive: true);

      final yamlBuf = StringBuffer();
      yamlBuf.writeln('id: "$id"');
      yamlBuf.writeln('name: "$name"');
      yamlBuf.writeln('states:');

      for (final stateEntry in stateMap.entries) {
        final stateName = stateEntry.key;
        final tracks = stateEntry.value;
        yamlBuf.writeln('  $stateName:');
        yamlBuf.writeln('    tracks:');

        for (final trackEntry in tracks.entries) {
          final trackKey = trackEntry.key;
          final srcPath = trackEntry.value;
          if (srcPath.isEmpty || !await File(srcPath).exists()) continue;

          // Dosyayı tema dizinine kopyala
          final ext = p.extension(srcPath);
          final newFilename = '${stateName}_$trackKey$ext';
          final destPath = p.join(themeDir.path, newFilename);
          await File(srcPath).copy(destPath);

          yamlBuf.writeln('      $trackKey:');
          yamlBuf.writeln('        - file: "$newFilename"');
          yamlBuf.writeln('          repeat: 0');
        }
      }

      await File(p.join(themeDir.path, 'theme.yaml')).writeAsString(yamlBuf.toString());
      return (true, themeDir.path);
    } catch (e) {
      return (false, 'Theme creation failed: $e');
    }
  }

  /// Tema dizinini siler.
  static Future<(bool, String)> deleteTheme(String soundpadRoot, String themeId) async {
    final themeDir = Directory(p.join(soundpadRoot, themeId));
    if (!await themeDir.exists()) return (false, 'Theme not found');
    try {
      await themeDir.delete(recursive: true);
      return (true, 'Theme deleted');
    } catch (e) {
      return (false, 'Delete failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Dosya/dizin yolunu tarayarak ses dosyalarını bulur.
  static List<String> _findAudioFiles(String pathFragment, String soundpadRoot) {
    final fullPath = p.join(soundpadRoot, pathFragment);

    // Dizin ise içindeki ses dosyalarını listele
    if (Directory(fullPath).existsSync()) {
      final found = <String>[];
      for (final file in Directory(fullPath).listSync()) {
        if (file is File && _audioExtensions.contains(p.extension(file.path).toLowerCase())) {
          found.add(file.path);
        }
      }
      return found;
    }

    // Dosya ise (uzantılı veya uzantısız)
    if (p.extension(fullPath).isNotEmpty) {
      if (File(fullPath).existsSync()) return [fullPath];
    } else {
      for (final ext in _audioExtensions) {
        final probe = '$fullPath$ext';
        if (File(probe).existsSync()) return [probe];
      }
    }

    return [];
  }

  /// Tek theme.yaml dosyasını parse eder.
  static Future<SoundpadTheme?> _parseThemeFile(String yamlPath, String baseFolder) async {
    try {
      final raw = await File(yamlPath).readAsString();
      final data = loadYaml(raw) as YamlMap?;
      if (data == null) return null;

      final tId = (data['id'] as String?) ?? p.basename(baseFolder);
      final tName = (data['name'] as String?) ?? tId;

      // Shortcuts
      final shortcuts = <String, String>{};
      final rawShortcuts = data['shortcuts'] as YamlMap?;
      if (rawShortcuts != null) {
        for (final entry in rawShortcuts.entries) {
          shortcuts[entry.key.toString()] = entry.value.toString();
        }
      }

      // States
      final states = <String, MusicState>{};
      final rawStates = data['states'] as YamlMap? ?? YamlMap();
      for (final stateEntry in rawStates.entries) {
        final stateName = stateEntry.key.toString();
        final stateData = stateEntry.value as YamlMap?;
        if (stateData == null) continue;

        final tracks = <String, MusicTrack>{};
        final rawTracks = stateData['tracks'] as YamlMap? ?? YamlMap();
        for (final trackEntry in rawTracks.entries) {
          final trackId = trackEntry.key.toString();
          var trackSeq = trackEntry.value;
          if (trackSeq is! YamlList) trackSeq = YamlList.wrap([trackSeq]);

          final sequence = <LoopNode>[];
          for (final nodeData in trackSeq) {
            final String? filename;
            if (nodeData is String) {
              filename = nodeData;
            } else if (nodeData is YamlMap) {
              filename = nodeData['file'] as String?;
            } else {
              continue;
            }
            if (filename == null) continue;
            final fullPath = p.join(baseFolder, filename);
            sequence.add(LoopNode(filePath: fullPath));
          }

          tracks[trackId] = MusicTrack(name: trackId, sequence: sequence);
        }

        states[stateName] = MusicState(name: stateName, tracks: tracks);
      }

      return SoundpadTheme(
        id: tId,
        name: tName,
        states: states,
        shortcuts: shortcuts,
      );
    } catch (e) {
      _log.e("Error parsing theme file '$yamlPath': $e");
      return null;
    }
  }

  /// Library YAML'ına yeni entry ekler.
  static Future<(bool, String)> _updateLibraryYaml(
    String soundpadRoot,
    String category,
    Map<String, dynamic> newEntry,
  ) async {
    final libraryFile = File(p.join(soundpadRoot, 'soundpad_library.yaml'));
    Map<String, dynamic> data = {'ambience': [], 'sfx': [], 'shortcuts': {}};

    if (await libraryFile.exists()) {
      try {
        final raw = await libraryFile.readAsString();
        final loaded = loadYaml(raw) as YamlMap?;
        if (loaded != null) data = _yamlToMap(loaded);
      } catch (e) {
        _log.e('Error reading library for update: $e');
      }
    }

    (data[category] as List? ?? []).add(newEntry);
    if (data[category] == null) data[category] = [newEntry];

    try {
      await _writeLibraryYaml(libraryFile, data);
      return (true, 'Sound added');
    } catch (e) {
      return (false, 'YAML update failed: $e');
    }
  }

  /// Basit YAML serializer (yaml paketi sadece reader, writer yok).
  static Future<void> _writeLibraryYaml(File file, Map<String, dynamic> data) async {
    final buf = StringBuffer();
    buf.writeln('# assets/soundpad/soundpad_library.yaml');
    buf.writeln();

    for (final section in ['ambience', 'sfx']) {
      buf.writeln('$section:');
      final list = (data[section] as List?) ?? [];
      for (final item in list) {
        final map = item as Map;
        buf.writeln('  - id: "${map['id']}"');
        buf.writeln('    name: "${map['name']}"');
        buf.writeln('    file: "${map['file']}"');
      }
      buf.writeln();
    }

    final shortcuts = data['shortcuts'] as Map?;
    if (shortcuts != null && shortcuts.isNotEmpty) {
      buf.writeln('shortcuts:');
      for (final entry in shortcuts.entries) {
        buf.writeln('  ${entry.key}: "${entry.value}"');
      }
    }

    await file.writeAsString(buf.toString());
  }

  /// YamlMap → mutable Map<String, dynamic> dönüşümü.
  static Map<String, dynamic> _yamlToMap(YamlMap yamlMap) {
    final result = <String, dynamic>{};
    for (final entry in yamlMap.entries) {
      final key = entry.key.toString();
      if (entry.value is YamlMap) {
        result[key] = _yamlToMap(entry.value as YamlMap);
      } else if (entry.value is YamlList) {
        result[key] = _yamlToList(entry.value as YamlList);
      } else {
        result[key] = entry.value;
      }
    }
    return result;
  }

  static List<dynamic> _yamlToList(YamlList yamlList) {
    return yamlList.map((item) {
      if (item is YamlMap) return _yamlToMap(item);
      if (item is YamlList) return _yamlToList(item);
      return item;
    }).toList();
  }
}
