import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NeshanService {
  // کلید API خودت رو اینجا بذار
  // کلید API خود را از پنل نشان بگیرید و اینجا بگذارید
static const String apiKey = 'YOUR_NESHAN_API_KEY'; 

  // گرفتن آدرس از روی مختصات (Reverse Geocoding)
  static Future<String> getAddress(LatLng point) async {
    try {
      final url = Uri.parse('https://api.neshan.org/v5/reverse?lat=${point.latitude}&lng=${point.longitude}');
      final response = await http.get(url, headers: {'Api-Key': apiKey});

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        // سعی میکنیم آدرس دقیق رو دربیاریم
        return data['formatted_address'] ?? 'آدرس نامشخص';
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return 'آدرس یافت نشد';
  }

  // گرفتن نقاط مسیر برای رسم خط (Routing)
  static Future<List<LatLng>> getRoute(LatLng origin, LatLng dest) async {
    try {
      final url = Uri.parse(
          'https://api.neshan.org/v4/direction?type=car&origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}');

      final response = await http.get(url, headers: {'Api-Key': apiKey});

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final routes = data['routes'];
        if (routes != null && routes.isNotEmpty) {
          // دیکد کردن خط مسیر (Polyline)
          final overviewPolyline = routes[0]['overview_polyline']['points'];
          return _decodePolyline(overviewPolyline);
        }
      }
    } catch (e) {
      print('Error getting route: $e');
    }
    return [];
  }

  // تابع کمکی برای تبدیل کد نشان به لیست مختصات
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 100000.0, lng / 100000.0));
    }
    return points;
  }
}

