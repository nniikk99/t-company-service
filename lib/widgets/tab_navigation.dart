import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TabNavigationItem {
  final String title;
  final bool isActive;
  final VoidCallback onTap;
  final IconData? icon;

  TabNavigationItem({
    required this.title,
    required this.isActive,
    required this.onTap,
    this.icon,
  });
}

class TabNavigation extends StatelessWidget {
  final List<TabNavigationItem> items;
  
  const TabNavigation({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: items.map((item) {
          return Expanded(
            child: GestureDetector(
              onTap: item.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: item.isActive ? AppTheme.primaryColor.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.icon != null) ...[
                      Icon(
                        item.icon,
                        color: item.isActive ? AppTheme.primaryColor : Colors.grey[400],
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: item.isActive ? AppTheme.primaryColor : Colors.grey[600],
                        fontSize: item.icon != null ? 10 : 14,
                        fontWeight: item.isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FilterDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const FilterDropdown({
    super.key,
    required this.hint,
    this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Softer light-blue gray
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(
            hint,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: Colors.grey[600],
            size: 20,
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class StatusBadgeNew extends StatelessWidget {
  final String text;
  final Color color;
  final bool outlined;

  const StatusBadgeNew({
    super.key,
    required this.text,
    required this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(12),
        border: outlined ? Border.all(color: color, width: 1) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: outlined ? color : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class EquipmentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const EquipmentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Placeholder для фото оборудования
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.precision_manufacturing_outlined,
                    color: Colors.grey[400],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadgeNew(
                  text: status,
                  color: statusColor,
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
