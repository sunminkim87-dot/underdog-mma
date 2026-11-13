# v0.2 구조

- `scripts/core/career.gd`: 기존 육성·경제 + 경기일 차단·회복 타임라인·은퇴·LP 시설·다음 선수.
- `scripts/core/bout.gd`: 기존 재현 가능한 MMA 경기 엔진.
- `scripts/core/save_store.gd`: 기존 v1 파일 호환 + 새 타임라인/시설/명예의 전당 검증.
- `scripts/core/online_gateway.gd`: HTTP 세션, 서버 상태/행동 요청, revision, 임의 request_id. 서버 캐시와 로컬 테스트 파일 분리.
- `scripts/ui/main.gd`: 로비와 육성·일정 카드·행동 선택·기록·명예의 전당·시설·상점·서버 연결 화면.
- `scripts/ui/components/activity_scene.gd`: 배경 아틀라스와 애니메이션 스프라이트, 팔레트, 행동별 장면 배치.
- `scripts/ui/components/month_playback.gd`: 실제 계산 타임라인 재생, 회복/피로/활력 게이지, 배속, 중복 없는 건너뛰기.
- `scripts/ui/components/activity_icon.gd`: 행동별 픽셀 아이콘.
- `assets/art/life_atlas.png`, `athlete_sheet.png`, `sprite_palette.gdshader`: 오리지널 생성 아트와 색상 처리. 기존 P0 아트는 삭제하지 않고 사용만 중단했다.
- `data/game_data.json`: 경제·행동·스타일·상대·시설 정의.
- `server/app.py`: 개발 서버, 계정별 SQLite, 세션, 트랜잭션, 중복/충돌 보호, 검증기 경계.
- `server/bridge.gd`: 서버가 같은 Godot 규칙을 호출한다. 클라이언트가 제출한 성장 결과를 저장하지 않는다.
- `tests/`: 로직, 렌더링 UI, 실제 HTTP Godot 연동, 서버 검증.

계승에서 선수 고유 ID를 유지한다. 이번 범위의 은퇴 기록은 명예의 전당에 저장되며 미래 코치/체육관은 `source_athlete_id`/`founder_athlete_id`로 해당 원본을 참조하도록 확장한다. 이번 버전에는 코치 전직이나 선수 설립 체육관 효과를 넣지 않았다.

정식 게임은 온라인을 목표로 한다. 실행 가능한 개발 서버와 클라이언트 연결은 준비했지만 운영 배포·영구 계정·Google Play 실제 결제·보안 저장소·운영 성능은 아직 미완성이다. 개발 테스트 로컬 저장을 실제 결제 권한의 근거로 사용하지 않는다.
