import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/service_request.dart';
import '../models/equipment.dart';
import '../models/client.dart';
import '../services/storage_service.dart';

class AdminDashboard extends StatefulWidget {
  final User user;

  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isLoading = true;
  List<ServiceRequest> _requests = [];
  List<Equipment> _equipment = [];
  List<Client> _clients = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final requests = await StorageService.getRequests();
      final equipment = await StorageService.getEquipment();
      final clients = await StorageService.getClients();

      setState(() {
        _requests = requests;
        _equipment = equipment;
        _clients = clients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final pendingRequests = _requests.where((r) => r.status == RequestStatus.pending).length;
    final activeEquipment = _equipment.where((e) => e.status == EquipmentStatus.active).length;
    final completedRequests = _requests.where((r) => r.status == RequestStatus.completed).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Панель администратора',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Карточки статистики
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildStatsCard(
                'Заявок на согласовании',
                pendingRequests.toString(),
                Colors.orange,
                Icons.pending,
              ),
              _buildStatsCard(
                'Активного оборудования',
                activeEquipment.toString(),
                Colors.green,
                Icons.build,
              ),
              _buildStatsCard(
                'Клиентов',
                _clients.length.toString(),
                Colors.blue,
                Icons.business,
              ),
              _buildStatsCard(
                'Выполнено заявок',
                completedRequests.toString(),
                Colors.purple,
                Icons.check_circle,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Последние заявки
          Text(
            'Последние заявки',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView.builder(
              itemCount: _requests.take(5).length,
              itemBuilder: (context, index) {
                final request = _requests[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: _getStatusIcon(request.status),
                    title: Text(request.title),
                    subtitle: Text(
                      '${request.typeDisplayName} • ${request.statusDisplayName}',
                    ),
                    trailing: Text(
                      _formatDate(request.createdAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      // TODO: Открыть детали заявки
                    },
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
          mainAxisAlignment: MainAxisAlignment.center,
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

  Widget _getStatusIcon(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return const Icon(Icons.schedule, color: Colors.orange);
      case RequestStatus.approved:
        return const Icon(Icons.check_circle, color: Colors.green);
      case RequestStatus.rejected:
        return const Icon(Icons.cancel, color: Colors.red);
      case RequestStatus.inProgress:
        return const Icon(Icons.settings, color: Colors.blue);
      case RequestStatus.completed:
        return const Icon(Icons.check_circle_outline, color: Colors.green);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey);
    }
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
