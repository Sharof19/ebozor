import 'package:ebozor/src/data/services/didox_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum DidoxStatus { initial, loading, success, failure }

@immutable
class DidoxState {
  const DidoxState({
    this.status = DidoxStatus.initial,
    this.pkcs,
    this.documentId,
    this.errorMessage,
    this.copyMessage,
    this.isCopying = false,
  });

  final DidoxStatus status;
  final String? pkcs;
  final String? documentId;
  final String? errorMessage;
  final String? copyMessage;
  final bool isCopying;

  static const _sentinel = Object();

  DidoxState copyWith({
    DidoxStatus? status,
    Object? pkcs = _sentinel,
    Object? documentId = _sentinel,
    Object? errorMessage = _sentinel,
    Object? copyMessage = _sentinel,
    bool? isCopying,
  }) {
    return DidoxState(
      status: status ?? this.status,
      pkcs: identical(pkcs, _sentinel) ? this.pkcs : pkcs as String?,
      documentId: identical(documentId, _sentinel)
          ? this.documentId
          : documentId as String?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      copyMessage: identical(copyMessage, _sentinel)
          ? this.copyMessage
          : copyMessage as String?,
      isCopying: isCopying ?? this.isCopying,
    );
  }
}

@immutable
abstract class DidoxEvent {
  const DidoxEvent();
}

class DidoxFlowStarted extends DidoxEvent {
  const DidoxFlowStarted({this.stir});
  final String? stir;
}

class DidoxRetryRequested extends DidoxEvent {
  const DidoxRetryRequested({this.stir});
  final String? stir;
}

class DidoxCopyRequested extends DidoxEvent {
  const DidoxCopyRequested();
}

class DidoxBloc extends Bloc<DidoxEvent, DidoxState> {
  DidoxBloc(this._service) : super(const DidoxState()) {
    on<DidoxFlowStarted>(_onFlowStart);
    on<DidoxRetryRequested>(_onFlowStart);
    on<DidoxCopyRequested>(_onCopyRequested);
  }

  final DidoxService _service;

  Future<void> _onFlowStart(
    DidoxEvent event,
    Emitter<DidoxState> emit,
  ) async {
    final stir = _eventStir(event);
    emit(
      state.copyWith(
        status: DidoxStatus.loading,
        pkcs: null,
        documentId: null,
        errorMessage: null,
        copyMessage: null,
      ),
    );
    try {
      final pkcs = await _service.startFlow(stir: stir);
      if (pkcs == null || pkcs.isEmpty) {
        emit(
          state.copyWith(
            status: DidoxStatus.failure,
            errorMessage:
                'E-IMZO ilovasida jarayonni yakunlang va qayta urinib ko\'ring.',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: DidoxStatus.success,
          pkcs: pkcs,
          documentId: _service.documentId,
          errorMessage: null,
          copyMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DidoxStatus.failure,
          errorMessage:
              e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
          copyMessage: null,
        ),
      );
    }
  }

  Future<void> _onCopyRequested(
    DidoxCopyRequested event,
    Emitter<DidoxState> emit,
  ) async {
    emit(
      state.copyWith(
        isCopying: true,
        copyMessage: null,
      ),
    );
    try {
      final pkcs = await _service.getCurrentPkcs();
      await Clipboard.setData(ClipboardData(text: pkcs));
      emit(
        state.copyWith(
          isCopying: false,
          copyMessage: 'PKCS nusxalandi.',
          pkcs: pkcs,
          documentId: _service.documentId,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isCopying: false,
          copyMessage:
              'Nusxalashda xato: ${e.toString().replaceFirst(RegExp(r'^Exception:\\s*'), '')}',
        ),
      );
    }
  }

  String? _eventStir(DidoxEvent event) {
    if (event is DidoxFlowStarted) return event.stir;
    if (event is DidoxRetryRequested) return event.stir;
    return null;
  }
}
