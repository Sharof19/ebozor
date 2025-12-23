import 'package:ebozor/src/app/app.dart';
import 'package:ebozor/src/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const EbozorApp());
}
