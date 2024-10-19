import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class Leaderboard extends StatefulWidget {
  @override
  _LeaderboardState createState() => _LeaderboardState();
}

class _LeaderboardState extends State<Leaderboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Pagination variables
  static const int pageSize = 10;
  DocumentSnapshot? lastDocument;
  bool hasMore = true;
  bool isLoading = false;
  List<DocumentSnapshot> documents = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      isLoading = true;
    });

    var snapshot = await _firestore
        .collection('users')
        .orderBy('maxScore', descending: true)
        .limit(pageSize)
        .get();

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        documents = snapshot.docs;
        lastDocument = snapshot.docs.last;
        hasMore = snapshot.docs.length == pageSize;
        isLoading = false;
      });
    } else {
      setState(() {
        hasMore = false;
        isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (isLoading || !hasMore) return;

    setState(() {
      isLoading = true;
    });

    var snapshot = await _firestore
        .collection('users')
        .orderBy('maxScore', descending: true)
        .startAfterDocument(lastDocument!)
        .limit(pageSize)
        .get();

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        documents.addAll(snapshot.docs);
        lastDocument = snapshot.docs.last;
        hasMore = snapshot.docs.length == pageSize;
        isLoading = false;
      });
    } else {
      setState(() {
        hasMore = false;
        isLoading = false;
      });
    }
  }

  void _shareScore() async {
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(_auth.currentUser!.uid).get();

    int userScore = userDoc['maxScore'];
    String shareText =
        'I scored ${NumberFormat('#,##0').format(userScore)} points on CCSU Guess! Give it a try at https://ccsu-guess.vercel.app/';

    await Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.share,
              color: Colors.white,
            ),
            onPressed: _shareScore,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(context),
          _buildColumnHeaders(),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (!isLoading &&
                    hasMore &&
                    scrollInfo.metrics.pixels ==
                        scrollInfo.metrics.maxScrollExtent) {
                  _loadMoreData();
                }
                return true;
              },
              child: ListView.builder(
                itemCount: documents.length + (hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == documents.length) {
                    return _buildLoadingIndicator();
                  }

                  DocumentSnapshot doc = documents[index];
                  bool isCurrentUser = doc.id == _auth.currentUser!.uid;
                  return _buildLeaderboardItem(doc, index + 1, isCurrentUser);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
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
            'Top Players',
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
