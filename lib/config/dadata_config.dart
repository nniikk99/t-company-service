/// Конфигурация DaData (подсказки по организациям).
///
/// ВАЖНО: этот токен — клиентский (API-ключ DaData для suggestions).
/// По дизайну DaData он используется в браузере и виден пользователям.
/// Защита — НЕ секретность, а ограничение по HTTP-referer в личном кабинете
/// DaData: добавьте туда домены приложения (например, nniikk99.github.io
/// и ваш будущий домен). Тогда с чужих сайтов токен работать не будет.
///
/// Секретный ключ DaData (для «стандартизации») здесь НЕ нужен и НЕ хранится.
class DadataConfig {
  /// API-ключ (token) DaData. Замените на свой при необходимости.
  static const String token = '521c63833be138f5361cd4f3c2c64c0fc370ceb2';

  static const String findByIdPartyUrl =
      'https://suggestions.dadata.ru/suggestions/api/4_1/rs/findById/party';
}
