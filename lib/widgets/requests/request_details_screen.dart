import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/request_message.dart';
import '../../models/user.dart' as AppUserModel;
import 'package:flutter/services.dart';
import '../pdf_iframe_view.dart';
import '../../models/service_request.dart';
import '../../models/equipment.dart';
import '../../services/supabase_service.dart';
import '../../services/image_service.dart';
import 'chat_screen.dart';
import '../assign_engineer_dialog.dart';
import '../equipment_specifications_widget.dart';
import '../equipment_maintenance_widget.dart';
import '../../theme/app_theme.dart';


class RequestDetailsScreen extends StatefulWidget {
  final ServiceRequest request;
  final AppUserModel.User currentUser;
  final Function() onStatusChanged;
  
  const RequestDetailsScreen({
    super.key, 
    required this.request,
    required this.currentUser,
    required this.onStatusChanged,
  });

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  late ServiceRequest _currentRequest;
  bool _isLoading = false;
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm');
  final ImagePicker _picker = ImagePicker();
  XFile? _invoiceFile;
  int _unreadCount = 0;
  DateTime? _lastReadTime;
  RealtimeChannel? _chatSubscription;
  Equipment? _equipment;
  RealtimeChannel? _subscription;


  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    _loadEquipment();
    _setupRealtime();
    _loadUnreadCount();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _chatSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReadStr = prefs.getString('chat_last_read_${_currentRequest.id}');
    if (lastReadStr != null) {
      _lastReadTime = DateTime.parse(lastReadStr);
    } else {
      _lastReadTime = DateTime.now().subtract(const Duration(days: 365));
    }

    // Загружаем сообщения после последнего прочтения
    try {
      final messages = await SupabaseService.getRequestMessages(_currentRequest.id);
      int count = 0;
      for (var msg in messages) {
        if (msg.senderId != widget.currentUser.id && 
            (_lastReadTime == null || msg.createdAt.isAfter(_lastReadTime!))) {
          count++;
        }
      }
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (e) {
      print('Error loading unread count: $e');
    }
  }

  void _subscribeToMessages() {
    _chatSubscription = SupabaseService.subscribeToRequestMessages(_currentRequest.id, (msg) {
      if (mounted && msg.senderId != widget.currentUser.id) {
        setState(() {
          _unreadCount++;
        });
      }
    });
  }

