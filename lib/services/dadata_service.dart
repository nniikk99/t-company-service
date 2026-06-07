import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/dadata_config.dart';

/// Данные организации из ЕГРЮЛ/ЕГРИП через DaData.
class CompanyInfo {
  final String inn;
  final String? kpp;
  final String? ogrn;
  final String shortName; // короткое название с ОПФ (ООО «Ромашка»)
  final String fullName; // полное название
  final String? address; // юридический адрес
  final String? management; // руководитель (ФИО)
  final String? status; // ACTIVE / LIQUIDATED / ...
  final String? type; // LEGAL / INDIVIDUAL (юр.лицо / ИП)

  const CompanyInfo({
    required this.inn,
    this.kpp,
    this.ogrn,
    required this.shortName,
    required this.fullName,
    this.address,
    this.management,
    this.status,
    this.type,
  });

  bool get isActive => status == null || status == 'ACTIVE';

  String get statusLabel {
    switch (status) {
      case 'ACTIVE':
        return 'Действующая';
      case 'LIQUIDATING':
        return 'В стадии ликвидации';
      case 'LIQUIDATED':
        return 'Ликвидирована';
      case 'BANKRUPT':
        return 'Банкротство';
      case 'REORGANIZING':
        return 'Реорганизация';
      default:
        return 'Статус неизвестен';
    }
  }
}

/// Сервис поиска организаций по ИНН через DaData findById/party.
class DadataService {
  /// Ищет организацию по ИНН (10 цифр — юр.лицо, 12 — ИП).
  /// Возвращает null, если не найдена или ошибка сети.
  static Future<CompanyInfo?> findByInn(String inn) async {
    final clean = inn.trim();
    if (clean.length != 10 && clean.length != 12) return null;

    try {
      final resp = await http
          .post(
            Uri.parse(DadataConfig.findByIdPartyUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Token ${DadataConfig.token}',
            },
            body: jsonEncode({'query': clean}),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return null;

      final json = jsonDecode(utf8.decode(resp.bodyBytes));
      final suggestions = (json['suggestions'] as List?) ?? const [];
      if (suggestions.isEmpty) return null;

      final data = (suggestions.first as Map)['data'] as Map?;
      if (data == null) return null;

      final name = data['name'] as Map?;
      final address = data['address'] as Map?;
      final management = data['management'] as Map?;
      final state = data['state'] as Map?;

      return CompanyInfo(
        inn: (data['inn'] ?? clean).toString(),
        kpp: data['kpp']?.toString(),
        ogrn: data['ogrn']?.toString(),
        shortName: (name?['short_with_opf'] ??
                name?['full_with_opf'] ??
                (suggestions.first as Map)['value'] ??
                '')
            .toString(),
        fullName: (name?['full_with_opf'] ??
                name?['short_with_opf'] ??
                (suggestions.first as Map)['value'] ??
                '')
            .toString(),
        address: address?['value']?.toString(),
        management: management?['name']?.toString(),
        status: state?['status']?.toString(),
        type: data['type']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
