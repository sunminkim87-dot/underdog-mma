# 구조와 다음 작업의 경계

```text
project.godot                Android 세로 기준 540×960, Compatibility 렌더러
scenes/main.tscn             시작 씬
scripts/ui/main.gd          화면·입력·확인창·저장 성공 후 상태 확정
scripts/core/catalog.gd    데이터 로드·기본 일정
scripts/core/career.gd      생성·월간 계산·상대·경기 보상
scripts/core/bout.gd        UI/디스크에 의존하지 않는 시드 기반 경기
scripts/core/save_store.gd  스키마 검증·임시 저장·백업·복구
 data/game_data.json        훈련·생활·스타일·경제·상대·전략 표시 정의
assets/                     한글 폰트와 임시 SVG 그래픽
 tests/                     로직·실제 렌더링 UI 테스트·결과 JSON·스크린샷
 docs/                      원본 기획서·실행법·범위·설계·라이선스
 tools/                     Windows 자동 테스트 실행 도우미
```

`Career.month`와 `Career.fight`는 입력을 깊은 복사한 뒤 결과를 반환한다. UI는 결과를 저장한 후에만 진행을 확정한다. 월말 미납·저장 실패 시 입력 상태가 유지된다. 월간 미리보기도 같은 계산 함수를 사용하므로 서로 다른 예측 공식을 관리하지 않는다.

경기 함수는 지역 `RandomNumberGenerator`만 사용한다. 향후 경기 상성·기술 숙련을 고도화해도 UI를 재작성하지 않도록 계산 경계를 두었다. 현재는 기본 능력치에서 방어를 파생하며 별도 세부 숙련 필드를 도입하지 않는다.

저장 루트의 현재 선수와 영구 데이터를 분리했다. P2에서 은퇴 기록을 `hall_of_fame`에 보관하고 코치는 `source_athlete_id`, 체육관은 `founder_athlete_id`로 원본 선수 ID를 참조한다. 은퇴 시 원본 기록을 지우지 않고 이전 선수의 스냅샷을 보존한다. 현재 P0에는 실제 은퇴·계승 처리가 없다.

Android 방향 설정과 터치 스크롤 가능한 UI는 준비됐지만, APK 서명/배포·백그라운드 종료·실기기 터치·기기 안전 영역/키보드 검증은 아직 수행하지 않았다. Android 프리셋을 완성했다고 표시하지 않는다. Windows 실행 파일에는 한글 폰트와 데이터 리소스를 포함한다.

초기 튜닝은 `data/game_data.json`만 수정한다. 경기 확률과 상태 전환은 `bout.gd`에 둔다. 다음 단계에서 규칙이 늘면 경기 규칙도 별도 데이터로 옮긴다.
