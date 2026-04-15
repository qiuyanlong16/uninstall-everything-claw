import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/update_info.dart';

class Updater {
  final String owner;
  final String repo;
  final String currentVersion;

  Updater({
    required this.owner,
    required this.repo,
    required this.currentVersion,
  });

  Future<UpdateInfo> checkForUpdates() async {
    final url = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/releases/latest');
    final response = await http.get(url, headers: {
      'Accept': 'application/vnd.github+json',
    });

    if (response.statusCode != 200) {
      throw Exception('Failed to check updates: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final latestVersion = (data['tag_name'] as String).replaceAll('v', '');
    final downloadUrl = (data['assets'] as List<dynamic>?)
            ?.firstWhere(
              (e) => true,
              orElse: () => null,
            )?['browser_download_url'] as String? ??
        '';
    final releaseNotes = data['body'] as String? ?? '';

    final hasUpdate = _compareVersions(latestVersion, currentVersion) > 0;

    return UpdateInfo(
      hasUpdate: hasUpdate,
      latestVersion: latestVersion,
      downloadUrl: downloadUrl,
      releaseNotes: releaseNotes,
      isCritical: false,
    );
  }

  int _compareVersions(String a, String b) {
    final partsA = a.split('.').map(int.tryParse).toList();
    final partsB = b.split('.').map(int.tryParse).toList();
    for (int i = 0; i < 3; i++) {
      final va = partsA.length > i ? partsA[i] : 0;
      final vb = partsB.length > i ? partsB[i] : 0;
      if (va != vb) return (va! > vb!) ? 1 : -1;
    }
    return 0;
  }
}
