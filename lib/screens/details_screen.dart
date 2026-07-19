import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../models/watchlist_item.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class DetailsScreen extends StatefulWidget {
  final String mediaType;
  final String tmdbId;
  final String watchlistId;

  const DetailsScreen({
    super.key,
    required this.mediaType,
    required this.tmdbId,
    required this.watchlistId,
  });

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  String _resolvedMediaType = '';
  String _resolvedTmdbId = '';
  Map<String, dynamic>? _details;
  bool _isLoading = true;
  bool _isAlreadyInWatchlist = false;

  List<WatchlistItem> _watchlist = [];
  WatchlistItem? _savedItem;

  @override
  void initState() {
    super.initState();
    _resolvedMediaType = widget.mediaType;
    _resolvedTmdbId = widget.tmdbId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    _watchlist = await _storageService.loadWatchlist();

    // Find saved item if watchlistId is provided or by matching tmdbId
    if (widget.watchlistId.isNotEmpty) {
      try {
        _savedItem = _watchlist.firstWhere((x) => x.id == widget.watchlistId);
      } catch (_) {
        _savedItem = null;
      }
    } else if (_resolvedMediaType.isNotEmpty && _resolvedTmdbId.isNotEmpty) {
      try {
        _savedItem = _watchlist.firstWhere(
          (x) => x.mediaType == _resolvedMediaType && x.tmdbId == _resolvedTmdbId,
        );
      } catch (_) {
        _savedItem = null;
      }
    }

    // Resolve identity if details are missing but we have a saved item
    if ((_resolvedMediaType.isEmpty || _resolvedTmdbId.isEmpty) && _savedItem != null) {
      final identity = await _apiService.resolveIdentity(_savedItem!.title, _savedItem!.year);
      _resolvedMediaType = identity['media_type'] ?? '';
      _resolvedTmdbId = identity['tmdb_id'] ?? '';
    }

    if (_resolvedMediaType.isNotEmpty && _resolvedTmdbId.isNotEmpty) {
      _details = await _apiService.fetchDetails(_resolvedMediaType, _resolvedTmdbId);
    }

    // Fallback dictionary if API call fails
    if (_details == null && _savedItem != null) {
      _details = {
        'title': _savedItem!.title,
        'year': _savedItem!.year,
        'poster': _savedItem!.poster.isNotEmpty ? _savedItem!.poster : 'https://via.placeholder.com/300x450',
        'backdrop': '',
        'tagline': '',
        'overview': 'Could not fetch details from TMDB right now.',
        'vote_average': 0.0,
        'vote_count': 0,
        'popularity': 0.0,
        'release_date': '',
        'language': '',
        'genres': '',
        'runtime': '',
        'cast': [],
        'director': '',
        'creator_label': 'Director',
        'countries': [],
        'trailer_url': '',
        'tmdb_url': '',
        'recommendations': []
      };
    }

    _checkWatchlistStatus();

    setState(() {
      _isLoading = false;
    });
  }

  void _checkWatchlistStatus() {
    _isAlreadyInWatchlist = false;
    final title = _details != null ? (_details!['title'] ?? '') : (_savedItem?.title ?? '');
    final year = _details != null ? (_details!['year'] ?? '') : (_savedItem?.year ?? '');

    for (var item in _watchlist) {
      if (_resolvedMediaType.isNotEmpty && _resolvedTmdbId.isNotEmpty) {
        if (item.mediaType == _resolvedMediaType && item.tmdbId == _resolvedTmdbId) {
          _isAlreadyInWatchlist = true;
          break;
        }
      }
      if (item.title.trim().toLowerCase() == title.trim().toLowerCase() && item.year == year) {
        _isAlreadyInWatchlist = true;
        break;
      }
    }
  }

  Future<void> _addToWatchlist() async {
    final title = _details?['title'] ?? _savedItem?.title ?? '';
    final year = _details?['year'] ?? _savedItem?.year ?? '';
    final poster = _details?['poster'] ?? _savedItem?.poster ?? 'https://via.placeholder.com/300x450';

    if (title.isEmpty) return;

    final newItem = WatchlistItem(
      id: const Uuid().v4(),
      title: title,
      year: year,
      poster: poster,
      status: 'plan',
      mediaType: _resolvedMediaType,
      tmdbId: _resolvedTmdbId,
    );

    await _storageService.addToWatchlist(newItem);
    _watchlist = await _storageService.loadWatchlist();
    
    setState(() {
      _isAlreadyInWatchlist = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to watchlist')),
      );
    }
  }

  String? _extractYoutubeId(String url) {
    if (!url.contains('youtube.com') && !url.contains('youtu.be')) {
      return null;
    }
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      } else if (uri.path.contains('embed')) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
      } else {
        return uri.queryParameters['v'];
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _launchExternalUrl(String urlStr) async {
    if (urlStr.isEmpty) return;

    final youtubeId = _extractYoutubeId(urlStr);
    if (youtubeId != null) {
      final nativeYoutubeUri = Uri.parse('vnd.youtube:$youtubeId');
      try {
        final bool launchedNative = await launchUrl(
          nativeYoutubeUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
        if (launchedNative) return;
      } catch (_) {
        // Fall back to browser if native app launch fails
      }
    }

    final uri = Uri.parse(urlStr);
    try {
      final bool launchedApp = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (launchedApp) return;
    } catch (_) {
      // Fallback
    }

    try {
      final bool launchedBrowser = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launchedBrowser) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open: $urlStr')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18212F);
    final mutedTextColor = isDark ? const Color(0xFF888888) : const Color(0xFF5A6474);
    final cardBgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xFF242424) : const Color(0xFFE3E7EE);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
        ),
      );
    }

    if (_details == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: cardBgColor,
          elevation: 0.5,
          title: Text('Error', style: TextStyle(color: primaryTextColor)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: primaryTextColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Could not load details. Please verify your internet connection.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: mutedTextColor),
            ),
          ),
        ),
      );
    }

    final title = _details!['title'] ?? '';
    final year = _details!['year'] ?? '';
    final poster = _details!['poster'] ?? '';
    final tagline = _details!['tagline'] ?? '';
    final overview = _details!['overview'] ?? '';
    final rating = _details!['vote_average'] as double? ?? 0.0;
    final votes = _details!['vote_count'] as int? ?? 0;
    final runtime = _details!['runtime'] ?? '';
    final language = _details!['language'] ?? '';
    final releaseDate = _details!['release_date'] ?? '';
    final popularity = _details!['popularity'] as double? ?? 0.0;
    final genres = _details!['genres'] ?? '';
    final director = _details!['director'] ?? '';
    final creatorLabel = _details!['creator_label'] ?? 'Director';
    final List<dynamic> countriesList = _details!['countries'] ?? [];
    final countries = countriesList.join(', ');
    final trailerUrl = _details!['trailer_url'] ?? '';
    final tmdbUrl = _details!['tmdb_url'] ?? '';
    final List<dynamic> cast = _details!['cast'] ?? [];
    final List<dynamic> recommendations = _details!['recommendations'] ?? [];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back button / Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${year.isNotEmpty ? year : ''}${year.isNotEmpty && _resolvedMediaType.isNotEmpty ? ' • ' : ''}${_resolvedMediaType == 'movie' ? 'Movie' : 'TV Show'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: mutedTextColor,
                                ),
                              ),
                              if (tagline.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  tagline,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: mutedTextColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('Back', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: cardBgColor,
                            foregroundColor: primaryTextColor,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Details Card (Poster + Overview + Facts)
                    LayoutBuilder(builder: (context, constraints) {
                      final useTwoCols = constraints.maxWidth > 600;

                      final posterWidget = Align(
                        alignment: Alignment.centerLeft,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: poster,
                            width: useTwoCols ? 220 : 180,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: useTwoCols ? 220 : 180,
                              height: useTwoCols ? 330 : 270,
                              color: isDark ? const Color(0xFF161616) : const Color(0xFFEEF1F6),
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: useTwoCols ? 220 : 180,
                              height: useTwoCols ? 330 : 270,
                              color: isDark ? const Color(0xFF161616) : const Color(0xFFEEF1F6),
                              child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                            ),
                          ),
                        ),
                      );

                      final contentWidget = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Overview',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            overview,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Facts grid
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: useTwoCols ? 2.0 : 2.2,
                            children: [
                              _buildFactBlock('TMDB rating', '${rating.toStringAsFixed(1)} / 10'),
                              _buildFactBlock('Votes', '$votes'),
                              if (runtime.isNotEmpty) _buildFactBlock('Runtime', runtime),
                              if (language.isNotEmpty) _buildFactBlock('Language', language),
                              if (releaseDate.isNotEmpty) _buildFactBlock('Release date', releaseDate),
                              _buildFactBlock('Popularity', popularity.toStringAsFixed(0)),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Metadata list
                          if (genres.isNotEmpty) ...[
                            _buildMetaText('Genres', genres),
                            const SizedBox(height: 8),
                          ],
                          if (director.isNotEmpty) ...[
                            _buildMetaText(creatorLabel, director),
                            const SizedBox(height: 8),
                          ],
                          if (countries.isNotEmpty) ...[
                            _buildMetaText('Country', countries),
                            const SizedBox(height: 12),
                          ],

                          // Action Buttons Row
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isAlreadyInWatchlist ? null : _addToWatchlist,
                                icon: Icon(
                                  _isAlreadyInWatchlist ? Icons.check_rounded : Icons.add_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  _isAlreadyInWatchlist ? 'Already in watchlist' : 'Add to watchlist',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isAlreadyInWatchlist ? const Color(0xFFE4FAED) : const Color(0xFF2563EB),
                                  foregroundColor: _isAlreadyInWatchlist ? const Color(0xFF1F9A4F) : Colors.white,
                                  disabledBackgroundColor: const Color(0xFFE4FAED),
                                  disabledForegroundColor: const Color(0xFF1F9A4F),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: _isAlreadyInWatchlist
                                        ? const BorderSide(color: Color(0xFFC8E7D1), width: 1.2)
                                        : BorderSide.none,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  elevation: 0,
                                ),
                              ),
                              if (trailerUrl.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: () => _launchExternalUrl(trailerUrl),
                                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                  label: const Text('Watch Trailer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    elevation: 0,
                                  ),
                                ),
                              if (tmdbUrl.isNotEmpty)
                                OutlinedButton.icon(
                                  onPressed: () => _launchExternalUrl(tmdbUrl),
                                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                  label: const Text('Open on TMDB', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), width: 1.2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    backgroundColor: cardBgColor,
                                    foregroundColor: primaryTextColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          border: Border.all(color: cardBorderColor),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: useTwoCols
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  posterWidget,
                                  const SizedBox(width: 16),
                                  Expanded(child: contentWidget),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  posterWidget,
                                  const SizedBox(height: 16),
                                  contentWidget,
                                ],
                              ),
                      );
                    }),
                    const SizedBox(height: 20),

                    // Top Cast
                    if (cast.isNotEmpty) ...[
                      Text(
                        'Top Cast',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(builder: (context, constraints) {
                        final useFourCols = constraints.maxWidth > 600;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cast.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: useFourCols ? 4 : 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.58,
                          ),
                          itemBuilder: (context, index) {
                            final person = cast[index];
                            final name = person['name'] ?? '';
                            final character = person['character'] ?? '';
                            final photo = person['photo'] ?? '';

                            return Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                border: Border.all(color: cardBorderColor),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: photo.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: photo,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                color: isDark ? const Color(0xFF161616) : const Color(0xFFEEF1F6),
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(strokeWidth: 1.5),
                                                  ),
                                                ),
                                              ),
                                              errorWidget: (context, url, error) =>
                                                  _buildCastPlaceholder(),
                                            )
                                          : _buildCastPlaceholder(),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  if (character.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      character,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: mutedTextColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      }),
                      const SizedBox(height: 20),
                    ],

                    // Similar Picks
                    if (recommendations.isNotEmpty) ...[
                      Text(
                        'Similar Picks',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recommendations.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final rec = recommendations[index];
                          final recTitle = rec['title'] ?? '';
                          final recYear = rec['year'] ?? '';
                          final double ratingVal = rec['rating'] as double? ?? 0.0;
                          final recMediaType = rec['media_type'] ?? '';
                          final recTmdbId = rec['tmdb_id'] ?? '';

                          return InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => DetailsScreen(
                                    mediaType: recMediaType,
                                    tmdbId: recTmdbId,
                                    watchlistId: '',
                                  ),
                                ),
                              ).then((_) => _loadData());
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                border: Border.all(color: cardBorderColor),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            recTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                        ),
                                        if (recYear.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '($recYear)',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: mutedTextColor,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      ratingVal.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFactBlock(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18212F);
    final mutedTextColor = isDark ? const Color(0xFF888888) : const Color(0xFF5A6474);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: mutedTextColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaText(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18212F);
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, color: primaryTextColor, fontFamily: 'sans-serif'),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor),
          ),
          TextSpan(text: value, style: TextStyle(color: primaryTextColor)),
        ],
      ),
    );
  }

  Widget _buildCastPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF161616) : const Color(0xFFEEF1F6),
      child: Center(
        child: Text(
          'No photo',
          style: TextStyle(color: isDark ? const Color(0xFF888888) : const Color(0xFF5A6474), fontSize: 12),
        ),
      ),
    );
  }
}
