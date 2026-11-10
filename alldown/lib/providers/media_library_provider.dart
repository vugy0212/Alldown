import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_item.dart';
import 'settings_provider.dart';

enum LibraryCategory {
  all,
  videos,
  audio,
  playlists,
  favorites,
}

enum LibrarySort {
  newest,
  oldest,
  largest,
  title,
}

class LibraryState {
  final List<MediaItem> items;
  final String searchQuery;
  final LibraryCategory selectedCategory;
  final bool isGridView;
  final LibrarySort sort;

  const LibraryState({
    required this.items,
    this.searchQuery = '',
    this.selectedCategory = LibraryCategory.all,
    this.isGridView = false,
    this.sort = LibrarySort.newest,
  });

  List<MediaItem> get filteredItems {
    var list = items;

    // Search filter
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((item) =>
        item.title.toLowerCase().contains(q) ||
        item.channel.toLowerCase().contains(q) ||
        item.format.toLowerCase().contains(q)
      ).toList();
    }

    // Category filter
    switch (selectedCategory) {
      case LibraryCategory.videos:
        list = list.where((item) => !item.isAudio).toList();
        break;
      case LibraryCategory.audio:
        list = list.where((item) => item.isAudio).toList();
        break;
      case LibraryCategory.favorites:
        list = list.where((item) => item.isFavorite).toList();
        break;
      case LibraryCategory.playlists:
        list = list.where((item) => item.title.toLowerCase().contains('album') || item.title.toLowerCase().contains('playlist')).toList();
        break;
      case LibraryCategory.all:
        break;
    }

    return list;
  }

  LibraryState copyWith({
    List<MediaItem>? items,
    String? searchQuery,
    LibraryCategory? selectedCategory,
    bool? isGridView,
    LibrarySort? sort,
  }) {
    return LibraryState(
      items: items ?? this.items,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isGridView: isGridView ?? this.isGridView,
      sort: sort ?? this.sort,
    );
  }
}

final mediaLibraryProvider = StateNotifierProvider<MediaLibraryNotifier, LibraryState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return MediaLibraryNotifier(storage);
});

class MediaLibraryNotifier extends StateNotifier<LibraryState> {
  final dynamic _storage;

  MediaLibraryNotifier(this._storage)
      : super(LibraryState(items: _storage.loadLibrary()));

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCategory(LibraryCategory category) {
    state = state.copyWith(selectedCategory: category);
  }

  void toggleViewMode() {
    state = state.copyWith(isGridView: !state.isGridView);
  }

  void setSort(LibrarySort sort) {
    state = state.copyWith(sort: sort);
  }

  void toggleFavorite(String id) {
    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(isFavorite: !item.isFavorite);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updated);
    _storage.saveLibrary(updated);
  }

  void addItem(MediaItem item) {
    final updated = [item, ...state.items];
    state = state.copyWith(items: updated);
    _storage.saveLibrary(updated);
  }

  void removeItem(String id) {
    final updated = state.items.where((e) => e.id != id).toList();
    state = state.copyWith(items: updated);
    _storage.saveLibrary(updated);
  }
}

