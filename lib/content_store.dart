import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'curriculum.dart';

/// A content pack contains words.json and PNG frames only, never application code.
/// Publish a tiny manifest on HTTPS. The app checks for a new pack and prompts
/// a guardian before downloading the disclosed size.
class PackOffer {
  const PackOffer(this.version, this.url, this.sha256, this.bytes);
  final String version;
  final Uri url;
  final String sha256;
  final int bytes;
  double get megabytes => bytes / (1024*1024);

  factory PackOffer.fromJson(Map<String,dynamic> json, Uri manifestUrl) {
    if (json['schema_version'] != 1) {
      throw const FormatException('Unsupported content manifest');
    }
    final version = json['content_version'];
    final hash = json['sha256'];
    final size = json['size_bytes'];
    final uri = manifestUrl.resolve(json['pack_url'] as String);
    if (version is! String || !RegExp(r'^[a-zA-Z0-9._-]{1,64}$').hasMatch(version) ||
        hash is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        size is! int || size < 100 || size > ContentStore.maxDownloadBytes ||
        uri.scheme != 'https' || uri.host != manifestUrl.host || uri.userInfo.isNotEmpty) {
      throw const FormatException('Unsafe or incomplete content manifest');
    }
    return PackOffer(version, uri, hash, size);
  }
}

class LoadedContent {
  const LoadedContent(this.catalog, this.directory);
  final Curriculum catalog;
  final Directory? directory;
}

class ContentStore {
  const ContentStore({this.manifestUrl =
    const String.fromEnvironment('WORDSPROUT_CONTENT_URL')});
  final String manifestUrl;
  static const maxDownloadBytes = 35 * 1024 * 1024;
  static const maxUncompressedBytes = 110 * 1024 * 1024;
  static const activePackKey = 'content_pack_active_v1';
  static final safeMember = RegExp(
    r'^(words[.]json|media/[a-z0-9_-]+/(still|frame_[0-9]{5})[.]png)$');

  Future<Directory> _root() async {
    final support = await getApplicationSupportDirectory();
    return Directory(support.path + '/wordsprout_content');
  }

  Future<LoadedContent> load() async {
    final starter = await Curriculum.load();
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getString(activePackKey);
    if (active == null || !RegExp(r'^[a-f0-9]{20}$').hasMatch(active)) {
      return (await _loadBundled()) ?? LoadedContent(starter, null);
    }
    try {
      final folder = Directory((await _root()).path + '/' + active);
      final jsonFile = File(folder.path + '/words.json');
      final catalog = Curriculum.fromJson(
        jsonDecode(await jsonFile.readAsString()) as Map<String,dynamic>);
      catalog.assertCompatibleWith(starter);
      _verifyFiles(catalog, folder);
      return LoadedContent(catalog, folder);
    } catch (_) {
      // The last cached pack must never prevent offline learning.
      await prefs.remove(activePackKey);
      return (await _loadBundled()) ?? LoadedContent(starter, null);
    }
  }

  /// A first-install pack is an ordinary bundled Flutter asset. New words and
  /// images remain playable without ever connecting to the content server.
  Future<LoadedContent?> _loadBundled() async {
    ByteData data;
    try {
      data = await rootBundle.load('assets/content/starter_pack.zip');
    } catch (_) {
      return null; // Existing development builds still use the bundled SVG A-Z.
    }
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    if (bytes.length > maxDownloadBytes) {
      throw const FormatException('Bundled content pack exceeds size limit');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify:true);
    final jsonEntry = archive.files.where((e) => e.name == 'words.json').firstOrNull;
    if (jsonEntry == null || !jsonEntry.isFile || jsonEntry.size > 512 * 1024) {
      throw const FormatException('Bundled content metadata is missing');
    }
    final jsonBytes = jsonEntry.readBytes();
    if (jsonBytes == null) {
      throw const FormatException('Corrupt bundled content metadata');
    }
    final catalog = Curriculum.fromJson(
      jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>);
    catalog.assertCompatibleWith(await Curriculum.load());
    final checksum = sha256.convert(bytes).toString();
    return _installBytes(bytes, PackOffer(
      catalog.version,
      Uri.parse('https://bundled.invalid/starter_pack.zip'),
      checksum,
      bytes.length,
    ));
  }

