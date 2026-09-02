import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;
  String? _errorMessage;

  Future<void> _signIn() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
    } on GoogleSignInException catch (error) {
      if (!mounted) return;
      if (error.code != GoogleSignInExceptionCode.canceled) {
        setState(() => _errorMessage = 'Google 로그인에 실패했어요. 다시 시도해 주세요.');
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _messageFor(error.code));
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = '로그인 중 문제가 발생했어요.');
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  String _messageFor(String code) => switch (code) {
    'account-exists-with-different-credential' => '이미 다른 방식으로 가입된 계정이에요.',
    'network-request-failed' => '네트워크 연결을 확인해 주세요.',
    _ => 'Google 로그인에 실패했어요. 다시 시도해 주세요.',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.kitchen_outlined,
                size: 46,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '뭐있지',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              '냉장고 속 식품을 안전하게 저장하고\n어디서든 확인하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                key: const Key('googleSignInButton'),
                onPressed: _isSigningIn ? null : _signIn,
                icon:
                    _isSigningIn
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.login),
                label: Text(_isSigningIn ? '로그인 중...' : 'Google로 계속하기'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '로그인하면 식품과 설정이 계정별로 동기화됩니다.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
