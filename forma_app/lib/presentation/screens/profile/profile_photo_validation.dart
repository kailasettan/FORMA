import 'dart:io';

const int maxProfilePhotoBytes = 5 * 1024 * 1024;
const String profilePhotoValidationMessage =
    'Please upload a JPG, PNG, or WebP image under 5 MB.';

Future<bool> isValidProfilePhotoFile(File file) async {
  if (!_hasAllowedProfilePhotoExtension(file.path)) return false;

  final length = await file.length();
  if (length <= 0 || length > maxProfilePhotoBytes) return false;

  final header = await file
      .openRead(0, 12)
      .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
  return _hasAllowedImageSignature(header);
}

bool hasAllowedProfilePhotoExtension(String path) {
  return _hasAllowedProfilePhotoExtension(path);
}

bool _hasAllowedProfilePhotoExtension(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp');
}

bool _hasAllowedImageSignature(List<int> header) {
  if (header.length >= 3 &&
      header[0] == 0xFF &&
      header[1] == 0xD8 &&
      header[2] == 0xFF) {
    return true;
  }

  if (header.length >= 8 &&
      header[0] == 0x89 &&
      header[1] == 0x50 &&
      header[2] == 0x4E &&
      header[3] == 0x47 &&
      header[4] == 0x0D &&
      header[5] == 0x0A &&
      header[6] == 0x1A &&
      header[7] == 0x0A) {
    return true;
  }

  if (header.length >= 12 &&
      header[0] == 0x52 &&
      header[1] == 0x49 &&
      header[2] == 0x46 &&
      header[3] == 0x46 &&
      header[8] == 0x57 &&
      header[9] == 0x45 &&
      header[10] == 0x42 &&
      header[11] == 0x50) {
    return true;
  }

  return false;
}
