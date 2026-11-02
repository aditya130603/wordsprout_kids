import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only child nickname and learning path. Never synchronized to friends
/// league or forwarded to the leaderboard service.
class LearnerProfile {
  const LearnerProfile({required this.name,required this.ageGroup,
    this.track='explorer'});
  final String name;
  final String ageGroup;
  final String track;
  bool get older=>ageGroup=='6-12';

  static const doneKey='wordsprout_onboarding_done_v1';
  static const nameKey='wordsprout_learner_name_v1';
  static const ageKey='wordsprout_learner_age_v1';
  static const trackKey='older_selected_track';

  /// Listened to by the root router, so switching ages in Family Settings
  /// immediately opens the appropriate curriculum, without resetting progress.
  static final ValueNotifier<int> changed=ValueNotifier<int>(0);

  static String? validateName(String value){
    final cleaned=value.trim();
    if(cleaned.isEmpty)return 'Add your name or a fun nickname to begin.';
    if(cleaned.runes.length>20)return 'Use 20 characters or fewer.';
    if(RegExp(r'[\u0000-\u001F\u007F]').hasMatch(cleaned)){
      return 'Please enter a short nickname without line breaks.';
    }
    return null;
  }

  Future<void> save() async{
    if(validateName(name)!=null)throw ArgumentError('Invalid learner nickname');
    if(ageGroup!='4-6'&&ageGroup!='6-12'){
      throw ArgumentError('Invalid learner age group');
    }
    if(!['explorer','adventurer','master'].contains(track)){
      throw ArgumentError('Unknown older learning path');
    }
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString(nameKey,name.trim());
    await prefs.setString(ageKey,ageGroup);
    await prefs.setString(trackKey,track);
    // Write the completion marker last: a partly saved onboarding profile
    // must never bypass a later launch's name/age selection.
    await prefs.setBool(doneKey,true);
    changed.value++;
  }

  static Future<LearnerProfile?> load()async{
    final prefs=await SharedPreferences.getInstance();
    if(prefs.getBool(doneKey)==true){
      final name=prefs.getString(nameKey)??'';
      final age=prefs.getString(ageKey)??'';
      final track=prefs.getString(trackKey)??'explorer';
      if(validateName(name)==null&&(age=='4-6'||age=='6-12')){
        return LearnerProfile(name:name,ageGroup:age,
          track:['explorer','adventurer','master'].contains(track)?
            track:'explorer');
      }
    }
    // Preserve legacy user progress. Children already playing the old app
    // should not be locked out by the new onboarding requirement.
    final hasPreschool=(prefs.getStringList('done')??const <String>[]).isNotEmpty ||
      (prefs.getStringList('checkpoints')??const <String>[]).isNotEmpty ||
      (prefs.getStringList('grammar_4_6_stars_v1')??const <String>[]).isNotEmpty;
    final hasOlder=(prefs.getStringList('older_stars')??const <String>[]).isNotEmpty;
    if(hasPreschool||hasOlder){
      final track=prefs.getString(trackKey)??'explorer';
      final legacy=LearnerProfile(
        name:'Explorer',ageGroup:hasOlder&&!hasPreschool?'6-12':'4-6',
        track:['explorer','adventurer','master'].contains(track)?
          track:'explorer');
      // Use a generic local nickname rather than guessing a child's name.
      await legacy.save();
      return legacy;
    }
    return null;
  }
}
