"""Picture Race: private simultaneous multiplayer for ages 4–6.

Only paired children with a parent-approved friendship (or the same parent)
can join. The backend is authoritative for timing, first-winner status,
shuffling, and points. Rooms use the furthest learner's A–Z letter as the
word-pool ceiling, as requested for the WordSprout launch pilot.
"""
import hashlib
import hmac
import json
import random
import secrets
import sqlite3
import time
from pathlib import Path

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

router=APIRouter(prefix="/v1/race",tags=["picture-race"])
WORDS=json.loads((Path(__file__).resolve().parents[1]/
    "assets/content/words_v1.json").read_text())["words"][:130]
MAX_PLAYERS=6
TOTAL_ROUNDS=5
ROUND_SECONDS=45
LETTERS="ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

def auth(authorization):
    from backend.friends_server import bearer
    return bearer(authorization,"child")

def connection():
    from backend.friends_server import db
    return db()

def init():
    with connection() as c:
        c.executescript("""
        CREATE TABLE IF NOT EXISTS race_rooms(
          code TEXT PRIMARY KEY,host_child TEXT NOT NULL,
          state TEXT NOT NULL,round_index INTEGER NOT NULL DEFAULT 0,
          word_index INTEGER,started_at REAL,finished_at REAL,
          winner TEXT,used TEXT NOT NULL DEFAULT '[]',
          created_at INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS race_players(
          code TEXT NOT NULL,child_id TEXT NOT NULL,
          furthest_letter INTEGER NOT NULL CHECK(furthest_letter BETWEEN 0 AND 25),
          points INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY(code,child_id));
        CREATE TABLE IF NOT EXISTS race_attempts(
          code TEXT NOT NULL,round_index INTEGER NOT NULL,
          child_id TEXT NOT NULL,wrong INTEGER NOT NULL DEFAULT 0,
          updated_at REAL NOT NULL DEFAULT 0,
          PRIMARY KEY(code,round_index,child_id));
        """)

class Progress(BaseModel):
    furthest_letter:int=Field(ge=0,le=25)

class Guess(BaseModel):
    round_index:int=Field(ge=1,le=TOTAL_ROUNDS)
    word:str=Field(min_length=2,max_length=24)

def get_room(c,code,child):
    room=c.execute("SELECT * FROM race_rooms WHERE code=?",(code,)).fetchone()
    if not room:raise HTTPException(404,"Room not found or expired")
    joined=c.execute("SELECT 1 FROM race_players WHERE code=? AND child_id=?",
                     (code,child)).fetchone()
    if not joined:raise HTTPException(403,"You are not in this room")
    return room

def is_friend(c,child,host):
    p=c.execute("SELECT parent_id FROM children WHERE id=?",(child,)).fetchone()
    q=c.execute("SELECT parent_id FROM children WHERE id=?",(host,)).fetchone()
    if not p or not q:return False
    if p["parent_id"]==q["parent_id"]:return True
    a,b=sorted((child,host))
    return c.execute("SELECT 1 FROM friendships WHERE a=? AND b=?",
                     (a,b)).fetchone() is not None

def furthest(c,code):
    return c.execute("SELECT MAX(furthest_letter) n FROM race_players WHERE code=?",
                     (code,)).fetchone()["n"]

def select_word(c,room):
    upto=(furthest(c,room["code"])+1)*5
    used=set(json.loads(room["used"]))
    candidates=[i for i in range(upto) if i not in used]
    if not candidates:candidates=list(range(upto))
    return secrets.choice(candidates)

def expire_round(c,room):
    if room["state"]=="playing" and room["started_at"] is not None:
        if time.time()>=room["started_at"]+ROUND_SECONDS:
            c.execute("UPDATE race_rooms SET state='round_complete',finished_at=? WHERE code=? AND state='playing'",
                      (time.time(),room["code"]))
            return c.execute("SELECT * FROM race_rooms WHERE code=?",(room["code"],)).fetchone()
    return room

