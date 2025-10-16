import 'package:flutter/material.dart';
import '../models/site.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../widgets/add_site_dialog.dart';

class SiteManagementScreen extends StatefulWidget {
  final User user;

  const SiteManagementScreen({
    super.key,
    required this.user,
  });

  @override
  State<SiteManagementScreen> createState() => _SiteManagementScreenState();
}

class _SiteManagementScreenState extends State<SiteManagementScreen> {
  List<Site> _sites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    setState(() => _isLoading = true);
    
    try {
      // Пытаемся загрузить из Supabase
      List<Site> sites = [];
      try {
        if (widget.user.companyId != null) {
          sites = await SupabaseService.getSites(widget.user.companyId!);
        }
      } catch (e) {
        print('Ошибка загрузки из Supabase: $e');
        // Если ошибка с Supabase, загружаем из локального хранилища
        final allSites = await StorageService.getSites();
        sites = allSites.where((site) => site.companyId == widget.user.companyId).toList();
      }
      
      setState(() {
        _sites = sites;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки площадок: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSite(Site site) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить площадку'),
        content: Text('Вы уверены, что хотите удалить площадку "${site.name}"?\n\nВсе связанное с ней оборудование останется без площадки.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Удаляем из Supabase
        await SupabaseService.deleteSite(site.id);
        
        // Удаляем из локального хранилища
        await StorageService.deleteSite(site.id);
        
        // Обновляем список
        await _loadSites();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Площадка удалена'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка удаления: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showAddSiteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddSiteDialog(
        user: widget.user,
        onSiteAdded: (site) {
          _loadSites();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление площадками'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Кнопка добавления
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _showAddSiteDialog,
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('Добавить площадку'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                
                // Список площадок
                Expanded(
                  child: _sites.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _sites.length,
                          itemBuilder: (context, index) {
                            final site = _sites[index];
                            return _buildSiteCard(site);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Нет площадок',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте первую площадку для мониторинга',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteCard(Site site) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFF4A90E2),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    site.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteSite(site),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.place, 'Адрес', site.address),
            if (site.phone != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.phone, 'Телефон', site.phone!),
            ],
            if (site.email != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.email, 'Email', site.email!),
            ],
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              'Создано',
              '${site.createdAt.day}.${site.createdAt.month.toString().padLeft(2, '0')}.${site.createdAt.year}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
