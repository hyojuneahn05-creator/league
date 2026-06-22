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

  Future<void> deleteLeague(String leagueId) async {
    final id = leagueId.trim();
    if (id.isEmpty) {
      throw ArgumentError('leagueId is empty');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Login required');
    }

    await _firestore.collection('leagues').doc(id).delete();
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

  Future<Map<String, dynamic>> updateFantasyRoster({
    required String leagueId,
    required String teamName,
    required List<Map<String, dynamic>> roster,
    required List<Map<String, dynamic>> starting,
    required List<Map<String, dynamic>> bench,
    String? captainName,
    String? viceCaptainName,
    String? captainPlayerId,
    String? viceCaptainPlayerId,
    List<Map<String, dynamic>>? kboRoundScoreStates,
  }) async {
    final id = leagueId.trim();
    if (id.isEmpty) {
      throw ArgumentError('leagueId is empty');
    }

    final callable = _functions.httpsCallable('updateFantasyRoster');
    final payload = <String, dynamic>{
      'leagueId': id,
      'teamName': teamName,
      'roster': roster,
      'starting': starting,
      'bench': bench,
      'captainName': captainName,
      'viceCaptainName': viceCaptainName,
      'captainPlayerId': captainPlayerId,
      'viceCaptainPlayerId': viceCaptainPlayerId,
      if (kboRoundScoreStates != null)
        'kboRoundScoreStates': kboRoundScoreStates,
    };
    final result = await callable.call<Map<String, dynamic>>(payload);
    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> renameFantasyTeamIdentity({
    required String teamName,
  }) async {
    final normalizedName = teamName.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('teamName is empty');
    }

    final callable = _functions.httpsCallable('renameFantasyTeamIdentity');
    final result = await callable.call<Map<String, dynamic>>({
      'teamName': normalizedName,
    });
    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>?> getPublicUserProfile(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw ArgumentError('uid is empty');
    }

    final callable = _functions.httpsCallable('getPublicUserProfile');
    final result = await callable.call<Map<String, dynamic>>({
      'uid': normalizedUid,
    });
    final data = Map<String, dynamic>.from(result.data);
    final profile = data['profile'];
    if (profile is Map) {
      return Map<String, dynamic>.from(profile);
    }
    return null;
  }

  Future<String> submitTradeRequest({
    required String leagueId,
    required String leagueName,
    required bool isSoccer,
    required String fromUid,
    required String fromTeamName,
    required String toUid,
    required String toTeamName,
    required List<Map<String, dynamic>> fromPlayers,
    required List<Map<String, dynamic>> toPlayers,
  }) async {
    final id = leagueId.trim();
    if (id.isEmpty) {
      throw ArgumentError('leagueId is empty');
    }
    if (fromUid.trim().isEmpty || toUid.trim().isEmpty) {
      throw ArgumentError('trade participants are empty');
    }

    final requestRef = _firestore.collection('tradeRequests').doc();
    await requestRef.set({
      'leagueId': id,
      'leagueName': leagueName.trim(),
      'sport': isSoccer ? 'soccer' : 'baseball',
      'status': 'pending',
      'participants': [fromUid.trim(), toUid.trim()],
      'fromUid': fromUid.trim(),
      'fromTeamName': fromTeamName.trim(),
      'toUid': toUid.trim(),
      'toTeamName': toTeamName.trim(),
      'fromPlayers': fromPlayers,
      'toPlayers': toPlayers,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return requestRef.id;
  }

  Future<List<Map<String, dynamic>>> getTradeRequestsForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return const <Map<String, dynamic>>[];
    try {
      final snapshot = await _firestore
          .collection('tradeRequests')
          .where('participants', arrayContains: user.uid)
          .get();

      final requests = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();

      requests.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];
        final aDate = aTime is Timestamp ? aTime.toDate() : DateTime(1970);
        final bDate = bTime is Timestamp ? bTime.toDate() : DateTime(1970);
        return bDate.compareTo(aDate);
      });
      return requests;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint('getTradeRequestsForCurrentUser permission denied');
        return const <Map<String, dynamic>>[];
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getTradeRequestById(String requestId) async {
    final id = requestId.trim();
    if (id.isEmpty) {
      throw ArgumentError('requestId is empty');
    }
    try {
      final snapshot = await _firestore
          .collection('tradeRequests')
          .doc(id)
          .get();
      if (!snapshot.exists) return null;
      final data = Map<String, dynamic>.from(snapshot.data() ?? const {});
      data['id'] = snapshot.id;
      return data;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint('getTradeRequestById permission denied');
        return null;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> respondToTradeRequest({
    required String requestId,
    required String action,
    Map<String, List<Map<String, dynamic>>>? kboRoundScoreStatesByTeam,
  }) async {
    final id = requestId.trim();
    final normalizedAction = action.trim().toLowerCase();
    if (id.isEmpty) {
      throw ArgumentError('requestId is empty');
    }
    if (normalizedAction != 'accept' && normalizedAction != 'decline') {
      throw ArgumentError('action must be accept or decline');
    }
    final callable = _functions.httpsCallable('respondToTradeRequest');
    final payload = <String, dynamic>{
      'requestId': id,
      'action': normalizedAction,
      if (kboRoundScoreStatesByTeam != null)
        'kboRoundScoreStatesByTeam': kboRoundScoreStatesByTeam,
    };
    final result = await callable.call<Map<String, dynamic>>(payload);
    return Map<String, dynamic>.from(result.data);
  }

  Future<List<Map<String, dynamic>>> getKLeagueWeeklyLeaderSnapshots(
    String leagueId,
  ) async {
    final id = leagueId.trim();
    if (id.isEmpty) {
      throw ArgumentError('leagueId is empty');
    }

    final callable = _functions.httpsCallable(
      'getKLeagueWeeklyLeaderSnapshots',
    );
    final result = await callable.call<Map<String, dynamic>>({'leagueId': id});
    final data = Map<String, dynamic>.from(result.data);
    final snapshots = data['snapshots'];
    if (snapshots is! List) return const <Map<String, dynamic>>[];
    return snapshots
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item.cast<Object?, Object?>()))
        .toList();
  }

  Future<List<Map<String, dynamic>>> saveKLeagueWeeklyLeaderSnapshots({
    required String leagueId,
    required List<Map<String, dynamic>> snapshots,
  }) async {
    final id = leagueId.trim();
    if (id.isEmpty) {
      throw ArgumentError('leagueId is empty');
    }

    final callable = _functions.httpsCallable(
      'saveKLeagueWeeklyLeaderSnapshots',
    );
    final result = await callable.call<Map<String, dynamic>>({
      'leagueId': id,
      'snapshots': snapshots,
    });
    final data = Map<String, dynamic>.from(result.data);
    final saved = data['snapshots'];
    if (saved is! List) return const <Map<String, dynamic>>[];
    return saved
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item.cast<Object?, Object?>()))
        .toList();
  }
}
