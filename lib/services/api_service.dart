import 'dart:convert';
import 'package:http/http.dart' as http;
import 'settings.dart';


class ApiService {
  // baseUrl and imgBase are now provided by Settings.
  Future<List<Map<String, dynamic>>> searchMulti(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final String apiKey = await Settings.apiKey;
      final uri = Uri.parse('${Settings.baseUrl}/search/multi').replace(queryParameters: {
        'api_key': apiKey,
        'query': query.trim(),
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final List<dynamic> results = data['results'] ?? [];

      List<Map<String, dynamic>> searchResults = [];
      for (var item in results) {
        final mediaType = item['media_type'];
        if (mediaType != 'movie' && mediaType != 'tv') continue;
        final title = item['title'] ?? item['name'];
        if (title == null) continue;
        final releaseDate = item['release_date'] ?? item['first_air_date'] ?? '';
        final year = releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
        final posterPath = item['poster_path'];
        final poster = posterPath != null ? '${Settings.imgBase}$posterPath' : 'https://via.placeholder.com/300x450';
        searchResults.add({
          'title': title,
          'year': year,
          'poster': poster,
          'media_type': mediaType,
          'tmdb_id': item['id']?.toString() ?? '',
        });
      }
      return searchResults;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchDetails(String mediaType, String tmdbId) async {
    if ((mediaType != 'movie' && mediaType != 'tv') || tmdbId.isEmpty) return null;
    try {
      final String apiKey = await Settings.apiKey;
      final uri = Uri.parse('${Settings.baseUrl}/$mediaType/$tmdbId').replace(queryParameters: {
        'api_key': apiKey,
        'append_to_response': 'credits,videos,recommendations',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 7));
      if (response.statusCode != 200) return null;
      
      final data = jsonDecode(response.body);
      
      // Genres
      final List<dynamic> genresList = data['genres'] ?? [];
      final genres = genresList.map((g) => g['name']?.toString() ?? '').where((n) => n.isNotEmpty).join(', ');
      
      // Runtime
      String runtime = '';
      if (mediaType == 'movie') {
        final mins = data['runtime'];
        runtime = mins != null ? '$mins min' : '';
      } else {
        final List<dynamic> episodeRunTime = data['episode_run_time'] ?? [];
        if (episodeRunTime.isNotEmpty) {
          runtime = '~${episodeRunTime[0]} min/episode';
        }
      }
      
      // Cast
      final List<dynamic> castList = data['credits']?['cast'] ?? [];
      final List<Map<String, String>> cast = [];
      for (var c in castList.take(8)) {
        final name = c['name'] ?? '';
        if (name.isEmpty) continue;
        final profilePath = c['profile_path'];
        cast.add({
          'name': name,
          'character': c['character'] ?? '',
          'photo': profilePath != null ? '${Settings.imgBase}$profilePath' : '',
        });
      }
      
      // Director / Creator
      String director = '';
      String creatorLabel = 'Director';
      if (mediaType == 'movie') {
        final List<dynamic> crewList = data['credits']?['crew'] ?? [];
        for (var p in crewList) {
          if (p['job'] == 'Director' && p['name'] != null && p['name'].toString().isNotEmpty) {
            director = p['name'].toString();
            break;
          }
        }
      } else {
        final List<dynamic> createdBy = data['created_by'] ?? [];
        if (createdBy.isNotEmpty) {
          director = createdBy[0]['name'] ?? '';
        }
        creatorLabel = 'Creator';
      }
      
      // Trailer URL
      final List<dynamic> videos = data['videos']?['results'] ?? [];
      String trailerKey = '';
      for (var video in videos) {
        if (video['site'] == 'YouTube' && video['type'] == 'Trailer' && video['official'] == true) {
          trailerKey = video['key'] ?? '';
          break;
        }
      }
      if (trailerKey.isEmpty) {
        for (var video in videos) {
          if (video['site'] == 'YouTube' && video['type'] == 'Trailer') {
            trailerKey = video['key'] ?? '';
            break;
          }
        }
      }
      
      // Production countries
      final List<dynamic> productionCountries = data['production_countries'] ?? [];
      List<String> countries = [];
      for (var c in productionCountries) {
        if (c['name'] != null) countries.add(c['name']);
      }
      if (countries.isEmpty) {
        final List<dynamic> originCountry = data['origin_country'] ?? [];
        for (var c in originCountry) {
          if (c != null) countries.add(c.toString());
        }
      }
      
      // Recommendations
      final List<dynamic> recs = data['recommendations']?['results'] ?? [];
      List<Map<String, dynamic>> recommendations = [];
      for (var rec in recs.take(6)) {
        final recTitle = rec['title'] ?? rec['name'];
        if (recTitle == null) continue;
        final releaseDate = rec['release_date'] ?? rec['first_air_date'] ?? '';
        final recYear = releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
        recommendations.add({
          'title': recTitle,
          'year': recYear,
          'rating': rec['vote_average'] ?? 0.0,
          'media_type': mediaType,
          'tmdb_id': rec['id']?.toString() ?? '',
        });
      }
      
      final releaseDate = data['release_date'] ?? data['first_air_date'] ?? '';
      final backdropPath = data['backdrop_path'];
      
      return {
        'title': data['title'] ?? data['name'] ?? '',
        'year': releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '',
        'poster': data['poster_path'] != null ? '${Settings.imgBase}${data['poster_path']}' : 'https://via.placeholder.com/300x450',
        'backdrop': backdropPath != null ? 'https://image.tmdb.org/t/p/w1280$backdropPath' : '',
        'tagline': data['tagline'] ?? '',
        'overview': data['overview'] ?? 'No overview available.',
        'vote_average': data['vote_average'] ?? 0.0,
        'vote_count': data['vote_count'] ?? 0,
        'popularity': data['popularity'] ?? 0.0,
        'release_date': releaseDate,
        'language': (data['original_language'] ?? '').toString().toUpperCase(),
        'genres': genres,
        'runtime': runtime,
        'cast': cast,
        'director': director,
        'creator_label': creatorLabel,
        'countries': countries,
        'trailer_url': trailerKey.isNotEmpty ? 'https://www.youtube.com/watch?v=$trailerKey' : '',
        'tmdb_url': 'https://www.themoviedb.org/$mediaType/$tmdbId',
        'recommendations': recommendations
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> resolveIdentity(String title, String year) async {
    if (title.trim().isEmpty) return {'media_type': '', 'tmdb_id': ''};
    try {
      final String apiKey = await Settings.apiKey;
      final uri = Uri.parse('${Settings.baseUrl}/search/multi').replace(queryParameters: {
        'api_key': apiKey,
        'query': title.trim(),
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return {'media_type': '', 'tmdb_id': ''};
      
      final data = jsonDecode(response.body);
      final List<dynamic> results = data['results'] ?? [];
      
      final candidates = results.where((r) => (r['media_type'] == 'movie' || r['media_type'] == 'tv') && r['id'] != null).toList();
      if (candidates.isEmpty) return {'media_type': '', 'tmdb_id': ''};
      
      if (year.isNotEmpty) {
        for (var cand in candidates) {
          final relDate = cand['release_date'] ?? cand['first_air_date'] ?? '';
          final candYear = relDate.length >= 4 ? relDate.substring(0, 4) : '';
          if (candYear == year) {
            return {
              'media_type': cand['media_type']?.toString() ?? '',
              'tmdb_id': cand['id']?.toString() ?? '',
            };
          }
        }
      }
      
      final best = candidates[0];
      return {
        'media_type': best['media_type']?.toString() ?? '',
        'tmdb_id': best['id']?.toString() ?? '',
      };
    } catch (_) {
      return {'media_type': '', 'tmdb_id': ''};
    }
  }

  Future<List<Map<String, dynamic>>> fetchTrending() async {
    try {
      final String apiKey = await Settings.apiKey;
      final uri = Uri.parse('${Settings.baseUrl}/trending/all/week').replace(queryParameters: {
        'api_key': apiKey,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];
      
      final data = jsonDecode(response.body);
      final List<dynamic> results = data['results'] ?? [];
      
      List<Map<String, dynamic>> list = [];
      for (var item in results) {
        final mediaType = item['media_type'];
        if (mediaType != 'movie' && mediaType != 'tv') continue;
        
        final title = item['title'] ?? item['name'];
        if (title == null) continue;
        
        final releaseDate = item['release_date'] ?? item['first_air_date'] ?? '';
        final year = releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
        final backdropPath = item['backdrop_path'];
        final posterPath = item['poster_path'];
        
        list.add({
          'title': title,
          'year': year,
          'poster': posterPath != null ? '${Settings.imgBase}$posterPath' : 'https://images.unsplash.com/photo-1594909122845-11baa439b7bf?q=80&w=300&auto=format&fit=crop',
          'backdrop': backdropPath != null ? 'https://image.tmdb.org/t/p/w780$backdropPath' : '',
          'media_type': mediaType,
          'tmdb_id': item['id']?.toString() ?? '',
          'overview': item['overview'] ?? '',
          'vote_average': item['vote_average'] ?? 0.0,
        });
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchTrendingToday() async {
    try {
      final String apiKey = await Settings.apiKey;
      final uri = Uri.parse('${Settings.baseUrl}/trending/all/day').replace(queryParameters: {
        'api_key': apiKey,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      final List<dynamic> results = data['results'] ?? [];
      List<Map<String, dynamic>> list = [];
      for (var item in results) {
        final mediaType = item['media_type'];
        if (mediaType != 'movie' && mediaType != 'tv') continue;
        final title = item['title'] ?? item['name'];
        if (title == null) continue;
        final releaseDate = item['release_date'] ?? item['first_air_date'] ?? '';
        final year = releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
        final posterPath = item['poster_path'];
        list.add({
          'title': title,
          'year': year,
          'poster': posterPath != null ? '${Settings.imgBase}$posterPath' : 'https://images.unsplash.com/photo-1594909122845-11baa439b7bf?q=80&w=300&auto=format&fit=crop',
          'media_type': mediaType,
          'tmdb_id': item['id']?.toString() ?? '',
          'vote_average': item['vote_average'] ?? 0.0,
        });
      }
      return list;
    } catch (_) {
      return [];
    }
  }
}
