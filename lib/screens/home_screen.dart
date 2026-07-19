import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/watchlist_item.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/server_settings_dialog.dart';
import 'login_screen.dart';
import 'details_screen.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  late PageController _pageController;
  Timer? _carouselTimer;
  bool _userInteractedWithCarousel = false;

  List<WatchlistItem> _watchlist = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  
  String _noticeMessage = '';
  String _noticeType = ''; // 'info', 'success', 'error'

  String _statusFilter = 'plan'; // 'all', 'plan', 'watched'
  int _currentIndex = 0;

  bool _isSyncing = false;
  List<Map<String, dynamic>> _trendingList = [];
  bool _isLoadingTrending = false;
  bool _hasFetchedTrendingThisSession = false;

  List<Map<String, dynamic>> _trendingTodayList = [];
  bool _isLoadingTrendingToday = false;
  bool _hasFetchedTrendingTodayThisSession = false;

  WatchlistItem? _lastDeletedItem;
  Timer? _undoTimer;
  bool _showUndoToast = false;
  final Set<String> _temporarilyDeletedIds = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _loadWatchlist();
    _initTrending();
    _initTrendingToday();
  }

  Future<void> _loadWatchlist({bool forceTrending = false}) async {
    final localList = await _storageService.loadWatchlistLocal();
    setState(() {
      _watchlist = localList;
    });
    _loadTrending(force: forceTrending);
    _loadTrendingToday(force: forceTrending);
    _performBackgroundSync();
  }

  Future<void> _initTrending() async {
    final cached = await _storageService.getCachedTrending();
    if (cached.isNotEmpty) {
      setState(() {
        _trendingList = cached;
      });
      _startCarouselTimer();
    }
    await _loadTrending(force: true);
  }

  Future<void> _loadTrending({bool force = false}) async {
    if (_hasFetchedTrendingThisSession && !force) return;

    final showLoadingSpinner = _trendingList.isEmpty;
    if (showLoadingSpinner) {
      setState(() {
        _isLoadingTrending = true;
      });
    }

    final list = await _apiService.fetchTrending();
    if (list.isNotEmpty) {
      await _storageService.saveCachedTrending(list);
      setState(() {
        _trendingList = list;
        _hasFetchedTrendingThisSession = true;
      });
      _startCarouselTimer();
    }

    if (showLoadingSpinner) {
      setState(() {
        _isLoadingTrending = false;
      });
    }
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    if (_trendingList.isEmpty || _userInteractedWithCarousel) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || _userInteractedWithCarousel || _trendingList.isEmpty) {
        timer.cancel();
        return;
      }
      if (_pageController.hasClients) {
        final nextPage = (_pageController.page?.round() ?? 0) + 1;
        if (nextPage < _trendingList.length) {
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
          );
        } else {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });
  }

  Future<void> _initTrendingToday() async {
    final cached = await _storageService.getCachedTrendingToday();
    if (cached.isNotEmpty) {
      setState(() {
        _trendingTodayList = cached;
      });
    }
    await _loadTrendingToday(force: true);
  }

  Future<void> _loadTrendingToday({bool force = false}) async {
    if (_hasFetchedTrendingTodayThisSession && !force) return;

    final showLoadingSpinner = _trendingTodayList.isEmpty;
    if (showLoadingSpinner) {
      setState(() {
        _isLoadingTrendingToday = true;
      });
    }

    final list = await _apiService.fetchTrendingToday();
    if (list.isNotEmpty) {
      await _storageService.saveCachedTrendingToday(list);
      setState(() {
        _trendingTodayList = list;
        _hasFetchedTrendingTodayThisSession = true;
      });
    }

    if (showLoadingSpinner) {
      setState(() {
        _isLoadingTrendingToday = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await _storageService.setLoggedIn(false);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _noticeMessage = 'Enter a movie or show title';
        _noticeType = 'error';
      });
      return;
    }


    setState(() {
      _isSearching = true;
      _noticeMessage = '';
    });

    final results = await _apiService.searchMulti(query);

    setState(() {
      _isSearching = false;
      if (results.isEmpty) {
        _searchResults = [];
        _noticeMessage = 'No results found';
        _noticeType = 'error';
      } else {
        _searchResults = results.take(12).toList();
        _noticeMessage = 'Found ${_searchResults.length} result(s)';
        _noticeType = 'info';
      }
    });
  }

  bool _isAlreadyInWatchlist(String title, String year, String mediaType, String tmdbId) {
    for (var item in _watchlist) {
      if (mediaType.isNotEmpty && tmdbId.isNotEmpty) {
        if (item.mediaType == mediaType && item.tmdbId == tmdbId) {
          return true;
        }
      }
      if (item.title.trim().toLowerCase() == title.trim().toLowerCase() && item.year == year) {
        return true;
      }
    }
    return false;
  }

  Future<void> _addToWatchlist(Map<String, dynamic> result) async {
    final title = result['title'] ?? '';
    final year = result['year'] ?? '';
    final poster = result['poster'] ?? 'https://via.placeholder.com/300x450';
    final mediaType = result['media_type'] ?? '';
    final tmdbId = result['tmdb_id'] ?? '';

    if (title.isEmpty) return;

    if (_isAlreadyInWatchlist(title, year, mediaType, tmdbId)) {
      setState(() {
        _noticeMessage = 'Already in your watchlist';
        _noticeType = 'info';
      });
      return;
    }

    final newItem = WatchlistItem(
      id: const Uuid().v4(),
      title: title,
      year: year,
      poster: poster,
      status: 'plan',
      mediaType: mediaType,
      tmdbId: tmdbId,
    );

    await _storageService.addToWatchlist(newItem);
    await _loadWatchlist();
    
    setState(() {
      _noticeMessage = 'Added to watchlist';
      _noticeType = 'success';
    });
  }

  Future<void> _toggleItemStatus(WatchlistItem item) async {
    final newStatus = item.status == 'plan' ? 'watched' : 'plan';
    await _storageService.toggleItemStatus(item, newStatus);
    await _loadWatchlist();
  }

  Future<void> _deleteItem(WatchlistItem item) async {
    // Commit any previous pending deletion immediately
    if (_lastDeletedItem != null) {
      _commitPendingDelete();
    }

    setState(() {
      _lastDeletedItem = item;
      _temporarilyDeletedIds.add(item.id);
      _showUndoToast = true;
    });

    _undoTimer = Timer(const Duration(seconds: 5), () {
      _commitPendingDelete();
    });
  }

  void _commitPendingDelete() {
    if (_lastDeletedItem == null) return;

    final itemToDelete = _lastDeletedItem!;
    _undoTimer?.cancel();
    _undoTimer = null;

    _storageService.deleteItem(itemToDelete.id).then((_) {
      if (mounted) {
        setState(() {
          _temporarilyDeletedIds.remove(itemToDelete.id);
          if (_lastDeletedItem?.id == itemToDelete.id) {
            _lastDeletedItem = null;
            _showUndoToast = false;
          }
        });
        _loadWatchlist();
      }
    });
  }

  void _undoDelete() {
    if (_lastDeletedItem == null) return;

    _undoTimer?.cancel();
    _undoTimer = null;

    setState(() {
      _temporarilyDeletedIds.remove(_lastDeletedItem!.id);
      _lastDeletedItem = null;
      _showUndoToast = false;
    });
    
    // Reload local list to restore card instantly
    _loadWatchlist();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _carouselTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _undoTimer?.cancel();
    if (_lastDeletedItem != null) {
      _storageService.deleteItem(_lastDeletedItem!.id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF121212) : Colors.white;

    // Filter out temporarily deleted items
    final visibleWatchlist = _watchlist.where((x) => !_temporarilyDeletedIds.contains(x.id)).toList();

    // Stats calculations
    final totalCount = visibleWatchlist.length;
    final watchedCount = visibleWatchlist.where((x) => x.status == 'watched').length;
    final planCount = totalCount - watchedCount;
    final completion = totalCount > 0 ? ((watchedCount / totalCount) * 100).toInt() : 0;

    // Filtered list (sorted newest first, reversing matches Flask[::-1])
    final reversedWatchlist = visibleWatchlist.reversed.toList();
    final filteredItems = _statusFilter == 'all'
        ? reversedWatchlist
        : reversedWatchlist.where((x) => x.status == _statusFilter).toList();

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _currentIndex = 0;
        });
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Stack(
                children: [
                  IndexedStack(
                    index: _currentIndex,
                    children: [
                      _buildWatchlistTab(filteredItems, totalCount, planCount, watchedCount, completion),
                      _buildSearchTab(),
                      _buildSettingsTab(),
                    ],
                  ),
                  if (_showUndoToast && _lastDeletedItem != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _buildUndoToast(),
                    ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: Container(
          color: cardBgColor,
          child: SafeArea(
            child: SizedBox(
              height: 72,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCustomTabItem(0, Icons.movie_rounded),
                        _buildCustomTabItem(1, Icons.search_rounded),
                        _buildCustomTabItem(2, Icons.settings_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTabItem(int index, IconData icon) {
    final bool isSelected = _currentIndex == index;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (index == 1 && _currentIndex == 1) {
            _searchFocusNode.requestFocus();
          }
          setState(() {
            _currentIndex = index;
          });
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            padding: const EdgeInsets.symmetric(vertical: 8),
            width: double.infinity,
            decoration: isSelected
                ? BoxDecoration(
                    color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFC4D7FF),
                    borderRadius: BorderRadius.circular(999),
                  )
                : BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
            child: Icon(
              icon,
              color: isSelected
                  ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF))
                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUndoToast() {
    final item = _lastDeletedItem!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color toastBgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final Color toastBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final Color textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final Color actionColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: toastBgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: toastBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: Text(
              'Deleted ${item.title}',
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _undoDelete,
            child: Text(
              'Undo',
              style: TextStyle(
                color: actionColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildNoticeBanner() {
    Color bgColor;
    Color borderColor;
    Color textColor;

    switch (_noticeType) {
      case 'success':
        bgColor = const Color(0xFFE4FAED);
        borderColor = const Color(0xFFCAE9D3);
        textColor = const Color(0xFF1F9A4F);
        break;
      case 'error':
        bgColor = const Color(0xFFFFE8E8);
        borderColor = const Color(0xFFF0C6C6);
        textColor = const Color(0xFFC73535);
        break;
      case 'info':
      default:
        bgColor = const Color(0xFFEFF6FF);
        borderColor = const Color(0xFFBFDBFE);
        textColor = const Color(0xFF2563EB);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _noticeMessage,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSearchResultsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18212F);
    final mutedTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF5A6474);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Search Results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _searchResults = [];
                  _searchController.clear();
                  _noticeMessage = '';
                });
              },
              icon: Icon(Icons.close_rounded, size: 18, color: mutedTextColor),
              label: Text(
                'Clear',
                style: TextStyle(color: mutedTextColor, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildItemsList(_searchResults),
      ],
    );
  }

  Widget _buildItemsList(List<Map<String, dynamic>> itemsList) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18212F);
    final mutedTextColor = isDark ? const Color(0xFF888888) : const Color(0xFF5A6474);
    final cardBgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xFF242424) : const Color(0xFFE3E7EE);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemsList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = itemsList[index];
        final title = item['title'] ?? '';
        final year = item['year'] ?? '';
        final poster = item['poster'] ?? '';
        final mediaType = item['media_type'] ?? '';
        final tmdbId = item['tmdb_id'] ?? '';

        final isAdded = _isAlreadyInWatchlist(title, year, mediaType, tmdbId);

        return Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cardBgColor,
            border: Border.all(color: cardBorderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 62,
                    child: CachedNetworkImage(
                      imageUrl: poster,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: isDark ? const Color(0xFF161616) : const Color(0xFFEEF1F6),
                        child: const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark ? const Color(0xFF161616) : const Color(0xFFEEF1F6),
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                          ),
                          if (year.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              year,
                              style: TextStyle(
                                fontSize: 13,
                                color: mutedTextColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mediaType == 'movie' ? 'Movie' : 'TV',
                        style: TextStyle(
                          fontSize: 13,
                          color: mutedTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Spacer(),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => DetailsScreen(
                                    mediaType: mediaType,
                                    tmdbId: tmdbId,
                                    watchlistId: '',
                                  ),
                                ),
                              ).then((_) => _loadWatchlist());
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              backgroundColor: cardBgColor,
                              foregroundColor: primaryTextColor,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            child: const Text('View details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: isAdded ? null : () => _addToWatchlist(item),
                            icon: Icon(
                              isAdded ? Icons.check_rounded : Icons.add_rounded,
                              size: 16,
                            ),
                            label: Text(
                              isAdded ? 'Already in watchlist' : 'Add to watchlist',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isAdded ? const Color(0xFFE4FAED) : const Color(0xFF2563EB),
                              foregroundColor: isAdded ? const Color(0xFF1F9A4F) : Colors.white,
                              disabledBackgroundColor: const Color(0xFFE4FAED),
                              disabledForegroundColor: const Color(0xFF1F9A4F),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: isAdded
                                    ? const BorderSide(color: Color(0xFFC8E7D1), width: 1.2)
                                    : BorderSide.none,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWatchlistSection(List<WatchlistItem> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18212F);
    final mutedTextColor = isDark ? const Color(0xFF888888) : const Color(0xFF5A6474);
    final cardBgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xFF242424) : const Color(0xFFE3E7EE);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section title + filters
        LayoutBuilder(builder: (context, constraints) {
          final wrapFilters = constraints.maxWidth < 450;
          final titleWidget = Text(
            'Your Watchlist',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          );

          final filtersWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterPill('All', 'all'),
              const SizedBox(width: 6),
              _buildFilterPill('Planned', 'plan'),
              const SizedBox(width: 6),
              _buildFilterPill('Watched', 'watched'),
            ],
          );

          if (wrapFilters) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleWidget,
                const SizedBox(height: 10),
                filtersWidget,
              ],
            );
          } else {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                titleWidget,
                filtersWidget,
              ],
            );
          }
        }),
        const SizedBox(height: 10),

        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : const Color(0xFFFBFCFE),
              border: Border.all(
                color: cardBorderColor,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Your list is empty. Search above to add your first title.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedTextColor,
                fontSize: 14,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];

              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => DetailsScreen(
                        mediaType: item.mediaType,
                        tmdbId: item.tmdbId,
                        watchlistId: item.id,
                      ),
                    ),
                  ).then((_) => _loadWatchlist());
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 112),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    border: Border.all(color: cardBorderColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 62,
                            child: CachedNetworkImage(
                              imageUrl: item.poster,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: isDark ? const Color(0xFF161616) : const Color(0xFFEEF1F6),
                                child: const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 1.5),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: isDark ? const Color(0xFF161616) : const Color(0xFFEEF1F6),
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ),
                                  if (item.year.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      item.year,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: mutedTextColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.status == 'watched' ? 'Watched' : 'Plan to watch',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: item.status == 'watched'
                                      ? const Color(0xFF1F9A4F)
                                      : mutedTextColor,
                                  fontWeight: item.status == 'watched'
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Spacer(),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _toggleItemStatus(item),
                                    icon: Icon(
                                      item.status == 'watched'
                                          ? Icons.bookmark_border_rounded
                                          : Icons.check_circle_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      item.status == 'watched'
                                          ? 'Mark as planned'
                                          : 'Mark as watched',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), width: 1.2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      backgroundColor: cardBgColor,
                                      foregroundColor: primaryTextColor,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _deleteItem(item),
                                    icon: const Icon(Icons.delete_rounded, size: 16),
                                    label: const Text('Delete', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFEDC7C7),
                                        width: 1.2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      backgroundColor: isDark
                                          ? const Color(0xFF450A0A).withValues(alpha: 0.4)
                                          : const Color(0xFFFFE8E8),
                                      foregroundColor: isDark
                                          ? const Color(0xFFFCA5A5)
                                          : const Color(0xFFC73535),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildFilterPill(String label, String value) {
    final isActive = _statusFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        setState(() {
          _statusFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
              : (isDark ? const Color(0xFF121212) : Colors.white),
          border: Border.all(
            color: isActive
                ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE))
                : (isDark ? const Color(0xFF242424) : const Color(0xFFE3E7EE)),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                : (isDark ? const Color(0xFF888888) : const Color(0xFF5A6474)),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildWatchlistTab(List<WatchlistItem> filteredItems, int totalCount, int planCount, int watchedCount, int completion) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18212F);
    final mutedTextColor = isDark ? const Color(0xFF888888) : const Color(0xFF5A6474);
    final cardBgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return RefreshIndicator(
      color: const Color(0xFF2563EB),
      backgroundColor: cardBgColor,
      onRefresh: () => _loadWatchlist(forceTrending: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header / Top section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Watchlist',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Simple tracker for movies and shows',
                    style: TextStyle(
                      fontSize: 14,
                      color: mutedTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Trending Carousel
              _buildTrendingCarousel(),
              const SizedBox(height: 24),

              // Watchlist Block
              _buildWatchlistSection(filteredItems),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18212F);
    final mutedTextColor = isDark ? const Color(0xFF888888) : const Color(0xFF5A6474);
    final cardBgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xFF242424) : const Color(0xFFE3E7EE);

    final searchInput = _searchController.text.trim();
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find movies and TV shows to add',
                  style: TextStyle(
                    fontSize: 14,
                    color: mutedTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search form
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      border: Border.all(color: cardBorderColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: mutedTextColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: (_) {},
                            style: TextStyle(color: primaryTextColor, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search movie or TV show',
                              hintStyle: TextStyle(
                                color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty || _searchResults.isNotEmpty || _noticeMessage.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.clear_rounded, color: mutedTextColor, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchResults = [];
                                _noticeMessage = '';
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _performSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    fixedSize: const Size.fromHeight(40),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Search',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Notice Message Banner
            if (_noticeMessage.isNotEmpty) ...[
              _buildNoticeBanner(),
              const SizedBox(height: 12),
            ],

            // Quick Add Directly Option (shows when search input has text)
            if (searchInput.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Add '$searchInput' directly",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Saves instantly. Syncs and fills details when online.",
                            style: TextStyle(
                              fontSize: 12,
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _addDirectlyByName(searchInput),
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Search Results Block
            if (_searchResults.isNotEmpty) ...[
              _buildSearchResultsSection(),
            ] else if (_searchController.text.trim().isEmpty) ...[
              _buildTrendingTodaySection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18212F);
    final mutedTextColor = isDark ? const Color(0xFF888888) : const Color(0xFF5A6474);
    final cardBgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xFF242424) : const Color(0xFFE3E7EE);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage account and connection configurations',
                  style: TextStyle(
                    fontSize: 14,
                    color: mutedTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Supabase Account Details Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBgColor,
                border: Border.all(color: cardBorderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_done_rounded, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        'Supabase Connection',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryTextColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Connected User:',
                    style: TextStyle(fontSize: 13, color: mutedTextColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Supabase.instance.client.auth.currentUser?.email ?? 'Offline Cache / Not Logged In',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryTextColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Syncing watchlist automatically to custom Supabase tables.',
                    style: TextStyle(fontSize: 13, color: mutedTextColor),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => showSupabaseSettingsDialog(context, () {
                        setState(() {});
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Configure Supabase Keys',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // TMDB API Settings Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBgColor,
                border: Border.all(color: cardBorderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.key_rounded, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        'TMDB API Settings',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryTextColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure your custom TMDB API Key to fetch movies and TV shows from the TMDB API.',
                    style: TextStyle(fontSize: 14, color: mutedTextColor),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => showApiKeyDialog(context, () {
                        setState(() {});
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Configure API Key',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Appearance (Theme Mode Selection) Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBgColor,
                border: Border.all(color: cardBorderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.palette_rounded, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        'Appearance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how the app theme looks on your device.',
                    style: TextStyle(
                      fontSize: 14,
                      color: mutedTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildThemeOption(context, 'Light', ThemeMode.light, Icons.light_mode_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildThemeOption(context, 'Dark', ThemeMode.dark, Icons.dark_mode_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildThemeOption(context, 'Device', ThemeMode.system, Icons.phone_android_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Account Actions Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBgColor,
                border: Border.all(color: cardBorderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_circle_rounded, color: mutedTextColor),
                      const SizedBox(width: 8),
                      Text(
                        'Account Actions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryTextColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: Icon(
                        Icons.logout_rounded,
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFC73535),
                      ),
                      label: Text(
                        'Logout',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFC73535),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFEDC7C7),
                          width: 1.2,
                        ),
                        backgroundColor: isDark
                            ? const Color(0xFF450A0A).withValues(alpha: 0.4)
                            : const Color(0xFFFFE8E8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addDirectlyByName(String name) async {
    if (name.isEmpty) return;

    final newItem = WatchlistItem(
      id: const Uuid().v4(),
      title: name,
      year: '',
      poster: 'https://images.unsplash.com/photo-1594909122845-11baa439b7bf?q=80&w=300&auto=format&fit=crop',
      status: 'plan',
      mediaType: 'movie',
      tmdbId: '', // Empty means added offline/manually
    );

    // Save item. The StorageService will try to save to server, or queue locally.
    await _storageService.addToWatchlist(newItem);
    
    // Clear search controller and results
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _noticeMessage = '';
      _currentIndex = 0; // Go to watchlist tab to see the item
    });

    await _loadWatchlist();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("'$name' added to your watchlist!"),
          backgroundColor: const Color(0xFF1F9A4F),
        ),
      );
    }
  }

  Future<void> _performBackgroundSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // Step 1: Sync pending mutations (add, update_status, delete)
      await _storageService.syncPendingActions();

      // Step 2: Fetch remote list from server to get fresh database state
      final freshList = await _storageService.loadWatchlist();

      // Step 3: Auto-enrich items lacking TMDB info
      final offlineItems = freshList.where((item) => item.tmdbId.isEmpty).toList();
      bool updatedAny = false;

      if (offlineItems.isNotEmpty) {
        for (var item in offlineItems) {
          try {
            final results = await _apiService.searchMulti(item.title);
            if (results.isNotEmpty) {
              final topResult = results.first;
              final enrichedItem = item.copyWith(
                id: const Uuid().v4(),
                title: topResult['title'] ?? item.title,
                year: topResult['year'] ?? '',
                poster: topResult['poster'] ?? 'https://images.unsplash.com/photo-1594909122845-11baa439b7bf?q=80&w=300&auto=format&fit=crop',
                mediaType: topResult['media_type'] ?? 'movie',
                tmdbId: (topResult['tmdb_id'] ?? '').toString(),
              );
              final success = await _storageService.addToWatchlist(enrichedItem);
              if (success) {
                await _storageService.deleteItem(item.id);
                updatedAny = true;
              }
            }
          } catch (_) {}
        }
      }

      // Sync once more if we added enriched items
      if (updatedAny) {
        await _storageService.syncPendingActions();
      }

      // Final load of fully synced/enriched database list
      final finalList = await _storageService.loadWatchlist();
      setState(() {
        _watchlist = finalList;
      });
    } catch (_) {}

    _isSyncing = false;
  }

  Widget _buildTrendingTodaySection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18212F);

    if (_isLoadingTrendingToday) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
        ),
      );
    }

    if (_trendingTodayList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up_rounded, color: Color(0xFF2563EB), size: 20),
            const SizedBox(width: 6),
            Text(
              'Trending Today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildItemsList(_trendingTodayList),
      ],
    );
  }

  Widget _buildTrendingCarousel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18212F);
    final cardBorderColor = isDark ? const Color(0xFF242424) : const Color(0xFFE3E7EE);
    final cardBgColor = isDark ? const Color(0xFF121212) : Colors.white;

    if (_isLoadingTrending) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: cardBgColor,
          border: Border.all(color: cardBorderColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
        ),
      );
    }

    if (_trendingList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.local_fire_department_rounded, color: Color(0xFF2563EB), size: 20),
            const SizedBox(width: 6),
            Text(
              'Trending This Week',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const Spacer(),
            Text(
              '${_trendingList.length} items',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF888888) : const Color(0xFF5A6474),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (notification is UserScrollNotification) {
                if (notification.direction != ScrollDirection.idle) {
                  setState(() {
                    _userInteractedWithCarousel = true;
                  });
                  _carouselTimer?.cancel();
                }
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: _trendingList.length,
              itemBuilder: (context, index) {
                final item = _trendingList[index];
                final backdrop = item['backdrop'] ?? '';
                final poster = item['poster'] ?? '';
                final title = item['title'] ?? '';
                final year = item['year'] ?? '';
                final vote = item['vote_average'] ?? 0.0;

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => DetailsScreen(
                            mediaType: item['media_type'] ?? 'movie',
                            tmdbId: item['tmdb_id'] ?? '',
                            watchlistId: '',
                          ),
                        ),
                      ).then((_) => _loadWatchlist());
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF18212F),
                          image: backdrop.isNotEmpty
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(backdrop),
                                  fit: BoxFit.cover,
                                )
                              : poster.isNotEmpty
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(poster),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: const [
                                      Color.fromRGBO(0, 0, 0, 0.0),
                                      Color.fromRGBO(0, 0, 0, 0.75),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color.fromRGBO(0, 0, 0, 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      vote is double ? vote.toStringAsFixed(1) : vote.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$year • ${(item['media_type'] == 'movie' ? 'Movie' : 'TV Show')}',
                                    style: const TextStyle(
                                      color: Color(0xFFE3E7EE),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption(BuildContext context, String label, ThemeMode mode, IconData icon) {
    final activeMode = MyApp.of(context).themeMode;
    final isSelected = activeMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => MyApp.of(context).changeTheme(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
              : (isDark ? const Color(0xFF121212) : Colors.white),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF242424) : const Color(0xFFE3E7EE)),
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : (isDark ? const Color(0xFF888888) : const Color(0xFF5A6474)),
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18212F)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
