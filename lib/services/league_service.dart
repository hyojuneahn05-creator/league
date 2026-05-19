import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class LeagueService {
  LeagueService._();

  static final LeagueService instance = LeagueService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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

  Future<void> leaveLeague(String leagueId) async {
    final id = leagueId.trim();
    if (id.isEmpty) {
      throw ArgumentError('leagueId is empty');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Login required');
    }

    final leagueRef = _firestore.collection('leagues').doc(id);
    final userRef = _firestore.collection('users').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(leagueRef);
      if (!snapshot.exists) {
        transaction.set(userRef, {
          'leagueIds': FieldValue.arrayRemove([id]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      final data = snapshot.data() ?? const <String, dynamic>{};
      final ownerId = '${data['ownerId'] ?? ''}';
      final members = List<String>.from(
        (data['members'] as List<dynamic>? ?? const []).map((e) => '$e'),
      );
      final remainingMembers = members.where((m) => m != user.uid).toList();

      if (remainingMembers.isEmpty) {
        transaction.delete(leagueRef);
      } else {
        final update = <String, dynamic>{
          'members': remainingMembers,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (ownerId == user.uid) {
          update['ownerId'] = remainingMembers.first;
        }
        transaction.update(leagueRef, update);
      }

      transaction.set(userRef, {
        'leagueIds': FieldValue.arrayRemove([id]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<Map<String, dynamic>> joinLeagueByInviteCode(String inviteCode) async {
    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) {
      throw ArgumentError('inviteCode is empty');
    }

    final callable = _functions.httpsCallable('joinLeagueByInviteCode');
    final result = await callable.call<Map<String, dynamic>>({'code': code});
    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> ensureDraftOrder(String leagueId) async {
    final id = leagueId.trim();
    if (id.isEmpty) {
      throw ArgumentError('leagueId is empty');
    }

    final callable = _functions.httpsCallable('ensureDraftOrder');
    final result = await callable.call<Map<String, dynamic>>({'leagueId': id});
    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> finalizeFantasyLeague({
    required String leagueId,
    required List<Map<String, dynamic>> draftBoard,
    required List<Map<String, dynamic>> fantasyTeams,
    required List<Map<String, dynamic>> fantasySchedule,
  }) async {
    final id = leagueId.trim();
    if (id.isEmpty) {
      throw ArgumentError('leagueId is empty');
    }

    final callable = _functions.httpsCallable('finalizeFantasyLeague');
    final result = await callable.call<Map<String, dynamic>>({
      'leagueId': id,
      'draftBoard': draftBoard,
      'fantasyTeams': fantasyTeams,
      'fantasySchedule': fantasySchedule,
    });
    return Map<String, dynamic>.from(result.data);
  }
}
