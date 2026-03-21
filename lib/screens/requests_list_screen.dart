import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../models/user.dart' as AppUserModel;
import '../models/service_request.dart';
import '../services/supabase_service.dart';
import '../widgets/animated_card.dart';
import '../widgets/animated_status_badge.dart';
import '../widgets/requests/request_details_screen.dart';
import '../services/image_service.dart';
import 'package:flutter/cupertino.dart';

class RequestsListScreen extends StatefulWidget {
  final AppUserModel.User user;

  const RequestsListScreen({super.key, required this.user});

  @override
  State<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends State<RequestsListScreen> {
  List<ServiceRequest> _allRequests = [];
  List<ServiceRequest> _filteredRequests = [];
  bool _isLoading = true;
  RealtimeChannel? _subscription;
  
  final TextEditingController _searchController = TextEditingController();
  RequestStatus? _statusFilter;
  String? _siteFilter;
  String? _modelFilter;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _setupRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _searchController.dispose();
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
      if (widget.user.role == AppUserModel.UserRole.supplier) {
        filteredRequests = await SupabaseService.getSupplierRequests(widget.user.id);
      }
      // Для инженеров загружаем только назначенные заявки
      else if (widget.user.role == AppUserModel.UserRole.engineer) {
        filteredRequests = await SupabaseService.getEngineerAssignedRequests(widget.user.id);
      }
      // Для ответственных лиц компании - только заявки их компании по ИНН
      else if (widget.user.role == AppUserModel.UserRole.companyResponsible ||
               widget.user.role == AppUserModel.UserRole.siteManager) {
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
      else if (widget.user.role == AppUserModel.UserRole.administrator) {
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
      else if (widget.user.role == AppUserModel.UserRole.operatorPM || 
               widget.user.role == AppUserModel.UserRole.contactPerson) {
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
      else if (widget.user.role == AppUserModel.UserRole.superAdmin || 
               widget.user.role == AppUserModel.UserRole.administrator) {
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
           _allRequests = filteredRequests;
           _applyFilters();
           _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredRequests = _allRequests.where((req) {
        final query = _searchController.text.toLowerCase();
        final matchesSearch = query.isEmpty || 
            (req.title.toLowerCase().contains(query)) ||
            (req.equipmentName?.toLowerCase().contains(query) ?? false) ||
            (req.equipmentModel?.toLowerCase().contains(query) ?? false) ||
            (req.id.toLowerCase().contains(query));
            
        final matchesStatus = _statusFilter == null || req.status == _statusFilter;
        final matchesSite = _siteFilter == null || req.siteName == _siteFilter;
        final matchesModel = _modelFilter == null || req.equipmentModel == _modelFilter;
        
        return matchesSearch && matchesStatus && matchesSite && matchesModel;
      }).toList();
    });
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.draft:
      case RequestStatus.pending:
        return const Color(0xFF2563EB); // Blue
      case RequestStatus.approved:
      case RequestStatus.inProgress:
      case RequestStatus.waitingForAcceptance:
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Заявки', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list, color: const Color(0xFF64748B)),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            onPressed: () => _loadRequests(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Поиск
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'Поиск по названию, модели или ID',
                    onChanged: (v) => _applyFilters(),
                  ),
                ),
                // Фильтры
                if (_showFilters)
                  _buildFiltersSection(),
                
                Expanded(
                  child: _filteredRequests.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredRequests.length,
                          itemBuilder: (context, index) {
                            final request = _filteredRequests[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: AnimatedCard(
                                onTap: () => _showRequestDetails(request),
                                child: _buildRequestCard(request),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFiltersSection() {
    final sites = _allRequests.map((e) => e.siteName).whereType<String>().toSet().toList();
    final models = _allRequests.map((e) => e.equipmentModel).whereType<String>().toSet().toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Column(
        children: [
           SingleChildScrollView(
             scrollDirection: Axis.horizontal,
             child: Row(
               children: [
                 _buildFilterChip<RequestStatus?>(
                   label: 'Статус',
                   value: _statusFilter,
                   items: [null, ...RequestStatus.values],
                   onChanged: (v) {
                     setState(() => _statusFilter = v);
                     _applyFilters();
                   },
                   labelBuilder: (v) => v == null ? 'Все статусы' : ServiceRequest(id:'', clientId: '', userId: '', type: RequestType.repair, title: '', description: '', status: v, createdAt: DateTime.now()).statusDisplayName,
                 ),
                 const SizedBox(width: 8),
                 _buildFilterChip<String?>(
                   label: 'Площадка',
                   value: _siteFilter,
                   items: [null, ...sites],
                   onChanged: (v) {
                     setState(() => _siteFilter = v);
                     _applyFilters();
                   },
                   labelBuilder: (v) => v ?? 'Все площадки',
                 ),
                 const SizedBox(width: 8),
                 _buildFilterChip<String?>(
                   label: 'Модель',
                   value: _modelFilter,
                   items: [null, ...models],
                   onChanged: (v) {
                     setState(() => _modelFilter = v);
                     _applyFilters();
                   },
                   labelBuilder: (v) => v ?? 'Все модели',
                 ),
               ],
             ),
           ),
           const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFilterChip<T>({
    required String label,
    required T value,
    required List<T> items,
    required Function(T) onChanged,
    required String Function(T) labelBuilder,
  }) {
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: value != null ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: value != null ? const Color(0xFF3B82F6) : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(labelBuilder(value), style: TextStyle(fontSize: 13, color: value != null ? const Color(0xFF2563EB) : const Color(0xFF475569))),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: value != null ? const Color(0xFF2563EB) : const Color(0xFF475569)),
          ],
        ),
      ),
      itemBuilder: (context) => items.map((item) => PopupMenuItem<T>(value: item, child: Text(labelBuilder(item)))).toList(),
    );
  }

  Widget _buildRequestCard(ServiceRequest request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение оборудования
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: request.equipmentManufacturer != null && request.equipmentModel != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        ImageService.getPossibleImagePaths(request.equipmentManufacturer!, request.equipmentModel!).first,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.precision_manufacturing, size: 24, color: Color(0xFF94A3B8)),
                      ),
                    )
                  : const Icon(Icons.precision_manufacturing, size: 24, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
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
                  if (request.companyName != null && request.companyName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        request.companyName!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6), // Blue title for company
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
            if (request.equipmentModel != null && 
                !(request.equipmentName ?? '').contains(request.equipmentModel!))
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
