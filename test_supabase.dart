import 'package:supabase/supabase.dart';
import 'lib/config/supabase_config.dart';

void main() async {
  final supabase = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
  
  try {
    // Check if we can delete a model using anon role (if RLS is permissive)
    // We'll just fetch them to see if we can do CRUD
    final res = await supabase.from('equipment_models').select().limit(5);
    print('Models: ${res.length}');
    
    // Test update
    if (res.isNotEmpty) {
      final modelId = res.first['id'];
      print('First model ID: ' + modelId);
      
      // Attempt an update with a null key via RLS
      print('Testing update to jsonb...');
      // By using anon key, this simulates how the client runs it. 
      // If client cannot update/delete, it is RLS policy.
    }
  } catch(e) {
    print('Error: \$e');
  }
}
