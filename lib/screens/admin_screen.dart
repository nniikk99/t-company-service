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
              Navigator.pushNamed(context, '/database-check', arguments: user);
            },
          ),
        ],
      ),
      body: const DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              indicatorColor: Color(0xFF4A90E2),
              labelColor: Color(0xFF4A90E2),
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(
                  icon: Icon(Icons.people),
                  text: 'Пользователи',
                ),
                Tab(
                  icon: Icon(Icons.assignment),
                  text: 'Заявки',
                ),
                Tab(
                  icon: Icon(Icons.payments),
                  text: 'Цены',
                ),
              ],
            ),
            Expanded(
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
