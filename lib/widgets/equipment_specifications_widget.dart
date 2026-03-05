import 'package:flutter/material.dart';
import 'pdf_iframe_view.dart';

/// Виджет для отображения технических характеристик оборудования
class EquipmentSpecificationsWidget extends StatefulWidget {
  final String manufacturer;
  final String model;
  final Map<String, dynamic>? customSpecs;

  const EquipmentSpecificationsWidget({
    super.key,
    required this.manufacturer,
    required this.model,
    this.customSpecs,
  });

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

    final Map<String, dynamic> specs = rawSpecs;

    if (specs.isEmpty) {
      return const SizedBox.shrink();
    }

    final instructionUrl = specs['_instruction_url'] as String?;
    final manualUrl = specs['_manual_url'] as String?;

    return Column(
      children: [
        Card(
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
                  ...specs.entries
                      .where((e) => e.key != 'type' && e.value != null && e.value is Map) 
                      .map((e) => _buildSimpleSpecRow(Map<String, dynamic>.from(e.value as Map)))
                      ,
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    if (instructionUrl != null && instructionUrl.isNotEmpty)
      _buildDocAccordion('Инструкция по эксплуатации', Icons.menu_book, instructionUrl),
    if (manualUrl != null && manualUrl.isNotEmpty)
      _buildDocAccordion('Мануал', Icons.build_circle_outlined, manualUrl),
    ],
    );
  }

  Widget _buildDocAccordion(String title, IconData iconData, String url) {
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
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              iconData,
              color: const Color(0xFF3B82F6),
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PdfIframeView(url: url, label: title),
            ),
          ],
        ),
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
              '${spec['value']}${spec['unit'] != null && spec['unit'].toString().isNotEmpty ? ' ${spec['unit']}' : ''}',
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

