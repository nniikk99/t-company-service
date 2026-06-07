import 'package:flutter/material.dart';
import '../models/equipment.dart';
import '../services/supabase_service.dart';

/// Контрол статуса оборудования: цветной индикатор + длительность в текущем
/// статусе + тумблер для быстрого включения/выключения.
///
///   • Включение  → статус «Активно».
///   • Выключение → спрашиваем причину: «В ремонте» (maintenance) или
///                  «Не используется» (inactive).
///
/// Меняет статус в Supabase, оптимистично обновляет UI и сообщает наверх через
/// [onChanged], чтобы родитель мог перезагрузить список карточек.
class EquipmentStatusControl extends StatefulWidget {
  final Equipment equipment;
  final bool canChange;
  final ValueChanged<EquipmentStatus>? onChanged;

  const EquipmentStatusControl({
    super.key,
    required this.equipment,
    this.canChange = false,
    this.onChanged,
  });

  @override
  State<EquipmentStatusControl> createState() => _EquipmentStatusControlState();
}

class _EquipmentStatusControlState extends State<EquipmentStatusControl> {
  late EquipmentStatus _status;
  DateTime? _changedAt;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = widget.equipment.status;
    _changedAt = widget.equipment.statusChangedAt;
  }

  bool get _isActive => _status == EquipmentStatus.active;

  Color get _color {
    switch (_status) {
      case EquipmentStatus.active:
        return const Color(0xFF16A34A);
      case EquipmentStatus.maintenance:
        return const Color(0xFFF59E0B);
      case EquipmentStatus.broken:
        return const Color(0xFFEF4444);
      case EquipmentStatus.inactive:
        return const Color(0xFF94A3B8);
    }
  }

  String get _label {
    switch (_status) {
      case EquipmentStatus.active:
        return 'Активно';
      case EquipmentStatus.maintenance:
        return 'В ремонте';
      case EquipmentStatus.broken:
        return 'Неисправно';
      case EquipmentStatus.inactive:
        return 'Не используется';
    }
  }

  /// «Активно · 23 дня» — длительность нахождения в текущем статусе.
  String get _durationText {
    if (_changedAt == null) return _label;
    final days = DateTime.now().difference(_changedAt!).inDays;
    final d = days < 0 ? 0 : days;
    return '$_label · ${Equipment.daysWord(d)}';
  }

  String _statusToDb(EquipmentStatus s) => s.toString().split('.').last;

  Future<void> _onToggle(bool turnOn) async {
    if (turnOn) {
      await _apply(EquipmentStatus.active);
      return;
    }
    // Выключение — спрашиваем причину
    final reason = await _askReason();
    if (reason != null) {
      await _apply(reason);
    }
  }

  Future<EquipmentStatus?> _askReason() {
    return showModalBottomSheet<EquipmentStatus>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Почему выключаем?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _reasonTile(
                ctx,
                icon: Icons.build_circle_outlined,
                color: const Color(0xFFF59E0B),
                title: 'В ремонте',
                subtitle: 'Техника на обслуживании или в ремонте',
                value: EquipmentStatus.maintenance,
              ),
              _reasonTile(
                ctx,
                icon: Icons.pause_circle_outline,
                color: const Color(0xFF94A3B8),
                title: 'Не используется',
                subtitle: 'Простаивает, временно не эксплуатируется',
                value: EquipmentStatus.inactive,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _reasonTile(
    BuildContext ctx, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required EquipmentStatus value,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  Future<void> _apply(EquipmentStatus status) async {
    if (status == _status) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.updateEquipmentStatus(
          widget.equipment.id, _statusToDb(status));
      if (!mounted) return;
      setState(() {
        _status = status;
        _changedAt = DateTime.now();
        _busy = false;
      });
      widget.onChanged?.call(status);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось изменить статус: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _color,
                  ),
                ),
                if (_changedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _durationText,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
          ),
          if (widget.canChange)
            _busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch.adaptive(
                    value: _isActive,
                    activeColor: const Color(0xFF16A34A),
                    onChanged: (v) => _onToggle(v),
                  )
          else
            // Только просмотр — показываем компактный бейдж без тумблера
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _isActive ? 'вкл' : 'выкл',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
