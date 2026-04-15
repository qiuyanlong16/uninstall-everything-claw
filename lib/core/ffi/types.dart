import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

typedef ScanAllAppsNative = Pointer<Utf8> Function();
typedef ScanAllAppsDart = Pointer<Utf8> Function();

typedef UninstallAppsNative = Pointer<Utf8> Function(
    Pointer<Utf8> appIdsJson, Pointer<NativeFunction<ProgressCallback>> cb);
typedef UninstallAppsDart = Pointer<Utf8> Function(
    Pointer<Utf8> appIdsJson, Pointer<NativeFunction<ProgressCallback>> cb);

typedef CheckForUpdatesNative = Pointer<Utf8> Function(Pointer<Utf8> version);
typedef CheckForUpdatesDart = Pointer<Utf8> Function(Pointer<Utf8> version);

typedef FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef FreeStringDart = void Function(Pointer<Utf8> ptr);

typedef ProgressCallback = Void Function(Pointer<Utf8> statusJson);

class NativeLibrary {
  late final DynamicLibrary _lib;

  NativeLibrary() {
    final libName = Platform.isWindows
        ? 'claw_sweeper_core.dll'
        : Platform.isMacOS
            ? 'libclaw_sweeper_core.dylib'
            : 'libclaw_sweeper_core.so';

    try {
      _lib = DynamicLibrary.open(libName);
    } catch (e) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      _lib = DynamicLibrary.open(p.join(exeDir, libName));
    }
  }

  Pointer<Utf8> scanAllApps() {
    final func = _lib.lookupFunction<ScanAllAppsNative, ScanAllAppsDart>(
        'scan_all_apps');
    return func();
  }

  Pointer<Utf8> uninstallApps(
      Pointer<Utf8> appIdsJson,
      Pointer<NativeFunction<ProgressCallback>> callback) {
    final func = _lib.lookupFunction<UninstallAppsNative, UninstallAppsDart>(
        'uninstall_apps');
    return func(appIdsJson, callback);
  }

  Pointer<Utf8> checkForUpdates(Pointer<Utf8> version) {
    final func = _lib.lookupFunction<CheckForUpdatesNative, CheckForUpdatesDart>(
        'check_for_updates');
    return func(version);
  }

  void freeString(Pointer<Utf8> ptr) {
    final func = _lib.lookupFunction<FreeStringNative, FreeStringDart>(
        'free_string');
    func(ptr);
  }
}
