import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/equipment.dart';
import '../services/supabase_service.dart';

class EquipmentMaintenanceWidget extends StatefulWidget {
  final Equipment equipment;
  final VoidCallback onUpdated;

  const EquipmentMaintenanceWidget({
    super.key,
    required this.equipment,
    required this.onUpdated,
  });

  @override
  State<EquipmentMaintenanceWidget> createState() => _EquipmentMaintenanceWidgetState();
}

class _EquipmentMaintenanceWidgetState extends State<EquipmentMaintenanceWidget> {
  bool _isExpanded = false;
  bool _notificationsEnabled = true;
  bool _isSaving = false;
  DateTime? _selectedDate;

  int? get _maintenanceMonths {
    final specs = widget.equipment.specifications;
    if (specs != null && specs.containsKey('_maintenance_months')) {
      return int.tryParse(specs['_maintenance_months'].toString());
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final specs = widget.equipment.specifications;
    if (specs != null && specs.containsKey('_notifications_enabled')) {
      _notificationsEnabled = specs['_notifications_enabled'] == 'true';
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _savePurchaseDate() async {
    if (_selectedDate == null) return;
    
    setState(() => _isSaving = true);
    
    try {
      final updatedEq = widget.equipment.copyWith(purchaseDate: _selectedDate);
      await SupabaseService.updateEquipment(updatedEq);
      widget.onUpdated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка сохранения: \$e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
      _isSaving = true;
    });

    try {
      Map<String, dynamic> newSpecs = Map.from(widget.equipment.specifications ?? {});
      newSpecs['_notifications_enabled'] = value.toString();
      
      final updatedEq = widget.equipment.copyWith(specifications: newSpecs);
      await SupabaseService.updateEquipment(updatedEq);
      widget.onUpdated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка сохранения: \$e')),
      );
      setState(() => _notificationsEnabled = !value);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = _maintenanceMonths;
    if (months == null || months <= 0) {
      return const SizedBox.shrink(); // Не показываем, если периодичность не задана
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: (expanded) => setState(() => _isExpanded = expanded),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: Colors.orange,
              size: 20,
            ),
          ),
          title: const Text(
            'Техническое обслуживание',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          trailing: Icon(
            _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: Colors.grey,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.equipment.purchaseDate == null
                  ? _buildDateInputForm()
                  : _buildScheduleList(months),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateInputForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 16),
        const Text(
          'Введите пожалуйста дату покупки данного оборудования для составления графика ТО.',
          style: TextStyle(color: Colors.black87),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Дата реализации (покупки)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  child: Text(
                    _selectedDate != null
                        ? DateFormat('dd.MM.yyyy').format(_selectedDate!)
                        : 'Выберите дату',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isSaving ? null : _savePurchaseDate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Сохранить'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScheduleList(int months) {
    final purchaseDate = widget.equipment.purchaseDate!;
    
    // Генерируем следующие 5 дат ТО, которые еще не прошли
    List<DateTime> upcomingDates = [];
    DateTime currentDate = purchaseDate;
    
    // Сначала "догоняем" текущую дату, если оборудование старое
    final boundaryDate = DateTime.now().subtract(const Duration(days: 30));
    
    // Безопасный счетчик чтобы избежать бесконечного цикла, если что-то пойдет не так
    int maxCatchupIterations = 1000;
    while(currentDate.isBefore(boundaryDate) && maxCatchupIterations > 0) {
      currentDate = DateTime(currentDate.year, currentDate.month + months, currentDate.day);
      maxCatchupIterations--;
    }

    // Теперь добавляем следующие 5 дат
    for (int i = 0; i < 5; i++) {
        upcomingDates.add(currentDate);
        currentDate = DateTime(currentDate.year, currentDate.month + months, currentDate.day);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 16),
        Text(
          'График технического обслуживания (каждые $months мес.):',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: upcomingDates.asMap().entries.map((entry) {
              final isNext = entry.key == 0;
              final date = entry.value;
              return ListTile(
                dense: true,
                leading: Icon(
                  isNext ? Icons.notifications_active : Icons.event_available,
                  color: isNext ? Colors.orange : Colors.green,
                  size: 20,
                ),
                title: Text(
                  DateFormat('dd MMMM yyyy', 'ru').format(date),
                  style: TextStyle(
                    fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                    color: isNext ? Colors.black87 : Colors.grey[700],
                  ),
                ),
                trailing: isNext ? const Text('Ближайшее ТО', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)) : null,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Уведомлять о предстоящем ТО', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: const Text('Напоминание за 7 дней до даты обслуживания', style: TextStyle(fontSize: 12)),
          value: _notificationsEnabled,
          onChanged: _isSaving ? null : _toggleNotifications,
          activeThumbColor: const Color(0xFF3B82F6),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
