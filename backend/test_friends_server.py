"""Contract tests for parent-issued child pairing and private server scores.

Use a temporary SQLite database and a stubbed SMTP mailer; no real child or
guardian information leaves the test process.
"""
import os
import tempfile
from pathlib import Path
from fastapi.testclient import TestClient

DB_TEMP=tempfile.TemporaryDirectory()
os.environ["WORDSPROUT_LEAGUE_DB"]=str(Path(DB_TEMP.name)/"private.sqlite")
os.environ["WORDSPROUT_LEAGUE_SECRET"]="only-for-tests-a-long-64-character-secret-never-in-production"
from backend import friends_server as server

client=TestClient(server.app)
codes={}

def parent(email):
    server.mail_code=lambda to,code: codes.__setitem__(to,code)
    response=client.post("/v1/parent/request-code",json={"email":email})
    assert response.status_code==200,response.text
    response=client.post("/v1/parent/verify-code",
                         json={"email":email,"code":codes[email]})
    assert response.status_code==200,response.text
    return {"Authorization":"Bearer "+response.json()["parent_token"]}

def child_profile(headers,alias):
    response=client.post("/v1/parent/children",
      json={"alias":alias,"consent":True},headers=headers)
    assert response.status_code==200,response.text
    return response.json()["child_id"]

def pair(headers,child_id):
    code=client.post("/v1/parent/device-code",
      json={"child_id":child_id},headers=headers).json()["code"]
    response=client.post("/v1/child/connect",json={"code":code})
    assert response.status_code==200,response.text
    assert client.post("/v1/child/connect",json={"code":code}).status_code==401
    return {"Authorization":"Bearer "+response.json()["child_token"]}

def test_parent_gated_private_league():
    assert client.get("/health").json()["status"]=="ready"
    assert client.get("/v1/leaderboard").status_code==401
    a=parent("guardian-a@example.test")
    b=parent("guardian-b@example.test")
    assert client.post("/v1/parent/children",
      json={"alias":"Sunny Comet","consent":False},headers=a).status_code==400
    cid=child_profile(a,"Sunny Comet")
    fid=child_profile(b,"Golden Otter")
    child=pair(a,cid)
    friend=pair(b,fid)
    self_only=client.get("/v1/leaderboard",headers=child).json()["friends"]
    assert len(self_only)==1 and self_only[0]["is_me"]
    invite=client.post("/v1/parent/friend-invite",
      json={"child_id":cid},headers=a).json()["code"]
    denied=client.post("/v1/parent/friend-accept",
      json={"child_id":cid,"code":invite},headers=a)
    assert denied.status_code==400
    approved=client.post("/v1/parent/friend-accept",
      json={"child_id":fid,"code":invite},headers=b)
    assert approved.status_code==200
    assert len(client.get("/v1/leaderboard",headers=child).json()["friends"])==2
    # Guessing or repeatedly tapping never pays server-verified points.
    data={"mission_id":"ex_lantern","stage":"detective",
          "index":0,"response":"INVENTED"}
    wrong=client.post("/v1/answer",json=data,headers=child)
    assert wrong.json()["correct"] is False and wrong.json()["xp_awarded"]==0
    data["response"]="CURIOUS"
    right=client.post("/v1/answer",json=data,headers=child).json()
    assert right["correct"] is True and right["xp_awarded"]==4
    repeat=client.post("/v1/answer",json=data,headers=child).json()
    assert repeat["xp_awarded"]==0
    board=client.get("/v1/leaderboard",headers=friend).json()["friends"]
    assert board[0]["alias"]=="Sunny Comet" and board[0]["weekly_xp"]==4
    # Different child cannot claim an account from another parent.
    denied=client.post("/v1/parent/device-code",
      json={"child_id":cid},headers=b)
    assert denied.status_code==403
    # Parent can revoke a child's social account and all sessions.
    assert client.delete("/v1/parent/children/"+cid,headers=a).status_code==200
    assert client.get("/v1/leaderboard",headers=child).status_code==401
    assert client.get("/v1/leaderboard",headers=friend).status_code==200
