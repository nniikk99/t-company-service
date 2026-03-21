import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/service_request.dart';
import '../models/equipment.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'create_request_form.dart';
import 'modern_card.dart';

class ContactDashboard extends StatefulWidget {
  final User user;

  const ContactDashboard({super.key, required this.user});

  @override
  State<ContactDashboard> createState() => _ContactDashboardState();
}

class _ContactDashboardState extends State<ContactDashboard> {
  bool _isLoading = true;
  List<ServiceRequest> _myRequests = [];
  List<Equipment> _myEquipment = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final allRequests = await StorageService.getRequests();
      final allEquipment = await StorageService.getEquipment();

      // Фильтруем только свои заявки
      final myRequests = allRequests
          .where((r) => r.userId == widget.user.id)
          .toList();
      
      // Фильтруем только назначенное оборудование
      List<Equipment> myEquipment = [];
      if (widget.user.equipmentIds != null) {
        myEquipment = allEquipment
            .where((e) => widget.user.equipmentIds!.contains(e.id))
            .toList();
      }

      setState(() {
        _myRequests = myRequests;
        _myEquipment = myEquipment;
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

    final pendingRequests = _myRequests.where((r) => r.status == RequestStatus.pending).length;
    final activeEquipment = _myEquipment.where((e) => e.status == EquipmentStatus.active).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Приветствие с градиентом
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Добро пожаловать!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user.firstName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.user.roleDisplayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Статистика
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: 'Мои заявки',
                  value: _myRequests.length.toString(),
                  icon: Icons.assignment_outlined,
                  color: AppTheme.infoColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatsCard(
                  title: 'Мое оборудование',
                  value: _myEquipment.length.toString(),
                  icon: Icons.precision_manufacturing_outlined,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Быстрые действия
          Text(
            'Быстрые действия',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          ActionCard(
            title: 'Создать заявку',
            subtitle: 'на ремонт или обслуживание',
            icon: Icons.add_circle_outline,
            color: AppTheme.primaryColor,
            onTap: () => _showCreateRequestDialog(),
          ),
          const SizedBox(height: 12),
          ActionCard(
            title: 'Мое оборудование',
            subtitle: 'просмотр и управление',
            icon: Icons.precision_manufacturing_outlined,
            color: AppTheme.successColor,
            onTap: () {
              // TODO: Перейти к оборудованию
            },
          ),

          const SizedBox(height: 24),

          // Последние заявки
          Text(
            'Мои последние заявки',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _myRequests.isEmpty
              ? ModernCard(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Icon(
                          Icons.assignment_outlined,
                          size: 32,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'У вас пока нет заявок',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Создайте первую заявку на обслуживание',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      GradientButton(
                        text: 'Создать заявку',
                        icon: Icons.add,
                        onPressed: () => _showCreateRequestDialog(),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: _myRequests.map((request) {
                    return ModernCard(
                      onTap: () {
                        // TODO: Открыть детали заявки
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _getStatusIcon(request.status),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  request.title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              StatusBadge(
                                text: request.statusDisplayName,
                                color: _getStatusColor(request.status),
                                small: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            request.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                _getTypeIcon(request.type),
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                request.typeDisplayName,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const Spacer(),
                              if (request.priority != RequestPriority.normal) ...[
                                StatusBadge(
                                  text: request.priorityDisplayName,
                                  color: _getPriorityColor(request.priority),
                                  small: true,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                _formatDate(request.createdAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
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

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getStatusIcon(RequestStatus status) {
    switch (status) {
      case RequestStatus.draft:
        return const Icon(Icons.edit_note, color: Colors.grey);
      case RequestStatus.pending:
        return const Icon(Icons.schedule, color: Colors.orange);
      case RequestStatus.approved:
        return const Icon(Icons.check_circle, color: Colors.blue);
      case RequestStatus.inProgress:
        return const Icon(Icons.settings, color: Colors.blueAccent);
      case RequestStatus.waitingForAcceptance:
        return const Icon(Icons.assignment_turned_in, color: Colors.orangeAccent);
      case RequestStatus.waitingForInvoice:
        return const Icon(Icons.receipt_long, color: Colors.purple);
      case RequestStatus.waitingForPayment:
        return const Icon(Icons.payments, color: Colors.teal);
      case RequestStatus.completed:
        return const Icon(Icons.check_circle_outline, color: Colors.green);
      case RequestStatus.rejected:
        return const Icon(Icons.cancel, color: Colors.red);
      case RequestStatus.cancelled:
        return const Icon(Icons.block, color: Colors.grey);
    }
  }

  Color _getPriorityColor(RequestPriority priority) {
    switch (priority) {
      case RequestPriority.low:
        return AppTheme.infoColor;
      case RequestPriority.normal:
        return Colors.grey;
      case RequestPriority.high:
        return AppTheme.warningColor;
      case RequestPriority.urgent:
        return AppTheme.errorColor;
    }
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.draft:
        return Colors.grey;
      case RequestStatus.pending:
        return AppTheme.warningColor;
      case RequestStatus.approved:
        return AppTheme.infoColor;
      case RequestStatus.inProgress:
        return AppTheme.primaryColor;
      case RequestStatus.waitingForAcceptance:
        return Colors.orangeAccent;
      case RequestStatus.waitingForInvoice:
        return Colors.purple;
      case RequestStatus.waitingForPayment:
        return Colors.teal;
      case RequestStatus.completed:
        return AppTheme.successColor;
      case RequestStatus.rejected:
      case RequestStatus.cancelled:
        return AppTheme.errorColor;
    }
  }

  IconData _getTypeIcon(RequestType type) {
    switch (type) {
      case RequestType.repair:
        return Icons.build_outlined;
      case RequestType.specialistVisit:
        return Icons.person_outline;
      case RequestType.partsOrder:
        return Icons.inventory_2_outlined;
      case RequestType.maintenance:
        return Icons.tune_outlined;
    }
  }

  void _showCreateRequestDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateRequestForm(user: widget.user),
      ),
    ).then((success) {
      if (success == true) {
        _loadData(); // Перезагружаем данные после создания заявки
      }
    });
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
