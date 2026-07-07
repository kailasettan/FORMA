import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../../cubits/auth_cubit.dart';
import '../../theme.dart';
import '../../widgets/avatar_image.dart';
import 'profile_photo_validation.dart';

class EditProfileScreen extends StatefulWidget {
  final User user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _usernameError =
      'Username can only use lowercase letters, numbers, dots, and underscores.';
  static final _usernamePattern = RegExp(
    r'^(?![._])(?!.*\.\.)[a-z0-9._]{3,30}(?<![._])$',
  );

  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;

  final _imagePicker = ImagePicker();
  File? _selectedProfilePhotoFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _usernameController = TextEditingController(text: widget.user.username);
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _locationController = TextEditingController(
      text: widget.user.location ?? '',
    );
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
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
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

    final selectedFile = File(file.path);
    final isValidPhoto = await isValidProfilePhotoFile(selectedFile);
    if (!mounted) return;
    if (!isValidPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(profilePhotoValidationMessage),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _selectedProfilePhotoFile = selectedFile;
    });
  }

  ImageProvider? _profilePhotoImage() {
    final selectedFile = _selectedProfilePhotoFile;
    if (selectedFile != null) return FileImage(selectedFile);

    return avatarImageProvider(widget.user.profilePhotoUrl);
  }

  void _submit() async {
    if (_isSaving) return;
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          _isSaving = true;
        });
        final profileRepo = context.read<ProfileRepository>();
        var profilePhotoUrl = widget.user.profilePhotoUrl;
        final selectedPhotoFile = _selectedProfilePhotoFile;
        if (selectedPhotoFile != null) {
          if (!await isValidProfilePhotoFile(selectedPhotoFile)) {
            throw const FormatException(profilePhotoValidationMessage);
          }
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
          username: _usernameController.text.trim().toLowerCase(),
          bio: _bioController.text.trim().isNotEmpty
              ? _bioController.text.trim()
              : '',
          location: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : '',
          profilePhotoUrl: profilePhotoUrl,
          headline: widget.user.headline,
          availability: widget.user.availability,
          preferredOpportunityTypes: widget.user.preferredOpportunityTypes,
          focusedSportId: widget.user.focusedSportId,
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
          final message = e is FormatException
              ? e.message
              : 'Failed to update profile: $e';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _isSaving ? null : _pickProfilePhoto,
                        child: CircleAvatar(
                          key: ValueKey(
                            _selectedProfilePhotoFile?.path ??
                                validAvatarUrl(widget.user.profilePhotoUrl),
                          ),
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
                const SizedBox(height: 24),

                TextFormField(
                  controller: _fullNameController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Name',
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
                  controller: _usernameController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
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
                const SizedBox(height: 18),

                TextFormField(
                  controller: _bioController,
                  enabled: !_isSaving,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
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
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.location_on_outlined),
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
      ),
    );
  }
}
