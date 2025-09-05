import 'package:flutter/material.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ-панель'),
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
