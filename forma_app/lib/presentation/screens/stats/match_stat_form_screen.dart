import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubits/auth_cubit.dart';
import '../../cubits/stats_cubit.dart';
import '../../theme.dart';

class MatchStatFormScreen extends StatefulWidget {
  const MatchStatFormScreen({super.key});

  @override
  State<MatchStatFormScreen> createState() => _MatchStatFormScreenState();
}

class _MatchStatFormScreenState extends State<MatchStatFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _opponentController = TextEditingController();
  final _goalsController = TextEditingController(text: '0');
  final _assistsController = TextEditingController(text: '0');

  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _opponentController.dispose();
    _goalsController.dispose();
    _assistsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: AppTheme.cardBg,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final authState = context.read<AuthCubit>().state;
      if (authState is! AuthAuthenticated) return;

      final userId = authState.user.id;
      final goals = int.parse(_goalsController.text);
      final assists = int.parse(_assistsController.text);

      context.read<StatsCubit>().addMatchStat(
        sport: 'football',
        date: _selectedDate,
        opponent: _opponentController.text.trim(),
        stats: {'goals': goals, 'assists': assists},
        userId: userId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        "${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}";

    return Scaffold(
      appBar: AppBar(title: const Text('Record Match')),
      body: BlocConsumer<StatsCubit, StatsState>(
        listener: (context, state) {
          if (state is StatsSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Match record added successfully'),
                backgroundColor: AppTheme.success,
              ),
            );
            Navigator.pop(context);
          } else if (state is StatsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isSubmitting = state is StatsSubmitting;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Match Details (Football)',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Input the game context and match stats to aggregate with your overall performance.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Opponent Field
                    TextFormField(
                      controller: _opponentController,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Opponent Name',
                        prefixIcon: Icon(Icons.shield_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the opponent name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Date Picker Trigger Row
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Match Date',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: isSubmitting
                                ? null
                                : () => _selectDate(context),
                            child: const Text('SELECT'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      'Match Stats',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Goals & Assists Inputs
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _goalsController,
                            enabled: !isSubmitting,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Goals Scored',
                              prefixIcon: Icon(Icons.sports_soccer_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final val = int.tryParse(value);
                              if (val == null) {
                                return 'Must be a number';
                              }
                              if (val < 0) {
                                return 'Cannot be negative';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _assistsController,
                            enabled: !isSubmitting,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Assists Given',
                              prefixIcon: Icon(Icons.assistant_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final val = int.tryParse(value);
                              if (val == null) {
                                return 'Must be a number';
                              }
                              if (val < 0) {
                                return 'Cannot be negative';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Submit
                    ElevatedButton(
                      onPressed: isSubmitting ? null : _submit,
                      child: isSubmitting
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
                          : const Text('SUBMIT STATS'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