  Future<void> _markAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString('chat_last_read_${_currentRequest.id}', now.toIso8601String());
    if (mounted) {
      setState(() {
        _unreadCount = 0;
        _lastReadTime = now;
      });
    }
  }

  void _setupRealtime() {
    _subscription = SupabaseService.subscribeToRequestChanges(_currentRequest.id, (updatedRequest) {
      if (mounted) {
        setState(() {
          _currentRequest = updatedRequest;
        });
        widget.onStatusChanged();
      }
    });
  }

  Future<void> _loadEquipment() async {
    if (_currentRequest.equipmentId != null) {
      final equipment = await SupabaseService.getEquipmentById(_currentRequest.equipmentId!);
      if (mounted) {
        setState(() {
          _equipment = equipment;
        });
      }
    }
  }

  Future<void> _refreshRequest() async {
    setState(() => _isLoading = true);
    final updatedRequest = await SupabaseService.getRequestById(_currentRequest.id);
    if (updatedRequest != null && mounted) {
      setState(() {
        _currentRequest = updatedRequest;
        _isLoading = false;
      });
      widget.onStatusChanged();
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Светло-серый фон
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              'Заявка ${_getRequestId(_currentRequest)}',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusChip(_currentRequest),
          ],
        ),
        actions: [
          if (widget.currentUser.role == AppUserModel.UserRole.administrator || 
              widget.currentUser.role == AppUserModel.UserRole.superAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              tooltip: 'Удалить заявку',
              onPressed: () => _confirmDelete(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(left: 56, bottom: 8, right: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
              'от ${_dateFormat.format(_currentRequest.createdAt)}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTimelineCard(),
                const SizedBox(height: 12),
                if (_currentRequest.assignedEngineerId != null) ...[
                  _buildEngineerCard(),
                  const SizedBox(height: 12),
                ],
                if (_currentRequest.engineerComment != null && _currentRequest.engineerComment!.isNotEmpty) ...[
                  _buildEngineerResultCard(),
                  const SizedBox(height: 12),
                ],
                if (_currentRequest.recommendations != null && _currentRequest.recommendations!.isNotEmpty) ...[
                  _buildRecommendationsCard(),
                  const SizedBox(height: 12),
                ],
                _buildEquipmentCard(),
                const SizedBox(height: 12),
                _buildSiteCard(),
                const SizedBox(height: 12),
                _buildContactsCard(),
                const SizedBox(height: 12),
                _buildDescriptionCard(),
                if (_currentRequest.invoiceAmount != null || _currentRequest.invoiceUrl != null) ...[
                  const SizedBox(height: 12),
                  _buildPaymentCard(),
                ],
                const SizedBox(height: 12),
                _buildChatCard(),
                const SizedBox(height: 24),
              ],
            ),
          ),
          
          if (_hasActionButtons())
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, -4),
                      blurRadius: 10,
                    )
                  ]
                ),
                child: _buildActionButtons(),
              ),
            ),

          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  String _getRequestId(ServiceRequest request) {
    if (request.id.length > 5) {
      return '#${request.id.substring(0, 5).toUpperCase()}';
    }
    return '#${request.id.toUpperCase()}';
  }

  Widget _buildStatusChip(ServiceRequest request) {
    Color bgColor;
    Color textColor;
    
    switch (request.status) {
      case RequestStatus.completed:
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF059669);
        break;
      case RequestStatus.inProgress:
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF2563EB);
        break;
      case RequestStatus.pending:
      case RequestStatus.approved:
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        break;
      case RequestStatus.rejected:
      case RequestStatus.cancelled:
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        break;
      default:
        bgColor = const Color(0xFFE2E8F0);
        textColor = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            request.statusDisplayName,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildCardHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineCard() {
    return _buildCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: _buildCardHeader(Icons.access_time_outlined, 'Ход выполнения'),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildTimelineContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimelineStep(
          title: 'Заявка создана',
          time: _currentRequest.createdAt,
          actor: _currentRequest.creatorName,
          icon: Icons.description_outlined,
          isCompleted: true,
          color: const Color(0xFF2563EB),
        ),
        _buildTimelineStep(
          title: _currentRequest.approvedAt != null ? 'Назначен инженер' : 'Назначение инженера',
          time: _currentRequest.approvedAt,
          actor: _currentRequest.approvedAt != null ? (_currentRequest.approvedByName ?? 'Администратор') : null,
          detail: _currentRequest.engineerName != null ? 'Инженер: ${_currentRequest.engineerName}' : null,
          icon: Icons.person_outline,
          isCompleted: _currentRequest.approvedAt != null || _currentRequest.assignedEngineerId != null,
          color: const Color(0xFF2563EB),
        ),
        _buildTimelineStep(
          title: _currentRequest.scheduledAt != null ? 'Выезд назначен' : 'Выезд',
          time: _currentRequest.scheduledTimestampAt ?? _currentRequest.scheduledAt,
          actor: (_currentRequest.scheduledTimestampAt != null || _currentRequest.scheduledAt != null) && _currentRequest.engineerName != null ? _currentRequest.engineerName : null,
          detail: _currentRequest.scheduledAt != null ? 'Дата выезда: ${DateFormat('dd.MM.yyyy').format(_currentRequest.scheduledAt!)}' : null,
          icon: Icons.local_shipping_outlined,
          isCompleted: _currentRequest.scheduledAt != null,
          color: const Color(0xFF2563EB),
        ),
        _buildTimelineStep(
          title: 'В работе',
          time: _currentRequest.engineerStartedAt,
          actor: _currentRequest.engineerStartedAt != null && _currentRequest.engineerName != null ? _currentRequest.engineerName : null,
          icon: Icons.build_outlined,
          isCompleted: _currentRequest.engineerStartedAt != null,
          color: const Color(0xFF2563EB),
        ),
        _buildTimelineStep(
          title: _currentRequest.engineerCompletedAt != null ? 'Выполнена' : 'Выполнение',
          time: _currentRequest.engineerCompletedAt,
          actor: _currentRequest.engineerCompletedAt != null && _currentRequest.engineerName != null ? _currentRequest.engineerName : null,
          icon: Icons.assignment_outlined,
          isCompleted: _currentRequest.engineerCompletedAt != null,
          color: const Color(0xFF2563EB),
        ),
        _buildTimelineStep(
          title: _currentRequest.status == RequestStatus.waitingForInvoice || _currentRequest.status == RequestStatus.waitingForPayment || _currentRequest.status == RequestStatus.completed ? 'Принято клиентом' : 'Приемка',
          time: _currentRequest.clientAcceptedAt,
          actor: _currentRequest.clientAcceptedAt != null ? (_currentRequest.creatorName ?? 'Клиент') : null,
          detail: (_currentRequest.clientAcceptanceComment != null && _currentRequest.clientAcceptanceComment!.isNotEmpty) ? 'Замечания: ${_currentRequest.clientAcceptanceComment}' : null,
          icon: Icons.check_circle_outline,
          isCompleted: _currentRequest.clientAcceptedAt != null || _currentRequest.status == RequestStatus.waitingForInvoice || _currentRequest.status == RequestStatus.waitingForPayment || _currentRequest.status == RequestStatus.completed,
          color: const Color(0xFF2563EB),
        ),
        _buildTimelineStep(
          title: _currentRequest.invoiceAmount != null || _currentRequest.status == RequestStatus.waitingForPayment || _currentRequest.status == RequestStatus.completed ? 'Счёт выставлен' : 'Счёт',
          time: (_currentRequest.invoiceAmount != null || _currentRequest.status == RequestStatus.waitingForPayment || _currentRequest.status == RequestStatus.completed) ? _currentRequest.engineerCompletedAt : null,
          actor: (_currentRequest.invoiceAmount != null || _currentRequest.status == RequestStatus.waitingForPayment || _currentRequest.status == RequestStatus.completed) ? 'Администратор' : null,
          detail: _currentRequest.invoiceAmount != null ? 'Сумма: ${_currentRequest.invoiceAmount} ₽' : null,
          icon: Icons.payments_outlined,
          isCompleted: _currentRequest.invoiceAmount != null || _currentRequest.status == RequestStatus.waitingForPayment || _currentRequest.status == RequestStatus.completed,
          color: const Color(0xFF2563EB),
        ),
        _buildTimelineStep(
          title: _currentRequest.completedAt != null ? 'Закрыта' : 'Закрытие',
          time: _currentRequest.completedAt,
          actor: _currentRequest.completedAt != null ? 'Администратор' : null,
          icon: Icons.check_circle_outline,
          isCompleted: _currentRequest.completedAt != null,
          color: const Color(0xFF2563EB),
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required String title,
    DateTime? time,
    String? actor,
    String? detail,
    required IconData icon,
    bool isCompleted = false,
    bool isLast = false,
    required Color color,
    Widget? trailing,
  }) {
    final activeColor = color;
    final inactiveColor = const Color(0xFFCBD5E1); // slate-300

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Столбец с иконкой и линией
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted ? activeColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted ? activeColor : inactiveColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isCompleted ? Colors.white : inactiveColor,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0), // blue-200 или slate-200
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Текстовая часть
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
                            color: const Color(0xFF1E293B), // slate-800
                          ),
                        ),
                      ),
                      if (trailing != null) trailing,
                    ],
                  ),
                  if (time != null || actor != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${time != null ? DateFormat('dd.MM.yyyy HH:mm').format(time) : ''}${time != null && actor != null ? ' — ' : ''}${actor ?? ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B), // slate-500
                      ),
                    ),
                  ],
                  if (detail != null && isCompleted) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2563EB), // blue-600
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentCard() {
    return _buildCard(
      child: InkWell(
        onTap: () {
          if (_equipment != null) {
            _showEquipmentDetails(_equipment!);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(Icons.build_outlined, 'Оборудование'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: _equipment != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              ImageService.getPossibleImagePaths(_equipment!.manufacturer, _equipment!.model).first,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.precision_manufacturing, color: Color(0xFF3B82F6)),
                            ),
                          )
                        : const Icon(Icons.precision_manufacturing, color: Color(0xFF3B82F6)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _equipment?.fullTitle ?? _currentRequest.equipmentName ?? 'Оборудование',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (_currentRequest.serialNumber != null)
                          Text(
                            'S/N: ${_currentRequest.serialNumber}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineerCard() {
    String initials = _currentRequest.engineerName?.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join('').toUpperCase() ?? 'И';
    
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.engineering_outlined, 'Назначенный инженер'),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentRequest.engineerName ?? 'Инженер не указан',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Сервисный инженер компании',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngineerResultCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.assignment_turned_in_outlined, 'Результаты работ'),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDCFCE7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Комментарий инженера:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF15803D),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentRequest.engineerComment ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF166534),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.lightbulb_outline_rounded, 'Рекомендации инженера'),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED), // Light orange/yellow
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFEEDD3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Рекомендовано:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC2410C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentRequest.recommendations ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9A3412),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatCard() {
    return _buildCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                requestId: _currentRequest.id, 
                requestTitle: _currentRequest.title, 
                currentUser: widget.currentUser,
              ),
            ),
          );
          _markAsRead();
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2563EB), size: 20),
        ),
        title: const Text(
          'Обсуждение заявки',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        subtitle: const Text('Перейти в чат', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.location_on_outlined, 'Площадка'),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.siteName ?? 'Не указано',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentRequest.siteAddress ?? 'Адрес не указан',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                if (_currentRequest.siteAddress != null) ...[
                  const SizedBox(height: 12),
                  _buildSmallButton(
                    onPressed: () => _openMap(_currentRequest.siteAddress!),
                    icon: Icons.map_outlined,
                    label: 'Открыть на карте',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.phone_outlined, 'Контакты'),
          const SizedBox(height: 16),
          if (widget.request.responsibleContact != null)
            _buildContactItem('Инициатор', widget.request.responsibleContact!),
          if (widget.request.siteManagerContact != null)
            _buildContactItem('Менеджер площадки', widget.request.siteManagerContact!),
          if (widget.request.operatorContact != null)
            _buildContactItem('Оператор ПМ', widget.request.operatorContact!),
        ],
      ),
    );
  }

  Widget _buildContactItem(String role, String contactInfo) {
    String name = contactInfo;
    String? phone;
    
    // Пытаемся вытащить телефон (простая версия)
    final phoneRegex = RegExp(r'(\+7|7|8)[\s\-]?\(?[0-9]{3}\)?[\s\-]?([0-9]{3})[\s\-]?([0-9]{2})[\s\-]?([0-9]{2})');
    final match = phoneRegex.firstMatch(contactInfo);
    if (match != null) {
      phone = match.group(0);
      name = contactInfo.replaceAll(phone!, '').trim();
      if (name.isEmpty) name = 'Без имени';
    }

    String initials = name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join('').toUpperCase();
    if (initials.isEmpty) initials = '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFDBEAFE),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          role,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        if (role == 'Инициатор') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Инициатор',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (phone != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:${phone!.replaceAll(RegExp(r'[^\d+]'), '')}')),
                icon: const Icon(Icons.phone_outlined, size: 16),
                label: const Text('Позвонить'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFFDBEAFE)),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заявку?'),
        content: const Text('Это действие нельзя отменить. Заявка будет удалена из базы данных для всех пользователей.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);
        await SupabaseService.deleteServiceRequest(_currentRequest.id);
        if (mounted) {
          Navigator.pop(context); // Возвращаемся в список
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заявка успешно удалена')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildDescriptionCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.error_outline, 'Описание неисправности'),
          const SizedBox(height: 16),
          Text(
            widget.request.description,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF334155),
              height: 1.5,
            ),
          ),
          if (_currentRequest.attachments != null && _currentRequest.attachments!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Фото неисправности',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _currentRequest.attachments!.length,
                itemBuilder: (context, index) {
                  final url = _currentRequest.attachments![index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      onTap: () => _showImageGallery(index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          url,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 120,
                              height: 120,
                              color: const Color(0xFFF1F5F9),
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 120,
                            height: 120,
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]
        ],
      ),
    );
  }

  bool _hasActionButtons() {
    return _buildActionButtonsBody().isNotEmpty;
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _buildActionButtonsBody(),
    );
  }

  List<Widget> _buildActionButtonsBody() {
    List<Widget> buttons = [];
    final bool isAdmin = widget.currentUser.role == AppUserModel.UserRole.superAdmin || widget.currentUser.role == AppUserModel.UserRole.administrator;
    final bool isAssignedEngineer = widget.currentUser.role == AppUserModel.UserRole.engineer && _currentRequest.assignedEngineerId == widget.currentUser.id;

    if (_canAssignEngineer(_currentRequest)) {
      buttons.add(
        _buildActionButton('Назначить инженера', const Color(0xFF10B981), () {
          _handleAssignEngineer();
        }),
      );
    }

    if (isAssignedEngineer && _currentRequest.status == RequestStatus.approved) {
      if (_currentRequest.scheduledAt == null) {
        buttons.add(
          _buildActionButton('Назначить дату выезда', const Color(0xFF8B5CF6), () {
             _selectServiceDate();
          }),
        );
      } else {
        buttons.add(
          _buildActionButton('Приступить к работе', const Color(0xFF0EA5E9), () {
             _startWork();
          }),
        );
      }
    }

    if (isAssignedEngineer && _currentRequest.status == RequestStatus.inProgress) {
      buttons.add(
        _buildActionButton('Завершить работы и сдать отчет', const Color(0xFFF59E0B), () {
           _completeWork();
        }),
      );
    }

    // Кнопка приемки для клиента (автора или менеджера)
    final bool isRequester = widget.currentUser.id == _currentRequest.userId || widget.currentUser.role == AppUserModel.UserRole.siteManager || widget.currentUser.role == AppUserModel.UserRole.companyResponsible;
    if (isRequester && _currentRequest.status == RequestStatus.waitingForAcceptance) {
      buttons.add(
        _buildActionButton('Принять работы', const Color(0xFF10B981), () {
           _acceptWorkDialog();
        }),
      );
    }

    if (isAdmin && _currentRequest.status == RequestStatus.waitingForInvoice) {
      buttons.add(
        _buildActionButton('Сформировать / Загрузить счет', const Color(0xFF8B5CF6), () {
             _uploadInvoiceDialog();
        }),
      );
    }

    if (isAdmin && _currentRequest.status == RequestStatus.waitingForPayment) {
      buttons.add(
        _buildActionButton('Подтвердить оплату и закрыть', const Color(0xFF10B981), () {
             _confirmPaymentDialog();
        }),
      );
    }

    return buttons;
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  bool _canAssignEngineer(ServiceRequest request) {
    if (widget.currentUser.role == AppUserModel.UserRole.administrator || 
        widget.currentUser.role == AppUserModel.UserRole.superAdmin) {
      return request.assignedEngineerId == null && 
             (request.status == RequestStatus.pending || request.status == RequestStatus.approved);
    }
    return false;
  }

  void _handleAssignEngineer() {
    final isSupplier = widget.currentUser.role == AppUserModel.UserRole.supplier;
    showDialog(
      context: context,
      builder: (context) => AssignEngineerDialog(
        requestId: _currentRequest.id,
        supplierUserId: isSupplier ? widget.currentUser.id : null,
        approverName: widget.currentUser.fullName,
        onEngineerAssigned: () {
          _refreshRequest();
        },
      ),
    );
  }

  Future<void> _selectServiceDate() async {
    final DateTime? pickedDate = await showDatePicker(
       context: context,
       initialDate: DateTime.now().add(const Duration(days: 1)),
       firstDate: DateTime.now(),
       lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null && mounted) {
       setState(() => _isLoading = true);
       try {
         await SupabaseService.updateRequestScheduledDate(_currentRequest.id, pickedDate);
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Дата выезда назначена!'), backgroundColor: Colors.green,));
           _refreshRequest();
         }
       } catch (e) {
         setState(() => _isLoading = false);
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red,));
         }
       }
    }
  }

  Future<void> _startWork() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.startEngineerWork(_currentRequest.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Работа начата!'), backgroundColor: Colors.green,));
        _refreshRequest();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red,));
      }
    }
  }

  Future<void> _completeWork() async {
    String comment = '';
    String recommendations = '';
    
    // Сначала окно выполненных работ
    final bool? workDone = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выполненные работы'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Опишите, что именно было сделано...',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
          onChanged: (v) => comment = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Далее')),
        ],
      )
    );

    if (workDone != true || !mounted) return;

    // Затем окно рекомендаций
    final bool? recDone = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Рекомендации'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Напишите рекомендации по дальнейшему обслуживанию...',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
          onChanged: (v) => recommendations = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Завершить')),
        ],
      )
    );

    if (recDone != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await SupabaseService.submitEngineerReport(
        _currentRequest.id, 
        comment, 
        recommendations
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отчет успешно отправлен!'), backgroundColor: Colors.green,));
        _refreshRequest();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red,));
      }
    }
  }

  Future<void> _acceptWorkDialog() async {
    String comment = '';
    bool showCommentField = false;
    bool isStepTwo = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isStepTwo ? 'Подтверждение' : 'Принятие работ', 
            style: const TextStyle(fontWeight: FontWeight.bold)
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isStepTwo) ...[
                const Text('Вы подтверждаете выполнение работ инженером?', style: TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    setDialogState(() {
                      showCommentField = !showCommentField;
                    });
                  },
                  icon: Icon(showCommentField ? Icons.close : Icons.add_comment_outlined, size: 18),
                  label: Text(showCommentField ? 'Скрыть комментарий' : 'Добавить замечание/комментарий'),
                ),
              ],
              if (isStepTwo)
                const Text('Работы будут отмечены как принятые. Вы уверены?', style: TextStyle(color: Color(0xFF64748B))),
              
              if (showCommentField && !isStepTwo) ...[
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Опишите замечания или добавьте отзыв...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  maxLines: 3,
                  onChanged: (v) => comment = v,
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!isStepTwo) {
                  setDialogState(() {
                    isStepTwo = true;
                  });
                } else {
                  Navigator.pop(ctx, true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isStepTwo ? 'Да, подтверждаю' : 'Принять'),
            ),
          ],
        ),
      ),
    ).then((accepted) async {
      if (accepted == true && mounted) {
        setState(() => _isLoading = true);
        try {
          await SupabaseService.acceptServiceWork(_currentRequest.id, isAccepted: true, comment: comment);
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
               content: Text('Работы успешно приняты!'), 
               backgroundColor: Colors.green,
             ));
             _refreshRequest();
          }
        } catch (e) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
          }
        }
      }
    });
  }

  Future<void> _uploadInvoiceDialog() async {
    String amountStr = '';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выставить счет'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Сумма к оплате (руб)',
                prefixIcon: Icon(Icons.currency_ruble, size: 18),
              ),
              onChanged: (v) => amountStr = v,
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  children: [
                    if (_invoiceFile == null)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
                          if (file != null) {
                            setDialogState(() {
                              _invoiceFile = file;
                            });
                          }
                        },
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Прикрепить счет (фото/скан)'),
                      )
                    else
                      ListTile(
                        leading: const Icon(Icons.description, color: Colors.blue),
                        title: Text(_invoiceFile!.name, style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setDialogState(() => _invoiceFile = null),
                        ),
                      ),
                  ],
                );
              }
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Отправить')
          ),
        ],
      )
    ).then((confirmed) async {
      if (confirmed == true && mounted) {
        final amount = double.tryParse(amountStr.replaceAll(',', '.'));
        
        setState(() => _isLoading = true);
        try {
          String? invoiceUrl;
          if (_invoiceFile != null) {
            final bytes = await _invoiceFile!.readAsBytes();
            invoiceUrl = await SupabaseService.uploadInvoiceFile(
              _currentRequest.id,
              bytes,
              _invoiceFile!.name,
            );
          }
          
          await SupabaseService.requestPaymentForInvoice(
            _currentRequest.id, 
            amount ?? 0,
            invoiceUrl: invoiceUrl,
            senderId: widget.currentUser.id,
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Счет выставлен клиенту!'), backgroundColor: Colors.green,));
            _refreshRequest();
          }
        } catch (e) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red,));
          }
        }
      }
    });
  }

  Future<void> _confirmPaymentDialog() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.updateRequestStatus(_currentRequest.id, RequestStatus.completed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Оплата подтверждена. Заявка закрыта!'), backgroundColor: Colors.green,));
        _refreshRequest();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red,));
      }
    }
  }

  void _openChat() {
    // Чат теперь встроен в карточку заявки
  }

  void _showEquipmentDetails(Equipment equipment) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(
                          minHeight: 140,
                          maxHeight: 250,
                        ),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          color: Colors.white,
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: equipment != null
                                    ? Image.asset(
                                        ImageService.getPossibleImagePaths(equipment.manufacturer, equipment.model).first,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.precision_manufacturing, size: 64, color: Colors.grey),
                                      )
                                    : const Icon(Icons.precision_manufacturing, size: 64, color: Colors.grey),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.black54),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${equipment.manufacturer} ${equipment.model}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (equipment.type != null) ...[
                              _buildEquipmentDetailRow(Icons.category_outlined, 'Тип', equipment.type!),
                              const SizedBox(height: 8),
                            ],
                            _buildEquipmentDetailRow(Icons.numbers, 'Серийный номер', equipment.serialNumber ?? 'Не указан'),
                            const SizedBox(height: 8),
                            _buildEquipmentDetailRow(Icons.location_on_outlined, 'Площадка', equipment.address.isNotEmpty ? equipment.address : equipment.location),
                            const SizedBox(height: 16),
                            
                            EquipmentSpecificationsWidget(
                              manufacturer: equipment.manufacturer,
                              model: equipment.model,
                              customSpecs: equipment.specifications,
                            ),
                            
                            EquipmentMaintenanceWidget(
                              equipment: equipment,
                              onUpdated: () async {
                                Navigator.pop(context);
                                _loadEquipment();
                              }
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEquipmentDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.payment_outlined, 'Оплата и счет'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Сумма к оплате:', style: TextStyle(color: Color(0xFF64748B))),
              Text(
                '${_currentRequest.invoiceAmount ?? 0} ₽',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          if (_currentRequest.invoiceUrl != null) ...[
            const SizedBox(height: 16),
            _buildSmallButton(
              onPressed: () => _viewInvoice(_currentRequest.invoiceUrl!),
              icon: Icons.description_outlined,
              label: 'Посмотреть счет (PDF/Фото)',
            ),
          ],
        ],
      ),
    );
  }

  void _viewInvoice(String url) async {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              AppBar(
                title: const Text('Просмотр счета', style: TextStyle(fontSize: 16)),
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E293B),
                elevation: 0,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.download), 
                    onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                  ),
                  IconButton(
                    icon: const Icon(Icons.close), 
                    onPressed: () => Navigator.pop(ctx)
                  ),
                ],
              ),
              Expanded(
                child: PdfIframeView(url: url, label: 'Счет на оплату'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF3B82F6)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMap(String address) async {
    final query = Uri.encodeComponent(address);
    final googleUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    
    try {
      if (await canLaunchUrl(googleUrl)) {
        await launchUrl(googleUrl, mode: LaunchMode.platformDefault);
      } else {
        throw Exception('Cannot launch map');
      }
    } catch (e) {
      print('Error launching maps: $e');
      Clipboard.setData(ClipboardData(text: googleUrl.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть карту (ссылка скопирована)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showImageGallery(int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: _currentRequest.attachments!.length,
              controller: PageController(initialPage: initialIndex),
              itemBuilder: (context, index) {
                final url = _currentRequest.attachments![index];
                return InteractiveViewer(
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      },
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

