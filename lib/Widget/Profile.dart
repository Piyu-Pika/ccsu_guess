import 'dart:convert';
import 'package:ccsu_guess/Screens/login.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class ProfileDialog extends StatefulWidget {
  const ProfileDialog({Key? key}) : super(key: key);

  @override
  _ProfileDialogState createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  String? _profilePicBase64;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final userData = await _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .get();

      setState(() {
        _nameController.text = userData.get('name') ?? '';
        _profilePicBase64 = userData.get('profilePic');
      });
    } catch (e) {
      _showError('Error loading user data');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);

        await _firestore
            .collection('users')
            .doc(_auth.currentUser?.uid)
            .update({'profilePic': base64String});

        setState(() => _profilePicBase64 = base64String);
      }
    } catch (e) {
      _showError('Error uploading image');
    }
  }

  Future<void> _updateUsername() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Username cannot be empty');
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .update({'name': _nameController.text.trim()});

      setState(() => _isEditing = false);
    } catch (e) {
      _showError('Error updating username');
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      Navigator.of(context).pop(); // Close dialog
      // Navigate to login screen or handle logout in your app
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => LoginPage()));
    } catch (e) {
      _showError('Error logging out');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _profilePicBase64 != null
                              ? MemoryImage(
                                  base64Decode(_profilePicBase64!),
                                )
                              : null,
                          child: _profilePicBase64 == null
                              ? const Icon(Icons.account_circle_outlined,
                                  size: 50)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 20),
                              onPressed: _pickAndUploadImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_isEditing) ...[
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() => _isEditing = false);
                            },
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: _updateUsername,
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        _nameController.text,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit, color: Colors.black),
                        label: const Text('Edit Username',
                            style: TextStyle(color: Colors.black)),
                        onPressed: () {
                          setState(() => _isEditing = true);
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text('Logout'),
                      onPressed: _logout,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
