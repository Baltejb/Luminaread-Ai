import 'package:flutter/material.dart';

/// Holds the current dynamic accent color, extracted from whichever book's
/// cover is open ("pixel-color" theming -- the app's palette reacts to the
/// book, the way Android's Material You reacts to the wallpaper).
class ThemeController extends ValueNotifier<Color?> {
  ThemeController._() : super(null);

  static final ThemeController instance = ThemeController._();

  void setSeed(Color? color) => value = color;

  void reset() => value = null;
}
