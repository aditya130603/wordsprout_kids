import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Private friends is discoverable by default. Parents can disable access,
/// while the actual online pairing still requires parent verification.
class FamilySettings extends StatefulWidget {
  const FamilySettings({super.key});
  static const leagueKey='family_friends_league_enabled_v1';
  static Future<bool> leagueEnabled() async =>
    (await SharedPreferences.getInstance()).getBool(leagueKey)??true;
  @override
  State<FamilySettings> createState()=>_FamilySettingsState();
}

class _FamilySettingsState extends State<FamilySettings>{
  bool league=true;
  bool loaded=false;
  @override
  void initState(){super.initState();_load();}
  Future<void> _load()async{
    final enabled=await FamilySettings.leagueEnabled();
    if(mounted)setState((){league=enabled;loaded=true;});
  }
  Future<void> _change(bool value)async{
    final prefs=await SharedPreferences.getInstance();
    await prefs.setBool(FamilySettings.leagueKey,value);
    if(mounted)setState(()=>league=value);
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:const Color(0xFFFFF8EB),
    appBar:AppBar(backgroundColor:const Color(0xFFFFF8EB),
      title:const Text('Family Settings',style:TextStyle(
        color:Color(0xFF24582E),fontWeight:FontWeight.w900))),
    body:SafeArea(child:ListView(
      padding:const EdgeInsets.all(20),children:[
        const Icon(Icons.family_restroom_rounded,size:56,color:Color(0xFF6CA53D)),
        const SizedBox(height:10),
        const Text('Your family, your choice.',textAlign:TextAlign.center,
          style:TextStyle(fontSize:24,color:Color(0xFF24582E),
            fontWeight:FontWeight.w900)),
        const SizedBox(height:18),
        Material(color:Colors.white,
          clipBehavior:Clip.antiAlias,
          shape:RoundedRectangleBorder(
            borderRadius:BorderRadius.circular(20),
            side:const BorderSide(color:Color(0xFFE4ECDD))),
          child:SwitchListTile.adaptive(
            key:const ValueKey('family_friends_toggle'),
            value:league,
            onChanged:loaded?_change:null,
            title:const Text('Friends League',style:TextStyle(
              fontWeight:FontWeight.w900,color:Color(0xFF24582E))),
            subtitle:const Text('Show the private friends leaderboard and allow online scoring on this device. Enabled by default; switch it off at any time.'),
            activeTrackColor:const Color(0xFFBFE5A7),
            activeThumbColor:const Color(0xFF407B32))),
        const SizedBox(height:15),
        Container(padding:const EdgeInsets.all(15),
          decoration:BoxDecoration(color:const Color(0xFFE9F3DE),
            borderRadius:BorderRadius.circular(17)),
          child:const Text('A child can learn and earn offline stars with Friends League off. Turning it on only makes the feature available; connecting an online child profile and approving friends still requires an adult. There is no public leaderboard or open chat.',
            style:TextStyle(color:Color(0xFF426C42),fontSize:14,height:1.5))),
        const SizedBox(height:20),
        const Text('Parent controls',style:TextStyle(color:Color(0xFF24582E),
          fontWeight:FontWeight.w900,fontSize:20)),
        const SizedBox(height:10),
        const Text('Friends can be removed from the private parent portal after an adult signs in. Turning the league off prevents new friend-score requests from this device. It does not delete the separate parent-controlled account on the server.',
          style:TextStyle(color:Color(0xFF60755A),height:1.5)),
      ])),
  );
}
