import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'login_page.dart';
import 'register_page.dart';
import 'package:firebase_core/firebase_core.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

final initializationSettingsAndroid =
AndroidInitializationSettings('@mipmap/ic_launcher');

final initializationSettingsIOS = IOSInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    onDidReceiveLocalNotification:
        (int id, String? title, String? body, String? payload) async {});

final initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (context) => FoodItemProvider(),
      child: MyApp(),
    ),
  );
}

Future<void> scheduleNotification(FoodItem item, Duration preExpiryPeriod) async {
  if (item.expiryDate != null) {
    var scheduledNotificationDateTime =
    item.expiryDate!.subtract(preExpiryPeriod);

    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'your channel id',
        'your channel name',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: false
    );

    var iOSPlatformChannelSpecifics = IOSNotificationDetails();

    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.schedule(
        item.hashCode,
        'Expiry Reminder',
        '${item.name} is expiring soon!',
        scheduledNotificationDateTime,
        platformChannelSpecifics);
  }
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Waste App',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.lightBlue[800],
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Define the routes
      routes: {
        '/': (context) => HomePage(),
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
      },
      initialRoute: '/',
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white60,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
        ),

        title: Text('Food Waste App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddFoodItemScreen()),
                );
              },

              child: Text('Add Food Item'),

            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                // Scan expiry date
                DateTime? expiryDate = await scanExpiryDate();
                print('Scanned expiry date: $expiryDate');
              },
              child: Text('Scan Expiry Date'),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                // Scan barcode
                String barcode = await scanBarcode();
                print('Scanned barcode: $barcode');
              },
              child: Text('Scan Barcode'),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LocalFoodBanksPage()),
                );
              },
              child: Text('Local Food Banks'),
            ),
            SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => InformativeTipsPage()),
                );
              },
              child: Text('Informative Tips'),
            ),
          ],
        ),
      ),
    );
  }
}

class AddFoodItemScreen extends StatefulWidget {
  @override
  _AddFoodItemScreenState createState() => _AddFoodItemScreenState();
}
class LocalFoodBanksPage extends StatefulWidget {
  @override
  _LocalFoodBanksPageState createState() => _LocalFoodBanksPageState();
}


class _LocalFoodBanksPageState extends State<LocalFoodBanksPage> {
  Position? currentPosition;
  Set<Marker> markers = {};

  @override
  void initState() {
    super.initState();
    _getNearbyFoodBanks();
  }

  void _getNearbyFoodBanks() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    currentPosition = position;

    List<FoodBank> foodBanks = [
      FoodBank(name: 'Food Bank 1', latitude: 25.50, longitude: 55.50),
      FoodBank(name: 'Food Bank 2', latitude: 24.50, longitude: 54.50),
      FoodBank(name: "FOOD BANK3", latitude: 23.50, longitude: 55.128),
    ];

    markers.add(
      Marker(
        markerId: MarkerId('userLocation'),
        position: LatLng(currentPosition!.latitude, currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarker,
      ),
    );
    foodBanks.forEach((foodBank) {
      markers.add(
        Marker(
          markerId: MarkerId(foodBank.name),
          position: LatLng(foodBank.latitude, foodBank.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Local Food Banks'),
      ),
      body: (currentPosition == null)
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
          zoom: 13.0,
        ),
        markers: markers,
      ),
    );
  }
}

class FoodBank {
  final String name;
  final double latitude;
  final double longitude;

  FoodBank({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}


class _AddFoodItemScreenState extends State<AddFoodItemScreen> {
  String? selectedCategory;
  String name = '';
  double quantity = 0.0;
  DateTime? expiryDate;

  List<String> categories = ['Fruit', 'Vegetable', 'Meat', 'Dairy', 'Grain', 'Other'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Food Item'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Category'),
              value: selectedCategory,
              items: categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? value) {
                setState(() {
                  selectedCategory = value;
                });
              },
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Name'),
              onChanged: (value) {
                setState(() {
                  name = value;
                });
              },
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],
              onChanged: (value) {
                setState(() {
                  quantity = double.tryParse(value) ?? 0.0;
                });
              },
            ),
            GestureDetector(
              onTap: () async {
                DateTime? selectedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(Duration(days: 365)),
                );
                setState(() {
                  expiryDate = selectedDate;
                });
              },
              child: Text(
                expiryDate == null
                    ? 'Select Expiry Date'
                    : 'Expiry Date: ${expiryDate!.toString().split(' ')[0]}',
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Scan expiry date
                DateTime? scannedDate = await scanExpiryDate();
                setState(() {
                  expiryDate = scannedDate;
                });
              },
              child: Text('Scan Expiry Date'),
            ),
            SizedBox(height: 15),
            ElevatedButton(
              onPressed: () {
                _addFoodItem(selectedCategory, name, quantity, expiryDate);
              },
              child: Text('Add Food Item'),
            ),
          ],
        ),
      ),
    );
  }

  void _addFoodItem(String? category, String name, double quantity, DateTime? expiryDate) {
    FoodItem newItem = FoodItem(
      category: category,
      name: name,
      quantity: quantity,
      expiryDate: expiryDate,

    );

    Provider.of<FoodItemProvider>(context, listen: false).addItem(newItem);
    scheduleNotification(newItem, Duration(days: 3));

    Navigator.pop(context);


  }
}

