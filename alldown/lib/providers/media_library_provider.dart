import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_item.dart';
import '../models/local_playlist.dart';
import '../services/external_music_service.dart';
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
  final List<ExternalFolder> externalFolders;
  final List<MediaItem> externalTracks;
  final String searchQuery;
  final LibraryCategory selectedCategory;
  final bool isGridView;
  final LibrarySort sort;

  const LibraryState({
    required this.items,
    this.localPlaylists = const [],
    this.externalFolders = const [],
    this.externalTracks = const [],
    this.searchQuery = '',
    this.selectedCategory = LibraryCategory.all,
    this.isGridView = false,
    this.sort = LibrarySort.newest,
  });

  List<MediaItem> get allItems => [...items, ...externalTracks];

  List<LocalPlaylist> get allPlaylists {
    final folderPlaylists = externalFolders.map((f) {
      final tracks = externalTracks.where((t) => t.localPath.startsWith(f.uri)).toList();
      return LocalPlaylist(
        id: 'ext_pl_${f.uri.hashCode}',
        title: '📁 ${f.name}',
        createdAt: f.addedAt,
        trackIds: tracks.map((t) => t.id).toList(),
      );
    }).toList();
    return [...localPlaylists, ...folderPlaylists];
  }

  List<MediaItem> get filteredItems {
    var list = [...items, ...externalTracks];

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
    List<ExternalFolder>? externalFolders,
    List<MediaItem>? externalTracks,
    String? searchQuery,
    LibraryCategory? selectedCategory,
    bool? isGridView,
    LibrarySort? sort,
  }) {
    return LibraryState(
      items: items ?? this.items,
      localPlaylists: localPlaylists ?? this.localPlaylists,
      externalFolders: externalFolders ?? this.externalFolders,
      externalTracks: externalTracks ?? this.externalTracks,
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
          items: _initItemsWithFavorites(_storage),
          localPlaylists: _storage.loadLocalPlaylists(),
        )) {
    loadExternalMusic();
  }

  static List<MediaItem> _initItemsWithFavorites(dynamic storage) {
    try {
      final items = storage.loadLibrary() as List<MediaItem>;
      final favIds = (storage.loadFavoriteIds() as List<String>? ?? []).toSet();
      if (favIds.isEmpty) return items;
      return items.map((it) => favIds.contains(it.id) ? it.copyWith(isFavorite: true) : it).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> loadExternalMusic() async {
    try {
      final service = ExternalMusicService();
      final folders = await service.getSavedFolders();
      final tracks = await service.scanAllFolders();
      final favIds = (_storage.loadFavoriteIds() as List<String>? ?? []).toSet();
      final tracksWithFav = tracks.map((t) {
        if (favIds.contains(t.id)) {
          return t.copyWith(isFavorite: true);
        }
        return t;
      }).toList();

      if (mounted) {
        state = state.copyWith(
          externalFolders: folders,
          externalTracks: tracksWithFav,
        );
      }
    } catch (_) {}
  }

  Future<ExternalFolder?> pickAndAddExternalFolder() async {
    try {
      final service = ExternalMusicService();
      final folder = await service.pickAndAddFolder();
      if (folder != null) {
        await loadExternalMusic();
      }
      return folder;
    } catch (_) {
      return null;
    }
  }

  Future<void> removeExternalFolder(String uri) async {
    try {
      final service = ExternalMusicService();
      await service.removeFolder(uri);
      await loadExternalMusic();
    } catch (_) {}
  }

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
    var inItems = false;
    final updatedItems = state.items.map((item) {
      if (item.id == id) {
        inItems = true;
        return item.copyWith(isFavorite: !item.isFavorite);
      }
      return item;
    }).toList();

    final updatedExternal = state.externalTracks.map((item) {
      if (item.id == id) {
        return item.copyWith(isFavorite: !item.isFavorite);
      }
      return item;
    }).toList();

    state = state.copyWith(
      items: updatedItems,
      externalTracks: updatedExternal,
    );

    if (inItems) {
      _storage.saveLibrary(updatedItems);
    }

    final allFavIds = [...updatedItems, ...updatedExternal]
        .where((e) => e.isFavorite)
        .map((e) => e.id)
        .toList();
    _storage.saveFavoriteIds(allFavIds);
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

  void updatePlaylist(String id, {String? title, List<String>? trackIds}) {
    final updated = state.localPlaylists.map((pl) {
      if (pl.id == id) {
        return pl.copyWith(
          title: title ?? pl.title,
          trackIds: trackIds ?? pl.trackIds,
        );
      }
      return pl;
    }).toList();

    state = state.copyWith(localPlaylists: updated);
    _storage.saveLocalPlaylists(updated);
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

  void removeTrackFromAllPlaylists(String trackId) {
    final updated = state.localPlaylists.map((pl) {
      if (pl.trackIds.contains(trackId)) {
        return pl.copyWith(trackIds: pl.trackIds.where((t) => t != trackId).toList());
      }
      return pl;
    }).toList();
    state = state.copyWith(localPlaylists: updated);
    _storage.saveLocalPlaylists(updated);
  }

  Future<bool> renameTrack(MediaItem item, String newTitle) async {
    final clean = newTitle.trim();
    if (clean.isEmpty) return false;

    if (item.localPath.startsWith('content://')) {
      final newUri = await ExternalMusicService().renameExternalFile(item.localPath, clean);
      final updatedTracks = state.externalTracks.map((t) {
        if (t.id == item.id) {
          return t.copyWith(
            title: clean,
            localPath: (newUri != null && newUri.isNotEmpty) ? newUri : t.localPath,
          );
        }
        return t;
      }).toList();
      state = state.copyWith(externalTracks: updatedTracks);
      return true;
    } else {
      final updated = state.items.map((t) {
        if (t.id == item.id) {
          return t.copyWith(title: clean);
        }
        return t;
      }).toList();
      state = state.copyWith(items: updated);
      _storage.saveLibrary(updated);
      return true;
    }
  }

  Future<bool> deleteTrack(MediaItem item) async {
    if (item.localPath.startsWith('content://')) {
      final deleted = await ExternalMusicService().deleteExternalFile(item.localPath);
      if (deleted) {
        final updatedTracks = state.externalTracks.where((t) => t.id != item.id).toList();
        final updatedFolders = state.externalFolders.map((f) {
          if (item.localPath.startsWith(f.uri)) {
            final count = updatedTracks.where((t) => t.localPath.startsWith(f.uri)).length;
            return f.copyWith(trackCount: count);
          }
          return f;
        }).toList();
        state = state.copyWith(externalTracks: updatedTracks, externalFolders: updatedFolders);
        removeTrackFromAllPlaylists(item.id);
        return true;
      }
      return false;
    } else {
      try {
        final f = File(item.localPath);
        if (f.existsSync()) {
          f.deleteSync();
        }
      } catch (_) {}
      removeItem(item.id);
      return true;
    }
  }
}
