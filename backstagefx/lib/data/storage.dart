import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SavedState {
  final double masterVolume;
  final bool locked;
  final String? defaultTrackPath;

  const SavedState({
    required this.masterVolume,
    required this.locked,
    this.defaultTrackPath,
  });

  factory SavedState.initial() => const SavedState(masterVolume: 0.8, locked: false);

  factory SavedState.fromJson(Map<String, dynamic> json) {
    return SavedState(
      masterVolume: (json['masterVolume'] as num?)?.toDouble() ?? 0.8,
      locked: json['locked'] as bool? ?? false,
      defaultTrackPath: json['defaultTrackPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'masterVolume': masterVolume,
        'locked': locked,
        'defaultTrackPath': defaultTrackPath,
      };

  SavedState copyWith({
    double? masterVolume,
    bool? locked,
    String? defaultTrackPath,
  }) {
    return SavedState(
      masterVolume: masterVolume ?? this.masterVolume,
      locked: locked ?? this.locked,
      defaultTrackPath: defaultTrackPath ?? this.defaultTrackPath,
    );
  }
}

class StorageService {
  static const String _dirName = 'backstagefx';
  static const String _fileName = 'state.json';

  Future<File> _stateFile() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}$_dirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  Future<SavedState> load() async {
    try {
      final f = await _stateFile();
      if (!await f.exists()) {
        return SavedState.initial();
      }
      final text = await f.readAsString();
      final data = jsonDecode(text) as Map<String, dynamic>;
      return SavedState.fromJson(data);
    } catch (_) {
      return SavedState.initial();
    }
  }

  Future<void> save(SavedState state) async {
    try {
      final f = await _stateFile();
      await f.writeAsString(jsonEncode(state.toJson()), flush: true);
    } catch (_) {
      // ignore write errors in show-time scenarios
    }
  }
}

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());