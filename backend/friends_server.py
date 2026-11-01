"""Parent-approved, private, server-validated WordSprout friends leaderboard.

Deploy separately on your own HTTPS host; no child accounts are created from
the child-facing app. Parent email OTP is required before authorizing profiles.
This is not a replacement for a legal/compliance review of parental consent.
"""
import hashlib
import hmac
import json
import os
import secrets
import smtplib
import sqlite3
import ssl
import time
from datetime import datetime, timezone, timedelta
from email.message import EmailMessage
from pathlib import Path

from fastapi import FastAPI, HTTPException, Header
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

DB_PATH = os.environ.get("WORDSPROUT_LEAGUE_DB", "wordsprout_league.sqlite")
SECRET = os.environ.get("WORDSPROUT_LEAGUE_SECRET", "")
CONTENT = Path(__file__).resolve().parents[1] / "assets/content/older_missions_v1.json"
ALIASES = (
    "Sunny Comet", "Blue Fox", "Golden Otter", "Brave Sparrow",
    "Little Meteor", "Silver Kite", "Clever Turtle", "Happy Willow",
    "Bright Moon", "Green Falcon", "Starry Panda", "Quiet Rocket",
)
app = FastAPI(title="WordSprout Private Friends League", version="0.1.0",
              docs_url=None, redoc_url=None)
MISSIONS = {m["id"]: m for m in json.loads(CONTENT.read_text())["missions"]}

def db():
    connection = sqlite3.connect(DB_PATH, timeout=10)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys=ON")
    return connection

def init_db():
    with db() as c:
        c.executescript("""
        CREATE TABLE IF NOT EXISTS parents(
          id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL,
          created_at INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS parent_codes(
          email TEXT PRIMARY KEY, hash TEXT NOT NULL,
          until INTEGER NOT NULL, tries INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE IF NOT EXISTS tokens(
          digest TEXT PRIMARY KEY, subject_id TEXT NOT NULL,
          kind TEXT NOT NULL, created_at INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS children(
          id TEXT PRIMARY KEY, parent_id TEXT NOT NULL,
          alias TEXT NOT NULL, consent INTEGER NOT NULL CHECK(consent=1),
          created_at INTEGER NOT NULL,
          FOREIGN KEY(parent_id) REFERENCES parents(id));
        CREATE TABLE IF NOT EXISTS device_codes(
          digest TEXT PRIMARY KEY, child_id TEXT NOT NULL,
          until INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS invites(
          digest TEXT PRIMARY KEY, child_id TEXT NOT NULL,
          until INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS friendships(
          a TEXT NOT NULL, b TEXT NOT NULL,
          PRIMARY KEY(a,b), CHECK(a < b));
        CREATE TABLE IF NOT EXISTS attempts(
          child_id TEXT NOT NULL, mission TEXT NOT NULL,
          stage TEXT NOT NULL, idx INTEGER NOT NULL,
          wrong INTEGER NOT NULL, awarded INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY(child_id,mission,stage,idx));
        CREATE TABLE IF NOT EXISTS score_events(
          child_id TEXT NOT NULL, event_id TEXT NOT NULL,
          xp INTEGER NOT NULL CHECK(xp>=0 AND xp<=25),
          created_at INTEGER NOT NULL,
          PRIMARY KEY(child_id,event_id));
        """)
init_db()

def require_secret():
    if len(SECRET)<32:
        raise HTTPException(503,"Server has no configured auth secret")

def digest(value):
    return hmac.new(SECRET.encode(),value.encode(),"sha256").hexdigest()

def bearer(authorization,kind):
    require_secret()
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401,"Authorization required")
    token = authorization[7:]
    if len(token)>120:
        raise HTTPException(401,"Invalid session")
    with db() as c:
        row=c.execute("SELECT subject_id,created_at FROM tokens WHERE digest=? AND kind=?",
                      (digest(token),kind)).fetchone()
        if row:
            ttl=12*3600 if kind=="parent" else 30*86400
            if row["created_at"]+ttl<int(time.time()):
                c.execute("DELETE FROM tokens WHERE digest=?",(digest(token),))
                row=None
    if not row:raise HTTPException(401,"Invalid or expired session")
    return row["subject_id"]

def issue_token(conn,subject,kind):
    token=secrets.token_urlsafe(32)
    conn.execute("INSERT INTO tokens VALUES (?,?,?,?)",
                 (digest(token),subject,kind,int(time.time())))
    return token

