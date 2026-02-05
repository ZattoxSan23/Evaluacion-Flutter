// lib/core/theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // ────────────────────────────────────────────────
  // PALETA DE COLORES OFICIAL - SPORT FITNESS CLUB
  // ────────────────────────────────────────────────
  static const Color primaryOrange =
      Color(0xFFFF6200); // Naranja principal vibrante
  static const Color orangeAccent =
      Color(0xFFFF8A65); // Naranja claro para acentos
  static const Color darkBlack = Color(0xFF0D0D0D); // Negro profundo (fondo)
  static const Color darkGrey = Color(0xFF1E1E1E); // Gris oscuro para cards
  static const Color mediumGrey = Color(0xFF333333); // Gris medio
  static const Color lightGrey =
      Color(0xFFB3B3B3); // Gris claro para texto secundario
  static const Color pureWhite = Color(0xFFFFFFFF); // Blanco puro

  // ────────────────────────────────────────────────
  // TEMA OSCURO PRINCIPAL (recomendado para la app)
  // ────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryOrange,
        scaffoldBackgroundColor: darkBlack,
        colorScheme: const ColorScheme.dark(
          primary: primaryOrange,
          secondary: orangeAccent,
          surface: darkGrey,
          onPrimary: pureWhite,
          onSecondary: pureWhite,
          onSurface: pureWhite,
          background: darkBlack,
          onBackground: pureWhite,
        ),

        // AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBlack,
          foregroundColor: pureWhite,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: pureWhite,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),

        // Cards
        cardTheme: CardThemeData(
          color: darkGrey,
          elevation: 6,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),

        // Textos generales
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: pureWhite,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
          titleLarge: TextStyle(
            color: pureWhite,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: pureWhite,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          bodyMedium: TextStyle(
            color: lightGrey,
            fontSize: 16,
          ),
          bodySmall: TextStyle(
            color: lightGrey,
            fontSize: 14,
          ),
          labelLarge: TextStyle(
            color: pureWhite,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Botones elevados
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryOrange,
            foregroundColor: pureWhite,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
            elevation: 8,
            shadowColor: primaryOrange.withOpacity(0.4),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),

        // Campos de texto
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: mediumGrey,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryOrange, width: 2.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          labelStyle: const TextStyle(color: lightGrey),
          hintStyle: const TextStyle(color: lightGrey),
          prefixIconColor: primaryOrange,
          suffixIconColor: primaryOrange,
        ),

        // Otros elementos comunes
        iconTheme: const IconThemeData(color: pureWhite),
        dividerColor: mediumGrey,
        splashColor: primaryOrange.withOpacity(0.2),
        highlightColor: primaryOrange.withOpacity(0.1),
      );
}
