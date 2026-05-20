import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../models/user.dart' as AppUserModel;
import '../models/service_request.dart';
import '../services/supabase_service.dart';
import '../widgets/animated_card.dart';
import '../widgets/animated_status_badge.dart';
import '../widgets/requests/request_details_screen.dart';
import '../widgets/requests/part_order_details_screen.dart';
import '../services/image_service.dart';
import 'package:flutter/cupertino.dart';

class RequestsListScreen extends StatefulWidget {
  final AppUserModel.User user;

  const RequestsListScreen({super.key, required this.user});

  @override
  State<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends State<RequestsListScreen>
    with SingleTickerProviderStateMixin {
  List<ServiceRequest> _allRequests = [];
  bool _isLoading = true;
  RealtimeChannel? _subscription;
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  RequestStatus? _statusFilter;
  String? _siteFilter;
  String? _modelFilter;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadRequests();
    _setupRealtime();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      List<ServiceRequest> requests;

      if (widget.user.role == AppUserModel.UserRole.supplier) {
        requests = await SupabaseService.getSupplierRequests(widget.user.id);
      } else if (widget.user.role == AppUserModel.UserRole.engineer) {
        requests = await SupabaseService.getEngineerAssignedRequests(widget.user.id);
      } else if (widget.user.role == AppUserModel.UserRole.companyResponsible ||
          widget.user.role == AppUserModel.UserRole.siteManager) {
        final profile = await SupabaseService.getUserProfile(widget.user.id);
        final inn = profile?['company_inn'];
        final requestsJson = inn != null
            ? await SupabaseService.getCompanyRequestsByInn(inn)
            : await SupabaseService.getUserServiceRequests(widget.user.id);
        requests = requestsJson
            .map((json) {
              try {
                return ServiceRequest.fromJson(json);
              } catch (_) {
                return null;
              }
            })
            .whereType<ServiceRequest>()
            .toList();
      } else if (widget.user.role == AppUserModel.UserRole.operatorPM ||
          widget.user.role == AppUserModel.UserRole.contactPerson) {
        final requestsJson = await SupabaseService.getUserServiceRequests(widget.user.id);
        requests = requestsJson
            .map((json) {
              try {
                return ServiceRequest.fromJson(json);
              } catch (_) {
                return null;
              }
            })
            .whereType<ServiceRequest>()
            .toList();
      } else if (widget.user.role == AppUserModel.UserRole.administrator) {
        final requestsJson = await SupabaseService.getAllServiceRequests();
        requests = requestsJson
            .map((json) {
              try {
                return ServiceRequest.fromJson(json);
              } catch (_) {
                return null;
              }
            })
            .whereType<ServiceRequest>()
            .toList();
      } else {
        requests = [];
      }

      if (mounted) {
        setState(() {
          _allRequests = requests;
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

  // ── Разделение по вкладкам и фильтрация ────────────────────────────────

  List<ServiceRequest> get _serviceRequests => _allRequests
      .where((r) => r.type != RequestType.partsOrder)
      .toList();

  List<ServiceRequest> get _partsOrders => _allRequests
      .where((r) => r.type == RequestType.partsOrder)
      .toList();

  List<ServiceRequest> _applyFilters(List<ServiceRequest> source) {
    final query = _searchController.text.toLowerCase();
    return source.where((req) {
      final matchesSearch = query.isEmpty ||
          (req.title.toLowerCase().contains(query)) ||
          (req.equipmentName?.toLowerCase().contains(query) ?? false) ||
          (req.equipmentModel?.toLowerCase().contains(query) ?? false) ||
          (req.id.toLowerCase().contains(query)) ||
          (req.displayId.toLowerCase().contains(query));

      final matchesStatus = _statusFilter == null || req.status == _statusFilter;
      final matchesSite = _siteFilter == null || req.siteName == _siteFilter;
      final matchesModel = _modelFilter == null || req.equipmentModel == _modelFilter;

      return matchesSearch && matchesStatus && matchesSite && matchesModel;
    }).toList();
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.draft:
      case RequestStatus.pending:
        return const Color(0xFF2563EB);
      case RequestStatus.approved:
      case RequestStatus.inProgress:
      case RequestStatus.waitingForAcceptance:
        return const Color(0xFFEA580C);
      case RequestStatus.waitingForInvoice:
      case RequestStatus.waitingForPayment:
        return const Color(0xFF8B5CF6);
      case RequestStatus.completed:
        return const Color(0xFF16A34A);
      case RequestStatus.rejected:
      case RequestStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }

  // ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isPartsTab = _tabController.index == 1;
    final filteredService = _applyFilters(_serviceRequests);
    final filteredParts = _applyFilters(_partsOrders);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Заявки',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!isPartsTab)
            IconButton(
              icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list,
                  color: const Color(0xFF64748B)),
              onPressed: () => setState(() => _showFilters = !_showFilters),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            onPressed: () => _loadRequests(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1E293B),
              unselectedLabelColor: const Color(0xFF94A3B8),
              labelStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500),
              indicatorColor: const Color(0xFF3B82F6),
              indicatorWeight: 3,
              tabs: [
                _tabWithBadge('Сервис', _serviceRequests.length),
                _tabWithBadge('Запчасти', _partsOrders.length),
              ],
            ),
          ),
        ),
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
                    placeholder: isPartsTab
                        ? 'Поиск по номеру заказа или артикулу'
                        : 'Поиск по названию, модели или ID',
                    onChanged: (v) => setState(() {}),
                  ),
                ),
                if (!isPartsTab && _showFilters) _buildFiltersSection(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildServiceList(filteredService),
                      _buildPartsList(filteredParts),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tabWithBadge(String label, int count) {
    return Tab(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceList(List<ServiceRequest> list) {
    if (list.isEmpty) {
      return _buildEmptyState(
        icon: Icons.build_outlined,
        title: 'Нет сервисных заявок',
        subtitle: 'Заявки на ремонт, ТО и выезды будут здесь',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AnimatedCard(
          onTap: () => _openServiceDetails(list[i]),
          child: _buildServiceCard(list[i]),
        ),
      ),
    );
  }

  Widget _buildPartsList(List<ServiceRequest> list) {
    if (list.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Нет заказов запчастей',
        subtitle: 'Заказы из каталога будут приходить сюда',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AnimatedCard(
          onTap: () => _openPartOrderDetails(list[i]),
          child: _buildPartOrderCard(list[i]),
        ),
      ),
    );
  }

  // ── Карточка сервисной заявки (без изменений по сути) ──────────────────

  Widget _buildServiceCard(ServiceRequest request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        ImageService.getPossibleImagePaths(
                                request.equipmentManufacturer!, request.equipmentModel!)
                            .first,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.precision_manufacturing,
                            size: 24,
                            color: Color(0xFF94A3B8)),
                      ),
                    )
                  : const Icon(Icons.precision_manufacturing,
                      size: 24, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.displayId,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatDate(request.createdAt)}${request.scheduledAt != null ? ' (Выезд: ${_formatDate(request.scheduledAt!)})' : ''}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  if (request.companyName != null && request.companyName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        request.companyName!,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B82F6)),
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
        Text(
          request.equipmentName ?? request.title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B)),
        ),
        if (request.equipmentModel != null &&
            !(request.equipmentName ?? '').contains(request.equipmentModel!))
          Text(
            request.equipmentModel!,
            style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500),
          ),
        const SizedBox(height: 4),
        if (request.serialNumber != null)
          Text(
            'S/N: ${request.serialNumber}',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B)),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.location_on_rounded,
                size: 16, color: Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                request.siteName ?? 'Местоположение не указано',
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildAvatar(request.engineerName ?? 'НЕ НАЗНАЧЕН'),
            const SizedBox(width: 8),
            Text(
              request.engineerName ?? 'НЕ НАЗНАЧЕН',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: request.engineerName != null
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF94A3B8),
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
          ],
        ),
      ],
    );
  }

  // ── Карточка заказа запчастей (новый компактный стиль) ─────────────────

  Widget _buildPartOrderCard(ServiceRequest request) {
    final details = request.partsOrderDetails ?? const {};
    final items = (details['items'] as List?) ?? const [];
    final total = (details['total_amount'] as num?)?.toDouble() ?? 0;
    final deliveryType = (details['delivery_type'] ?? '').toString();
    final isPickup = deliveryType == 'pickup';
    final qty = items.fold<int>(0, (s, i) {
      if (i is Map) {
        return s + ((i['quantity'] as num?)?.toInt() ?? 0);
      }
      return s;
    });

    final color = _getStatusColor(request.status);
    final clientName = request.creatorName ?? request.companyName ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Шапка: иконка + ID + статус
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.inventory_2_outlined, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.displayId,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(request.createdAt),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            AnimatedStatusBadge(
              text: _partOrderStatusLabel(request.status),
              color: color,
              delay: const Duration(milliseconds: 200),
            ),
          ],
        ),

        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        const SizedBox(height: 12),

        // Клиент
        if (clientName != '—')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    clientName,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Сумма + кол-во позиций
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              total > 0 ? '${total.toStringAsFixed(0)} ₽' : 'По запросу',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: total > 0
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFEA580C),
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '${items.length} поз. · $qty шт.',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Доставка
        Row(
          children: [
            Icon(
              isPickup
                  ? Icons.store_outlined
                  : Icons.local_shipping_outlined,
              size: 16,
              color: const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              isPickup ? 'Самовывоз' : 'Доставка',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '· ${details['delivery_address'] ?? '—'}',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1)),
          ],
        ),
      ],
    );
  }

  String _partOrderStatusLabel(RequestStatus s) {
    switch (s) {
      case RequestStatus.pending:
        return 'Новый';
      case RequestStatus.approved:
        return 'Принят';
      case RequestStatus.inProgress:
        return 'В сборке';
      case RequestStatus.waitingForAcceptance:
        return 'Готов';
      case RequestStatus.completed:
        return 'Выполнен';
      case RequestStatus.cancelled:
        return 'Отменён';
      case RequestStatus.rejected:
        return 'Отклонён';
      default:
        return s.toString().split('.').last;
    }
  }

  // ── Фильтры, аватар, заглушки ──────────────────────────────────────────

  Widget _buildFiltersSection() {
    final sites = _serviceRequests
        .map((e) => e.siteName)
        .whereType<String>()
        .toSet()
        .toList();
    final models = _serviceRequests
        .map((e) => e.equipmentModel)
        .whereType<String>()
        .toSet()
        .toList();

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
                  onChanged: (v) => setState(() => _statusFilter = v),
                  labelBuilder: (v) => v == null
                      ? 'Все статусы'
                      : ServiceRequest(
                              id: '',
                              clientId: '',
                              userId: '',
                              type: RequestType.repair,
                              title: '',
                              description: '',
                              status: v,
                              createdAt: DateTime.now())
                          .statusDisplayName,
                ),
                const SizedBox(width: 8),
                _buildFilterChip<String?>(
                  label: 'Площадка',
                  value: _siteFilter,
                  items: [null, ...sites],
                  onChanged: (v) => setState(() => _siteFilter = v),
                  labelBuilder: (v) => v ?? 'Все площадки',
                ),
                const SizedBox(width: 8),
                _buildFilterChip<String?>(
                  label: 'Модель',
                  value: _modelFilter,
                  items: [null, ...models],
                  onChanged: (v) => setState(() => _modelFilter = v),
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
          color: value != null
              ? const Color(0xFFEFF6FF)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: value != null
                  ? const Color(0xFF3B82F6)
                  : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(labelBuilder(value),
                style: TextStyle(
                    fontSize: 13,
                    color: value != null
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF475569))),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down,
                size: 18,
                color: value != null
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF475569)),
          ],
        ),
      ),
      itemBuilder: (context) => items
          .map((item) =>
              PopupMenuItem<T>(value: item, child: Text(labelBuilder(item))))
          .toList(),
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
        color: name == 'НЕ НАЗНАЧЕН'
            ? const Color(0xFFF1F5F9)
            : const Color(0xFFEFF6FF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: name == 'НЕ НАЗНАЧЕН'
              ? const Color(0xFF94A3B8)
              : const Color(0xFF2563EB),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
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
            child: Icon(icon, size: 40, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Навигация ─────────────────────────────────────────────────────────

  void _openServiceDetails(ServiceRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestDetailsScreen(
          request: request,
          currentUser: widget.user,
          onStatusChanged: _loadRequests,
        ),
      ),
    );
  }

  void _openPartOrderDetails(ServiceRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartOrderDetailsScreen(
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
