import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as intl;

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final currencyFormat = intl.NumberFormat("#,###", "en_US");

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تاریخچه سفرها'),
          centerTitle: true,
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<QuerySnapshot>(
          // کوئری: فقط سفرهای همین کاربر رو بیار، به ترتیب جدیدترین
          stream: FirebaseFirestore.instance
              .collection('trips')
              .where('user_id', isEqualTo: user?.uid)
              .orderBy('created_at', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_toggle_off, size: 80, color: Colors.grey),
                    SizedBox(height: 10),
                    Text('هنوز سفری انجام نشده!', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ),
              );
            }

            final trips = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index].data() as Map<String, dynamic>;
                final price = trip['price'] ?? 0;
                final driverName = trip['driver_name'] ?? 'نامشخص';
                final driverPlate = trip['driver_plate'] ?? '---';

                // مختصات برای نمایش در جزئیات
                final originLat = (trip['origin_lat'] as num).toStringAsFixed(4);
                final originLng = (trip['origin_lng'] as num).toStringAsFixed(4);
                final destLat = (trip['dest_lat'] as num).toStringAsFixed(4);
                final destLng = (trip['dest_lng'] as num).toStringAsFixed(4);

                final Timestamp? timestamp = trip['created_at'] as Timestamp?;
                final date = timestamp != null
                    ? intl.DateFormat('yyyy/MM/dd - HH:mm').format(timestamp.toDate())
                    : '---';

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green[100],
                      child: Icon(Icons.check, color: Colors.green[700]),
                    ),
                    title: Text('سفر با $driverName', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(date),
                    trailing: const Icon(Icons.chevron_left),

                    // 👇👇👇 اضافه شدن کلیک برای جزئیات 👇👇👇
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => Directionality(
                          textDirection: TextDirection.rtl,
                          child: AlertDialog(
                            title: const Text('جزئیات سفر', style: TextStyle(fontWeight: FontWeight.bold)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow(Icons.person, 'راننده:', driverName),
                                _buildDetailRow(Icons.directions_car, 'پلاک:', driverPlate),
                                _buildDetailRow(Icons.attach_money, 'هزینه:', '${currencyFormat.format(price)} تومان'),
                                const Divider(),
                                const Text('📍 مسیر:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 5),
                                Text('مبدا: $originLat, $originLng', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text('مقصد: $destLat, $destLng', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('بستن'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
            },

        ),
      ),
    );
  }
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text('$label ', style: const TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
