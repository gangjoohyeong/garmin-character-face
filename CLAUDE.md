# Pixel Pals (Garmin Connect IQ 워치페이스)

Forerunner 265S/265용 픽셀 캐릭터 워치페이스. Monkey C.

## 규칙
- 캐릭터·폰트·아이콘 그림은 `tools/gen_sprites.py`에서만 수정한다. 수정 후 `python3 tools/gen_sprites.py`를 실행해
  `source-full/Sprites.mc`, `source-store/Sprites.mc`, `preview/sprites.js`, 아이콘들을 재생성하고 함께 커밋한다.
- 빌드 판이 둘이다: 전체판(`monkey.jungle`, source-full/resources-full) = 4캐릭터 개인용,
  스토어판(`store.jungle`, source-store/resources-store) = 모찌만. 공통 코드는 `source/`.
  팬아트 캐릭터 이름·에셋·설정 목록은 절대 공통 폴더나 스토어 폴더에 넣지 않는다 (`check_resources.py`가 검사).
- `preview/watchface.js`는 `source/MochiFaceView.mc`, `Pix.mc`, `Smooth.mc`를 그대로 옮긴 것이다. 화면 로직을 바꾸면 둘 다 수정한다.
- 설정 항목을 추가하면 `Settings.mc`(KEYS/COUNTS/DEFAULTS/labels), `SettingsMenu.mc`, 영/한 `strings.xml`,
  두 판의 `properties.xml`·`settings.xml`, `preview/index.html`의 OPTIONS를 함께 바꾼다.
- 검사: `python3 tools/check_resources.py`, `cd tools/check && npm ci && npm run lint`(+ source-full, source-store),
  `NODE_PATH=$(npm root -g) node tools/check/render_matrix.mjs` (AOD·겹침), `node tools/check/store_screens.mjs`.
- 캐릭터: 0 모찌, 1 꼬부기, 2 파이리, 3 도롱이. 픽셀(격자) + 디지털(SMOOTH 벡터 도형) 두 벌이 있다.
- 디지털 캐릭터 스타일은 `tools/fetch_assets.py`가 만든 비트맵(꼬부기/파이리 = PokeAPI 공식 아트, 도롱이 = `assets/dorongi.png`)을
  우선 쓰고, 없으면 `Smooth.mc` 벡터로 대체한다. 에셋과 생성물(`source-full/Assets.mc`, `resources-full/drawables/`,
  `preview/assets.js`)은 저작권 때문에 커밋하지 않는다 (공개 저장소). 로컬 확인 전 `pip install pillow && python3 tools/fetch_assets.py`.
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
