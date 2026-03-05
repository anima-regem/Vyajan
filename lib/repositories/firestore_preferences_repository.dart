import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_preferences.dart';
import 'preferences_repository.dart';

class FirestorePreferencesRepository implements PreferencesRepository {
  FirestorePreferencesRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String userId) =>
      _firestore.collection('user_preferences').doc(userId);

  @override
  Stream<UserPreferences> watchPreferences(String userId) {
    return _doc(userId).snapshots().map((snapshot) {
      return UserPreferences.fromMap(snapshot.data());
    });
  }

  @override
  Future<UserPreferences> getPreferences(String userId) async {
    final snapshot = await _doc(userId).get();
    return UserPreferences.fromMap(snapshot.data());
  }

  @override
  Future<void> setPreferences(
      String userId, UserPreferences preferences) async {
    await _doc(userId).set(preferences.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> patchPreferences(
      String userId, Map<String, dynamic> patch) async {
    await _doc(userId).set(patch, SetOptions(merge: true));
  }
}
