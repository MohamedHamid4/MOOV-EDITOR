import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Locale-aware font utilities.
/// English → Poppins | Arabic → Cairo
class AppFonts {
  AppFonts._();

  static bool _isArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  /// 32 px, Bold — page titles, hero text
  static TextStyle displayLarge(BuildContext context) => _isArabic(context)
      ? GoogleFonts.cairo(fontSize: 32, fontWeight: FontWeight.w700)
      : GoogleFonts.poppins(
          fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5);

  /// 24 px, SemiBold — section headings
  static TextStyle headline(BuildContext context) => _isArabic(context)
      ? GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.w600)
      : GoogleFonts.poppins(
          fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.3);

  /// 20 px, SemiBold — card titles, screen sub-headings
  static TextStyle title(BuildContext context) => _isArabic(context)
      ? GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w600)
      : GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600);

  /// 17 px, Medium — AppBar titles, prominent labels
  static TextStyle titleMedium(BuildContext context) => _isArabic(context)
      ? GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w500)
      : GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w500);

  /// 15 px, Regular — default body text
  static TextStyle body(BuildContext context) => _isArabic(context)
      ? GoogleFonts.cairo(fontSize: 15)
      : GoogleFonts.poppins(fontSize: 15);

  /// 13 px, Medium — captions, secondary labels
  static TextStyle label(BuildContext context) => _isArabic(context)
      ? GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w500)
      : GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500);

  /// 11 px — small metadata, timestamps
  static TextStyle caption(BuildContext context) => _isArabic(context)
      ? GoogleFonts.cairo(fontSize: 11)
      : GoogleFonts.poppins(fontSize: 11);

  /// Brand wordmark — splash "moov", home AppBar title
  static TextStyle brand(BuildContext context, {Color color = Colors.white}) =>
      _isArabic(context)
          ? GoogleFonts.cairo(
              fontSize: 40, fontWeight: FontWeight.w700, color: color)
          : GoogleFonts.poppins(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: color);

  /// Button text — 15 px SemiBold
  static TextStyle button(BuildContext context) => _isArabic(context)
      ? GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600)
      : GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600);

  // ── Locale-keyed helpers (no context) ────────────────────────────────────

  static bool isArabicLocale(Locale locale) => locale.languageCode == 'ar';

  static TextStyle bodyForLocale(Locale locale) => isArabicLocale(locale)
      ? GoogleFonts.cairo(fontSize: 15)
      : GoogleFonts.poppins(fontSize: 15);

  static TextStyle buttonForLocale(Locale locale) => isArabicLocale(locale)
      ? GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600)
      : GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600);

  static TextStyle appBarTitleForLocale(Locale locale, Color color) =>
      isArabicLocale(locale)
          ? GoogleFonts.cairo(
              fontSize: 17, fontWeight: FontWeight.w600, color: color)
          : GoogleFonts.poppins(
              fontSize: 17, fontWeight: FontWeight.w600, color: color);
}
