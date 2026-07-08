import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/api_client.dart';
import '../../domain/entities/drop.dart';
import '../../domain/repositories/drop_repository.dart';

enum DropUploadStage {
  idle,
  preparing,
  requestingSignature,
  uploading,
  verifying,
  publishing,
  refreshing,
  success,
  failure,
}

abstract class DropUploadState extends Equatable {
  const DropUploadState();

  DropUploadStage get stage;
  bool get isActive => switch (stage) {
    DropUploadStage.preparing ||
    DropUploadStage.requestingSignature ||
    DropUploadStage.uploading ||
    DropUploadStage.verifying ||
    DropUploadStage.publishing ||
    DropUploadStage.refreshing => true,
    _ => false,
  };

  @override
  List<Object?> get props => [stage];
}

class DropUploadInitial extends DropUploadState {
  const DropUploadInitial();

  @override
  DropUploadStage get stage => DropUploadStage.idle;
}

class DropUploadPreparing extends DropUploadState {
  const DropUploadPreparing();

  @override
  DropUploadStage get stage => DropUploadStage.preparing;
}

class DropUploadRequestingSignature extends DropUploadState {
  const DropUploadRequestingSignature();

  @override
  DropUploadStage get stage => DropUploadStage.requestingSignature;
}

class DropUploadProgress extends DropUploadState {
  final double progress;
  const DropUploadProgress(this.progress);

  @override
  DropUploadStage get stage => DropUploadStage.uploading;

  @override
  List<Object?> get props => [stage, progress];
}

class DropUploadVerifying extends DropUploadState {
  const DropUploadVerifying();

  @override
  DropUploadStage get stage => DropUploadStage.verifying;
}

class DropUploadPublishing extends DropUploadState {
  const DropUploadPublishing();

  @override
  DropUploadStage get stage => DropUploadStage.publishing;
}

class DropUploadRefreshing extends DropUploadState {
  final Drop drop;
  const DropUploadRefreshing(this.drop);

  @override
  DropUploadStage get stage => DropUploadStage.refreshing;

  @override
  List<Object?> get props => [stage, drop];
}

class DropUploadSuccess extends DropUploadState {
  final Drop drop;
  final String? secondaryMessage;
  const DropUploadSuccess(this.drop, {this.secondaryMessage});

  @override
  DropUploadStage get stage => DropUploadStage.success;

  @override
  List<Object?> get props => [stage, drop, secondaryMessage];
}

enum DropUploadRetryAction { upload, publish }

class DropUploadError extends DropUploadState {
  final String message;
  final DropUploadRetryAction retryAction;
  const DropUploadError(this.message, {required this.retryAction});

  @override
  DropUploadStage get stage => DropUploadStage.failure;

  @override
  List<Object?> get props => [stage, message, retryAction];
}

class PendingDropPublish {
  final String providerAssetId;
  final String publicId;
  final String playbackUrl;
  final String? thumbnailUrl;
  final double durationSeconds;
  final int? width;
  final int? height;
  final String format;
  final int bytes;
  final String? sportId;
  final String? categoryId;
  final String? caption;
  final String visibility;
  final String? audience;
  final String? location;

  const PendingDropPublish({
    required this.providerAssetId,
    required this.publicId,
    required this.playbackUrl,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.width,
    required this.height,
    required this.format,
    required this.bytes,
    this.sportId,
    this.categoryId,
    this.caption,
    required this.visibility,
    this.audience,
    this.location,
  });
}

class DropUploadCubit extends Cubit<DropUploadState> {
  final DropRepository _dropRepository;

  XFile? _lastFile;
  String? _lastSportId;
  String? _lastCategoryId;
  String? _lastCaption;
  String? _lastVisibility;
  String? _lastAudience;
  String? _lastLocation;
  PendingDropPublish? _pendingPublish;
  int _operationId = 0;

  DropUploadCubit(this._dropRepository) : super(const DropUploadInitial());

