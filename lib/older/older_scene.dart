import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Original lightweight illustrated environments drawn on-device, not emoji
/// placeholder art. The same missions keep their backgrounds while offline.
class StoryScene extends StatelessWidget {
  const StoryScene({super.key,required this.scene,this.height=188,this.outcome});
  final String scene;
  final double height;
  final bool? outcome;

  @override
  Widget build(BuildContext context)=>ClipRRect(
    borderRadius:BorderRadius.circular(25),
    child:SizedBox(height:height,width:double.infinity,
      child:CustomPaint(painter:_ScenePainter(scene,outcome))),
  );
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter(this.scene,this.outcome);
  final String scene;
  final bool? outcome;
  static const ink=Color(0xFF2C514A);

  @override
  void paint(Canvas canvas,Size size){
    final w=size.width,h=size.height;
    final isNight=scene=='forest'||scene=='cave'||scene=='library';
    final sky=Paint()..shader=LinearGradient(
      begin:Alignment.topCenter,end:Alignment.bottomCenter,
      colors:isNight?[const Color(0xFF254D70),const Color(0xFF7EA6B5)]:
        [const Color(0xFF9FCEE3),const Color(0xFFF3D7AB)]).createShader(
      Rect.fromLTWH(0,0,w,h));
    canvas.drawRect(Rect.fromLTWH(0,0,w,h),sky);
    final light=Paint()..color=isNight?const Color(0xFFFFE2A1):const Color(0xFFFFD57E);
    canvas.drawCircle(Offset(w*.82,h*.19),h*.088,light);
    canvas.drawCircle(Offset(w*.82,h*.19),h*.13,
      Paint()..color=const Color(0x18FFE5AD));

    for(var i=0;i<4;i++){
      final x=w*(.12+i*.27),y=h*(.20+(i%2)*.1);
      _cloud(canvas,x,y,w*.12,isNight);
    }

    final hill1=Path()
      ..moveTo(0,h*.69)
      ..quadraticBezierTo(w*.20,h*.41,w*.43,h*.69)
      ..quadraticBezierTo(w*.66,h*.52,w,h*.64)
      ..lineTo(w,h)..lineTo(0,h)..close();
    canvas.drawPath(hill1,Paint()..color=isNight?const Color(0xFF427A75):const Color(0xFF8DBB89));
    final hill2=Path()
      ..moveTo(0,h*.86)
      ..quadraticBezierTo(w*.32,h*.63,w*.58,h*.82)
      ..quadraticBezierTo(w*.81,h*.69,w,h*.78)
      ..lineTo(w,h)..lineTo(0,h)..close();
    canvas.drawPath(hill2,Paint()..color=isNight?const Color(0xFF305D58):const Color(0xFF6FAE83));
    canvas.drawOval(Rect.fromCenter(center:Offset(w*.50,h*.99),width:w*.68,height:h*.16),
      Paint()..color=const Color(0x32614D3D));

    switch(scene){
      case 'forest':_forest(canvas,w,h,true);break;
      case 'river':_river(canvas,w,h);break;
      case 'garden':_garden(canvas,w,h);break;
      case 'town':_town(canvas,w,h);break;
      case 'cave':_cave(canvas,w,h);break;
      case 'festival':_town(canvas,w,h);_lanterns(canvas,w,h);break;
      case 'library':_library(canvas,w,h);break;
      case 'mountain':_mountain(canvas,w,h);break;
      case 'workshop':_workshop(canvas,w,h);break;
      default:_forest(canvas,w,h,false);break;
    }
    if(outcome==true) {
      for(var i=0;i<8;i++){
        final x=w*(.13+(i*.111)),y=h*(.13+(i%3)*.14);
        canvas.drawCircle(Offset(x,y),2.6,Paint()..color=const Color(0xFFFBE4A7));
      }
    }
    if(outcome==false) {
      final p=Paint()..color=const Color(0x556B4B46);
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0,h*.78,w,h*.22),const Radius.circular(12)),p);
    }
  }

  void _cloud(Canvas c,double x,double y,double width,bool night){
    final p=Paint()..color=night?const Color(0x33F7F5E6):const Color(0xAADCECF1);
    c.drawOval(Rect.fromCenter(center:Offset(x,y),width:width*1.4,height:width*.35),p);
    c.drawCircle(Offset(x-width*.24,y-width*.12),width*.24,p);
    c.drawCircle(Offset(x+width*.13,y-width*.13),width*.3,p);
  }

  void _tree(Canvas c,double x,double y,double radius,Color leaves){
    final bark=Paint()..color=const Color(0xFF80654A);
    c.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(x-radius*.12,y-radius*.1,radius*.24,radius*1.25),
      const Radius.circular(6)),bark);
    final p=Paint()..color=leaves;
    c.drawCircle(Offset(x,y-radius*.34),radius*.70,p);
    c.drawCircle(Offset(x-radius*.40,y),radius*.58,p);
    c.drawCircle(Offset(x+radius*.44,y-radius*.05),radius*.56,p);
    c.drawCircle(Offset(x,y-radius*.3),radius*.37,
      Paint()..color=const Color(0x2152D6A5));
  }

  void _forest(Canvas c,double w,double h,bool lantern){
    _tree(c,w*.13,h*.59,h*.23,const Color(0xFF306B58));
    _tree(c,w*.92,h*.56,h*.28,const Color(0xFF306B58));
    _tree(c,w*.28,h*.72,h*.16,const Color(0xFF3B795D));
    final path=Path()..moveTo(w*.26,h)..quadraticBezierTo(w*.59,h*.77,w*.53,h*.61)
      ..lineTo(w*.66,h*.61)..quadraticBezierTo(w*.75,h*.84,w*.64,h)..close();
    c.drawPath(path,Paint()..color=const Color(0xFFC5AA83));
    if(lantern) {
      c.drawLine(Offset(w*.65,h*.42),Offset(w*.65,h*.63),
        Paint()..color=const Color(0xFF4D4E45)..strokeWidth=3);
      c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w*.625,h*.59,w*.055,h*.17),const Radius.circular(3)),
        Paint()..color=const Color(0xFFF3CB75));
      c.drawCircle(Offset(w*.65,h*.68),h*.10,
        Paint()..color=const Color(0x33FFEABA));
    }
  }

  void _river(Canvas c,double w,double h){
    final stream=Path()
      ..moveTo(w*.48,h*.56)..quadraticBezierTo(w*.20,h*.75,w*.28,h)
      ..lineTo(w*.84,h)..quadraticBezierTo(w*.60,h*.81,w*.73,h*.64)..close();
    c.drawPath(stream,Paint()..color=const Color(0xFF72B4C6));
    for(var i=0;i<4;i++) {
      c.drawArc(Rect.fromLTWH(w*(.34+i*.1),h*(.64+i*.065),w*.07,h*.04),
        0,math.pi,false,Paint()..color=const Color(0xFFD3F1E9)
          ..strokeWidth=2..style=PaintingStyle.stroke);
    }
    _tree(c,w*.13,h*.61,h*.19,const Color(0xFF518E72));
    _tree(c,w*.88,h*.56,h*.22,const Color(0xFF44836A));
    c.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w*.03,h*.82,w*.21,h*.07),const Radius.circular(9)),
      Paint()..color=const Color(0xFFDBBD90));
  }
  void _garden(Canvas c,double w,double h){
    for(var i=0;i<5;i++){
      final x=w*(.19+i*.17),y=h*(.83+(i%2)*.045);
      c.drawLine(Offset(x,y),Offset(x,y-h*.15),
        Paint()..color=const Color(0xFF316F52)..strokeWidth=4);
      for(var k=0;k<5;k++){
        final a=k*2*math.pi/5;
        c.drawCircle(Offset(x+math.cos(a)*9,y-h*.18+math.sin(a)*9),
          5.5,Paint()..color=const Color(0xFFF3D2A8));
      }
      c.drawCircle(Offset(x,y-h*.18),5,Paint()..color=const Color(0xFFE7A76B));
    }
    _tree(c,w*.13,h*.56,h*.22,const Color(0xFF51906F));
    _tree(c,w*.94,h*.60,h*.19,const Color(0xFF639D76));
  }
  void _building(Canvas c,double x,double y,double width,double height,Color color){
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,y,width,height),
      const Radius.circular(6)),Paint()..color=color);
    c.drawPath(Path()..moveTo(x-width*.10,y)..lineTo(x+width*.5,y-height*.27)
      ..lineTo(x+width*1.1,y)..close(),
      Paint()..color=const Color(0xFFBA725D));
    for(var i=0;i<2;i++){
      for(var j=0;j<2;j++){
        c.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(x+width*(.18+j*.43),y+height*(.20+i*.36),
            width*.19,height*.16),const Radius.circular(3)),
          Paint()..color=const Color(0xFFF8DCAA));
      }
    }
  }
  void _town(Canvas c,double w,double h){
    _building(c,w*.12,h*.49,w*.22,h*.38,const Color(0xFFF2C5A4));
    _building(c,w*.41,h*.34,w*.29,h*.48,const Color(0xFFF4D5A9));
    _building(c,w*.77,h*.48,w*.19,h*.35,const Color(0xFFDFAD9A));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.02,h*.89,w*.96,h*.07),
      const Radius.circular(10)),Paint()..color=const Color(0xFFD4BD95));
  }
  void _lanterns(Canvas c,double w,double h){
    final wire=Path()..moveTo(0,h*.22)..quadraticBezierTo(w*.50,h*.40,w,h*.18);
    c.drawPath(wire,Paint()..color=ink..style=PaintingStyle.stroke..strokeWidth=2);
    for(var i=0;i<7;i++){
      final x=w*(.10+i*.133),y=h*(.26-(i-3).abs()*.012);
      c.drawLine(Offset(x,y),Offset(x,y+h*.12),
        Paint()..color=const Color(0xFF5A6453)..strokeWidth=1.8);
      c.drawOval(Rect.fromCenter(center:Offset(x,y+h*.15),width:16,height:23),
        Paint()..color=i.isEven?const Color(0xFFF7C16E):const Color(0xFFE88E81));
    }
  }
  void _cave(Canvas c,double w,double h){
    final p=Path()..moveTo(0,0)..lineTo(w*.35,0)..lineTo(w*.24,h*.38)
      ..lineTo(w*.40,h*.53)..lineTo(w*.29,h*.75)..lineTo(w*.05,h*.92)
      ..lineTo(0,h)..close();
    c.drawPath(p,Paint()..color=const Color(0xFF485C67));
    final p2=Path()..moveTo(w,0)..lineTo(w*.78,0)..lineTo(w*.70,h*.28)
      ..lineTo(w*.83,h*.49)..lineTo(w*.72,h*.73)..lineTo(w,h*.83)..close();
    c.drawPath(p2,Paint()..color=const Color(0xFF506675));
    c.drawLine(Offset(w*.28,h*.84),Offset(w*.72,h*.84),
      Paint()..color=const Color(0xFFD7AB75)..strokeWidth=15);
    for(var i=0;i<6;i++){
      final x=w*(.31+i*.07);
      c.drawLine(Offset(x,h*.80),Offset(x,h*.90),
        Paint()..color=const Color(0xFF806E63)..strokeWidth=6);
    }
  }
  void _library(Canvas c,double w,double h){
    c.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w*.10,h*.16,w*.80,h*.68),const Radius.circular(12)),
      Paint()..color=const Color(0xFF795F55));
    for(var shelf=0;shelf<3;shelf++){
      final y=h*(.28+shelf*.18);
      for(var book=0;book<13;book++){
        final x=w*(.15+book*.056);
        c.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(x,y,w*.043,h*.14),const Radius.circular(2)),
          Paint()..color=[const Color(0xFFBC9F79),
            const Color(0xFF729A9D),const Color(0xFFD59C84),
            const Color(0xFFAAC18D)][(book+shelf)%4]);
      }
      c.drawLine(Offset(w*.14,y+h*.16),Offset(w*.86,y+h*.16),
        Paint()..color=const Color(0xFFE6C398)..strokeWidth=5);
    }
  }
  void _mountain(Canvas c,double w,double h){
    for(var i=0;i<3;i++){
      final x=w*(i*.45-.16),top=h*(.22+i*.09);
      final p=Path()..moveTo(x,h*.82)..lineTo(x+w*.43,top)
        ..lineTo(x+w*.88,h*.82)..close();
      c.drawPath(p,Paint()..color=[
        const Color(0xFF647E83),const Color(0xFF789498),
        const Color(0xFF587D87)][i]);
      c.drawPath(Path()..moveTo(x+w*.29,top+h*.16)..lineTo(x+w*.43,top)
        ..lineTo(x+w*.58,top+h*.16)..lineTo(x+w*.50,top+h*.11)
        ..lineTo(x+w*.43,top+h*.13)..lineTo(x+w*.36,top+h*.11)..close(),
        Paint()..color=const Color(0xFFEDF1E7));
    }
    _tree(c,w*.14,h*.81,h*.12,const Color(0xFF3F795B));
    _tree(c,w*.88,h*.82,h*.11,const Color(0xFF4E825F));
  }
  void _workshop(Canvas c,double w,double h){
    _building(c,w*.10,h*.28,w*.80,h*.58,const Color(0xFFBCB09E));
    for(var i=0;i<3;i++){
      final x=w*(.30+i*.20),y=h*.58;
      c.drawCircle(Offset(x,y),h*.10,Paint()..color=const Color(0xFF648F90));
      c.drawCircle(Offset(x,y),h*.043,Paint()..color=const Color(0xFFDEC8A1));
    }
    c.drawRect(Rect.fromLTWH(w*.23,h*.76,w*.54,h*.08),
      Paint()..color=const Color(0xFF956A52));
  }
  @override
  bool shouldRepaint(covariant _ScenePainter old)=>old.scene!=scene||old.outcome!=outcome;
}
