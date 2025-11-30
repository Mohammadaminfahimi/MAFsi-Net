import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // مختصات پیش‌فرض (قم)
  final LatLng _qomCenter = const LatLng(34.6416, 50.8746);
  final MapController _mapController = MapController();

  // کلید API مپ (حتما جایگزین کن)
  final String apiKey = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImp0aSI6ImYyYWIxYjZlZDQwOTE3OTczZDcwMDc4YWEwZmFiYjZiYjMzOGI0OWY5YjgzM2RiOGY2NjExNWNjODcxZWU3ZDdhZDRkN2ZjN2E3NDM5ZmUzIn0.eyJhdWQiOiIzNTU4MSIsImp0aSI6ImYyYWIxYjZlZDQwOTE3OTczZDcwMDc4YWEwZmFiYjZiYjMzOGI0OWY5YjgzM2RiOGY2NjExNWNjODcxZWU3ZDdhZDRkN2ZjN2E3NDM5ZmUzIiwiaWF0IjoxNzY0MjQyNzI2LCJuYmYiOjE3NjQyNDI3MjYsImV4cCI6MTc2Njc0ODMyNiwic3ViIjoiIiwic2NvcGVzIjpbImJhc2ljIl19.e_IuJ4EiCPub-9JUbE5uiw0FFswEPxg7h0TFngZJ_2RizWgKPnKmtGrvXS0D37V7CzVSIC2VYMuG6k7HfQC6uIZU5zkqprN9LW-pIvJFIG-zbiV28IxeL7jitwwaH9ZquU5fpcOJT7aGj0Dgejr90nyv3Ido_0qDIVi0owntbkOkpObZb7af_eiwKkSpEXpFW6kEIU8iwdAVzie0ZXhFdV1aLT0oxmV_CRtCh50qawG6SxTaTdDNH0egqNo2qGJZgQI0IUPAD5fIFSZpijwMbeTSPh-BCwudowP3CY87GNvN5JU4vn201Xh-Ukh8Z1VZ-6GBxc68qwrGQrlMT9BTng';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('انتخاب مبدا'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _qomCenter,
              initialZoom: 14.0,
            ),
            children: [
              // لایه نقشه Map.ir
              TileLayer(
                urlTemplate: "https://map.ir/shiveh/xyz/1.0.0/vec/light/{z}/{x}/{y}?x-api-key={apikey}",
                additionalOptions: {
                  'apikey': apiKey,
                },
                // هدرهای لازم برای Map.ir (گاهی لازمه)
                userAgentPackageName: 'com.example.qom_taxi',
              ),

              // نمایش لوگوی Map.ir (طبق قوانینشون باید باشه)
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'Map.ir',
                    onTap: null, // یا لینک به سایتشون
                  ),
                ],
              ),
            ],
          ),

          // پین وسط صفحه (برای انتخاب لوکیشن)
          const Center(
            child: Icon(
              Icons.location_on,
              size: 50,
              color: Colors.red,
            ),
          ),

          // دکمه تایید مبدا
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                // مختصات وسط صفحه رو میگیریم
                LatLng center = _mapController.camera.center;
                print("مختصات انتخاب شده: ${center.latitude}, ${center.longitude}");

                // اینجا بعداً میریم مرحله بعد (انتخاب مقصد)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('مبدا انتخاب شد: $center')),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.green,
              ),
              child: const Text(
                'تایید مبدا',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}