import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/player_profile.dart';
import '../../../domain/entities/sport.dart';
import '../../cubits/auth_cubit.dart';
import '../../cubits/profile_cubit.dart';
import '../../cubits/catalog_cubit.dart';
import '../../theme.dart';
import 'profile_dropdown_safety.dart';

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
  bool _isRemoving = false;

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

  Future<void> _confirmRemoveSpecialization() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove this specialization?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Remove',
                style: TextStyle(color: AppTheme.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated || widget.profile == null) return;

    setState(() {
      _isRemoving = true;
    });

    final removed = await context.read<ProfileCubit>().deleteProfile(
      profileId: widget.profile!.id,
      userId: authState.user.id,
    );

    if (!mounted) return;
    if (!removed) {
      setState(() {
        _isRemoving = false;
      });
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
                  _isRemoving
                      ? 'Specialization removed'
                      : isEditMode
                      ? 'Profile updated successfully'
                      : 'Profile created successfully',
                ),
                backgroundColor: AppTheme.success,
              ),
            );
            Navigator.pop(context);
          } else if (state is ProfileError) {
            if (_isRemoving) {
              setState(() {
                _isRemoving = false;
              });
            }
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
          final isBusy = isSubmitting || _isRemoving;

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
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: AppTheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(catalogState.message, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            context
                                .read<CatalogCubit>()
                                .loadSportsAndCategories();
                          },
                          child: const Text('RETRY'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              List<Sport> sports = [];
              if (catalogState is CatalogLoaded) {
                sports = uniqueByDropdownId(
                  catalogState.sports,
                  (sport) => sport.id,
                  debugLabel: 'ProfileForm.sport',
                );
                if (_selectedSportId == null &&
                    sports.isNotEmpty &&
                    !isEditMode) {
                  _selectedSportId = sports.first.id;
                }
              }
              final safeSportId = safeDropdownValue(
                _selectedSportId,
                sports,
                (sport) => sport.id,
                debugLabel: 'ProfileForm.sport',
              );
              final uniqueSkillLevels = uniqueByDropdownId(
                _skillLevels,
                (level) => level,
                debugLabel: 'ProfileForm.skillLevel',
              );
              final safeSkillLevel = safeDropdownValue(
                _selectedSkillLevel,
                uniqueSkillLevels,
                (level) => level,
                debugLabel: 'ProfileForm.skillLevel',
              );

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          isEditMode
                              ? 'Modify Profile'
                              : 'Configure Sport Profile',
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
                            initialValue:
                                widget.profile?.sportDetails?.name ??
                                widget.profile?.sport.toUpperCase(),
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Sport',
                              prefixIcon: Icon(Icons.sports_rounded),
                            ),
                          )
                        else
                          DropdownButtonFormField<String>(
                            key: ValueKey('profile-sport-$safeSportId'),
                            initialValue: safeSportId,
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
                          enabled: !isBusy,
                          decoration: const InputDecoration(
                            labelText:
                                'Role, Position or Discipline (e.g. Striker, Pace Bowler)',
                            prefixIcon: Icon(Icons.location_searching_rounded),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Skill Level Dropdown
                        DropdownButtonFormField<String>(
                          key: ValueKey('skill-level-$safeSkillLevel'),
                          initialValue: safeSkillLevel,
                          decoration: const InputDecoration(
                            labelText: 'Skill Level',
                            prefixIcon: Icon(Icons.star_outline),
                          ),
                          items: uniqueSkillLevels.map((level) {
                            return DropdownMenuItem<String>(
                              value: level,
                              child: Text(level.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: isBusy
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
                          onPressed: isBusy ? null : _submit,
                          child: isBusy
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
                                  isEditMode
                                      ? 'Save Changes'
                                      : 'CREATE PROFILE',
                                ),
                        ),
                        if (isEditMode) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: isBusy
                                ? null
                                : _confirmRemoveSpecialization,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              side: const BorderSide(color: AppTheme.error),
                            ),
                            child: const Text('Remove Specialization'),
                          ),
                        ],
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
