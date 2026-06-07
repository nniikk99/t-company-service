import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user.dart' as AppUserModel;
import '../models/service_request.dart';
import '../services/supabase_service.dart';
import '../utils/responsive.dart';

/// Аналитика — единая точка входа. Внутри роутит на нужный дашборд по роли.
///
/// Дизайн-принципы:
///   - Один скроллируемый список карточек, никаких тяжёлых графиков
///   - Период вверху (7д / 30д / 90д / Всё), пересчёт всех метрик
///   - KPI-карточки 2×N в шапке
///   - Ниже секции: распределения, топы, инсайты
///   - Согласован со стилем приложения (карточки, голубой акцент, тёмные иконки)
class AnalyticsScreen extends StatefulWidget {
  final AppUserModel.User user;

  const AnalyticsScreen({super.key, required this.user});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _Period _period = _Period.days30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _PeriodSelector(
              value: _period,
              onChanged: (p) => setState(() => _period = p),
            ),
            Expanded(
              child: _buildDashboard(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Хедер ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final role = widget.user.role;
    final (title, subtitle) = switch (role) {
      AppUserModel.UserRole.administrator => (
          'Аналитика платформы',
          'Глобальная картина'
        ),
      AppUserModel.UserRole.supplier => (
          'Аналитика',
          'Заказы, выручка, команда'
        ),
      AppUserModel.UserRole.engineer => (
          'Моя статистика',
          'Заявки, рейтинг, заработок'
        ),
      _ => ('Аналитика', 'Техника, заявки и затраты'),
    };

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              )),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  // ── Роутинг по роли ─────────────────────────────────────────────────────

  Widget _buildDashboard() {
    switch (widget.user.role) {
      case AppUserModel.UserRole.administrator:
        return _AdminDashboard(user: widget.user, period: _period);
      case AppUserModel.UserRole.supplier:
        return _SupplierDashboard(user: widget.user, period: _period);
      case AppUserModel.UserRole.engineer:
        return _EngineerDashboard(user: widget.user, period: _period);
      default:
        return _ClientDashboard(user: widget.user, period: _period);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Период
// ════════════════════════════════════════════════════════════════════════════

enum _Period { days7, days30, days90, all }

extension _PeriodExt on _Period {
  String get label => switch (this) {
        _Period.days7 => '7 дней',
        _Period.days30 => '30 дней',
        _Period.days90 => '90 дней',
        _Period.all => 'Всё время',
      };

  /// DateTime начала периода, или null если "всё время"
  DateTime? get since {
    final now = DateTime.now();
    return switch (this) {
      _Period.days7 => now.subtract(const Duration(days: 7)),
      _Period.days30 => now.subtract(const Duration(days: 30)),
      _Period.days90 => now.subtract(const Duration(days: 90)),
      _Period.all => null,
    };
  }
}

class _PeriodSelector extends StatelessWidget {
  final _Period value;
  final ValueChanged<_Period> onChanged;
  const _PeriodSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            for (final p in _Period.values)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: value == p ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: value == p
                          ? [
                              const BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: value == p
                              ? const Color(0xFF1E293B)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Общие виджеты
// ════════════════════════════════════════════════════════════════════════════

/// KPI-карточка: иконка, метка, значение, опциональный подзаголовок.
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? subtitle;
  const _KpiCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, color.withOpacity(0.06)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: const TextStyle(
                    fontSize: 10.5, color: Color(0xFF94A3B8))),
          ]
        ],
      ),
    );
  }
}

