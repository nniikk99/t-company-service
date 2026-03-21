import 'package:supabase/supabase.dart';
void main() async {
  final client = SupabaseClient('https://kwunhuzfnjpcoeusnxzy.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt3dW5odXpmbmpwY29ldXNueHp5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQwNDM2MTksImV4cCI6MjA1OTYxOTYxOX0.2ppg8GtsGKE-ACMC__jSTy0gmn7eUya2xHagi9cdypE');
  try {
    final response = await client.from('request_messages').select('*, sender:user_profiles(*)').limit(1);
    print("SUCCESS: \$response");
  } catch (e) {
    print("ERROR OCCURRED: \$e");
  }
}
