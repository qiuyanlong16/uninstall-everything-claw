import 'package:equatable/equatable.dart';

class UpdateInfo extends Equatable {
  final bool hasUpdate;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool isCritical;

  const UpdateInfo({
    this.hasUpdate = false,
    this.latestVersion = '',
    this.downloadUrl = '',
    this.releaseNotes = '',
    this.isCritical = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      hasUpdate: json['has_update'] as bool? ?? false,
      latestVersion: json['latest_version'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? '',
      isCritical: json['is_critical'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [hasUpdate, latestVersion];
}
