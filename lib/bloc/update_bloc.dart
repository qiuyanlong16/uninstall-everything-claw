import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/update_info.dart';
import '../update/updater.dart';

sealed class UpdateEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class CheckUpdateRequested extends UpdateEvent {}

sealed class UpdateState extends Equatable {
  @override
  List<Object?> get props => [];
}

class UpdateInitial extends UpdateState {}

class UpdateChecking extends UpdateState {}

class UpdateChecked extends UpdateState {
  final UpdateInfo info;
  const UpdateChecked(this.info);

  @override
  List<Object?> get props => [info];
}

class UpdateError extends UpdateState {
  final String message;
  const UpdateError(this.message);

  @override
  List<Object?> get props => [message];
}

class UpdateBloc extends Bloc<UpdateEvent, UpdateState> {
  final Updater _updater;

  UpdateBloc(this._updater) : super(UpdateInitial()) {
    on<CheckUpdateRequested>(_onCheckUpdateRequested);
  }

  Future<void> _onCheckUpdateRequested(
      CheckUpdateRequested event, Emitter<UpdateState> emit) async {
    emit(UpdateChecking());
    try {
      final info = await _updater.checkForUpdates();
      emit(UpdateChecked(info));
    } catch (e) {
      emit(UpdateError(e.toString()));
    }
  }
}
