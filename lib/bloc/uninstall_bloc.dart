import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../core/ffi/bindings.dart';

sealed class UninstallEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class UninstallRequested extends UninstallEvent {
  final List<String> appIds;
  const UninstallRequested(this.appIds);

  @override
  List<Object?> get props => [appIds];
}

sealed class UninstallState extends Equatable {
  @override
  List<Object?> get props => [];
}

class UninstallInitial extends UninstallState {}

class UninstallProgress extends UninstallState {
  final String appId;
  final String status;
  final String? errorMessage;

  const UninstallProgress({
    required this.appId,
    required this.status,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [appId, status];
}

class UninstallCompleted extends UninstallState {
  final Map<String, bool> results;
  const UninstallCompleted(this.results);

  @override
  List<Object?> get props => [results];
}

class UninstallFailed extends UninstallState {
  final String message;
  const UninstallFailed(this.message);

  @override
  List<Object?> get props => [message];
}

class UninstallBloc extends Bloc<UninstallEvent, UninstallState> {
  UninstallBloc() : super(UninstallInitial()) {
    on<UninstallRequested>(_onUninstallRequested);
  }

  Future<void> _onUninstallRequested(
      UninstallRequested event, Emitter<UninstallState> emit) async {
    try {
      final results = uninstallApps(event.appIds, (progressData) {
        final appId = progressData['app_id'] as String? ?? 'unknown';
        final statusRaw = progressData['status'] ?? progressData.keys.first;
        emit(UninstallProgress(
          appId: appId,
          status: statusRaw.toString().toLowerCase(),
        ));
      });
      emit(UninstallCompleted(results));
    } catch (e) {
      emit(UninstallFailed(e.toString()));
    }
  }
}
