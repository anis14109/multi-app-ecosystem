import 'package:flutter_app/app/app.dart';
import 'package:flutter_app/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
