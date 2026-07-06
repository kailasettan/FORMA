import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/sport.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../../cubits/auth_cubit.dart';
import '../../cubits/catalog_cubit.dart';
import '../../theme.dart';
import 'profile_dropdown_safety.dart';

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

  final _imagePicker = ImagePicker();
  File? _selectedProfilePhotoFile;
  bool _isSaving = false;
  String? _selectedAvailability;
  String? _selectedFocusedSportId;
  Set<String> _validFocusedSportIds = {};

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
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;

    if (!_isAllowedProfileImage(file.path)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a JPG, PNG, or WEBP image.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _selectedProfilePhotoFile = File(file.path);
    });
  }

  ImageProvider? _profilePhotoImage() {
    final selectedFile = _selectedProfilePhotoFile;
    if (selectedFile != null) return FileImage(selectedFile);

    final currentUrl = widget.user.profilePhotoUrl;
    if (currentUrl != null && currentUrl.isNotEmpty) {
      return NetworkImage(currentUrl);
    }

    return null;
  }

  bool _isAllowedProfileImage(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  void _submit() async {
    if (_isSaving) return;
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
        setState(() {
          _isSaving = true;
        });
        final profileRepo = context.read<ProfileRepository>();
        var profilePhotoUrl = widget.user.profilePhotoUrl;
        final selectedPhotoFile = _selectedProfilePhotoFile;
        if (selectedPhotoFile != null) {
          final signature = await profileRepo.getProfilePhotoUploadSignature();
          final cloudinaryResponse = await profileRepo
              .uploadProfilePhotoToCloudinary(
                file: selectedPhotoFile,
                signatureData: signature,
              );
          profilePhotoUrl = cloudinaryResponse['secure_url'] as String;
        }

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
          profilePhotoUrl: profilePhotoUrl,
          availability: _selectedAvailability,
          preferredOpportunityTypes: opportunities.isNotEmpty
              ? opportunities
              : null,
          focusedSportId:
              _validFocusedSportIds.contains(_selectedFocusedSportId)
              ? _selectedFocusedSportId
              : null,
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
          Navigator.pop(context, updatedUser);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
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
            sports = uniqueByDropdownId(
              catalogState.sports,
              (sport) => sport.id,
              debugLabel: 'EditProfile.focusedSport',
            );
          }
          _validFocusedSportIds = sports.map((sport) => sport.id).toSet();
          final safeAvailability = safeDropdownValue(
            _selectedAvailability,
            _availabilityOptions,
            (option) => option,
            debugLabel: 'EditProfile.availability',
          );
          final safeFocusedSportId = safeDropdownValue(
            _selectedFocusedSportId,
            sports,
            (sport) => sport.id,
            debugLabel: 'EditProfile.focusedSport',
          );

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
                      enabled: !_isSaving,
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

                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _isSaving ? null : _pickProfilePhoto,
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: AppTheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              foregroundImage: _profilePhotoImage(),
                              child: _profilePhotoImage() == null
                                  ? const Icon(
                                      Icons.person_rounded,
                                      size: 42,
                                      color: AppTheme.primary,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _isSaving ? null : _pickProfilePhoto,
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Change photo'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    TextFormField(
                      controller: _headlineController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Headline (e.g. Badminton Singles Player)',
                        prefixIcon: Icon(Icons.flash_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),

                    TextFormField(
                      controller: _bioController,
                      enabled: !_isSaving,
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
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Location (e.g. California, US)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Availability Status Dropdown
                    DropdownButtonFormField<String>(
                      key: ValueKey('availability-$safeAvailability'),
                      initialValue: safeAvailability,
                      decoration: const InputDecoration(
                        labelText: 'Availability Status',
                        prefixIcon: Icon(Icons.event_available_rounded),
                      ),
                      items: _availabilityOptions.map((opt) {
                        return DropdownMenuItem(value: opt, child: Text(opt));
                      }).toList(),
                      onChanged: (val) {
                        if (_isSaving) return;
                        setState(() {
                          _selectedAvailability = val;
                        });
                      },
                    ),
                    const SizedBox(height: 18),

                    // Focused Sport Dropdown
                    DropdownButtonFormField<String>(
                      key: ValueKey('focused-sport-$safeFocusedSportId'),
                      initialValue: safeFocusedSportId,
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
                        if (_isSaving) return;
                        setState(() {
                          _selectedFocusedSportId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 18),

                    TextFormField(
                      controller: _opportunitiesController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Preferred Opportunities (comma separated)',
                        hintText: 'Trials, Teams, Coaching, Competitions',
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('SAVE PROFILE'),
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
