import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../core/ffi/bindings.dart';
import '../models/scanned_app.dart';

sealed class ScannerEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ScanRequested extends ScannerEvent {}

sealed class ScannerState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ScannerInitial extends ScannerState {}

class ScannerLoading extends ScannerState {}

class ScannerLoaded extends ScannerState {
  final List<ScannedApp> apps;
  const ScannerLoaded(this.apps);

  @override
  List<Object?> get props => [apps];
}

class ScannerError extends ScannerState {
  final String message;
  const ScannerError(this.message);

  @override
  List<Object?> get props => [message];
}

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  ScannerBloc() : super(ScannerInitial()) {
    on<ScanRequested>(_onScanRequested);
  }

  Future<void> _onScanRequested(
      ScanRequested event, Emitter<ScannerState> emit) async {
    emit(ScannerLoading());
    try {
      final apps = scanAllApps();
      emit(ScannerLoaded(apps));
    } catch (e) {
      emit(ScannerError(e.toString()));
    }
  }
}