/// Кольцевая диаграмма (donut) — рисуется через CustomPainter, без библиотек.
class _DonutChart extends StatelessWidget {
  final List<_BreakdownItem> items;
  final double size;
  final String? centerValue;
  final String? centerLabel;
  const _DonutChart({
    required this.items,
    this.size = 140,
    this.centerValue,
    this.centerLabel,
  });

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (s, i) => s + i.value);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(items: items, total: total),
          ),
          if (centerValue != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(centerValue!,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A))),
                if (centerLabel != null)
                  Text(centerLabel!,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_BreakdownItem> items;
  final double total;
  _DonutPainter({required this.items, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.16;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    if (total <= 0) {
      final bg = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0xFFF1F5F9);
      canvas.drawCircle(center, radius, bg);
      return;
    }

    double startAngle = -1.5708; // -90° сверху
    const gap = 0.04; // зазор между сегментами в радианах
    for (final item in items) {
      final sweep = (item.value / total) * 6.2832 - gap;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = item.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.items != items || old.total != total;
}

/// Распределение с кольцевой диаграммой + легендой.
/// На широком экране — donut слева, легенда справа; на узком — donut сверху.
class _DonutBreakdown extends StatelessWidget {
  final List<_BreakdownItem> items;
  final String? centerLabel;
  const _DonutBreakdown({required this.items, this.centerLabel});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Нет данных',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
      );
    }
    final total = items.fold<double>(0, (s, i) => s + i.value);
    final donut = _DonutChart(
      items: items,
      size: 132,
      centerValue: total == total.roundToDouble()
          ? total.toInt().toString()
          : total.toStringAsFixed(0),
      centerLabel: centerLabel,
    );
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _legendRow(items[i], total),
          if (i < items.length - 1) const SizedBox(height: 8),
        ]
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 380) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              donut,
              const SizedBox(width: 20),
              Expanded(child: legend),
            ],
          );
        }
        return Column(
          children: [
            donut,
            const SizedBox(height: 16),
            legend,
          ],
        );
      },
    );
  }

  Widget _legendRow(_BreakdownItem item, double total) {
    final pct = total > 0 ? (item.value / total * 100) : 0;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(item.label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Text(item.valueLabel,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: item.color)),
        const SizedBox(width: 6),
        Text('${pct.toStringAsFixed(0)}%',
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF94A3B8))),
      ],
    );
  }
}

/// Адаптивная раскладка KPI-карточек.
/// На широком экране — 4 в ряд, на узком — 2 в ряд. Высоту карточки задаёт сама.
Widget _kpiGrid(List<Widget> cards) {
  return LayoutBuilder(
    builder: (context, c) {
      final cols = c.maxWidth >= 760 ? 4 : 2;
      const gap = 10.0;
      final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: cards
            .map((card) => SizedBox(width: cardW, child: card))
            .toList(),
      );
    },
  );
}

/// Заголовок секции с опциональной подписью.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  const _SectionHeader(this.title, {this.subtitle, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B))),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка для содержимого секции.
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}

/// Распределение по категориям — горизонтальные бары.
class _BreakdownList extends StatelessWidget {
  final List<_BreakdownItem> items;
  final String? emptyText;
  const _BreakdownList({required this.items, this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          emptyText ?? 'Нет данных',
          style:
              const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        ),
      );
    }
    final max = items.map((e) => e.value).fold<double>(0, (a, b) => b > a ? b : a);
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _BreakdownRow(item: items[i], max: max),
          if (i < items.length - 1) const SizedBox(height: 10),
        ]
      ],
    );
  }
}

class _BreakdownItem {
  final String label;
  final double value;
  final String valueLabel;
  final Color color;
  final IconData? icon;
  const _BreakdownItem({
    required this.label,
    required this.value,
    required this.valueLabel,
    this.color = const Color(0xFF3B82F6),
    this.icon,
  });
}

class _BreakdownRow extends StatelessWidget {
  final _BreakdownItem item;
  final double max;
  const _BreakdownRow({required this.item, required this.max});

  @override
  Widget build(BuildContext context) {
    final ratio = max > 0 ? (item.value / max).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, size: 14, color: item.color),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(item.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Text(item.valueLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                )),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: item.color.withOpacity(0.10),
            valueColor: AlwaysStoppedAnimation(item.color),
          ),
        ),
      ],
    );
  }
}

/// Пустое состояние для дашборда.
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _EmptyState(
      {required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF3B82F6)),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B))),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF64748B))),
            ]
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Хелперы агрегации
// ════════════════════════════════════════════════════════════════════════════

/// Считает сумму выручки/затрат за период из ServiceRequest списка.
/// Берёт estimated_cost для сервисных заявок и parts_order_details.total_amount для заказов запчастей.
double _sumRevenue(List<ServiceRequest> reqs) {
  double total = 0;
  for (final r in reqs) {
    if (r.type == RequestType.partsOrder) {
      final details = r.partsOrderDetails ?? const {};
      total += (details['total_amount'] as num?)?.toDouble() ?? 0;
    } else {
      total += r.estimatedCost ?? 0;
    }
  }
  return total;
}

