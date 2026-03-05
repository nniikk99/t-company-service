void main() {
  const url = 'https://drive.google.com/file/d/1G7H_QZ_WzX12345/view?usp=sharing';
  print('url: \$url');
  
  if (url.contains('drive.google.com/file/d/')) {
      final startIndex = url.indexOf('/d/') + 3;
      final endIndex = url.indexOf('/', startIndex);
      if (endIndex != -1) {
        final id = url.substring(startIndex, endIndex);
        print('https://drive.google.com/file/d/\$id/preview');
      } else {
        final qIndex = url.indexOf('?', startIndex);
        if (qIndex != -1) {
           final id = url.substring(startIndex, qIndex);
           print('https://drive.google.com/file/d/\$id/preview');
        } else {
           final id = url.substring(startIndex);
           print('https://drive.google.com/file/d/\$id/preview');
        }
      }
    }
}
