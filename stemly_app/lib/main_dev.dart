import 'core/config/app_flavor.dart';
import 'main.dart';

/// Entrypoint for Development Flavor
/// Run with: flutter run -t lib/main_dev.dart --flavor dev
Future<void> main() async {
  await bootstrapApp(AppFlavor.dev);
}
