import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Runs before every test file. Blocking google_fonts' runtime fetching
/// keeps tests hermetic and golden rendering deterministic: text falls
/// back to the FlutterTest font, which is metrically stable across
/// platforms, so goldens verify layout and color rather than typography
/// rasterization.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
