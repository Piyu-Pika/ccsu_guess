import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:ccsu_guess/Screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/src/foundation/isolates.dart';
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
  List<Map<String, dynamic>> imageQueue = [];
  bool isNextImageLoading = false;
  Uint8List? nextDecodedImageBytes;
  String? nextImageBase64;
  LatLng? nextTargetLocation;
  LatLng? targetLocation;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  LatLng? markedLocation;
  int remainingTime = 30;
  Timer? timer;
  final mapController = MapController();
  double currentZoom = 15.0;
  static const double minZoom = 15.0;
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
  int currentLevel = 1;
  int imagesCompleted = 0;
  int timeForCurrentLevel = 30;
  bool showLevelUpOverlay = false;
  Timer? countDownTimer;
  bool isRoundActive = false;
  Set<String> usedImageIds = {};
  bool isFirstImageLoading = true;
  Uint8List? decodedImageBytes;

  @override
  void initState() {
    super.initState();
    loadMaxScore();
    initializeGame();
    _preloadFirstImage();
  }

  Future<void> initializeGame() async {
    setState(() {
      isLoading = true;
      isRoundActive = false; // Reset round status
    });
    await loadRandomImage();
    startCountDown();
  }

  Future<void> _preloadFirstImage() async {
    try {
      setState(() {
        isFirstImageLoading = true;
      });

      // Get cached image from SharedPreferences if available
      final prefs = await SharedPreferences.getInstance();
      final cachedFirstImageId = prefs.getString('lastImageId');
      final cachedFirstImage = prefs.getString('lastImageData');

      if (cachedFirstImage != null && cachedFirstImageId != null) {
        // Use cached image immediately while loading fresh one
        setState(() {
          imageBase64 = cachedFirstImage;
          isFirstImageLoading = false;
        });
      }

      // Load fresh image from Firestore
      final QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('images').limit(1).get();

      if (querySnapshot.docs.isEmpty) {
        print('No images found in Firestore');
        return;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      final base64Code = data['imageCode'];

      if (base64Code != null) {
        final bytes = await compute(
            base64Decode as ComputeCallback<dynamic, Uint8List>, base64Code);

        await prefs.setString('lastImageId', doc.id);
        await prefs.setString('lastImageData', base64Code);

        if (!mounted) return;

        setState(() {
          imageBase64 = base64Code;
          decodedImageBytes = bytes;
          isFirstImageLoading = false;
        });

        // Pre-cache the image for smoother display
        await precacheImage(MemoryImage(bytes), context);

        if (data['targetLocation'] != null) {
          final GeoPoint geoPoint = data['targetLocation'];
          setState(() {
            targetLocation = LatLng(geoPoint.latitude, geoPoint.longitude);
          });
        }

        // Add to used images after successful load
        usedImageIds.add(doc.id);
        loadRandomImage();
      }
    } catch (e) {
      print('Error loading first image: $e');
      setState(() {
        isFirstImageLoading = false;
      });
    }
  }

  void _handleBackButton() async {
    final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Game?'),
            content: const Text(
                'Are you sure you want to exit? Your current progress will be saved.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Exit'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldExit && mounted) {
      await updateMaxScore();
      Navigator.of(context).pop();
    }
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

  void updateTimeForLevel() {
    if (imagesCompleted < 10) {
      timeForCurrentLevel = 30;
      currentLevel = 1;
    } else if (imagesCompleted < 20) {
      timeForCurrentLevel = 20;
      currentLevel = 2;
    } else {
      timeForCurrentLevel = 10;
      currentLevel = 3;
    }
  }

  void startGameTimer() {
    if (timer?.isActive ?? false) {
      timer?.cancel();
    }

    _controller = AnimationController(
      duration: Duration(seconds: timeForCurrentLevel),
      vsync: this,
    );
    _animation = Tween(begin: 1.0, end: 0.0).animate(_controller)
      ..addListener(() {
        setState(() {});
      });
    _controller.forward();

    remainingTime = timeForCurrentLevel;
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
                currentZoom = 15.0; // Reset to initial zoom level
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
      resetRound();
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
      // If we have a preloaded next image, use that immediately
      if (nextImageBase64 != null) {
        setState(() {
          imageBase64 = nextImageBase64;
          decodedImageBytes = nextDecodedImageBytes;
          targetLocation = nextTargetLocation;
          nextImageBase64 = null;
          nextDecodedImageBytes = null;
          nextTargetLocation = null;
        });

        // Preload the next image in the background
        _preloadNextImage();
        return;
      }

      // If we have images in queue, select a random one instead of the first
      if (imageQueue.isNotEmpty) {
        final randomIndex = Random().nextInt(imageQueue.length);
        final nextImage = imageQueue.removeAt(randomIndex);
        _processImageData(nextImage);

        // Preload the next image in the background
        _preloadNextImage();
        return;
      }

      // Otherwise load fresh from Firestore
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('images')
          .where(FieldPath.documentId,
              whereNotIn: usedImageIds.isEmpty ? null : usedImageIds.toList())
          .limit(20) // Increased limit to get more images for random selection
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('No images found in Firestore');
        // If no images left, reset used images and try again
        usedImageIds.clear();
        loadRandomImage();
        return;
      }

      // Add all new images to our queue
      for (var doc in querySnapshot.docs) {
        if (!usedImageIds.contains(doc.id)) {
          imageQueue
              .add({'id': doc.id, 'data': doc.data() as Map<String, dynamic>});
        }
      }

      // Shuffle the queue to ensure randomness
      imageQueue.shuffle();

      // Process a random image from queue
      if (imageQueue.isNotEmpty) {
        final nextImage = imageQueue.removeAt(0);
        _processImageData(nextImage);

        // Preload the next image in the background
        _preloadNextImage();
      }
    } catch (e) {
      print('Error loading random image: $e');
    }
  }

