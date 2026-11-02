import 'core/config/app_flavor.dart';
import 'main.dart';

/// Entrypoint for Production Flavor
/// Run with: flutter run -t lib/main_prod.dart --flavor prod --release
/// Build bundle: flutter build appbundle -t lib/main_prod.dart --flavor prod --release --obfuscate --split-debug-info=build/app/outputs/symbols
Future<void> main() async {
  await bootstrapApp(AppFlavor.prod);
}
