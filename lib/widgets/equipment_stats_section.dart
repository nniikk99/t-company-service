import 'package:flutter/material.dart';
import '../models/equipment.dart';
import '../models/service_request.dart';
import '../services/supabase_service.dart';

/// Раскрывающийся раздел «Статистика по машине».
///
/// Собирает по конкретной единице техники:
///   • сколько дней была активна / в ремонте / не использовалась
///     (из таблицы equipment_status_history);
///   • сколько денег затрачено (сумма по закрытым заявкам);
///   • сколько сервисных заявок отработано и по каким причинам.
///
/// Цель — дать владельцу полную картину по машине, чтобы решить:
/// брать ещё такую же или выбрать другую модель.
class EquipmentStatsSection extends StatefulWidget {
  final Equipment equipment;
  const EquipmentStatsSection({super.key, required this.equipment});

  @override
  State<EquipmentStatsSection> createState() => _EquipmentStatsSectionState();
}

class _EquipmentStatsSectionState extends State<EquipmentStatsSection> {
  bool _loading = true;
  bool _loaded = false; // данные подгружаются лениво при первом раскрытии

  // Дни по периодам
  int _activeDays = 0;
  int _repairDays = 0;
  int _unusedDays = 0;

  // Заявки
  int _reqTotal = 0;
  int _reqCompleted = 0;
  double _totalSpent = 0;
  final Map<RequestType, int> _byType = {};

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final id = widget.equipment.id;
      final results = await Future.wait([
        SupabaseService.getEquipmentStatusHistory(id),
        SupabaseService.getEquipmentServiceRequests(id),
      ]);
      _computeDays(results[0] as List<Map<String, dynamic>>);
      _computeRequests(results[1] as List<ServiceRequest>);
    } catch (_) {
      // мягкая деградация — покажем то, что удалось
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _bucket(String status) {
    switch (status) {
      case 'active':
        return 'active';
      case 'maintenance':
      case 'broken':
        return 'repair';
      default:
        return 'unused'; // inactive и неизвестные
    }
  }

  void _computeDays(List<Map<String, dynamic>> hist) {
    final now = DateTime.now();
    double activeSec = 0, repairSec = 0, unusedSec = 0;

    DateTime? parse(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    if (hist.isNotEmpty) {
      for (int i = 0; i < hist.length; i++) {
        final start = parse(hist[i]['started_at']);
        if (start == null) continue;
        final end = (i + 1 < hist.length ? parse(hist[i + 1]['started_at']) : now) ?? now;
        final sec = end.difference(start).inSeconds.toDouble();
        if (sec <= 0) continue;
        switch (_bucket(hist[i]['status']?.toString() ?? '')) {
          case 'active':
            activeSec += sec;
            break;
          case 'repair':
            repairSec += sec;
            break;
          default:
            unusedSec += sec;
        }
      }
    } else {
      // Истории нет (миграция не применена / новая запись) —
      // показываем хотя бы текущий статус по status_changed_at.
      final days = widget.equipment.daysInCurrentStatus ?? 0;
      final sec = days * 86400.0;
      final dbStatus = widget.equipment.status.toString().split('.').last;
      switch (_bucket(dbStatus)) {
        case 'active':
          activeSec = sec;
          break;
        case 'repair':
          repairSec = sec;
          break;
        default:
          unusedSec = sec;
      }
    }

    _activeDays = (activeSec / 86400).round();
    _repairDays = (repairSec / 86400).round();
    _unusedDays = (unusedSec / 86400).round();
  }

  void _computeRequests(List<ServiceRequest> reqs) {
    _reqTotal = reqs.length;
    _reqCompleted = reqs.where((r) => r.isCompleted).length;
    _byType.clear();
    double spent = 0;
    for (final r in reqs) {
      _byType[r.type] = (_byType[r.type] ?? 0) + 1;
      if (r.isCompleted) {
        final amount = r.invoiceAmount ?? r.estimatedCost ?? 0;
        spent += amount;
      }
    }
    _totalSpent = spent;
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: (open) {
            if (open) _ensureLoaded();
          },
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.insights_outlined,
                color: Color(0xFF3B82F6), size: 20),
          ),
          title: const Text(
            'Статистика по машине',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          subtitle: const Text(
            'Наработка, простои, затраты, заявки',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final totalDays = _activeDays + _repairDays + _unusedDays;
    final uptime = totalDays > 0
        ? (_activeDays / totalDays * 100).round()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 16),

        // ── Распределение времени ──
        Row(
          children: [
            const Text('Время по статусам',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155))),
            const Spacer(),
            if (uptime != null)
              Text('Загрузка $uptime%',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A))),
          ],
        ),
        const SizedBox(height: 10),
        _timeBar(totalDays),
        const SizedBox(height: 12),
        _legendRow(const Color(0xFF16A34A), 'Активна', _activeDays),
        const SizedBox(height: 6),
        _legendRow(const Color(0xFFF59E0B), 'В ремонте', _repairDays),
        const SizedBox(height: 6),
        _legendRow(const Color(0xFF94A3B8), 'Не используется', _unusedDays),

        const SizedBox(height: 18),

        // ── Деньги и заявки ──
        Row(
          children: [
            Expanded(
              child: _statTile(
                icon: Icons.payments_outlined,
                color: const Color(0xFF3B82F6),
                label: 'Затрачено',
                value: _money(_totalSpent),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statTile(
                icon: Icons.task_alt_outlined,
                color: const Color(0xFF16A34A),
                label: 'Заявок закрыто',
                value: '$_reqCompleted из $_reqTotal',
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // ── Причины обращений ──
        const Text('Обращения по причинам',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155))),
        const SizedBox(height: 10),
        if (_reqTotal == 0)
          const Text('Обращений по этой машине пока не было',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)))
        else
          ..._buildReasonRows(),
      ],
    );
  }

  /// Горизонтальная стопка-бар по трём периодам.
  Widget _timeBar(int totalDays) {
    if (totalDays <= 0) {
      return Container(
        height: 14,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: const Text('Нет данных о наработке',
            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
      );
    }
    int flexOf(int d) => d <= 0 ? 0 : d;
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        height: 14,
        child: Row(
          children: [
            if (_activeDays > 0)
              Expanded(
                  flex: flexOf(_activeDays),
                  child: Container(color: const Color(0xFF16A34A))),
            if (_repairDays > 0)
              Expanded(
                  flex: flexOf(_repairDays),
                  child: Container(color: const Color(0xFFF59E0B))),
            if (_unusedDays > 0)
              Expanded(
                  flex: flexOf(_unusedDays),
                  child: Container(color: const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(Color color, String label, int days) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
        ),
        Text(Equipment.daysWord(days),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  List<Widget> _buildReasonRows() {
    // Порядок и оформление причин
    const order = [
      RequestType.repair,
      RequestType.maintenance,
      RequestType.partsOrder,
      RequestType.specialistVisit,
    ];
    Color colorOf(RequestType t) {
      switch (t) {
        case RequestType.repair:
          return const Color(0xFFEF4444);
        case RequestType.maintenance:
          return const Color(0xFF3B82F6);
        case RequestType.partsOrder:
          return const Color(0xFF8B5CF6);
        case RequestType.specialistVisit:
          return const Color(0xFF0EA5E9);
      }
    }

    String nameOf(RequestType t) {
      switch (t) {
        case RequestType.repair:
          return 'Ремонт';
        case RequestType.maintenance:
          return 'Техобслуживание';
        case RequestType.partsOrder:
          return 'Заказ запчастей';
        case RequestType.specialistVisit:
          return 'Вызов специалиста';
      }
    }

    final maxCount = _byType.values.isEmpty
        ? 1
        : _byType.values.reduce((a, b) => a > b ? a : b);

    final rows = <Widget>[];
    for (final t in order) {
      final count = _byType[t] ?? 0;
      if (count == 0) continue;
      final color = colorOf(t);
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Text(nameOf(t),
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF475569))),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: count / maxCount,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('$count',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
          ],
        ),
      ));
    }
    return rows;
  }

  String _money(num v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${buf.toString()} ₽';
  }
}
