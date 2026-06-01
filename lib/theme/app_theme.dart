// ============================================================
// app_theme.dart — Thème global Scanova
// ------------------------------------------------------------
// Centralise toutes les couleurs, rayons, ombres et styles
// dérivés du design system. À utiliser via :
//
//     MaterialApp(
//       theme: AppTheme.light(),
//       home: const LoginScreen(),
//     );
//
// Ne casse aucune logique métier — ce fichier n'a aucune
// dépendance vers les services OCR, parsers ou SQLite.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  AppColors._();

  // ---- Brand / primary -----------------------------------
  static const Color brand600   = Color(0xFF2563EB); // primary
  static const Color brand700   = Color(0xFF1D4ED8); // pressed
  static const Color brand500   = Color(0xFF3B82F6);
  static const Color brand300   = Color(0xFF93C5FD); // disabled
  static const Color brand100   = Color(0xFFDBEAFE);
  static const Color brand050   = Color(0xFFEFF6FF);

  // ---- Neutrals (slate) ----------------------------------
  static const Color ink900     = Color(0xFF0F172A); // texte principal
  static const Color ink700     = Color(0xFF334155);
  static const Color ink500     = Color(0xFF64748B); // texte secondaire
  static const Color ink400     = Color(0xFF94A3B8); // hint
  static const Color ink300     = Color(0xFFCBD5E1); // bordures
  static const Color ink200     = Color(0xFFE2E8F0);
  static const Color ink100     = Color(0xFFF1F5F9); // fond login
  static const Color ink050     = Color(0xFFF8FAFC); // fond app
  static const Color white      = Color(0xFFFFFFFF);

  // ---- Semantic ------------------------------------------
  static const Color success600 = Color(0xFF16A34A);
  static const Color success100 = Color(0xFFDCFCE7);

  static const Color warning600 = Color(0xFFD97706);
  static const Color warning500 = Color(0xFFF59E0B); // "à vérifier"
  static const Color warning100 = Color(0xFFFEF3C7);

  static const Color danger600  = Color(0xFFDC2626);
  static const Color danger100  = Color(0xFFFEE2E2);

  // ---- Document type colors ------------------------------
  static const Color docOrdonnance = brand600;
  static const Color docBilan      = success600;
  static const Color docRadio      = Color(0xFF9333EA);
  static const Color docCr         = Color(0xFFEA580C);
  static const Color docAutre      = ink500;
}

class AppRadii {
  AppRadii._();
  static const double sm  = 8;
  static const double md  = 12; // fields, boutons
  static const double lg  = 14; // tuiles de liste
  static const double xl  = 18; // cartes image, dialogs
  static const double xxl = 22; // hero cards
  static const double header = 28; // bottom-only AppBar bleu
}

class AppShadows {
  AppShadows._();
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 10, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> elev = [
    BoxShadow(color: Color(0x120F172A), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> pop = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 18, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> brandGlow = [
    BoxShadow(color: Color(0x402563EB), blurRadius: 18, offset: Offset(0, 8)),
  ];
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);

    // ---- TextTheme -----------------------------------------
    // Bases sur les fontSize que ton code utilise déjà
    // (12/13/14/15/16/20/22/24). On garde Roboto par défaut
    // sur Android — pas besoin d'ajouter google_fonts.
    final textTheme = base.textTheme.copyWith(
      displaySmall: const TextStyle(
        fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink900, height: 1.2,
      ),
      headlineMedium: const TextStyle(
        fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink900, height: 1.2,
      ),
      headlineSmall: const TextStyle(
        fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink900, height: 1.25,
      ),
      titleLarge: const TextStyle(
        fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink900,
      ),
      titleMedium: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink900,
      ),
      bodyLarge: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.ink700, height: 1.45,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.ink500, height: 1.45,
      ),
      bodySmall: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.ink500,
      ),
      labelLarge: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.white, // boutons
      ),
    );

    // ---- ColorScheme ---------------------------------------
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand600,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.brand600,
      onPrimary: AppColors.white,
      secondary: AppColors.brand500,
      surface: AppColors.white,
      onSurface: AppColors.ink900,
      surfaceContainerLowest: AppColors.ink050,
      error: AppColors.danger600,
    );

    return base.copyWith(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.ink050,
      textTheme: textTheme,
      dividerColor: AppColors.ink200,

      // ---- AppBar -----------------------------------------
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.brand600,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        // Pas de couleur figée ici : la couleur du titre suit le
        // `foregroundColor` de chaque AppBar (blanc sur les AppBars bleues,
        // ink900 sur les AppBars blanches). Évite le titre blanc-sur-blanc.
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      // ---- Card -------------------------------------------
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // ---- Inputs -----------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.ink400, fontSize: 15),
        labelStyle: const TextStyle(color: AppColors.ink500, fontSize: 14, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(color: AppColors.brand600, fontSize: 14, fontWeight: FontWeight.w600),
        prefixIconColor: AppColors.ink500,
        suffixIconColor: AppColors.ink500,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.ink300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.ink300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.brand600, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.danger600, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.danger600, width: 1.5),
        ),
      ),

      // ---- ElevatedButton ---------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand600,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.brand300,
          disabledForegroundColor: AppColors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      // ---- OutlinedButton ---------------------------------
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand600,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: const BorderSide(color: AppColors.brand600, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      // ---- TextButton -------------------------------------
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand600,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ---- FloatingActionButton ---------------------------
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brand600,
        foregroundColor: AppColors.white,
        elevation: 6,
        extendedTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),

      // ---- Dialog -----------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xxl),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink900,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.ink700, height: 1.45,
        ),
      ),

      // ---- SnackBar ---------------------------------------
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink900,
        contentTextStyle: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
        ),
      ),

      // ---- ListTile ---------------------------------------
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.ink500,
        textColor: AppColors.ink900,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),

      // ---- Progress indicator -----------------------------
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand600,
        circularTrackColor: AppColors.brand100,
      ),

      // ---- Icons ------------------------------------------
      iconTheme: const IconThemeData(color: AppColors.ink500, size: 22),
      primaryIconTheme: const IconThemeData(color: AppColors.white, size: 22),
    );
  }
}
