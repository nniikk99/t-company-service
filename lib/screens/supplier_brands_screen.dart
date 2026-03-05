import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';

class SupplierBrandsScreen extends StatefulWidget {
  final User supplier;

  const SupplierBrandsScreen({super.key, required this.supplier});

  @override
  State<SupplierBrandsScreen> createState() => _SupplierBrandsScreenState();
}

class _SupplierBrandsScreenState extends State<SupplierBrandsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _brands = [];

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('equipment_brands')
          .select()
          .eq('supplier_id', widget.supplier.id)
          .order('name');
          
      setState(() {
        _brands = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки товарных знаков: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addBrand() async {
    final TextEditingController nameController = TextEditingController();
    
    final bool? shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Добавить товарный знак'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Название бренда',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Отправить заявку'),
            ),
          ],
        );
      },
    );

    if (shouldAdd == true && nameController.text.trim().isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await _supabase.from('equipment_brands').insert({
          'name': nameController.text.trim(),
          'supplier_id': widget.supplier.id,
          'status': 'pending', // Отправляем на модерацию
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заявка на добавление бренда отправлена администратору!'), backgroundColor: Colors.green),
          );
        }
        _loadBrands();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при добавлении: $e'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои товарные знаки'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBrands,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _brands.isEmpty
              ? _buildEmptyState()
              : _buildBrandsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBrand,
        icon: const Icon(Icons.add),
        label: const Text('Добавить товарный знак'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.branding_watermark, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'У вас пока нет зарегистрированных\nтоварных знаков',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addBrand,
            icon: const Icon(Icons.add),
            label: const Text('Подать заявку'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandsList() {
    return RefreshIndicator(
      onRefresh: _loadBrands,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _brands.length,
        itemBuilder: (context, index) {
          final brand = _brands[index];
          final String status = brand['status'] ?? 'pending';
          final String name = brand['name'] ?? 'Неизвестно';
          
          IconData statusIcon;
          Color statusColor;
          String statusText;
          
          switch (status) {
            case 'approved':
              statusIcon = Icons.check_circle;
              statusColor = Colors.green;
              statusText = 'Подтвержден';
              break;
            case 'rejected':
              statusIcon = Icons.cancel;
              statusColor = Colors.red;
              statusText = 'Отклонен';
              break;
            case 'pending':
            default:
              statusIcon = Icons.hourglass_empty;
              statusColor = Colors.orange;
              statusText = 'На модерации';
              break;
          }

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
                child: const Icon(Icons.verified, color: Colors.blue),
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Row(
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
