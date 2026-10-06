import 'package:shared_preferences/shared_preferences.dart';

import '../models/movie_sort.dart';

class SortPreference {
  SortPreference({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const defaultSort = MovieSort.latest;
  static const _selectedSortKey = 'selected_sort';

  final SharedPreferencesAsync _preferences;

  Future<MovieSort> read() async {
    final name = await _preferences.getString(_selectedSortKey);
    return MovieSort.values.asNameMap()[name] ?? defaultSort;
  }

  Future<void> save(MovieSort sort) async {
    await _preferences.setString(_selectedSortKey, sort.name);
  }

  Future<void> clear() async {
    await _preferences.remove(_selectedSortKey);
  }
}
