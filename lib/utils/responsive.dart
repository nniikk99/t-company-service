import 'package:flutter/widgets.dart';

/// Брейкпойнты адаптивной верстки (как в крупных веб-проектах).
///
///   mobile   : < 600   — телефон, нижняя навигация, контент во всю ширину
///   tablet   : 600-1023 — планшет/узкое окно, навигационный rail (только иконки)
///   desktop  : 1024+    — ПК, полное боковое меню, master-detail раскладки
///   wide     : 1440+    — широкий ПК, тот же layout + ограничение ширины контента
class Breakpoints {
  Breakpoints._();

  static const double tablet = 600;
  static const double desktop = 1024;
  static const double wide = 1440;

  /// Максимальная ширина основного контента на широких экранах,
  /// чтобы строки не растягивались на весь 4K-монитор.
  static const double maxContentWidth = 1280;

  static bool isMobile(BuildContext c) =>
      MediaQuery.of(c).size.width < tablet;

  static bool isTablet(BuildContext c) {
    final w = MediaQuery.of(c).size.width;
    return w >= tablet && w < desktop;
  }

  static bool isDesktop(BuildContext c) =>
      MediaQuery.of(c).size.width >= desktop;

  static bool isWide(BuildContext c) =>
      MediaQuery.of(c).size.width >= wide;

  /// На десктопе/планшете бывает удобно показывать master+detail.
  static bool useTwoPane(BuildContext c) =>
      MediaQuery.of(c).size.width >= desktop;

  static DeviceClass of(BuildContext c) {
    final w = MediaQuery.of(c).size.width;
    if (w >= desktop) return DeviceClass.desktop;
    if (w >= tablet) return DeviceClass.tablet;
    return DeviceClass.mobile;
  }
}

enum DeviceClass { mobile, tablet, desktop }

/// Builder, который даёт класс устройства. Удобно для условного рендера.
///
/// ```dart
/// ResponsiveBuilder(
///   builder: (context, device) => device == DeviceClass.desktop
///       ? const DesktopLayout()
///       : const MobileLayout(),
/// )
/// ```
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceClass device) builder;
  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final device = w >= Breakpoints.desktop
            ? DeviceClass.desktop
            : w >= Breakpoints.tablet
                ? DeviceClass.tablet
                : DeviceClass.mobile;
        return builder(context, device);
      },
    );
  }
}

/// Ограничивает ширину контента и центрирует его на широких экранах.
class CenteredContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const CenteredContent({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.maxContentWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}
