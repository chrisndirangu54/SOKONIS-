import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:grocerry/providers/user_provider.dart';
import 'package:grocerry/services/rider_location_service.dart';
import 'package:path_provider/path_provider.dart';


class TrackingScreen extends StatefulWidget {
  final String orderId;
  final RiderLocationService riderLocationService;
  final UserProvider userProvider;

  const TrackingScreen({
    super.key,
    required this.orderId,
    required this.riderLocationService,
    required this.userProvider,
  });

  @override
  TrackingScreenState createState() => TrackingScreenState();
}

class TrackingScreenState extends State<TrackingScreen> {
  Stream<LatLng>? _riderLocationStream;
  Set<Polyline> _polylines = {};
  final List<LatLng> _polylinePoints = [];
  StreamSubscription<LatLng>? _locationSubscription;
  LatLng? _currentDeviceLocation;
  LatLng? _userSelectedLocation;
  final bool _isLocationSelectedByUser = false;
  late LatLng pinLocation;
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    pinLocation = widget.userProvider.pinLocation!;
    _recorder = FlutterSoundRecorder();
    _initLocationService();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _recorder?.closeRecorder();
    _recorder = null;
    super.dispose();
  }

  void _initLocationService() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _promptEnableLocationServices();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      _currentDeviceLocation = await _getCurrentLocation();
      _startLocationStream();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<LatLng> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    return LatLng(position.latitude, position.longitude);
  }

  void _startLocationStream() {
    _riderLocationStream = widget.riderLocationService
        .getRiderLocationStream(LocationAccuracy.high)
        .map((Position position) =>
            LatLng(position.latitude, position.longitude));

    _locationSubscription = _riderLocationStream?.listen((location) {
      _updatePolyline(location);
      _checkProximityAndRecord(location);
    });
  }

  void _updatePolyline(LatLng newPoint) {
    setState(() {
      if (_polylinePoints.length > 100) {
        _polylinePoints.removeAt(0);
      }
      _polylinePoints.add(newPoint);
      _polylines = {
        Polyline(
          polylineId: const PolylineId('riderPath'),
          points: _polylinePoints,
          color: Colors.blue,
          width: 5,
        )
      };
    });
  }

  void _checkProximityAndRecord(LatLng riderLocation) async {
    LatLng targetLocation =
        _isLocationSelectedByUser ? _userSelectedLocation! : _currentDeviceLocation!;
    double distance = Geolocator.distanceBetween(
      targetLocation.latitude,
      targetLocation.longitude,
      riderLocation.latitude,
      riderLocation.longitude,
    );

    if (distance <= 10 && !_isRecording && widget.userProvider.currentUser?.isRider == true) {
      _startRecording();
    } else if (distance > 10 && _isRecording) {
      _stopRecordingAndAnalyze();
    }
  }

  Future<void> _startRecording() async {
    try {
      await _recorder?.openRecorder();
      await _recorder?.startRecorder(toFile: 'rider_audio.mp3');
      setState(() {
        _isRecording = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording started...')),
      );
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecordingAndAnalyze() async {
    try {
      String? localPath = await _recorder?.stopRecorder();
      await _recorder?.closeRecorder();
      if (localPath != null) {
        String downloadURL = await _getRecordingFilePath(widget.userProvider.currentUser?.id ?? 'anonymous');
        await _performSentimentAnalysis(downloadURL);
      }
      setState(() {
        _isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording stopped and analysis started.')),
      );
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<String> _getRecordingFilePath(String userId) async {
    final storage = firebase_storage.FirebaseStorage.instance;
    final firestore = FirebaseFirestore.instance;

    String fileName = '${DateTime.now().millisecondsSinceEpoch}.mp3';
    firebase_storage.Reference ref = storage.ref().child('rider_audio/$userId/$fileName');

    String localFilePath = await getApplicationDocumentsDirectory()
        .then((value) => '${value.path}/rider_audio.mp3');
    firebase_storage.UploadTask uploadTask = ref.putFile(File(localFilePath));

    firebase_storage.TaskSnapshot uploadSnapshot = await uploadTask;

    if (uploadSnapshot.state == firebase_storage.TaskState.success) {
      String downloadURL = await uploadSnapshot.ref.getDownloadURL();
      await firestore.collection('rider_audio').add({
        'userId': userId,
        'fileName': fileName,
        'downloadURL': downloadURL,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await File(localFilePath).delete();
      return downloadURL;
    } else {
      throw Exception('Failed to upload audio file');
    }
  }

  Future<void> _performSentimentAnalysis(String audioUrl) async {
    String text = await _convertAudioToText(audioUrl);
    if (text.isNotEmpty) {
      var sentimentAnalysis = await _analyzeSentimentWithChatGPT(text);
      var sabotageInsights = await _getInsightsWithChatGPT(text, 'sabotage');
      var defamationInsights = await _getInsightsWithChatGPT(text, 'defamation');
      await _storeAnalysisInFirebase(audioUrl, sentimentAnalysis, sabotageInsights, defamationInsights);
    }
  }

  Future<String> _convertAudioToText(String audioUrl) async {
    String apiKey = 'YOUR_API_KEY'; // Replace with your Google API key
    String url = 'https://speech.googleapis.com/v1/speech:recognize?key=$apiKey';

    var audioBytes = await http.get(Uri.parse(audioUrl)).then((response) => response.bodyBytes);
    var audioBase64 = base64Encode(audioBytes);

    var requestBody = jsonEncode({
      'config': {
        'encoding': 'LINEAR16',

        'sampleRateHertz': 16000,
        'languageCode': 'en-US',
        'enableAutomaticPunctuation': true,
        'maxAlternatives': 3,
      },
      'audio': {'content': audioBase64}
    });

    var response = await http.post(Uri.parse(url),
        headers: {"Content-Type": "application/json"}, body: requestBody);

    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      if (data['results'] != null && data['results'].isNotEmpty) {
        var firstResult = data['results'][0];
        if (firstResult['alternatives'] != null && firstResult['alternatives'].isNotEmpty) {
          return firstResult['alternatives'][0]['transcript'] as String;
        }
      }
      return '';
    } else {
      print('Failed to recognize speech: ${response.body}');
      return '';
    }
  }

  Future<String> _analyzeSentimentWithChatGPT(String text) async {
    const url = 'YOUR_CHATGPT_API_ENDPOINT'; // Replace with actual endpoint
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'model': 'gpt-4',
      'messages': [
        {'role': 'system', 'content': 'You are an AI that performs sentiment analysis.'},
        {'role': 'user', 'content': 'Analyze the sentiment of this text: $text'}
      ]
    });

    final response = await http.post(Uri.parse(url), headers: headers, body: body);
    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      return jsonResponse['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to analyze sentiment: ${response.reasonPhrase}');
    }
  }

  Future<String> _getInsightsWithChatGPT(String text, String topic) async {
    const url = 'YOUR_CHATGPT_API_ENDPOINT'; // Replace with actual endpoint
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'model': 'gpt-4',
      'messages': [
        {'role': 'system', 'content': 'You are an AI that provides insights on $topic.'},
        {'role': 'user', 'content': 'Provide insights on possible cases of $topic from this text: $text'}
      ]
    });

    final response = await http.post(Uri.parse(url), headers: headers, body: body);
    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      return jsonResponse['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to get insights on $topic: ${response.reasonPhrase}');
    }
  }

  Future<void> _storeAnalysisInFirebase(
      String audioPath, String sentimentAnalysis, String sabotageInsights, String defamationInsights) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('audio_analyses').add({
      'audioPath': audioPath,
      'sentimentAnalysis': sentimentAnalysis,
      'sabotageInsights': sabotageInsights,
      'defamationInsights': defamationInsights,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _promptEnableLocationServices() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enable Location Services'),
          content: const Text('Location services are disabled. Please enable them.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openLocationSettings();
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Rider'),
      ),
      body: (_currentDeviceLocation == null)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _isLocationSelectedByUser
                          ? _userSelectedLocation!
                          : _currentDeviceLocation!,
                      zoom: 15,
                    ),
                    polylines: _polylines,
                    markers: _buildMarkers(),
                  ),
                ),
              ],
            ),
    );
  }

  Set<Marker> _buildMarkers() {
    return {
      if (_userSelectedLocation != null)
        Marker(
          markerId: const MarkerId('userSelected'),
          position: _userSelectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Selected Location'),
        ),
      if (_polylinePoints.isNotEmpty)
        Marker(
          markerId: const MarkerId('rider'),
          position: _polylinePoints.last,
          infoWindow: const InfoWindow(title: 'Rider Location'),
        ),
      if (!_isLocationSelectedByUser &&
          _currentDeviceLocation != null &&
          widget.userProvider.pinLocation == null)
        Marker(
          markerId: const MarkerId('device'),
          position: _currentDeviceLocation!,
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
    };
  }
}