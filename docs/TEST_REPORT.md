# v0.3 자동 검증 결과

Godot 4.6.3 stable official, Linux x86_64, Xorg + Mesa llvmpipe OpenGL Compatibility. Windows OS/Android 실기기 검증은 별개로 남아 있다.

| 검사 | 통과 | 실패 |
|---|---:|---:|
| 핵심 육성·경기·저장 `test_core.gd` | 4,756 | 0 |
| 새 성장·아이템·이벤트 `test_progression.gd` | 66 | 0 |
| 렌더링 UI `test_ui.gd` | 540 | 0 |
| 연결 UI 회귀 `test_connection_ui.gd` | 15 | 0 |
| Godot 실제 HTTP `test_online.gd` | 16 | 0 |
| 서버 API `python -m unittest server.test_server -v` | 14 시나리오 | 0 |

## 확인한 동작

- 기존 월 진행·경제·피로·성장·자동 경기·150개월 저장·6,400경기 분포 검사 유지. 예정 경기 월 도달/초과 시 진행 거부, 경기 후 재개. 실제 회복과 피로 연속성, 부분/손상 회복 리포트 거부.
- 5베이스 총184/종목 강점·기존 선수 수치 보존 마이그레이션·조건부 알바 차단/코치 해금/수입.
- 물품 실제 현금 차감·재고·장비 중복 구매 거부·착용/해제·파생 경기 보너스·원본 스탯 불변·최대치 제한·경기 스냅샷 재현.
- 실제 회복 상한·체력100에서 물품 낭비 방지·월3회·동일 서버 요청 재시도/동시 구매 중복 차감·소모 방지.
- 이벤트 조건/대기 선택/재전송 보상 거부·기술 습득/미루기·첫 만남/친밀도/연애·친구로 돌아가기·일정에서만 친밀도 증가·업적 최초1회.
- 실제 540×960·360×800 렌더링 UI: 로비·5베이스 미리보기·컬러 일정·실제 회복·행동 재생·배속/건너뛰기·경기일·아이템 사용 게이지·상점·인연·기술 이벤트·업적. 스크린샷 20장.
- 지연503 응답 중 연결창 닫아도 해제된 Label 접근 오류 없음. 실제 서버 계정/선수로 연속2회 자동 이어하기. 연결 실패 시 로컬 자동 덮어쓰기/전환 금지, 명시적 전환 후 로컬/서버 캐시 모두 보존.
- 계정 분리·서버 권한 계산·클라이언트 임의 현금/능력치/해금 거부·revision/request_id/트랜잭션·영수증 검증기 경계와 재사용 거부.
- JSON 왕복 실수 비교 허용 오차는 0.000001. 테스트가 끝나도록 watchdog을 두었으며 테스트 DB와 userdata는 사용자 저장과 분리했다.

## 빌드 검증

Windows 공식 x86_64 release 템플릿으로 내보내기 성공, PE32+ 및 내장 PCK 확인. 새 JSON/스프라이트 자원 포함 확인. 같은 소스의 Linux release 내보내기와 실제 headless/Xorg GUI 시작 성공. 저장 캐시가 없는 깨끗한 프로젝트 복사본에서 가져오기·4,756개 핵심 검사·66개 새 성장 검사 재통과. ZIP 무결성과 GitHub 다운로드 파일의 SHA256은 최종 배포 시 확인한다. 실행 파일 해시는 `BUILD_VERIFICATION.txt`에 기록한다.

버그 검사 중 연결 테스트의 선수 ID 필드와 UI 테스트의 이벤트 쿨다운 초기화에 잘못된 테스트 픽스처가 있어 바로잡고 재실행했다. 최종 위 결과는 수정 후 통과 기록이다.

## 미검증/미연결

실제 Windows 실행·코드서명·SmartScreen 해결, Android APK/실기기, 실제 Google Play 결제/영수증/환불, 운영 온라인 서버 배포·영구 계정·복구·기기 이전·보안/부하는 검증하지 않았다. 구매 테스트는 테스트 함수가 주입한 검증기 경계 검사이며 실제 결제가 아니다. 현재 기술은 능력치 보너스로, 별도 기술 행동 AI/대형 트리/긴 관계 이야기는 이번 범위가 아니다.

## 개발자 재현 명령

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/test_core.gd
godot --headless --path . --script res://tests/test_progression.gd
godot --path . --audio-driver Dummy --script res://tests/test_ui.gd -- --ui-test
python -m unittest server.test_server -v
# 서버 8765 실행 및 별도 테스트 userdata 사용:
godot --headless --path . --script res://tests/test_online.gd
# 지연 실패 fixture 서버 8771도 실행 및 별도 테스트 userdata 사용:
godot --path . --audio-driver Dummy --script res://tests/test_connection_ui.gd -- --ui-test
```

서버 실행 방법은 `server/README.md`를 따른다. 각각 독립 userdata를 사용하며 기존 사용자 파일로 테스트하지 않는다. 버튼 신호 기반 UI 검증이므로 실제 터치/키보드 입력·운영 네트워크의 모든 실패 상황을 보장하지 않는다.