def tiles_for(code,round_index,child,word):
    """Fixed unique tile order for each child for the whole round."""
    from backend.friends_server import SECRET
    text=f"{code}:{round_index}:{child}:picture-race".encode()
    digest=hmac.new(SECRET.encode(),text,hashlib.sha256).digest()
    tiles=list(word)
    random.Random(int.from_bytes(digest[:16],"big")).shuffle(tiles)
    if tiles==list(word) and len(set(word))>1:
        tiles=list(reversed(tiles))
        if tiles==list(word):
            tiles=tiles[1:]+tiles[:1]
    return tiles

@router.post("/rooms")
def create_room(progress:Progress,authorization:str|None=Header(None)):
    child=auth(authorization)
    init()
    now=int(time.time())
    with connection() as c:
        # Remove expired rooms and associated records.
        stale=c.execute("SELECT code FROM race_rooms WHERE created_at<?",
                        (now-24*3600,)).fetchall()
        for r in stale:
            c.execute("DELETE FROM race_players WHERE code=?",(r["code"],))
            c.execute("DELETE FROM race_attempts WHERE code=?",(r["code"],))
            c.execute("DELETE FROM race_rooms WHERE code=?",(r["code"],))
        for _ in range(12):
            code="".join(secrets.choice(LETTERS) for _ in range(6))
            if not c.execute("SELECT 1 FROM race_rooms WHERE code=?",(code,)).fetchone():
                break
        else:raise HTTPException(503,"Could not create a room")
        c.execute("INSERT INTO race_rooms (code,host_child,state,created_at) VALUES (?,?,'lobby',?)",
                  (code,child,now))
        c.execute("INSERT INTO race_players (code,child_id,furthest_letter) VALUES (?,?,?)",
                  (code,child,progress.furthest_letter))
    return {"code":code,"status":"lobby"}

@router.post("/rooms/{code}/join")
def join(code:str,progress:Progress,authorization:str|None=Header(None)):
    child=auth(authorization)
    with connection() as c:
        c.execute("BEGIN IMMEDIATE")
        room=c.execute("SELECT * FROM race_rooms WHERE code=?",(code,)).fetchone()
        if not room:raise HTTPException(404,"Room not found")
        already=c.execute("SELECT 1 FROM race_players WHERE code=? AND child_id=?",
                          (code,child)).fetchone()
        if already:return {"code":code,"status":room["state"]}
        if room["state"]!="lobby":raise HTTPException(409,"Game already started")
        if not is_friend(c,child,room["host_child"]):
            raise HTTPException(403,"Only parent-approved friends can join")
        count=c.execute("SELECT COUNT(*) n FROM race_players WHERE code=?",
                        (code,)).fetchone()["n"]
        if count>=MAX_PLAYERS:raise HTTPException(409,"Room is full")
        c.execute("INSERT INTO race_players (code,child_id,furthest_letter) VALUES (?,?,?)",
                  (code,child,progress.furthest_letter))
    return {"code":code,"status":"lobby"}

@router.get("/rooms/{code}")
def room_state(code:str,authorization:str|None=Header(None)):
    child=auth(authorization)
    with connection() as c:
        c.execute("BEGIN IMMEDIATE")
        room=expire_round(c,get_room(c,code,child))
        rows=c.execute("""SELECT p.child_id,p.points,p.furthest_letter,
            ch.alias FROM race_players p JOIN children ch ON ch.id=p.child_id
            WHERE p.code=? ORDER BY p.points DESC,ch.alias""",(code,)).fetchall()
        ceiling=furthest(c,code)
        result={
            "code":code,"state":room["state"],"round_index":room["round_index"],
            "total_rounds":TOTAL_ROUNDS,"ceiling_letter":chr(65+ceiling),
            "is_host":room["host_child"]==child,
            "seconds_left":max(0,ROUND_SECONDS-(time.time()-(room["started_at"] or time.time()))) if room["state"]=="playing" else 0,
            "players":[{"alias":r["alias"],"points":r["points"],
                        "furthest_letter":chr(65+r["furthest_letter"]),
                        "is_me":r["child_id"]==child,
                        "is_winner":r["child_id"]==room["winner"]} for r in rows],
        }
        if room["word_index"] is not None:
            word=WORDS[room["word_index"]]
            result["word_index"]=room["word_index"]
            result["tiles"]=tiles_for(code,room["round_index"],child,
                                      word["word"].replace(" ","").replace("-",""))
            if room["state"]!="playing":
                result["answer"]=word["word"]
                result["winner_alias"]=next((r["alias"] for r in rows
                    if r["child_id"]==room["winner"]),None)
        return result