def mail_code(to,code):
    host=os.environ.get("WORDSPROUT_SMTP_HOST")
    user=os.environ.get("WORDSPROUT_SMTP_USER")
    password=os.environ.get("WORDSPROUT_SMTP_PASSWORD")
    sender=os.environ.get("WORDSPROUT_SMTP_FROM")
    if not all((host,user,password,sender)):
        raise HTTPException(503,"Parent email verification is unavailable")
    msg=EmailMessage()
    msg["Subject"]="Your WordSprout parent verification code"
    msg["From"]=sender
    msg["To"]=to
    msg.set_content("Your parent setup code is "+code+
                    ". It expires in 10 minutes. Do not share it.")
    with smtplib.SMTP(host,int(os.environ.get("WORDSPROUT_SMTP_PORT","587")),
                      timeout=12) as smtp:
        smtp.starttls(context=ssl.create_default_context())
        smtp.login(user,password)
        smtp.send_message(msg)

class ParentStart(BaseModel):
    email: str = Field(min_length=6,max_length=254)
class ParentVerify(ParentStart):
    code: str = Field(pattern=r"^[0-9]{6}$")
class ChildCreate(BaseModel):
    alias: str
    consent: bool
class ChildTarget(BaseModel):
    child_id: str = Field(min_length=20,max_length=50)
class CodeEntry(BaseModel):
    code: str = Field(min_length=7,max_length=16)
class FriendAccept(CodeEntry):
    child_id: str
class Answer(BaseModel):
    mission_id: str = Field(min_length=3,max_length=80)
    stage: str = Field(pattern="^(detective|relation|sentence|pattern|transfer)$")
    index: int = Field(ge=0,le=30)
    response: str = Field(min_length=1,max_length=300)

@app.get("/parents",include_in_schema=False)
def parent_portal():
    return FileResponse(Path(__file__).with_name("parent_portal.html"),
                        media_type="text/html",
                        headers={"Cache-Control":"no-store",
                                 "Content-Security-Policy":"default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; object-src 'none'"})

@app.get("/health")
def health(): return {"status":"ready"}

@app.post("/v1/parent/request-code")
def request_code(body:ParentStart):
    require_secret()
    email=body.email.strip().lower()
    if "@" not in email or "." not in email.split("@")[-1]:
        raise HTTPException(400,"Invalid email")
    now=int(time.time())
    with db() as c:
        old=c.execute("SELECT until FROM parent_codes WHERE email=?",(email,)).fetchone()
        if old and old["until"]>now+540:
            raise HTTPException(429,"Please wait before requesting another code")
        code=str(secrets.randbelow(1000000)).zfill(6)
        c.execute("INSERT OR REPLACE INTO parent_codes VALUES (?,?,?,0)",
                  (email,digest(email+":"+code),now+600))
    mail_code(email,code)
    return {"message":"If email can receive messages, the code was sent."}

@app.post("/v1/parent/verify-code")
def verify_parent(body:ParentVerify):
    require_secret()
    email=body.email.strip().lower()
    with db() as c:
        row=c.execute("SELECT * FROM parent_codes WHERE email=?",(email,)).fetchone()
        if not row or row["until"]<time.time() or row["tries"]>=5:
            raise HTTPException(401,"Code expired or invalid")
        c.execute("UPDATE parent_codes SET tries=tries+1 WHERE email=?",(email,))
        if not hmac.compare_digest(row["hash"],digest(email+":"+body.code)):
            raise HTTPException(401,"Invalid verification code")
        c.execute("DELETE FROM parent_codes WHERE email=?",(email,))
        parent=c.execute("SELECT id FROM parents WHERE email=?",(email,)).fetchone()
        parent_id=parent["id"] if parent else secrets.token_urlsafe(18)
        if not parent:
            c.execute("INSERT INTO parents VALUES (?,?,?)",(parent_id,email,int(time.time())))
        return {"parent_token":issue_token(c,parent_id,"parent")}

@app.post("/v1/parent/children")
def create_child(body:ChildCreate,authorization:str|None=Header(None)):
    parent=bearer(authorization,"parent")
    if not body.consent:
        raise HTTPException(400,"Parent must explicitly approve private friends features")
    if body.alias not in ALIASES: raise HTTPException(400,"Choose an approved nickname")
    with db() as c:
        count=c.execute("SELECT COUNT(*) n FROM children WHERE parent_id=?",(parent,)).fetchone()["n"]
        if count>=8: raise HTTPException(409,"Too many profiles")
        child_id=secrets.token_urlsafe(18)
        c.execute("INSERT INTO children VALUES (?,?,?,?,?)",
                  (child_id,parent,body.alias,1,int(time.time())))
    return {"child_id":child_id,"alias":body.alias}

def owned_child(parent,child_id):
    with db() as c:
        found=c.execute("SELECT id FROM children WHERE id=? AND parent_id=?",
                        (child_id,parent)).fetchone()
    if not found: raise HTTPException(403,"Child is not in your family")

