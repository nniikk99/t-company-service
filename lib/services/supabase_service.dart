import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/user.dart' as AppUserModel;
import '../models/equipment.dart';
import '../models/site.dart';
import '../models/service_request.dart';
import '../models/user_company.dart';
import '../models/equipment_model.dart';
import 'storage_service.dart';
import 'telegram_bot_service.dart';
import '../models/request_message.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Убираем старые ключи и методы инициализации
  // Supabase уже инициализирован в main.dart

  // === AUTHENTICATION ===

  static User? get currentUser => _client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  static Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signUp(String email, String password, {
    required String firstName,
    required String lastName,
    required String role,
    String? companyId,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
      },
    );

    return response;
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // === USER PROFILES ===

  static Future<void> createUserProfile({
    required String userId,
    required String email,
    required String firstName,
    required String lastName,
    required String role,
    String? companyId,
    String? phone,
    String? position,
    String? companyName,
    String? companyInn,
    String? companyAddress,
    String? companyPhone,
    String? companyEmail,
    String? passwordHash,
    bool canManageRequestsIndependently = false,
    List<String>? assignedSiteIds,
    String? createdBy,
    int? telegramId,
    String? telegramUsername,
    DateTime? birthDate,
    String? comments,
    bool isOnVacation = false,
  }) async {
    await _client.from('user_profiles').insert({
      'id': userId,
      'company_id': companyId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'role': role,
      'position': position ?? '',
      'company_name': companyName,
      'company_inn': companyInn,
      'company_address': companyAddress,
      'company_phone': companyPhone,
      'company_email': companyEmail,
      'password_hash': passwordHash,
      'can_manage_requests_independently': canManageRequestsIndependently,
      'assigned_site_ids': assignedSiteIds,
      'created_by': createdBy,
      'telegram_id': telegramId,
      'telegram_username': telegramUsername,
      'birth_date': birthDate?.toIso8601String().split('T')[0], // Только дата без времени
      'comments': comments,
      'is_on_vacation': isOnVacation,
    });
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await _client
        .from('user_profiles')
        .select('*, companies(*)')
        .eq('id', userId)
        .single();
    
    print('🔍 Загружен профиль пользователя $userId:');
    print('  - assigned_site_ids: ${response['assigned_site_ids']}');
    print('  - role: ${response['role']}');
    
    return response;
  }

  static Future<List<Map<String, dynamic>>> getCompanyUsers(String companyId) async {
    final response = await _client
        .from('user_profiles')
        .select('*')
        .eq('company_id', companyId);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> updateUserProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? position,
    String? companyName,
    String? companyInn,
    String? companyAddress,
    String? companyPhone,
    String? companyEmail,
    DateTime? birthDate,
    String? comments,
    bool? isOnVacation,
    String? role,
  }) async {
    final updateData = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Добавляем только те поля, которые переданы (не null)
    if (firstName != null) updateData['first_name'] = firstName;
    if (lastName != null) updateData['last_name'] = lastName;
    if (email != null) updateData['email'] = email;
    if (phone != null) updateData['phone'] = phone;
    if (position != null) updateData['position'] = position;
    if (companyName != null) updateData['company_name'] = companyName;
    if (companyInn != null) updateData['company_inn'] = companyInn;
    if (companyAddress != null) updateData['company_address'] = companyAddress;
    if (companyPhone != null) updateData['company_phone'] = companyPhone;
    if (companyEmail != null) updateData['company_email'] = companyEmail;
    if (birthDate != null) updateData['birth_date'] = birthDate.toIso8601String().split('T')[0];
    if (comments != null) updateData['comments'] = comments;
    if (isOnVacation != null) updateData['is_on_vacation'] = isOnVacation;
    if (role != null) updateData['role'] = role;

    await _client
        .from('user_profiles')
        .update(updateData)
        .eq('id', userId);
  }

  static Future<void> deleteUserProfile(String userId) async {
    await _client.from('user_profiles').delete().eq('id', userId);
  }

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await _client
        .from('user_profiles')
        .select('*')
        .order('last_name');
    return List<Map<String, dynamic>>.from(response);
  }

  // === COMPANIES ===

  // старый вариант createCompany оставляем для совместимости имени,
  // но перенаправляем на новый метод с inn nullable
  static Future<String> createCompany({
    required String name,
    String? description,
    String? contactEmail,
    String? contactPhone,
    String? address,
  }) async {
    final response = await _client.from('companies').insert({
      'name': name,
      'description': description,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'address': address,
    }).select().single();

    return response['id'];
  }

  static Future<List<Map<String, dynamic>>> getAllCompanies() async {
    final response = await _client
        .from('companies')
        .select('*')
        .order('name');

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>?> getCompany(String companyId) async {
    final response = await _client
        .from('companies')
        .select('*')
        .eq('id', companyId)
        .single();

    return response;
  }

  static Future<void> updateCompany(String companyId, Map<String, dynamic> updates) async {
    await _client.from('companies').update(updates).eq('id', companyId);
  }

  static Future<void> deleteCompany(String companyId) async {
    await _client.from('companies').delete().eq('id', companyId);
  }

  // === SITES === (удалены старые методы, оставлены новые в конце файла)

  // === EQUIPMENT ===


  static Future<List<Map<String, dynamic>>> getCompanyEquipment(String companyId) async {
    final response = await _client
        .from('equipment')
        .select('*, sites(name, address)')
        .eq('company_id', companyId)
        .order('name');

    return List<Map<String, dynamic>>.from(response);
  }



  // === SERVICE REQUESTS ===

  static Future<String> createServiceRequest({
    required String companyId,
    required String equipmentId,
    required String userId,
    required String title,
    required String description,
    required String type,
    String? companyInn,
    String priority = 'medium',
    double? estimatedCost,
    DateTime? scheduledDate,
    String? notes,
    List<String>? attachments,
    bool requiresApproval = true, // Требуется ли согласование
  }) async {
    // Получаем supplier_id из equipment
    String? supplierId;
    try {
      final equipmentResponse = await _client
          .from('equipment')
          .select('supplier_id')
          .eq('id', equipmentId)
          .maybeSingle();
      
      if (equipmentResponse != null && equipmentResponse['supplier_id'] != null) {
        supplierId = equipmentResponse['supplier_id'];
      }
    } catch (e) {
      print('⚠️ Ошибка получения supplier_id из equipment: $e');
      // Продолжаем создание заявки даже если не удалось получить supplier_id
    }

    // Определяем начальный статус
    final initialStatus = requiresApproval ? 'pending' : 'approved';

    // Подготавливаем данные для вставки
    final Map<String, dynamic> insertData = {
      'equipment_id': equipmentId,
      'user_id': userId,
      'supplier_id': supplierId, // Сохраняем supplier_id из equipment
      'title': title,
      'description': description,
      'message': description, // Совместимость с полем message
      'type': type,
      'status': initialStatus,
      'priority': priority == 'medium' ? 'normal' : priority,
      'estimated_cost': estimatedCost,
      'scheduled_at': scheduledDate?.toIso8601String(),
      'notes': notes,
      'attachments': attachments,
      'company_inn': companyInn,
    };

    // Добавляем company_id только если он не пустой
    if (companyId.isNotEmpty) {
      insertData['company_id'] = companyId;
    }

    final response = await _client.from('service_requests').insert(insertData).select().single();

    return response['id'];
  }

  static Future<void> deleteServiceRequest(String requestId) async {
    try {
      await _client.from('service_requests').delete().eq('id', requestId);
    } catch (e) {
      print('❌ Ошибка удаления заявки: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getCompanyServiceRequests(String companyId) async {
    final response = await _client
        .from('service_requests')
        .select('*, equipment(name, model), author:user_profiles!service_requests_user_id_fkey(first_name, last_name, phone, role, company_name)')
        .eq('company_id', companyId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getAllServiceRequests() async {
    final response = await _client
        .from('service_requests')
        .select('''
          *,
          author:user_profiles!service_requests_user_id_fkey(first_name, last_name, phone, role, company_name),
          equipment(
            name, model, serial_number,
            site:sites(
              name, address,
              manager:user_profiles!sites_contact_person_id_fkey(first_name, last_name, phone)
            ),
            operator:user_profiles!equipment_responsible_user_id_fkey(first_name, last_name, phone)
          ),
          assigned_engineer:user_profiles!service_requests_assigned_engineer_id_fkey(first_name, last_name)
        ''')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getCompanyRequestsByInn(String inn) async {
    final response = await _client
        .from('service_requests')
        .select('''
          *,
          author:user_profiles!service_requests_user_id_fkey(first_name, last_name, phone, role, company_name),
          equipment(
            name, model, serial_number,
            site:sites(
              name, address,
              manager:user_profiles!sites_contact_person_id_fkey(first_name, last_name, phone)
            ),
            operator:user_profiles!equipment_responsible_user_id_fkey(first_name, last_name, phone)
          ),
          assigned_engineer:user_profiles!service_requests_assigned_engineer_id_fkey(first_name, last_name)
        ''')
        .eq('company_inn', inn)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getUserServiceRequests(String userId) async {
    final response = await _client
        .from('service_requests')
        .select('''
          *,
          author:user_profiles!service_requests_user_id_fkey(first_name, last_name, phone, role, company_name),
          equipment(
            name, model, serial_number,
            site:sites(
              name, address,
              manager:user_profiles!sites_contact_person_id_fkey(first_name, last_name, phone)
            ),
            operator:user_profiles!equipment_responsible_user_id_fkey(first_name, last_name, phone)
          ),
          assigned_engineer:user_profiles!service_requests_assigned_engineer_id_fkey(first_name, last_name)
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> updateServiceRequest(String requestId, Map<String, dynamic> updates) async {
    await _client
        .from('service_requests')
        .update(updates)
        .eq('id', requestId);
  }

  static Future<void> approveServiceRequest(String requestId, String approvedBy) async {
    await _client
        .from('service_requests')
        .update({
          'status': 'approved',
          'approved_by': approvedBy,
          'approved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
        
    // Уведомляем участников
    _notifyParties(requestId, 'Заявка одобрена', 'Ваша заявка одобрена администратором.');
  }

  // === ATTACHMENTS / STORAGE ===

  /// Загрузка вложения для заявки в Supabase Storage
  static Future<String> uploadRequestAttachment(String requestId, List<int> fileBytes, String fileName, String contentType) async {
    try {
      final fileExt = fileName.split('.').last;
      final path = '$requestId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      print('📤 Загрузка файла в Storage: attachments/$path');
      
      await _client.storage.from('attachments').uploadBinary(
        path,
        Uint8List.fromList(fileBytes),
        fileOptions: FileOptions(contentType: contentType, cacheControl: '3600', upsert: true),
      );
      
      final publicUrl = _client.storage.from('attachments').getPublicUrl(path);
      print('✅ Файл загружен, URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Ошибка загрузки файла в Storage: $e');
      rethrow;
    }
  }

  /// Загрузка счета (PDF или фото)
  static Future<String> uploadInvoiceFile(String requestId, Uint8List fileBytes, String fileName) async {
    try {
      final fileExt = fileName.split('.').last;
      final path = 'invoices/$requestId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      print('📤 Загрузка счета в Storage: attachments/$path');
      
      await _client.storage.from('attachments').uploadBinary(
        path,
        fileBytes,
        fileOptions: const FileOptions(
          contentType: 'application/pdf', // По умолчанию PDF, если это фото - storage сам определит или мы передадим
          upsert: true
        ),
      );
      
      final publicUrl = _client.storage.from('attachments').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      print('❌ Ошибка загрузки счета: $e');
      rethrow;
    }
  }

  /// Обновление списка вложений в БД
  static Future<void> updateServiceRequestAttachments(String requestId, List<String> attachments) async {
    await _client
        .from('service_requests')
        .update({'attachments': attachments})
        .eq('id', requestId);
  }


  // === PARTS REQUESTS ===

  static Future<String> createPartsRequest({
    required String companyId,
    required String equipmentId,
    required String userId,
    String? serviceRequestId,
    required String partName,
    String? partNumber,
    int quantity = 1,
    String? description,
    double? estimatedCost,
    String? supplier,
  }) async {
    final response = await _client.from('parts_requests').insert({
      'company_id': companyId,
      'equipment_id': equipmentId,
      'user_id': userId,
      'service_request_id': serviceRequestId,
      'part_name': partName,
      'part_number': partNumber,
      'quantity': quantity,
      'description': description,
      'estimated_cost': estimatedCost,
      'supplier': supplier,
    }).select().single();

    return response['id'];
  }

  static Future<List<Map<String, dynamic>>> getCompanyPartsRequests(String companyId) async {
    final response = await _client
        .from('parts_requests')
        .select('*, equipment(name, model), user_profiles(first_name, last_name)')
        .eq('company_id', companyId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // === NOTIFICATIONS ===

  static Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? relatedId,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('📤 Создаем уведомление:');
      print('  - User ID: $userId');
      print('  - Title: $title');
      print('  - Message: $message');
      print('  - Type: $type');
      print('  - Related ID: $relatedId');
      print('  - Data: $data');
      
      final response = await _client.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'related_id': relatedId,
        'data': data,
      }).select();
      
      print('✅ Уведомление создано: $response');
    } catch (e) {
      print('❌ Ошибка создания уведомления: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    try {
      print('🔍 Загружаем уведомления для пользователя: $userId');
      
      final response = await _client
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      print('📋 Получено уведомлений из Supabase: ${response.length}');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Ошибка загрузки уведомлений для пользователя $userId: $e');
      return [];
    }
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  // === REALTIME SUBSCRIPTIONS ===

  static RealtimeChannel subscribeToUserNotifications(String userId, Function(Map<String, dynamic>) onData) {
    return _client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onData(payload.newRecord),
        )
        .subscribe();
  }

  static RealtimeChannel subscribeToCompanyRequests(String companyId, Function(Map<String, dynamic>) onData) {
    return _client
        .channel('requests:$companyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'service_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: companyId,
          ),
          callback: (payload) => onData(payload.newRecord ?? payload.oldRecord ?? {}),
        )
        .subscribe();
  }

  // Sites (площадки)
  static Future<List<Site>> getSites(String companyId) async {
    try {
      print('🔵 Загрузка площадок для companyId: $companyId');
      
      // Пытаемся найти площадки по UUID
      var response = await _client
          .from('sites')
          .select()
          .eq('company_id', companyId);
      
      print('🔵 Найдено площадок по UUID: ${(response as List).length}');
      
      // Если не найдено, пытаемся найти по ИНН компании
      if ((response as List).isEmpty) {
        print('🔵 Пытаемся найти по ИНН...');
        final company = await _client
            .from('companies')
            .select('id')
            .eq('company_inn', companyId)
            .maybeSingle();
        
        if (company != null) {
          print('🔵 Найдена компания по ИНН: ${company['id']}');
          response = await _client
              .from('sites')
              .select()
              .eq('company_id', company['id']);
          print('🔵 Найдено площадок по ИНН: ${(response as List).length}');
        }
      }
      
      final sites = (response as List)
          .map((json) => Site.fromJson(json))
          .toList();
      
      print('✅ Загружено площадок: ${sites.length}');
      return sites;
    } catch (e) {
      print('❌ Ошибка загрузки площадок: $e');
      print('❌ Тип ошибки: ${e.runtimeType}');
      return [];
    }
  }

  static Future<Site> createSite(Site site) async {
    try {
      print('🔵 Создание площадки: ${site.name}');
      print('🔵 companyId: ${site.companyId}');
      print('🔵 companyInn: ${site.companyInn}');
      print('🔵 site.toJson(): ${site.toJson()}');
      
      final response = await _client
          .from('sites')
          .insert(site.toJson())
          .select()
          .single();
      
      print('✅ Площадка успешно создана: ${response['id']}');
      return Site.fromJson(response);
    } catch (e) {
      print('❌ Ошибка создания площадки: $e');
      print('❌ Тип ошибки: ${e.runtimeType}');
      rethrow;
    }
  }

  static Future<Site> updateSite(Site site) async {
    final response = await _client
        .from('sites')
        .update(site.toJson())
        .eq('id', site.id)
        .select()
        .single();
    
    return Site.fromJson(response);
  }

  static Future<void> deleteSite(String siteId) async {
    await _client
        .from('sites')
        .delete()
        .eq('id', siteId);
  }

  // Equipment (оборудование)
  static Future<List<Equipment>> getEquipment(String companyId) async {
    final response = await _client
        .from('equipment')
        .select()
        .eq('company_id', companyId);
    
    return (response as List)
        .map((json) => Equipment.fromJson(json))
        .toList();
  }

  static Future<Equipment> createEquipment(Equipment equipment) async {
    final response = await _client
        .from('equipment')
        .insert(equipment.toJson())
        .select()
        .single();
    
    return Equipment.fromJson(response);
  }

  static Future<Equipment> updateEquipment(Equipment equipment) async {
    final response = await _client
        .from('equipment')
        .update(equipment.toJson())
        .eq('id', equipment.id)
        .select()
        .single();
    
    return Equipment.fromJson(response);
  }

  static Future<void> deleteEquipment(String equipmentId) async {
    await _client
        .from('equipment')
        .delete()
        .eq('id', equipmentId);
  }

  static Future<Equipment?> getEquipmentById(String equipmentId) async {
    try {
      final response = await _client
          .from('equipment')
          .select('*, sites(*)')
          .eq('id', equipmentId)
          .maybeSingle();
      
      return response != null ? Equipment.fromJson(response) : null;
    } catch (e) {
      print('❌ Ошибка загрузки оборудования: $e');
      return null;
    }
  }

  static Future<List<Equipment>> getEquipmentBySite(String siteId) async {
    final response = await _client
        .from('equipment')
        .select()
        .eq('site_id', siteId);
    
    return (response as List)
        .map((json) => Equipment.fromJson(json))
        .toList();
  }

  /// Получение оборудования с учетом роли пользователя
  static Future<List<Equipment>> getUserEquipment(AppUserModel.User user) async {
    try {
      print('🔍 Загружаем оборудование для пользователя: ${user.fullName} (${user.role})');
      print('🔍 assigned_site_ids: ${user.assignedSiteIds}');
      print('🔍 equipment_ids: ${user.equipmentIds}');
      print('🔍 company_id: ${user.companyId}');
      
      List<Equipment> equipment = [];
      
      switch (user.role) {
        case AppUserModel.UserRole.administrator:
          // Администраторы видят все оборудование всех компаний
          print('🔍 Загружаем все оборудование для администратора');
          final response = await _client
              .from('equipment')
              .select('*')
              .order('name');
          equipment = (response as List)
              .map((json) => Equipment.fromJson(json))
              .toList();
          break;
          
        case AppUserModel.UserRole.companyResponsible:
          // Ответственное лицо видит все оборудование своей компании
          print('🔍 Загружаем оборудование компании для ответственного лица');
          if (user.companyId != null) {
            equipment = await getEquipment(user.companyId!);
          }
          break;
          
        case AppUserModel.UserRole.siteManager:
          // Менеджер площадки видит оборудование только назначенных ему площадок + неназначенное оборудование своей компании
          print('🔍 Загружаем оборудование для менеджера площадки');
          if (user.assignedSiteIds != null && user.assignedSiteIds!.isNotEmpty) {
            final siteIds = user.assignedSiteIds!.map((id) => '"$id"').join(',');
            final response = await _client
                .from('equipment')
                .select('*')
                .or('site_id.in.($siteIds),and(company_id.eq.${user.companyId},site_id.is.null)')
                .order('name');
            equipment = (response as List)
                .map((json) => Equipment.fromJson(json))
                .toList();
          } else if (user.companyId != null) {
            // Если нет назначенных площадок, все равно показываем неназначенное оборудование компании
            final response = await _client
                .from('equipment')
                .select('*')
                .isFilter('site_id', null)
                .eq('company_id', user.companyId!)
                .order('name');
            equipment = (response as List)
                .map((json) => Equipment.fromJson(json))
                .toList();
          }
          break;
          
        case AppUserModel.UserRole.operatorPM:
          // Оператор ПМ видит оборудование с назначенных ему площадок + неназначенное оборудование своей компании
          print('🔍 Загружаем оборудование для оператора ПМ');
          if (user.assignedSiteIds != null && user.assignedSiteIds!.isNotEmpty) {
            final siteIds = user.assignedSiteIds!.map((id) => '"$id"').join(',');
            final response = await _client
                .from('equipment')
                .select('*')
                .or('site_id.in.($siteIds),and(company_id.eq.${user.companyId},site_id.is.null)')
                .order('name');
            equipment = (response as List)
                .map((json) => Equipment.fromJson(json))
                .toList();
          } else if (user.companyId != null) {
            final response = await _client
                .from('equipment')
                .select('*')
                .isFilter('site_id', null)
                .eq('company_id', user.companyId!)
                .order('name');
            equipment = (response as List)
                .map((json) => Equipment.fromJson(json))
                .toList();
          }
          break;
          
        case AppUserModel.UserRole.engineer:
          // Инженеры не видят оборудование (работают только с заявками)
          print('🔍 Инженер не видит оборудование');
          equipment = [];
          break;
          
        default:
          // Для остальных ролей - пустой список
          print('🔍 Неизвестная роль, возвращаем пустой список');
          equipment = [];
          break;
      }
      
      print('✅ Загружено оборудования: ${equipment.length}');
      return equipment;
    } catch (e) {
      print('❌ Ошибка загрузки оборудования для пользователя ${user.id}: $e');
      return [];
    }
  }

  /// Обновление статуса оборудования (для оператора ПМ)
  static Future<void> updateEquipmentStatus(String equipmentId, String status) async {
    await _client
        .from('equipment')
        .update({'status': status})
        .eq('id', equipmentId);
  }

  // === AUTHENTICATION & USERS ===

  static Future<AppUserModel.User> createUser(AppUserModel.User user) async {
    final response = await _client
        .from('user_profiles')
        .insert(user.toJson())
        .select()
        .single();
    
    return AppUserModel.User.fromJson(response);
  }

  static Future<String?> findCompanyByInn(String inn) async {
    final response = await _client
        .from('companies')
        .select('id')
        .or('inn.eq.$inn,company_inn.eq.$inn')
        .maybeSingle();
    
    return response?['id'];
  }

  static Future<String> createCompanyWithInn({
    required String name,
    required String inn,
    String? description,
    String? orgType, // 'customer' | 'supplier' | 'service_partner'
  }) async {
    final Map<String, dynamic> insertData = {
      'name': name,
      'inn': inn,
      'company_inn': inn,
      if (description != null) 'description': description,
      if (orgType != null) 'org_type': orgType,
    };
    
    final response = await _client.from('companies').insert(insertData).select().single();

    return response['id'];
  }

  /// Обновление типа организации компании
  static Future<void> updateCompanyOrgType(String companyId, String orgType) async {
    await _client
        .from('companies')
        .update({'org_type': orgType})
        .eq('id', companyId);
  }

  static Future<void> changePassword(String userId, String newPasswordHash) async {
    await _client
        .from('user_profiles')
        .update({'password_hash': newPasswordHash})
        .eq('id', userId);
  }

  /// Получение всех пользователей (для восстановления паролей)
  static Future<List<AppUserModel.User>> getUsers() async {
    try {
      final response = await _client
          .from('user_profiles')
          .select()
          .order('created_at', ascending: false);
      
      return response.map<AppUserModel.User>((json) => AppUserModel.User.fromJson(json)).toList();
    } catch (e) {
      print('Error getting users from Supabase: $e');
      // Возвращаем пустой список в случае ошибки
      return [];
    }
  }

  // === MULTIPLE COMPANIES MANAGEMENT ===

  /// Получение всех компаний пользователя
  static Future<List<UserCompany>> getUserCompanies(String userId) async {
    try {
      final response = await _client
          .from('user_companies')
          .select('*, companies(name)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return response.map<UserCompany>((json) {
        final companyData = json['companies'] as Map<String, dynamic>?;
        return UserCompany.fromJson({
          ...json,
          'company_name': companyData?['name'] ?? '',
        });
      }).toList();
    } catch (e) {
      print('Error getting user companies: $e');
      return [];
    }
  }

  static Future<void> deleteUserCompany(String userCompanyId) async {
    await _client.from('user_companies').delete().eq('id', userCompanyId);
  }

  /// Получение одобренных компаний пользователя
  static Future<List<UserCompany>> getApprovedUserCompanies(String userId) async {
    try {
      final response = await _client
          .from('user_companies')
          .select('*, companies(name)')
          .eq('user_id', userId)
          .eq('status', 'approved')
          .order('created_at', ascending: false);
      
      return response.map<UserCompany>((json) {
        final companyData = json['companies'] as Map<String, dynamic>?;
        return UserCompany.fromJson({
          ...json,
          'company_name': companyData?['name'] ?? '',
        });
      }).toList();
    } catch (e) {
      print('Error getting approved user companies: $e');
      return [];
    }
  }

  /// Создание заявки на присоединение к существующей компании
  static Future<UserCompany> requestJoinCompany({
    required String userId,
    required String companyId,
    required String companyInn,
    required String companyName,
    required String role,
    String status = 'pending',
  }) async {
    final Map<String, dynamic> insertData = {
      'user_id': userId,
      'company_id': companyId,
      'company_inn': companyInn,
      'company_name': companyName,
      'role': role,
      'status': status,
      'requested_at': DateTime.now().toIso8601String(),
    };
    
    if (status == 'approved') {
      insertData['approved_at'] = DateTime.now().toIso8601String();
    }

    final response = await _client
        .from('user_companies')
        .insert(insertData)
        .select()
        .single();
        
    // Создаем уведомление админам только для новых заявок (статус pending)
    if (status == 'pending') {
      try {
        await createNotification(
          userId: '00000000-0000-0000-0000-000000000001',
          title: 'Заявка на присоединение к компании',
          message: 'Пользователь запросил роль $role в "$companyName" (ИНН $companyInn).',
          type: 'companyJoinRequest',
          relatedId: response['id'],
          data: {'requestId': response['id']},
        );
      } catch (_) {}
    }
    
    return UserCompany.fromJson(response);
  }

  /// Создание заявки на создание новой компании
  static Future<CompanyRequest> requestCreateCompany({
    required String userId,
    required String companyName,
    required String companyInn,
    String? companyAddress,
    String? companyPhone,
    String? companyEmail,
    String requestedRole = 'companyResponsible',
    String? orgType, // 'customer' | 'supplier' | 'service_partner'
  }) async {
    print('🔍 Создание заявки на компанию:');
    print('  - User ID: $userId');
    print('  - Company Name: $companyName');
    print('  - Company INN: $companyInn');
    print('  - Role: $requestedRole');
    
    // Пытаемся проверить существование пользователя, но не блокируем процесс,
    // чтобы не мешать отправке заявки в средах без синхронизации профилей
    try {
      final userCheck = await _client
          .from('user_profiles')
          .select('id, first_name, last_name')
          .eq('id', userId)
          .maybeSingle();
      if (userCheck != null) {
        print('✅ Пользователь найден: ${userCheck['first_name']} ${userCheck['last_name']}');
      } else {
        print('⚠️ Пользователь с ID $userId не найден в user_profiles. Продолжаем без проверки.');
      }
    } catch (e) {
      print('⚠️ Ошибка проверки пользователя (игнорируем): $e');
    }
    
    final response = await _client
        .from('company_requests')
        .insert({
          'user_id': userId,
          'company_name': companyName,
          'company_inn': companyInn,
          'company_address': companyAddress,
          'company_phone': companyPhone,
          'company_email': companyEmail,
          'requested_role': requestedRole,
          'status': 'pending',
          if (orgType != null) 'org_type': orgType,
        })
        .select()
        .single();
    // Уведомление админам
    try {
      await createNotification(
        userId: '00000000-0000-0000-0000-000000000001',
        title: 'Заявка на создание компании',
        message: 'Запрос на создание "$companyName" (ИНН $companyInn).',
        type: 'companyCreationRequest',
        relatedId: response['id'],
        data: {'requestId': response['id']},
      );
    } catch (_) {}
    
    return CompanyRequest.fromJson(response);
  }

  /// Проверка существования компании по ИНН (полная информация)
  static Future<Map<String, dynamic>?> findCompanyByInnFull(String inn) async {
    try {
      final response = await _client
          .from('companies')
          .select('*')
          .eq('company_inn', inn)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('Error finding company by INN: $e');
      return null;
    }
  }

  /// Проверка, занята ли компания ответственным лицом
  static Future<bool> isCompanyResponsibleAssigned(String companyId) async {
    try {
      final response = await _client
          .from('user_companies')
          .select('id')
          .eq('company_id', companyId)
          .eq('role', 'companyResponsible')
          .eq('status', 'approved')
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      print('Error checking company responsible: $e');
      return false;
    }
  }

  /// Получение всех заявок на присоединение к компаниям (для админов)
  static Future<List<UserCompany>> getAllCompanyJoinRequests() async {
    try {
      final response = await _client
          .from('user_companies')
          .select('*, companies(name), user_profiles(first_name, last_name, email)')
          .eq('status', 'pending')
          .order('requested_at', ascending: false);
      
      return response.map<UserCompany>((json) {
        final companyData = json['companies'] as Map<String, dynamic>?;
        return UserCompany.fromJson({
          ...json,
          'company_name': companyData?['name'] ?? '',
        });
      }).toList();
    } catch (e) {
      print('Error getting company join requests: $e');
      return [];
    }
  }

  /// Получение всех заявок на создание компаний (для админов)
  static Future<List<CompanyRequest>> getAllCompanyCreationRequests() async {
    try {
      final response = await _client
          .from('company_requests')
          .select('*, user_profiles(first_name, last_name, email)')
          .eq('status', 'pending')
          .order('requested_at', ascending: false);
      
      return response.map<CompanyRequest>((json) => CompanyRequest.fromJson(json)).toList();
    } catch (e) {
      print('Error getting company creation requests: $e');
      return [];
    }
  }

  /// Подтверждение заявки на присоединение к компании
  static Future<void> approveCompanyJoinRequest(String requestId, String approvedBy) async {
    await _client
        .from('user_companies')
        .update({
          'status': 'approved',
          'approved_by': approvedBy,
          'approved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
  }

  /// Отклонение заявки на присоединение к компании
  static Future<void> rejectCompanyJoinRequest(String requestId, String approvedBy, String reason) async {
    await _client
        .from('user_companies')
        .update({
          'status': 'rejected',
          'approved_by': approvedBy,
          'approved_at': DateTime.now().toIso8601String(),
          'rejection_reason': reason,
        })
        .eq('id', requestId);
  }

  /// Подтверждение заявки на создание компании
  static Future<void> approveCompanyCreationRequest(String requestId, String approvedBy) async {
    // Сначала получаем данные заявки
    final request = await _client
        .from('company_requests')
        .select('*')
        .eq('id', requestId)
        .single();
    
    // Обновляем статус заявки
    await _client
        .from('company_requests')
        .update({
          'status': 'approved',
          'approved_by': approvedBy,
          'approved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
    
    // Проверяем, существует ли уже компания с таким ИНН
    final existingCompany = await _client
        .from('companies')
        .select('id')
        .eq('company_inn', request['company_inn'])
        .maybeSingle();
    
    String companyId;
    
    if (existingCompany != null) {
      // Компания уже существует, используем её ID
      companyId = existingCompany['id'];
      print('✅ Компания с ИНН ${request['company_inn']} уже существует, используем существующую');
    } else {
      // Создаем новую компанию
      final companyResponse = await _client
          .from('companies')
          .insert({
            'name': request['company_name'],
            'company_inn': request['company_inn'],
            'address': request['company_address'],
            'contact_phone': request['company_phone'],
            'contact_email': request['company_email'],
          })
          .select()
          .single();
      
      companyId = companyResponse['id'];
      print('✅ Создана новая компания с ИНН ${request['company_inn']}');
    }
    
    // Создаем запись в user_companies
    await _client
        .from('user_companies')
        .insert({
          'user_id': request['user_id'],
          'company_id': companyId,
          'company_inn': request['company_inn'],
          'company_name': request['company_name'],
          'role': request['requested_role'],
          'status': 'approved',
          'approved_by': approvedBy,
          'approved_at': DateTime.now().toIso8601String(),
        });
    
    print('✅ Заявка на создание компании одобрена и создана запись в user_companies');
  }

  /// Отклонение заявки на создание компании
  static Future<void> rejectCompanyCreationRequest(String requestId, String approvedBy, String reason) async {
    await _client
        .from('company_requests')
        .update({
          'status': 'rejected',
          'approved_by': approvedBy,
          'approved_at': DateTime.now().toIso8601String(),
          'rejection_reason': reason,
        })
        .eq('id', requestId);
  }

  /// Удаление уведомления
  static Future<void> deleteNotification(String notificationId) async {
    await _client
        .from('notifications')
        .delete()
        .eq('id', notificationId);
  }

  /// Переключение активной компании пользователя
  static Future<void> switchActiveCompany(String userId, String companyId, String companyInn) async {
    await _client
        .from('user_profiles')
        .update({
          'company_id': companyId,
          'company_inn': companyInn,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  // === МЕТОДЫ ДЛЯ ИНЖЕНЕРОВ ===

  /// Получение назначенных заявок для инженера
  static Future<List<ServiceRequest>> getEngineerAssignedRequests(String engineerId) async {
    final response = await _client
        .from('service_requests')
        .select('*, equipment(name, model, serial_number, location), author:user_profiles!service_requests_user_id_fkey(first_name, last_name, phone, company_name), assigned_engineer:user_profiles!service_requests_assigned_engineer_id_fkey(first_name, last_name)')
        .eq('assigned_engineer_id', engineerId)
        .or('status.eq.approved,status.eq.inProgress,status.eq.waitingForInvoice,status.eq.waitingForPayment')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => ServiceRequest.fromJson(json))
        .toList();
  }

  /// Получение выполненных заявок инженера для статистики
  static Future<List<ServiceRequest>> getEngineerCompletedRequests(String engineerId, String period) async {
    DateTime startDate;
    final now = DateTime.now();
    
    switch (period) {
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'year':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = now.subtract(const Duration(days: 7));
    }

    final response = await _client
        .from('service_requests')
        .select()
        .eq('assigned_engineer_id', engineerId)
        .eq('status', 'completed')
        .gte('engineer_completed_at', startDate.toIso8601String())
        .order('engineer_completed_at', ascending: false);

    return (response as List)
        .map((json) => ServiceRequest.fromJson(json))
        .toList();
  }

  /// Назначение заявки инженеру (для администраторов)
  static Future<void> assignRequestToEngineer(String requestId, String engineerId) async {
    await _client
        .from('service_requests')
        .update({
          'assigned_engineer_id': engineerId,
          'status': 'approved', // Заявка переходит в статус "одобрена" для работы инженера
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
  }

  /// Получение заявок для поставщика
  /// Поставщик видит только заявки на оборудование, которое он поставил
  static Future<List<ServiceRequest>> getSupplierRequests(String supplierUserId) async {
    try {
      final response = await _client
          .from('service_requests')
          .select('*, equipment(name, model, manufacturer, serial_number, location), author:user_profiles!service_requests_user_id_fkey(first_name, last_name, phone, role, company_name), assigned_engineer:user_profiles!service_requests_assigned_engineer_id_fkey(first_name, last_name)')
          .eq('supplier_id', supplierUserId)
          .neq('status', 'cancelled')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ServiceRequest.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Ошибка загрузки заявок поставщика: $e');
      return [];
    }
  }

  /// Получение инженеров поставщика
  /// Возвращает список всех инженеров, принадлежащих данному поставщику
  static Future<List<AppUserModel.User>> getSupplierEngineers(String supplierUserId) async {
    try {
      print('🔍 Загружаем инженеров поставщика $supplierUserId...');
      
      // Получаем ID поставщика из таблицы suppliers или напрямую из user_profiles
      // Предполагаем, что supplierUserId это ID пользователя с ролью supplier
      // и инженеры имеют supplier_id = supplierUserId в таблице user_profiles
      
      final response = await _client
          .from('user_profiles')
          .select('*')
          .eq('role', 'engineer')
          .eq('supplier_id', supplierUserId) // Инженеры должны иметь supplier_id
          .order('first_name');

      print('📋 Получено инженеров: ${response.length}');
      
      final engineers = (response as List)
          .map((json) => AppUserModel.User.fromJson(json))
          .toList();
      
      print('👥 Инженеры: ${engineers.map((e) => '${e.firstName} ${e.lastName}').join(', ')}');
      return engineers;
    } catch (e) {
      print('❌ Ошибка загрузки инженеров поставщика: $e');
      return [];
    }
  }

  static Future<void> assignEngineerToRequest({
    required String requestId,
    required String engineerId,
    required String supplierUserId,
    required String approverName, // Имя того, кто назначает
    bool startWorkImmediately = false,
  }) async {
    try {
      // Проверка 1: Заявка принадлежит этому поставщику
      final requestResponse = await _client
          .from('service_requests')
          .select('supplier_id, status')
          .eq('id', requestId)
          .maybeSingle();

      if (requestResponse == null) {
        throw Exception('Заявка не найдена');
      }

      if (requestResponse['supplier_id'] != supplierUserId) {
        throw Exception('Эта заявка не принадлежит вашему поставщику');
      }

      // Проверка 2: Инженер принадлежит этому поставщику
      final engineerResponse = await _client
          .from('user_profiles')
          .select('id, role, supplier_id')
          .eq('id', engineerId)
          .maybeSingle();

      if (engineerResponse == null) {
        throw Exception('Инженер не найден');
      }

      if (engineerResponse['role'] != 'engineer') {
        throw Exception('Пользователь не является инженером');
      }

      if (engineerResponse['supplier_id'] != supplierUserId) {
        throw Exception('Этот инженер не принадлежит вашему поставщику');
      }

      // Обновляем заявку: назначаем инженера и меняем статус
      final status = startWorkImmediately ? 'inProgress' : 'approved';
      final updateData = {
        'assigned_engineer_id': engineerId,
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (startWorkImmediately) {
        updateData['engineer_started_at'] = DateTime.now().toIso8601String();
      }

      // Дополнительно ставим отметку об одобрении (для таймлайна)
      updateData['approved_at'] = DateTime.now().toIso8601String();
      updateData['approved_by'] = approverName;

       await _client
          .from('service_requests')
          .update(updateData)
          .eq('id', requestId);

      print('✅ Инженер $engineerId успешно назначен на заявку $requestId');
      
      // Уведомляем участников
      _notifyParties(requestId, 'Назначен инженер', 'На вашу заявку назначен инженер.');
    } catch (e) {
      print('❌ Ошибка назначения инженера: $e');
      rethrow;
    }
  }

  /// Получение доступных заявок для инженера (по его регионам)
  static Future<List<ServiceRequest>> getAvailableServiceRequests(AppUserModel.User engineer) async {
    try {
      final regions = engineer.serviceRegions ?? [];
      if (regions.isEmpty) return [];

      // 1. Получаем все sites из регионов инженера
      final sitesResponse = await _client
          .from('sites')
          .select('id')
          .inFilter('region', regions);
          
      final List<String> siteIds = (sitesResponse as List)
          .map((s) => s['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
          
      if (siteIds.isEmpty) return [];

      // 2. Ищем свободные заявки на этих площадках
      final response = await _client
          .from('service_requests')
          .select('*, equipment(name, model, manufacturer, serial_number, location), author:user_profiles!service_requests_user_id_fkey(first_name, last_name, phone, role, company_name), assigned_engineer:user_profiles!service_requests_assigned_engineer_id_fkey(first_name, last_name), site:sites!service_requests_site_id_fkey(name, address, region)')
          .inFilter('site_id', siteIds)
          .isFilter('assigned_engineer_id', null)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) {
            return ServiceRequest.fromJson(json);
          })
          .toList();
    } catch (e) {
      print('❌ Ошибка загрузки доступных заявок: $e');
      return [];
    }
  }

  /// Инженер берет заявку в работу (Атомарно!)
  static Future<bool> takeServiceRequest(String requestId, String engineerId) async {
    try {
      final response = await _client.rpc('take_service_request', params: {
        'p_request_id': requestId,
        'p_engineer_id': engineerId,
      });
      return response == true;
    } catch (e) {
      print('❌ Ошибка взятия заявки: $e');
      return false;
    }
  }

  /// Начало работы инженера над заявкой
  static Future<void> startEngineerWork(String requestId) async {
    await _client
        .from('service_requests')
        .update({
          'status': 'inProgress',
          'engineer_started_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);

    _notifyParties(requestId, 'Работы начаты', 'Инженер приступил к выполнению работ по вашей заявке.');
  }

  /// Установка назначенной даты
  static Future<void> updateRequestScheduledDate(String requestId, DateTime date) async {
    await _client
        .from('service_requests')
        .update({
          'scheduled_at': date.toIso8601String(),
          'scheduled_timestamp_at': DateTime.now().toIso8601String(), // Время совершения действия
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);

    _notifyParties(requestId, 'Выезд запланирован', 'Назначена дата выезда инженера: ${DateFormat('dd.MM.yyyy').format(date)}');
  }

  /// Сдача отчета инженером (перевод в "Ждет приемки")
  static Future<void> submitEngineerReport(String requestId, String comment, String recommendations) async {
    await _client
        .from('service_requests')
        .update({
          'status': 'waitingForAcceptance',
          'engineer_comment': comment,
          'recommendations': recommendations,
          'engineer_completed_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);

    _notifyParties(requestId, 'Отчет готов', 'Инженер подготовил отчет о выполнении. Пожалуйста, проверьте и примите работы.');
  }

  /// Приемка работ клиентом
  static Future<void> acceptServiceWork(String requestId, {required bool isAccepted, String? comment}) async {
    await _client
        .from('service_requests')
        .update({
          'status': isAccepted ? 'waitingForInvoice' : 'inProgress', // Если есть серьезные замечания, можно вернуть в работу
          'is_accepted_by_client': isAccepted,
          'client_acceptance_comment': comment,
          'client_accepted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);

    if (isAccepted) {
      _notifyParties(requestId, 'Работы приняты', 'Клиент принял выполненные работы.');
    } else {
      _notifyParties(requestId, 'Работы отклонены', 'Клиент не принял работу. Комментарий: ${comment ?? 'Без комментария'}');
    }
  }

  static Future<void> requestPaymentForInvoice(String requestId, double amount, {String? invoiceUrl, required String senderId}) async {
    await _client
        .from('service_requests')
        .update({
          'status': 'waitingForPayment',
          'invoice_amount': amount,
          'invoice_url': invoiceUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);

    // Уведомляем участников (покупателя)
    _notifyParties(requestId, 'Счет выставлен', 'Для вашей заявки выставлен счет на сумму $amount ₽.');
    
    // Если есть ссылка на счет, можно отправить отдельное сообщение в чат
    if (invoiceUrl != null) {
      await sendRequestMessage(
        requestId: requestId,
        senderId: senderId,
        message: 'Счет на оплату выставлен: $amount ₽. Ссылка: $invoiceUrl',
      );
    }
  }

  /// Обновление статуса заявки
  static Future<void> updateRequestStatus(String requestId, RequestStatus status) async {
    await _client
        .from('service_requests')
        .update({
          'status': status.name,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
        
    // Уведомляем участников (кроме стандартных статусов, которые имеют свои методы)
    final String statusDisplay = ServiceRequest(id:'', clientId: '', userId: '', type: RequestType.repair, title: '', description: '', status: status, createdAt: DateTime.now()).statusDisplayName;
    _notifyParties(requestId, 'Статус обновлен', 'Статус вашей заявки изменен на "$statusDisplay"');
  }

  /// Получение заявки по ID
  static Future<ServiceRequest?> getRequestById(String requestId) async {
    try {
      final response = await _client
          .from('service_requests')
          .select('*, equipment(name, model, manufacturer, serial_number, location), author:user_profiles!service_requests_user_id_fkey(first_name, last_name, phone, role, company_name), assigned_engineer:user_profiles!service_requests_assigned_engineer_id_fkey(first_name, last_name), site:sites!service_requests_site_id_fkey(name, address, region)')
          .eq('id', requestId)
          .maybeSingle();

      if (response != null) {
        return ServiceRequest.fromJson(response);
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки заявки: $e');
      return null;
    }
  }

  /// Получение списка всех инженеров
  static Future<List<AppUserModel.User>> getEngineers() async {
    try {
      print('🔍 Загружаем инженеров из Supabase...');
      final response = await _client
          .from('user_profiles')
          .select('*')
          .eq('role', 'engineer')
          .order('first_name');

      print('📋 Получено инженеров из Supabase: ${response.length}');
      final engineers = (response as List)
          .map((json) => AppUserModel.User.fromJson(json))
          .toList();
      
      print('👥 Инженеры: ${engineers.map((e) => '${e.firstName} ${e.lastName} (${e.phone})').join(', ')}');
      return engineers;
    } catch (e) {
      print('❌ Ошибка загрузки инженеров: $e');
      return [];
    }
  }

  // === SITE ASSIGNMENT MANAGEMENT ===

  /// Назначение площадки менеджеру
  static Future<void> assignSiteToManager(String userId, String siteId, String assignedBy) async {
    try {
      // Получаем текущие назначенные площадки
      final userResponse = await _client
          .from('user_profiles')
          .select('assigned_site_ids')
          .eq('id', userId)
          .maybeSingle();
      
      if (userResponse == null) {
        throw Exception('Пользователь не найден');
      }
      
      List<String> assignedSites = List<String>.from(userResponse['assigned_site_ids'] ?? []);
      
      // Добавляем новую площадку если её еще нет
      if (!assignedSites.contains(siteId)) {
        assignedSites.add(siteId);
        
        // Обновляем назначенные площадки
        await _client
            .from('user_profiles')
            .update({'assigned_site_ids': assignedSites})
            .eq('id', userId);
        
        print('✅ Площадка $siteId назначена пользователю $userId');
      }
    } catch (e) {
      print('❌ Ошибка назначения площадки: $e');
      rethrow;
    }
  }

  /// Отмена назначения площадки менеджеру
  static Future<void> unassignSiteFromManager(String userId, String siteId, String unassignedBy) async {
    try {
      // Получаем текущие назначенные площадки
      final userResponse = await _client
          .from('user_profiles')
          .select('assigned_site_ids')
          .eq('id', userId)
          .maybeSingle();
      
      if (userResponse == null) {
        throw Exception('Пользователь не найден');
      }
      
      List<String> assignedSites = List<String>.from(userResponse['assigned_site_ids'] ?? []);
      
      // Удаляем площадку из списка
      assignedSites.remove(siteId);
      
      // Обновляем назначенные площадки
      await _client
          .from('user_profiles')
          .update({'assigned_site_ids': assignedSites})
          .eq('id', userId);
      
      print('✅ Площадка $siteId отменена у пользователя $userId');
    } catch (e) {
      print('❌ Ошибка отмены назначения площадки: $e');
      rethrow;
    }
  }

  /// Получение менеджеров площадок компании
  static Future<List<AppUserModel.User>> getSiteManagers(String companyId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('*')
          .eq('company_id', companyId)
          .eq('role', 'siteManager')
          .order('first_name');
      
      return (response as List)
          .map((json) => AppUserModel.User.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Ошибка загрузки менеджеров площадок: $e');
      return [];
    }
  }

  /// Получение всех сотрудников компании (для ответственного лица)
  static Future<List<AppUserModel.User>> getCompanyEmployees({
    String? companyId,
    String? companyInn,
  }) async {
    try {
      print('🔍 Поиск сотрудников для companyId: $companyId, companyInn: $companyInn');
      
      // Формируем фильтр OR
      String orFilter = '';
      if (companyId != null && companyInn != null && companyId != companyInn) {
        orFilter = 'company_id.eq.$companyId,company_inn.eq.$companyInn';
      } else if (companyId != null) {
        orFilter = 'company_id.eq.$companyId';
      } else if (companyInn != null) {
        orFilter = 'company_inn.eq.$companyInn';
      }

      if (orFilter.isEmpty) {
        print('⚠️ Не переданы идентификаторы компании для поиска сотрудников');
        return [];
      }

      final response = await _client
          .from('user_profiles')
          .select('*')
          .or(orFilter)
          .inFilter('role', ['siteManager', 'operatorPM', 'engineer', 'pendingApproval'])
          .order('first_name');
      
      print('🔍 Результат поиска сотрудников компании: ${(response as List).length} чел.');
      
      return (response as List)
          .map((json) => AppUserModel.User.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Ошибка загрузки сотрудников компании: $e');
      return [];
    }
  }

  /// Назначение площадки сотруднику (для ответственного лица)
  static Future<void> assignSiteToEmployee(String userId, String siteId, String assignedBy) async {
    try {
      print('🔍 Начинаем назначение площадки $siteId пользователю $userId');
      print('🔍 Назначает пользователь: $assignedBy');
      
      // Получаем информацию о пользователе
      final userResponse = await _client
          .from('user_profiles')
          .select('role, assigned_site_ids, first_name, last_name, company_id, company_inn')
          .eq('id', userId)
          .maybeSingle();
      
      print('🔍 Результат поиска пользователя: $userResponse');
      
      if (userResponse == null) {
        print('❌ Пользователь с ID $userId не найден в базе данных');
        throw Exception('Пользователь с ID $userId не найден');
      }
      
      final userRole = userResponse['role'];
      final userName = '${userResponse['first_name']} ${userResponse['last_name']}';
      final userCompanyId = userResponse['company_id'];
      final userCompanyInn = userResponse['company_inn'];
      
      print('🔍 Найден пользователь: $userName, роль: $userRole');
      print('🔍 Компания пользователя: ID=$userCompanyId, ИНН=$userCompanyInn');
      
      if (userRole != 'siteManager' && userRole != 'operatorPM') {
        throw Exception('Можно назначать площадки только менеджерам площадок и операторам ПМ');
      }
      
      // Проверяем права назначающего пользователя
      String assignedByRole = 'administrator'; // По умолчанию считаем администратором
      String assignedByName = 'Администратор';
      
      try {
        final assignedByResponse = await _client
            .from('user_profiles')
            .select('role, first_name, last_name')
            .eq('id', assignedBy)
            .maybeSingle();
        
        if (assignedByResponse != null) {
          assignedByRole = assignedByResponse['role'];
          assignedByName = '${assignedByResponse['first_name']} ${assignedByResponse['last_name']}';
        }
      } catch (e) {
        print('⚠️ Не удалось загрузить данные назначающего пользователя: $e');
        // Продолжаем с дефолтными значениями
      }
      
      print('🔍 Назначает пользователь: $assignedByName, роль: $assignedByRole');
      
      // Проверяем права на назначение
      if (assignedByRole != 'superAdmin' && 
          assignedByRole != 'administrator' && 
          assignedByRole != 'companyResponsible') {
        throw Exception('Только администраторы и ответственные лица могут назначать площадки');
      }
      
      List<String> assignedSites = List<String>.from(userResponse['assigned_site_ids'] ?? []);
      print('🔍 Текущие назначенные площадки: $assignedSites');
      
      // Добавляем новую площадку если её еще нет
      if (!assignedSites.contains(siteId)) {
        assignedSites.add(siteId);
        
        // Обновляем назначенные площадки с принудительным обновлением
        print('🔧 Обновляем assigned_site_ids для пользователя $userId: $assignedSites');
        try {
          // Временно отключаем RLS для обновления
          await _client.rpc('disable_rls_for_update');
          
          // Используем upsert для гарантированного обновления
          final updateResponse = await _client
              .from('user_profiles')
              .update({
                'assigned_site_ids': assignedSites,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', userId)
              .select();
          
          print('✅ assigned_site_ids обновлен для пользователя $userId');
          print('🔍 Ответ от Supabase: $updateResponse');
          
          // Включаем RLS обратно
          await _client.rpc('enable_rls_after_update');
          
          // Проверяем, что обновление действительно произошло
          final verifyResponse = await _client
              .from('user_profiles')
              .select('assigned_site_ids')
              .eq('id', userId)
              .single();
          
          print('🔍 Проверка после обновления: ${verifyResponse['assigned_site_ids']}');
          
        } catch (e) {
          print('❌ Ошибка обновления assigned_site_ids: $e');
          // Пытаемся включить RLS обратно в случае ошибки
          try {
            await _client.rpc('enable_rls_after_update');
          } catch (_) {}
          rethrow;
        }
        print('✅ Площадка $siteId назначена сотруднику $userId');
        
        // Автоматически обновляем кеш пользователя
        try {
          await _updateUserCache(userId);
          print('✅ Кеш пользователя $userId автоматически обновлен');
        } catch (e) {
          print('⚠️ Ошибка автоматического обновления кеша: $e');
        }
        
        // Отправляем уведомление пользователю
        await _createSiteAssignmentNotification(userId, siteId, assignedBy);
      } else {
        print('⚠️ Площадка $siteId уже назначена пользователю $userId');
      }
    } catch (e) {
      print('❌ Ошибка назначения площадки сотруднику: $e');
      rethrow;
    }
  }

  /// Отмена назначения площадки сотруднику (для ответственного лица)
  static Future<void> unassignSiteFromEmployee(String userId, String siteId, String unassignedBy) async {
    try {
      print('🔍 Начинаем отмену назначения площадки $siteId у пользователя $userId');
      print('🔍 Отменяет пользователь: $unassignedBy');
      
      // Получаем текущие назначенные площадки
      final userResponse = await _client
          .from('user_profiles')
          .select('assigned_site_ids, first_name, last_name, role')
          .eq('id', userId)
          .maybeSingle();
      
      if (userResponse == null) {
        throw Exception('Пользователь не найден');
      }
      
      // Проверяем права отменяющего пользователя
      String unassignedByRole = 'administrator'; // По умолчанию считаем администратором
      String unassignedByName = 'Администратор';
      
      try {
        final unassignedByResponse = await _client
            .from('user_profiles')
            .select('role, first_name, last_name')
            .eq('id', unassignedBy)
            .maybeSingle();
        
        if (unassignedByResponse != null) {
          unassignedByRole = unassignedByResponse['role'];
          unassignedByName = '${unassignedByResponse['first_name']} ${unassignedByResponse['last_name']}';
        }
      } catch (e) {
        print('⚠️ Не удалось загрузить данные отменяющего пользователя: $e');
        // Продолжаем с дефолтными значениями
      }
      
      print('🔍 Отменяет пользователь: $unassignedByName, роль: $unassignedByRole');
      
      // Проверяем права на отмену назначения
      if (unassignedByRole != 'superAdmin' && 
          unassignedByRole != 'administrator' && 
          unassignedByRole != 'companyResponsible') {
        throw Exception('Только администраторы и ответственные лица могут отменять назначения площадок');
      }
      
      List<String> assignedSites = List<String>.from(userResponse['assigned_site_ids'] ?? []);
      print('🔍 Текущие назначенные площадки: $assignedSites');
      
      // Удаляем площадку из списка
      assignedSites.remove(siteId);
      print('🔧 Обновляем assigned_site_ids для пользователя $userId: $assignedSites');
      
      // Обновляем назначенные площадки с использованием RLS функций
      try {
        // Временно отключаем RLS для обновления
        await _client.rpc('disable_rls_for_update');
        
        final updateResponse = await _client
            .from('user_profiles')
            .update({
              'assigned_site_ids': assignedSites,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId)
            .select();
        
        print('✅ assigned_site_ids обновлен для пользователя $userId');
        print('🔍 Ответ от Supabase: $updateResponse');
        
        // Включаем RLS обратно
        await _client.rpc('enable_rls_after_update');
        
        // Проверяем, что обновление действительно произошло
        final verifyResponse = await _client
            .from('user_profiles')
            .select('assigned_site_ids')
            .eq('id', userId)
            .single();
        
        print('🔍 Проверка после обновления: ${verifyResponse['assigned_site_ids']}');
        
      } catch (e) {
        print('❌ Ошибка обновления assigned_site_ids: $e');
        // Пытаемся включить RLS обратно в случае ошибки
        try {
          await _client.rpc('enable_rls_after_update');
        } catch (_) {}
        rethrow;
      }
      
      print('✅ Площадка $siteId отменена у сотрудника $userId');
      
      // Автоматически обновляем кеш пользователя
      try {
        await _updateUserCache(userId);
        print('✅ Кеш пользователя $userId автоматически обновлен');
      } catch (e) {
        print('⚠️ Ошибка автоматического обновления кеша: $e');
      }
    } catch (e) {
      print('❌ Ошибка отмены назначения площадки сотруднику: $e');
      rethrow;
    }
  }

  /// Автоматическое обновление кеша пользователя
  static Future<void> _updateUserCache(String userId) async {
    try {
      print('🔄 Автоматическое обновление кеша для пользователя: $userId');
      
      // Загружаем свежие данные из Supabase
      final response = await _client
          .from('user_profiles')
          .select('*, companies(*)')
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null) {
        final user = AppUserModel.User.fromJson(response);
        
        // Проверяем, является ли этот пользователь текущим
        final prefs = await SharedPreferences.getInstance();
        final currentUserId = prefs.getString('current_user_id');
        
        if (currentUserId == userId) {
          // Обновляем кеш только для текущего пользователя
          await prefs.setString('current_user', jsonEncode(user.toJson()));
          print('✅ Кеш текущего пользователя $userId обновлен: ${user.fullName}');
        } else {
          print('ℹ️ Пользователь $userId не является текущим, кеш не обновляется');
        }
        
        print('🔍 Назначенные площадки: ${user.assignedSiteIds}');
      } else {
        print('⚠️ Пользователь $userId не найден в Supabase');
      }
    } catch (e) {
      print('❌ Ошибка обновления кеша пользователя $userId: $e');
      // Не пробрасываем ошибку, чтобы не нарушить основной процесс
    }
  }

  /// Изменение роли сотрудника (доступно для companyResponsible)
  static Future<void> changeEmployeeRole(
    String userId, 
    String newRole, 
    String changedBy,
  ) async {
    try {
      print('🔍 Начинаем изменение роли пользователя $userId на $newRole');
      print('🔍 Изменяет пользователь: $changedBy');
      
      // Получаем информацию о пользователе
      final userResponse = await _client
          .from('user_profiles')
          .select('first_name, last_name, role, company_id')
          .eq('id', userId)
          .maybeSingle();
      
      if (userResponse == null) {
        throw Exception('Пользователь не найден');
      }
      
      final currentRole = userResponse['role'];
      final userCompanyId = userResponse['company_id'];
      
      // Проверяем права изменяющего пользователя
      String changedByRole = 'administrator';
      String changedByName = 'Администратор';
      String changedByCompanyId = '';
      
      try {
        final changedByResponse = await _client
            .from('user_profiles')
            .select('role, first_name, last_name, company_id')
            .eq('id', changedBy)
            .maybeSingle();
        
        if (changedByResponse != null) {
          changedByRole = changedByResponse['role'];
          changedByName = '${changedByResponse['first_name']} ${changedByResponse['last_name']}';
          changedByCompanyId = changedByResponse['company_id'] ?? '';
        }
      } catch (e) {
        print('⚠️ Не удалось загрузить данные изменяющего пользователя: $e');
      }
      
      print('🔍 Изменяет пользователь: $changedByName, роль: $changedByRole');
      
      // Проверяем права на изменение роли
      if (changedByRole != 'superAdmin' && 
          changedByRole != 'administrator' && 
          changedByRole != 'companyResponsible') {
        throw Exception('Только администраторы и ответственные лица могут изменять роли');
      }
      
      // Ответственное лицо может менять роли только внутри своей компании
      if (changedByRole == 'companyResponsible' && changedByCompanyId != userCompanyId) {
        throw Exception('Вы можете изменять роли только сотрудников своей компании');
      }
      
      // Разрешенные роли для назначения ответственным лицом
      const allowedRolesForResponsible = ['siteManager', 'operatorPM', 'engineer'];
      if (changedByRole == 'companyResponsible' && !allowedRolesForResponsible.contains(newRole)) {
        throw Exception('Вы можете назначать только роли: Менеджер площадки, Оператор ПМ, Инженер');
      }
      
      // Нельзя изменить роль на администратора или супер-админа через этот метод
      if (newRole == 'superAdmin' || newRole == 'administrator') {
        throw Exception('Назначение ролей администратора доступно только супер-админу');
      }
      
      print('🔧 Изменяем роль пользователя $userId: $currentRole → $newRole');
      
      // Обновляем роль с использованием RLS функций
      try {
        // Временно отключаем RLS для обновления
        await _client.rpc('disable_rls_for_update');
        
        final updateResponse = await _client
            .from('user_profiles')
            .update({
              'role': newRole,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId)
            .select();
        
        print('✅ Роль обновлена для пользователя $userId');
        print('🔍 Ответ от Supabase: $updateResponse');
        
        // Включаем RLS обратно
        await _client.rpc('enable_rls_after_update');
        
        // Проверяем, что обновление действительно произошло
        final verifyResponse = await _client
            .from('user_profiles')
            .select('role')
            .eq('id', userId)
            .single();
        
        print('🔍 Проверка после обновления: роль = ${verifyResponse['role']}');
        
        if (verifyResponse['role'] != newRole) {
          throw Exception('Роль не была обновлена в базе данных');
        }
      } catch (e) {
        // Включаем RLS обратно даже в случае ошибки
        try {
          await _client.rpc('enable_rls_after_update');
        } catch (rlsError) {
          print('❌ Ошибка включения RLS: $rlsError');
        }
        rethrow;
      }
      
      print('✅ Роль пользователя $userId изменена на $newRole');
      
      // Автоматически обновляем кеш пользователя
      try {
        await _updateUserCache(userId);
        print('✅ Кеш пользователя $userId автоматически обновлен');
      } catch (e) {
        print('⚠️ Ошибка автоматического обновления кеша: $e');
      }
    } catch (e) {
      print('❌ Ошибка изменения роли сотрудника: $e');
      rethrow;
    }
  }

  /// Создание уведомления о назначении площадки
  static Future<void> _createSiteAssignmentNotification(String userId, String siteId, String assignedBy) async {
    try {
      // Получаем информацию о площадке
      final site = await getSiteById(siteId);
      if (site == null) {
        print('⚠️ Площадка $siteId не найдена для уведомления');
        return;
      }
      
      // Получаем информацию о том, кто назначил
      final assignedByResponse = await _client
          .from('user_profiles')
          .select('first_name, last_name')
          .eq('id', assignedBy)
          .maybeSingle();
      
      String assignedByName = 'Администратор';
      if (assignedByResponse != null) {
        assignedByName = '${assignedByResponse['first_name']} ${assignedByResponse['last_name']}';
      }
      
      // Создаем уведомление
      await createNotification(
        userId: userId,
        type: 'siteAssignment',
        title: 'Назначена новая площадка',
        message: 'Вам назначена площадка "${site.name}" от $assignedByName',
        data: {
          'site_id': siteId,
          'site_name': site.name,
          'assigned_by': assignedBy,
          'assigned_by_name': assignedByName,
        },
      );
      
      print('✅ Уведомление о назначении площадки отправлено пользователю $userId');
    } catch (e) {
      print('❌ Ошибка создания уведомления о назначении площадки: $e');
    }
  }

  /// Получение площадки по ID
  static Future<Site?> getSiteById(String siteId) async {
    try {
      final response = await _client
          .from('sites')
          .select('*')
          .eq('id', siteId)
          .maybeSingle();
      
      if (response != null) {
        return Site.fromJson(response);
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки площадки $siteId: $e');
      return null;
    }
  }

  /// Принудительное обновление данных пользователя из базы данных
  static Future<AppUserModel.User?> refreshUserData(String userId) async {
    try {
      print('🔄 Принудительное обновление данных пользователя: $userId');
      
      final response = await _client
          .from('user_profiles')
          .select('*, companies(*)')
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null) {
        final user = AppUserModel.User.fromJson(response);
        print('✅ Данные пользователя обновлены: ${user.fullName}');
        print('🔍 Назначенные площадки: ${user.assignedSiteIds}');
        return user;
      } else {
        print('⚠️ Пользователь $userId не найден в Supabase');
        return null;
      }
    } catch (e) {
      print('❌ Ошибка обновления данных пользователя: $e');
      return null;
    }
  }

  /// Очистка кеша пользователя и принудительная загрузка из Supabase
  static Future<AppUserModel.User?> forceRefreshUserData(String userId) async {
    try {
      print('🔄 Принудительная очистка кеша и загрузка данных пользователя: $userId');
      
      // Очищаем кеш пользователя
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');
      
      // Загружаем свежие данные из Supabase
      final response = await _client
          .from('user_profiles')
          .select('*, companies(*)')
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null) {
        final user = AppUserModel.User.fromJson(response);
        print('✅ Свежие данные пользователя загружены: ${user.fullName}');
        print('🔍 Назначенные площадки: ${user.assignedSiteIds}');
        
        // Сохраняем обновленные данные в кеш
        await StorageService.setCurrentUser(user);
        
        return user;
      } else {
        print('⚠️ Пользователь $userId не найден в Supabase');
        return null;
      }
    } catch (e) {
      print('❌ Ошибка принудительного обновления данных пользователя: $e');
      return null;
    }
  }

  // --- Методы для работы с моделями оборудования (Equipment Models) ---

  /// Получить все доступные модели оборудования
  Future<List<EquipmentModel>> getEquipmentModels() async {
    try {
      print('🔍 Supabase: Fetching all equipment models...');
      final response = await _client
          .from('equipment_models')
          .select()
          .order('manufacturer', ascending: true)
          .order('model', ascending: true);
      
      print('📊 Supabase Raw Response: $response');

      final list = (response as List).map((json) => EquipmentModel.fromJson(json)).toList();
      print('✅ Supabase: Successfully fetched ${list.length} models');
      return list;
    } catch (e) {
      print('❌ Supabase: Error fetching equipment models: $e');
      return [];
    }
  }

  /// Получить модели конкретного поставщика
  Future<List<EquipmentModel>> getSupplierEquipmentModels(String supplierId) async {
    try {
      final response = await _client
          .from('equipment_models')
          .select()
          .eq('supplier_id', supplierId)
          .order('created_at', ascending: false);
      
      return (response as List).map((json) => EquipmentModel.fromJson(json)).toList();
    } catch (e) {
      print('❌ Ошибка получения моделей поставщика: $e');
      return [];
    }
  }

  /// Создать новую модель оборудования
  Future<EquipmentModel?> createEquipmentModel(EquipmentModel model) async {
    try {
      final response = await _client
          .from('equipment_models')
          .insert(model.toJson())
          .select()
          .single();
      
      return EquipmentModel.fromJson(response);
    } catch (e) {
      print('❌ Ошибка создания модели оборудования: $e');
      rethrow;
    }
  }

  /// Обновить существующую модель оборудования
  Future<EquipmentModel?> updateEquipmentModel(EquipmentModel model) async {
    try {
      await _client.rpc('update_equipment_model', params: {
        'p_model_id': model.id,
        'p_manufacturer': model.manufacturer,
        'p_model': model.model,
        'p_image_url': model.imageUrl,
        'p_specs': model.specifications,
      });

      // Мы после успешного вызова RPC просто возвращаем переданную модель 
      // с обновленным временем (так как RPC не возвращает саму запись)
      return model.copyWith(updatedAt: DateTime.now());
    } catch (e) {
      print('❌ Ошибка обновления модели оборудования: $e');
      rethrow;
    }
  }


  /// Получить список клиентов, у которых есть оборудование данного поставщика
  Future<List<Map<String, dynamic>>> getSupplierClients(String supplierId) async {
    try {
      // 1. Получаем одобренные бренды поставщика
      final brandsResponse = await _client
          .from('equipment_brands')
          .select('name')
          .eq('supplier_id', supplierId)
          .eq('status', 'approved');
          
      final brands = (brandsResponse as List).map((e) => e['name'] as String).toList();
      if (brands.isEmpty) return [];

      // 2. Ищем всё оборудование этих брендов
      final equipmentResponse = await _client
          .from('equipment')
          .select('company_id, client_id, responsible_user_id')
          .inFilter('manufacturer', brands);

      final List<dynamic> equipmentList = equipmentResponse as List;
      if (equipmentList.isEmpty) return [];

      // 3. Собираем уникальные ID компаний
      final Set<String> companyIds = equipmentList
          .map((e) => e['company_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      // Собираем прямые ID пользователей (частников, старых клиентов)
      final Set<String> directUserIds = {};
      for (var e in equipmentList) {
        if (e['client_id'] != null && e['client_id'].toString().isNotEmpty) {
          directUserIds.add(e['client_id'].toString());
        }
        if (e['responsible_user_id'] != null && e['responsible_user_id'].toString().isNotEmpty) {
          directUserIds.add(e['responsible_user_id'].toString());
        }
      }

      if (companyIds.isEmpty && directUserIds.isEmpty) return [];

      // 4. Получаем данные пользователей
      String orFilter = '';
      final conditions = <String>[];
      if (companyIds.isNotEmpty) {
        conditions.add('company_id.in.(${companyIds.join(',')})');
      }
      if (directUserIds.isNotEmpty) {
        conditions.add('id.in.(${directUserIds.join(',')})');
      }
      orFilter = conditions.join(',');

      final usersResponse = await _client
          .from('user_profiles')
          .select('*, companies(*)')
          .or(orFilter);

      return List<Map<String, dynamic>>.from(usersResponse as List);
    } catch (e) {
      print('❌ Ошибка получения клиентов поставщика: $e');
      return [];
    }
  }

  /// Получить сервисных партнеров по ИНН
  Future<List<Map<String, dynamic>>> getServicePartnersByInn(String inn) async {
    try {
      // Ищем пользователей/компании с таким же ИНН
      final response = await _client
          .from('user_profiles')
          .select('*, companies(*)')
          .eq('company_inn', inn);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('❌ Ошибка получения сервисных партнеров: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllEquipmentModels() async {
    final response = await _client
        .from('equipment_models')
        .select('*')
        .order('manufacturer');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> deleteEquipmentModel(String modelId) async {
    await _client.from('equipment_models').delete().eq('id', modelId);
  }

  // --- Запасные части (Spare Parts) ---
  
  static Future<List<dynamic>> getSpareParts({String? category, String? modelFilter}) async {
    var query = _client.from('spare_parts').select();
    
    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }
    
    if (modelFilter != null && modelFilter.isNotEmpty) {
      // Ищем запчасти, у которых массив compatible_models содержит указанную модель
      query = query.contains('compatible_models', [modelFilter]);
    }
    
    final response = await query.order('name');
    return response as List;
  }

  static Future<List<dynamic>> getSupplierSpareParts(String supplierId) async {
    final response = await _client
        .from('spare_parts')
        .select()
        .eq('supplier_id', supplierId)
        .order('created_at', ascending: false);
        
    return response as List;
  }

  static Future<dynamic> createSparePart(Map<String, dynamic> partData) async {
    final response = await _client
        .from('spare_parts')
        .insert(partData)
        .select()
        .single();
    return response;
  }

  static Future<dynamic> updateSparePart(Map<String, dynamic> partData) async {
    final response = await _client
        .from('spare_parts')
        .update(partData)
        .eq('id', partData['id'])
        .select()
        .single();
    return response;
  }

  static Future<void> deleteSparePart(String id) async {
    await _client.from('spare_parts').delete().eq('id', id);
  }

  // ═══════════════════════════════════
  // КОРЗИНА (cart_items)
  // ═══════════════════════════════════

  static Future<List<dynamic>> getCartItems(String userId) async {
    final response = await _client
        .from('cart_items')
        .select('*, spare_parts(id, name, article, price, images, supplier_id, category)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return response as List;
  }

  static Future<void> addToCart(String userId, String partId, int quantity) async {
    // Если товар уже в корзине — увеличиваем количество
    final existing = await _client
        .from('cart_items')
        .select('id, quantity')
        .eq('user_id', userId)
        .eq('part_id', partId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('cart_items')
          .update({'quantity': (existing['quantity'] as int) + quantity})
          .eq('id', existing['id']);
    } else {
      await _client.from('cart_items').insert({
        'user_id': userId,
        'part_id': partId,
        'quantity': quantity,
      });
    }
  }

  static Future<void> updateCartItemQuantity(String cartItemId, int quantity) async {
    await _client
        .from('cart_items')
        .update({'quantity': quantity})
        .eq('id', cartItemId);
  }

  static Future<void> removeFromCart(String cartItemId) async {
    await _client.from('cart_items').delete().eq('id', cartItemId);
  }

  static Future<void> clearCart(String userId) async {
    await _client.from('cart_items').delete().eq('user_id', userId);
  }

  // ═══════════════════════════════════
  // ИЗБРАННОЕ (favorites)
  // ═══════════════════════════════════

  static Future<List<dynamic>> getFavorites(String userId) async {
    final response = await _client
        .from('favorites')
        .select('*, spare_parts(id, name, article, price, images, category)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return response as List;
  }

  static Future<void> addToFavorites(String userId, String partId) async {
    // Проверяем, не добавлен ли уже
    final existing = await _client
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('part_id', partId)
        .maybeSingle();
    if (existing == null) {
      await _client.from('favorites').insert({
        'user_id': userId,
        'part_id': partId,
      });
    }
  }

  static Future<void> removeFromFavorites(String favId) async {
    await _client.from('favorites').delete().eq('id', favId);
  }

  // ═══════════════════════════════════
  // ЗАКАЗЫ ЗАПЧАСТЕЙ (part_orders)
  // ═══════════════════════════════════

  static Future<void> createPartOrder({
    required String clientId,
    required String supplierId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    // Создаём заказ
    final order = await _client.from('part_orders').insert({
      'client_id': clientId,
      'supplier_id': supplierId,
      'total_amount': totalAmount,
      'status': 'pending',
    }).select().single();

    // Добавляем позиции
    final orderItems = items.map((item) => {
      ...item,
      'order_id': order['id'],
    }).toList();

    await _client.from('part_order_items').insert(orderItems);
  }

  static Future<List<dynamic>> getSupplierPartOrders(String supplierId) async {
    final response = await _client
        .from('part_orders')
        .select('*, user_profiles!part_orders_client_id_fkey(first_name, last_name, phone), part_order_items(*, spare_parts(name, article, price))')
        .eq('supplier_id', supplierId)
        .order('created_at', ascending: false);
    return response as List;
  }

  static Future<List<dynamic>> getClientPartOrders(String clientId) async {
    final response = await _client
        .from('part_orders')
        .select('*, user_profiles!part_orders_supplier_id_fkey(first_name, last_name, company_name), part_order_items(*, spare_parts(name, article, price))')
        .eq('client_id', clientId)
        .order('created_at', ascending: false);
    return response as List;
  }

  static Future<void> updatePartOrderStatus(String orderId, String status) async {
    await _client
        .from('part_orders')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', orderId);
  }

  /// Подписка на изменения конкретной заявки
  static RealtimeChannel subscribeToRequestChanges(String requestId, Function(ServiceRequest) onUpdate) {
    print('🔄 Подписка на изменения заявки $requestId...');
    final channel = _client.channel('public:service_requests:id=eq.$requestId');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'service_requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: requestId,
      ),
      callback: (payload) async {
        print('🔔 Получено обновление заявки $requestId: ${payload.eventType}');
        // Перезагружаем заявку целиком, чтобы получить данные из джойнов
        final updatedRequest = await getRequestById(requestId);
        if (updatedRequest != null) {
          onUpdate(updatedRequest);
        }
      },
    ).subscribe();
    
    return channel;
  }

  /// Подписка на изменения всех заявок пользователя/компании
  static RealtimeChannel subscribeToAllRequests(AppUserModel.User user, Function() onUpdate) {
    print('🔄 Подписка на все изменения заявок...');
    final channel = _client.channel('public:service_requests_all');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'service_requests',
      callback: (payload) {
        print('🔔 Обнаружено изменение в таблице заявок: ${payload.eventType}');
        onUpdate();
      },
    ).subscribe();
    
    return channel;
  }

  // === CHAT / MESSAGES ===

  static Future<List<RequestMessage>> getRequestMessages(String requestId) async {
    try {
      final response = await _client
          .from('request_messages')
          .select('*, sender:user_profiles!request_messages_sender_id_fkey(*)')
          .eq('request_id', requestId)
          .order('created_at', ascending: true);
      
      return (response as List).map((json) => RequestMessage.fromJson(json)).toList();
    } catch (e) {
      print('❌ Ошибка загрузки сообщений: $e');
      return [];
    }
  }

  static Future<RequestMessage?> getMessageById(String messageId) async {
    try {
      final response = await _client
          .from('request_messages')
          .select('*, sender:user_profiles!request_messages_sender_id_fkey(*)')
          .eq('id', messageId)
          .maybeSingle();
      
      if (response != null) {
        return RequestMessage.fromJson(response);
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки сообщения по ID: $e');
      return null;
    }
  }

  static Future<void> sendRequestMessage({
    required String requestId,
    required String senderId,
    String? message,
    List<String>? attachments,
  }) async {
    try {
      final response = await _client.from('request_messages').insert({
        'request_id': requestId,
        'sender_id': senderId,
        'message': message,
        'attachments': attachments,
      }).select().single();
      
      // Уведомляем участников о новом сообщении
      _notifyParties(requestId, 'Новое сообщение', message ?? 'Вам прислали вложение в чат.', message: message);
      
      print('✅ Сообщение отправлено: ${response['id']}');
    } catch (e) {
      print('❌ Ошибка отправки сообщения: $e');
      rethrow;
    }
  }

  static RealtimeChannel subscribeToRequestMessages(String requestId, Function(RequestMessage) onNewMessage) {
    print('🔄 Подписка на сообщения заявки $requestId...');
    final channel = _client.channel('messages_$requestId');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'request_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'request_id',
        value: requestId,
      ),
      callback: (payload) async {
        print('🔔 Новое событие Postgres: ${payload.newRecord['id']}');
        // Загружаем только это конкретное сообщение (с джойном отправителя)
        final newMessage = await getMessageById(payload.newRecord['id']);
        if (newMessage != null) {
           onNewMessage(newMessage);
        }
      },
    ).subscribe();
    
    return channel;
  }

  // === NOTIFICATION SYSTEM ===

  static Future<void> _notifyParties(String requestId, String title, String body, {String? message}) async {
    try {
      // 1. Получаем заявку и участников
      final req = await getRequestById(requestId);
      if (req == null) return;
      
      final authorId = req.userId;
      final engineerId = req.assignedEngineerId;
      
      // 2. Добавляем уведомление в системную таблицу (для UI Mini App)
      // Нам нужно создать уведомление для каждого участника (пока просто в таблицу)
      // В реальности тут лучше цикл по всем причастным.
      
      Set<String> notifyIds = {authorId};
      if (engineerId != null) notifyIds.add(engineerId);
      
      // Добавляем администраторов для уведомлений
      try {
        final adminsResponse = await _client
            .from('user_profiles')
            .select('id')
            .inFilter('role', ['superAdmin', 'administrator']);
        
        for (var admin in adminsResponse as List) {
          notifyIds.add(admin['id']);
        }
      } catch (e) {
        print('⚠️ Ошибка получения списка админов для уведомления: $e');
      }
      
      final String shortId = requestId.length > 5 ? requestId.substring(0, 5).toUpperCase() : requestId.toUpperCase();
      
      for (final uid in notifyIds) {
        // Пропускаем если отправитель это текущий пользователь
        if (uid == currentUser?.id) continue;
        
        await createNotification(
          userId: uid,
          title: 'Новое сообщение по заявке #$shortId',
          message: body,
          type: 'newMessage',
          relatedId: requestId,
        );
        
        // 3. Отправляем в Telegram
        _sendTelegramNotification(uid, '$title: $body ${message != null ? '\n\n"$message"' : ''}');
      }
      
      // Также уведомляем админов, если тип уведомления критичен (или просто сообщение)
      // Для примера отправим уведомление в ТГ всем админам (если у них привязан ТГ)
    } catch (e) {
      print('⚠️ Ошибка при рассылке уведомлений: $e');
    }
  }

  static Future<void> _sendTelegramNotification(String userId, String text) async {
    try {
      final profile = await getUserProfile(userId);
      if (profile == null) return;
      
      final String? tgIdStr = profile['telegram_id']?.toString();
      final String? fullName = '${profile['first_name']} ${profile['last_name']}';
      
      if (tgIdStr != null && tgIdStr.isNotEmpty) {
         TelegramBotService.notifyUserDirectly(tgIdStr, text);
      }
    } catch (e) {
      print('⚠️ Ошибка отправки ТГ уведомления: $e');
    }
  }
}
