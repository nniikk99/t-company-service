import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/equipment.dart';
import '../services/storage_service.dart';
import '../widgets/create_request_form.dart';

class EquipmentScreen extends StatefulWidget {
  final User? user;
  
  const EquipmentScreen({super.key, this.user});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  bool _isLoading = true;
  List<Equipment> _equipment = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    try {
      // Загружаем оборудование только для текущей компании
      final filteredEquipment = await StorageService.getEquipment(companyId: widget.user?.companyId);

      setState(() {
        _equipment = filteredEquipment;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Equipment> get _filteredEquipment {
    if (_searchQuery.isEmpty) return _equipment;
    
    return _equipment.where((equipment) {
      return equipment.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             equipment.model.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             equipment.location.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оборудование'),
        actions: [
          if (widget.user?.role == UserRole.admin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                // TODO: Добавить новое оборудование
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Функция будет доступна в следующем обновлении')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Поиск оборудования...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Список оборудования
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEquipment.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.build, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Оборудование не найдено',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredEquipment.length,
                        itemBuilder: (context, index) {
                          final equipment = _filteredEquipment[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: _getStatusIcon(equipment.status),
                              title: Text(
                                equipment.fullTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('📍 ${equipment.location}'),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(equipment.status),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          equipment.statusDisplayName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (equipment.needsService) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'Требует ТО',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => _showEquipmentDetails(equipment),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: widget.user?.canCreateRequests == true
          ? FloatingActionButton(
              onPressed: () => _navigateToCreateRequest(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _getStatusIcon(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.active:
        return const Icon(Icons.check_circle, color: Colors.green);
      case EquipmentStatus.maintenance:
        return const Icon(Icons.build, color: Colors.orange);
      case EquipmentStatus.inactive:
        return const Icon(Icons.pause_circle, color: Colors.grey);
      case EquipmentStatus.broken:
        return const Icon(Icons.error, color: Colors.red);
    }
  }

  Color _getStatusColor(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.active:
        return Colors.green;
      case EquipmentStatus.maintenance:
        return Colors.orange;
      case EquipmentStatus.inactive:
        return Colors.grey;
      case EquipmentStatus.broken:
        return Colors.red;
    }
  }

  void _showEquipmentDetails(Equipment equipment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок
                Row(
                  children: [
                    _getStatusIcon(equipment.status),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        equipment.fullTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildDetailRow('Модель', equipment.model),
                      _buildDetailRow('Расположение', equipment.location),
                      _buildDetailRow('Адрес', equipment.address),
                      _buildDetailRow('Статус', equipment.statusDisplayName),
                      if (equipment.serialNumber != null)
                        _buildDetailRow('Серийный номер', equipment.serialNumber!),
                      if (equipment.lastServiceDate != null)
                        _buildDetailRow('Последнее ТО', _formatDate(equipment.lastServiceDate!)),
                      if (equipment.nextServiceDate != null)
                        _buildDetailRow('Следующее ТО', _formatDate(equipment.nextServiceDate!)),
                      
                      const SizedBox(height: 24),
                      
                      // Действия
                      if (widget.user?.canCreateRequests == true) ...[
                        const Text(
                          'Действия',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _navigateToCreateRequest(equipment: equipment);
                                },
                                icon: const Icon(Icons.build),
                                label: const Text('Ремонт'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _navigateToCreateRequest(equipment: equipment);
                                },
                                icon: const Icon(Icons.settings),
                                label: const Text('ТО'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _navigateToCreateRequest({Equipment? equipment}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateRequestForm(
          user: widget.user!,
          preselectedEquipment: equipment,
        ),
      ),
    ).then((success) {
      if (success == true) {
        _loadEquipment(); // Перезагружаем данные после создания заявки
      }
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}