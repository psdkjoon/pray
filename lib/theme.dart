import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CatppuccinMocha {
  static const rosewater = Color(0xFFF5E0DC);
  static const flamingo = Color(0xFFF2CDCD);
  static const pink = Color(0xFFF5C2E7);
  static const mauve = Color(0xFFCBA6F7);
  static const red = Color(0xFFF38BA8);
  static const maroon = Color(0xFFEBA0AC);
  static const peach = Color(0xFFFAB387);
  static const yellow = Color(0xFFF9E2AF);
  static const green = Color(0xFFA6E3A1);
  static const teal = Color(0xFF94E2D5);
  static const sky = Color(0xFF89DCEB);
  static const sapphire = Color(0xFF74C7EC);
  static const blue = Color(0xFF89B4FA);
  static const lavender = Color(0xFFB4BEFE);
  static const text = Color(0xFFCDD6F4);
  static const subtext1 = Color(0xFFBAC2DE);
  static const subtext0 = Color(0xFFA6ADC8);
  static const overlay2 = Color(0xFF9399B2);
  static const overlay1 = Color(0xFF7F849C);
  static const overlay0 = Color(0xFF6C7086);
  static const surface2 = Color(0xFF585B70);
  static const surface1 = Color(0xFF45475A);
  static const surface0 = Color(0xFF313244);
  static const base = Color(0xFF1E1E2E);
  static const mantle = Color(0xFF181825);
  static const crust = Color(0xFF11111B);
}

class CatppuccinLatte {
  static const rosewater = Color(0xFFDC8A78);
  static const flamingo = Color(0xFFDD7878);
  static const pink = Color(0xFFEA76CB);
  static const mauve = Color(0xFF8839EF);
  static const red = Color(0xFFD20F39);
  static const maroon = Color(0xFFE64553);
  static const peach = Color(0xFFFE640B);
  static const yellow = Color(0xFFDF8E1D);
  static const green = Color(0xFF40A02B);
  static const teal = Color(0xFF179299);
  static const sky = Color(0xFF04A5E5);
  static const sapphire = Color(0xFF209FB5);
  static const blue = Color(0xFF1E66F5);
  static const lavender = Color(0xFF7287FD);
  static const text = Color(0xFF4C4F69);
  static const subtext1 = Color(0xFF5C5F77);
  static const subtext0 = Color(0xFF6C6F85);
  static const overlay2 = Color(0xFF7C7F93);
  static const overlay1 = Color(0xFF8C8FA1);
  static const overlay0 = Color(0xFF9CA0B0);
  static const surface2 = Color(0xFFACB0BE);
  static const surface1 = Color(0xFFBCC0CC);
  static const surface0 = Color(0xFFCCD0DA);
  static const base = Color(0xFFEFF1F5);
  static const mantle = Color(0xFFE6E9EF);
  static const crust = Color(0xFFDCE0E8);
}

