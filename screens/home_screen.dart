import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:geolocator/geolocator.dart'; // مکان‌یابی
import 'dart:async';
import 'dart:math';
import 'profile_screen.dart';
import 'history_screen.dart';
import 'payment_screen.dart';
import '../services/neshan_service.dart'; // سرویس نشان

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum TripState { selectOrigin, selectDestination, confirmPrice, searching, tripStarted }

class Driver {
  final String name;
  final String carModel;
  final String plateNumber;
  final double rating;
  final String imageUrl;

  Driver(this.name, this.carModel, this.plateNumber, this.rating, this.imageUrl);
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();

  TripState _currentState = TripState.selectOrigin;
  LatLng? _origin;
  LatLng? _destination;
  int _price = 0;
  double _distanceKm = 0;
  int _durationMin = 0;

  String _originAddress = "در حال انتخاب...";
  String _destAddress = "در حال انتخاب...";
  List<LatLng> _routePoints = []; // نقاط خط مسیر

  Driver? _selectedDriver;

  final List<Driver> _fakeDrivers = [
    Driver('رضا پیشرو', 'پراید سفید', '۱۲ ب ۴۶', 4.8, 'https://cinematablo.ir/wp-content/uploads/2024/12/%D8%A8%D8%B1%D8%B1%D8%B3%DB%8C-%D8%B2%D9%86%D8%AF%DA%AF%DB%8C-%D9%88-%D8%A2%D8%AB%D8%A7%D8%B1-%D9%87%D9%86%D8%B1%DB%8C-%D9%BE%DB%8C%D8%B4%D8%B1%D9%88.webp'),
    Driver('محسن لرستانی', 'پژو ۴۰۵ شوتی', '۶۷ ج ۱۲۳', 4.5, 'https://nicmusic.net/wp-content/uploads/2016/04/photo_2022-01-03_20-16-39-500x500.jpg'),
    Driver('نجم الدین شریعتی', 'تیبا سفید', '۸۸ ط ۹۹۹', 4.9, 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRkxZLe9L5V1P6FZwV32q8vrIu9KNnRK1FgOR5knFgkxPQM3rGmXV7M-AlG-hUIx0nsONYyuYHYEkZXy_NoTKnUgsnH5ulsddoYmQEygKA&s=10'),
    // Driver('امید کریمی', 'سمند مشکی', '۳۳ د ۱۱۱', 4.2, 'https://i.pravatar.cc/150?img=13'),
    Driver('داریوش اقبالی', 'ساینا آبی', '۴۴ س ۵۵۵', 4.7, 'https://muzicgitars.com/wp-content/uploads/2025/08/dariush-ey-be.jpg'),
    Driver('شهرام شبپره', 'مزدا وانت', 'نامشخص', 3.1, 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQaQPcikHuk-5rBxSAKe_X23zdsq4ZbotHJptNN0Wfs4iY1AGxCfNDXJGGG577cJQBE1244dfVPw0g-SIxOxGuGGKD0wpS5oipLkA0dSJBn&s=10'),
    Driver('امیر تتلو', 'پژو پارس نوک مدادی', '۸۸ خ ۱۲۸', 5.0, 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRWlEJ9RXwcR93U0FzvWmxiiYKxTTkvZA0-2w0-0vc_EuHtKELFuBMKsIgJINMa9OR6ErY&usqp=CAU')
  ];

  DateTime? currentBackPressTime;
  final _currencyFormat = NumberFormat("#,###", "en_US");

  // مکان‌یابی کاربر
  Future<void> _locateUser() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لطفا GPS را روشن کنید')));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    final userLatLng = LatLng(position.latitude, position.longitude);

    _mapController.move(userLatLng, 15);
  }

  // دریافت آدرس از نشان
  Future<void> _updateAddress(LatLng point, bool isOrigin) async {
    setState(() {
      if (isOrigin) _originAddress = "در حال دریافت...";
      else _destAddress = "در حال دریافت...";
    });

    final address = await NeshanService.getAddress(point);

    if (mounted) {
      setState(() {
        if (isOrigin) _originAddress = address;
        else _destAddress = address;
      });
    }
  }

  // رسم مسیر
  Future<void> _drawRoute() async {
    if (_origin != null && _destination != null) {
      final points = await NeshanService.getRoute(_origin!, _destination!);
      if (mounted) {
        setState(() {
          _routePoints = points;
        });
      }
    }
  }

  void _calculateTripDetails() {
    final Distance distance = const Distance();
    double distanceMeters = distance.as(LengthUnit.Meter, _origin!, _destination!);
    _distanceKm = distanceMeters / 1000;
    _durationMin = ((_distanceKm * 2) + 5).round();

    double rawPrice = 12000 + (_distanceKm * 6000);
    _price = (rawPrice / 500).ceil() * 500;
    if (_price < 15000) _price = 15000;
  }

  void _startRequestProcess() {
    setState(() => _currentState = TripState.searching);
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _selectedDriver = _fakeDrivers[Random().nextInt(_fakeDrivers.length)];
        _submitTripToFirebase();
        setState(() => _currentState = TripState.tripStarted);
      }
    });
  }

  Future<void> _submitTripToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('trips').add({
      'user_id': user.uid,
      'origin_lat': _origin!.latitude,
      'origin_lng': _origin!.longitude,
      'dest_lat': _destination!.latitude,
      'dest_lng': _destination!.longitude,
      'origin_address': _originAddress,
      'dest_address': _destAddress,
      'price': _price,
      'distance': _distanceKm,
      'status': 'accepted',
      'driver_name': _selectedDriver!.name,
      'driver_plate': _selectedDriver!.plateNumber,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> _onWillPop() async {
    if (_currentState == TripState.tripStarted || _currentState == TripState.searching) {
      setState(() => _currentState = TripState.confirmPrice);
      return false;
    }
    if (_currentState == TripState.confirmPrice) {
      setState(() {
        _currentState = TripState.selectDestination;
        _destination = null;
        _routePoints = [];
      });
      return false;
    }
    if (_currentState == TripState.selectDestination) {
      setState(() {
        _currentState = TripState.selectOrigin;
        _origin = null;
      });
      return false;
    }
    if (_currentState == TripState.selectOrigin) {
      DateTime now = DateTime.now();
      if (currentBackPressTime == null ||
          now.difference(currentBackPressTime!) > const Duration(seconds: 2)) {
        currentBackPressTime = now;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('برای خروج دوباره بازگشت را بزنید'), duration: Duration(seconds: 2))
        );
        return false;
      }
      return true;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Text(
              _currentState == TripState.selectOrigin ? 'انتخاب مبدا'
                  : _currentState == TripState.selectDestination ? 'انتخاب مقصد'
                  : _currentState == TripState.searching ? 'در حال جستجو...'
                  : 'سفر فعال',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.person),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
              ),
            ],
          ),
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(34.6416, 50.8746),
                  initialZoom: 14.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    userAgentPackageName: 'com.example.qom_taxi',
                  ),

                  // خط مسیر (Polyline)
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 5.0,
                          color: Colors.blue,
                        ),
                      ],
                    ),

                  MarkerLayer(
                    markers: [
                      if (_origin != null)
                        Marker(
                          point: _origin!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.trip_origin, color: Colors.blue, size: 40),
                        ),
                      if (_destination != null)
                        Marker(
                          point: _destination!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.flag, color: Colors.red, size: 40),
                        ),
                      if (_currentState == TripState.tripStarted && _origin != null)
                        Marker(
                          point: LatLng(_origin!.latitude + 0.001, _origin!.longitude + 0.001),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.directions_car, color: Colors.black, size: 40),
                        ),
                    ],
                  ),
                ],
              ),

              // پین انتخابگر
              if (_currentState == TripState.selectOrigin || _currentState == TripState.selectDestination)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Icon(
                      Icons.location_pin,
                      size: 50,
                      color: _currentState == TripState.selectOrigin ? Colors.blue : Colors.red,
                    ),
                  ),
                ),

              // دکمه مکان‌یابی
              if (_currentState == TripState.selectOrigin || _currentState == TripState.selectDestination)
                Positioned(
                  bottom: 240, // بالاتر از پنل سفید
                  right: 20,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: _locateUser,
                    child: const Icon(Icons.my_location, color: Colors.black54),
                  ),
                ),

              // پنل پایین
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // نمایش آدرس‌ها
                      if (_currentState != TripState.searching && _currentState != TripState.tripStarted) ...[
                        if (_origin != null)
                          _AddressRow(icon: Icons.trip_origin, color: Colors.blue, text: _originAddress),
                        if (_currentState != TripState.selectOrigin) ...[
                          const Divider(height: 20),
                          _AddressRow(icon: Icons.flag, color: Colors.red, text: _currentState == TripState.selectDestination ? "نقشه را جابجا کنید..." : _destAddress),
                        ],
                        const SizedBox(height: 20),
                      ],

                      if (_currentState == TripState.confirmPrice) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _InfoBox(title: 'مسافت', value: '${_distanceKm.toStringAsFixed(1)} km'),
                            _InfoBox(title: 'زمان', value: '$_durationMin دقیقه'),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Center(
                          child: Text('هزینه سفر: ${_currencyFormat.format(_price)} تومان',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                        const SizedBox(height: 20),
                      ],

                      if (_currentState == TripState.searching) ...[
                        const Center(child: CircularProgressIndicator(color: Colors.green)),
                        const SizedBox(height: 15),
                        const Center(child: Text("در حال یافتن راننده...", style: TextStyle(fontSize: 16))),
                        const SizedBox(height: 20),
                      ],

                      if (_currentState == TripState.tripStarted && _selectedDriver != null) ...[
                        const Text("✅ راننده پیدا شد!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: NetworkImage(_selectedDriver!.imageUrl),
                              backgroundColor: Colors.grey[300],
                            ),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedDriver!.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('${_selectedDriver!.carModel} - ${_selectedDriver!.plateNumber}',
                                    style: const TextStyle(color: Colors.grey)),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    Text(' ${_selectedDriver!.rating}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                )
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: (){},
                              icon: const Icon(Icons.phone, color: Colors.green),
                              style: IconButton.styleFrom(backgroundColor: Colors.green.shade50),
                            )
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      if (_currentState != TripState.searching && _currentState != TripState.tripStarted)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              setState(() {
                                if (_currentState == TripState.selectOrigin) {
                                  _origin = _mapController.camera.center;
                                  _updateAddress(_origin!, true);
                                  _currentState = TripState.selectDestination;
                                } else if (_currentState == TripState.selectDestination) {
                                  _destination = _mapController.camera.center;
                                  _updateAddress(_destination!, false);
                                  _drawRoute();
                                  _calculateTripDetails();
                                  _currentState = TripState.confirmPrice;
                                } else if (_currentState == TripState.confirmPrice) {
                                  _startRequestProcess();
                                }
                              });
                            },
                            child: Text(
                              _currentState == TripState.selectOrigin ? 'تایید مبدا'
                                  : _currentState == TripState.selectDestination ? 'تایید مقصد'
                                  : 'درخواست راننده',
                              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                      if (_currentState == TripState.tripStarted) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PaymentScreen(price: _price),
                                ),
                              ).then((_) {
                                setState(() {
                                  _currentState = TripState.selectOrigin;
                                  _origin = null;
                                  _destination = null;
                                  _routePoints = [];
                                });
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text("پرداخت و پایان سفر", style: TextStyle(fontSize: 18, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _currentState = TripState.selectOrigin;
                                _origin = null;
                                _destination = null;
                                _routePoints = [];
                              });
                            },
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text("لغو سفر"),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ویجت نمایش آدرس
class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _AddressRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String value;
  const _InfoBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
