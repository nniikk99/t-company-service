import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../models/service_request.dart';
import '../../services/supabase_service.dart';
import '../assign_engineer_dialog.dart';

class RequestDetailsScreen extends StatefulWidget {
  final ServiceRequest request;
  final User currentUser;
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
  final _dateFormat = DateFormat('dd.MM.yyyy');
  late ServiceRequest _currentRequest;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
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
                _buildEquipmentCard(),
                const SizedBox(height: 12),
                _buildSiteCard(),
                const SizedBox(height: 12),
                _buildContactsCard(),
                const SizedBox(height: 12),
                _buildDescriptionCard(),
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
                      color: Colors.black.withValues(alpha: 0.05),
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
              color: Colors.white.withValues(alpha: 0.7),
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

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      padding: const EdgeInsets.all(16),
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
    if (_currentRequest.status == RequestStatus.completed) {
      currentStepIndex = 6;
    } else if (_currentRequest.status == RequestStatus.inProgress) {
      currentStepIndex = 3;
    } else if (_currentRequest.scheduledAt != null) {
      currentStepIndex = 2;
    } else if (_currentRequest.assignedEngineerId != null) {
      currentStepIndex = 1;
    } else {
      currentStepIndex = 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

  Widget _buildEquipmentCard() {
    return _buildCard(
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.precision_manufacturing, color: Color(0xFF3B82F6)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.request.equipmentName ?? widget.request.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (widget.request.equipmentModel != null)
                        Text(
                          '${widget.request.equipmentName?.split(' ').first ?? ''} · ${widget.request.equipmentModel}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.request.serialNumber != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.numbers, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                const Text(
                  'Серийный номер: ',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                ),
                Text(
                  widget.request.serialNumber!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ],
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
            padding: const EdgeInsets.all(12),
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
                const Text(
                  'Адрес площадки будет здесь (TODO)', // TODO: Add address string to ServiceRequest or fetch it
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('tel:${phone!.replaceAll(RegExp(r'[^\d+]'), '')}')),
                    icon: const Icon(Icons.phone, size: 16),
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
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Тут логика для мессенджера или смс
                    },
                    icon: const Icon(Icons.message_outlined, size: 16),
                    label: const Text('Написать'),
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
            ),
          ]
        ],
      ),
    );
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
            // Здесь должна быть карусель фото
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
    final bool isAdmin = widget.currentUser.role == UserRole.superAdmin || widget.currentUser.role == UserRole.administrator;
    final bool isAssignedEngineer = widget.currentUser.role == UserRole.engineer && _currentRequest.assignedEngineerId == widget.currentUser.id;

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
        _buildActionButton('Завершить работы', const Color(0xFFF59E0B), () {
           _completeWork();
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
    if (widget.currentUser.role == UserRole.administrator || 
        widget.currentUser.role == UserRole.superAdmin) {
      return request.assignedEngineerId == null && 
             (request.status == RequestStatus.pending || request.status == RequestStatus.approved);
    }
    return false;
  }

  void _handleAssignEngineer() {
    final isSupplier = widget.currentUser.role == UserRole.supplier;
    showDialog(
      context: context,
      builder: (context) => AssignEngineerDialog(
        requestId: _currentRequest.id,
        supplierUserId: isSupplier ? widget.currentUser.id : null,
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
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Завершение работы'),
        content: TextField(
          decoration: const InputDecoration(hintText: 'Опишите выполненные работы...'),
          maxLines: 3,
          onChanged: (v) => comment = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Завершить')
          ),
        ],
      )
    ).then((confirmed) async {
      if (confirmed == true && mounted) {
        setState(() => _isLoading = true);
        try {
          await SupabaseService.completeEngineerWork(_currentRequest.id, comment);
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Работы завершены, заявка ждет счет!'), backgroundColor: Colors.green,));
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

  Future<void> _uploadInvoiceDialog() async {
    String amountStr = '';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выставить счет'),
        content: TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Сумма к оплате (руб)'),
          onChanged: (v) => amountStr = v,
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
          await SupabaseService.requestPaymentForInvoice(_currentRequest.id, amount ?? 0);
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
}
