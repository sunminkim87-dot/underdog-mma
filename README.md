# Windows 게임 다운로드

**[P0 테스트 빌드 다운로드 페이지](https://github.com/sunminkim87-dot/underdog-mma/releases/tag/v0.1.0-p0)**

1. 위 페이지의 **Assets**에서 **UNDERDOG_P0_Windows.zip**을 받습니다.
2. Windows에서 오른쪽 클릭 → **모두 압축 풀기**를 선택합니다.
3. 풀린 폴더의 **UNDERDOG_P0.exe**를 더블클릭합니다. Godot 설치는 필요 없습니다.
4. 그림이 있는 설명은 ZIP 안의 **START_HERE.html**을 엽니다.

전체 프로젝트 보관용 ZIP은 같은 페이지의 **UNDERDOG_P0_Godot_Project.zip**입니다. GitHub가 자동 제공하는 Source code ZIP과 구분해 주세요.

이 저장소에는 기존에 완성한 프로젝트 파일을 복사했습니다. Windows 실행 파일은 공식 템플릿으로 내보내기를 검증했으며 Windows OS에서 직접 실행하는 검증은 아직 하지 않았습니다.

---

# UNDERDOG: ROAD TO CHAMPION — P0

18세 신인 선수를 생성하고, 4주 일정을 편성하며, 생활비를 벌고, 3라운드 자동 경기를 반복하는 Godot 4.6.3 프로젝트입니다.

Windows 초보자 실행법: `docs/WINDOWS_GUIDE.md`
구현/미구현: `docs/STATUS.md`
테스트와 한계: `docs/TEST_REPORT.md`
테스트용 수치와 규칙: `ASSUMPTIONS.md`
원본 기획서: `docs/UNDERDOG_MMA_Game_Design_v1.3.md`
구조: `docs/ARCHITECTURE.md`

Godot 프로젝트 관리자에서 `project.godot`을 가져온 후 오른쪽 위 ▶ 버튼(F5)으로 실행합니다. 별도 Windows 실행 파일을 쓰면 Godot 설치 없이 플레이할 수 있습니다.

개발자용 로직 테스트:

```
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/test_core.gd
```

렌더링 가능한 데스크톱 환경의 UI 테스트:

```
godot --audio-driver Dummy --path . --script res://tests/test_ui.gd -- --ui-test
```

테스트는 `automated_test_save.json` 또는 `ui_test_career.json`만 사용합니다. 실제 `career_v1.json`을 변경하지 않습니다. 수치는 밸런스 초안이며 Android 빌드/실기기와 Windows OS 네이티브 실행 검증은 아직 수행하지 않았습니다.
