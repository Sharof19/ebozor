import 'package:ebozor/src/data/services/eimzo_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum EimzoStatus { initial, loading, success, needsInstallation, failure }

@immutable
class EimzoState {
  const EimzoState({
    this.status = EimzoStatus.initial,
    this.errorMessage,
  });

  final EimzoStatus status;
  final String? errorMessage;

  static const _noChange = Object();

  EimzoState copyWith({
    EimzoStatus? status,
    Object? errorMessage = _noChange,
  }) {
    return EimzoState(
      status: status ?? this.status,
      errorMessage: identical(errorMessage, _noChange)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

@immutable
abstract class EimzoEvent {
  const EimzoEvent();
}

class EimzoFlowStarted extends EimzoEvent {
  const EimzoFlowStarted();
}

class EimzoRetryRequested extends EimzoEvent {
  const EimzoRetryRequested();
}

class EimzoBloc extends Bloc<EimzoEvent, EimzoState> {
  EimzoBloc(this._service) : super(const EimzoState()) {
    on<EimzoFlowStarted>(_onFlowStart);
    on<EimzoRetryRequested>(_onFlowStart);
  }

  final EimzoService _service;

  Future<void> _onFlowStart(
    EimzoEvent event,
    Emitter<EimzoState> emit,
  ) async {
    emit(
      state.copyWith(
        status: EimzoStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final pkcs = await _service.startFlow();
      if (pkcs == null || pkcs.isEmpty) {
        emit(
          state.copyWith(
            status: EimzoStatus.needsInstallation,
            errorMessage:
                'E-IMZO ilovasini o\'rnatish yoki ishga tushirish talab etiladi.',
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: EimzoStatus.success,
            errorMessage: null,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: EimzoStatus.failure,
          errorMessage: _formatException(e),
        ),
      );
    }
  }

  String _formatException(Object error) {
    final raw = error.toString();
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}
