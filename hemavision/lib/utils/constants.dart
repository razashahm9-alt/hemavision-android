import 'package:flutter/foundation.dart';

class AppConstants {
  static const String baseUrl = 'http://your-django-server/api/';
  static const String appName = 'HemaVision';
  static const String medlineBase =
      'https://connect.nlm.nih.gov/connect/service';
  static const String googlePlacesBase =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  static const String newsBase = 'https://newsapi.org/v2/everything';
  static const String openWeatherBase =
      'https://api.openweathermap.org/data/2.5/weather';
  static const String qrBase = 'https://api.qrserver.com/v1/create-qr-code/';
  static const String infermedicaBase =
      'https://api.infermedica.com/v3/diagnosis';
  static String get modelBridgeBase {
    const configuredBase = String.fromEnvironment('MODEL_BRIDGE_BASE');
    if (configuredBase.isNotEmpty) return configuredBase;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }
}

/*
Firestore rules to set in Firebase Console:
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    match /cbc_reports/{reportId} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
    }
    match /analysis_results/{resultId} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
    }
  }
}
*/
