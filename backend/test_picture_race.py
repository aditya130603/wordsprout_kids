"""Functional server integration tests with fake families, no SMTP sent."""
from backend.test_friends_server import (
    client,parent,child_profile,pair,server)
from backend.picture_race import WORDS,tiles_for,ROUND_SECONDS

def make_friends():
    a=parent("race-parent-a@example.test")
    b=parent("race-parent-b@example.test")
    left=child_profile(a,"Brave Sparrow")
    right=child_profile(b,"Starry Panda")
    host=pair(a,left)
    visitor=pair(b,right)
    invite=client.post("/v1/parent/friend-invite",
        headers=a,json={"child_id":left}).json()["code"]
    result=client.post("/v1/parent/friend-accept",
        headers=b,json={"child_id":right,"code":invite})
    assert result.status_code==200
    return host,visitor

def test_random_letters_keep_repeats_and_do_not_present_solution_in_order():
    letters=tiles_for("ABC123",3,"left-kid","APPLE")
    assert len(letters)==8 # 5 word letters + 3 distinct distractors
    assert all(letters.count(ch)=="APPLE".count(ch) for ch in set("APPLE"))
    assert sorted(letter for letter in letters if letter not in word)==sorted(
        letter for letter in set(letters) if letter not in word)
    assert len([x for x in letters if x not in "APPLE"])==3
    assert letters[:5]!=list("APPLE")
    assert letters==tiles_for("ABC123",3,"left-kid","APPLE")
    large=tiles_for("ABCF34",1,"another","BALLOON")
    assert len(large)==11
    assert sorted(ch for ch in large if ch in "BALLOON")==sorted("BALLOON")
    assert len([x for x in large if x not in "BALLOON"])==4
    short=tiles_for("ABCF35",1,"another","ANT")
    assert len(short)==5

def test_approved_friends_share_a_round_and_first_answer_wins():
    host,guest=make_friends()
    start=client.post("/v1/race/rooms",headers=host,
        json={"furthest_letter":17})
    assert start.status_code==200,start.text
    code=start.json()["code"]
    joining=client.post("/v1/race/rooms/"+code+"/join",
        headers=guest,json={"furthest_letter":6})
    assert joining.status_code==200,joining.text
    lobby=client.get("/v1/race/rooms/"+code,headers=guest).json()
    assert lobby["ceiling_letter"]=="R"
    assert lobby["state"]=="lobby" and len(lobby["players"])==2
    assert client.post("/v1/race/rooms/"+code+"/start",headers=guest).status_code==403
    assert client.post("/v1/race/rooms/"+code+"/start",headers=host).status_code==200
    state=client.get("/v1/race/rooms/"+code,headers=guest).json()
    other=client.get("/v1/race/rooms/"+code,headers=host).json()
    assert state["state"]=="playing"
    assert state["word_index"]==other["word_index"]
    assert state["word_index"] < 18*5
    expected=WORDS[state["word_index"]]["word"]
    spelling=expected.replace(" ","").replace("-","")
    assert len(state["tiles"])>len(spelling)
    assert all(state["tiles"].count(ch)==spelling.count(ch) for ch in set(spelling))
    assert len([ch for ch in state["tiles"] if ch not in spelling])>=2
    assert state["tiles"][:len(spelling)]!=list(spelling)
    assert "answer" not in state
    win=client.post("/v1/race/rooms/"+code+"/answer",headers=guest,
        json={"round_index":1,"word":expected})
    assert win.status_code==200,win.text
    assert win.json()["first"] is True and win.json()["points"]==100
    duplicate=client.post("/v1/race/rooms/"+code+"/answer",headers=host,
        json={"round_index":1,"word":expected}).json()
    assert duplicate["round_closed"] is True and duplicate["first"] is False
    result=client.get("/v1/race/rooms/"+code,headers=host).json()
    assert result["state"]=="round_complete"
    assert result["winner_alias"]=="Starry Panda"
    assert result["answer"]==expected
    assert sum(p["points"] for p in result["players"])==100
    assert client.post("/v1/race/rooms/"+code+"/next",headers=guest).status_code==403
    assert client.post("/v1/race/rooms/"+code+"/next",headers=host).status_code==200
    next_round=client.get("/v1/race/rooms/"+code,headers=host).json()
    assert next_round["round_index"]==2
    assert next_round["word_index"]!=state["word_index"]

def test_strangers_and_invalid_progress_are_rejected():
    host=parent("race-owner@example.test")
    stranger=parent("race-stranger@example.test")
    left=child_profile(host,"Little Meteor")
    right=child_profile(stranger,"Silver Kite")
    h=pair(host,left)
    g=pair(stranger,right)
    room=client.post("/v1/race/rooms",headers=h,
        json={"furthest_letter":0}).json()["code"]
    denied=client.post("/v1/race/rooms/"+room+"/join",headers=g,
        json={"furthest_letter":25})
    assert denied.status_code==403
    invalid=client.post("/v1/race/rooms",headers=h,
        json={"furthest_letter":26})
    assert invalid.status_code==422
    unauthorized=client.get("/v1/race/rooms/"+room,headers=g)
    assert unauthorized.status_code==403