class showfod extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Local Food Banks'),
      ),
      body: Consumer<FoodItemProvider>(
        builder: (context, foodItemProvider, child) {
          return ListView.builder(
            itemCount: foodItemProvider.items.length,
            itemBuilder: (context, index) {
              FoodItem item = foodItemProvider.items[index];
              return ListTile(
                title: Text(item.name),
                subtitle: Text('Category: ${item.category}\nQuantity: ${item.quantity}\nExpiry Date: ${item.expiryDate}'),
              );
            },
          );
        },
      ),
    );
  }
}

class InformativeTipsPage extends StatefulWidget {
  @override
  _InformativeTipsPageState createState() => _InformativeTipsPageState();
}

class _InformativeTipsPageState extends State<InformativeTipsPage> {
  late Future<List<String>> futureTips = Future.value([]);

  @override
  void initState() {
    super.initState();
    fetchTips();
  }

  Future<void> fetchTips() async {
    try {
      List<String> tips = await fetchAndPrintTips();
      setState(() {
        futureTips = Future.value(tips);
      });
    } catch (e) {
      print('Error fetching tips: $e');
      setState(() {
        futureTips = Future.error('Error fetching tips: $e');
      });
    }
  }

  Future<List<String>> fetchAndPrintTips() async {
    String apiKey = 'AIzaSyBtXDeujD8MIhE4jJODOBLiejs8J_DUcPY';

    final model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);

    final content = [Content.text('Give me 5 tips on how to save food waste.')];

    final response = await model.generateContent(content);

    List<String> tips = response.text != null ? response.text!.split('\n') : [];

    tips.removeWhere((tip) => tip.trim().isEmpty);

    tips = tips.map((tip) => tip.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (match) => '${match.group(1)}')).toList();

    print(tips);

    return tips.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Informative Tips'),
      ),
      body: FutureBuilder<List<String>>(
        future: futureTips,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasData) {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                List<String> parts = snapshot.data![index].split(':');
                String tip = parts[0].trim();
                String description = parts.length > 1 ? parts.sublist(1).join(':').trim() : '';

                return ListTile(
                  title: Text('Tip ${index + 1}'),
                  subtitle: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(text: tip, style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: ': $description'),
                      ],
                      style: DefaultTextStyle.of(context).style,
                    ),
                  ),
                );
              },
            );
          } else if (snapshot.hasError) {
            return Center(child: Text("${snapshot.error}"));
          } else {
            return Center(child: Text("No tips available."));
          }
        },
      ),
    );
  }
}

Future<DateTime?> scanExpiryDate() async {
  try {
    ScanResult result = await BarcodeScanner.scan();
    DateTime? expiryDate = DateTime.tryParse(result.rawContent);
    return expiryDate;
  } catch (e) {
    print('Error scanning expiry date: $e');
    return null;
  }
}

Future<String> scanBarcode() async {
  try {
    ScanResult result = await BarcodeScanner.scan();
    return result.rawContent;
  } catch (e) {
    print('Error scanning barcode: $e');
    return '';
  }
}
class FoodItem {
  final String? category;
  final String name;
  final double quantity;
  final DateTime? expiryDate;

  FoodItem({
    this.category,
    this.name = '',
    this.quantity = 0.0,
    this.expiryDate,
  });
}
class FoodItemProvider with ChangeNotifier {
  List<FoodItem> _items = [];

  List<FoodItem> get items => _items;

  void addItem(FoodItem item) {
    _items.add(item);
    notifyListeners();
  }
}