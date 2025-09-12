import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/habit_hearts_auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<HabitHeartsAuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Home Screen',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            if (authProvider.habitHeartsUser != null) ...[
              const Text('Welcome to HabitHearts!'),
              const SizedBox(height: 10),
              Text('Your unique code: ${authProvider.habitHeartsUser!.uniqueCode}'),
            ],
          ],
        ),
      ),
    );
  }
}