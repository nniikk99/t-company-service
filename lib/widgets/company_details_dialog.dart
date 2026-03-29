import 'package:flutter/material.dart';
import '../models/company.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';

import '../widgets/company_edit_dialog.dart';

class CompanyDetailsDialog extends StatefulWidget {
  final Company company;
  final bool canEdit;
  final VoidCallback? onUpdate;

  const CompanyDetailsDialog({
    super.key,
    required this.company,
    this.canEdit = false,
    this.onUpdate,
  });

  @override
  State<CompanyDetailsDialog> createState() => _CompanyDetailsDialogState();
}

class _CompanyDetailsDialogState extends State<CompanyDetailsDialog> {
  late Company _currentCompany;

  @override
  void initState() {
    super.initState();
    _currentCompany = widget.company;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 600,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentCompany.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ИНН: ${_currentCompany.inn ?? "Не указан"}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Юридическая информация'),
                    _buildDetailRow('Орг. форма', _currentCompany.orgForm, isRequired: true),
                    _buildDetailRow('КПП', _currentCompany.kpp),
                    _buildDetailRow('ОГРН', _currentCompany.ogrn),
                    _buildDetailRow('Юр. адрес', _currentCompany.legalAddress, isLongText: true),
                    _buildDetailRow('Город', _currentCompany.city),
                    _buildDetailRow('Директор', _currentCompany.directorName),
                    _buildDetailRow('Основание', _currentCompany.directorBasis),
                    
                    const SizedBox(height: 24),
                    _buildSectionHeader('Банковские реквизиты'),
                    _buildDetailRow('Банк', _currentCompany.bankName, isRequired: true),
                    _buildDetailRow('БИК', _currentCompany.bik, isRequired: true),
                    _buildDetailRow('Р/с', _currentCompany.checkingAccount, isRequired: true),
                    _buildDetailRow('К/с', _currentCompany.correspondentAccount),
                    
                    const SizedBox(height: 24),
                    _buildSectionHeader('Документы и НДС'),
                    _buildDetailRow('НДС', _currentCompany.vatIncluded ? 'Включен' : 'Без НДС'),
                    _buildDocumentRow('Подпись (скан)', _currentCompany.signatureUrl),
                    _buildDocumentRow('Печать (скан)', _currentCompany.stampUrl),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            if (widget.canEdit)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openEditDialog(context),
                  icon: const Icon(Icons.edit_note, color: Colors.white),
                  label: const Text('Заполнить реквизиты', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final bool isComplete = _currentCompany.isRequisitesComplete;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isComplete ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isComplete ? Colors.green[200]! : Colors.orange[200]!,
        ),
      ),
      child: Text(
        isComplete ? 'Заполнено' : 'Не все данные',
        style: TextStyle(
          color: isComplete ? Colors.green[700] : Colors.orange[700],
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, {bool isRequired = false, bool isLongText = false}) {
    final bool isEmpty = value == null || value.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              if (isRequired && isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text('*', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isEmpty ? 'Не заполнено' : value!,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isEmpty ? Colors.red[300] : Colors.black87,
              fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(String label, String? url) {
    final bool hasUrl = url != null && url.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          if (hasUrl)
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text('Загружено', style: TextStyle(color: Colors.green, fontSize: 13)),
              ],
            )
          else
            Text('Отсутствует', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _openEditDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => CompanyEditDialog(
        company: _currentCompany,
        onUpdate: () async {
          // После обновления реквизитов, перезагружаем данные компании
          final updatedData = await SupabaseService.getCompany(_currentCompany.id);
          if (updatedData != null) {
            setState(() {
              _currentCompany = Company.fromJson(updatedData);
            });
            widget.onUpdate?.call();
          }
        },
      ),
    );
  }
}