final ThemeData mochaTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: CatppuccinMocha.base,
  fontFamily: 'JetBrainsMono',
  colorScheme: const ColorScheme.dark(
    brightness: Brightness.dark,
    primary: CatppuccinMocha.mauve,
    onPrimary: CatppuccinMocha.crust,
    primaryContainer: CatppuccinMocha.surface0,
    onPrimaryContainer: CatppuccinMocha.mauve,
    secondary: CatppuccinMocha.blue,
    onSecondary: CatppuccinMocha.crust,
    secondaryContainer: CatppuccinMocha.surface0,
    onSecondaryContainer: CatppuccinMocha.blue,
    tertiary: CatppuccinMocha.teal,
    onTertiary: CatppuccinMocha.crust,
    tertiaryContainer: CatppuccinMocha.surface0,
    onTertiaryContainer: CatppuccinMocha.teal,
    error: CatppuccinMocha.red,
    onError: CatppuccinMocha.crust,
    errorContainer: CatppuccinMocha.surface0,
    onErrorContainer: CatppuccinMocha.red,
    surface: CatppuccinMocha.base,
    onSurface: CatppuccinMocha.text,
    surfaceContainerLowest: CatppuccinMocha.crust,
    surfaceContainerLow: CatppuccinMocha.mantle,
    surfaceContainer: CatppuccinMocha.base,
    surfaceContainerHigh: CatppuccinMocha.surface0,
    surfaceContainerHighest: CatppuccinMocha.surface1,
    onSurfaceVariant: CatppuccinMocha.subtext0,
    outline: CatppuccinMocha.overlay0,
    outlineVariant: CatppuccinMocha.surface2,
    shadow: CatppuccinMocha.crust,
    scrim: CatppuccinMocha.crust,
    inverseSurface: CatppuccinMocha.text,
    onInverseSurface: CatppuccinMocha.base,
    inversePrimary: CatppuccinMocha.mauve,
  ),
  canvasColor: CatppuccinMocha.base,
  cardColor: CatppuccinMocha.surface0,
  dividerColor: CatppuccinMocha.surface1,
  disabledColor: CatppuccinMocha.overlay0,
  highlightColor: CatppuccinMocha.surface0,
  splashColor: CatppuccinMocha.surface1,
  hintColor: CatppuccinMocha.subtext0,
  focusColor: CatppuccinMocha.lavender,
  shadowColor: CatppuccinMocha.crust,
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      color: CatppuccinMocha.text,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      color: CatppuccinMocha.text,
      fontWeight: FontWeight.bold,
    ),
    displaySmall: TextStyle(
      color: CatppuccinMocha.text,
      fontWeight: FontWeight.bold,
    ),
    headlineLarge: TextStyle(
      color: CatppuccinMocha.text,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: TextStyle(
      color: CatppuccinMocha.text,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: TextStyle(
      color: CatppuccinMocha.text,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      color: CatppuccinMocha.text,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      color: CatppuccinMocha.text,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: TextStyle(
      color: CatppuccinMocha.subtext1,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(color: CatppuccinMocha.text),
    bodyMedium: TextStyle(color: CatppuccinMocha.text),
    bodySmall: TextStyle(color: CatppuccinMocha.subtext0),
    labelLarge: TextStyle(
      color: CatppuccinMocha.text,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: TextStyle(color: CatppuccinMocha.subtext1),
    labelSmall: TextStyle(color: CatppuccinMocha.subtext0),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: CatppuccinMocha.mantle,
    foregroundColor: CatppuccinMocha.text,
    elevation: 0,
    scrolledUnderElevation: 1,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    iconTheme: IconThemeData(color: CatppuccinMocha.text),
    actionsIconTheme: IconThemeData(color: CatppuccinMocha.subtext1),
    titleTextStyle: TextStyle(
      color: CatppuccinMocha.text,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
  ),
  cardTheme: CardThemeData(
    color: CatppuccinMocha.surface0,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: CatppuccinMocha.surface1),
    ),
    margin: const EdgeInsets.all(8),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: CatppuccinMocha.mantle,
    surfaceTintColor: Colors.transparent,
    elevation: 8,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    titleTextStyle: const TextStyle(
      color: CatppuccinMocha.text,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    contentTextStyle: const TextStyle(color: CatppuccinMocha.subtext1),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: CatppuccinMocha.mantle,
    surfaceTintColor: Colors.transparent,
    modalBackgroundColor: CatppuccinMocha.mantle,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: CatppuccinMocha.surface0,
    contentTextStyle: const TextStyle(color: CatppuccinMocha.text),
    actionTextColor: CatppuccinMocha.mauve,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: CatppuccinMocha.surface0,
    hintStyle: const TextStyle(color: CatppuccinMocha.overlay1),
    labelStyle: const TextStyle(color: CatppuccinMocha.subtext0),
    floatingLabelStyle: const TextStyle(color: CatppuccinMocha.mauve),
    prefixIconColor: CatppuccinMocha.subtext0,
    suffixIconColor: CatppuccinMocha.subtext0,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: CatppuccinMocha.surface1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: CatppuccinMocha.surface1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: CatppuccinMocha.mauve, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: CatppuccinMocha.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: CatppuccinMocha.red, width: 1.5),
    ),
    errorStyle: const TextStyle(color: CatppuccinMocha.red),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: CatppuccinMocha.mauve,
      foregroundColor: CatppuccinMocha.crust,
      disabledBackgroundColor: CatppuccinMocha.surface1,
      disabledForegroundColor: CatppuccinMocha.overlay0,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: CatppuccinMocha.mauve,
      foregroundColor: CatppuccinMocha.crust,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: CatppuccinMocha.mauve,
      side: const BorderSide(color: CatppuccinMocha.surface2),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: CatppuccinMocha.mauve,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(foregroundColor: CatppuccinMocha.subtext1),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: CatppuccinMocha.mauve,
    foregroundColor: CatppuccinMocha.crust,
    elevation: 2,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: CatppuccinMocha.surface0,
    disabledColor: CatppuccinMocha.surface0.withValues(alpha: 0.5),
    selectedColor: CatppuccinMocha.mauve,
    secondarySelectedColor: CatppuccinMocha.surface1,
    labelStyle: const TextStyle(color: CatppuccinMocha.text),
    secondaryLabelStyle: const TextStyle(color: CatppuccinMocha.crust),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    side: const BorderSide(color: CatppuccinMocha.surface1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  dividerTheme: const DividerThemeData(
    color: CatppuccinMocha.surface1,
    thickness: 1,
    space: 1,
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: CatppuccinMocha.surface1,
      borderRadius: BorderRadius.circular(6),
    ),
    textStyle: const TextStyle(color: CatppuccinMocha.text),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? CatppuccinMocha.mauve
          : CatppuccinMocha.overlay1,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? CatppuccinMocha.mauve.withValues(alpha: 0.5)
          : CatppuccinMocha.surface1,
    ),
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? CatppuccinMocha.mauve
          : Colors.transparent,
    ),
    checkColor: const WidgetStatePropertyAll(CatppuccinMocha.crust),
    side: const BorderSide(color: CatppuccinMocha.overlay1, width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
  radioTheme: RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? CatppuccinMocha.mauve
          : CatppuccinMocha.overlay1,
    ),
  ),
  sliderTheme: SliderThemeData(
    activeTrackColor: CatppuccinMocha.mauve,
    inactiveTrackColor: CatppuccinMocha.surface1,
    thumbColor: CatppuccinMocha.mauve,
    overlayColor: CatppuccinMocha.mauve.withValues(alpha: 0.15),
    valueIndicatorColor: CatppuccinMocha.surface2,
    valueIndicatorTextStyle: const TextStyle(color: CatppuccinMocha.text),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: CatppuccinMocha.mauve,
    linearTrackColor: CatppuccinMocha.surface1,
    circularTrackColor: CatppuccinMocha.surface1,
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: CatppuccinMocha.mauve,
    unselectedLabelColor: CatppuccinMocha.subtext0,
    indicatorColor: CatppuccinMocha.mauve,
    dividerColor: CatppuccinMocha.surface1,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: CatppuccinMocha.mantle,
    indicatorColor: CatppuccinMocha.surface1,
    surfaceTintColor: Colors.transparent,
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        color: states.contains(WidgetState.selected)
            ? CatppuccinMocha.text
            : CatppuccinMocha.subtext0,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        color: states.contains(WidgetState.selected)
            ? CatppuccinMocha.mauve
            : CatppuccinMocha.subtext0,
      ),
    ),
  ),
  navigationRailTheme: const NavigationRailThemeData(
    backgroundColor: CatppuccinMocha.mantle,
    selectedIconTheme: IconThemeData(color: CatppuccinMocha.mauve),
    unselectedIconTheme: IconThemeData(color: CatppuccinMocha.subtext0),
    selectedLabelTextStyle: TextStyle(color: CatppuccinMocha.text),
    unselectedLabelTextStyle: TextStyle(color: CatppuccinMocha.subtext0),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: CatppuccinMocha.mantle,
    selectedItemColor: CatppuccinMocha.mauve,
    unselectedItemColor: CatppuccinMocha.subtext0,
    type: BottomNavigationBarType.fixed,
  ),
  drawerTheme: const DrawerThemeData(
    backgroundColor: CatppuccinMocha.mantle,
    surfaceTintColor: Colors.transparent,
  ),
  listTileTheme: const ListTileThemeData(
    iconColor: CatppuccinMocha.subtext1,
    textColor: CatppuccinMocha.text,
    tileColor: Colors.transparent,
    selectedTileColor: CatppuccinMocha.surface0,
    selectedColor: CatppuccinMocha.mauve,
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: CatppuccinMocha.surface0,
    surfaceTintColor: Colors.transparent,
    textStyle: const TextStyle(color: CatppuccinMocha.text),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
  menuTheme: MenuThemeData(
    style: MenuStyle(
      backgroundColor: const WidgetStatePropertyAll(CatppuccinMocha.surface0),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  ),
  scrollbarTheme: ScrollbarThemeData(
    thumbColor: WidgetStatePropertyAll(
      CatppuccinMocha.overlay0.withValues(alpha: 0.6),
    ),
    trackColor: const WidgetStatePropertyAll(Colors.transparent),
    radius: const Radius.circular(8),
  ),
  badgeTheme: const BadgeThemeData(
    backgroundColor: CatppuccinMocha.red,
    textColor: CatppuccinMocha.crust,
  ),
  iconTheme: const IconThemeData(color: CatppuccinMocha.text),
  primaryIconTheme: const IconThemeData(color: CatppuccinMocha.crust),
  splashFactory: InkRipple.splashFactory,
  visualDensity: VisualDensity.standard,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  ),
);

