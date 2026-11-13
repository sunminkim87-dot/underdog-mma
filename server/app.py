"""Server-authoritative prototype. Runs the SAME Godot rules as the client.
No client-provided stats, currency, match result, or premium cash is accepted.
Real Google Play checkout is deliberately unavailable until a verified provider is configured.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import sqlite3
import subprocess
import tempfile
from typing import Callable
from fastapi import FastAPI, Header, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field

PROJECT = Path(__file__).resolve().parents[1]
PRODUCTS = {"cash_100":100,"cash_550":550}
ALLOWED = {"new":{"name","style","appearance"},"month":set(),"fight":{"strategy"},"schedule":{"schedule"},"preset":{"schedule"},"retire":set(),"upgrade":{"facility"}}

class Mutation(BaseModel):
    model_config = ConfigDict(extra="allow")
    revision: int = Field(ge=0,le=10**9)
    request_id: str = Field(pattern=r"^[A-Za-z0-9_-]{16,64}$")

class Receipt(BaseModel):
    model_config = ConfigDict(extra="forbid")
    product_id: str = Field(max_length=80)
    purchase_token: str = Field(min_length=10,max_length=4096)


def create_app(db_path: str | Path | None = None, verifier: Callable | None = None) -> FastAPI:
    db_path = Path(db_path or os.environ.get("UNDERDOG_DB", str(PROJECT / ".server-data" / "accounts.sqlite3")))
    db_path.parent.mkdir(parents=True,exist_ok=True)
    api = FastAPI(title="UNDERDOG development server",version="0.2.0")
    def db():
        conn = sqlite3.connect(db_path,timeout=40)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys=ON")
        return conn
    with db() as conn:
        conn.executescript('''
        CREATE TABLE IF NOT EXISTS accounts (id TEXT PRIMARY KEY, token_hash TEXT UNIQUE NOT NULL, revision INTEGER NOT NULL DEFAULT 0, state TEXT, cash INTEGER NOT NULL DEFAULT 0 CHECK(cash>=0));
        CREATE TABLE IF NOT EXISTS requests (account_id TEXT NOT NULL, request_id TEXT NOT NULL, fingerprint TEXT NOT NULL, response TEXT NOT NULL, PRIMARY KEY(account_id,request_id), FOREIGN KEY(account_id) REFERENCES accounts(id));
        CREATE TABLE IF NOT EXISTS purchases (token_hash TEXT PRIMARY KEY, account_id TEXT NOT NULL, product_id TEXT NOT NULL, credited INTEGER NOT NULL, FOREIGN KEY(account_id) REFERENCES accounts(id));
        ''')
    def account(authorization: str | None):
        if not authorization or not authorization.startswith("Bearer "):
            raise HTTPException(401,"계정 인증이 필요합니다.")
        digest = hashlib.sha256(authorization[7:].encode()).hexdigest()
        with db() as conn:
            row = conn.execute("SELECT * FROM accounts WHERE token_hash=?",(digest,)).fetchone()
        if row is None: raise HTTPException(401,"인증이 만료되었거나 올바르지 않습니다.")
        return row
    def snapshot(row):
        return {"ok":True,"revision":row["revision"],"state":json.loads(row["state"]) if row["state"] else None,"wallet":{"cash":row["cash"]},"capabilities":{"billing_enabled":verifier is not None,"server_authoritative":True,"guest_accounts":True}}
    @api.get("/health")
    def health():
        return {"ok":True,"protocol":1,"version":"0.2.0","billing_enabled":verifier is not None}
    @api.post("/session")
    def session():
        token = secrets.token_urlsafe(40)
        uid = secrets.token_hex(16)
        digest = hashlib.sha256(token.encode()).hexdigest()
        with db() as conn: conn.execute("INSERT INTO accounts(id,token_hash) VALUES(?,?)",(uid,digest))
        return {"ok":True,"token":token,"account_id":uid}
    @api.get("/state")
    def state(authorization: str | None = Header(default=None)):
        return snapshot(account(authorization))
    @api.post("/action/{operation}")
    def action(operation: str, command: Mutation, authorization: str | None = Header(default=None)):
        viewer = account(authorization)
        if operation not in ALLOWED: raise HTTPException(404,"지원하지 않는 행동입니다.")
        payload = command.model_dump(exclude={"revision","request_id"})
        if set(payload)-ALLOWED[operation]: raise HTTPException(422,"능력치·현금·경기 결과는 직접 제출할 수 없습니다.")
        fingerprint = hashlib.sha256(json.dumps([operation,payload],sort_keys=True).encode()).hexdigest()
        with db() as conn:
            conn.execute("BEGIN IMMEDIATE")
            cached = conn.execute("SELECT fingerprint,response FROM requests WHERE account_id=? AND request_id=?",(viewer["id"],command.request_id)).fetchone()
            if cached:
                if cached["fingerprint"] != fingerprint: raise HTTPException(409,"같은 요청 번호에 다른 행동을 보낼 수 없습니다.")
                return json.loads(cached["response"])
            row = conn.execute("SELECT * FROM accounts WHERE id=?",(viewer["id"],)).fetchone()
            if row["revision"] != command.revision: raise HTTPException(409,"다른 요청에서 진행이 바뀌었습니다. 서버 상태를 다시 불러와 주세요.")
            state = json.loads(row["state"]) if row["state"] else {}
            engine = shutil.which(os.environ.get("GODOT_BIN","godot"))
            if not engine: raise HTTPException(503,"서버의 Godot 실행 환경을 확인해 주세요.")
            with tempfile.TemporaryDirectory(prefix="underdog-rule-") as directory:
                input_file = Path(directory)/"input.json"
                output_file = Path(directory)/"output.json"
                input_file.write_text(json.dumps({"operation":operation,"state":state,"payload":payload,"match_seed":secrets.randbelow(2**31)},ensure_ascii=False))
                try:
                    run = subprocess.run([engine,"--headless","--path",str(PROJECT),"--script","res://server/bridge.gd","--",str(input_file),str(output_file)],capture_output=True,timeout=25,env=os.environ.copy())
                except subprocess.TimeoutExpired:
                    raise HTTPException(503,"규칙 서버 응답이 지연되고 있습니다.")
                if run.returncode or not output_file.exists(): raise HTTPException(503,"규칙 계산 서버를 확인해 주세요.")
                result = json.loads(output_file.read_text())
            if not result.get("ok"): return JSONResponse(result,status_code=409)
            next_revision = int(row["revision"])+1
            conn.execute("UPDATE accounts SET state=?,revision=? WHERE id=?",(json.dumps(result["state"],ensure_ascii=False),next_revision,row["id"]))
            response = dict(result,revision=next_revision,wallet={"cash":row["cash"]})
            conn.execute("INSERT INTO requests VALUES(?,?,?,?)",(row["id"],command.request_id,fingerprint,json.dumps(response,ensure_ascii=False)))
            return response
    @api.post("/billing/verify")
    def verify(receipt: Receipt, authorization: str | None = Header(default=None)):
        viewer = account(authorization)
        if verifier is None: raise HTTPException(503,"Google Play 개발자 계정·영수증 검증 서비스가 연결되지 않았습니다.")
        if receipt.product_id not in PRODUCTS: raise HTTPException(422,"등록되지 않은 상품입니다.")
        # Only a trusted server-side provider can return a verified purchase.
        # Never accept a client 'paid', 'cash', 'verified' or price field.
        verified = verifier(receipt.product_id,receipt.purchase_token,viewer["id"])
        if not verified or verified.get("account_id") != viewer["id"] or verified.get("product_id") != receipt.product_id or verified.get("purchase_state") != "PURCHASED":
            raise HTTPException(403,"서버에서 결제를 확인하지 못했습니다.")
        digest = hashlib.sha256(receipt.purchase_token.encode()).hexdigest()
        with db() as conn:
            conn.execute("BEGIN IMMEDIATE")
            existing = conn.execute("SELECT * FROM purchases WHERE token_hash=?",(digest,)).fetchone()
            if existing and existing["account_id"] != viewer["id"]: raise HTTPException(409,"이미 사용된 구매입니다.")
            if not existing:
                amount = PRODUCTS[receipt.product_id]
                conn.execute("INSERT INTO purchases VALUES(?,?,?,?)",(digest,viewer["id"],receipt.product_id,amount))
                conn.execute("UPDATE accounts SET cash=cash+? WHERE id=?",(amount,viewer["id"]))
            row = conn.execute("SELECT * FROM accounts WHERE id=?",(viewer["id"],)).fetchone()
            return snapshot(row)
    return api

app = create_app()
