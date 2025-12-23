import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('uz_UZ', null);
  final app = await builder();
  runApp(app);
}
