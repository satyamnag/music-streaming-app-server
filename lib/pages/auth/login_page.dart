import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/provider/auth/auth_provider.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';

class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final authState = ref.watch(authProvider);
    final phoneController = useTextEditingController();
    final theme = Theme.of(context);

    return Scaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Soulful Bhakti', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: theme.colorScheme.foreground)),
              const Gap(8),
              Text('Enter your phone number to sign in', style: TextStyle(color: theme.colorScheme.mutedForeground)),
              const Gap(32),
              FormField(
                key: FormKey<dynamic>('phone'),
                label: const Text('Phone Number'),
                child: TextField(
                  controller: phoneController,
                  placeholder: const Text('+1234567890'),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  keyboardType: TextInputType.phone,
                ),
              ),
              const Gap(16),
              Button.primary(
                enabled: !authState.loading,
                onPressed: () {
                  final phone = phoneController.text.trim();
                  if (phone.isNotEmpty) {
                    ref.read(authProvider.notifier).sendOtp('+$phone');
                  }
                },
                child: authState.loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Send OTP'),
              ),
              if (authState.error != null) ...[
                const Gap(16),
                Text(authState.error!, style: TextStyle(color: theme.colorScheme.destructive)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OtpPage extends HookConsumerWidget {
  final String phone;
  const OtpPage({super.key, required this.phone});

  @override
  Widget build(BuildContext context, ref) {
    final authState = ref.watch(authProvider);
    final otpController = useTextEditingController();
    final theme = Theme.of(context);

    return Scaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Verify OTP', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.colorScheme.foreground)),
              const Gap(8),
              Text('Enter the code sent to $phone', style: TextStyle(color: theme.colorScheme.mutedForeground)),
              const Gap(32),
              FormField(
                key: FormKey<dynamic>('otp'),
                label: const Text('OTP Code'),
                child: TextField(
                  controller: otpController,
                  placeholder: const Text('123456'),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  keyboardType: TextInputType.number,
                ),
              ),
              const Gap(16),
              Button.primary(
                enabled: !authState.loading,
                onPressed: () {
                  final otp = otpController.text.trim();
                  if (otp.length == 6) {
                    ref.read(authProvider.notifier).verifyOtp(otp);
                  }
                },
                child: authState.loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Verify & Sign In'),
              ),
              if (authState.error != null) ...[
                const Gap(16),
                Text(authState.error!, style: TextStyle(color: theme.colorScheme.destructive)),
              ],
              const Gap(24),
              Button.text(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileDialog extends ConsumerStatefulWidget {
  const ProfileDialog({super.key});

  @override
  ConsumerState<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<ProfileDialog> {
  final nameController = TextEditingController();
  final avatarController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    avatarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final baseUrl = 'http://127.0.0.1:${SangeetMedia.serverPort}';

    return AlertDialog(
      title: const Text('Profile'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(SangeetIcons.user, size: 32, color: theme.colorScheme.primary),
            ),
            const Gap(8),
            Text(authState.phone ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Gap(16),
            FormField(
              key: FormKey<dynamic>('name'),
              label: const Text('Full Name'),
              child: TextField(controller: nameController, placeholder: const Text('Your name')),
            ),
            const Gap(12),
            FormField(
              key: FormKey<dynamic>('avatar'),
              label: const Text('Avatar URL'),
              child: TextField(controller: avatarController, placeholder: const Text('https://...')),
            ),
            const Gap(16),
            Button.primary(
              onPressed: () async {
                final dio = Dio();
                await dio.post('$baseUrl/supabase/user-profile', data: {
                  'id': authState.userId,
                  'full_name': nameController.text,
                  'avatar_url': avatarController.text,
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
            const Gap(8),
            Button.destructive(
              onPressed: () async {
                ref.read(authProvider.notifier).logout();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}
