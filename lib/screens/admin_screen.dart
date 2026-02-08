import 'package:flutter/material.dart';
import '../models/user.dart';

class AdminScreen extends StatelessWidget {
  final User user;
  
  const AdminScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ-панель'),
        actions: [
          IconButton(
            icon: const Icon(Icons.storage),
            tooltip: 'Инструменты БД',
            onPressed: () {
              Navigator.pushNamed(context, '/database-check');
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Пользователи'),
                Tab(text: 'Заявки'),
                Tab(text: 'Цены'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  Center(child: Text('Управление пользователями')),
                  Center(child: Text('Управление заявками')),
                  Center(child: Text('Управление ценами')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
