import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LeagueEntry {
  const LeagueEntry({required this.alias,required this.weekXp,required this.isMe});
  final String alias;
  final int weekXp;
  final bool isMe;
}
class LeagueBoard {
  const LeagueBoard({required this.weekStart,required this.entries});
  final String weekStart;
  final List<LeagueEntry> entries;
}

/// Child-facing client: the parent creates the account in a separate adult
/// portal and gives a one-time device pairing code to the child. Token is
/// encrypted using Android Keystore, never SharedPreferences.
class FriendsApi {
  const FriendsApi();
  static const String endpoint=String.fromEnvironment('WORDSPROUT_FRIENDS_API_URL');
  static const FlutterSecureStorage _vault=FlutterSecureStorage(
    aOptions:AndroidOptions(encryptedSharedPreferences:true));
  static const tokenKey='wordsprout_private_child_session_v1';

  bool get configured {
    final u=Uri.tryParse(endpoint);
    return u!=null&&u.scheme=='https'&&u.host.isNotEmpty&&
      u.userInfo.isEmpty;
  }
  Uri _uri(String path) {
    if(!configured)throw StateError('Friends server is not configured');
    final u=Uri.parse(endpoint);
    return u.replace(path:path,query:null,fragment:null);
  }
  String get parentPortal => configured?_uri('/parents').toString():'';

  Future<bool> get paired async => (await _vault.read(key:tokenKey))?.isNotEmpty==true;

  Future<Map<String,dynamic>> _request(String method,String path,
      {Map<String,dynamic>? payload,bool authorized=true}) async {
    final client=HttpClient()..connectionTimeout=const Duration(seconds:8);
    try {
      final request=await client.openUrl(method,_uri(path))
        .timeout(const Duration(seconds:12));
      request.followRedirects=false;
      request.headers.set(HttpHeaders.acceptHeader,'application/json');
      if(authorized){
        final token=await _vault.read(key:tokenKey);
        if(token==null||token.isEmpty)throw StateError('Pair with a parent first');
        request.headers.set(HttpHeaders.authorizationHeader,'Bearer '+token);
      }
      if(payload!=null){
        request.headers.contentType=ContentType.json;
        request.write(jsonEncode(payload));
      }
      final response=await request.close().timeout(const Duration(seconds:14));
      final bytes=<int>[];
      await for(final chunk in response.timeout(const Duration(seconds:14))){
        bytes.addAll(chunk);
        if(bytes.length>65536)throw const FormatException('Response too large');
      }
      final data=jsonDecode(utf8.decode(bytes));
      if(data is! Map<String,dynamic>)throw const FormatException('Invalid league response');
      if(response.statusCode<200||response.statusCode>299){
        throw HttpException(data['detail']?.toString()??'League server unavailable');
      }
      return data;
    }finally{
      client.close(force:true);
    }
  }

  Future<void> connect(String code) async {
    if(!RegExp(r'^[A-Fa-f0-9]{10}$').hasMatch(code.trim())) {
      throw const FormatException('Enter the ten-character parent pairing code');
    }
    final result=await _request('POST','/v1/child/connect',
      payload:{'code':code.trim().toUpperCase()},authorized:false);
    final token=result['child_token'];
    if(token is! String || token.length<32){
      throw const FormatException('The server returned an invalid child session');
    }
    await _vault.write(key:tokenKey,value:token);
  }

  Future<void> disconnect() async => _vault.delete(key:tokenKey);

  Future<LeagueBoard> leaderboard() async {
    final data=await _request('GET','/v1/leaderboard');
    final entries=(data['friends'] as List).map((v){
      final e=v as Map<String,dynamic>;
      return LeagueEntry(
        alias:e['alias'] as String,
        weekXp:e['weekly_xp'] as int,
        isMe:e['is_me'] as bool);
    }).toList(growable:false);
    return LeagueBoard(weekStart:data['week_start_utc'] as String,entries:entries);
  }

  /// The server independently checks each answer against the authored
  /// curriculum and calculates points. Unverified offline XP never becomes
  /// public leaderboard XP; network failure never blocks a child from playing.
  Future<void> submitAnswer({
    required String missionId,required String stage,
    required int index,required String response,
  }) async {
    if(!configured)return;
    try{
      if(!await paired)return;
      await _request('POST','/v1/answer',payload:{
        'mission_id':missionId,'stage':stage,'index':index,'response':response
      });
    }catch(_){ /* Offline play must never be interrupted. */ }
  }
}
