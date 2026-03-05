import 'package:http/http.dart' as http;
import 'lib/config/supabase_config.dart';
import 'dart:convert';

void main() async {
  const urlStr = '${SupabaseConfig.url}/rest/v1/?apikey=${SupabaseConfig.anonKey}';
  final url = Uri.parse(urlStr);
  final res = await http.get(url);
  
  if (res.statusCode == 200) {
    final spec = jsonDecode(res.body);
    final defs = spec['definitions'] as Map<String, dynamic>;
    
    // Find all models that reference equipment_models
    defs.forEach((tableName, schema) {
      final props = schema['properties'] as Map<String, dynamic>?;
      if (props != null) {
        props.forEach((colName, details) {
          final desc = details['description'] as String?;
          if (desc != null && desc.contains("table='equipment_models'")) {
            print('Table \$tableName has FK \$colName to equipment_models');
          }
        });
      }
    });
  }
}