@router.post("/rooms/{code}/start")
def start(code:str,authorization:str|None=Header(None)):
    child=auth(authorization)
    with connection() as c:
        c.execute("BEGIN IMMEDIATE")
        room=get_room(c,code,child)
        if room["host_child"]!=child:raise HTTPException(403,"Only the host can start")
        if room["state"]!="lobby":raise HTTPException(409,"Room already started")
        n=c.execute("SELECT COUNT(*) n FROM race_players WHERE code=?",
                    (code,)).fetchone()["n"]
        if n<2:raise HTTPException(409,"Invite at least one friend")
        chosen=select_word(c,room)
        c.execute("""UPDATE race_rooms SET state='playing',round_index=1,
            word_index=?,used=?,started_at=?,winner=NULL WHERE code=?""",
            (chosen,json.dumps([chosen]),time.time(),code))
    return {"started":True}

@router.post("/rooms/{code}/answer")
def submit(code:str,body:Guess,authorization:str|None=Header(None)):
    child=auth(authorization)
    guess=body.word.upper().replace(" ","").replace("-","")
    with connection() as c:
        c.execute("BEGIN IMMEDIATE")
        room=expire_round(c,get_room(c,code,child))
        if room["state"]!="playing" or room["round_index"]!=body.round_index:
            return {"correct":False,"round_closed":True,"first":False}
        expected=WORDS[room["word_index"]]["word"].replace(" ","").replace("-","")
        attempt=c.execute("""SELECT wrong,updated_at FROM race_attempts
          WHERE code=? AND round_index=? AND child_id=?""",
          (code,body.round_index,child)).fetchone()
        errors=attempt["wrong"] if attempt else 0
        if errors>=3:raise HTTPException(429,"Try again next round")
        if attempt and time.time()-attempt["updated_at"]<.5:
            raise HTTPException(429,"Take a moment before trying again")
        if guess!=expected:
            c.execute("""INSERT INTO race_attempts VALUES (?,?,?,?,?)
              ON CONFLICT(code,round_index,child_id)
              DO UPDATE SET wrong=wrong+1,updated_at=excluded.updated_at""",
              (code,body.round_index,child,1,time.time()))
            return {"correct":False,"round_closed":False,"first":False,
                    "tries_left":2-errors}
        c.execute("""UPDATE race_rooms SET state='round_complete',winner=?,
          finished_at=? WHERE code=? AND state='playing'""",
          (child,time.time(),code))
        c.execute("UPDATE race_players SET points=points+100 WHERE code=? AND child_id=?",
                  (code,child))
        return {"correct":True,"round_closed":True,"first":True,"points":100}

@router.post("/rooms/{code}/next")
def next_round(code:str,authorization:str|None=Header(None)):
    child=auth(authorization)
    with connection() as c:
        c.execute("BEGIN IMMEDIATE")
        room=get_room(c,code,child)
        if room["host_child"]!=child:raise HTTPException(403,"Only host can continue")
        room=expire_round(c,room)
        if room["state"]!="round_complete":
            raise HTTPException(409,"Wait for the current round to finish")
        if room["round_index"]>=TOTAL_ROUNDS:
            c.execute("UPDATE race_rooms SET state='finished' WHERE code=?",(code,))
            return {"finished":True}
        chosen=select_word(c,room)
        used=json.loads(room["used"])+[chosen]
        c.execute("""UPDATE race_rooms SET state='playing',round_index=?,
          word_index=?,used=?,started_at=?,finished_at=NULL,
          winner=NULL WHERE code=?""",
          (room["round_index"]+1,chosen,json.dumps(used),time.time(),code))
    return {"started":True}
