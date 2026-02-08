import 'package:flutter/material.dart';
import '../data/equipment_specifications.dart';

/// Виджет для отображения технических характеристик оборудования
class EquipmentSpecificationsWidget extends StatefulWidget {
  final String manufacturer;
  final String model;
  final Map<String, dynamic>? customSpecs;

  const EquipmentSpecificationsWidget({
    Key? key,
    required this.manufacturer,
    required this.model,
    this.customSpecs,
  }) : super(key: key);

  @override
  State<EquipmentSpecificationsWidget> createState() => _EquipmentSpecificationsWidgetState();
}

class _EquipmentSpecificationsWidgetState extends State<EquipmentSpecificationsWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final rawSpecs = widget.customSpecs;

    if (rawSpecs == null || rawSpecs.isEmpty) {
      return const SizedBox.shrink();
    }

    // Фильтруем характеристики по шаблону (показываем только то, что есть в эталоне)
    final template = EquipmentSpecifications.getTypeTemplate(''); // Берем базовый шаблон
    final Map<String, dynamic> specs = {};
    
    rawSpecs.forEach((key, value) {
      if (template.containsKey(key)) {
        specs[key] = value;
      }
    });

    if (specs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Color(0xFF3B82F6),
              size: 20,
            ),
          ),
          title: const Text(
            'Технические характеристики',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, thickness: 1),
                  const SizedBox(height: 16),
                  
                  // Основные характеристики (с иконками)
                  if (specs['power'] != null)
                    _buildSpecRow(
                      icon: Icons.flash_on,
                      iconColor: Colors.orange,
                      spec: specs['power'],
                    ),
                  if (specs['voltage'] != null)
                    _buildSpecRow(
                      icon: Icons.electrical_services,
                      iconColor: Colors.blue,
                      spec: specs['voltage'],
                    ),
                  if (specs['warranty'] != null)
                    _buildSpecRow(
                      icon: Icons.verified_user_outlined,
                      iconColor: Colors.teal,
                      spec: specs['warranty'],
                    ),
                  if (specs['dimensions'] != null)
                    _buildSpecRow(
                      icon: Icons.square_foot,
                      iconColor: Colors.purple,
                      spec: specs['dimensions'],
                    ),
                  
                  if (specs['power'] != null || specs['voltage'] != null || specs['weight'] != null || specs['dimensions'] != null) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1, thickness: 0.5),
                    const SizedBox(height: 16),
                  ],
                  
                  // Остальные характеристики (без иконок)
                  ...specs.entries
                      .where((e) => !['power', 'voltage', 'warranty', 'dimensions', 'type'].contains(e.key))
                      .map((e) => _buildSimpleSpecRow(e.value))
                      .toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Строка с иконкой для основных характеристик
  Widget _buildSpecRow({
    required IconData icon,
    required Color iconColor,
    required Map<String, dynamic> spec,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec['label'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${spec['value']}${spec['unit'].isNotEmpty ? ' ${spec['unit']}' : ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Простая строка без иконки для остальных характеристик
  Widget _buildSimpleSpecRow(Map<String, dynamic> spec) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              spec['label'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${spec['value']}${spec['unit'].isNotEmpty ? ' ${spec['unit']}' : ''}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

