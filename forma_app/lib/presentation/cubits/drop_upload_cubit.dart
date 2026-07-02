import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/drop.dart';
import '../../domain/repositories/drop_repository.dart';

abstract class DropUploadState extends Equatable {
  const DropUploadState();
  @override
  List<Object?> get props => [];
}

class DropUploadInitial extends DropUploadState {}

class DropUploadLoading extends DropUploadState {}

class DropUploadProgress extends DropUploadState {
  final double progress;
  const DropUploadProgress(this.progress);

  @override
  List<Object?> get props => [progress];
}

class DropUploadRegistering extends DropUploadState {}

class DropUploadSuccess extends DropUploadState {
  final Drop drop;
  const DropUploadSuccess(this.drop);

  @override
  List<Object?> get props => [drop];
}

class DropUploadError extends DropUploadState {
  final String message;
  const DropUploadError(this.message);

  @override
  List<Object?> get props => [message];
}

class DropUploadCubit extends Cubit<DropUploadState> {
  final DropRepository _dropRepository;

  DropUploadCubit(this._dropRepository) : super(DropUploadInitial());

  Future<void> uploadDrop({
    required File file,
    required String sportId,
    String? categoryId,
    String? caption,
    required String visibility,
  }) async {
    try {
      emit(DropUploadLoading());

      // 1. Get Signature
      final signatureData = await _dropRepository.getUploadSignature();

      // 2. Upload to Cloudinary directly with progress
      emit(const DropUploadProgress(0.0));
      final cloudinaryResponse = await _dropRepository.uploadToCloudinary(
        file: file,
        signatureData: signatureData,
        onProgress: (progress) {
          emit(DropUploadProgress(progress));
        },
      );

      // 3. Register Drop on backend
      emit(DropUploadRegistering());
      
      final publicId = cloudinaryResponse['public_id'] as String;
      final playbackUrl = cloudinaryResponse['secure_url'] as String;
      final providerAssetId = cloudinaryResponse['asset_id'] as String? ?? publicId;
      final duration = (cloudinaryResponse['duration'] as num).toDouble();
      final width = cloudinaryResponse['width'] as int?;
      final height = cloudinaryResponse['height'] as int?;
      final format = cloudinaryResponse['format'] as String;
      final bytes = cloudinaryResponse['bytes'] as int;

      // Extract Cloudinary image thumbnail
      final String thumbnailUrl = playbackUrl.replaceAll(
        RegExp(r'\.(mp4|mov|webm)$'),
        '.jpg',
      );

      final drop = await _dropRepository.registerDrop(
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
      );

      emit(DropUploadSuccess(drop));
    } catch (e) {
      emit(DropUploadError(e.toString()));
    }
  }

  void reset() {
    emit(DropUploadInitial());
  }
}
