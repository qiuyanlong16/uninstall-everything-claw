import 'package:equatable/equatable.dart';

enum AppFamily {
  claw,
  hermes,
  other,
}

enum StatusBadge {
  removable,
  needsPrivilege,
  running,
}

class ScannedApp extends Equatable {
  final String id;
  final String name;
  final AppFamily family;
  final String version;
  final int sizeBytes;
  final String installPath;
  final List<String> residuePaths;
  final bool isRunning;
  final int? pid;
  final bool requiresPrivilege;
  final bool autoStart;

  StatusBadge get statusBadge {
    if (isRunning) return StatusBadge.running;
    if (requiresPrivilege) return StatusBadge.needsPrivilege;
    return StatusBadge.removable;
  }

  const ScannedApp({
    required this.id,
    required this.name,
    required this.family,
    required this.version,
    required this.sizeBytes,
    required this.installPath,
    required this.residuePaths,
    this.isRunning = false,
    this.pid,
    this.requiresPrivilege = false,
    this.autoStart = false,
  });

  factory ScannedApp.fromJson(Map<String, dynamic> json) {
    return ScannedApp(
      id: json['id'] as String,
      name: json['name'] as String,
      family: _parseFamily(json['family'] as String?),
      version: json['version'] as String,
      sizeBytes: json['size_bytes'] as int? ?? 0,
      installPath: json['install_path'] as String,
      residuePaths: (json['residue_paths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isRunning: json['is_running'] as bool? ?? false,
      pid: json['pid'] as int?,
      requiresPrivilege: json['requires_privilege'] as bool? ?? false,
      autoStart: json['auto_start'] as bool? ?? false,
    );
  }

  static AppFamily _parseFamily(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'claw':
        return AppFamily.claw;
      case 'hermes':
        return AppFamily.hermes;
      default:
        return AppFamily.other;
    }
  }

  @override
  List<Object?> get props => [id];
}
