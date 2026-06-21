import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member.dart';

class MembersService {
  static const String _ipKey = 'server_ip';

  Future<String?> getSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ipKey);
  }

  Future<void> saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipKey, ip);
  }

  Future<List<Member>> getMembers() async {
    final ip = await getSavedIp();
    if (ip == null || ip.isEmpty) return [];

    try {
      final response = await http.get(Uri.parse('http://$ip/users'));
      if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.asMap().entries.map((e) {
        final map = e.value as Map<String, dynamic>;
        final id = map['id']?.toString() ?? e.key.toString();
        return Member.fromMap(id, map);
      }).toList();
    }
    } catch (_) {}
    return [];
  }

  Future<bool> enrollMember(String name, File image) async {
    final ip = await getSavedIp();
    if (ip == null || ip.isEmpty) return false;

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://$ip/enroll'),
      );
      request.fields['name'] = name;
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final response = await request.send();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeMember(String memberId) async {
    final ip = await getSavedIp();
    if (ip == null || ip.isEmpty) return false;

    try {
      final response = await http.delete(
        Uri.parse('http://$ip/users/$memberId'),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
