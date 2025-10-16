import 'package:flutter/material.dart';
import '../models/user.dart' as AppUserModel;
import '../models/user_company.dart';
import '../services/supabase_service.dart';
import 'add_company_dialog.dart';

class UserCompaniesWidget extends StatefulWidget {
  final AppUserModel.User user;
  final Function()? onCompanySwitched;

  const UserCompaniesWidget({
    Key? key,
    required this.user,
    this.onCompanySwitched,
  }) : super(key: key);

  @override
  State<UserCompaniesWidget> createState() => _UserCompaniesWidgetState();
}

class _UserCompaniesWidgetState extends State<UserCompaniesWidget> {
  List<UserCompany> _companies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoading = true);
    try {
      final companies = await SupabaseService.getUserCompanies(widget.user.id);
      setState(() {
        _companies = companies;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Ошибка загрузки компаний пользователя: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _switchToCompany(UserCompany company) async {
    if (company.status != 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Компания еще не подтверждена'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await SupabaseService.switchActiveCompany(
        widget.user.id,
        company.companyId,
        company.companyInn,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Переключились на компанию "${company.companyName}"'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onCompanySwitched?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка переключения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddCompanyDialog() {
    showDialog(
      context: context,
      builder: (context) => AddCompanyDialog(
        user: widget.user,
        onCompanyAdded: () {
          _loadCompanies();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Текущая компания с плюсиком
        _buildCompanyRow(
          companyName: widget.user.companyName ?? 'Тест компания',
          companyInn: widget.user.companyInn ?? '0000000001',
          isActive: true,
          showPlus: true,
        ),
        
        // Дополнительные компании
        ..._companies.map((company) => _buildCompanyRow(
          companyName: company.companyName,
          companyInn: company.companyInn,
          isActive: false,
          showPlus: false,
          status: company.status,
          onTap: company.status == 'approved' 
              ? () => _switchToCompany(company)
              : null,
        )),
      ],
    );
  }

  Widget _buildCompanyRow({
    required String companyName,
    required String companyInn,
    required bool isActive,
    required bool showPlus,
    String? status,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? Colors.blue : Colors.grey[300]!,
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    companyName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isActive ? Colors.blue[800] : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ИНН: $companyInn',
                    style: TextStyle(
                      fontSize: 14,
                      color: isActive ? Colors.blue[600] : Colors.grey[600],
                    ),
                  ),
                  if (status != null && status != 'approved')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getStatusText(status),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (showPlus)
            GestureDetector(
              onTap: _showAddCompanyDialog,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            )
          else if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.swap_horiz,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved':
        return 'Подтверждена';
      case 'pending':
        return 'Ожидает';
      case 'rejected':
        return 'Отклонена';
      default:
        return 'Неизвестно';
    }
  }
}