  Future<PackOffer?> checkForUpdate(String currentVersion) async {
    if (manifestUrl.isEmpty) return null; // offline-only until an HTTPS URL is configured
    final uri = Uri.tryParse(manifestUrl);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
      throw const FormatException('The content URL must be HTTPS');
    }
    final data = await _readHttps(uri, 65536);
    final json = jsonDecode(utf8.decode(data));
    if (json is! Map<String,dynamic>) throw const FormatException('Invalid manifest');
    final offer = PackOffer.fromJson(json, uri);
    return offer.version == currentVersion ? null : offer;
  }

  Future<LoadedContent> install(PackOffer offer) async {
    final downloaded = await _readHttps(offer.url, maxDownloadBytes);
    if (downloaded.length != offer.bytes || sha256.convert(downloaded).toString() != offer.sha256) {
      throw const FormatException('Downloaded pack failed size or SHA-256 verification');
    }
    return _installBytes(downloaded, offer);
  }

  Future<LoadedContent> _installBytes(Uint8List downloaded, PackOffer offer) async {
    final root = await _root();
    await root.create(recursive: true);
    final identity = sha256.convert(utf8.encode(offer.version + offer.sha256))
        .toString().substring(0,20);
    final staging = Directory(root.path + '/' + identity + '_staging');
    final destination = Directory(root.path + '/' + identity);
    if (await staging.exists()) await staging.delete(recursive:true);
    await staging.create(recursive:true);
    try {
      final files = ZipDecoder().decodeBytes(downloaded, verify: true);
      if (files.length > 1000) throw const FormatException('Too many files');
      var size = 0;
      final seen = <String>{};
      for (final entry in files) {
        if (!entry.isFile) continue;
        final path = entry.name;
        if (!safeMember.hasMatch(path) || !seen.add(path) || entry.size > 2*1024*1024) {
          throw FormatException('Unexpected file in pack: '+path);
        }
        size += entry.size;
        if (size > maxUncompressedBytes) throw const FormatException('Pack is too large');
        final target = File(staging.path + '/' + path);
        await target.parent.create(recursive:true);
        final bytes = entry.readBytes();
        if (bytes == null) throw const FormatException('Corrupt ZIP entry');
        await target.writeAsBytes(bytes, flush:true);
      }
      final jsonFile = File(staging.path + '/words.json');
      if (!await jsonFile.exists()) throw const FormatException('Pack has no words.json');
      final catalog = Curriculum.fromJson(
        jsonDecode(await jsonFile.readAsString()) as Map<String,dynamic>);
      if (catalog.version != offer.version) throw const FormatException('Version mismatch');
      catalog.assertCompatibleWith(await Curriculum.load());
      _verifyFiles(catalog, staging);
      if (await destination.exists()) await destination.delete(recursive:true);
      await staging.rename(destination.path);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(activePackKey, identity);
      return LoadedContent(catalog, destination);
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive:true);
      rethrow;
    }
  }

  void _verifyFiles(Curriculum catalog, Directory base) {
    for (final word in catalog.words) {
      if (word.isDownloadedImage && !File(base.path + '/' + word.image).existsSync()) {
        throw FormatException('Missing image: '+word.image);
      }
      for (final frame in word.animationFrames) {
        if (!File(base.path + '/' + frame).existsSync()) {
          throw FormatException('Missing animation frame: '+frame);
        }
      }
    }
  }

  static Future<Uint8List> _readHttps(Uri uri, int maxBytes) async {
    final client = HttpClient()..connectionTimeout=const Duration(seconds:12);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds:16));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream, application/json');
      final response = await request.close().timeout(const Duration(seconds:16));
      if (response.statusCode != 200) {
        throw HttpException('Content server returned '+response.statusCode.toString());
      }
      final content = BytesBuilder(copy:false);
      var count = 0;
      await for (final chunk in response.timeout(const Duration(seconds:25))) {
        count += chunk.length;
        if (count > maxBytes) throw const FormatException('Content download exceeds limit');
        content.add(chunk);
      }
      return content.takeBytes();
    } finally {
      client.close(force:true);
    }
  }
}
