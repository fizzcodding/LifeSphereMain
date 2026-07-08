import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
class HealthService {
  static const _geminiKey = String.fromEnvironment('GEMINI_API_KEY');

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Stream<DatabaseEvent> vitalsStream() {
    if (_uid == null) return const Stream.empty();
    return _db.ref('users/$_uid/vital32').onValue;
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    if (_uid == null) return null;
    try {
      final snap = await _db.ref('users/$_uid/profile').get();
      if (snap.exists) {
        return Map<String, dynamic>.from(snap.value as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile(
    String name,
    String birthDate,
    String? phonetag,
  ) async {
    if (_uid == null) return;
    await _db.ref('users/$_uid/profile').set({
      'name': name,
      'birthDate': birthDate,
      'phonetag': phonetag,
    });
  }

  Future<void> updateHydration(int delta) async {
    if (_uid == null) return;
    final ref = _db.ref('users/$_uid/vital32/hydration/currently');

    final snap = await ref.get();
    final current = snap.exists ? (snap.value as num).toInt() : 0;

    final newValue = (current + delta).clamp(0, 100000);

    await ref.set(newValue);
    await _db
        .ref('users/$_uid/vital32/hydration/lastRecorded')
        .set(DateTime.now().toIso8601String());
  }

  Future<void> addDietItem(String meal, String item) async {
    if (_uid == null) return;
    final ref = _db.ref('users/$_uid/vital32/diet/$meal');
    final snap = await ref.get();

    final list = snap.exists
        ? List<String>.from(snap.value as List)
        : [];

    list.add(item);
    await ref.set(list);
  }

  Future<void> removeDietItem(String meal, int index) async {
    if (_uid == null) return;
    final ref = _db.ref('users/$_uid/vital32/diet/$meal');
    final snap = await ref.get();

    if (!snap.exists) return;

    final list = List<String>.from(snap.value as List);
    if (index < 0 || index >= list.length) return;

    list.removeAt(index);
    await ref.set(list);
  }

  Future<void> generateAISuggestions() async {
    if (_uid == null || _geminiKey.isEmpty) return;
    final userRef = _db.ref("users/$_uid");

    try {
      var age = 0;
      final birthSnap = await userRef.child("profile/birthDate").get();
      if (birthSnap.exists) {
        final birthStr = birthSnap.value as String;
        if (birthStr.isNotEmpty) {
          final birth = DateTime.parse(birthStr);
          final now = DateTime.now();
          age = now.year - birth.year;
          if (now.month < birth.month ||
              (now.month == birth.month && now.day < birth.day)) {
            age--;
          }
        }
      }

      Future<int> vital(String key) async {
        final snap = await userRef.child("vital32/$key/currently").get();
        return snap.exists ? (snap.value as num).toInt() : 0;
      }

      final steps = await vital("steps");
      final hydration = await vital("hydration");
      final hr = await vital("hr");
      final spo2 = await vital("spo2");
      final temp = await vital("temp");

      final prompt = """
You are SphereAI, a precision health intelligence embedded in a caregiving system.

Analyze these real-time biometrics and return EXACTLY 3 actionable micro-interventions.

BIOMETRICS:
- Age: $age
- Steps today: $steps
- Hydration: $hydration ml
- Heart Rate: $hr bpm
- SpO2: ${spo2}%
- Body Temp: ${temp}°C

RULES:
- each tip must be a direct action, not advice (say "drink 200ml now" not "stay hydrated")
- under 10 words per tip
- prioritize the most clinically concerning metric first
- if hr > 100 → address it first
- if spo2 < 95 → address it first, its urgent
- if hydration < 1500ml and steps > 5000 → flag dehydration risk
- if temp > 37.5 → flag it
- no generic tips like "sleep well" or "eat healthy"
- no emojis, no bullet symbols, no numbering
- plain text, one tip per line, nothing else
- tone: calm, direct, like a PhD doctor texting you
""";

      final res = await http.post(
        Uri.parse(
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiKey",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {"text": prompt},
              ],
            },
          ],
        }),
      );

      if (res.statusCode != 200) {
        return;
      }

      final data = jsonDecode(res.body);

      final text = data["candidates"][0]["content"]["parts"][0]["text"];

      final tips = text
          .split(RegExp(r'\n|\d\.\s|\*|-'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && e.length > 3)
          .take(3)
          .toList();

      while (tips.length < 3) {
        tips.add("Keep moving for better health.");
      }

      await userRef.child("vital32/aiSuggestions").set({
        "0": tips[0],
        "1": tips[1],
        "2": tips[2],
      });

    } catch (_) {}
  }
}
