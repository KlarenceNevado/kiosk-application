import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class WeatherData {
  final double temperature;
  final String condition;
  final bool isDay;

  WeatherData({
    required this.temperature,
    required this.condition,
    this.isDay = true,
  });
}

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  // Coordinates for San Agustin, Batangas (Philippines)
  static const double lat = 13.7850;
  static const double lon = 121.0425;

  Future<WeatherData> fetchCurrentWeather() async {
    try {
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true');
      
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current_weather'];
        
        return WeatherData(
          temperature: (current['temperature'] as num).toDouble(),
          condition: _mapWeatherCode(current['weathercode']),
          isDay: current['is_day'] == 1,
        );
      }
    } catch (e) {
      debugPrint("⚠️ WeatherService: Failed to fetch weather: $e");
    }
    
    // Fallback Mock Data if offline or error
    return WeatherData(temperature: 29.0, condition: "Clear");
  }

  String _mapWeatherCode(int code) {
    if (code == 0) return "Clear";
    if (code >= 1 && code <= 3) return "Partly Cloudy";
    if (code >= 45 && code <= 48) return "Foggy";
    if (code >= 51 && code <= 67) return "Rainy";
    if (code >= 71 && code <= 77) return "Snowy";
    if (code >= 80 && code <= 99) return "Stormy";
    return "Cloudy";
  }
}
