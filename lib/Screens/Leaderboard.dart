import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class Leaderboard extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: Colors.blue[800],
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .orderBy('maxScore', descending: true)
            .limit(100) // Keep limit high to find current user's position
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          List<DocumentSnapshot> documents = snapshot.data!.docs;
          String currentUserId = _auth.currentUser!.uid;
          int currentUserRank =
              documents.indexWhere((doc) => doc.id == currentUserId) + 1;

          return Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _buildLeaderboardList(
                    documents, currentUserId, currentUserRank),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[800],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: const Column(
        children: [
          Text(
            'Top 10 Players',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 8),
          Text(
            'Compete to reach the top!',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(List<DocumentSnapshot> documents,
      String currentUserId, int currentUserRank) {
    bool isCurrentUserInTop10 = currentUserRank <= 10;
    int itemCount = isCurrentUserInTop10
        ? 11 // Header + top 10
        : 13; // Header + top 10 + divider + current user

    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildColumnHeaders();
        }

        index -= 1; // Adjust for header

        // Show top 10
        if (index < 10) {
          return _buildLeaderboardItem(documents[index], index + 1,
              documents[index].id == currentUserId);
        }

        // If current user is not in top 10, show divider and current user's position
        if (!isCurrentUserInTop10 && index == 10) {
          return _buildDivider();
        }

        if (!isCurrentUserInTop10 && index == 11) {
          return _buildLeaderboardItem(
              documents[currentUserRank - 1], currentUserRank, true);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("• • •",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey[200],
      child: const Row(
        children: [
          Expanded(
              flex: 1,
              child:
                  Text('Rank', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 3,
              child:
                  Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 2,
              child:
                  Text('Score', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(
      DocumentSnapshot doc, int rank, bool isCurrentUser) {
    String name = doc['name'];
    int score = doc['maxScore'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.yellow[100] : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '$rank',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: _getRankColor(rank)),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _buildAvatar(name, isCurrentUser),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCurrentUser ? '$name (You)' : name,
                    style: TextStyle(
                        fontWeight: isCurrentUser
                            ? FontWeight.bold
                            : FontWeight.normal),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              NumberFormat('#,##0').format(score),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, bool isCurrentUser) {
    return CircleAvatar(
      backgroundColor: isCurrentUser ? Colors.blue : Colors.grey[300],
      child: Text(
        name.substring(0, 1).toUpperCase(),
        style: TextStyle(color: isCurrentUser ? Colors.white : Colors.black),
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.orange;
    if (rank == 2) return Colors.grey[600]!;
    if (rank == 3) return Colors.brown;
    return Colors.black;
  }
}
