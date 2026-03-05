import 'dart:io';

void main() async {
  final regions = [
    'eu-central-1', 'eu-west-1', 'eu-west-2', 'eu-west-3', 
    'us-east-1', 'us-east-2', 'us-west-1', 'us-west-2',
    'ap-south-1', 'ap-southeast-1', 'ap-southeast-2', 'ap-northeast-1', 'ap-northeast-2',
    'sa-east-1', 'ca-central-1'
  ];
  
  for (final r in regions) {
    try {
      const host = 'aws-0-\$r.pooler.supabase.com';
      final res = await InternetAddress.lookup(host);
      if (res.isNotEmpty) {
        print('Resolved: \$host');
      }
    } catch(e) { }
  }
}
