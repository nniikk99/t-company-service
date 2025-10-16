import 'package:flutter/material.dart';
import '../data/equipment_specifications.dart';

/// Виджет для отображения технических характеристик оборудования
class EquipmentSpecificationsWidget extends StatelessWidget {
  final String manufacturer;
  final String model;

  const EquipmentSpecificationsWidget({
    Key? key,
    required this.manufacturer,
    required this.model,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final specs = EquipmentSpecifications.getSpecifications(manufacturer, model);

    if (specs == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Технические характеристики пока не добавлены',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            const Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Color(0xFF3B82F6),
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Технические характеристики',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
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
            if (specs['weight'] != null)
              _buildSpecRow(
                icon: Icons.fitness_center,
                iconColor: Colors.grey,
                spec: specs['weight'],
              ),
            if (specs['dimensions'] != null)
              _buildSpecRow(
                icon: Icons.square_foot,
                iconColor: Colors.purple,
                spec: specs['dimensions'],
              ),
            
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            
            // Остальные характеристики (без иконок)
            if (specs['operatorPosition'] != null)
              _buildSimpleSpecRow(specs['operatorPosition']),
            if (specs['productivity'] != null)
              _buildSimpleSpecRow(specs['productivity']),
            if (specs['cleaningWidth'] != null)
              _buildSimpleSpecRow(specs['cleaningWidth']),
            if (specs['squeegeeWidth'] != null)
              _buildSimpleSpecRow(specs['squeegeeWidth']),
            if (specs['brushCount'] != null)
              _buildSimpleSpecRow(specs['brushCount']),
            if (specs['brushDiameter'] != null)
              _buildSimpleSpecRow(specs['brushDiameter']),
            if (specs['brushPressure'] != null)
              _buildSimpleSpecRow(specs['brushPressure']),
            if (specs['brushSpeed'] != null)
              _buildSimpleSpecRow(specs['brushSpeed']),
            if (specs['cleaningType'] != null)
              _buildSimpleSpecRow(specs['cleaningType']),
            if (specs['cleanWaterTank'] != null)
              _buildSimpleSpecRow(specs['cleanWaterTank']),
            if (specs['dirtyWaterTank'] != null)
              _buildSimpleSpecRow(specs['dirtyWaterTank']),
            if (specs['maxClimb'] != null)
              _buildSimpleSpecRow(specs['maxClimb']),
            if (specs['powerType'] != null)
              _buildSimpleSpecRow(specs['powerType']),
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

