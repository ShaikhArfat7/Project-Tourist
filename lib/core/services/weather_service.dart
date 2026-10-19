import 'dart:convert';
import 'package:http/http.dart' as http;

class DailyForecastItem {
  final String date;
  final int weatherCode;
  final double maxTemp;
  final double minTemp;
  final double precipitationSum;

  DailyForecastItem({
    required this.date,
    required this.weatherCode,
    required this.maxTemp,
    required this.minTemp,
    required this.precipitationSum,
  });

  String get conditionDescription => WeatherService.getWeatherDescription(weatherCode);
}

class WeatherData {
  final String locationName;
  final double latitude;
  final double longitude;
  final DateTime observationTime;
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final double precipitation;
  final double windSpeed;
  final int weatherCode;
  final List<DailyForecastItem> dailyForecast;
  final bool isFromCache;

  WeatherData({
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.observationTime,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.weatherCode,
    required this.dailyForecast,
    this.isFromCache = false,
  });

  String get conditionDescription => WeatherService.getWeatherDescription(weatherCode);

  static const String disclaimer =
      'Weather information is provided solely for environmental awareness and tourist outdoor safety. '
      'Statistical caution: Weather does NOT predict, cause, or correlate with crime trends.';
}

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  final Map<String, _CachedWeather> _cache = {};
  static const Duration _cacheDuration = Duration(minutes: 15);

  /// Fetch weather for a given coordinate with caching
  Future<WeatherData> fetchWeather({
    required double latitude,
    required double longitude,
    required String locationName,
  }) async {
    final cacheKey = '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';
    final now = DateTime.now();

    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (now.difference(cached.timestamp) < _cacheDuration) {
        return cached.data;
      }
    }

    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum'
      '&timezone=auto',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final current = json['current'] as Map<String, dynamic>? ?? {};
        final daily = json['daily'] as Map<String, dynamic>? ?? {};

        final dailyItems = <DailyForecastItem>[];
        final times = (daily['time'] as List?)?.cast<String>() ?? [];
        final codes = (daily['weather_code'] as List?) ?? [];
        final maxTemps = (daily['temperature_2m_max'] as List?) ?? [];
        final minTemps = (daily['temperature_2m_min'] as List?) ?? [];
        final precips = (daily['precipitation_sum'] as List?) ?? [];

        for (int i = 0; i < times.length; i++) {
          dailyItems.add(DailyForecastItem(
            date: times[i],
            weatherCode: (i < codes.length) ? (codes[i] as num).toInt() : 0,
            maxTemp: (i < maxTemps.length) ? (maxTemps[i] as num).toDouble() : 0.0,
            minTemp: (i < minTemps.length) ? (minTemps[i] as num).toDouble() : 0.0,
            precipitationSum: (i < precips.length) ? (precips[i] as num).toDouble() : 0.0,
          ));
        }

        final weather = WeatherData(
          locationName: locationName,
          latitude: latitude,
          longitude: longitude,
          observationTime: DateTime.tryParse(current['time']?.toString() ?? '') ?? now,
          temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 0.0,
          apparentTemperature: (current['apparent_temperature'] as num?)?.toDouble() ?? 0.0,
          humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
          precipitation: (current['precipitation'] as num?)?.toDouble() ?? 0.0,
          windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
          weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
          dailyForecast: dailyItems,
          isFromCache: false,
        );

        _cache[cacheKey] = _CachedWeather(timestamp: now, data: weather);
        return weather;
      } else {
        throw Exception('Open-Meteo returned status ${response.statusCode}');
      }
    } catch (e) {
      if (_cache.containsKey(cacheKey)) {
        return _cache[cacheKey]!.data;
      }
      rethrow;
    }
  }

  static String getWeatherDescription(int code) {
    switch (code) {
      case 0:
        return 'Clear Sky';
      case 1:
        return 'Mainly Clear';
      case 2:
        return 'Partly Cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Fog / Depositing Rime Fog';
      case 51:
      case 53:
      case 55:
        return 'Drizzle (Light/Moderate/Dense)';
      case 61:
      case 63:
      case 65:
        return 'Rain (Slight/Moderate/Heavy)';
      case 71:
      case 73:
      case 75:
        return 'Snow Fall';
      case 80:
      case 81:
      case 82:
        return 'Rain Showers';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Fair / Variable';
    }
  }
}

class _CachedWeather {
  final DateTime timestamp;
  final WeatherData data;
  _CachedWeather({required this.timestamp, required this.data});
}
