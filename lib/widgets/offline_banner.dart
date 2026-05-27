import 'package:flutter/material.dart';
import '../services/offline_queue_service.dart';

/// Тонкий баннер, который показывается над контентом экрана,
/// когда нет сети ИЛИ есть pending операции в очереди.
///
/// Использование:
/// ```
/// Scaffold(
///   body: Column(children: [const OfflineBanner(), ...rest])
/// )
/// ```
class OfflineBanner extends StatefulWidget {
  /// Если задан — отображает счётчик именно по этой заявке/заказу.
  /// Если null — показывает общий счётчик очереди.
  final String? requestId;

  const OfflineBanner({super.key, this.requestId});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _online = OfflineQueueService.instance.isOnline;
  int _pending = OfflineQueueService.instance.pendingCount;

  @override
  void initState() {
    super.initState();
    OfflineQueueService.instance.onlineStream.listen((v) {
      if (mounted) setState(() => _online = v);
    });
    OfflineQueueService.instance.pendingCountStream.listen((n) {
      if (mounted) setState(() => _pending = n);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ничего показывать не нужно: онлайн и очередь пуста
    if (_online && _pending == 0) return const SizedBox.shrink();

    if (!_online) {
      return _bar(
        bg: const Color(0xFFFEF3C7),
        border: const Color(0xFFFCD34D),
        icon: Icons.wifi_off_rounded,
        iconColor: const Color(0xFFB45309),
        text: _pending > 0
            ? 'Нет связи · $_pending ${_word(_pending)} сохранится локально'
            : 'Нет связи · изменения сохраняются локально',
        textColor: const Color(0xFF92400E),
      );
    }

    // Онлайн, но есть pending — синхронизируем
    return _bar(
      bg: const Color(0xFFEFF6FF),
      border: const Color(0xFFBFDBFE),
      icon: Icons.sync_rounded,
      iconColor: const Color(0xFF2563EB),
      text:
          'Синхронизация · $_pending ${_word(_pending)} ${_pending == 1 ? "ожидает" : "ожидают"} отправки',
      textColor: const Color(0xFF1E3A8A),
      withSpinner: true,
      onTap: () => OfflineQueueService.instance.flush(),
    );
  }

  Widget _bar({
    required Color bg,
    required Color border,
    required IconData icon,
    required Color iconColor,
    required String text,
    required Color textColor,
    bool withSpinner = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: border),
            ),
          ),
          child: Row(
            children: [
              if (withSpinner)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(iconColor),
                  ),
                )
              else
                Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _word(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'изменение';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'изменения';
    }
    return 'изменений';
  }
}

/// Маленький бейдж-индикатор pending для use в списках или AppBar.
class OfflinePendingBadge extends StatefulWidget {
  const OfflinePendingBadge({super.key});

  @override
  State<OfflinePendingBadge> createState() => _OfflinePendingBadgeState();
}

class _OfflinePendingBadgeState extends State<OfflinePendingBadge> {
  int _pending = OfflineQueueService.instance.pendingCount;
  bool _online = OfflineQueueService.instance.isOnline;

  @override
  void initState() {
    super.initState();
    OfflineQueueService.instance.pendingCountStream.listen((n) {
      if (mounted) setState(() => _pending = n);
    });
    OfflineQueueService.instance.onlineStream.listen((v) {
      if (mounted) setState(() => _online = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pending == 0) return const SizedBox.shrink();
    final color =
        _online ? const Color(0xFF3B82F6) : const Color(0xFFEA580C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _online ? Icons.sync_rounded : Icons.cloud_off_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$_pending',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color),
          ),
        ],
      ),
    );
  }
}
