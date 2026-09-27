# Pixel Pals (Garmin Connect IQ 워치페이스)

Forerunner 265S/265용 픽셀 캐릭터 워치페이스. Monkey C.

## 규칙
- 캐릭터·폰트·아이콘 그림은 `tools/gen_sprites.py`에서만 수정한다. 수정 후 `python3 tools/gen_sprites.py`를 실행해
  `source/Sprites.mc`, `preview/sprites.js`, `resources/drawables/launcher_icon.png`를 재생성하고 함께 커밋한다.
- `preview/watchface.js`는 `source/MochiFaceView.mc`, `Pix.mc`, `Smooth.mc`를 그대로 옮긴 것이다. 화면 로직을 바꾸면 둘 다 수정한다.
- 설정 항목을 추가하면 `Settings.mc`(KEYS/COUNTS/DEFAULTS/labels), `SettingsMenu.mc`, 영/한 `strings.xml`,
  `properties.xml`, `settings.xml`, `preview/index.html`의 OPTIONS를 함께 바꾼다.
- 캐릭터: 0 모찌, 1 꼬부기, 2 파이리, 3 도롱이. 픽셀(격자) + 디지털(SMOOTH 벡터 도형) 두 벌이 있다.
- 한글 날짜는 시스템 폰트 대신 `HANGUL` 픽셀 글리프로 그린다 (한글 폰트 없는 모델 대비).
- 좌표는 360x360 기준으로 설계하고 `_ox/_oy`만큼 옮겨 그린다 (FR265 416px 대응).
- 스프라이트 런 인코딩: `x | y<<6 | w<<12 | color<<18`, 팔레트 0=투명, 1=외곽선(AOD에서 이것만 그림).
- 배열 리터럴은 `as Array<...>`로 캐스트한다 (최신 SDK는 리터럴을 Tuple로 추론).
- 빌드 플래그 `-l 0`(타입검사 끔)을 쓴다.

## 빌드/검증
- 클라우드 세션에서는 Garmin 서버가 막혀 SDK를 설치할 수 없다. 실제 컴파일은 GitHub Actions(`.github/workflows/build.yml`,
  비밀값 `GARMIN_USERNAME`/`GARMIN_PASSWORD`)나 사용자 PC(`build.ps1`)에서 한다.
- 로컬에서 확인 가능한 것: `python3 tools/gen_sprites.py`, `node --check preview/watchface.js`, Playwright로 `preview/index.html` 렌더링.
- 미리보기 아티팩트: https://claude.ai/artifact/Wind66oE6g2tE6cQ7jFWqY (preview/index.html + sprites.js + watchface.js)

## 문서
- 사용자 안내는 한국어 `README.md`.
