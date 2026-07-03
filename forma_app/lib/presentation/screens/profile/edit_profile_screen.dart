import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/sport.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../../cubits/auth_cubit.dart';
import '../../cubits/catalog_cubit.dart';
import '../../theme.dart';

class EditProfileScreen extends StatefulWidget {
  final User user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _headlineController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late TextEditingController _opportunitiesController;
  late TextEditingController _photoUrlController;

  String? _selectedAvailability;
  String? _selectedFocusedSportId;

  final List<String> _availabilityOptions = [
    'Open to trials',
    'Open to teams',
    'Open to coaching',
    'Open to competitions',
    'Not currently available',
  ];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _headlineController = TextEditingController(
      text: widget.user.headline ?? '',
    );
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _locationController = TextEditingController(
      text: widget.user.location ?? '',
    );
    _photoUrlController = TextEditingController(
      text: widget.user.profilePhotoUrl ?? '',
    );

    final opportunitiesList = widget.user.preferredOpportunityTypes ?? [];
    _opportunitiesController = TextEditingController(
      text: opportunitiesList.join(', '),
    );

    _selectedAvailability = widget.user.availability;
    _selectedFocusedSportId = widget.user.focusedSportId;

    // Load sports catalog to display in Focused Sport dropdown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogCubit>().loadSportsAndCategories();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _headlineController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _opportunitiesController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final opportunitiesText = _opportunitiesController.text.trim();
      final List<String> opportunities = opportunitiesText.isNotEmpty
          ? opportunitiesText
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList()
          : [];

      try {
        final profileRepo = context.read<ProfileRepository>();
        final updatedUser = await profileRepo.updateMe(
          fullName: _fullNameController.text.trim(),
          headline: _headlineController.text.trim().isNotEmpty
              ? _headlineController.text.trim()
              : null,
          bio: _bioController.text.trim().isNotEmpty
              ? _bioController.text.trim()
              : null,
          location: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
          profilePhotoUrl: _photoUrlController.text.trim().isNotEmpty
              ? _photoUrlController.text.trim()
              : null,
          availability: _selectedAvailability,
          preferredOpportunityTypes: opportunities.isNotEmpty
              ? opportunities
              : null,
          focusedSportId: _selectedFocusedSportId,
        );

        // Update auth state in AuthCubit
        if (mounted) {
          context.read<AuthCubit>().updateCurrentUser(updatedUser);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: AppTheme.success,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update profile: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: BlocBuilder<CatalogCubit, CatalogState>(
        builder: (context, catalogState) {
          List<Sport> sports = [];
          if (catalogState is CatalogLoaded) {
            sports = catalogState.sports;
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    TextFormField(
                      controller: _photoUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Profile Photo URL',
                        prefixIcon: Icon(Icons.image_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),

                    TextFormField(
                      controller: _headlineController,
                      decoration: const InputDecoration(
                        labelText: 'Headline (e.g. Badminton Singles Player)',
                        prefixIcon: Icon(Icons.flash_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),

                    TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Athlete Bio',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 40.0),
                          child: Icon(Icons.description_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location (e.g. California, US)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Availability Status Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAvailability,
                      decoration: const InputDecoration(
                        labelText: 'Availability Status',
                        prefixIcon: Icon(Icons.event_available_rounded),
                      ),
                      items: _availabilityOptions.map((opt) {
                        return DropdownMenuItem(value: opt, child: Text(opt));
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedAvailability = val;
                        });
                      },
                    ),
                    const SizedBox(height: 18),

                    // Focused Sport Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedFocusedSportId,
                      decoration: const InputDecoration(
                        labelText: 'Focused Sport',
                        prefixIcon: Icon(Icons.star_rounded),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('NONE'),
                        ),
                        ...sports.map((sport) {
                          return DropdownMenuItem<String>(
                            value: sport.id,
                            child: Text(sport.name.toUpperCase()),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedFocusedSportId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 18),

                    TextFormField(
                      controller: _opportunitiesController,
                      decoration: const InputDecoration(
                        labelText: 'Preferred Opportunities (comma separated)',
                        hintText: 'Trials, Teams, Coaching, Competitions',
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _submit,
                      child: const Text('SAVE PROFILE'),
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
