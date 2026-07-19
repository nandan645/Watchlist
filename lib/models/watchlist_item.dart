class WatchlistItem {
  final String id;
  final String title;
  final String year;
  final String poster;
  final String status; // "plan" or "watched"
  final String mediaType; // "movie" or "tv"
  final String tmdbId;

  WatchlistItem({
    required this.id,
    required this.title,
    required this.year,
    required this.poster,
    required this.status,
    required this.mediaType,
    required this.tmdbId,
  });

  WatchlistItem copyWith({
    String? id,
    String? title,
    String? year,
    String? poster,
    String? status,
    String? mediaType,
    String? tmdbId,
  }) {
    return WatchlistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      year: year ?? this.year,
      poster: poster ?? this.poster,
      status: status ?? this.status,
      mediaType: mediaType ?? this.mediaType,
      tmdbId: tmdbId ?? this.tmdbId,
    );
  }

  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    return WatchlistItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      year: json['year'] ?? '',
      poster: json['poster'] ?? '',
      status: json['status'] ?? 'plan',
      mediaType: json['media_type'] ?? '',
      tmdbId: json['tmdb_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'year': year,
      'poster': poster,
      'status': status,
      'media_type': mediaType,
      'tmdb_id': tmdbId,
    };
  }
}
