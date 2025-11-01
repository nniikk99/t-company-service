import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/service_request.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tab_navigation.dart';
import '../widgets/animated_card.dart';
import '../widgets/animated_status_badge.dart';
import '../widgets/assign_engineer_dialog.dart';

class RequestsListScreen extends StatefulWidget {
  final User user;

  const RequestsListScreen({super.key, required this.user});

  @override
  State<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends State<RequestsListScreen> {
  List<ServiceRequest> _requests = [];
  bool _isLoading = true;
  String? _selectedStatus;

  final List<String> _statuses = [
    'Все статусы',
    'Новая',
    'В работе',
    'Выполнено',
    'Отменено',
  ];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    
    try {
      List<ServiceRequest> filteredRequests;
      
      // Для поставщиков - загружаем заявки на их оборудование
      if (widget.user.role == UserRole.supplier) {
        filteredRequests = await SupabaseService.getSupplierRequests(widget.user.id);
      }
      // Для инженеров загружаем только назначенные заявки
      else if (widget.user.role == UserRole.engineer) {
        filteredRequests = await SupabaseService.getEngineerAssignedRequests(widget.user.id);
      }
      // Для создателей заявок (operatorPM, siteManager, companyResponsible)
      else if (widget.user.role == UserRole.operatorPM || 
               widget.user.role == UserRole.siteManager || 
               widget.user.role == UserRole.companyResponsible) {
        // Загружаем заявки, созданные этим пользователем
        filteredRequests = await SupabaseService.getUserServiceRequests(widget.user.id);
        // Преобразуем в ServiceRequest объекты
        filteredRequests = filteredRequests.map((json) {
          try {
            return ServiceRequest.fromJson(json);
          } catch (e) {
            print('⚠️ Ошибка парсинга заявки: $e');
            return null;
          }
        }).whereType<ServiceRequest>().toList();
      }
      // Для остальных ролей используем старую логику
      else {
        final allRequests = await StorageService.getRequests();
        
        // Фильтруем по роли пользователя
        filteredRequests = allRequests;
        if (widget.user.role == UserRole.contactPerson) {
          filteredRequests = allRequests.where((r) => 
            r.userId == widget.user.id).toList();
        } else if (widget.user.role == UserRole.clientResponsible) {
          filteredRequests = allRequests.where((r) => 
            r.clientId == widget.user.companyId).toList();
        }
      }
      
      setState(() {
        _requests = filteredRequests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки заявок: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.draft:
      case RequestStatus.pending:
        return Colors.orange;
      case RequestStatus.approved:
      case RequestStatus.inProgress:
        return AppTheme.primaryColor;
      case RequestStatus.completed:
        return Colors.green;
      case RequestStatus.rejected:
      case RequestStatus.cancelled:
        return Colors.red;
    }
  }

  String _getRequestId(ServiceRequest request) {
    return 'REQ-${request.id.toUpperCase().substring(0, 3)}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок и описание
          const Text(
            'Заявки',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Управление сервисными заявками\nи запросами на запчасти',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Фильтры
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Фильтр по статусу',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                FilterDropdown(
                  hint: 'Все статусы',
                  value: _selectedStatus,
                  items: _statuses,
                  onChanged: (value) => setState(() => _selectedStatus = value),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Фильтр по дате',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    'Выберите период',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Список заявок
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _requests.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: _requests.asMap().entries.map((entry) {
                        final index = entry.key;
                        final request = entry.value;
                        return FadeInWidget(
                          delay: Duration(milliseconds: index * 100),
                          child: SlideInWidget(
                            delay: Duration(milliseconds: index * 100),
                            child: _buildRequestCard(request),
                          ),
                        );
                      }).toList(),
                    ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(ServiceRequest request) {
    return AnimatedCard(
      onTap: () => _showRequestDetails(request),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок с ID и статусом
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getRequestId(request),
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              AnimatedStatusBadge(
                text: request.statusDisplayName,
                color: _getStatusColor(request.status),
                delay: Duration(milliseconds: 200),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Название и описание
          Text(
            request.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            request.typeDisplayName,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Информация внизу
          Row(
            children: [
              Text(
                'Дата: ${_formatDate(request.createdAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              const Spacer(),
              Text(
                'Ответственный: Петров В.И.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          
          // Кнопка "Назначить инженера" для поставщиков
          if (_canAssignEngineer(request)) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleAssignEngineer(request),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Назначить инженера'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          
          // Кнопки действий (только для определенных ролей)
          if (_canManageRequest(request)) ...[
            const SizedBox(height: 12),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showRequestActions(request),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Детали'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.grey[300],
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showRequestActions(request),
                    icon: const Icon(Icons.attachment_outlined, size: 16),
                    label: const Text('Файлы'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.grey[300],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, size: 20),
                  onSelected: (value) => _handleRequestAction(request, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'work',
                      child: Text('В работу'),
                    ),
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('Завершить'),
                    ),
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Отменить'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 40,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Нет заявок',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Заявки будут отображаться здесь',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canManageRequest(ServiceRequest request) {
    // Поставщики могут управлять заявками на свое оборудование
    if (widget.user.role == UserRole.supplier) {
      return request.supplierId == widget.user.id;
    }
    
    // Инженеры могут управлять только назначенными им заявками
    if (widget.user.role == UserRole.engineer) {
      return request.assignedEngineerId == widget.user.id;
    }
    
    // Создатели заявок могут управлять своими заявками
    if (widget.user.role == UserRole.operatorPM || 
        widget.user.role == UserRole.siteManager || 
        widget.user.role == UserRole.companyResponsible) {
      return request.userId == widget.user.id;
    }
    
    // Остальные роли используют старую логику
    return widget.user.canApproveRequests || widget.user.canManageClients;
  }

  bool _canAssignEngineer(ServiceRequest request) {
    // Поставщик может назначить инженера, если:
    // 1. Это его заявка
    // 2. Инженер еще не назначен
    // 3. Статус заявки позволяет назначение (pending или approved)
    if (widget.user.role == UserRole.supplier) {
      return request.supplierId == widget.user.id &&
             request.assignedEngineerId == null &&
             (request.status == RequestStatus.pending || 
              request.status == RequestStatus.approved);
    }
    return false;
  }

  void _handleAssignEngineer(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (context) => AssignEngineerDialog(
        requestId: request.id,
        supplierUserId: widget.user.id,
        onEngineerAssigned: () {
          _loadRequests(); // Перезагружаем список после назначения
        },
      ),
    );
  }

  void _showRequestDetails(ServiceRequest request) {
    // TODO: Открыть детали заявки
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Открыть детали заявки ${_getRequestId(request)}')),
    );
  }

  void _showRequestActions(ServiceRequest request) {
    // Для инженеров показываем специальные действия
    if (widget.user.role == UserRole.engineer) {
      _showEngineerActions(request);
    } else {
      // Для остальных ролей - стандартные действия
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Действия с заявкой')),
      );
    }
  }

  void _handleRequestAction(ServiceRequest request, String action) {
    switch (action) {
      case 'work':
        _startEngineerWork(request);
        break;
      case 'complete':
        _completeEngineerWork(request);
        break;
      case 'cancel':
        _cancelEngineerWork(request);
        break;
    }
  }

  void _showEngineerActions(ServiceRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Управление заявкой',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            
            // Кнопки действий в зависимости от статуса
            if (request.canEngineerStart) ...[
              _buildActionButton(
                'Начать работу',
                Icons.play_arrow,
                Colors.green,
                () => _startEngineerWork(request),
              ),
            ],
            
            if (request.canEngineerComplete) ...[
              _buildActionButton(
                'Завершить работу',
                Icons.check_circle,
                Colors.blue,
                () => _completeEngineerWork(request),
              ),
            ],
            
            if (request.status == RequestStatus.approved || request.status == RequestStatus.inProgress) ...[
              _buildActionButton(
                'Отменить заявку',
                Icons.cancel,
                Colors.red,
                () => _cancelEngineerWork(request),
              ),
            ],
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Future<void> _startEngineerWork(ServiceRequest request) async {
    try {
      await SupabaseService.startEngineerWork(request.id);
      Navigator.pop(context);
      _loadRequests();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Работа над заявкой начата'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeEngineerWork(ServiceRequest request) async {
    final commentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершить работу'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Добавьте комментарий о выполненной работе:'),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Описание выполненной работы...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SupabaseService.completeEngineerWork(request.id, commentController.text);
                Navigator.pop(context);
                Navigator.pop(context); // Закрываем bottom sheet
                _loadRequests();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Работа завершена'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ошибка: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelEngineerWork(ServiceRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить заявку'),
        content: const Text('Вы уверены, что хотите отменить эту заявку?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.updateRequestStatus(request.id, RequestStatus.cancelled);
        Navigator.pop(context); // Закрываем bottom sheet
        _loadRequests();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заявка отменена'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
