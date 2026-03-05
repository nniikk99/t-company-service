import 'package:http/http.dart' as http;
import 'lib/config/supabase_config.dart';

void main() async {
  final url = Uri.parse('\${SupabaseConfig.url}/rest/v1/rpc/test_sql');
  // wait we can't run arbitrary SQL through anon API unless there's an RPC.
  // There is no test_sql.
  // Instead, let's use the PostgREST API to query pg_policies?
  final pgPoliciesUrl = Uri.parse('\${SupabaseConfig.url}/rest/v1/pg_policies?tablename=eq.equipment_models');
  final res = await http.get(pgPoliciesUrl, headers: {
    'apikey': SupabaseConfig.anonKey,
    'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
  });
  print('Status: ${res.statusCode}');
  print('Body: ${res.body}');
}
