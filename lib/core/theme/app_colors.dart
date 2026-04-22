import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark theme backgrounds
  static const Color darkBackground = Color(0xFF0B0E14);
  static const Color darkSurface = Color(0xFF151922);
  static const Color darkSurfaceElevated = Color(0xFF1E2330);
  static const Color darkBorder = Color(0xFF2A3040);

  // Light theme backgrounds
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Brand
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color secondary = Color(0xFF10B981);
  static const Color accent = Color(0xFFF59E0B);

  // Timeline tracks
  static const Color trackVideo = Color(0xFF3B82F6);
  static const Color trackAudio = Color(0xFF10B981);
  static const Color trackText = Color(0xFFF59E0B);
  static const Color trackBackground = Color(0xFF1E2330);
  static const Color playhead = Color(0xFFEF4444);

  // Keyframes
  static const Color keyframe = Color(0xFFFBBF24);
  static const Color keyframeActive = Color(0xFFF59E0B);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Dark text
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextDisabled = Color(0xFF64748B);

  // Light text
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextDisabled = Color(0xFF94A3B8);

  // Gradient stops
  static const List<Color> splashGradient = [primary, darkBackground];
  static const List<Color> projectCardGradient = [primary, primaryDark];
}