  Future<void> uploadDrop({
    required XFile file,
    String? sportId,
    String? categoryId,
    String? caption,
    String? location,
    String? audience,
    required String visibility,
  }) async {
    if (state.isActive) return;
    _lastFile = file;
    _lastSportId = sportId;
    _lastCategoryId = categoryId;
    _lastCaption = caption;
    _lastVisibility = visibility;
    _lastAudience = audience;
    _lastLocation = location;
    _pendingPublish = null;
    final operationId = ++_operationId;

    try {
      _safeEmit(const DropUploadPreparing());
      _debugCheckpoint('preparing');

      _safeEmit(const DropUploadRequestingSignature());
      _debugCheckpoint('requesting signed upload');
      final signatureData = await _dropRepository.getUploadSignature();
      if (!_isCurrentOperation(operationId)) return;

      _safeEmit(const DropUploadProgress(0.0));
      _debugCheckpoint('uploading to cloudinary');
      final cloudinaryResponse = await _dropRepository.uploadToCloudinary(
        file: file,
        signatureData: signatureData,
        onProgress: (progress) {
          if (!_isCurrentOperation(operationId)) return;
          _safeEmit(DropUploadProgress(progress.clamp(0.0, 1.0)));
        },
      );
      if (!_isCurrentOperation(operationId)) return;

      _safeEmit(const DropUploadVerifying());
      _debugCheckpoint('verifying cloudinary response');
      _pendingPublish = _buildPendingPublish(
        cloudinaryResponse,
        sportId: sportId,
        categoryId: categoryId,
        caption: caption,
        visibility: visibility,
        audience: audience,
        location: location,
      );

      await _publishPending(operationId: operationId);
    } catch (e) {
      if (!_isCurrentOperation(operationId)) return;
      _debugCheckpoint('upload failed: ${_cleanError(e)}');
      _safeEmit(
        DropUploadError(
          _uploadMessageFor(e),
          retryAction: DropUploadRetryAction.upload,
        ),
      );
    }
  }

  Future<void> retryUpload() async {
    final file = _lastFile;
    final visibility = _lastVisibility;
    if (file == null || visibility == null) return;
    await uploadDrop(
      file: file,
      sportId: _lastSportId,
      categoryId: _lastCategoryId,
      caption: _lastCaption,
      location: _lastLocation,
      audience: _lastAudience,
      visibility: visibility,
    );
  }

  Future<void> retryPublish() async {
    if (state.isActive) return;
    await _publishPending(operationId: ++_operationId);
  }

  Future<void> _publishPending({required int operationId}) async {
    final pending = _pendingPublish;
    if (pending == null) return;

    try {
      _safeEmit(const DropUploadPublishing());
      _debugCheckpoint('creating drop');
      final drop = await _dropRepository.registerDrop(
        providerAssetId: pending.providerAssetId,
        publicId: pending.publicId,
        playbackUrl: pending.playbackUrl,
        thumbnailUrl: pending.thumbnailUrl,
        durationSeconds: pending.durationSeconds,
        width: pending.width,
        height: pending.height,
        format: pending.format,
        bytes: pending.bytes,
        sportId: pending.sportId,
        categoryId: pending.categoryId,
        caption: pending.caption,
        visibility: pending.visibility,
        audience: pending.audience,
        location: pending.location,
      );
      if (!_isCurrentOperation(operationId)) return;
      _debugCheckpoint('drop created');
      _pendingPublish = null;
      _safeEmit(DropUploadRefreshing(drop));
      _safeEmit(DropUploadSuccess(drop));
    } catch (e) {
      if (!_isCurrentOperation(operationId)) return;
      _debugCheckpoint('drop creation failed: ${_cleanError(e)}');
      _safeEmit(
        DropUploadError(
          _publishMessageFor(e),
          retryAction: DropUploadRetryAction.publish,
        ),
      );
    }
  }

  void markRefreshFailed(Drop drop) {
    _safeEmit(
      DropUploadSuccess(
        drop,
        secondaryMessage: 'Drop posted, but refresh failed. Pull to refresh.',
      ),
    );
  }

