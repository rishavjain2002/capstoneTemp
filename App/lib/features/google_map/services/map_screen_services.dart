import 'dart:async';
import 'package:csv/csv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Add this import

class MapServices {
  GoogleMapController? controller;
  StreamSubscription<AccelerometerEvent>? accelerometerSubscription;
  LatLng? startLocation;
  LatLng? destLocation;
  List<AccelerometerEvent> accelerometerValues = [];
  String address = "";
  String prediction = "Unknown";
  List<Map<String, dynamic>> dataRecords = [];

  // Initialize position
  Future<Position> determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  // Start map
  Future<void> startMap() async {
    // Start accelerometer subscription here when the map is started
    accelerometerSubscription = accelerometerEventStream().listen((event) {
      accelerometerValues = [event];
      sendDataForPrediction(event);
    });

    Position position = await determinePosition();
    List<Placemark> placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    Placemark place = placemarks[0];
    startLocation = LatLng(position.latitude, position.longitude);
    address =
        "${place.name}, ${place.street}, ${place.locality}, ${place.subAdministrativeArea}, ${place.administrativeArea}, ${place.postalCode}, ${place.country}";

    if (controller != null) {
      controller!.animateCamera(CameraUpdate.newLatLng(startLocation!));
    }
  }

  // Send data for prediction
  Future<void> sendDataForPrediction(AccelerometerEvent event) async {
    final data = {
      'x': event.x,
      'y': event.y,
      'z': event.z,
    };

    try {
      var url = Uri.parse('http://10.0.2.2:5002/predict');
      var response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        String predictedLabel = responseData['label'];
        prediction = predictedLabel;

        // If the prediction is 'bump' or 'pothole', save the data
        if (predictedLabel == 'bump' || predictedLabel == 'pothole') {
          dataRecords.add({
            'x': event.x,
            'y': event.y,
            'z': event.z,
            'label': predictedLabel,
          });
        }
      } else {
        throw Exception('Failed to get prediction');
      }
    } catch (e) {
      print('Error during prediction: $e');
    }
  }

  // Stop the map and cancel the subscription
  void stopMap() async {
    startLocation = null;
    destLocation = null;
    address = "";
    prediction = "Unknown";

    accelerometerSubscription?.cancel(); // Stop accelerometer subscription
    if (controller != null) {
      controller!.animateCamera(
        CameraUpdate.newLatLng(const LatLng(28.6139, 77.2090)),
      );
    }

    if (dataRecords.isNotEmpty) {
      try {
        List<List<dynamic>> csvData = [
          ['x', 'y', 'z', 'label'],
          ...dataRecords.map((record) =>
              [record['x'], record['y'], record['z'], record['label']]),
        ];
        String csvString = const ListToCsvConverter().convert(csvData);
        print(csvString);

        var url = Uri.parse('http://10.0.2.2:5002/upload_csv');
        var response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'csv_data': csvString}),
        );

        if (response.statusCode == 200) {
          print('CSV uploaded successfully');
        } else {
          print('Error uploading CSV: ${response.body}');
        }
      } catch (e) {
        print('Error during CSV upload: $e');
      }
    }
  }

  // Set destination coordinates
  void setDestination(double? latitude, double? longitude) {
    if (latitude != null && longitude != null) {
      destLocation = LatLng(latitude, longitude);
      if (controller != null) {
        controller!.animateCamera(CameraUpdate.newLatLng(destLocation!));
      }
    } else {
      throw Exception('Invalid coordinates.');
    }
  }

  // Create markers for the map
  Set<Marker> createMarkers() {
    final markers = <Marker>{};
    if (startLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('startLocation'),
          icon: BitmapDescriptor.defaultMarker,
          position: startLocation!,
        ),
      );
    }
    if (destLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destLocation'),
          icon: BitmapDescriptor.defaultMarker,
          position: destLocation!,
        ),
      );
    }

    return markers;
  }
}
