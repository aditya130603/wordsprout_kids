import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RewardGrant {
  const RewardGrant(this.points,{required this.alreadyClaimed});
  final int points;
  final bool alreadyClaimed;
}
class RewardEvent {
  const RewardEvent(this.points,this.day);
  final int points;
  final String day;
}
class RewardBadge {
  const RewardBadge(this.id,this.title,this.description,this.symbol,this.unlocked,this.progress,this.target);
  final String id,title,description,symbol;
  final bool unlocked;
  final int progress,target;
}
/// Offline learning XP cannot be farmed by repeatedly replaying a question.
/// Friend scores require separate server-side verification before publication.
class RewardLedger {
  RewardLedger._(this._prefs,this._events);
  static const storageKey='older_xp_events_v1';
  final SharedPreferences _prefs;
  final Map<String,RewardEvent> _events;

  static Future<RewardLedger> load() async {
    final prefs=await SharedPreferences.getInstance();
    final saved=prefs.getString(storageKey);
    final events=<String,RewardEvent>{};
    if(saved!=null) {
      try {
        final data=jsonDecode(saved) as Map<String,dynamic>;
        for(final entry in data.entries) {
          final info=entry.value;
          if(info is! Map<String,dynamic>)continue;
          final xp=info['xp'];
          final day=info['day'];
          if(xp is int&&xp>0&&xp<=25&&day is String&&
             RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)&&
             entry.key.length<=120) {
            events[entry.key]=RewardEvent(xp,day);
          }
        }
      }catch(_){ /* Broken reward data must never block learning. */ }
    }
    return RewardLedger._(prefs,events);
  }

  static String dayKey(DateTime day)=>
    day.year.toString().padLeft(4,'0')+'-'+
    day.month.toString().padLeft(2,'0')+'-'+
    day.day.toString().padLeft(2,'0');

  int get totalXp=>_events.values.fold(0,(sum,event)=>sum+event.points);
  int get earnedQuestionCount=>_events.keys.where((key)=>key.startsWith('answer:')).length;
  int get reviewCount=>_events.keys.where((key)=>key.startsWith('review:')).length;
  int get completedMissionCount=>_events.keys.where((key)=>key.startsWith('finish:')).length;
  int get perfectMissionCount=>_events.keys.where((key)=>key.startsWith('perfect:')).length;
  int pointsSince(DateTime start)=>_events.values
    .where((event)=>event.day.compareTo(dayKey(start))>=0)
    .fold(0,(sum,event)=>sum+event.points);
  int get thisWeekXp => pointsSince(_monday(DateTime.now()));
  static DateTime _monday(DateTime date) {
    final today=DateTime(date.year,date.month,date.day);
    return today.subtract(Duration(days:today.weekday-1));
  }

  Future<RewardGrant> _award(String key,int points,DateTime now) async {
    if(_events.containsKey(key)) return const RewardGrant(0,alreadyClaimed:true);
    if(points<1||points>25||key.length>120)throw ArgumentError('Invalid reward');
    _events[key]=RewardEvent(points,dayKey(now));
    await _prefs.setString(storageKey,jsonEncode(
      _events.map((k,v)=>MapEntry(k,{'xp':v.points,'day':v.day}))));
    return RewardGrant(points,alreadyClaimed:false);
  }

  Future<RewardGrant> answer({
    required String missionId, required String stage,
    required int index, required int wrongAttempts, DateTime? now,
  }) {
    if(!RegExp(r'^[a-z0-9_]+$').hasMatch(missionId)||
       !const {'detective','relation','sentence','pattern','transfer'}.contains(stage)||
       index<0||index>30||wrongAttempts<0) {
      throw ArgumentError('Unknown mission question');
    }
    final points=stage=='sentence'
      ?(wrongAttempts==0?15:6)
      :(wrongAttempts==0?10:4);
    return _award('answer:'+missionId+':'+stage+':'+index.toString(),
      points,now??DateTime.now());
  }

  Future<RewardGrant> finish(String missionId,{DateTime? now}) {
    if(!RegExp(r'^[a-z0-9_]+$').hasMatch(missionId))throw ArgumentError('Invalid mission');
    return _award('finish:'+missionId,20,now??DateTime.now());
  }
  Future<RewardGrant> perfect(String missionId,{DateTime? now}) {
    if(!RegExp(r'^[a-z0-9_]+$').hasMatch(missionId))throw ArgumentError('Invalid mission');
    return _award('perfect:'+missionId,10,now??DateTime.now());
  }

  /// Only correct recall is paid, once per word/day, capped at 50 XP/day.
  Future<RewardGrant> review(String word,{bool correct=true,DateTime? now}) {
    final date=now??DateTime.now();
    final dateString=dayKey(date);
    if(!correct)return Future.value(const RewardGrant(0,alreadyClaimed:false));
    if(!RegExp(r'^[A-Z][A-Z ]{1,31}$').hasMatch(word)) {
      throw ArgumentError('Invalid review word');
    }
    if(_events.entries
      .where((e)=>e.key.startsWith('review:'+dateString+':'))
      .fold<int>(0,(sum,e)=>sum+e.value.points)>=50) {
      return Future.value(const RewardGrant(0,alreadyClaimed:false));
    }
    return _award('review:'+dateString+':'+word,5,date);
  }

  List<RewardBadge> badges({int highestMissionStars=0}) {
    RewardBadge badge(String id,String title,String subtitle,String symbol,
        int current,int threshold) =>
      RewardBadge(id,title,subtitle,symbol,current>=threshold,current,threshold);
    return [
      badge('first_step','First Footprint','Finish your first story mission','footprints',
        completedMissionCount,1),
      badge('clue_finder','Clue Finder','Solve 10 word challenges','search',
        earnedQuestionCount,10),
      badge('story_scout','Story Scout','Finish three different missions','map',
        completedMissionCount,3),
      badge('triple_star','Three-Star Thinker','Earn 3 stars in a mission','star',
        highestMissionStars,3),
      badge('memory_keeper','Memory Keeper','Recall 10 vocabulary words','brain',
        reviewCount,10),
      badge('bright_spark','Bright Spark','Collect 100 learning XP','lightbulb',
        totalXp,100),
      badge('word_explorer','Word Explorer','Finish ten different missions','compass',
        completedMissionCount,10),
      badge('shining_mind','Shining Mind','Collect 500 learning XP','trophy',
        totalXp,500),
      badge('careful_champion','Careful Champion','Finish a mission without mistakes','shield',
        perfectMissionCount,1),
      badge('word_legend','Word Legend','Collect 1,000 learning XP','crown',
        totalXp,1000),
    ];
  }
}
