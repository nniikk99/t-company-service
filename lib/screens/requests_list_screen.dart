import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user.dart';
import '../models/service_request.dart';
import '../services/supabase_service.dart';
import '../widgets/animated_card.dart';
import '../widgets/animated_status_badge.dart';
import '../widgets/requests/request_details_screen.dart';

class RequestsListScreen extends StatefulWidget {
  final User user;

  const RequestsListScreen({super.key, required this.user});

  @override
  State<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends State<RequestsListScreen> {
  List<ServiceRequest> _requests = [];
  bool _isLoading = true;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _setupRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    _subscription = SupabaseService.subscribeToAllRequests(widget.user, () {
      if (mounted) {
        _loadRequests(showLoading: false);
      }
    });
  }

  Future<void> _loadRequests({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    
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
            // print('⚠️ Ошибка парсинга заявки (INN-filter): $e');
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
            // print('⚠️ Ошибка парсинга заявки (user): $e');
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
      
      if (mounted) {
        setState(() {
          _requests = filteredRequests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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
      case RequestStatus.waitingForInvoice:
      case RequestStatus.waitingForPayment:
        return const Color(0xFF8B5CF6); // Purple
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
                  if (_requests.isEmpty)
                    _buildEmptyState()
                  else
                    ..._requests.asMap().entries.map((entry) {
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

  Widget _buildRequestCard(ServiceRequest request) {
    return Column(
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
                  '${_formatDate(request.createdAt)}${request.scheduledAt != null ? ' (Выезд: ${_formatDate(request.scheduledAt!)})' : ''}',
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
      ],
    );
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
            const Text(
              'Нет заявок',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Заявки будут отображаться здесь',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestDetails(ServiceRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestDetailsScreen(
          request: request,
          currentUser: widget.user,
          onStatusChanged: _loadRequests,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
