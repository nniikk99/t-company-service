import 'package:flutter/material.dart';
import '../models/user.dart' as AppUserModel;
import '../models/user_company.dart';
import '../services/supabase_service.dart';

class MyOrganizationsScreen extends StatefulWidget {
  final AppUserModel.User user;

  const MyOrganizationsScreen({
    super.key,
    required this.user,
  });

  @override
  State<MyOrganizationsScreen> createState() => _MyOrganizationsScreenState();
}

class _MyOrganizationsScreenState extends State<MyOrganizationsScreen> {
  List<UserCompany> _userCompanies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserCompanies();
  }

  Future<void> _loadUserCompanies() async {
    setState(() => _isLoading = true);
    try {
      var companies = await SupabaseService.getUserCompanies(widget.user.id);
      
      // Если список пуст, но у пользователя в профиле есть ИНН, 
      // пробуем найти эту компанию и показать её
      if (companies.isEmpty) {
        final profile = await SupabaseService.getUserProfile(widget.user.id);
        final inn = profile?['company_inn'];
        if (inn != null) {
          final companyId = await SupabaseService.findCompanyByInn(inn);
          if (companyId != null) {
            final companyData = await SupabaseService.getCompany(companyId);
            if (companyData != null) {
              final now = DateTime.now();
              // Создаем временный объект для отображения
              companies = [
                UserCompany(
                  id: 'temp',
                  userId: widget.user.id,
                  companyId: companyId,
                  companyName: companyData['name'] ?? 'Ваша компания',
                  companyInn: inn,
                  role: widget.user.role.toString().split('.').last,
                  status: 'approved',
                  requestedAt: now,
                  createdAt: now,
                  updatedAt: now,
                )
              ];
            }
          }
        }
      }

      setState(() {
        _userCompanies = companies;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user companies: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCompanyLink(UserCompany userCompany) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение'),
        content: Text('Вы уверены, что хотите отвязать организацию "${userCompany.companyName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.deleteUserCompany(userCompany.id);
        _loadUserCompanies();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Организация удалена из вашего списка')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при удалении: $e')),
          );
        }
      }
    }
  }

  void _showAddCompanyDialog() {
    final innController = TextEditingController();
    final nameController = TextEditingController();
    bool isSearching = false;
    String? foundCompanyId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Добавить организацию'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: innController,
                decoration: InputDecoration(
                  labelText: 'ИНН организации',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () async {
                      if (innController.text.isEmpty) return;
                      setDialogState(() => isSearching = true);
                      try {
                        final companyId = await SupabaseService.findCompanyByInn(innController.text);
                        if (companyId != null) {
                          final company = await SupabaseService.getCompany(companyId);
                          setDialogState(() {
                            foundCompanyId = companyId;
                            nameController.text = company?['name'] ?? '';
                            isSearching = false;
                          });
                        } else {
                          setDialogState(() {
                            foundCompanyId = null;
                            isSearching = false;
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Организация с таким ИНН не найдена. Введите название для создания новой.')),
                            );
                          }
                        }
                      } catch (e) {
                        setDialogState(() => isSearching = false);
                      }
                    },
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название организации',
                ),
                readOnly: foundCompanyId != null,
              ),
              if (isSearching)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                
                try {
                  String companyId;
                  if (foundCompanyId != null) {
                    companyId = foundCompanyId!;
                  } else {
                    companyId = await SupabaseService.createCompanyWithInn(
                      name: nameController.text,
                      inn: innController.text,
                    );
                  }

                  await SupabaseService.requestJoinCompany(
                    userId: widget.user.id,
                    companyId: companyId,
                    companyInn: innController.text,
                    companyName: nameController.text,
                    role: 'companyResponsible',
                  );

                  Navigator.pop(context);
                  _loadUserCompanies();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _editCompany(UserCompany userCompany) async {
    final company = await SupabaseService.getCompany(userCompany.companyId);
    if (company == null) return;

    final nameController = TextEditingController(text: company['name']);
    final addressController = TextEditingController(text: company['address'] ?? '');
    final phoneController = TextEditingController(text: company['contact_phone'] ?? '');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать организацию'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Адрес'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Телефон'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SupabaseService.updateCompany(
                  userCompany.companyId,
                  {
                    'name': nameController.text,
                    'address': addressController.text,
                    'contact_phone': phoneController.text,
                    'updated_at': DateTime.now().toIso8601String(),
                  },
                );
                Navigator.pop(context);
                _loadUserCompanies();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e')),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Мои организации'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userCompanies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.apartment_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('У вас пока нет привязанных организаций'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _showAddCompanyDialog,
                        child: const Text('Добавить организацию'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _userCompanies.length,
                  itemBuilder: (context, index) {
                    final uc = _userCompanies[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE0F2FE),
                          child: Icon(Icons.business, color: Color(0xFF0284C7)),
                        ),
                        title: Text(uc.companyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ИНН: ${uc.companyInn}'),
                            Text('Статус: ${uc.statusDisplayName}', 
                              style: TextStyle(
                                color: uc.status == 'approved' ? Colors.green : (uc.status == 'rejected' ? Colors.red : Colors.orange),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'edit') {
                              _editCompany(uc);
                            } else if (val == 'delete') {
                              _deleteCompanyLink(uc);
                            }
                          },
                          itemBuilder: (context) => [
                            if (uc.status == 'approved')
                              const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                            const PopupMenuItem(value: 'delete', child: Text('Удалить')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCompanyDialog,
        backgroundColor: const Color(0xFF2563EB),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
