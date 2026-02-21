import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class LeagueService {
  LeagueService._();

  static final LeagueService instance = LeagueService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> createLeague(
    String leagueName, {
    required bool isSoccer,
    int? teamCount,
    int? roundCount,
    DateTime? draftDateTime,
  }) async {
    debugPrint('🔥 createLeague called');

    final name = leagueName.trim();
    if (name.isEmpty) {
      throw ArgumentError('leagueName is empty');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Login required');
    }

    final leagueRef = _firestore.collection('leagues').doc();
    final inviteCode = leagueRef.id.substring(0, 6).toUpperCase();
    final userRef = _firestore.collection('users').doc(user.uid);

    final data = <String, dynamic>{
      'name': name,
      'ownerId': user.uid,
      'members': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isPublic': false,
      'inviteCode': inviteCode,
      'sport': isSoccer ? 'soccer' : 'baseball',
    };
    if (teamCount != null) data['teamCount'] = teamCount;
    if (roundCount != null) data['roundCount'] = roundCount;
    if (draftDateTime != null) {
      data['draftDateTime'] = Timestamp.fromDate(draftDateTime);
    }

    final batch = _firestore.batch();
    batch.set(leagueRef, data);
    batch.set(userRef, {
      'leagueIds': FieldValue.arrayUnion([leagueRef.id]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    debugPrint('✅ createLeague success: ${leagueRef.id}');
    return leagueRef.id;
  }
}