@app.get("/v1/parent/children")
def list_children(authorization:str|None=Header(None)):
    parent=bearer(authorization,"parent")
    with db() as c:
        rows=c.execute("SELECT id,alias FROM children WHERE parent_id=?",(parent,)).fetchall()
    return {"children":[dict(row) for row in rows]}

@app.post("/v1/parent/device-code")
def device_code(body:ChildTarget,authorization:str|None=Header(None)):
    parent=bearer(authorization,"parent")
    owned_child(parent,body.child_id)
    code=secrets.token_hex(5).upper()
    with db() as c:
        c.execute("INSERT INTO device_codes VALUES (?,?,?)",
                  (digest(code),body.child_id,int(time.time())+900))
    return {"code":code,"expires_in_seconds":900}

@app.post("/v1/child/connect")
def connect_child(body:CodeEntry):
    require_secret()
    code=body.code.upper()
    with db() as c:
        row=c.execute("SELECT child_id,until FROM device_codes WHERE digest=?",
                      (digest(code),)).fetchone()
        if not row or row["until"]<time.time():
            raise HTTPException(401,"Invalid or expired parent-issued code")
        c.execute("DELETE FROM device_codes WHERE digest=?",(digest(code),))
        child=c.execute("SELECT alias FROM children WHERE id=?",(row["child_id"],)).fetchone()
        if not child: raise HTTPException(404,"Profile removed")
        token=issue_token(c,row["child_id"],"child")
    return {"child_token":token,"alias":child["alias"]}

@app.post("/v1/parent/friend-invite")
def invite(body:ChildTarget,authorization:str|None=Header(None)):
    parent=bearer(authorization,"parent")
    owned_child(parent,body.child_id)
    code=secrets.token_hex(5).upper()
    with db() as c:
        c.execute("INSERT INTO invites VALUES (?,?,?)",
                  (digest(code),body.child_id,int(time.time())+86400))
    return {"code":code,"expires_in_seconds":86400}

@app.post("/v1/parent/friend-accept")
def accept(body:FriendAccept,authorization:str|None=Header(None)):
    parent=bearer(authorization,"parent")
    owned_child(parent,body.child_id)
    with db() as c:
        row=c.execute("SELECT child_id,until FROM invites WHERE digest=?",
                      (digest(body.code.upper()),)).fetchone()
        if not row or row["until"]<time.time():
            raise HTTPException(400,"Invitation expired")
        other=row["child_id"]
        if other==body.child_id:raise HTTPException(400,"Cannot add self")
        edge=sorted([body.child_id,other])
        count=c.execute("SELECT COUNT(*) n FROM friendships WHERE a=? OR b=?",
                        (body.child_id,body.child_id)).fetchone()["n"]
        if count>=30:raise HTTPException(409,"Friend limit reached")
        c.execute("DELETE FROM invites WHERE digest=?",(digest(body.code.upper()),))
        c.execute("INSERT OR IGNORE INTO friendships VALUES (?,?)",edge)
    return {"status":"friends_approved"}

@app.get("/v1/parent/friends/{child_id}")
def parent_friends(child_id:str,authorization:str|None=Header(None)):
    parent=bearer(authorization,"parent")
    owned_child(parent,child_id)
    with db() as c:
        rows=c.execute("""SELECT c.id,c.alias FROM friendships f
          JOIN children c ON c.id=CASE WHEN f.a=? THEN f.b ELSE f.a END
          WHERE f.a=? OR f.b=? ORDER BY c.alias""",
          (child_id,child_id,child_id)).fetchall()
    return {"friends":[dict(row) for row in rows]}

@app.delete("/v1/parent/friends/{child_id}/{friend_id}")
def remove_friend(child_id:str,friend_id:str,authorization:str|None=Header(None)):
    parent=bearer(authorization,"parent")
    owned_child(parent,child_id)
    a,b=sorted((child_id,friend_id))
    with db() as c:
        c.execute("DELETE FROM friendships WHERE a=? AND b=?",(a,b))
    return {"status":"friend_removed"}

@app.delete("/v1/parent/children/{child_id}")
def delete_child(child_id:str,authorization:str|None=Header(None)):
    parent=bearer(authorization,"parent")
    owned_child(parent,child_id)
    with db() as c:
        for statement in (
            "DELETE FROM tokens WHERE subject_id=? AND kind='child'",
            "DELETE FROM friendships WHERE a=? OR b=?",
            "DELETE FROM score_events WHERE child_id=?",
            "DELETE FROM attempts WHERE child_id=?",
            "DELETE FROM invites WHERE child_id=?",
            "DELETE FROM device_codes WHERE child_id=?",
            "DELETE FROM children WHERE id=?",
        ):
            c.execute(statement,(child_id,child_id) if " OR b=?" in statement else (child_id,))
    return {"status":"deleted"}

