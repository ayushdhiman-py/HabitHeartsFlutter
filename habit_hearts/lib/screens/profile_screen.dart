import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/habit_hearts_auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Profile Screen',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            if (authProvider.user != null) ...[
              CircleAvatar(
                radius: 50,
                backgroundImage: authProvider.user?.photoURL != null
                    ? NetworkImage(authProvider.user!.photoURL!)
                    : null,
                child: authProvider.user?.photoURL == null
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                authProvider.user?.displayName ?? 'User',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                authProvider.user?.email ?? '',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              if (authProvider.habitHeartsUser != null) ...[
                const Text(
                  'Unique Code:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  authProvider.habitHeartsUser!.uniqueCode,
                  style: const TextStyle(fontSize: 18, color: Colors.pink),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}