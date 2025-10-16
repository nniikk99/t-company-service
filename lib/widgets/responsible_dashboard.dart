import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/service_request.dart';
import '../models/equipment.dart';
import '../services/storage_service.dart';

class ResponsibleDashboard extends StatefulWidget {
  final User user;

  const ResponsibleDashboard({super.key, required this.user});

  @override
  State<ResponsibleDashboard> createState() => _ResponsibleDashboardState();
}

class _ResponsibleDashboardState extends State<ResponsibleDashboard> {
  bool _isLoading = true;
  List<ServiceRequest> _requests = [];
  List<Equipment> _equipment = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final allRequests = await StorageService.getRequests();
      final allEquipment = await StorageService.getEquipment();

      // Фильтруем только заявки клиента
      final clientRequests = allRequests
          .where((r) => r.clientId == widget.user.companyId)
          .toList();
      
      final clientEquipment = allEquipment
          .where((e) => e.clientId == widget.user.companyId)
          .toList();

      setState(() {
        _requests = clientRequests;
        _equipment = clientEquipment;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _approveRequest(ServiceRequest request) async {
    try {
      final allRequests = await StorageService.getRequests();
      final updatedRequests = allRequests.map((r) {
        if (r.id == request.id) {
          return r.copyWith(
            status: RequestStatus.approved,
            approvedByUserId: widget.user.id,
            approvedAt: DateTime.now(),
          );
        }
        return r;
      }).toList();

      await StorageService.saveRequest(updatedRequests.first);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заявка одобрена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка при одобрении заявки'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(ServiceRequest request, String reason) async {
    try {
      final allRequests = await StorageService.getRequests();
      final updatedRequests = allRequests.map((r) {
        if (r.id == request.id) {
          return r.copyWith(
            status: RequestStatus.rejected,
            rejectionReason: reason,
          );
        }
        return r;
      }).toList();

      await StorageService.saveRequest(updatedRequests.first);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заявка отклонена'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка при отклонении заявки'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final pendingRequests = _requests.where((r) => r.status == RequestStatus.pending).toList();
    final activeEquipment = _equipment.where((e) => e.status == EquipmentStatus.active).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Панель ответственного лица',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Статистика
          Row(
            children: [
              Expanded(
                child: _buildStatsCard(
                  'Ожидают согласования',
                  pendingRequests.length.toString(),
                  Colors.orange,
                  Icons.pending_actions,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatsCard(
                  'Активного оборудования',
                  activeEquipment.toString(),
                  Colors.green,
                  Icons.build,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Заявки на согласование
          Text(
            'Заявки на согласование',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: pendingRequests.isEmpty
                ? const Center(
                    child: Text(
                      'Нет заявок на согласование',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: pendingRequests.length,
                    itemBuilder: (context, index) {
                      final request = pendingRequests[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      request.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getPriorityColor(request.priority),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      request.priorityDisplayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                request.description,
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${request.typeDisplayName} • ${_formatDate(request.createdAt)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _approveRequest(request),
                                      icon: const Icon(Icons.check),
                                      label: const Text('Одобрить'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showRejectDialog(request),
                                      icon: const Icon(Icons.close),
                                      label: const Text('Отклонить'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(String title, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(RequestPriority priority) {
    switch (priority) {
      case RequestPriority.low:
        return Colors.grey;
      case RequestPriority.normal:
        return Colors.blue;
      case RequestPriority.high:
        return Colors.orange;
      case RequestPriority.urgent:
        return Colors.red;
    }
  }

  void _showRejectDialog(ServiceRequest request) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отклонить заявку'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Укажите причину отклонения заявки "${request.title}"'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Причина отклонения',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty) {
                Navigator.pop(context);
                _rejectRequest(request, reasonController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Отклонить'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}д назад';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}ч назад';
    } else {
      return '${difference.inMinutes}м назад';
    }
  }
}
