import 'package:flutter/painting.dart';

/// Radius scale from the approved v3 design.
abstract final class AppRadius {
  static const xs = 8.0;
  static const sm = 10.0;
  static const md = 12.0;
  static const lg = 14.0;
  static const xl = 16.0;
  static const xxl = 18.0;
  static const card = 20.0;
  static const hero = 22.0;
  static const xxxl = 24.0;
  static const pill = 999.0;

  static const cardRadius = BorderRadius.all(Radius.circular(card));
  static const tileRadius = BorderRadius.all(Radius.circular(md));
  static const pillRadius = BorderRadius.all(Radius.circular(pill));
}
