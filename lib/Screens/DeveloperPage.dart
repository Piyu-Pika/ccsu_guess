import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutDeveloperScreen extends StatelessWidget {
  const AboutDeveloperScreen({Key? key}) : super(key: key);

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.blue[700],
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 70,
                      backgroundImage: AssetImage("assets/images/profile.png"),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Piyush Bhardwaj",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Flutter Developer",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    title: "Connect",
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialButton(
                          icon: Icons.email,
                          label: "Email",
                          onPressed: () =>
                              _launchUrl('mailto:piyushbhardwaj1603@gmail.com'),
                        ),
                        _buildSocialButton(
                          icon: Icons.code,
                          label: "GitHub",
                          onPressed: () =>
                              _launchUrl('https://github.com/Piyu-Pika'),
                        ),
                        _buildSocialButton(
                          icon: Icons.link,
                          label: "LinkedIn",
                          onPressed: () => _launchUrl(
                              'https://in.linkedin.com/in/piyush-bhardwaj-flutter'),
                        ),
                      ],
                    ),
                  ),
                  _buildSection(
                    title: "About Me",
                    child: Text(
                      "A passionate Flutter app developer pursuing B.Tech in Computer Science "
                      "from Chaudhary Charan Singh University. Expanding skills in Flutter, "
                      "Dart, and Firebase for app development. Also proficient in Python, C, and C++.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                  ),
                  _buildSection(
                    title: "Skills",
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        "Flutter",
                        "Dart",
                        "Firebase",
                        "Python",
                        "C",
                        "C++",
                        "SQL",
                        "Android SDK",
                        "Git",
                        "GitHub"
                      ]
                          .map((skill) => Chip(
                                label: Text(skill),
                                backgroundColor: Colors.blue[100],
                                labelStyle: TextStyle(color: Colors.blue[800]),
                              ))
                          .toList(),
                    ),
                  ),
                  _buildSection(
                    title: "Education",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEducationItem(
                          degree: "Bachelor of Technology (Computer Science)",
                          institution:
                              "Chaudhary Charan Singh University, Meerut",
                          duration: "2022 - 2026",
                        ),
                        const SizedBox(height: 12),
                        _buildEducationItem(
                          degree: "High School & Intermediate",
                          institution: "Modern School, Vaishali",
                          duration: "2020 - 2022",
                        ),
                      ],
                    ),
                  ),
                  _buildSection(
                    title: "Certifications",
                    child: Column(
                      children: [
                        _buildCertificationItem("C++ (Letsupgrade)"),
                        _buildCertificationItem("Python (GUVI)"),
                        _buildCertificationItem("AI for India 2.0 (GUVI)"),
                        _buildCertificationItem(
                            "Introduction to Flutter (CareerNinja)"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      "Version 1.0.0",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          IconButton(
            icon: Icon(icon),
            onPressed: onPressed,
            color: Colors.blue[700],
            iconSize: 32,
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.blue[700],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationItem({
    required String degree,
    required String institution,
    required String duration,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            degree,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            institution,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            duration,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationItem(String certification) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: Colors.blue[700], size: 20),
          const SizedBox(width: 12),
          Text(
            certification,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }
}
