import 'package:flutter/material.dart';
import '../models/user.dart' as AppUserModel;
import '../services/supabase_service.dart';
import 'main_screen.dart';

class EngineerManagementScreen extends StatefulWidget {
  final AppUserModel.User adminUser;

  const EngineerManagementScreen({
    super.key,
    required this.adminUser,
  });

  @override
  State<EngineerManagementScreen> createState() => _EngineerManagementScreenState();
}

class _EngineerManagementScreenState extends State<EngineerManagementScreen> {
  List<AppUserModel.User> _engineers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEngineers();
  }

  Future<void> _loadEngineers() async {
    setState(() => _isLoading = true);

    try {
      final engineers = await SupabaseService.getEngineers();
      print('Loaded engineers: ${engineers.map((e) => e.fullName).join(', ')}');
      setState(() {
        _engineers = engineers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки инженеров: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Управление инженерами',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadEngineers,
            icon: const Icon(
              Icons.refresh,
              color: Colors.black87,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_engineers.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadEngineers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _engineers.length,
        itemBuilder: (context, index) {
          final engineer = _engineers[index];
          return _buildEngineerCard(engineer);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.engineering,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Нет инженеров',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Инженеры появятся здесь после назначения роли',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEngineerCard(AppUserModel.User engineer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _loginAsEngineer(engineer),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Аватар
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: Text(
                      _getUserInitials(engineer),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Информация об инженере
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        engineer.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        engineer.phone,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        engineer.companyName ?? 'Компания не указана',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Иконка редактирования тарифов
                IconButton(
                  onPressed: () => _editEngineerRates(engineer),
                  icon: const Icon(Icons.edit, color: Colors.blueGrey),
                  tooltip: 'Изменить тарифы',
                ),
                
                // Иконка входа
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.login,
                    color: Colors.teal,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getUserInitials(AppUserModel.User user) {
    final firstInitial = user.firstName.isNotEmpty 
        ? user.firstName[0].toUpperCase() 
        : '';
    final lastInitial = user.lastName.isNotEmpty 
        ? user.lastName[0].toUpperCase() 
        : '';
    return '$firstInitial$lastInitial';
  }

  void _loginAsEngineer(AppUserModel.User engineer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainScreen(
          user: engineer,
          adminUser: widget.adminUser,
        ),
      ),
    );
  }

  void _editEngineerRates(AppUserModel.User engineer) {
    final callOutCtrl = TextEditingController(text: engineer.callOutRate?.toString() ?? '5000');
    final hourlyCtrl = TextEditingController(text: engineer.hourlyRate?.toString() ?? '1500');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Тарифы: ${engineer.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: callOutCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ставка за выезд (руб)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: hourlyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Почасовая ставка (руб)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final callOut = double.tryParse(callOutCtrl.text);
              final hourly = double.tryParse(hourlyCtrl.text);
              
              if (callOut != null && hourly != null) {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await SupabaseService.updateUserProfile(
                    userId: engineer.id,
                    callOutRate: callOut,
                    hourlyRate: hourly,
                  );
                  await _loadEngineers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Тарифы успешно обновлены')),
                    );
                  }
                } catch (e) {
                  setState(() => _isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка обновления: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