// This is a helper function that will be used with compute
// It needs to match the expected signature exactly
  Uint8List decodeBase64Isolate(dynamic input) {
    return base64Decode(input as String);
  }

  void _processImageData(Map<String, dynamic> imageData) {
    final data = imageData['data'];
    final base64Code = data['imageCode'];
    final docId = imageData['id'];

    if (base64Code != null) {
      // Use the helper function with compute
      compute(decodeBase64Isolate, base64Code).then((bytes) {
        if (!mounted) return;

        setState(() {
          imageBase64 = base64Code;
          decodedImageBytes = bytes;
          usedImageIds.add(docId);
        });

        // Pre-cache the image for smoother display
        precacheImage(MemoryImage(bytes), context);

        if (data['targetLocation'] != null) {
          final GeoPoint geoPoint = data['targetLocation'];
          setState(() {
            targetLocation = LatLng(geoPoint.latitude, geoPoint.longitude);
          });
        }
      });
    }
  }

// Modified method to preload a random next image in background
  Future<void> _preloadNextImage() async {
    if (isNextImageLoading || imageQueue.isEmpty) return;

    isNextImageLoading = true;

    try {
      // Select a random image from the queue but don't remove it yet
      final randomIndex = Random().nextInt(imageQueue.length);
      final nextImage = imageQueue[randomIndex];
      final data = nextImage['data'];
      final base64Code = data['imageCode'];

      if (base64Code != null) {
        final bytes = await compute(
            base64Decode as ComputeCallback<dynamic, Uint8List>, base64Code);

        if (!mounted) {
          isNextImageLoading = false;
          return;
        }

        // Store the preloaded image
        nextImageBase64 = base64Code;
        nextDecodedImageBytes = bytes;

        if (data['targetLocation'] != null) {
          final GeoPoint geoPoint = data['targetLocation'];
          nextTargetLocation = LatLng(geoPoint.latitude, geoPoint.longitude);
        }

        // Pre-cache the next image
        precacheImage(MemoryImage(bytes), context);

        // Now remove this image from the queue since we've preloaded it
        imageQueue.removeAt(randomIndex);
      }
    } catch (e) {
      print('Error preloading next image: $e');
    } finally {
      isNextImageLoading = false;
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
    _preloadNextImage();

    if (targetLocation != null && markedLocation != null) {
      final distance = Geolocator.distanceBetween(
        targetLocation!.latitude,
        targetLocation!.longitude,
        markedLocation!.latitude,
        markedLocation!.longitude,
      );

      // Game over threshold at 500 meters
      const maxAllowedDistance = 500.0;

      int roundScore = 0;
      bool isGameEnding = false;

      // Scoring system based on distance
      if (distance > maxAllowedDistance) {
        // Location marked too far from target
        roundScore = 0;
        isGameEnding = true; // End game if guess is too far
      } else if (distance < 10) {
        // Extremely accurate guess (within 10 meters)
        roundScore = 1000;
      } else if (distance < 25) {
        // Very accurate guess (within 25 meters)
        roundScore = 750;
      } else if (distance < 50) {
        // Good guess (within 50 meters)
        roundScore = 500;
      } else if (distance < 100) {
        // Decent guess (within 100 meters)
        roundScore = 250;
      } else if (distance < maxAllowedDistance) {
        // Within allowed range but not very accurate
        roundScore = 100;
      }

      setState(() {
        currentScore += roundScore;
        if (roundScore > 0) {
          consecutiveCorrect++;
        } else {
          consecutiveCorrect = 0;
        }
      });

      if (isGameEnding) {
        showGameOverDialog(roundScore, distance);
      } else {
        showResultDialog(roundScore, distance);
      }
    } else {
      showResultDialog(0, null);
    }
  }

  void showGameOverDialog(int roundScore, double distance) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Game Over!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your guess was too far from the target location!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Distance: ${distance.toStringAsFixed(2)} meters',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                'Final Score: $currentScore',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Best Score: $maxScore',
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await updateMaxScore();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => HomeScreen()));
                }
              },
              child: const Text('Return to Home'),
            ),
          ],
        ),
      ),
    );
  }

  void showResultDialog(int roundScore, double? distance) {
    if (isGameOver) return;

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
              onPressed: () async {
                Navigator.of(context).pop();
                loadRandomImage();

                if (roundScore > 0 && distance != null && distance < 1000) {
                  resetRound();
                } else {
                  await updateMaxScore();
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => HomeScreen()));
                  }
                }
              },
              child: Text(roundScore > 0 && distance != null && distance < 1000
                  ? 'Next Round'
                  : 'Return to Home'),
            ),
          ],
        ),
      ),
    );
  }

  void resetRound() {
    if (!mounted) return;

    setState(() {
      imagesCompleted++;
      updateTimeForLevel();

      // Check if we're moving to a new level
      int oldLevel = currentLevel;
      if (oldLevel != currentLevel) {
        showLevelUpOverlay = true;
      }

      markedLocation = null;
      isLocationMarked = false;
      remainingTime = timeForCurrentLevel;
      currentZoom = 3.0;
      isRoundActive = false;
    });

    // Cancel any existing timers
    timer?.cancel();
    _controller.reset();

    if (showLevelUpOverlay) {
      // During level up overlay, we have time to load next image
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            showLevelUpOverlay = false;
          });
          // The image should already be preloaded
          startCountDown();
        }
      });
    } else {
      // The image should already be preloaded
      startCountDown();
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Play'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Look at the image and try to guess its location on the map. '
              'Tap the map to mark your guess, then press the Submit button. '
              'The closer you are, the more points you\'ll earn!',
            ),
            const SizedBox(height: 16),
            const Text(
              'Level System:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Level 1',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('First 10 images - 30 seconds each'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Level 2',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Next 10 images - 20 seconds each'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Level 3',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Remaining images - 10 seconds each'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Progress through levels to test your speed and accuracy!',
              style: TextStyle(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
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

  void endGame() async {
    setState(() {
      isGameOver = true;
    });

    await updateMaxScore();

    if (!mounted) return;

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
          ElevatedButton(
            onPressed: () async {
              await updateMaxScore();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/home_screen');
              }
            },
            child: const Text('Return to Home'),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelUpOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.arrow_upward,
              color: Colors.yellow,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Level Up!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Level $currentLevel',
              style: const TextStyle(
                color: Colors.yellow,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'New Time Limit: $timeForCurrentLevel seconds',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ],
        ),
      ),
    );
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
    return SafeArea(
      child: Scaffold(
        body: OrientationBuilder(
          builder: (context, orientation) {
            return Stack(
              children: [
                orientation == Orientation.portrait
                    ? _buildPortraitLayout()
                    : _buildLandscapeLayout(),
                if (isLoading) _buildCountdownOverlay(),
                if (showLevelUpOverlay) _buildLevelUpOverlay(),
                // Add this new Positioned widget for the back button
                Positioned(
                  top: 95,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _handleBackButton,
                      tooltip: 'Back',
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildScoreBar(),
        Expanded(
          flex: 5,
          child: _buildImageSection(),
        ),
        Expanded(
          flex: 5,
          child: _buildMapSection(),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Column(
      children: [
        _buildScoreBar(),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildImageSection(),
              ),
              Expanded(
                child: _buildMapSection(),
              ),
            ],
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildScoreBar() {
    return Container(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'Score: $currentScore',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'Best: $maxScore',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (isFirstImageLoading)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading first image...'),
                ],
              ),
            ),
          )
        else if (decodedImageBytes != null)
          Image.memory(
            decodedImageBytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading image',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            },
          )
        else if (imageBase64 != null)
          Image.memory(
            base64Decode(imageBase64!),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading image',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        if (!isLoading) _buildTimerOverlay(),
      ],
    );
  }

  Widget _buildTimerOverlay() {
    return Stack(
      children: [
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: _animation.value,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      remainingTime > 10 ? Colors.green : Colors.red,
                    ),
                    strokeWidth: 4,
                  ),
                ),
                Text(
                  '$remainingTime',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Stack(
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
          if (isLocationMarked) _buildMarkerInfo(),
        ],
      ),
    );
  }

  Widget _buildMarkerInfo() {
    return Positioned(
      bottom: 70,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              'Location marked',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLocationMarked ? submitGuess : null,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              isLocationMarked ? 'Submit Guess' : 'Mark a location first',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Get Ready!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
              ),
              child: Center(
                child: Text(
                  '$countDown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
    updateMaxScore();
    timer?.cancel();
    countDownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
