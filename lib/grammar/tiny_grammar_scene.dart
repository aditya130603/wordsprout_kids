import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Purpose-built light vector grammar scenes, drawn locally (no network,
/// emoji substitutions or mismatched recognizer pictures).
class TinyGrammarScene extends StatelessWidget {
  const TinyGrammarScene({super.key,required this.scene,this.height=170});
  final String scene;
  final double height;
  @override
  Widget build(BuildContext context)=>ClipRRect(
    borderRadius:BorderRadius.circular(24),
    child:SizedBox(width:double.infinity,height:height,
      child:CustomPaint(painter:_GrammarPainter(scene))));
}
class _GrammarPainter extends CustomPainter {
  const _GrammarPainter(this.scene);
  final String scene;
  static const dark=Color(0xFF55764F);
  static const ground=Color(0xFFACCF82);
  static const brown=Color(0xFFAF7856);
  static const blue=Color(0xFF75BBD0);
  static const red=Color(0xFFF18B70);
  static const cream=Color(0xFFFFF8E5);

  void rect(Canvas c,Rect r,Color color,{double radius=8}){
    c.drawRRect(RRect.fromRectAndRadius(r,Radius.circular(radius)),
      Paint()..color=color);
  }
  void circle(Canvas c,Offset o,double radius,Color color){
    c.drawCircle(o,radius,Paint()..color=color);
  }
  void line(Canvas c,Offset a,Offset b,Color color,double width){
    c.drawLine(a,b,Paint()..color=color..strokeWidth=width
      ..strokeCap=StrokeCap.round);
  }
  void face(Canvas c,double x,double y,double r){
    circle(c,Offset(x-r*.26,y-r*.13),r*.07,dark);
    circle(c,Offset(x+r*.26,y-r*.13),r*.07,dark);
    final smile=Path()..moveTo(x-r*.2,y+r*.1)
      ..quadraticBezierTo(x,y+r*.38,x+r*.2,y+r*.1);
    c.drawPath(smile,Paint()..color=dark..strokeWidth=r*.06
      ..strokeCap=StrokeCap.round..style=PaintingStyle.stroke);
  }
  void ball(Canvas c,double x,double y,double r){
    circle(c,Offset(x,y+r*.94),r*.70,const Color(0x448F8860));
    circle(c,Offset(x,y),r,red);
    circle(c,Offset(x-r*.31,y-r*.36),r*.28,const Color(0x75FFF5DA));
    face(c,x,y,r);
  }
  void box(Canvas c,double x,double y,double w,double h){
    rect(c,Rect.fromLTWH(x,y,w,h),const Color(0xFFD8A477),radius:7);
    line(c,Offset(x+3,y+3),Offset(x+w-3,y+3),const Color(0xFFB78054),3);
    line(c,Offset(x+w*.4,y),Offset(x+w*.4,y+h),const Color(0xFFCE9467),3);
    rect(c,Rect.fromLTWH(x+w*.52,y+h*.53,w*.36,h*.3),
      const Color(0x55FFFFFF),radius:3);
  }
  void tree(Canvas c,double x,double y,double r){
    rect(c,Rect.fromLTWH(x-r*.17,y+r*.2,r*.34,r*1.35),brown,radius:5);
    circle(c,Offset(x,y-r*.12),r*.78,const Color(0xFF5EA678));
    circle(c,Offset(x-r*.55,y+r*.12),r*.55,const Color(0xFF72B57D));
    circle(c,Offset(x+r*.53,y+r*.08),r*.57,const Color(0xFF6CAE78));
    for(final offset in [Offset(-.25,-.16),Offset(.38,-.23),Offset(.16,.27)]){
      circle(c,Offset(x+offset.dx*r,y+offset.dy*r),r*.065,
        const Color(0xFFFFD18B));
    }
  }
  void cloud(Canvas c,double x,double y,double scale) {
    final p=Paint()..color=const Color(0xB5FFFFFF);
    c.drawOval(Rect.fromCenter(center:Offset(x,y),width:scale*1.8,
      height:scale*.48),p);
    c.drawCircle(Offset(x-scale*.4,y-scale*.19),scale*.3,p);
    c.drawCircle(Offset(x+scale*.12,y-scale*.24),scale*.37,p);
  }
  void house(Canvas c,double x,double y,double w,double h){
    rect(c,Rect.fromLTWH(x,y,w,h),const Color(0xFFF0CEAD),radius:8);
    final roof=Path()..moveTo(x-8,y+3)..lineTo(x+w*.5,y-h*.34)
      ..lineTo(x+w+8,y+3)..close();
    c.drawPath(roof,Paint()..color=const Color(0xFFD88975));
    rect(c,Rect.fromLTWH(x+w*.37,y+h*.42,w*.27,h*.58),brown,radius:5);
    circle(c,Offset(x+w*.57,y+h*.73),3,cream);
    rect(c,Rect.fromLTWH(x+w*.13,y+h*.24,w*.18,h*.2),blue,radius:4);
  }
  void table(Canvas c,double x,double y,double w){
    rect(c,Rect.fromLTWH(x,y,w,13),brown,radius:6);
    rect(c,Rect.fromLTWH(x+12,y+10,10,58),
      const Color(0xFF9D7658),radius:4);
    rect(c,Rect.fromLTWH(x+w-22,y+10,10,58),
      const Color(0xFF9D7658),radius:4);
  }
  void cat(Canvas c,double x,double y,double s,{bool hidden=false}){
    if(hidden){circle(c,Offset(x,y),s*.7,const Color(0xFF56785B));}
    circle(c,Offset(x,y+s*.55),s*.48,const Color(0xFFF0B879));
    final ears=Path()..moveTo(x-s*.46,y-s*.2)..lineTo(x-s*.36,y-s*.82)
      ..lineTo(x-s*.02,y-s*.4)..lineTo(x+s*.35,y-s*.82)
      ..lineTo(x+s*.47,y-s*.17)..close();
    c.drawPath(ears,Paint()..color=const Color(0xFFE2A16C));
    circle(c,Offset(x,y),s*.51,const Color(0xFFF3C28D));
    face(c,x,y,s*.54);
    line(c,Offset(x+s*.29,y+s*.25),Offset(x+s*.73,y+s*.42),dark,1.4);
    line(c,Offset(x-s*.29,y+s*.25),Offset(x-s*.73,y+s*.42),dark,1.4);
    final tail=Path()..moveTo(x+s*.43,y+s*.54)
      ..quadraticBezierTo(x+s*1.12,y+s*.11,x+s*.85,y-s*.14);
    c.drawPath(tail,Paint()..strokeWidth=s*.18..color=const Color(0xFFE5AE74)
      ..style=PaintingStyle.stroke..strokeCap=StrokeCap.round);
  }
  void bird(Canvas c,double x,double y,double r) {
    circle(c,Offset(x,y),r,const Color(0xFF85B7D7));
    circle(c,Offset(x+r*.41,y-r*.46),r*.63,const Color(0xFF94C9E8));
    c.drawPath(Path()..moveTo(x+r*.9,y-r*.52)
      ..lineTo(x+r*1.38,y-r*.3)..lineTo(x+r*.9,y-r*.09)..close(),
      Paint()..color=const Color(0xFFF7C05D));
    circle(c,Offset(x+r*.59,y-r*.61),r*.095,dark);
    c.drawOval(Rect.fromCenter(center:Offset(x-r*.22,y+r*.14),
      width:r*1.1,height:r*.6),Paint()..color=const Color(0xFF71A3C8));
  }
  void kite(Canvas c,double x,double y,double r){
    final p=Path()..moveTo(x,y-r)..lineTo(x+r*.64,y)
      ..lineTo(x,y+r*.85)..lineTo(x-r*.64,y)..close();
    c.drawPath(p,Paint()..color=const Color(0xFFFFC46A));
    line(c,Offset(x,y-r),Offset(x,y+r*.85),const Color(0xFFE19C53),2);
    line(c,Offset(x-r*.64,y),Offset(x+r*.64,y),const Color(0xFFE19C53),2);
    final string=Path()..moveTo(x,y+r*.85)
      ..quadraticBezierTo(x+r*.2,y+r*1.7,x-r*.3,y+r*2.6);
    c.drawPath(string,Paint()..color=const Color(0xFFAD8565)
      ..style=PaintingStyle.stroke..strokeWidth=2);
  }
  void apple(Canvas c,double x,double y,double r){
    // Round apple silhouette with a recognisable stem and green leaf.
    circle(c,Offset(x-r*.30,y+r*.12),r*.68,const Color(0xFFE65B51));
    circle(c,Offset(x+r*.30,y+r*.12),r*.68,const Color(0xFFEA705B));
    c.drawOval(Rect.fromLTWH(x-r*.60,y-r*.24,r*.35,r*.49),
      Paint()..color=const Color(0x55FFE9D7));
    line(c,Offset(x,y-r*.54),Offset(x+r*.08,y-r*1.02),
      const Color(0xFF855A38),4);
    c.drawOval(Rect.fromCenter(
      center:Offset(x+r*.36,y-r*.91),width:r*.64,height:r*.32),
      Paint()..color=const Color(0xFF57A55F));
  }
  void lunchPlate(Canvas c,double x,double y,double r){
    c.drawOval(Rect.fromCenter(center:Offset(x,y),width:r*2.5,height:r*1.25),
      Paint()..color=const Color(0xFFFAF6ED));
    c.drawOval(Rect.fromCenter(center:Offset(x,y),width:r*1.8,height:r*.75),
      Paint()..color=const Color(0xFFF0C584));
    circle(c,Offset(x-r*.32,y),r*.28,const Color(0xFF7CBA5F));
    circle(c,Offset(x+r*.34,y-r*.06),r*.24,const Color(0xFFE98A59));
    line(c,Offset(x-r*1.55,y-r*.43),Offset(x-r*1.55,y+r*.40),
      const Color(0xFF819C8D),3.2);
  }
  void washHands(Canvas c,double x,double y,double r){
    rect(c,Rect.fromLTWH(x-r*.34,y-r*.10,r*.67,r*.85),
      const Color(0xFFF0B68E),radius:13);
    for(var i=0;i<4;i++){
      rect(c,Rect.fromLTWH(x-r*.34+i*r*.17,y-r*.55,r*.14,r*.57),
        const Color(0xFFF0B68E),radius:8);
    }
    for(var i=0;i<4;i++){
      final dx=(i-1.5)*r*.3;
      c.drawPath(Path()..moveTo(x+dx,y-r*.85)
        ..quadraticBezierTo(x+dx-r*.16,y-r*.60,x+dx,y-r*.54),
        Paint()..color=const Color(0xFF6FB9D4));
    }
  }
  void twoPanel(Canvas c,double w,double h,{required bool after}){
    rect(c,Rect.fromLTWH(w*.09,h*.30,w*.33,h*.49),
      const Color(0xDFFFFFFF),radius:17);
    rect(c,Rect.fromLTWH(w*.58,h*.30,w*.33,h*.49),
      const Color(0xDFFFFFFF),radius:17);
    if(after){
      lunchPlate(c,w*.255,h*.55,22);
      ball(c,w*.745,h*.54,25);
    }else{
      washHands(c,w*.255,h*.51,29);
      lunchPlate(c,w*.745,h*.55,22);
    }
    final p=Path()..moveTo(w*.44,h*.50)
      ..lineTo(w*.53,h*.50)
      ..lineTo(w*.50,h*.46)
      ..moveTo(w*.53,h*.50)
      ..lineTo(w*.50,h*.54);
    c.drawPath(p,Paint()..color=dark..strokeWidth=3
      ..strokeCap=StrokeCap.round..style=PaintingStyle.stroke);
  }
  void book(Canvas c,double x,double y){
    final p=Path()..moveTo(x,y)
      ..quadraticBezierTo(x-23,y-10,x-56,y-4)
      ..lineTo(x-56,y+33)..quadraticBezierTo(x-27,y+25,x,y+37)
      ..quadraticBezierTo(x+27,y+25,x+56,y+33)
      ..lineTo(x+56,y-4)..quadraticBezierTo(x+23,y-10,x,y)
      ..close();
    c.drawPath(p,Paint()..color=const Color(0xFFFAF9E8));
    line(c,Offset(x,y),Offset(x,y+37),brown,2);
    for(var i=0;i<3;i++) {
      line(c,Offset(x-48,y+9+i*8),Offset(x-13,y+12+i*8),
        const Color(0xFFACC8AE),1.5);
      line(c,Offset(x+13,y+12+i*8),Offset(x+48,y+9+i*8),
        const Color(0xFFACC8AE),1.5);
    }
  }
  void clock(Canvas c,double x,double y,double r){
    circle(c,Offset(x,y),r,const Color(0xFFEEB969));
    circle(c,Offset(x,y),r*.79,cream);
    line(c,Offset(x,y),Offset(x,y-r*.48),dark,3.2);
    line(c,Offset(x,y),Offset(x+r*.47,y+r*.21),dark,3.2);
    circle(c,Offset(x,y),r*.1,dark);
  }
  void bag(Canvas c,double x,double y,double w){
    rect(c,Rect.fromLTWH(x-w*.52,y,w,w*.93),const Color(0xFFDBA46D),radius:15);
    final handle=Path()..moveTo(x-w*.25,y+3)
      ..quadraticBezierTo(x,y-w*.34,x+w*.25,y+3);
    c.drawPath(handle,Paint()..color=brown..strokeWidth=5
      ..style=PaintingStyle.stroke);
  }
  void child(Canvas c,double x,double y,double r){
    circle(c,Offset(x,y),r*.68,const Color(0xFFF0B48C));
    circle(c,Offset(x-r*.16,y-r*.12),2.3,dark);
    circle(c,Offset(x+r*.2,y-r*.12),2.3,dark);
    final smile=Path()..moveTo(x-r*.12,y+r*.14)
      ..quadraticBezierTo(x,y+r*.27,x+r*.2,y+r*.14);
    c.drawPath(smile,Paint()..color=dark..style=PaintingStyle.stroke..strokeWidth=2);
    rect(c,Rect.fromLTWH(x-r*.7,y+r*.71,r*1.4,r*1.26),
      const Color(0xFF91B6D3),radius:11);
  }

  @override
  void paint(Canvas c,Size size) {
    final w=size.width,h=size.height;
    c.drawRect(Rect.fromLTWH(0,0,w,h),Paint()..shader=const LinearGradient(
      begin:Alignment.topCenter,end:Alignment.bottomCenter,
      colors:[Color(0xFFB5E5EE),Color(0xFFFFF2C9)]).createShader(
        Rect.fromLTWH(0,0,w,h)));
    cloud(c,w*.22,h*.17,22);
    cloud(c,w*.78,h*.25,17);
    c.drawPath(Path()..moveTo(0,h*.76)
      ..quadraticBezierTo(w*.41,h*.63,w,h*.76)
      ..lineTo(w,h)..lineTo(0,h)..close(),
      Paint()..color=ground);
    c.drawOval(Rect.fromCenter(center:Offset(w*.52,h*.92),
      width:w*.63,height:h*.10),Paint()..color=const Color(0x30917C4F));
    final mid=w*.51;
    switch(scene){
      case 'in':
        box(c,mid-52,h*.49,104,68);ball(c,mid,h*.60,23);break;
      case 'on':
        box(c,mid-52,h*.55,104,67);ball(c,mid,h*.55-23,23);break;
      case 'under':
        table(c,mid-90,h*.52,180);ball(c,mid,h*.81,23);break;
      case 'above':
        tree(c,w*.49,h*.57,h*.19);
        bird(c,w*.54,h*.15,19);break;
      case 'below':
        rect(c,Rect.fromLTWH(mid-96,h*.39,192,13),brown,radius:7);
        ball(c,mid,h*.77,24);break;
      case 'next_to':
        box(c,mid-76,h*.56,96,63);cat(c,mid+65,h*.65,28);break;
      case 'between':
        box(c,mid-118,h*.56,77,64);
        box(c,mid+41,h*.56,77,64);ball(c,mid,h*.71,24);break;
      case 'behind':
        cat(c,w*.46,h*.67,31);tree(c,w*.49,h*.43,48);break;
      case 'in_front':
        tree(c,w*.5,h*.38,46);cat(c,w*.5,h*.70,34);break;
      case 'near':
        house(c,mid-112,h*.40,112,75);tree(c,mid+67,h*.49,36);break;
      case 'here':
      case 'this':
        ball(c,mid-50,h*.65,40);
        child(c,w*.79,h*.48,31);break;
      case 'there':
      case 'that':
        ball(c,w*.76,h*.41,17);
        child(c,w*.23,h*.48,28);break;
      case 'clock':
        clock(c,mid,h*.48,48);break;
      case 'rain':
        cloud(c,mid,h*.30,58);
        for(var i=0;i<7;i++) {
          final x=mid-90+i*30.0;
          line(c,Offset(x,h*.42),Offset(x-9,h*.54),blue,2.2);
        }
        break;
      case 'kite':
        kite(c,mid,h*.32,38);break;
      case 'house':
        house(c,mid-60,h*.39,120,91);break;
      case 'at':
        house(c,mid-60,h*.39,120,91);
        rect(c,Rect.fromLTWH(mid-51,h*.48,102,20),
          const Color(0xFFF6EFDA),radius:4);
        final school=TextPainter(text:const TextSpan(
          text:'SCHOOL',style:TextStyle(color:dark,fontSize:14,
            fontWeight:FontWeight.w900)),textDirection:TextDirection.ltr)
          ..layout();
        school.paint(c,Offset(mid-school.width/2,h*.48+2));
        break;
      case 'child':
        child(c,mid,h*.38,39);break;
      case 'bag':
        bag(c,mid,h*.48,103);break;
      case 'ball':
        ball(c,mid,h*.58,35);break;
      case 'apple':
        apple(c,mid,h*.58,42);break;
      case 'before':
        twoPanel(c,w,h,after:false);break;
      case 'after':
        twoPanel(c,w,h,after:true);break;
      case 'now':
        child(c,mid,h*.34,32);
        book(c,mid,h*.76);break;
      default:
        ball(c,mid,h*.62,31);break;
    }
    for(var i=0;i<9;i++){
      final x=(i+1)*w/10;
      circle(c,Offset(x,h*(.84+math.sin(i*.7)*.03)),2.6,
        const Color(0xFFECF7B7));
    }
  }
  @override
  bool shouldRepaint(covariant _GrammarPainter old)=>old.scene!=scene;
}
