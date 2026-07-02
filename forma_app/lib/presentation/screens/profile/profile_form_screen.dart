import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/player_profile.dart';
import '../../../domain/entities/sport.dart';
import '../../cubits/auth_cubit.dart';
import '../../cubits/profile_cubit.dart';
import '../../cubits/catalog_cubit.dart';
import '../../theme.dart';

class ProfileFormScreen extends StatefulWidget {
  final PlayerProfile? profile;

  const ProfileFormScreen({super.key, this.profile});

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedSportId;
  late String _selectedSkillLevel;
  final _roleOrDisciplineController = TextEditingController();

  final List<String> _skillLevels = ['beginner', 'intermediate', 'advanced'];

  bool get isEditMode => widget.profile != null;

  @override
  void initState() {
    super.initState();
    _selectedSkillLevel = widget.profile?.skillLevel ?? 'beginner';
    _roleOrDisciplineController.text =
        widget.profile?.roleOrDiscipline ?? widget.profile?.position ?? '';
    _selectedSportId = widget.profile?.sportId;

    // Load sports catalog on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogCubit>().loadSportsAndCategories();
    });
  }

  @override
  void dispose() {
    _roleOrDisciplineController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final authState = context.read<AuthCubit>().state;
      if (authState is! AuthAuthenticated) return;

      final userId = authState.user.id;

      if (isEditMode) {
        context.read<ProfileCubit>().updateProfile(
          profileId: widget.profile!.id,
          position: _roleOrDisciplineController.text.trim(),
          skillLevel: _selectedSkillLevel,
          userId: userId,
        );
      } else {
        context.read<ProfileCubit>().createProfile(
          sport: _selectedSportId!, // We pass sport_id now!
          position: _roleOrDisciplineController.text.trim(),
          skillLevel: _selectedSkillLevel,
          userId: userId,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Profile' : 'Add Sport Profile'),
      ),
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state is ProfileSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isEditMode
                      ? 'Profile updated successfully'
                      : 'Profile created successfully',
                ),
                backgroundColor: AppTheme.success,
              ),
            );
            Navigator.pop(context);
          } else if (state is ProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isSubmitting = state is ProfileSubmitting;

          return BlocBuilder<CatalogCubit, CatalogState>(
            builder: (context, catalogState) {
              if (catalogState is CatalogLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (catalogState is CatalogError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
                        const SizedBox(height: 16),
                        Text(catalogState.message, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            context.read<CatalogCubit>().loadSportsAndCategories();
                          },
                          child: const Text('RETRY'),
                        )
                      ],
                    ),
                  ),
                );
              }

              List<Sport> sports = [];
              if (catalogState is CatalogLoaded) {
                sports = catalogState.sports;
                if (_selectedSportId == null && sports.isNotEmpty && !isEditMode) {
                  _selectedSportId = sports.first.id;
                }
              }

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          isEditMode ? 'Modify Profile' : 'Configure Sport Profile',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Define your sport selection, play position, and relative skill tier level.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Sport Dropdown (Disabled in Edit Mode)
                        if (isEditMode)
                          TextFormField(
                            initialValue: widget.profile?.sportDetails?.name ?? widget.profile?.sport.toUpperCase(),
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Sport',
                              prefixIcon: Icon(Icons.sports_rounded),
                            ),
                          )
                        else
                          DropdownButtonFormField<String>(
                            initialValue: _selectedSportId,
                            decoration: const InputDecoration(
                              labelText: 'Sport',
                              prefixIcon: Icon(Icons.sports_rounded),
                            ),
                            items: sports.map((sport) {
                              return DropdownMenuItem<String>(
                                value: sport.id,
                                child: Text(sport.name.toUpperCase()),
                              );
                            }).toList(),
                            onChanged: isSubmitting
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedSportId = val;
                                      });
                                    }
                                  },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                  return 'Please select a sport';
                              }
                              return null;
                            },
                          ),
                        const SizedBox(height: 20),

                        // Position / Discipline Text Input
                        TextFormField(
                          controller: _roleOrDisciplineController,
                          enabled: !isSubmitting,
                          decoration: const InputDecoration(
                            labelText: 'Role, Position or Discipline (e.g. Striker, Pace Bowler)',
                            prefixIcon: Icon(Icons.location_searching_rounded),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Skill Level Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSkillLevel,
                          decoration: const InputDecoration(
                            labelText: 'Skill Level',
                            prefixIcon: Icon(Icons.star_outline),
                          ),
                          items: _skillLevels.map((level) {
                            return DropdownMenuItem<String>(
                              value: level,
                              child: Text(level.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: isSubmitting
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedSkillLevel = val;
                                    });
                                  }
                                },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a skill level';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 40),

                        // Submit Button
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
                              : Text(
                                  isEditMode ? 'SAVE CHANGES' : 'CREATE PROFILE',
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
