import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubits/auth_cubit.dart';
import '../../theme.dart';
import '../../router.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const _usernameError =
      'Username can only use lowercase letters, numbers, dots, and underscores.';
  static final _usernamePattern = RegExp(
    r'^(?![._])(?!.*\.\.)[a-z0-9._]{3,30}(?<![._])$',
  );

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_normalizeUsernameInput);
  }

  void _normalizeUsernameInput() {
    final current = _usernameController.text;
    final normalized = current.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (current == normalized) return;

    _usernameController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  @override
  void dispose() {
    _usernameController.removeListener(_normalizeUsernameInput);
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (context.read<AuthCubit>().state is AuthLoading) return;
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        return;
      }
      final username = _usernameController.text.trim().toLowerCase();
      context.read<AuthCubit>().signUp(
        username: username,
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        role: 'athlete',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            if (state.verificationRequired) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRouter.otpVerification,
                (route) => false,
                arguments: state.user.email,
              );
            } else {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRouter.dashboard,
                (route) => false,
              );
            }
          } else if (state is AuthError) {
            String displayMessage = state.message;
            if (displayMessage.toLowerCase().contains(
                  'username is already taken',
                ) ||
                displayMessage.toLowerCase().contains(
                  'username or email is already taken',
                )) {
              displayMessage = 'Username is already taken.';
            } else if (displayMessage.toLowerCase().contains(
              'username can only use',
            )) {
              displayMessage = _usernameError;
            } else if (displayMessage.toLowerCase().contains(
                  'email is already taken',
                ) ||
                displayMessage.toLowerCase().contains(
                  'email is already registered',
                )) {
              displayMessage = 'Email is already registered.';
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Join FORMA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connect to the server and track your athletic stats.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Inputs
                    TextFormField(
                      controller: _fullNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        helperText:
                            'Use 3-30 lowercase letters, numbers, dots, or underscores.',
                        prefixIcon: Icon(Icons.alternate_email_outlined),
                      ),
                      validator: (value) {
                        final username = value?.trim().toLowerCase() ?? '';
                        if (username.isEmpty) {
                          return 'Please enter a username';
                        }
                        if (!_usernamePattern.hasMatch(username)) {
                          return _usernameError;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 8 ||
                            !RegExp(r'[a-zA-Z]').hasMatch(value) ||
                            !RegExp(r'[0-9]').hasMatch(value)) {
                          return 'Password must be at least 8 characters and include a letter and a number.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Submit
                    BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, state) {
                        final isLoading = state is AuthLoading;
                        return ElevatedButton(
                          onPressed: isLoading ? null : _submit,
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
                              : const Text('CREATE ACCOUNT'),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
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