final ThemeData latteTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: CatppuccinLatte.base,
  fontFamily: 'JetBrainsMono',
  colorScheme: const ColorScheme.light(
    brightness: Brightness.light,
    primary: CatppuccinLatte.mauve,
    onPrimary: CatppuccinLatte.base,
    primaryContainer: CatppuccinLatte.surface0,
    onPrimaryContainer: CatppuccinLatte.mauve,
    secondary: CatppuccinLatte.blue,
    onSecondary: CatppuccinLatte.base,
    secondaryContainer: CatppuccinLatte.surface0,
    onSecondaryContainer: CatppuccinLatte.blue,
    tertiary: CatppuccinLatte.teal,
    onTertiary: CatppuccinLatte.base,
    tertiaryContainer: CatppuccinLatte.surface0,
    onTertiaryContainer: CatppuccinLatte.teal,
    error: CatppuccinLatte.red,
    onError: CatppuccinLatte.base,
    errorContainer: CatppuccinLatte.surface0,
    onErrorContainer: CatppuccinLatte.red,
    surface: CatppuccinLatte.base,
    onSurface: CatppuccinLatte.text,
    surfaceContainerLowest: CatppuccinLatte.crust,
    surfaceContainerLow: CatppuccinLatte.mantle,
    surfaceContainer: CatppuccinLatte.base,
    surfaceContainerHigh: CatppuccinLatte.surface0,
    surfaceContainerHighest: CatppuccinLatte.surface1,
    onSurfaceVariant: CatppuccinLatte.subtext0,
    outline: CatppuccinLatte.overlay0,
    outlineVariant: CatppuccinLatte.surface2,
    shadow: CatppuccinLatte.crust,
    scrim: CatppuccinLatte.crust,
    inverseSurface: CatppuccinLatte.text,
    onInverseSurface: CatppuccinLatte.base,
    inversePrimary: CatppuccinLatte.mauve,
  ),
  canvasColor: CatppuccinLatte.base,
  cardColor: CatppuccinLatte.surface0,
  dividerColor: CatppuccinLatte.surface1,
  disabledColor: CatppuccinLatte.overlay0,
  highlightColor: CatppuccinLatte.surface0,
  splashColor: CatppuccinLatte.surface1,
  hintColor: CatppuccinLatte.subtext0,
  focusColor: CatppuccinLatte.lavender,
  shadowColor: CatppuccinLatte.crust,
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      color: CatppuccinLatte.text,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      color: CatppuccinLatte.text,
      fontWeight: FontWeight.bold,
    ),
    displaySmall: TextStyle(
      color: CatppuccinLatte.text,
      fontWeight: FontWeight.bold,
    ),
    headlineLarge: TextStyle(
      color: CatppuccinLatte.text,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: TextStyle(
      color: CatppuccinLatte.text,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: TextStyle(
      color: CatppuccinLatte.text,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      color: CatppuccinLatte.text,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      color: CatppuccinLatte.text,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: TextStyle(
      color: CatppuccinLatte.subtext1,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(color: CatppuccinLatte.text),
    bodyMedium: TextStyle(color: CatppuccinLatte.text),
    bodySmall: TextStyle(color: CatppuccinLatte.subtext0),
    labelLarge: TextStyle(
      color: CatppuccinLatte.text,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: TextStyle(color: CatppuccinLatte.subtext1),
    labelSmall: TextStyle(color: CatppuccinLatte.subtext0),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: CatppuccinLatte.mantle,
    foregroundColor: CatppuccinLatte.text,
    elevation: 0,
    scrolledUnderElevation: 1,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    iconTheme: IconThemeData(color: CatppuccinLatte.text),
    actionsIconTheme: IconThemeData(color: CatppuccinLatte.subtext1),
    titleTextStyle: TextStyle(
      color: CatppuccinLatte.text,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
  ),
  cardTheme: CardThemeData(
    color: CatppuccinLatte.surface0,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: CatppuccinLatte.surface1),
    ),
    margin: const EdgeInsets.all(8),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: CatppuccinLatte.mantle,
    surfaceTintColor: Colors.transparent,
    elevation: 8,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    titleTextStyle: const TextStyle(
      color: CatppuccinLatte.text,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    contentTextStyle: const TextStyle(color: CatppuccinLatte.subtext1),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: CatppuccinLatte.mantle,
    surfaceTintColor: Colors.transparent,
    modalBackgroundColor: CatppuccinLatte.mantle,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: CatppuccinLatte.surface0,
    contentTextStyle: const TextStyle(color: CatppuccinLatte.text),
    actionTextColor: CatppuccinLatte.mauve,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: CatppuccinLatte.surface0,
    hintStyle: const TextStyle(color: CatppuccinLatte.overlay1),
    labelStyle: const TextStyle(color: CatppuccinLatte.subtext0),
    floatingLabelStyle: const TextStyle(color: CatppuccinLatte.mauve),
    prefixIconColor: CatppuccinLatte.subtext0,
    suffixIconColor: CatppuccinLatte.subtext0,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: CatppuccinLatte.surface1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: CatppuccinLatte.surface1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: CatppuccinLatte.mauve, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: CatppuccinLatte.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: CatppuccinLatte.red, width: 1.5),
    ),
    errorStyle: const TextStyle(color: CatppuccinLatte.red),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: CatppuccinLatte.mauve,
      foregroundColor: CatppuccinLatte.base,
      disabledBackgroundColor: CatppuccinLatte.surface1,
      disabledForegroundColor: CatppuccinLatte.overlay0,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: CatppuccinLatte.mauve,
      foregroundColor: CatppuccinLatte.base,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: CatppuccinLatte.mauve,
      side: const BorderSide(color: CatppuccinLatte.surface2),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: CatppuccinLatte.mauve,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(foregroundColor: CatppuccinLatte.subtext1),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: CatppuccinLatte.mauve,
    foregroundColor: CatppuccinLatte.base,
    elevation: 2,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: CatppuccinLatte.surface0,
    disabledColor: CatppuccinLatte.surface0.withValues(alpha: 0.5),
    selectedColor: CatppuccinLatte.mauve,
    secondarySelectedColor: CatppuccinLatte.surface1,
    labelStyle: const TextStyle(color: CatppuccinLatte.text),
    secondaryLabelStyle: const TextStyle(color: CatppuccinLatte.base),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    side: const BorderSide(color: CatppuccinLatte.surface1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  dividerTheme: const DividerThemeData(
    color: CatppuccinLatte.surface1,
    thickness: 1,
    space: 1,
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: CatppuccinLatte.surface1,
      borderRadius: BorderRadius.circular(6),
    ),
    textStyle: const TextStyle(color: CatppuccinLatte.text),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? CatppuccinLatte.mauve
          : CatppuccinLatte.overlay1,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? CatppuccinLatte.mauve.withValues(alpha: 0.5)
          : CatppuccinLatte.surface1,
    ),
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? CatppuccinLatte.mauve
          : Colors.transparent,
    ),
    checkColor: const WidgetStatePropertyAll(CatppuccinLatte.base),
    side: const BorderSide(color: CatppuccinLatte.overlay1, width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
  radioTheme: RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? CatppuccinLatte.mauve
          : CatppuccinLatte.overlay1,
    ),
  ),
  sliderTheme: SliderThemeData(
    activeTrackColor: CatppuccinLatte.mauve,
    inactiveTrackColor: CatppuccinLatte.surface1,
    thumbColor: CatppuccinLatte.mauve,
    overlayColor: CatppuccinLatte.mauve.withValues(alpha: 0.15),
    valueIndicatorColor: CatppuccinLatte.surface2,
    valueIndicatorTextStyle: const TextStyle(color: CatppuccinLatte.text),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: CatppuccinLatte.mauve,
    linearTrackColor: CatppuccinLatte.surface1,
    circularTrackColor: CatppuccinLatte.surface1,
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: CatppuccinLatte.mauve,
    unselectedLabelColor: CatppuccinLatte.subtext0,
    indicatorColor: CatppuccinLatte.mauve,
    dividerColor: CatppuccinLatte.surface1,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: CatppuccinLatte.mantle,
    indicatorColor: CatppuccinLatte.surface1,
    surfaceTintColor: Colors.transparent,
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        color: states.contains(WidgetState.selected)
            ? CatppuccinLatte.text
            : CatppuccinLatte.subtext0,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        color: states.contains(WidgetState.selected)
            ? CatppuccinLatte.mauve
            : CatppuccinLatte.subtext0,
      ),
    ),
  ),
  navigationRailTheme: const NavigationRailThemeData(
    backgroundColor: CatppuccinLatte.mantle,
    selectedIconTheme: IconThemeData(color: CatppuccinLatte.mauve),
    unselectedIconTheme: IconThemeData(color: CatppuccinLatte.subtext0),
    selectedLabelTextStyle: TextStyle(color: CatppuccinLatte.text),
    unselectedLabelTextStyle: TextStyle(color: CatppuccinLatte.subtext0),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: CatppuccinLatte.mantle,
    selectedItemColor: CatppuccinLatte.mauve,
    unselectedItemColor: CatppuccinLatte.subtext0,
    type: BottomNavigationBarType.fixed,
  ),
  drawerTheme: const DrawerThemeData(
    backgroundColor: CatppuccinLatte.mantle,
    surfaceTintColor: Colors.transparent,
  ),
  listTileTheme: const ListTileThemeData(
    iconColor: CatppuccinLatte.subtext1,
    textColor: CatppuccinLatte.text,
    tileColor: Colors.transparent,
    selectedTileColor: CatppuccinLatte.surface0,
    selectedColor: CatppuccinLatte.mauve,
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: CatppuccinLatte.surface0,
    surfaceTintColor: Colors.transparent,
    textStyle: const TextStyle(color: CatppuccinLatte.text),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
  menuTheme: MenuThemeData(
    style: MenuStyle(
      backgroundColor: const WidgetStatePropertyAll(CatppuccinLatte.surface0),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  ),
  scrollbarTheme: ScrollbarThemeData(
    thumbColor: WidgetStatePropertyAll(
      CatppuccinLatte.overlay0.withValues(alpha: 0.6),
    ),
    trackColor: const WidgetStatePropertyAll(Colors.transparent),
    radius: const Radius.circular(8),
  ),
  badgeTheme: const BadgeThemeData(
    backgroundColor: CatppuccinLatte.red,
    textColor: CatppuccinLatte.base,
  ),
  iconTheme: const IconThemeData(color: CatppuccinLatte.text),
  primaryIconTheme: const IconThemeData(color: CatppuccinLatte.base),
  splashFactory: InkRipple.splashFactory,
  visualDensity: VisualDensity.standard,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  ),
);
