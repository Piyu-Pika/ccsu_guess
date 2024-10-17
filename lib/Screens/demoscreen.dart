import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  String? imageBase64;
  LatLng? targetLocation;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  LatLng? markedLocation;
  int remainingTime = 30;
  Timer? timer;
  final mapController = MapController();
  double currentZoom = 15.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 18.0;
  late AnimationController _controller;
  late Animation<double> _animation;
  int currentScore = 0;
  int maxScore = 0;
  int consecutiveCorrect = 0;
  bool isGameOver = false;
  bool isLocationMarked = false;
  bool isLoading = true;
  int countDown = 3;
  Timer? countDownTimer;
  bool isRoundActive =
      false; // New flag to track if a round is currently active
  Set<String> usedImageIds = {}; // Track used image IDs to prevent repetition

  @override
  void initState() {
    super.initState();
    loadMaxScore();
    initializeGame();
  }

  Future<void> initializeGame() async {
    setState(() {
      isLoading = true;
      isRoundActive = false; // Reset round status
    });
    await loadRandomImage();
    startCountDown();
  }

  void startCountDown() {
    if (countDownTimer?.isActive ?? false) {
      countDownTimer?.cancel();
    }

    setState(() {
      countDown = 3;
    });

    countDownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (countDown > 1) {
          countDown--;
        } else {
          countDownTimer?.cancel();
          startGameTimer();
          setState(() {
            isLoading = false;
            isRoundActive = true; // Mark round as active
          });
        }
      });
    });
  }

  void startGameTimer() {
    if (timer?.isActive ?? false) {
      timer?.cancel();
    }

    _controller = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
    _animation = Tween(begin: 1.0, end: 0.0).animate(_controller)
      ..addListener(() {
        setState(() {});
      });
    _controller.forward();

    remainingTime = 30;
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime > 0) {
        setState(() {
          remainingTime--;
        });
      } else {
        timer.cancel();
        if (markedLocation == null && isRoundActive) {
          autoSubmit();
        } else if (isRoundActive) {
          calculateScore();
        }
      }
    });
  }

  Widget _buildZoomControls() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom In Button
          FloatingActionButton(
            heroTag: "zoomIn",
            onPressed: () {
              if (currentZoom < maxZoom) {
                setState(() {
                  currentZoom = (currentZoom + 1).clamp(minZoom, maxZoom);
                  mapController.move(mapController.camera.center, currentZoom);
                });
              }
            },
            mini: true,
            child: const Icon(Icons.add),
            backgroundColor: currentZoom < maxZoom
                ? Theme.of(context).primaryColor
                : Colors.grey,
          ),
          const SizedBox(height: 8),

          // Current Zoom Level Indicator
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              currentZoom.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Zoom Out Button
          FloatingActionButton(
            heroTag: "zoomOut",
            onPressed: () {
              if (currentZoom > minZoom) {
                setState(() {
                  currentZoom = (currentZoom - 1).clamp(minZoom, maxZoom);
                  mapController.move(mapController.camera.center, currentZoom);
                });
              }
            },
            mini: true,
            child: const Icon(Icons.remove),
            backgroundColor: currentZoom > minZoom
                ? Theme.of(context).primaryColor
                : Colors.grey,
          ),

          // Reset Zoom Button
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "resetZoom",
            onPressed: () {
              setState(() {
                currentZoom = 3.0; // Reset to initial zoom level
                mapController.move(
                  const LatLng(
                      28.969139, 77.740111), // Reset to initial position
                  currentZoom,
                );
              });
            },
            mini: true,
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  void markLocation(LatLng tappedPoint) {
    setState(() {
      markedLocation = tappedPoint;
      isLocationMarked = true;
    });
    print('Location marked: $markedLocation');
  }

  void submitGuess() {
    if (markedLocation != null) {
      calculateScore();
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Location Marked'),
          content: const Text(
              'Please mark a location on the map before submitting.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> loadMaxScore() async {
    User? user = _auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      maxScore = prefs.getInt('maxScore') ?? 0;
    });

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid)
        .get();
    print('User document fetched');
    if (userDoc.exists) {
      final firebaseMaxScore = userDoc.data()?['maxScore'] ?? 0;
      if (firebaseMaxScore > maxScore) {
        setState(() {
          maxScore = firebaseMaxScore;
        });
        await prefs.setInt('maxScore', maxScore);
        print('Max score updated from Firebase');
      }
    }
  }

  Future<void> updateMaxScore() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && currentScore > maxScore) {
        setState(() {
          maxScore = currentScore;
        });

        // Update both SharedPreferences and Firestore
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('maxScore', maxScore);

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'maxScore': maxScore,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error updating max score: $e');
    }
  }

  Future<void> loadRandomImage() async {
    try {
      final QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('images').get();

      if (querySnapshot.docs.isEmpty) {
        print('No images found in Firestore');
        return;
      }

      final availableDocs = querySnapshot.docs
          .where((doc) => !usedImageIds.contains(doc.id))
          .toList();

      if (availableDocs.isEmpty) {
        usedImageIds.clear();
        availableDocs.addAll(querySnapshot.docs);
      }

      final random = availableDocs[
          DateTime.now().microsecondsSinceEpoch % availableDocs.length];

      usedImageIds.add(random.id);

      final data = random.data() as Map<String, dynamic>;
      final base64Code = data['imageCode']; // Changed from 'url' to 'imageCode'

      if (base64Code != null) {
        setState(() {
          imageBase64 = base64Code;
        });
      }

      if (data['targetLocation'] != null) {
        print(data['targetLocation']);
        final GeoPoint geoPoint = data['targetLocation'];
        setState(() {
          targetLocation = LatLng(geoPoint.latitude, geoPoint.longitude);
        });
      }
    } catch (e) {
      print('Error loading random image: $e');
    }
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime > 0) {
        setState(() {
          remainingTime--;
        });
        print('Time left: $remainingTime');
      } else {
        timer.cancel();
        if (markedLocation == null) {
          autoSubmit();
        } else {
          calculateScore();
        }
      }
    });
  }

  void autoSubmit() {
    calculateScore();
    print('Auto-submitted');
  }

  void calculateScore() {
    if (!isRoundActive) return; // Prevent multiple score calculations

    setState(() {
      isRoundActive = false; // Mark round as inactive
    });

    if (targetLocation != null && markedLocation != null) {
      final distance = Geolocator.distanceBetween(
        targetLocation!.latitude,
        targetLocation!.longitude,
        markedLocation!.latitude,
        markedLocation!.longitude,
      );

      int roundScore = 0;
      if (distance < 10) {
        roundScore = 1000;
      } else if (distance < 100) {
        roundScore = 750;
      } else if (distance < 500) {
        roundScore = 500;
      } else if (distance < 1000) {
        roundScore = 250;
      } else {
        roundScore = 100;
      }

      setState(() {
        currentScore += roundScore;
        consecutiveCorrect++;
      });

      showResultDialog(roundScore, distance);
    } else {
      showResultDialog(0, null);
    }
  }

  void showResultDialog(int roundScore, double? distance) {
    if (isGameOver) return; // Prevent multiple dialogs

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: Text(roundScore > 0 ? 'Great job!' : 'Oops!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Score this round: $roundScore'),
              if (distance != null)
                Text('Distance: ${distance.toStringAsFixed(2)} meters'),
              Text('Total score: $currentScore'),
              Text('Consecutive correct: $consecutiveCorrect'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (roundScore > 0 && distance != null && distance < 1000) {
                  resetRound();
                } else {
                  endGame();
                }
              },
              child: Text(roundScore > 0 && distance != null && distance < 1000
                  ? 'Next Round'
                  : 'End Game'),
            ),
          ],
        ),
      ),
    );
  }

  void resetRound() {
    if (!mounted) return;

    setState(() {
      imageBase64 = null;
      targetLocation = null;
      markedLocation = null;
      isLocationMarked = false;
      remainingTime = 30;
      currentZoom = 3.0;
      isRoundActive = false;
    });

    // Cancel any existing timers
    timer?.cancel();
    _controller.reset();

    loadRandomImage().then((_) {
      if (mounted) {
        startCountDown();
      }
    });
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Play'),
        content: const Text(
          'Look at the image and try to guess its location on the map. '
          'Tap the map to mark your guess, then press the Submit button. '
          'The closer you are, the more points you\'ll earn! You have 30 seconds for each round.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void endGame() {
    setState(() {
      isGameOver = true;
    });
    updateMaxScore();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Final Score: $currentScore'),
            Text('Max Score: $maxScore'),
            Text('Consecutive Correct: $consecutiveCorrect'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              resetGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
    print('Game Over');
  }

  void resetGame() {
    setState(() {
      currentScore = 0;
      consecutiveCorrect = 0;
      isGameOver = false;
    });
    resetRound();
    print('Game reset');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Score: $currentScore | Max: $maxScore'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageBase64 != null && !isLoading)
                      Image.memory(
                        base64Decode(imageBase64!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text('Error loading image: $error'),
                          );
                        },
                      ),
                    if (!isLoading) _buildTimerOverlay(),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: _buildMap(),
              ),
              ElevatedButton(
                onPressed: isLocationMarked ? submitGuess : null,
                child: const Text('Submit Guess'),
              ),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Starting in...',
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                    Text(
                      '$countDown',
                      style: const TextStyle(color: Colors.white, fontSize: 48),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimerOverlay() {
    return Stack(
      children: [
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Time: $remainingTime',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: CircularProgressIndicator(
            value: _animation.value,
            backgroundColor: Colors.white.withOpacity(0.5),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
            strokeWidth: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: const LatLng(28.969139, 77.740111),
            initialZoom: currentZoom,
            onTap: (_, latlng) => markLocation(latlng),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
              tileProvider: CancellableNetworkTileProvider(),
            ),
            MarkerLayer(
              markers: _buildMarkers(),
            ),
          ],
        ),
        _buildZoomControls(),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (markedLocation != null) {
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: markedLocation!,
          child: const Icon(
            Icons.location_pin,
            color: Colors.red,
            size: 40,
          ),
        ),
      );
    }
    if (isGameOver && targetLocation != null) {
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: targetLocation!,
          child: const Icon(
            Icons.star,
            color: Colors.green,
            size: 40,
          ),
        ),
      );
    }
    return markers;
  }

  @override
  void dispose() {
    timer?.cancel();
    countDownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
