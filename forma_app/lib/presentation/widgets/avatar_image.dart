import 'package:flutter/material.dart';

String? validAvatarUrl(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  return trimmed;
}

ImageProvider? avatarImageProvider(String? value, {Object? cacheBust}) {
  final url = validAvatarUrl(value);
  if (url == null) return null;
  if (cacheBust == null) return NetworkImage(url);

  final uri = Uri.parse(url);
  final bustedUri = uri.replace(
    queryParameters: {...uri.queryParameters, 'v': cacheBust.toString()},
  );
  return NetworkImage(bustedUri.toString());
}
