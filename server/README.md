# UNDERDOG 개발용 온라인 서버 (v0.3 / protocol 2)

이 폴더는 운영 배포된 서비스가 아니라, 클라이언트에서 연결해 검증할 수 있는 개발 서버 코드다. Windows 게임 UI의 '개발 테스트'와 실제 운영 서버 연결을 혼동하지 않는다.

## 구현된 경계

- 익명 게스트 세션: 긴 임의 토큰을 발급하고 서버 DB에는 해시만 저장한다. 계정별 진행과 캐시 잔액을 분리한다.
- SQLite 저장: 선수/LP/시설/명예의 전당/전적은 서버 레코드에 보관한다.
- 클라이언트는 '훈련 진행', '전략 선택', '시설 업그레이드' 같은 행동만 보낸다. 스탯·현금·승패·유료 캐시를 직접 제출할 수 없다.
- 계산은 `bridge.gd`가 기존 `Career`/`Bout`를 실행한다. 서버와 UI에 서로 다른 성장 공식을 복제하지 않는다.
- 월간 미리보기와 서버 계산의 JSON 왕복 정밀도 허용 오차는 0.000001이다.
- 경기 시드는 서버가 생성한다. 경기일에는 서버도 월 진행을 거부한다.
- `revision`으로 충돌을 거부하고 `request_id`로 같은 요청의 재전송을 한 번만 처리한다. SQLite 트랜잭션으로 동시에 들어온 월 진행도 중복 적용하지 않는다.
- `/billing/verify`는 신뢰할 수 있는 서버 검증기가 없으면 503을 반환한다. 검증 전에는 캐시가 지급되지 않는다.
- 검증기 경계/대기 결제 거부/구매 토큰 재사용 방지/중복 지급 방지는 테스트한다. 테스트 검증기는 단위 테스트 함수 안에서만 주입한다. 가짜 캐시 지급 HTTP API는 없다.

## 개발자가 실행할 때

Godot 4.6.3 Standard와 Python 3.11+가 필요하다. 프로젝트 루트에서:

```sh
python -m venv .venv
# 생성한 가상 환경을 활성화한 뒤:
python -m pip install -r server/requirements.txt
godot --headless --editor --path . --import --quit
python -m uvicorn server.app:app --host 127.0.0.1 --port 8765
```

서버 실행 시 `GODOT_BIN`으로 엔진 경로, `UNDERDOG_DB`로 DB 위치를 지정할 수 있다. 기본 DB는 `.server-data/accounts.sqlite3`이며 Git/배포 ZIP에 넣지 않는다.

클라이언트 로비 → '온라인 서버 연결' → `http://127.0.0.1:8765` → 연결. 운영 주소는 HTTPS만 허용하고 개발용 localhost에만 HTTP를 허용한다. 연결 후 선수/월간/경기/프리셋/은퇴/시설 작업은 서버 요청으로 처리한다. 새 서버 계정은 기존 로컬 테스트 파일을 자동으로 가져오지 않는다. 서버 캐시는 `online_cache_v1.json`, 기존 로컬 테스트 저장은 `career_v1.json`로 분리해 유지한다.

이 명령은 개발자용이다. 기획자의 UI/연출 플레이 테스트에는 서버를 직접 설치할 필요가 없다. 정식 온라인 플레이에는 별도의 운영 배포가 필요하다.

## 아직 필요한 실제 서비스 작업

- 운영 호스팅, HTTPS 도메인, 배포/백업/모니터링, 요청 제한, 인증 강화와 부하 테스트.
- Google/Apple 등 영구 계정 연결과 기기 이전·게스트 토큰 분실 시 복구. 현재는 익명 게스트만 제공한다.
- 사용자에게 발급한 토큰은 클라이언트 `server_connection.cfg`에 저장한다. 정식 Android 앱에서는 플랫폼 보안 저장소를 연결해야 한다.
- Google Play 개발자 계정, Android 패키지명, 실제 결제 상품, 테스트 트랙, Android Billing 플러그인.
- Google Play 서버 API를 호출하는 실제 영수증 검증 어댑터, 계정 바인딩, acknowledgement/consume 재시도, 환불·취소 통지 및 정산. 현재 검증기 주입 인터페이스만 있으며 실제 Google 검증은 구현/연결하지 않았다.
- 실제 가격은 스토어에서 가져와야 한다. 이 빌드에는 실제 가격·실제 결제 완료 처리·임의 캐시 지급 기능이 없다.

SQLite + 요청마다 Godot 프로세스를 실행하는 방식은 검증용이다. 동시 접속 서비스 성능을 검증했다는 뜻이 아니다. 운영에서는 지속 실행 워커와 계정별 처리 큐 등으로 바꾸어야 한다.

## 검증

```sh
python -m unittest server.test_server -v
# 위 개발 서버를 실행한 상태에서, 테스트용 userdata 폴더를 별도로 사용:
godot --headless --path . --script res://tests/test_online.gd
```

단위 테스트 DB는 임시 디렉터리에 만들고 실제 사용자의 DB/구매 기록을 변경하지 않는다. `test_online.gd`는 개발 서버에 독립 게스트를 만들거나 해당 테스트 전용 userdata의 게스트만 사용한다. 실제 서비스 주소로 실행하지 않는다.

## v0.3 추가 검증

`new`의 `base`는 서버의 5종 정규 능력치 표를 사용한다. `buy`, `equip`, `use_item`, `event`, `focus`, `end_relationship`도 동일한 Godot 모듈과 revision/request_id 검증을 거친다. 코치 알바 해금·기술 습득·아이템 보유·관계 결과는 클라이언트 입력으로 덮어쓸 수 없다. 기존 v0.2 서버는 프로토콜이 다르므로 함께 업데이트한다. 기존 SQLite 스키마를 유지하고 저장 JSON에 새 필드만 추가한다.

연결 UI 회귀 검증은 개발 서버(8765) 외에 아래 지연 실패 서버(8771)를 실행한 상태에서, 별도 테스트 userdata로 `tests/test_connection_ui.gd -- --ui-test`를 실행한다.

```sh
python -m uvicorn server.test_connection_fixture:app --host 127.0.0.1 --port 8771
```

이 fixture는 지연된 503 응답만 반환하고 계정/구매 권한을 발급하지 않는다. 테스트에서는 연결 중 닫기·서버 자동 이어하기·연결 실패 시 로컬 전환 금지·명시적 로컬 전환과 양쪽 파일 보존을 확인한다.
