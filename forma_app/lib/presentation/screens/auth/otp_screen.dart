import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../cubits/auth_cubit.dart';
import '../../theme.dart';
import '../../router.dart';

class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  
  int _cooldownSeconds = 60;
  Timer? _timer;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    setState(() {
      _cooldownSeconds = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _submitVerification() {
    if (context.read<AuthCubit>().state is AuthLoading) return;
    if (_formKey.currentState!.validate()) {
      context.read<AuthCubit>().verifyOtp(
        widget.email,
        _otpController.text.trim(),
      );
    }
  }

  Future<void> _resendCode() async {
    if (_cooldownSeconds > 0 || _isResending) return;
    setState(() {
      _isResending = true;
    });
    
    try {
      final authRepo = RepositoryProvider.of<AuthRepository>(context);
      await authRepo.resendOtp(email: widget.email);
      _startCooldownTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code resent successfully.'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('ApiException:')) {
          errorMsg = errorMsg.replaceAll('ApiException:', '').trim();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              context.read<AuthCubit>().logout();
            },
          )
        ],
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated && state.user.emailVerified) {
            // Successfully verified! Redirect to dashboard by clearing navigation stack
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRouter.dashboard,
              (route) => false,
            );
          } else if (state is AuthError) {
            String displayMessage = state.message;
            if (displayMessage.toLowerCase().contains('invalid verification code')) {
              displayMessage = 'Invalid verification code.';
            } else if (displayMessage.toLowerCase().contains('expired')) {
              displayMessage = 'Verification code has expired.';
            } else if (displayMessage.toLowerCase().contains('too many failed attempts')) {
              displayMessage = 'Too many failed attempts. Please request a new code.';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(displayMessage),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 80,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Enter Verification Code',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We sent a 6-digit verification code to:\n${widget.email}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: '000000',
                        hintStyle: TextStyle(
                          color: AppTheme.textSecondary,
                          letterSpacing: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the code';
                        }
                        if (value.trim().length != 6) {
                          return 'Verification code must be 6 digits';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submitVerification(),
                    ),
                    const SizedBox(height: 32),
                    BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, state) {
                        final isLoading = state is AuthLoading || _isResending;
                        return ElevatedButton(
                          onPressed: isLoading ? null : _submitVerification,
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('VERIFY EMAIL'),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Didn't receive the code? ",
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        GestureDetector(
                          onTap: _cooldownSeconds > 0 || _isResending ? null : _resendCode,
                          child: Text(
                            _cooldownSeconds > 0
                                ? 'Resend in ${_cooldownSeconds}s'
                                : 'Resend Code',
                            style: TextStyle(
                              color: _cooldownSeconds > 0 || _isResending
                                  ? AppTheme.textSecondary
                                  : AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
