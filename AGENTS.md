# Pixel Pals (Garmin Connect IQ 워치페이스)

Forerunner 265S/265용 픽셀 캐릭터 워치페이스. Monkey C.

## 규칙
- 캐릭터·폰트·아이콘 그림은 `tools/gen_sprites.py`에서만 수정한다. 수정 후 `python3 tools/gen_sprites.py`를 실행해
  `source-full/Sprites.mc`, `source-store/Sprites.mc`, `preview/sprites.js`, 아이콘들을 재생성하고 함께 커밋한다.
- 빌드 판이 둘이다: 전체판(`monkey.jungle`, 앱 이름 Pixel Pals, 사이드로드용)과 스토어판(`store.jungle`,
  manifest-store.xml, 앱 이름 Mochi Pixel, 별도 앱 ID). 캐릭터는 둘 다 모찌·도롱이(둘 다 사용자 오리지널).
  공통 코드·문자열·아이콘·에셋은 `source/`, `resources/`. 판별로 다른 것은 Sprites.mc(`"store": True` 캐릭터만)와 설정 XML.
- `preview/watchface.js`는 `source/MochiFaceView.mc`, `Pix.mc`, `Smooth.mc`, `Scenery.mc`를 그대로 옮긴 것이다. 화면 로직을 바꾸면 둘 다 수정한다.
- 설정 항목을 추가하면 `Settings.mc`(KEYS/COUNTS/DEFAULTS/labels), `SettingsMenu.mc`, 영/한 `strings.xml`,
  두 판의 `properties.xml`·`settings.xml`, `preview/index.html`의 OPTIONS를 함께 바꾼다.
- 검사: `python3 tools/check_resources.py`, `cd tools/check && npm ci && npm run lint`(+ source-full, source-store),
  `NODE_PATH=$(npm root -g) node tools/check/render_matrix.mjs` (AOD·겹침), `node tools/check/store_screens.mjs`.
- 캐릭터: 0 모찌, 1 도롱이. 픽셀(격자) + 디지털(SMOOTH 벡터 도형) 두 벌이 있다.
- 저작권 문제로 팬아트 캐릭터를 제거했다 (이전 상태: `backup/fanart-characters` 브랜치). 다시 넣지 않는다.
  `check_resources.py`의 BANNED 목록이 관련 이름이 들어오면 실패시킨다.
- 디지털 캐릭터 스타일은 `tools/fetch_assets.py`가 만든 비트맵(도롱이 = `assets/dorongi.png`, 사용자가 제공·커밋 허락함, 표정 5종 자동 생성)을
  우선 쓰고, 없으면 `Smooth.mc` 벡터로 대체한다. 생성물(`source/Assets.mc`, `resources/drawables/assets*`,
  `preview/assets.js`)은 커밋하지 않는다. 로컬 확인 전 `pip install pillow && python3 tools/fetch_assets.py`.
- 한글 날짜는 시스템 폰트 대신 `HANGUL` 픽셀 글리프로 그린다 (한글 폰트 없는 모델 대비).
- 좌표는 360x360 기준으로 설계하고 `_ox/_oy`만큼 옮겨 그린다 (FR265 416px 대응).
- 스프라이트 런 인코딩: `x | y<<6 | w<<12 | color<<18`, 팔레트 0=투명, 1=외곽선(AOD에서 이것만 그림).
- 배열 리터럴은 `as Array<...>`로 캐스트한다 (최신 SDK는 리터럴을 Tuple로 추론).
- 빌드 플래그 `-l 0`(타입검사 끔)을 쓴다.

## 빌드/검증
- 클라우드 세션에서는 Garmin 서버가 막혀 SDK를 설치할 수 없다. 실제 컴파일은 GitHub Actions(`.github/workflows/build.yml`,
  비밀값 `GARMIN_USERNAME`/`GARMIN_PASSWORD` 등록됨)나 사용자 PC(`build.ps1`)에서 한다.
- CI 결과는 로그인 없이 공개 API로 확인한다: `actions/runs?head_sha=<sha>` → `runs/<id>/jobs` → `check-runs/<job id>/annotations`.
  컴파일 단계가 monkeyc의 ERROR/WARNING 줄과 단계별 "성공"을 annotation으로 남긴다.
- 로컬에서 확인 가능한 것: `python3 tools/gen_sprites.py`, `node --check preview/watchface.js`, Playwright로 `preview/index.html` 렌더링.
- 미리보기 아티팩트: https://claude.ai/artifact/Wind66oE6g2tE6cQ7jFWqY (preview/index.html + sprites.js + watchface.js)

## 문서
- 사용자 안내는 한국어 `README.md`.
