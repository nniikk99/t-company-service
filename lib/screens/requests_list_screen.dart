import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/service_request.dart';
import '../services/supabase_service.dart';
import '../widgets/animated_card.dart';
import '../widgets/animated_status_badge.dart';
import '../widgets/assign_engineer_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class RequestsListScreen extends StatefulWidget {
  final User user;

  const RequestsListScreen({super.key, required this.user});

  @override
  State<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends State<RequestsListScreen> {
  List<ServiceRequest> _requests = [];
  List<ServiceRequest> _availableRequests = [];
  bool _isLoading = true;
  String? _selectedStatus;
  bool _showAvailableMode = false;

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
        
        final available = await SupabaseService.getAvailableServiceRequests(widget.user);
        if (mounted) {
          setState(() {
            _availableRequests = available;
          });
        }
      }
      // Для ответственных лиц компании - только заявки их компании по ИНН
      else if (widget.user.role == UserRole.companyResponsible ||
               widget.user.role == UserRole.siteManager) {
        final profile = await SupabaseService.getUserProfile(widget.user.id);
        final inn = profile?['company_inn'];
        
        final requestsJson = inn != null 
            ? await SupabaseService.getCompanyRequestsByInn(inn)
            : await SupabaseService.getUserServiceRequests(widget.user.id);
            
        filteredRequests = requestsJson.map((json) {
          try {
            return ServiceRequest.fromJson(json);
          } catch (e) {
            print('⚠️ Ошибка парсинга заявки (INN-filter): $e');
            return null;
          }
        }).whereType<ServiceRequest>().toList();
      }
      // Для админов - всё без фильтров
      else if (widget.user.role == UserRole.superAdmin || 
               widget.user.role == UserRole.administrator) {
        final requestsJson = await SupabaseService.getAllServiceRequests();
        filteredRequests = requestsJson.map((json) {
          try {
            return ServiceRequest.fromJson(json);
          } catch (e) {
            return null;
          }
        }).whereType<ServiceRequest>().toList();
      }
      // Для операторов и контактных лиц - только свои
      else if (widget.user.role == UserRole.operatorPM || 
               widget.user.role == UserRole.contactPerson) {
        final requestsJson = await SupabaseService.getUserServiceRequests(widget.user.id);
        filteredRequests = requestsJson.map((json) {
          try {
            return ServiceRequest.fromJson(json);
          } catch (e) {
            print('⚠️ Ошибка парсинга заявки (user): $e');
            return null;
          }
        }).whereType<ServiceRequest>().toList();
      }
      // Для админов - всё
      else if (widget.user.role == UserRole.superAdmin || 
               widget.user.role == UserRole.administrator) {
        final requestsJson = await SupabaseService.getAllServiceRequests();
        filteredRequests = requestsJson.map((json) {
          try {
            return ServiceRequest.fromJson(json);
          } catch (e) {
            return null;
          }
        }).whereType<ServiceRequest>().toList();
      }
      // Для остальных ролей (инженеры, поставщики и т.д. обрабатываются выше)
      else {
        filteredRequests = [];
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
        return const Color(0xFF2563EB); // Blue
      case RequestStatus.approved:
      case RequestStatus.inProgress:
        return const Color(0xFFEA580C); // Orange
      case RequestStatus.completed:
        return const Color(0xFF16A34A); // Green
      case RequestStatus.rejected:
      case RequestStatus.cancelled:
        return const Color(0xFFEF4444); // Red
    }
  }

  String _getRequestId(ServiceRequest request) {
    if (request.id.length > 5) {
      return '#${request.id.substring(0, 5).toUpperCase()}';
    }
    return '#${request.id.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                children: [
                  const Text(
                    'Заявки',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'История и статус сервисных работ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (widget.user.role == UserRole.engineer)
                    _buildEngineerTabs(),
                  const SizedBox(height: 24),
                  if ((_showAvailableMode ? _availableRequests : _requests).isEmpty)
                    _buildEmptyState()
                  else
                    ...(_showAvailableMode ? _availableRequests : _requests).asMap().entries.map((entry) {
                      final index = entry.key;
                      final request = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: AnimatedCard(
                          onTap: () => _showRequestDetails(request),
                          child: _buildRequestCard(request),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildEngineerTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
             child: GestureDetector(
               onTap: () => setState(() => _showAvailableMode = false),
               child: Container(
                 padding: const EdgeInsets.symmetric(vertical: 12),
                 decoration: BoxDecoration(
                   color: !_showAvailableMode ? Colors.white : Colors.transparent,
                   borderRadius: BorderRadius.circular(8),
                   boxShadow: !_showAvailableMode ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                 ),
                 alignment: Alignment.center,
                 child: Text('Мои заявки (${_requests.length})', style: TextStyle(fontWeight: FontWeight.bold, color: !_showAvailableMode ? Colors.blue : Colors.grey[600])),
               )
             )
          ),
          Expanded(
             child: GestureDetector(
               onTap: () => setState(() => _showAvailableMode = true),
               child: Container(
                 padding: const EdgeInsets.symmetric(vertical: 12),
                 decoration: BoxDecoration(
                   color: _showAvailableMode ? Colors.white : Colors.transparent,
                   borderRadius: BorderRadius.circular(8),
                   boxShadow: _showAvailableMode ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                 ),
                 alignment: Alignment.center,
                 child: Text('Доступные (${_availableRequests.length})', style: TextStyle(fontWeight: FontWeight.bold, color: _showAvailableMode ? Colors.blue : Colors.grey[600])),
               )
             )
          ),
        ]
      )
    );
  }

  Widget _buildRequestCard(ServiceRequest request) {
    return AnimatedCard(
      onTap: () => _showRequestDetails(request),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Верхняя часть: ID, Дата и Статус
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getRequestId(request),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8), // Slate 400
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(request.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              AnimatedStatusBadge(
                text: request.statusDisplayName,
                color: _getStatusColor(request.status),
                delay: const Duration(milliseconds: 200),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Название оборудования и модель
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.equipmentName ?? request.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (request.equipmentModel != null)
                Text(
                  request.equipmentModel!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),

          
          const SizedBox(height: 4),
          
          // Серийный номер
          if (request.serialNumber != null)
            Text(
              'S/N: ${request.serialNumber}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B), // Slate 500
              ),
            ),
          
          const SizedBox(height: 12),
          
          // Местоположение (Площадка)
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  request.siteName ?? 'Местоположение не указано',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          
          // Нижняя часть: Ответственный / Инженер
          Row(
            children: [
              _buildAvatar(request.engineerName ?? 'НЕ НАЗНАЧЕН'),
              const SizedBox(width: 8),
              Text(
                request.engineerName ?? 'НЕ НАЗНАЧЕН',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: request.engineerName != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
            ],
          ),
          
          if (_showAvailableMode && request.status == RequestStatus.pending) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleTakeRequest(request),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('ВЗЯТЬ ЗАЯВКУ В РАБОТУ', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Future<void> _handleTakeRequest(ServiceRequest request) async {
    setState(() => _isLoading = true);
    final success = await SupabaseService.takeServiceRequest(request.id, widget.user.id);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Вы успешно взяли заявку в работу!'), backgroundColor: Colors.green));
        setState(() => _showAvailableMode = false); // Переключаем на "мои заявки"
        _loadRequests();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заявку уже кто-то взял до вас.'), backgroundColor: Colors.red));
        _loadRequests();
      }
    }
  }

  Widget _buildAvatar(String name) {
    final initials = name == 'НЕ НАЗНАЧЕН' 
        ? '?' 
        : name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join('').toUpperCase();
    
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: name == 'НЕ НАЗНАЧЕН' ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: name == 'НЕ НАЗНАЧЕН' ? const Color(0xFF94A3B8) : const Color(0xFF2563EB),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDetailModal(request),
    );
  }

  Widget _buildDetailModal(ServiceRequest request) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Text(
                      _getRequestId(request),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const Spacer(),
                    AnimatedStatusBadge(
                      text: request.statusDisplayName,
                      color: _getStatusColor(request.status),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  request.equipmentName ?? request.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 24),
                
                _buildStatusTimeline(request),
                
                const SizedBox(height: 32),
                
                _buildDetailSection('ОБОРУДОВАНИЕ', [
                  _buildDetailRow('Серийный номер', request.serialNumber ?? '—'),
                  _buildDetailRow('Площадка', request.siteName ?? '—'),
                ]),
                
                const SizedBox(height: 24),
                
                _buildDetailSection('КОНТАКТЫ ДЛЯ СВЯЗИ', [
                  _buildCompactContactRow('Автор заявки (Ответственное лицо)', request.responsibleContact ?? 'Не указан'),
                  _buildCompactContactRow('Менеджер площадки', request.siteManagerContact ?? 'Не указан'),
                  _buildCompactContactRow('Оператор ПМ', request.operatorContact ?? 'Не указан'),
                ]),
                
                const SizedBox(height: 24),
                
                _buildDetailSection('ОПИСАНИЕ ПРОБЛЕМЫ', [
                  Text(
                    request.description,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF334155), height: 1.5),
                  ),
                ]),
                
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB), // Blue color like other buttons
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20), // Taller button
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Закрыть', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactContactRow(String label, String contactInfo) {
    // Сложная логика извлечения телефона для ссылки
    final phoneRegex = RegExp(r'(\+7|7|8)[\s\-]?\(?[0-9]{3}\)?[\s\-]?([0-9]{3})[\s\-]?([0-9]{2})[\s\-]?([0-9]{2})');
    final match = phoneRegex.firstMatch(contactInfo);
    String? phone;
    String cleanText = contactInfo;

    if (match != null) {
      phone = match.group(0);
      // Убираем телефон из текста, если хотим разделить, но здесь лучше оставить как есть для красоты
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), height: 1.4),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w400),
                  ),
                  if (phone != null) ...[
                    TextSpan(
                      text: contactInfo.substring(0, contactInfo.indexOf(phone)),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: () => launchUrl(Uri.parse('tel:${phone!.replaceAll(RegExp(r'[^\d+]'), '')}')),
                        child: Text(
                          phone,
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    TextSpan(
                      text: contactInfo.substring(contactInfo.indexOf(phone) + phone.length),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ] else
                    TextSpan(
                      text: contactInfo,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(ServiceRequest request) {
    final List<String> steps = [
      'Новая',
      'Назначен инженер',
      'Назначена дата',
      'Приступил к работе',
      'Ждет счет',
      'Ждет оплату',
      'Закрыта'
    ];

    int currentStepIndex = 0;
    if (request.status == RequestStatus.completed) {
      currentStepIndex = 6;
    } else if (request.status == RequestStatus.inProgress) {
      currentStepIndex = 3;
    } else if (request.scheduledAt != null) {
      currentStepIndex = 2;
    } else if (request.assignedEngineerId != null) {
      currentStepIndex = 1;
    } else {
      currentStepIndex = 0;
    }

    // Для демонстрации "Ждет счет" и "Ждет оплату" можно добавить условия
    // На данный момент оставим логику выше как базовую

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'СТАТУС ВЫПОЛНЕНИЯ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(steps.length, (index) {
              final isActive = index <= currentStepIndex;
              final isLast = index == steps.length - 1;
              
              return Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: isActive 
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Center(child: Text('${index + 1}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)))),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        steps[index],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  if (!isLast)
                    Container(
                      width: 40,
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: index < currentStepIndex ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
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
