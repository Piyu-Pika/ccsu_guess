import 'dart:ui';
import 'package:ccsu_guess/Screens/GameScreen.dart';
import 'package:ccsu_guess/Screens/Leaderboard.dart';
import 'package:ccsu_guess/Screens/DeveloperPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../Widget/Infowidget.dart';
import '../Widget/Profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();
    checkAndStoreUserName(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> checkUserNameExists() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      return userDoc.exists &&
          (userDoc.data() as Map<String, dynamic>).containsKey('name');
    }
    return false;
  }

  Future<void> checkAndStoreUserName(BuildContext context) async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists ||
          !(userDoc.data() as Map<String, dynamic>).containsKey('name')) {
        String? name = await _showNameInputDialog(context);
        if (name != null && name.isNotEmpty) {
          await _firestore.collection('users').doc(user.uid).set({
            'name': name,
            'maxScore': 0,
          }, SetOptions(merge: true));
        } else {
          _showNameInputDialog(context);
        }
      }
    }
  }

  Future<String?> _showNameInputDialog(BuildContext context) async {
    String? name;
    final TextEditingController _controller = TextEditingController();
    bool _isSubmitted = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(_isSubmitted ? 'Name Submitted' : 'Enter Your Name'),
          content: TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Your Name"),
          ),
          actions: [
            TextButton(
              child: Text(_isSubmitted ? 'Submit Again' : 'Submit'),
              onPressed: () {
                name = _controller.text;
                setState(() {
                  _isSubmitted = true;
                });
                _controller.clear();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
    return name;
  }

  Future<void> handleStartGame() async {
    bool hasName = await checkUserNameExists();
    if (!hasName) {
      String? name = await _showNameInputDialog(context);
      if (name != null && name.isNotEmpty) {
        User? user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).set({
            'name': name,
            'maxScore': 0,
          }, SetOptions(merge: true));
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GameScreen()),
          );
        }
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GameScreen()),
      );
    }
  }

  void _showGameInfoWidget() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GameInfoWidget(
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          
          AnimatedBuilder(
            animation: _controller,
            builder: (_, child) {
              return Transform.translate(
                offset: Offset(
                    -_controller.value * MediaQuery.of(context).size.width * 2,
                    0),
                child: Row(
                  children: List.generate(
                    3,
                    (index) => Image.asset(
                      'assets/images/ccsu_cover.jpg',
                      fit: BoxFit.cover,
                      height: double.infinity,
                      width: MediaQuery.of(context).size.width,
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.person_rounded,
                              color: Colors.white),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const ProfileDialog(),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline,
                              color: Colors.white),
                          onPressed: () {
                            _showGameInfoWidget();
                          },
                        ),
                      ],
                    ),
                  ),
                  // Middle Section
                  SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Title
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.blue, Colors.purple],
                          ).createShader(bounds),
                          child: Text(
                            'CCSU GUESS',
                            style: GoogleFonts.domine(
                              fontSize: 47,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Shimmer.fromColors(
                          baseColor: Colors.black,
                          highlightColor: Colors.white,
                          child: Text(
                            'Test Your Knowledge',
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(height: 50),
                        // Buttons
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.all(30),
                                color: Colors.white.withOpacity(0.2),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildButton('Start Game', Icons.play_arrow,
                                        Colors.blue, GameScreen()),
                                    const SizedBox(height: 15),
                                    _buildButton(
                                        'Leaderboard',
                                        Icons.leaderboard,
                                        Colors.green,
                                        Leaderboard()),
                                    const SizedBox(height: 15),
                                    _buildButton(
                                        'About Devloper',
                                        Icons.person,
                                        Colors.orange,
                                        const AboutDeveloperScreen()),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bottom Section
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialButton('assets/icons/facebook.svg'),
                        const SizedBox(width: 20),
                        _buildSocialButton('assets/icons/twitter.svg'),
                        const SizedBox(width: 20),
                        _buildSocialButton('assets/icons/instagram.svg'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
      String text, IconData icon, Color color, Widget destinationScreen) {
    return ElevatedButton.icon(
      icon: Icon(
        icon,
        color: Colors.white,
      ),
      label: Text(text),
      onPressed: () {
        if (text == 'Start Game') {
          handleStartGame();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destinationScreen),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        textStyle:
            GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 5,
      ),
    );
  }

  Widget _buildSocialButton(String assetName) {
    return InkWell(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: SvgPicture.asset(
          assetName,
          height: 24,
          width: 24,
          color: Colors.white,
        ),
      ),
    );
  }
}
