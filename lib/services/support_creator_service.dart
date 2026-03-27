import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class SupportDonorEntry {
  final String name;
  final String? amount;
  final String? date;
  final String? message;

  const SupportDonorEntry({
    required this.name,
    this.amount,
    this.date,
    this.message,
  });

  factory SupportDonorEntry.fromJson(Map<String, dynamic> json) {
    return SupportDonorEntry(
      name: (json['name'] as String? ?? '').trim(),
      amount: (json['amount'] as String?)?.trim(),
      date: (json['date'] as String?)?.trim(),
      message: (json['message'] as String?)?.trim(),
    );
  }
}

class SupportDonorData {
  final String? title;
  final String? subtitle;
  final String? updatedAt;
  final List<SupportDonorEntry> donors;

  const SupportDonorData({
    this.title,
    this.subtitle,
    this.updatedAt,
    required this.donors,
  });

  factory SupportDonorData.fromJson(Map<String, dynamic> json) {
    final donorItems = (json['donors'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) =>
            SupportDonorEntry.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.name.isNotEmpty)
        .toList();
    return SupportDonorData(
      title: (json['title'] as String?)?.trim(),
      subtitle: (json['subtitle'] as String?)?.trim(),
      updatedAt: (json['updatedAt'] as String?)?.trim(),
      donors: donorItems,
    );
  }
}

class SupportCreatorService {
  static const MethodChannel _channel =
      MethodChannel('com.example.university_timetable/support');
  static const String donorsUrl =
      'https://raw.githubusercontent.com/Mutx163/mikcb/main/docs/donors.json';

  final http.Client _client;

  SupportCreatorService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<SupportDonorData> fetchDonors() async {
    final response = await _client.get(
      Uri.parse(donorsUrl),
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'mikcb-app',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('加载鸣谢名单失败（HTTP ${response.statusCode}）');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('鸣谢名单格式不正确');
    }
    return SupportDonorData.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<bool> saveAssetImageToGallery({
    required String assetPath,
    required String fileName,
  }) async {
    final byteData = await rootBundle.load(assetPath);
    final bytes = Uint8List.sublistView(byteData);
    final savedUri = await _channel.invokeMethod<String>(
      'saveImageToGallery',
      {
        'bytes': bytes,
        'fileName': fileName,
        'mimeType': 'image/png',
      },
    );
    return savedUri != null && savedUri.isNotEmpty;
  }
}
