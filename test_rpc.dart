import 'package:http/http.dart' as http;
import 'lib/config/supabase_config.dart';
import 'dart:convert';

void main() async {
  const urlStr = '${SupabaseConfig.url}/rest/v1/?apikey=${SupabaseConfig.anonKey}';
  final url = Uri.parse(urlStr);
  final res = await http.get(url);
  
  if (res.statusCode == 200) {
    final spec = jsonDecode(res.body);
    final paths = spec['paths'] as Map<String, dynamic>;
    
    // Check RPC disable_rls_for_update
    final info = paths['/rpc/disable_rls_for_update'];
    print('disable_rls_for_update schema: ${jsonEncode(info)}');
  }
}
