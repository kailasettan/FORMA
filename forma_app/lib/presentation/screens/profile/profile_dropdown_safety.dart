import 'package:flutter/foundation.dart';

List<T> uniqueByDropdownId<T>(
  Iterable<T> items,
  String Function(T item) idOf, {
  String debugLabel = 'dropdown',
}) {
  final seen = <String>{};
  final unique = <T>[];

  for (final item in items) {
    final id = idOf(item);
    if (seen.add(id)) {
      unique.add(item);
    } else if (kDebugMode) {
      debugPrint('[$debugLabel] duplicate dropdown value ignored: $id');
    }
  }

  return unique;
}

String? safeDropdownValue<T>(
  String? selectedValue,
  Iterable<T> items,
  String Function(T item) valueOf, {
  String debugLabel = 'dropdown',
}) {
  if (selectedValue == null || selectedValue.isEmpty) return null;

  var matches = 0;
  for (final item in items) {
    if (valueOf(item) == selectedValue) {
      matches++;
    }
  }

  if (matches == 1) return selectedValue;

  if (kDebugMode) {
    debugPrint(
      '[$debugLabel] unsafe selected value ignored: '
      '$selectedValue matches=$matches',
    );
  }
  return null;
}
