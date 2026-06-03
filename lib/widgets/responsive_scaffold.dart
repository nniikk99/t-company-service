import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// Универсальный пункт навигации для адаптивной оболочки.
class NavItem {
  final String id;
  final String label;
  final IconData? icon;
  final IconData? activeIcon;
  final String? customIconPath;

  const NavItem({
    required this.id,
    required this.label,
    this.icon,
    this.activeIcon,
    this.customIconPath,
  });
}

/// Адаптивная навигационная оболочка.
///
///   mobile  → нижняя навигация (bottom bar)
///   tablet  → узкий navigation rail (только иконки) слева
///   desktop → полное боковое меню с подписями + верхняя панель
///
/// Бизнес-контент (`body`) остаётся неизменным — меняется только обрамление.
class ResponsiveScaffold extends StatelessWidget {
  final List<NavItem> tabs;
  final String activeTabId;
  final ValueChanged<String> onTabSelected;
  final Widget body;

  /// Заголовок текущего раздела (для верхней панели десктопа).
  final String? title;

  /// Шапка профиля для сайдбара.
  final String userName;
  final String userRoleLabel;
  final String? companyName;

  /// Действия.
  final VoidCallback? onProfile;
  final VoidCallback? onNotifications;
  final VoidCallback? onLogout;
  final int unreadNotifications;

  /// Верхняя плашка над контентом (например, offline-баннер).
  final Widget? topBanner;

  /// Кнопка-действие на мобильном AppBar (например «назад в админку»).
  final Widget? mobileLeading;

  const ResponsiveScaffold({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onTabSelected,
    required this.body,
    required this.userName,
    required this.userRoleLabel,
    this.companyName,
    this.title,
    this.onProfile,
    this.onNotifications,
    this.onLogout,
    this.unreadNotifications = 0,
    this.topBanner,
    this.mobileLeading,
  });

  static const _bg = Color(0xFFF8FAFC);
  static const _accent = Color(0xFF2563EB);
  static const _accentBg = Color(0xFFEFF6FF);
  static const _sidebarW = 248.0;
  static const _railW = 76.0;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, device) {
        switch (device) {
          case DeviceClass.desktop:
            return _desktop(context);
          case DeviceClass.tablet:
            return _tablet(context);
          case DeviceClass.mobile:
            return _mobile(context);
        }
      },
    );
  }

  // ── Desktop: сайдбар + топбар ───────────────────────────────────────────

  Widget _desktop(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          _sidebar(context),
          Expanded(
            child: Column(
              children: [
                if (topBanner != null) topBanner!,
                // Экраны сохраняют собственные AppBar'ы; навигация, профиль,
                // уведомления и выход живут в сайдбаре — двойных шапок нет.
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar(BuildContext context) {
    return Container(
      width: _sidebarW,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Логотип / название
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cleaning_services_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'AI Service',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // Навигация
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              children: [
                for (final tab in tabs) _sidebarItem(context, tab),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // Низ: уведомления, профиль, выход
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _sidebarAction(
                  icon: Icons.notifications_none_rounded,
                  label: 'Уведомления',
                  badge: unreadNotifications,
                  onTap: onNotifications,
                ),
                _sidebarAction(
                  icon: Icons.logout_rounded,
                  label: 'Выход',
                  danger: true,
                  onTap: onLogout,
                ),
                const SizedBox(height: 8),
                _profileChip(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(BuildContext context, NavItem tab) {
    final active = tab.id == activeTabId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? _accentBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => onTabSelected(tab.id),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                _navIcon(tab, active, size: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? _accent : const Color(0xFF475569),
                    ),
                  ),
                ),
                if (active)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebarAction({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    int badge = 0,
    bool danger = false,
  }) {
    final color = danger ? const Color(0xFFEF4444) : const Color(0xFF64748B);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: color)),
              ),
              if (badge > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileChip(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onProfile,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _avatar(userName, 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      companyName?.isNotEmpty == true
                          ? companyName!
                          : userRoleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tablet: navigation rail ─────────────────────────────────────────────

  Widget _tablet(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          Container(
            width: _railW,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cleaning_services_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final tab in tabs) _railItem(context, tab),
                    ],
                  ),
                ),
                _railIconBtn(
                  icon: Icons.notifications_none_rounded,
                  badge: unreadNotifications,
                  onTap: onNotifications,
                ),
                _railIconBtn(
                  icon: Icons.person_outline_rounded,
                  onTap: onProfile,
                ),
                _railIconBtn(
                  icon: Icons.logout_rounded,
                  danger: true,
                  onTap: onLogout,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                if (topBanner != null) topBanner!,
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _railItem(BuildContext context, NavItem tab) {
    final active = tab.id == activeTabId;
    return Tooltip(
      message: tab.label,
      preferBelow: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Material(
          color: active ? _accentBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onTabSelected(tab.id),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: _navIcon(tab, active, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _railIconBtn({
    required IconData icon,
    VoidCallback? onTap,
    int badge = 0,
    bool danger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          IconButton(
            onPressed: onTap,
            icon: Icon(icon,
                size: 22,
                color: danger
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF64748B)),
          ),
          if (badge > 0)
            Positioned(
              right: 8,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: Color(0xFFEF4444), shape: BoxShape.circle),
                constraints:
                    const BoxConstraints(minWidth: 15, minHeight: 15),
                child: Text('$badge',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Mobile: bottom nav ──────────────────────────────────────────────────

  Widget _mobile(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: mobileLeading != null
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 60,
              leading: mobileLeading,
            )
          : null,
      extendBodyBehindAppBar: mobileLeading != null,
      body: Column(
        children: [
          if (topBanner != null) SafeArea(bottom: false, child: topBanner!),
          Expanded(
            child: SafeArea(top: topBanner == null, child: body),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: tabs.map((tab) {
                final active = tab.id == activeTabId;
                return Expanded(
                  child: Tooltip(
                    message: tab.label,
                    child: InkWell(
                      onTap: () => onTabSelected(tab.id),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: active ? _accentBg : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _navIcon(tab, active, size: 22),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                tab.label,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: active
                                      ? const Color(0xFF1D4ED8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Общее ───────────────────────────────────────────────────────────────

  Widget _navIcon(NavItem tab, bool active, {double size = 22}) {
    final color = active ? const Color(0xFF1D4ED8) : const Color(0xFF64748B);
    if (tab.customIconPath != null) {
      return ImageIcon(AssetImage(tab.customIconPath!),
          color: color, size: size);
    }
    return Icon(
      active ? (tab.activeIcon ?? tab.icon) : tab.icon,
      color: color,
      size: size,
    );
  }

  Widget _avatar(String name, double size) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .map((s) => s.isNotEmpty ? s[0] : '')
            .take(2)
            .join()
            .toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: _accentBg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.bold,
          color: _accent,
        ),
      ),
    );
  }
}
