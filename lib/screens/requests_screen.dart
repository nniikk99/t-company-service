import 'package:flutter/material.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Заявки'),
      ),
      body: const Center(
        child: Text('Экран заявок в разработке'),
      ),
    );
  }
}
