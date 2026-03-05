import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';

class SupplierFleetScreen extends StatefulWidget {
  final User supplier;

  const SupplierFleetScreen({super.key, required this.supplier});

  @override
  State<SupplierFleetScreen> createState() => _SupplierFleetScreenState();
}

class _SupplierFleetScreenState extends State<SupplierFleetScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _equipmentList = [];
  Map<String, int> _statusCounts = {};
  Map<String, int> _modelCounts = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      // 1. Получаем список одобренных брендов текущего поставщика
      final brandsResponse = await _supabase
          .from('equipment_brands')
          .select('name')
          .eq('supplier_id', widget.supplier.id)
          .eq('status', 'approved');
      
      final brands = (brandsResponse as List).map((e) => e['name'] as String).toList();
      
      if (brands.isEmpty) {
        setState(() {
          _equipmentList = [];
          _isLoading = false;
        });
        return;
      }

      // 2. Получаем все оборудование, у которого производитель - один из этих брендов
      final equipmentResponse = await _supabase
          .from('equipment')
          .select('id, name, model, manufacturer, status, type')
          .inFilter('manufacturer', brands);
          
      _equipmentList = List<Map<String, dynamic>>.from(equipmentResponse);
      
      // 3. Вычисляем статистику
      _statusCounts = {};
      _modelCounts = {};
      
      for (var eq in _equipmentList) {
        final status = eq['status'] as String? ?? 'unknown';
        final displayModel = '${eq['manufacturer']} ${eq['model']}';
        
        _statusCounts[status] = (_statusCounts[status] ?? 0) + 1;
        _modelCounts[displayModel] = (_modelCounts[displayModel] ?? 0) + 1;
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при загрузке аналитики парка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getStatusFullName(String status) {
    switch (status) {
      case 'active': return 'Активно';
      case 'maintenance': return 'Обслуживается';
      case 'repair': return 'В ремонте';
      case 'broken': return 'Неисправно';
      case 'inactive': return 'Простаивает';
      default: return 'Неизвестно';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'maintenance': return Colors.orange;
      case 'repair': return Colors.redAccent;
      case 'broken': return Colors.red;
      case 'inactive': return Colors.grey;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Аналитика парка'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _equipmentList.isEmpty
              ? _buildEmptyState()
              : _buildDashboard(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Данных пока нет',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Убедитесь, что у вас есть одобренные бренды и клиенты добавили оборудование вашей марки.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Total Count
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: const Icon(Icons.precision_manufacturing, size: 30, color: Colors.blue),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Всего оборудования',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_equipmentList.length} ед.',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Status breakdown
        const Text(
          'Статусы эксплуатации парка',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        ..._statusCounts.entries.map((entry) {
          final percentage = (entry.value / _equipmentList.length) * 100;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_getStatusFullName(entry.key), style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('${entry.value} (${percentage.toStringAsFixed(1)}%)', style: TextStyle(color: Colors.grey[700])),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey[200],
                  color: _getStatusColor(entry.key),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
              ],
            ),
          );
        }),
        
        const SizedBox(height: 24),
        
        // Models breakdown
        const Text(
          'Популярные модели в сети',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _modelCounts.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final sortedModels = _modelCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final model = sortedModels[index];
              return ListTile(
                leading: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                title: Text(model.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${model.value} шт',
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
