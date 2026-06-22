import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String kPublicUserProfilesCollection = 'publicUserProfiles';

DocumentReference<Map<String, dynamic>> publicUserProfileRef(
  FirebaseFirestore firestore,
  String uid,
) => firestore.collection(kPublicUserProfilesCollection).doc(uid.trim());

Future<void> syncPublicUserProfile(
  FirebaseFirestore firestore, {
  required String uid,
  String? displayName,
  String? normalizedDisplayName,
  String? photoUrl,
}) async {
  final normalizedUid = uid.trim();
  if (normalizedUid.isEmpty) return;

  final payload = <String, dynamic>{
    'uid': normalizedUid,
    'updatedAt': FieldValue.serverTimestamp(),
  };
  if (displayName != null) payload['displayName'] = displayName;
  if (normalizedDisplayName != null) {
    payload['normalizedDisplayName'] = normalizedDisplayName;
  }
  if (photoUrl != null) payload['photoUrl'] = photoUrl;

  await publicUserProfileRef(firestore, normalizedUid).set(
    payload,
    SetOptions(merge: true),
  );
}

Future<void> syncCurrentUserPublicProfileFromAuth(
  FirebaseFirestore firestore, {
  String? displayNameOverride,
  String? normalizedDisplayNameOverride,
  String? photoUrlOverride,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  final uid = user?.uid.trim() ?? '';
  if (uid.isEmpty) return;

  await syncPublicUserProfile(
    firestore,
    uid: uid,
    displayName: displayNameOverride ?? user?.displayName ?? '',
    normalizedDisplayName:
        normalizedDisplayNameOverride ??
        (displayNameOverride ?? user?.displayName ?? '')
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ')
            .toLowerCase(),
    photoUrl: photoUrlOverride ?? user?.photoURL ?? '',
  );
}
