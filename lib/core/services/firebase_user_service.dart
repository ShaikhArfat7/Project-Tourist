import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TouristProfile {
  final String uid;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String preferredLanguage;
  final String bloodGroup;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TouristProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    this.phoneNumber = '',
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.preferredLanguage = 'English',
    this.bloodGroup = '',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestoreMap({bool isNew = false}) {
    return {
      'fullName': fullName.trim(),
      'email': email.trim(),
      'phoneNumber': phoneNumber.trim(),
      'emergencyContact': {
        'name': emergencyContactName.trim(),
        'phone': emergencyContactPhone.trim(),
      },
      'preferredLanguage': preferredLanguage.trim(),
      'bloodGroup': bloodGroup.trim(),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory TouristProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    final ec = data['emergencyContact'] as Map<String, dynamic>? ?? {};
    return TouristProfile(
      uid: uid,
      fullName: (data['fullName'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      phoneNumber: (data['phoneNumber'] as String?) ?? '',
      emergencyContactName: (ec['name'] as String?) ??
          (data['emergencyContactName'] as String?) ??
          '',
      emergencyContactPhone: (ec['phone'] as String?) ??
          (data['emergencyContactPhone'] as String?) ??
          '',
      preferredLanguage: (data['preferredLanguage'] as String?) ?? 'English',
      bloodGroup: (data['bloodGroup'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class FirebaseUserService extends ChangeNotifier {
  static final FirebaseUserService _instance = FirebaseUserService._internal();
  factory FirebaseUserService() => _instance;
  FirebaseUserService._internal();

  bool _isFirebaseInitialized = false;
  String? _initializationError;
  User? _currentUser;
  TouristProfile? _currentProfile;
  StreamSubscription<User?>? _authSubscription;

  bool get isFirebaseInitialized => _isFirebaseInitialized;
  String? get initializationError => _initializationError;
  User? get currentUser => _currentUser;
  TouristProfile? get currentProfile => _currentProfile;
  bool get isGuestSignedIn => _currentUser == null && _currentProfile != null;
  bool get isSignedIn => _currentProfile != null || (_isFirebaseInitialized && _currentUser != null);

  static const FirebaseOptions _firebaseOptions = FirebaseOptions(
    apiKey: 'AIzaSyDb2wybopgrlPkxOU9sZWHNuWcws-9tEq0',
    authDomain: 'project-tourist-47bca.firebaseapp.com',
    projectId: 'project-tourist-47bca',
    storageBucket: 'project-tourist-47bca.firebasestorage.app',
    messagingSenderId: '911531693651',
    appId: '1:911531693651:web:1e7a3e33541c91eee518a6',
    measurementId: 'G-V38TTWG9G3',
  );

  Future<void> initializeFirebase() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseInitialized = true;
        _initializationError = null;
      } else {
        await Firebase.initializeApp(options: _firebaseOptions);
        _isFirebaseInitialized = true;
        _initializationError = null;
      }

      _currentUser = FirebaseAuth.instance.currentUser;
      if (_currentUser != null) {
        await _loadUserProfile(_currentUser!);
      }

      _authSubscription?.cancel();
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
        _currentUser = user;
        if (user != null) {
          await _loadUserProfile(user);
        } else if (!isGuestSignedIn) {
          _currentProfile = null;
        }
        notifyListeners();
      });
    } catch (e) {
      _isFirebaseInitialized = false;
      _initializationError = e.toString();
      debugPrint('Firebase initialization notice: $e');
    }
    notifyListeners();
  }

  Future<void> _saveLocalProfile(TouristProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_profile_uid', profile.uid);
      await prefs.setString('cached_profile_name', profile.fullName);
      await prefs.setString('cached_profile_email', profile.email);
      await prefs.setString('cached_profile_phone', profile.phoneNumber);
      await prefs.setString('cached_profile_ec_name', profile.emergencyContactName);
      await prefs.setString('cached_profile_ec_phone', profile.emergencyContactPhone);
      await prefs.setString('cached_profile_lang', profile.preferredLanguage);
      await prefs.setString('cached_profile_blood', profile.bloodGroup);
    } catch (e) {
      debugPrint('Error saving local profile: $e');
    }
  }

  Future<TouristProfile?> _loadLocalProfile(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUid = prefs.getString('cached_profile_uid');
      if (cachedUid == uid || cachedUid != null) {
        return TouristProfile(
          uid: cachedUid ?? uid,
          fullName: prefs.getString('cached_profile_name') ?? '',
          email: prefs.getString('cached_profile_email') ?? '',
          phoneNumber: prefs.getString('cached_profile_phone') ?? '',
          emergencyContactName: prefs.getString('cached_profile_ec_name') ?? '',
          emergencyContactPhone: prefs.getString('cached_profile_ec_phone') ?? '',
          preferredLanguage: prefs.getString('cached_profile_lang') ?? 'English',
          bloodGroup: prefs.getString('cached_profile_blood') ?? '',
        );
      }
    } catch (e) {
      debugPrint('Error reading local profile: $e');
    }
    return null;
  }

  /// Guest / Offline Presentation Mode: allows exploring the app without waiting for Firebase.
  Future<void> signInAsGuest({
    String name = 'Demo Tourist',
    String email = 'demo@touristsafety.org',
  }) async {
    _currentUser = null;
    final guest = TouristProfile(
      uid: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      fullName: name,
      email: email,
      phoneNumber: '+91 98765 43210',
      emergencyContactName: 'Emergency Family Contact',
      emergencyContactPhone: '+91 98765 00000',
      preferredLanguage: 'English',
      bloodGroup: 'O+',
    );
    _currentProfile = guest;
    await _saveLocalProfile(guest);
    notifyListeners();
  }

  Future<void> _loadUserProfile(User user) async {
    // 1. Instantly load from local storage cache
    final local = await _loadLocalProfile(user.uid);
    if (local != null) {
      _currentProfile = local;
      notifyListeners();
    }

    // 2. Fetch latest from Cloud Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        _currentProfile = TouristProfile.fromFirestore(user.uid, doc.data()!);
        await _saveLocalProfile(_currentProfile!);
      } else if (_currentProfile == null) {
        _currentProfile = TouristProfile(
          uid: user.uid,
          fullName: user.displayName ?? 'Tourist User',
          email: user.email ?? '',
        );
        await _saveLocalProfile(_currentProfile!);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Notice loading Cloud Firestore profile: $e');
      _currentProfile ??= TouristProfile(
        uid: user.uid,
        fullName: user.displayName ?? 'Tourist User',
        email: user.email ?? '',
      );
      notifyListeners();
    }
  }

  Future<String?> signUp({
    required String fullName,
    required String email,
    required String password,
    String phoneNumber = '',
    String emergencyContactName = '',
    String emergencyContactPhone = '',
    String preferredLanguage = 'English',
    String bloodGroup = '',
  }) async {
    if (!_isFirebaseInitialized) {
      return 'Firebase is not initialized. Please check network connection.';
    }

    final trimmedEmail = email.trim();
    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    if (!emailRegex.hasMatch(trimmedEmail)) {
      return 'Invalid email address format (e.g. tourist@example.com).';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password) ||
        !RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Password must contain at least one uppercase letter, one lowercase letter, one number, and one symbol.';
    }

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return 'Account creation failed. Please try again.';
      }

      await user.updateDisplayName(fullName.trim());

      final profile = TouristProfile(
        uid: user.uid,
        fullName: fullName.trim(),
        email: email.trim(),
        phoneNumber: phoneNumber.trim(),
        emergencyContactName: emergencyContactName.trim(),
        emergencyContactPhone: emergencyContactPhone.trim(),
        preferredLanguage: preferredLanguage,
        bloodGroup: bloodGroup.trim(),
      );

      // Save locally first so profile is never lost
      await _saveLocalProfile(profile);
      _currentProfile = profile;
      notifyListeners();

      // Sync to Cloud Firestore
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(profile.toFirestoreMap(isNew: true));
      } catch (firestoreError) {
        debugPrint('Firestore database permission notice: $firestoreError');
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyAuthError(e);
    } catch (e) {
      return 'Registration error: $e';
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!_isFirebaseInitialized) {
      return 'Firebase is not initialized. Please check network connection.';
    }

    final trimmedEmail = email.trim();
    if (!trimmedEmail.contains('@') || !trimmedEmail.contains('.')) {
      return 'Please enter a valid email address.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
      if (credential.user != null) {
        await _loadUserProfile(credential.user!);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyAuthError(e);
    } catch (e) {
      return 'Sign-in error: $e';
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    if (!_isFirebaseInitialized) {
      return 'Firebase is not initialized.';
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyAuthError(e);
    } catch (e) {
      return 'Password reset error: $e';
    }
  }

  Future<String?> updateProfile(TouristProfile updated) async {
    // 1. Always save to local storage immediately
    await _saveLocalProfile(updated);
    _currentProfile = updated;
    notifyListeners();

    // If guest user, local save is completely successful
    if (_currentUser == null) {
      return null;
    }

    // 2. Sync to Cloud Firestore
    try {
      await _currentUser!.updateDisplayName(updated.fullName.trim());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set(updated.toFirestoreMap(isNew: false), SetOptions(merge: true));
      return null;
    } on FirebaseException catch (e) {
      debugPrint('Firestore sync notice: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        return 'Profile saved locally! [Firebase Notice]: Cloud Firestore permission denied. In Firebase Console, set rules to allow authenticated users to read/write their own profile.';
      }
      return 'Profile saved locally! Cloud sync notice: ${e.message ?? e.code}';
    } catch (e) {
      debugPrint('Profile update sync error: $e');
      return 'Profile saved locally! Cloud sync notice: $e';
    }
  }

  /// Logs an explicitly user-confirmed SOS incident to Firestore when signed in.
  Future<void> logConfirmedSosIncident({
    required double? latitude,
    required double? longitude,
    required String address,
    required String reason,
  }) async {
    if (!_isFirebaseInitialized || _currentUser == null) return;
    try {
      await FirebaseFirestore.instance.collection('incidents').add({
        'uid': _currentUser!.uid,
        'userEmail': _currentUser!.email,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'reason': reason,
        'confirmedByUser': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Could not log SOS incident to Firestore: $e');
    }
  }

  Future<void> signOut() async {
    if (_isFirebaseInitialized) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    _currentProfile = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_profile_uid');
      await prefs.remove('cached_profile_name');
      await prefs.remove('cached_profile_email');
      await prefs.remove('cached_profile_phone');
      await prefs.remove('cached_profile_ec_name');
      await prefs.remove('cached_profile_ec_phone');
      await prefs.remove('cached_profile_lang');
      await prefs.remove('cached_profile_blood');
    } catch (_) {}
    notifyListeners();
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'invalid-credential':
        return 'Incorrect email or password. Please verify your credentials.';
      case 'wrong-password':
        return 'Incorrect password. Try again or use "Forgot Password".';
      case 'email-already-in-use':
        return 'An account already exists with this email address. Try signing in.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 8 characters with numbers and symbols.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'operation-not-allowed':
        return 'Firebase Error: Email/Password sign-in provider is disabled in Firebase Console (Authentication > Sign-in method).';
      case 'app-not-authorized':
        return 'Firebase Error: This app is not authorized in Firebase Console. Add SHA-1 fingerprint in Project Settings.';
      case 'configuration-not-found':
        return 'Firebase Error: Authentication configuration not found. Check Firebase Console.';
      default:
        return 'Firebase Auth (${e.code}): ${e.message ?? 'Unknown authentication error.'}';
    }
  }
}
