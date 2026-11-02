import 'package:flutter/material.dart';
import 'learner_profile.dart';
import 'onboarding_flow.dart';

/// Routes the real first launch into the illustrated intro. Completed profiles
/// open the appropriate learning app on every subsequent launch.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key,required this.preschoolBuilder,
    required this.olderBuilder,this.skipOnboarding=false});
  final Widget Function() preschoolBuilder,olderBuilder;
  /// Existing Flutter screenshot tests can render Home without first-run UI.
  @visibleForTesting
  final bool skipOnboarding;
  @override
  State<OnboardingGate> createState()=>_OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  LearnerProfile? profile;
  bool loading=true;
  @override
  void initState(){
    super.initState();
    LearnerProfile.changed.addListener(_refresh);
    if(!widget.skipOnboarding)_refresh();
    else loading=false;
  }
  void _refresh(){
    LearnerProfile.load().then((value){
      if(mounted)setState((){profile=value;loading=false;});
    }).catchError((_){
      if(mounted)setState(()=>loading=false);
    });
  }
  @override
  void dispose(){
    LearnerProfile.changed.removeListener(_refresh);
    super.dispose();
  }
  @override
  Widget build(BuildContext context){
    if(widget.skipOnboarding)return widget.preschoolBuilder();
    if(loading)return const Scaffold(
      backgroundColor:Color(0xFFFFFAF0),
      body:Center(child:CircularProgressIndicator(color:Color(0xFF69AC29))));
    if(profile==null)return WordSproutOnboarding(
      onFinished:(newProfile)=>setState(()=>profile=newProfile));
    return KeyedSubtree(key:ValueKey('learner_'+profile!.ageGroup),
      child:profile!.older?widget.olderBuilder():widget.preschoolBuilder());
  }
}
