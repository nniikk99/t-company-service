import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/service_request.dart';
import '../models/company.dart';
import 'supabase_service.dart';

class ActGeneratorService {
  /// Генерация PDF акта выполненных работ
  static Future<Uint8List> generateActPdf({
    required ServiceRequest request,
    required Company executor,
    required Company customer,
  }) async {
    final pdf = pw.Document();

    // Загружаем шрифт с поддержкой кириллицы
    // Используем Roboto из Google Fonts через пакет printing
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final dateFormat = DateFormat('dd.MM.yyyy');
    final actDate = request.actCreatedAt ?? DateTime.now();
    final actNumber = request.actNumber ?? 'Б/Н';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Шапка
              pw.Text(
                'АКТ № $actNumber от ${dateFormat.format(actDate)} г.',
                style: pw.TextStyle(font: fontBold, fontSize: 16),
              ),
              pw.Text(
                'сдачи-приемки выполненных работ (оказанных услуг)',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
              pw.Divider(thickness: 1, height: 20),

              // Стороны
              _buildPartyInfo('Исполнитель', executor, font, fontBold),
              pw.SizedBox(height: 10),
              _buildPartyInfo('Заказчик', customer, font, fontBold),
              pw.SizedBox(height: 20),

              if (request.contractNumber != null && request.contractNumber!.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Text(
                    'Основание: Договор № ${request.contractNumber}',
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                ),

              // Таблица работ
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                children: [
                  // Заголовок таблицы
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('№', fontBold, width: 30),
                      _buildTableCell('Наименование работ, услуг', fontBold),
                      _buildTableCell('Кол-во', fontBold, width: 50),
                      _buildTableCell('Цена', fontBold, width: 70),
                      _buildTableCell('Сумма', fontBold, width: 80),
                    ],
                  ),
                  // Строка с работой
                  pw.TableRow(
                    children: [
                      _buildTableCell('1', font),
                      _buildTableCell(
                        'Сервисное обслуживание: ${request.equipmentName ?? "Оборудование"} (${request.typeDisplayName}). Заявка ${request.displayId}',
                        font,
                      ),
                      _buildTableCell('1', font),
                      _buildTableCell('${request.invoiceAmount ?? 0} .руб', font),
                      _buildTableCell('${request.invoiceAmount ?? 0} .руб', font),
                    ],
                  ),
                ],
              ),

              // Итого
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Итого:  ${request.invoiceAmount ?? 0} руб. 00 коп.',
                    style: pw.TextStyle(font: fontBold, fontSize: 11),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    executor.vatIncluded ? 'В том числе НДС.' : 'Без НДС.',
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Text(
                'Всего оказано услуг на сумму: ${request.invoiceAmount ?? 0} руб. 00 коп.',
                style: pw.TextStyle(font: font, fontSize: 11),
              ),
              pw.Text(
                'Вышеуказанные услуги выполнены полностью и в срок. Заказчик претензий по объему, качеству и срокам оказания услуг не имеет.',
                style: pw.TextStyle(font: font, fontSize: 10, fontStyle: pw.FontStyle.italic),
              ),

              pw.SizedBox(height: 40),

              // Подписи
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Исполнитель:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                        pw.SizedBox(height: 20),
                        pw.Divider(thickness: 0.5, endIndent: 20),
                        pw.Text('/ ${executor.directorName ?? "________________/"}', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('М.П.', style: pw.TextStyle(font: font, fontSize: 8)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Заказчик:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                        pw.SizedBox(height: 20),
                        pw.Divider(thickness: 0.5, endIndent: 20),
                        pw.Text('/ ________________/', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('М.П.', style: pw.TextStyle(font: font, fontSize: 8)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPartyInfo(String role, Company company, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(text: '$role: ', style: pw.TextStyle(font: fontBold, fontSize: 10)),
              pw.TextSpan(
                text: '${company.name}, ИНН ${company.inn ?? ""}, КПП ${company.kpp ?? ""}, ${company.legalAddress ?? company.address ?? ""}',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, pw.Font font, {double? width}) {
    return pw.Container(
      width: width,
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9)),
    );
  }

  /// Генерация и загрузка акта в хранилище Supabase
  static Future<String> generateAndUploadAct({
    required ServiceRequest request,
    required Company executor,
    required Company customer,
  }) async {
    try {
      final pdfBytes = await generateActPdf(
        request: request,
        executor: executor,
        customer: customer,
      );

      final fileName = 'act_${request.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      // Используем существующий метод загрузки вложений, 
      // но в будущем можно сделать отдельную папку acts/
      final publicUrl = await SupabaseService.uploadRequestAttachment(
        request.id,
        pdfBytes.toList(),
        fileName,
        'application/pdf',
      );

      // Обновляем данные заявки в БД
      await SupabaseService.updateServiceRequest(request.id, {
        'executor_company_id': executor.id,
        'act_url': publicUrl,
        'act_number': request.actNumber ?? 'АКТ-${request.displayId.replaceAll("#", "")}',
        'act_created_at': DateTime.now().toIso8601String(),
      });

      return publicUrl;
    } catch (e) {
      print('❌ Ошибка генерации или загрузки акта: $e');
      rethrow;
    }
  }
}
