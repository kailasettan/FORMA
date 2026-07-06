import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../domain/entities/drop.dart';
import '../../../domain/entities/sport.dart';
import '../../../domain/entities/sport_category.dart';
import '../../cubits/catalog_cubit.dart';
import '../../cubits/drop_upload_cubit.dart';
import '../../theme.dart';

class DropUploadScreen extends StatefulWidget {
  final bool showAppBar;
  final bool popOnSuccess;
  final ValueChanged<Drop>? onDropPosted;

  const DropUploadScreen({
    super.key,
    this.showAppBar = true,
    this.popOnSuccess = true,
    this.onDropPosted,
  });

  @override
  State<DropUploadScreen> createState() => _DropUploadScreenState();
}

class _DropUploadScreenState extends State<DropUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  final _imagePicker = ImagePicker();

  File? _videoFile;
  VideoPlayerController? _videoPlayerController;

  String? _selectedSportId;
  String? _selectedCategoryId;
  String _selectedVisibility = 'public';

  bool _isValidatingVideo = false;
  String? _videoValidationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DropUploadCubit>().reset();
      context.read<CatalogCubit>().loadSportsAndCategories();
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    setState(() {
      _videoValidationError = null;
      _isValidatingVideo = true;
    });

    try {
      final XFile? file = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 90),
      );

      if (file == null) {
        setState(() {
          _isValidatingVideo = false;
        });
        return;
      }

      final videoFile = File(file.path);
      final int fileBytes = await videoFile.length();
      final double fileSizeMB = fileBytes / (1024 * 1024);

      if (fileSizeMB > 50) {
        setState(() {
          _videoValidationError =
              'Video file size exceeds 50 MB limit (${fileSizeMB.toStringAsFixed(1)} MB)';
          _isValidatingVideo = false;
        });
        return;
      }

      // Initialize Video Player to fetch duration/resolution details
      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      final duration = controller.value.duration.inMilliseconds / 1000.0;

      if (duration > 60.0) {
        await controller.dispose();
        setState(() {
          _videoValidationError =
              'Video exceeds 60 seconds limit (${duration.toStringAsFixed(1)} seconds). Please trim your clip.';
          _isValidatingVideo = false;
        });
        return;
      }

      // Dispose existing controller if any
      await _videoPlayerController?.dispose();

      setState(() {
        _videoFile = videoFile;
        _videoPlayerController = controller;
        _isValidatingVideo = false;

        // Autoplay/loop preview
        _videoPlayerController!.setLooping(true);
        _videoPlayerController!.play();
      });
    } catch (e) {
      setState(() {
        _videoValidationError = 'Failed to validate video file: $e';
        _isValidatingVideo = false;
      });
    }
  }

  void _submit() {
    if (_videoFile == null) {
      setState(() {
        _videoValidationError = 'Please select a video clip to upload';
      });
      return;
    }

    if (_formKey.currentState!.validate()) {
      context.read<DropUploadCubit>().uploadDrop(
        file: _videoFile!,
        sportId: _selectedSportId!,
        categoryId: _selectedCategoryId,
        caption: _captionController.text.trim().isNotEmpty
            ? _captionController.text.trim()
            : null,
        visibility: _selectedVisibility,
      );
    }
  }

  Future<void> _resetForm() async {
    await _videoPlayerController?.dispose();
    if (!mounted) return;
    setState(() {
      _captionController.clear();
      _videoFile = null;
      _videoPlayerController = null;
      _selectedCategoryId = null;
      _selectedVisibility = 'public';
      _isValidatingVideo = false;
      _videoValidationError = null;
    });
    context.read<DropUploadCubit>().reset();
  }

  void _finishUpload(Drop drop) {
    if (widget.popOnSuccess) {
      Navigator.pop<Drop>(context, drop);
    } else {
      _resetForm();
    }
  }

  void _dismissUpload() {
    if (!widget.popOnSuccess) {
      _resetForm();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Upload Drop'))
          : null,
      body: BlocConsumer<DropUploadCubit, DropUploadState>(
        listener: (context, state) {
          if (state is DropUploadSuccess) {
            widget.onDropPosted?.call(state.drop);
            _debugUploadScreen(
              'success state: id=${state.drop.id} '
              'secondary=${state.secondaryMessage != null}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.secondaryMessage ?? 'Drop posted'),
                backgroundColor: AppTheme.success,
              ),
            );
            if (widget.popOnSuccess && state.secondaryMessage == null) {
              _debugUploadScreen('popping created drop: id=${state.drop.id}');
              Navigator.pop<Drop>(context, state.drop);
            }
          } else if (state is DropUploadError) {
            _debugUploadScreen('error state: ${state.message}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final bool isUploading = state.isActive;

          return BlocBuilder<CatalogCubit, CatalogState>(
            builder: (context, catalogState) {
              List<Sport> sports = [];
              Map<String, List<SportCategory>> categoriesMap = {};

              if (catalogState is CatalogLoaded) {
                sports = catalogState.sports;
                categoriesMap = catalogState.categories;
                if (_selectedSportId == null && sports.isNotEmpty) {
                  _selectedSportId = sports.first.id;
                }
              }

              final activeCategories = _selectedSportId != null
                  ? (categoriesMap[_selectedSportId] ?? [])
                  : <SportCategory>[];

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Share a Drop',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Upload a sports highlight video (under 60s, max 50MB) and tag it to your sport catalog.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Video Selection / Preview Card
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: GestureDetector(
                            onTap: isUploading ? null : _pickVideo,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _videoValidationError != null
                                      ? AppTheme.error
                                      : Colors.white24,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child:
                                  _videoFile != null &&
                                      _videoPlayerController != null
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        VideoPlayer(_videoPlayerController!),
                                        Container(
                                          color: Colors.black26,
                                          child: const Center(
                                            child: Icon(
                                              Icons.play_circle_outline_rounded,
                                              size: 48,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Center(
                                      child: _isValidatingVideo
                                          ? const CircularProgressIndicator()
                                          : const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.video_call_rounded,
                                                  size: 48,
                                                  color: AppTheme.primary,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Tap to Select Video Clip',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                            ),
                          ),
                        ),
                        if (_videoValidationError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _videoValidationError!,
                            style: const TextStyle(
                              color: AppTheme.error,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Caption Field
                        TextFormField(
                          controller: _captionController,
                          enabled: !isUploading,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Caption / Description',
                            prefixIcon: Icon(Icons.closed_caption_rounded),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Sport Selector Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSportId,
                          decoration: const InputDecoration(
                            labelText: 'Associated Sport',
                            prefixIcon: Icon(Icons.sports_rounded),
                          ),
                          items: sports.map((sport) {
                            return DropdownMenuItem<String>(
                              value: sport.id,
                              child: Text(sport.name.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: isUploading
                              ? null
                              : (val) {
                                  setState(() {
                                    _selectedSportId = val;
                                    _selectedCategoryId =
                                        null; // Reset category
                                  });
                                },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a sport';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // Category Selector Dropdown (Dynamically enabled/filled)
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration: InputDecoration(
                            labelText: activeCategories.isEmpty
                                ? 'No Categories for this Sport'
                                : 'Sport Category (Optional)',
                            prefixIcon: const Icon(Icons.category_rounded),
                          ),
                          items: activeCategories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat.id,
                              child: Text(cat.name.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (isUploading || activeCategories.isEmpty)
                              ? null
                              : (val) {
                                  setState(() {
                                    _selectedCategoryId = val;
                                  });
                                },
                        ),
                        const SizedBox(height: 18),

                        // Visibility dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _selectedVisibility,
                          decoration: const InputDecoration(
                            labelText: 'Visibility',
                            prefixIcon: Icon(Icons.visibility_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'public',
                              child: Text('PUBLIC'),
                            ),
                            DropdownMenuItem(
                              value: 'private',
                              child: Text('PRIVATE'),
                            ),
                          ],
                          onChanged: isUploading
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedVisibility = val;
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 32),

                        // Progress representation
                        if (state is DropUploadSuccess) ...[
                          _buildUploadProgress(state),
                          const SizedBox(height: 24),
                        ] else if (isUploading) ...[
                          _buildUploadProgress(state),
                          const SizedBox(height: 24),
                        ],
                        if (state is DropUploadError) ...[
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Submit Button
                        _buildActions(state, isUploading),
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

  Widget _buildUploadProgress(DropUploadState state) {
    String label = 'Preparing video...';
    double? percent;

    if (state is DropUploadRequestingSignature) {
      label = 'Preparing video...';
    } else if (state is DropUploadProgress) {
      percent = state.progress;
      label = 'Uploading ${(percent * 100).toStringAsFixed(0)}%';
    } else if (state is DropUploadVerifying) {
      label = 'Verifying upload...';
    } else if (state is DropUploadPublishing) {
      label = 'Publishing Drop...';
    } else if (state is DropUploadRefreshing) {
      label = 'Refreshing profile and feed...';
    } else if (state is DropUploadSuccess) {
      percent = 1.0;
      label = 'Drop posted';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: percent,
          minHeight: 6,
          backgroundColor: Colors.white10,
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(DropUploadState state, bool isUploading) {
    if (state is DropUploadSuccess) {
      return ElevatedButton(
        onPressed: () => _finishUpload(state.drop),
        child: const Text('DONE'),
      );
    }

    if (state is DropUploadError) {
      final retryLabel = state.retryAction == DropUploadRetryAction.publish
          ? 'RETRY PUBLISH'
          : 'RETRY UPLOAD';
      final retryAction = state.retryAction == DropUploadRetryAction.publish
          ? context.read<DropUploadCubit>().retryPublish
          : context.read<DropUploadCubit>().retryUpload;
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _dismissUpload,
              child: const Text('CANCEL'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: retryAction,
              child: Text(retryLabel),
            ),
          ),
        ],
      );
    }

    if (isUploading) {
      return OutlinedButton(
        onPressed: () => context.read<DropUploadCubit>().cancel(),
        child: const Text('CANCEL'),
      );
    }

    return ElevatedButton(
      onPressed: _submit,
      child: const Text('PUBLISH DROP'),
    );
  }

  void _debugUploadScreen(String message) {
    if (kDebugMode) {
      debugPrint('[DropUploadScreen] $message');
    }
  }
}
