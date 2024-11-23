import 'package:cap_1/common/widgets/snackbar.dart';
import 'package:cap_1/common/widgets/dataContainer.dart';
import 'package:cap_1/features/google_map/services/map_screen_services.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapPageState();
}

class _MapPageState extends State<MapScreen> {
  final MapServices _mapServices = MapServices();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _mapServices.accelerometerSubscription?.cancel(); // Cancel subscription
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapServices.controller = controller;
  }

  void _startMap() async {
    try {
      await _mapServices.startMap(); // Start accelerometer data collection
      setState(() {}); // Trigger UI update once map has started
    } catch (e) {
      showSnackBar(context, e.toString());
    }
  }

  void _stopMap() {
    _mapServices.stopMap();
    setState(() {}); // Update UI when map is stopped
  }

  void _setDestination() {
    final double? latitude = double.tryParse(_latitudeController.text);
    final double? longitude = double.tryParse(_longitudeController.text);
    try {
      _mapServices.setDestination(latitude, longitude);
      setState(() {});
    } catch (e) {
      showSnackBar(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Map Center Screen'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Map Container
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2.0),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: _mapServices.startLocation != null
                  ? GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(28.6139, 77.2090),
                        zoom: 10,
                      ),
                      markers: _mapServices.createMarkers(),
                    )
                  : const Center(
                      child: Text(
                        'Map is stopped.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
            ),
          ),
          // Accelerometer Data and Prediction
          Padding(
            padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                buildDataContainer(
                    'X',
                    _mapServices.accelerometerValues.isNotEmpty
                        ? _mapServices.accelerometerValues[0].x
                        : 0),
                buildDataContainer(
                    'Y',
                    _mapServices.accelerometerValues.isNotEmpty
                        ? _mapServices.accelerometerValues[0].y
                        : 0),
                buildDataContainer(
                    'Z',
                    _mapServices.accelerometerValues.isNotEmpty
                        ? _mapServices.accelerometerValues[0].z
                        : 0),
              ],
            ),
          ),
          // Start/Stop Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _startMap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(200, 50),
                  ),
                  child: const Text('Start Driving'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _stopMap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(200, 50),
                  ),
                  child: const Text('Stop Driving'),
                ),
                const SizedBox(height: 20),
                Text(
                  'Prediction: ${_mapServices.prediction}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
