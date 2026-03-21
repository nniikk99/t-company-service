import 'package:supabase/supabase.dart';
void main() async {
  final client = SupabaseClient('https://kwunhuzfnjpcoeusnxzy.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt3dW5odXpmbmpwY29ldXNueHp5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQwNDM2MTksImV4cCI6MjA1OTYxOTYxOX0.2ppg8GtsGKE-ACMC__jSTy0gmn7eUya2xHagi9cdypE');
  
  try {
    final response = await client.from('request_messages').select('*, sender:user_profiles(*)');
    print('Fetched messages. Parsing...');
    
    for (var json in response) {
      try {
        final senderProfile = json['sender'] as Map<String, dynamic>?;
        final senderName = senderProfile != null 
            ? senderProfile['first_name'] + ' ' + senderProfile['last_name']
            : null;

        final msg = {
          'id': json['id'],
          'requestId': json['request_id'],
          'senderId': json['sender_id'],
          'senderName': senderName,
          'message': json['message'],
          'attachments': json['attachments'] != null ? List<String>.from(json['attachments']) : null,
          'createdAt': DateTime.parse(json['created_at'].toString()),
        };
        print('Parsed successfully: ' + json['id'].toString());
      } catch (e) {
        print('Error parsing message: ' + json['id'].toString() + ' Error: ' + e.toString());
      }
    }
  } catch (e) {
    print('Top level exception: ' + e.toString());
  }
}
