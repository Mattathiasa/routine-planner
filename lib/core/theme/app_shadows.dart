import 'package:flutter/painting.dart';

/// Shadow tokens from the approved v3 design. Screen-specific shadows
/// (gradient hero card, pill nav, etc.) are added when those are built.
abstract final class AppShadows {
  /// The standard "layered white card" shadow used on nearly every card.
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x0A101828), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0F101828), offset: Offset(0, 4), blurRadius: 16),
  ];

  /// The circular icon-button shadow (e.g. a settings gear button).
  static const iconButton = <BoxShadow>[
    BoxShadow(color: Color(0x0F101828), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0F101828), offset: Offset(0, 4), blurRadius: 12),
  ];
}
