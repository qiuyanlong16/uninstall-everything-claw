import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import '../../models/scanned_app.dart';
import '../../models/update_info.dart';
import 'types.dart';

final nativeLibrary = NativeLibrary();

List<ScannedApp> scanAllApps() {
  final resultPtr = nativeLibrary.scanAllApps();
  try {
    final jsonStr = resultPtr.toDartString();
    final List<dynamic> data = jsonDecode(jsonStr);
    return data.map((e) => ScannedApp.fromJson(e as Map<String, dynamic>)).toList();
  } finally {
    nativeLibrary.freeString(resultPtr.cast());
  }
}

Map<String, bool> uninstallApps(
    List<String> appIds, void Function(Map<String, dynamic>) onProgress) {
  final callback = NativeCallable<ProgressCallback>.isolateLocal(
    (Pointer<Utf8> statusJsonPtr) {
      try {
        final jsonStr = statusJsonPtr.toDartString();
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        onProgress(data);
      } catch (_) {}
    },
  );

  final idsJson = jsonEncode(appIds);
  final idsJsonPtr = idsJson.toNativeUtf8();

  try {
    final resultPtr = nativeLibrary.uninstallApps(idsJsonPtr, callback.nativeFunction);
    try {
      final jsonStr = resultPtr.toDartString();
      final List<dynamic> data = jsonDecode(jsonStr);
      return {
        for (var item in data)
          (item as List)[0] as String: item[1] as bool
      };
    } finally {
      nativeLibrary.freeString(resultPtr.cast());
    }
  } finally {
    calloc.free(idsJsonPtr);
  }
}

UpdateInfo checkForUpdatesFFI(String currentVersion) {
  final versionPtr = currentVersion.toNativeUtf8();
  try {
    final resultPtr = nativeLibrary.checkForUpdates(versionPtr);
    try {
      final jsonStr = resultPtr.toDartString();
      return UpdateInfo.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } finally {
      nativeLibrary.freeString(resultPtr.cast());
    }
  } finally {
    calloc.free(versionPtr);
  }
}
