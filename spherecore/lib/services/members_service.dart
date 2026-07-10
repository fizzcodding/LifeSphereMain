import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member.dart';

class MembersService {
  static const _ipKey = 'server_ip';

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
      final res = await http.get(Uri.parse('http://$ip/users'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
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
      final request = http.MultipartRequest('POST', Uri.parse('http://$ip/enroll'));
      request.fields['name'] = name;
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
      final res = await request.send();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeMember(String id) async {
    final ip = await getSavedIp();
    if (ip == null || ip.isEmpty) return false;

    try {
      final res = await http.delete(Uri.parse('http://$ip/users/$id'));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
