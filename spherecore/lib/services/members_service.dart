import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member.dart';

class MemeberServices {
  static const String _ipKey = 'server_ip';
  Future<String?> getServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ipKey);
  }

  Future<void> saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstances();
    await prefs.setString(_ipKey, ip);
  }

  Future<List<Member>> getMembers() async {
    final ip = await getSavedIp();
    if (ip == null || )
  }
}