/// Форматирует число с разделителями ('1 234 567').
String _fmt(num n) {
  final s = n.toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _money(num n) => '${_fmt(n)} ₽';

/// Фильтрует заявки по периоду.
List<ServiceRequest> _filterByPeriod(
    List<ServiceRequest> source, _Period period) {
  final since = period.since;
  if (since == null) return source;
  return source.where((r) => r.createdAt.isAfter(since)).toList();
}

/// Группировка для топ-N (по моделям, площадкам, поставщикам и т.п.).
class _TopAgg {
  int count = 0;
  double sum = 0;
  void add({int c = 1, double s = 0}) {
    count += c;
    sum += s;
  }
}

List<MapEntry<String, _TopAgg>> _topByKey(
  List<ServiceRequest> reqs,
  String Function(ServiceRequest) keyFn, {
  int limit = 5,
  bool bySum = false,
}) {
  final map = <String, _TopAgg>{};
  for (final r in reqs) {
    final k = keyFn(r);
    if (k.isEmpty) continue;
    final agg = map.putIfAbsent(k, () => _TopAgg());
    double s = 0;
    if (r.type == RequestType.partsOrder) {
      s = ((r.partsOrderDetails ?? const {})['total_amount'] as num?)
              ?.toDouble() ??
          0;
    } else {
      s = r.estimatedCost ?? 0;
    }
    agg.add(c: 1, s: s);
  }
  final list = map.entries.toList();
  list.sort((a, b) =>
      bySum ? b.value.sum.compareTo(a.value.sum) : b.value.count.compareTo(a.value.count));
  return list.take(limit).toList();
}

// ════════════════════════════════════════════════════════════════════════════
// Клиентский дашборд
// ════════════════════════════════════════════════════════════════════════════

class _ClientDashboard extends StatefulWidget {
  final AppUserModel.User user;
  final _Period period;
  const _ClientDashboard({required this.user, required this.period});

  @override
  State<_ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<_ClientDashboard> {
  bool _loading = true;
  List<ServiceRequest> _all = [];
  int _equipmentCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ClientDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // период меняется — пересчитываем фильтрацию, данные не перезагружаем
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Все заявки клиента (сервис + заказы запчастей) — мерж уже в SupabaseService
      List<Map<String, dynamic>> json;
      if (widget.user.role == AppUserModel.UserRole.companyResponsible ||
          widget.user.role == AppUserModel.UserRole.siteManager) {
        final profile =
            await SupabaseService.getUserProfile(widget.user.id);
        final inn = profile?['company_inn'];
        json = inn != null && inn.toString().isNotEmpty
            ? await SupabaseService.getCompanyRequestsByInn(inn)
            : await SupabaseService.getUserServiceRequests(widget.user.id);
      } else {
        json = await SupabaseService.getUserServiceRequests(widget.user.id);
      }
      _all = json
          .map((j) {
            try {
              return ServiceRequest.fromJson(j);
            } catch (_) {
              return null;
            }
          })
          .whereType<ServiceRequest>()
          .toList();

      // Кол-во техники
      try {
        final equip = await SupabaseService.getUserEquipment(widget.user);
        _equipmentCount = equip.length;
      } catch (_) {
        _equipmentCount = 0;
      }
    } catch (_) {
      // оставляем пустые
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final inPeriod = _filterByPeriod(_all, widget.period);
    final services = inPeriod.where((r) => r.type != RequestType.partsOrder).toList();
    final orders = inPeriod.where((r) => r.type == RequestType.partsOrder).toList();
    final activeRequests = _all
        .where((r) =>
            r.status != RequestStatus.completed &&
            r.status != RequestStatus.cancelled &&
            r.status != RequestStatus.rejected)
        .toList();
    final activeOrders = activeRequests
        .where((r) => r.type == RequestType.partsOrder)
        .toList();
    final activeServices = activeRequests
        .where((r) => r.type != RequestType.partsOrder)
        .toList();

    final totalSpend = _sumRevenue(inPeriod);
    final ordersSpend = _sumRevenue(orders);
    final servicesSpend = _sumRevenue(services);

    if (_all.isEmpty && _equipmentCount == 0) {
      return const _EmptyState(
        icon: Icons.analytics_outlined,
        title: 'Пока нет данных',
        subtitle:
            'Здесь появится статистика когда вы\nдобавите технику и оформите заявки',
      );
    }

    return CenteredContent(
      maxWidth: 1100,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // KPI — 4 в ряд на десктопе, 2x2 на мобильном
        _kpiGrid([
          _KpiCard(
            icon: Icons.precision_manufacturing_outlined,
            color: const Color(0xFF3B82F6),
            label: 'Техника',
            value: '$_equipmentCount',
            subtitle: 'в эксплуатации',
          ),
          _KpiCard(
            icon: Icons.engineering_outlined,
            color: const Color(0xFFEA580C),
            label: 'Открытых заявок',
            value: '${activeServices.length}',
            subtitle: 'на сервис',
          ),
          _KpiCard(
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFF8B5CF6),
            label: 'Заказы ЗЧ',
            value: '${activeOrders.length}',
            subtitle: 'в работе',
          ),
          _KpiCard(
            icon: Icons.payments_outlined,
            color: const Color(0xFF16A34A),
            label: 'Затраты',
            value: totalSpend > 0 ? _money(totalSpend) : '—',
            subtitle: 'за ${widget.period.label.toLowerCase()}',
          ),
        ]),

        // Разбивка затрат
        if (totalSpend > 0) ...[
          const _SectionHeader('Структура затрат',
              icon: Icons.donut_small_outlined),
          _Card(
            child: _DonutBreakdown(items: [
              _BreakdownItem(
                label: 'Сервис и выезды',
                value: servicesSpend,
                valueLabel: _money(servicesSpend),
                color: const Color(0xFF3B82F6),
                icon: Icons.engineering_outlined,
              ),
              _BreakdownItem(
                label: 'Запчасти',
                value: ordersSpend,
                valueLabel: _money(ordersSpend),
                color: const Color(0xFF8B5CF6),
                icon: Icons.inventory_2_outlined,
              ),
            ]),
          ),
        ],

        // Распределение заявок по статусам
        if (inPeriod.isNotEmpty) ...[
          const _SectionHeader('Заявки по статусам',
              subtitle: 'за выбранный период',
              icon: Icons.pie_chart_outline_rounded),
          _Card(
            child: _DonutBreakdown(
                items: _statusBreakdown(inPeriod), centerLabel: 'всего'),
          ),
        ],

        // Топ-моделей по обращениям
        if (inPeriod.isNotEmpty) ...[
          const _SectionHeader('Самые «горячие» модели',
              subtitle: 'по количеству обращений',
              icon: Icons.local_fire_department_outlined),
          _Card(
            child: _BreakdownList(
              items: _topByKey(
                inPeriod,
                (r) => r.equipmentModel ?? '',
              ).map((e) {
                return _BreakdownItem(
                  label: e.key,
                  value: e.value.count.toDouble(),
                  valueLabel:
                      '${e.value.count} обр.${e.value.sum > 0 ? ' · ${_money(e.value.sum)}' : ''}',
                  color: const Color(0xFFEA580C),
                );
              }).toList(),
            ),
          ),
        ],

        // Топ-площадок по затратам
        if (servicesSpend + ordersSpend > 0) ...[
          const _SectionHeader('Затраты по площадкам',
              icon: Icons.location_on_outlined),
          _Card(
            child: _BreakdownList(
              emptyText: 'Площадки не указаны',
              items: _topByKey(
                inPeriod,
                (r) => r.siteName ?? '',
                bySum: true,
              ).map((e) {
                return _BreakdownItem(
                  label: e.key,
                  value: e.value.sum,
                  valueLabel: _money(e.value.sum),
                  color: const Color(0xFF16A34A),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 24),
        _FooterNote(period: widget.period),
      ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Инженер
// ════════════════════════════════════════════════════════════════════════════

class _EngineerDashboard extends StatefulWidget {
  final AppUserModel.User user;
  final _Period period;
  const _EngineerDashboard({required this.user, required this.period});

  @override
  State<_EngineerDashboard> createState() => _EngineerDashboardState();
}

class _EngineerDashboardState extends State<_EngineerDashboard> {
  bool _loading = true;
  List<ServiceRequest> _all = [];
  double _rating = 0;
  int _ratingCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _all = await SupabaseService.getEngineerAssignedRequests(widget.user.id);
      final profile = await SupabaseService.getUserProfile(widget.user.id);
      _rating = (profile?['average_rating'] as num?)?.toDouble() ?? 0;
      _ratingCount = (profile?['rating_count'] as num?)?.toInt() ?? 0;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_all.isEmpty) {
      return const _EmptyState(
        icon: Icons.assignment_outlined,
        title: 'Пока нет назначенных заявок',
        subtitle: 'Когда вам назначат заявку,\nона появится здесь',
      );
    }

    final inPeriod = _filterByPeriod(_all, widget.period);
    final active = _all
        .where((r) =>
            r.status != RequestStatus.completed &&
            r.status != RequestStatus.cancelled &&
            r.status != RequestStatus.rejected)
        .toList();
    final completed = inPeriod
        .where((r) => r.status == RequestStatus.completed)
        .toList();
    final earned = _sumRevenue(completed);

    return CenteredContent(
      maxWidth: 1100,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _kpiGrid([
          _KpiCard(
            icon: Icons.work_outline,
            color: const Color(0xFFEA580C),
            label: 'Активных заявок',
            value: '${active.length}',
            subtitle: 'в работе',
          ),
          _KpiCard(
            icon: Icons.task_alt_rounded,
            color: const Color(0xFF16A34A),
            label: 'Выполнено',
            value: '${completed.length}',
            subtitle: 'за ${widget.period.label.toLowerCase()}',
          ),
          _KpiCard(
            icon: Icons.payments_outlined,
            color: const Color(0xFF3B82F6),
            label: 'Заработано',
            value: earned > 0 ? _money(earned) : '—',
            subtitle: 'за период',
          ),
          _KpiCard(
            icon: Icons.star_rounded,
            color: const Color(0xFFFACC15),
            label: 'Рейтинг',
            value: _rating > 0 ? _rating.toStringAsFixed(1) : '—',
            subtitle: '$_ratingCount ${_ratingsWord(_ratingCount)}',
          ),
        ]),

        if (inPeriod.isNotEmpty) ...[
          const _SectionHeader('Заявки по статусам',
              subtitle: 'за выбранный период',
              icon: Icons.pie_chart_outline_rounded),
          _Card(
            child: _DonutBreakdown(
                items: _statusBreakdown(inPeriod), centerLabel: 'всего'),
          ),
        ],

        if (inPeriod.isNotEmpty) ...[
          const _SectionHeader('Где чаще работаешь',
              subtitle: 'топ моделей по обращениям',
              icon: Icons.precision_manufacturing_outlined),
          _Card(
            child: _BreakdownList(
              items: _topByKey(
                inPeriod,
                (r) => r.equipmentModel ?? '',
              ).map((e) {
                return _BreakdownItem(
                  label: e.key,
                  value: e.value.count.toDouble(),
                  valueLabel: '${e.value.count} заявок',
                  color: const Color(0xFF3B82F6),
                );
              }).toList(),
            ),
          ),
        ],

        if (inPeriod.isNotEmpty) ...[
          const _SectionHeader('По площадкам',
              icon: Icons.location_on_outlined),
          _Card(
            child: _BreakdownList(
              emptyText: 'Не указано',
              items: _topByKey(
                inPeriod,
                (r) => r.siteName ?? '',
              ).map((e) {
                return _BreakdownItem(
                  label: e.key,
                  value: e.value.count.toDouble(),
                  valueLabel: '${e.value.count} заявок',
                  color: const Color(0xFF8B5CF6),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 24),
        _FooterNote(period: widget.period),
      ],
      ),
    );
  }

  String _ratingsWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'оценка';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'оценки';
    }
    return 'оценок';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Поставщик
// ════════════════════════════════════════════════════════════════════════════

class _SupplierDashboard extends StatefulWidget {
  final AppUserModel.User user;
  final _Period period;
  const _SupplierDashboard({required this.user, required this.period});

  @override
  State<_SupplierDashboard> createState() => _SupplierDashboardState();
}

class _SupplierDashboardState extends State<_SupplierDashboard> {
  bool _loading = true;
  List<ServiceRequest> _all = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _all = await SupabaseService.getSupplierRequests(widget.user.id);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_all.isEmpty) {
      return const _EmptyState(
        icon: Icons.business_center_outlined,
        title: 'Пока нет заявок',
        subtitle:
            'Когда клиенты начнут оформлять заказы\nи заявки, здесь появится статистика',
      );
    }

    final inPeriod = _filterByPeriod(_all, widget.period);
    final services =
        inPeriod.where((r) => r.type != RequestType.partsOrder).toList();
    final orders =
        inPeriod.where((r) => r.type == RequestType.partsOrder).toList();
    final activeRequests = _all
        .where((r) =>
            r.status != RequestStatus.completed &&
            r.status != RequestStatus.cancelled &&
            r.status != RequestStatus.rejected)
        .toList();
    final activeServices = activeRequests
        .where((r) => r.type != RequestType.partsOrder)
        .toList();
    final activeOrders = activeRequests
        .where((r) => r.type == RequestType.partsOrder)
        .toList();
    final revenue = _sumRevenue(inPeriod);
    final ordersRevenue = _sumRevenue(orders);
    final servicesRevenue = _sumRevenue(services);
    final uniqueClients = inPeriod
        .map((r) => r.companyName ?? r.creatorName ?? r.userId)
        .toSet()
        .length;

    return CenteredContent(
      maxWidth: 1100,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _kpiGrid([
          _KpiCard(
            icon: Icons.payments_outlined,
            color: const Color(0xFF16A34A),
            label: 'Оборот',
            value: revenue > 0 ? _money(revenue) : '—',
            subtitle: 'за ${widget.period.label.toLowerCase()}',
          ),
          _KpiCard(
            icon: Icons.people_alt_outlined,
            color: const Color(0xFF8B5CF6),
            label: 'Клиентов',
            value: '$uniqueClients',
            subtitle: 'обратилось',
          ),
          _KpiCard(
            icon: Icons.engineering_outlined,
            color: const Color(0xFFEA580C),
            label: 'Сервис',
            value:
                '${activeServices.length}/${_all.where((r) => r.type != RequestType.partsOrder).length}',
            subtitle: 'активных / всего',
          ),
          _KpiCard(
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFF3B82F6),
            label: 'Заказы ЗЧ',
            value:
                '${activeOrders.length}/${_all.where((r) => r.type == RequestType.partsOrder).length}',
            subtitle: 'активных / всего',
          ),
        ]),

        // Структура выручки
        if (revenue > 0) ...[
          const _SectionHeader('Структура выручки',
              icon: Icons.donut_small_outlined),
          _Card(
            child: _DonutBreakdown(items: [
              _BreakdownItem(
                label: 'Сервис и выезды',
                value: servicesRevenue,
                valueLabel: _money(servicesRevenue),
                color: const Color(0xFFEA580C),
                icon: Icons.engineering_outlined,
              ),
              _BreakdownItem(
                label: 'Запчасти',
                value: ordersRevenue,
                valueLabel: _money(ordersRevenue),
                color: const Color(0xFF3B82F6),
                icon: Icons.inventory_2_outlined,
              ),
            ]),
          ),
        ],

        // Распределение всех обращений по статусам
        if (inPeriod.isNotEmpty) ...[
          const _SectionHeader('Все обращения по статусам',
              subtitle: 'за выбранный период',
              icon: Icons.pie_chart_outline_rounded),
          _Card(
            child: _DonutBreakdown(
                items: _statusBreakdown(inPeriod), centerLabel: 'всего'),
          ),
        ],

        // Топ моделей по обращениям/заказам
        if (inPeriod.isNotEmpty) ...[
          const _SectionHeader('Топ моделей',
              subtitle: 'по количеству обращений',
              icon: Icons.local_fire_department_outlined),
          _Card(
            child: _BreakdownList(
              items: _topByKey(inPeriod, (r) => r.equipmentModel ?? '')
                  .map((e) => _BreakdownItem(
                        label: e.key,
                        value: e.value.count.toDouble(),
                        valueLabel:
                            '${e.value.count} обр.${e.value.sum > 0 ? ' · ${_money(e.value.sum)}' : ''}',
                        color: const Color(0xFFEA580C),
                      ))
                  .toList(),
            ),
          ),
        ],

        // Топ клиентов по выручке
        if (revenue > 0) ...[
          const _SectionHeader('Топ клиентов',
              subtitle: 'по сумме обращений',
              icon: Icons.workspace_premium_outlined),
          _Card(
            child: _BreakdownList(
              items: _topByKey(
                inPeriod,
                (r) => r.companyName ?? r.creatorName ?? '—',
                bySum: true,
              )
                  .map((e) => _BreakdownItem(
                        label: e.key,
                        value: e.value.sum,
                        valueLabel: _money(e.value.sum),
                        color: const Color(0xFF16A34A),
                      ))
                  .toList(),
            ),
          ),
        ],

        const SizedBox(height: 24),
        _FooterNote(period: widget.period),
      ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Админ
// ════════════════════════════════════════════════════════════════════════════

class _AdminDashboard extends StatefulWidget {
  final AppUserModel.User user;
  final _Period period;
  const _AdminDashboard({required this.user, required this.period});

  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<_AdminDashboard> {
  bool _loading = true;
  List<ServiceRequest> _all = [];
  Map<String, int> _usersByRole = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final json = await SupabaseService.getAllServiceRequests();
      _all = json
          .map((j) {
            try {
              return ServiceRequest.fromJson(j);
            } catch (_) {
              return null;
            }
          })
          .whereType<ServiceRequest>()
          .toList();

      // Считаем пользователей по ролям
      try {
        final usersJson = await SupabaseService.getAllUsers();
        final map = <String, int>{};
        for (final u in usersJson) {
          final role = (u['role'] ?? '').toString();
          if (role.isEmpty) continue;
          map[role] = (map[role] ?? 0) + 1;
        }
        _usersByRole = map;
      } catch (_) {}
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final inPeriod = _filterByPeriod(_all, widget.period);
    final totalUsers = _usersByRole.values.fold<int>(0, (a, b) => a + b);
    final totalRevenue = _sumRevenue(inPeriod);
    final active = _all
        .where((r) =>
            r.status != RequestStatus.completed &&
            r.status != RequestStatus.cancelled &&
            r.status != RequestStatus.rejected)
        .length;
    final completed = inPeriod
        .where((r) => r.status == RequestStatus.completed)
        .length;

    if (_all.isEmpty && totalUsers == 0) {
      return const _EmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'Платформа пока пуста',
        subtitle: 'Когда появятся пользователи и заявки,\nстатистика будет здесь',
      );
    }

    return CenteredContent(
      maxWidth: 1100,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _kpiGrid([
          _KpiCard(
            icon: Icons.groups_outlined,
            color: const Color(0xFF3B82F6),
            label: 'Пользователей',
            value: '$totalUsers',
            subtitle: 'на платформе',
          ),
          _KpiCard(
            icon: Icons.payments_outlined,
            color: const Color(0xFF16A34A),
            label: 'Оборот платформы',
            value: totalRevenue > 0 ? _money(totalRevenue) : '—',
            subtitle: 'за ${widget.period.label.toLowerCase()}',
          ),
          _KpiCard(
            icon: Icons.bolt_outlined,
            color: const Color(0xFFEA580C),
            label: 'Активных',
            value: '$active',
            subtitle: 'в работе',
          ),
          _KpiCard(
            icon: Icons.task_alt_rounded,
            color: const Color(0xFF8B5CF6),
            label: 'Завершено',
            value: '$completed',
            subtitle: 'за период',
          ),
        ]),

        if (_usersByRole.isNotEmpty) ...[
          const _SectionHeader('Пользователи по ролям',
              icon: Icons.groups_2_outlined),
          _Card(
            child: _DonutBreakdown(
              centerLabel: 'польз.',
              items: _usersByRole.entries
                  .map((e) => _BreakdownItem(
                        label: _roleLabel(e.key),
                        value: e.value.toDouble(),
                        valueLabel: '${e.value}',
                        color: _roleColor(e.key),
                      ))
                  .toList()
                ..sort((a, b) => b.value.compareTo(a.value)),
            ),
          ),
        ],

        if (inPeriod.isNotEmpty) ...[
          const _SectionHeader('Заявки по статусам',
              subtitle: 'за выбранный период',
              icon: Icons.pie_chart_outline_rounded),
          _Card(
            child: _DonutBreakdown(
                items: _statusBreakdown(inPeriod), centerLabel: 'всего'),
          ),
        ],

        if (inPeriod.isNotEmpty) ...[
          const _SectionHeader('Самые востребованные модели',
              icon: Icons.local_fire_department_outlined),
          _Card(
            child: _BreakdownList(
              items: _topByKey(inPeriod, (r) => r.equipmentModel ?? '')
                  .map((e) => _BreakdownItem(
                        label: e.key,
                        value: e.value.count.toDouble(),
                        valueLabel: '${e.value.count} обр.',
                        color: const Color(0xFFEA580C),
                      ))
                  .toList(),
            ),
          ),
        ],

        if (totalRevenue > 0) ...[
          const _SectionHeader('Топ компаний-клиентов',
              subtitle: 'по обороту',
              icon: Icons.workspace_premium_outlined),
          _Card(
            child: _BreakdownList(
              items: _topByKey(
                inPeriod,
                (r) => r.companyName ?? r.creatorName ?? '—',
                bySum: true,
              )
                  .map((e) => _BreakdownItem(
                        label: e.key,
                        value: e.value.sum,
                        valueLabel: _money(e.value.sum),
                        color: const Color(0xFF16A34A),
                      ))
                  .toList(),
            ),
          ),
        ],

        const SizedBox(height: 24),
        _FooterNote(period: widget.period),
      ],
      ),
    );
  }

  String _roleLabel(String r) {
    switch (r) {
      case 'administrator':
      case 'superAdmin':
        return 'Администраторы';
      case 'supplier':
        return 'Поставщики';
      case 'engineer':
        return 'Инженеры';
      case 'companyResponsible':
        return 'Ответственные лица';
      case 'siteManager':
        return 'Менеджеры площадок';
      case 'operatorPM':
        return 'Операторы ПМ';
      case 'contactPerson':
        return 'Контактные лица';
      default:
        return r;
    }
  }

  Color _roleColor(String r) {
    switch (r) {
      case 'administrator':
      case 'superAdmin':
        return const Color(0xFFEF4444);
      case 'supplier':
        return const Color(0xFF8B5CF6);
      case 'engineer':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF16A34A);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Статус-распределение и подвал
// ════════════════════════════════════════════════════════════════════════════

List<_BreakdownItem> _statusBreakdown(List<ServiceRequest> reqs) {
  final byStatus = <RequestStatus, int>{};
  for (final r in reqs) {
    byStatus[r.status] = (byStatus[r.status] ?? 0) + 1;
  }
  final order = [
    RequestStatus.pending,
    RequestStatus.approved,
    RequestStatus.inProgress,
    RequestStatus.waitingForAcceptance,
    RequestStatus.completed,
    RequestStatus.cancelled,
    RequestStatus.rejected,
  ];
  final result = <_BreakdownItem>[];
  for (final s in order) {
    final n = byStatus[s] ?? 0;
    if (n == 0) continue;
    result.add(_BreakdownItem(
      label: _statusLabel(s),
      value: n.toDouble(),
      valueLabel: '$n',
      color: _statusColor(s),
    ));
  }
  return result;
}

String _statusLabel(RequestStatus s) {
  switch (s) {
    case RequestStatus.pending:
      return 'Новые';
    case RequestStatus.approved:
      return 'Подтверждены';
    case RequestStatus.inProgress:
      return 'В работе';
    case RequestStatus.waitingForAcceptance:
      return 'Ожидают приёмки';
    case RequestStatus.waitingForInvoice:
      return 'Ожидают счёт';
    case RequestStatus.waitingForPayment:
      return 'Ожидают оплаты';
    case RequestStatus.completed:
      return 'Выполнены';
    case RequestStatus.cancelled:
      return 'Отменены';
    case RequestStatus.rejected:
      return 'Отклонены';
    default:
      return s.toString().split('.').last;
  }
}

Color _statusColor(RequestStatus s) {
  switch (s) {
    case RequestStatus.pending:
    case RequestStatus.draft:
      return const Color(0xFF3B82F6);
    case RequestStatus.approved:
    case RequestStatus.inProgress:
    case RequestStatus.waitingForAcceptance:
      return const Color(0xFFEA580C);
    case RequestStatus.waitingForInvoice:
    case RequestStatus.waitingForPayment:
      return const Color(0xFF8B5CF6);
    case RequestStatus.completed:
      return const Color(0xFF16A34A);
    case RequestStatus.rejected:
    case RequestStatus.cancelled:
      return const Color(0xFFEF4444);
  }
}

class _FooterNote extends StatelessWidget {
  final _Period period;
  const _FooterNote({required this.period});

  @override
  Widget build(BuildContext context) {
    final dateRange = period.since == null
        ? 'за всё время'
        : 'с ${DateFormat('dd.MM.yyyy').format(period.since!)} '
            'по ${DateFormat('dd.MM.yyyy').format(DateTime.now())}';
    return Center(
      child: Text(
        'Данные обновляются в реальном времени · $dateRange',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
      ),
    );
  }
}
