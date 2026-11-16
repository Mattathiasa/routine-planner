import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/theme/app_colors.dart';

double _linear(double channel) {
  return channel <= 0.03928 ? channel / 12.92 : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color c) {
  return 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// WCAG AA: 4.5:1 for body text, 3:1 for large text (>=18.7px bold) and
/// meaningful non-text UI. Checked for both palettes so a dark-token edit
/// can't silently regress readability.
void main() {
  for (final (name, c) in [('light', AppColorScheme.light), ('dark', AppColorScheme.dark)]) {
    group('$name palette', () {
      void expectContrast(String label, Color fg, Color bg, double min) {
        final ratio = contrast(fg, bg);
        expect(ratio, greaterThanOrEqualTo(min),
            reason: '$label is ${ratio.toStringAsFixed(2)}:1, needs $min:1');
      }

      test('body text meets 4.5:1', () {
        expectContrast('textPrimary on surface', c.textPrimary, c.surface, 4.5);
        expectContrast('textPrimary on background', c.textPrimary, c.background, 4.5);
        expectContrast('textSecondary on surface', c.textSecondary, c.surface, 4.5);
        expectContrast('textSecondary on background', c.textSecondary, c.background, 4.5);
        expectContrast('success on successContainer', c.success, c.successContainer, 4.5);
        expectContrast('warning on warningContainer', c.warning, c.warningContainer, 4.5);
      });

      test('accent and badge text meets 4.5:1', () {
        expectContrast('primary on surface', c.primary, c.surface, 4.5);
        expectContrast('rarity5Text on rarity5Background', c.rarity5Text, c.rarity5Background, 4.5);
        expectContrast('rarity4Text on rarity4Background', c.rarity4Text, c.rarity4Background, 4.5);
      });

      test('large text and iconography meets 3:1', () {
        expectContrast('pyro avatar initial', c.pyroAvatarText, c.pyroAvatarBackground, 3);
        expectContrast('hydro avatar initial', c.hydroAvatarText, c.hydroAvatarBackground, 3);
        expectContrast('electro avatar initial', c.electroAvatarText, c.electroAvatarBackground, 3);
        expectContrast('green tile icon', c.tileGreenIcon, c.tileGreenBackground, 3);
        expectContrast('blue tile icon', c.tileBlueIcon, c.tileBlueBackground, 3);
        expectContrast('purple tile icon', c.tilePurpleIcon, c.tilePurpleBackground, 3);
        expectContrast('amber tile icon', c.tileAmberIcon, c.tileAmberBackground, 3);
      });
    });
  }
}
