import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InternetState {
  const InternetState({required this.status});

  final ConnectivityResult status;

  bool get isConnected => status != ConnectivityResult.none;
}

class InternetChecker extends Cubit<InternetState> {
  InternetChecker({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity(),
        super(const InternetState(status: ConnectivityResult.none)) {
    unawaited(_initialize());
    _subscription =
        _connectivity.onConnectivityChanged.listen(_onStatusChanged);
  }

  final Connectivity _connectivity;
  late final StreamSubscription<dynamic> _subscription;

  Future<void> _initialize() async {
    try {
      final current = await _connectivity.checkConnectivity();
      _onStatusChanged(current);
    } catch (_) {
      emit(const InternetState(status: ConnectivityResult.none));
    }
  }

  void _onStatusChanged(dynamic event) {
    if (event is List<ConnectivityResult>) {
      final status = event.isNotEmpty ? event.first : ConnectivityResult.none;
      emit(InternetState(status: status));
      return;
    }
    if (event is ConnectivityResult) {
      emit(InternetState(status: event));
      return;
    }
    emit(const InternetState(status: ConnectivityResult.none));
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
