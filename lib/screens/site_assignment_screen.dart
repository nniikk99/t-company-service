import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/site.dart';
import '../services/supabase_service.dart';

class SiteAssignmentScreen extends StatefulWidget {
  final User manager;
  final User currentUser;

  const SiteAssignmentScreen({
    super.key,
    required this.manager,
    required this.currentUser,
  });

  @override
  State<SiteAssignmentScreen> createState() => _SiteAssignmentScreenState();
}

class _SiteAssignmentScreenState extends State<SiteAssignmentScreen> {
  List<Site> _allSites = [];
  List<Site> _assignedSites = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Загружаем все площадки компании менеджера
      final allSites = await SupabaseService.getSites(widget.manager.companyId!);
      
      // Фильтруем только площадки той же компании
      final companySites = allSites.where((site) => 
        site.companyId == widget.manager.companyId
      ).toList();

      // Получаем назначенные площадки
      final assignedSites = companySites.where((site) => 
        widget.manager.assignedSiteIds?.contains(site.id) == true
      ).toList();

      setState(() {
        _allSites = companySites;
        _assignedSites = assignedSites;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки площадок: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _assignSite(Site site) async {
    try {
      await SupabaseService.assignSiteToManager(
        widget.manager.id,
        site.id,
        widget.currentUser.id,
      );
      
      // Обновляем локальное состояние
      setState(() {
        _assignedSites.add(site);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Площадка "${site.name}" назначена менеджеру'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка назначения площадки: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unassignSite(Site site) async {
    try {
      await SupabaseService.unassignSiteFromManager(
        widget.manager.id,
        site.id,
        widget.currentUser.id,
      );
      
      // Обновляем локальное состояние
      setState(() {
        _assignedSites.removeWhere((s) => s.id == site.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Площадка "${site.name}" отменена у менеджера'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка отмены назначения: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Назначение площадок'),
            Text(
              '${widget.manager.fullName} (${widget.manager.roleDisplayName})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSites,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Информация о менеджере
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Информация о менеджере',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('ФИО: ${widget.manager.fullName}'),
                          Text('Компания: ${widget.manager.companyName}'),
                          Text('ИНН: ${widget.manager.companyInn}'),
                          Text('Назначено площадок: ${_assignedSites.length}'),
                        ],
                      ),
                    ),
                    
                    // Список площадок
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _allSites.length,
                        itemBuilder: (context, index) {
                          final site = _allSites[index];
                          final isAssigned = _assignedSites.any((s) => s.id == site.id);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                isAssigned ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isAssigned ? Colors.green : Colors.grey,
                              ),
                              title: Text(site.name),
                              subtitle: Text(site.address ?? 'Адрес не указан'),
                              trailing: isAssigned
                                  ? ElevatedButton(
                                      onPressed: () => _unassignSite(site),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Отменить'),
                                    )
                                  : ElevatedButton(
                                      onPressed: () => _assignSite(site),
                                      child: const Text('Назначить'),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