  void reset() {
    if (state.isActive) return;
    _operationId++;
    _pendingPublish = null;
    _safeEmit(const DropUploadInitial());
  }

  void cancel() {
    if (!state.isActive) return;
    _operationId++;
    _debugCheckpoint('upload cancelled');
    _safeEmit(
      const DropUploadError(
        'Upload cancelled.',
        retryAction: DropUploadRetryAction.upload,
      ),
    );
  }

  PendingDropPublish _buildPendingPublish(
    Map<String, dynamic> cloudinaryResponse, {
    required String? sportId,
    required String? categoryId,
    required String? caption,
    required String? location,
    required String? audience,
    required String visibility,
  }) {
    _validateCloudinaryResponse(cloudinaryResponse);
    final publicId = cloudinaryResponse['public_id'] as String;
    final playbackUrl = cloudinaryResponse['secure_url'] as String;
    final providerAssetId = cloudinaryResponse['asset_id'] as String;
    final duration = cloudinaryResponse['duration'] != null
        ? (cloudinaryResponse['duration'] as num).toDouble()
        : 0.0;
    final width = cloudinaryResponse['width'] as int?;
    final height = cloudinaryResponse['height'] as int?;
    final format = cloudinaryResponse['format'] as String;
    final bytes = cloudinaryResponse['bytes'] as int;

    final isImage = cloudinaryResponse['resource_type'] == 'image';
    final thumbnailUrl = isImage
        ? playbackUrl
        : playbackUrl.replaceAll(
            RegExp(r'\.(mp4|mov|webm)(\?.*)?$', caseSensitive: false),
            '.jpg',
          );

    return PendingDropPublish(
      providerAssetId: providerAssetId,
      publicId: publicId,
      playbackUrl: playbackUrl,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: duration,
      width: width,
      height: height,
      format: format,
      bytes: bytes,
      sportId: sportId,
      categoryId: categoryId,
      caption: caption,
      visibility: visibility,
      audience: audience,
      location: location,
    );
  }

  void _validateCloudinaryResponse(Map<String, dynamic> json) {
    final missingFields = <String>[];
    for (final field in [
      'asset_id',
      'public_id',
      'resource_type',
      'secure_url',
      'format',
      'bytes',
    ]) {
      if (json[field] == null) missingFields.add(field);
    }
    if (json['resource_type'] == 'video' && json['duration'] == null) {
      missingFields.add('duration');
    }
    if (missingFields.isNotEmpty) {
      throw Exception(
        'Cloudinary upload response was missing: ${missingFields.join(', ')}.',
      );
    }
    if (json['resource_type'] != 'video' && json['resource_type'] != 'image') {
      throw Exception(
        'Cloudinary rejected the upload: asset is not a video or image.',
      );
    }
  }

  String _uploadMessageFor(Object error) {
    final message = _cleanError(error);
    if (message.toLowerCase().contains('timed out')) {
      return 'Upload timed out. Check your connection and try again.';
    }
    if (message.toLowerCase().contains('cloudinary')) {
      return message;
    }
    return 'Couldn\'t prepare the upload. Try again.';
  }

  String _publishMessageFor(Object error) {
    final safeMessage = _cleanError(error);
    if (error is ApiException && safeMessage.trim().isNotEmpty) {
      return safeMessage;
    }
    return safeMessage.trim().isNotEmpty
        ? safeMessage
        : 'Video uploaded, but the Drop was not published.';
  }

  String _cleanError(Object error) {
    if (error is TimeoutException) {
      return 'Upload timed out. Check your connection and try again.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _safeEmit(DropUploadState nextState) {
    if (!isClosed) emit(nextState);
  }

  bool _isCurrentOperation(int operationId) {
    return !isClosed && operationId == _operationId;
  }

  void _debugCheckpoint(String checkpoint) {
    if (kDebugMode) {
      debugPrint('[DropUpload] $checkpoint');
    }
  }
}
