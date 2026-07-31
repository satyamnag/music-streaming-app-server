import 'package:dio/dio.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/provider/auth/auth_provider.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';

class ProfilePage extends HookConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final authState = ref.watch(authProvider);
    final nameController = useTextEditingController();
    final theme = Theme.of(context);
    final baseUrl = 'http://127.0.0.1:${SangeetMedia.serverPort}';

    return Scaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(40),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(SangeetIcons.user, size: 40, color: theme.colorScheme.primary),
                  ),
                  const Gap(16),
                  Text(authState.phone ?? 'User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('ID: ${authState.userId?.substring(0, 8) ?? ""}...', style: TextStyle(fontSize: 12, color: theme.colorScheme.mutedForeground)),
                ],
              ),
            ),
            const Gap(32),
            Text('Profile Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.colorScheme.foreground)),
            const Gap(16),
            FormField(
              key: FormKey<dynamic>('name'),
              label: const Text('Full Name'),
              child: TextField(controller: nameController, placeholder: const Text('Enter your name')),
            ),
            const Gap(16),
            FormField(
              key: FormKey<dynamic>('avatar'),
              label: const Text('Avatar URL'),
              child: TextField(placeholder: const Text('https://example.com/avatar.jpg')),
            ),
            const Gap(24),
            Button.primary(
              onPressed: () async {
                final dio = Dio();
                await dio.post('$baseUrl/supabase/user-profile', data: {
                  'id': authState.userId,
                  'full_name': nameController.text,
                });
              },
              child: const Text('Save Profile'),
            ),
            const Gap(40),
            const Divider(),
            const Gap(16),
            Button.destructive(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      Button.text(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      Button.primary(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out')),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(authProvider.notifier).logout();
                }
              },
              child: const Text('Sign Out'),
            ),
            const Gap(40),
          ],
        ),
      ),
    );
  }
}
