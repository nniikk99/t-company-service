import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/service_request.dart';
import '../models/equipment.dart';
import '../services/storage_service.dart';

class RequestsScreen extends StatefulWidget {
  final User? user;
  
  const RequestsScreen({super.key, this.user});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  bool _isLoading = true;
  List<ServiceRequest> _requests = [];
  List<Equipment> _equipment = [];
  String _searchQuery = '';
  RequestStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final allRequests = await StorageService.getRequests();
      final allEquipment = await StorageService.getEquipment(companyId: widget.user?.companyId);
      
      List<ServiceRequest> filteredRequests;
      if (widget.user?.role == UserRole.administrator) {
        filteredRequests = allRequests;
      } else if (widget.user?.role == UserRole.contactPerson) {
        filteredRequests = allRequests
            .where((r) => r.userId == widget.user?.id)
            .toList();
      } else {
        filteredRequests = allRequests
            .where((r) => r.clientId == widget.user?.companyId)
            .toList();
      }

      setState(() {
        _requests = filteredRequests;
        _equipment = allEquipment;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<ServiceRequest> get _filteredRequests {
    var filtered = _requests;
    
    if (_statusFilter != null) {
      filtered = filtered.where((r) => r.status == _statusFilter).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((request) {
        return request.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               request.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Заявки'),
        actions: [
          PopupMenuButton<RequestStatus?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) => setState(() => _statusFilter = status),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Все заявки')),
              ...RequestStatus.values.map((status) => PopupMenuItem(
                value: status,
                child: Text(status.name),
              )),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Поиск заявок...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRequests.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Заявки не найдены', 
                                 style: TextStyle(fontSize: 18, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredRequests.length,
                        itemBuilder: (context, index) {
                          final request = _filteredRequests[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: _getStatusIcon(request.status),
                              title: Text(request.title),
                              subtitle: Text(request.description, maxLines: 2),
                              trailing: Text(_formatDate(request.createdAt)),
                              onTap: () => _showRequestDetails(request),
                            ),
                          );
                        },
                      ),
          ),
        ],
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
        return const Icon(Icons.check_circle, color: Colors.green);
      case RequestStatus.rejected:
        return const Icon(Icons.cancel, color: Colors.red);
      case RequestStatus.inProgress:
        return const Icon(Icons.build, color: Colors.blue);
      case RequestStatus.waitingForAcceptance:
        return const Icon(Icons.how_to_reg, color: Colors.purple);
      case RequestStatus.waitingForInvoice:
        return const Icon(Icons.receipt_long, color: Colors.amber);
      case RequestStatus.waitingForPayment:
        return const Icon(Icons.payment, color: Colors.deepOrange);
      case RequestStatus.completed:
        return const Icon(Icons.task_alt, color: Colors.teal);
      case RequestStatus.cancelled:
        return const Icon(Icons.block, color: Colors.red);
    }
  }

  void _showRequestDetails(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(request.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Статус: ${request.statusDisplayName}'),
            const SizedBox(height: 8),
            Text('Тип: ${request.typeDisplayName}'),
            const SizedBox(height: 8),
            Text('Описание: ${request.description}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}д';
    if (diff.inHours > 0) return '${diff.inHours}ч';
    return '${diff.inMinutes}м';
  }
}
