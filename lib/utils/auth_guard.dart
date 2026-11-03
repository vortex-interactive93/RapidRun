import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

/// Simple route guard helper. Returns true if authenticated; otherwise
/// navigates to /login and returns false.
Future<bool> ensureAuthenticated(BuildContext context) async {
  if (FirebaseService.user != null) return true;
  final res = await Navigator.pushNamed(context, '/login');
  return res == true && FirebaseService.user != null;
}
