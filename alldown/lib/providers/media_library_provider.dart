import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_item.dart';
import '../models/local_playlist.dart';
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
  final List<LocalPlaylist> localPlaylists;
  final String searchQuery;
  final LibraryCategory selectedCategory;
  final bool isGridView;
  final LibrarySort sort;

  const LibraryState({
    required this.items,
    this.localPlaylists = const [],
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
        // Playlists category displays LocalPlaylist cards, but if needed filters items:
        list = list.where((item) => item.isAudio).toList();
        break;
      case LibraryCategory.all:
        break;
    }

    return list;
  }

  LibraryState copyWith({
    List<MediaItem>? items,
    List<LocalPlaylist>? localPlaylists,
    String? searchQuery,
    LibraryCategory? selectedCategory,
    bool? isGridView,
    LibrarySort? sort,
  }) {
    return LibraryState(
      items: items ?? this.items,
      localPlaylists: localPlaylists ?? this.localPlaylists,
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
      : super(LibraryState(
          items: _storage.loadLibrary(),
          localPlaylists: _storage.loadLocalPlaylists(),
        ));

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
    // Also remove reference from any local playlists
    final updatedPlaylists = state.localPlaylists.map((pl) {
      if (pl.trackIds.contains(id)) {
        return pl.copyWith(
          trackIds: pl.trackIds.where((tid) => tid != id).toList(),
        );
      }
      return pl;
    }).toList();

    state = state.copyWith(items: updated, localPlaylists: updatedPlaylists);
    _storage.saveLibrary(updated);
    _storage.saveLocalPlaylists(updatedPlaylists);
  }

  // Playlist management
  LocalPlaylist createPlaylist(String title, List<String> trackIds) {
    final newPlaylist = LocalPlaylist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'My Playlist' : title.trim(),
      createdAt: DateTime.now(),
      trackIds: trackIds,
    );

    final updated = [newPlaylist, ...state.localPlaylists];
    state = state.copyWith(localPlaylists: updated);
    _storage.saveLocalPlaylists(updated);
    return newPlaylist;
  }

  void deletePlaylist(String id) {
    final updated = state.localPlaylists.where((pl) => pl.id != id).toList();
    state = state.copyWith(localPlaylists: updated);
    _storage.saveLocalPlaylists(updated);
  }

  void addTracksToPlaylist(String id, List<String> trackIds) {
    final updated = state.localPlaylists.map((pl) {
      if (pl.id == id) {
        final merged = {...pl.trackIds, ...trackIds}.toList();
        return pl.copyWith(trackIds: merged);
      }
      return pl;
    }).toList();

    state = state.copyWith(localPlaylists: updated);
    _storage.saveLocalPlaylists(updated);
  }

  void removeTrackFromPlaylist(String id, String trackId) {
    final updated = state.localPlaylists.map((pl) {
      if (pl.id == id) {
        return pl.copyWith(
          trackIds: pl.trackIds.where((t) => t != trackId).toList(),
        );
      }
      return pl;
    }).toList();

    state = state.copyWith(localPlaylists: updated);
    _storage.saveLocalPlaylists(updated);
  }
}