def normal(value):return " ".join(value.lower().strip().strip(".!?").split())

def expected(mission,stage,index):
    if stage in ("detective","relation"):
        if index>=4:raise HTTPException(400,"Invalid word index")
        word=mission["words"][index]
        if stage=="detective":return [word["term"]]
        return [word["antonym" if index%2 else "synonym"]]
    if index!=0:raise HTTPException(400,"Invalid question index")
    if stage=="sentence":
        return [mission["sentence"],*mission["sentenceAlternatives"]]
    name="pattern" if stage=="pattern" else "transfer"
    item=mission[name]
    return [item["options"][item["answer"]]]

@app.post("/v1/answer")
def answer(body:Answer,authorization:str|None=Header(None)):
    child=bearer(authorization,"child")
    mission=MISSIONS.get(body.mission_id)
    if not mission:raise HTTPException(400,"Unknown mission")
    valid=[normal(v) for v in expected(mission,body.stage,body.index)]
    good=normal(body.response) in valid
    with db() as c:
        old=c.execute("""SELECT wrong,awarded FROM attempts
          WHERE child_id=? AND mission=? AND stage=? AND idx=?""",
          (child,body.mission_id,body.stage,body.index)).fetchone()
        if old and old["awarded"]:
            return {"correct":good,"xp_awarded":0,"already_credited":True}
        wrong=old["wrong"] if old else 0
        if not good:
            c.execute("""INSERT INTO attempts VALUES (?,?,?,?,1,0)
              ON CONFLICT(child_id,mission,stage,idx) DO UPDATE SET wrong=wrong+1""",
              (child,body.mission_id,body.stage,body.index))
            return {"correct":False,"xp_awarded":0,"already_credited":False}
        points=(15 if wrong==0 else 6) if body.stage=="sentence" else (10 if wrong==0 else 4)
        c.execute("""INSERT INTO attempts VALUES (?,?,?,?,?,1)
          ON CONFLICT(child_id,mission,stage,idx) DO UPDATE SET awarded=1""",
          (child,body.mission_id,body.stage,body.index,wrong))
        now=int(time.time())
        c.execute("INSERT OR IGNORE INTO score_events VALUES (?,?,?,?)",
                  (child,"answer:"+body.mission_id+":"+body.stage+":"+str(body.index),
                   points,now))
        completed=c.execute("""SELECT COUNT(*) n FROM attempts
          WHERE child_id=? AND mission=? AND awarded=1""",
          (child,body.mission_id)).fetchone()["n"]
        if completed==11:
            c.execute("INSERT OR IGNORE INTO score_events VALUES (?,?,20,?)",
                      (child,"finish:"+body.mission_id,now))
            mistakes=c.execute("""SELECT SUM(wrong) n FROM attempts
              WHERE child_id=? AND mission=?""",(child,body.mission_id)).fetchone()["n"]
            if mistakes==0:
                c.execute("INSERT OR IGNORE INTO score_events VALUES (?,?,10,?)",
                          (child,"perfect:"+body.mission_id,now))
    return {"correct":True,"xp_awarded":points,"already_credited":False}

@app.get("/v1/leaderboard")
def leaderboard(authorization:str|None=Header(None)):
    child=bearer(authorization,"child")
    today=datetime.now(timezone.utc)
    start=(today-timedelta(days=today.weekday())).replace(
        hour=0,minute=0,second=0,microsecond=0)
    since=int(start.timestamp())
    with db() as c:
        friends=c.execute("""SELECT CASE WHEN a=? THEN b ELSE a END friend
          FROM friendships WHERE a=? OR b=?""",(child,child,child)).fetchall()
        ids=[child]+[row["friend"] for row in friends]
        result=[]
        for ident in ids:
            r=c.execute("SELECT alias FROM children WHERE id=?",(ident,)).fetchone()
            if not r:continue
            xp=c.execute("SELECT COALESCE(SUM(xp),0) n FROM score_events WHERE child_id=? AND created_at>=?",
                         (ident,since)).fetchone()["n"]
            result.append({"is_me":ident==child,"alias":r["alias"],"weekly_xp":xp})
        result.sort(key=lambda r:(-r["weekly_xp"],r["alias"]))
    return {"week_start_utc":start.date().isoformat(),"friends":result,
            "note":"Scores are validated by the server; local offline XP is not synced."}

# Parent-approved live Picture Race rooms (same verified child sessions).
from backend.picture_race import router as picture_race_router
app.include_router(picture_race_router)
