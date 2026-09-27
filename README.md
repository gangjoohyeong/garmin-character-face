# Pixel Pals: Forerunner 265S 워치페이스

포켓몬 슬립 느낌의 픽셀 캐릭터 워치페이스입니다.

| 항목 | 선택지 |
|---|---|
| 워치페이스 스타일 | 픽셀아트 / 디지털 |
| 캐릭터 | 모찌(오리지널) / 꼬부기 / 파이리 / 도롱이 / 매일 랜덤 |
| 캐릭터 스타일 | 워치페이스 따라감 / 픽셀아트 / 디지털(부드러운 벡터) |
| 캐릭터 크기 | 작게 / 보통 / 크게 |
| 배경 | 자동(시간대) / 아침 / 낮 / 저녁 / 밤 / 심플(검정) |
| 강조색 | 자동 / 핑크 / 하늘 / 주황 / 민트 / 보라 / 노랑 |
| 시각 색상 | 흰색 / 강조색 |
| 바깥 링 | 걸음 / 배터리 / Body Battery / 초 / 끄기 |
| 정보 칸 1~4 | 없음 / 심박 / Body Battery / 걸음 / 배터리 / 칼로리 / 거리 / 오른 층수 / 스트레스 |
| 날짜 | 표시 켜기·끄기, 언어: 워치 언어 따라감 / English / 한국어 |
| 캐릭터 취침·기상 | 취침 21~1시, 기상 5~9시 |
| 애니메이션 | 켜기 / 끄기 |

- **시간대 연출**: 05–10시 아침, 10–17시 낮, 17–20시 저녁, 20–05시 밤 (배경이 '자동'일 때)
- **캐릭터 상태**: 깜빡임, 숨쉬기(들썩임), 기상 후 3시간 동안 가끔 하품, 취침~기상 사이 수면(Zzz), 파이리 꼬리 불꽃 깜빡임
- **날짜 표시**: 영어 `SAT 27 SEP` / 한국어 `9월 27일 토`. 워치 기본 폰트에 한글이 없는 모델이 있어 한글은 직접 만든 픽셀 글자로 그립니다.
- **정보 배치**: 픽셀아트는 나무판에 칸 1~4를 2줄로, 디지털은 칸 1~3을 가로로 놓고 칸 4를 맨 아래에 작게 표시
- **AOD(항상 켜짐)**: 켜진 픽셀을 최소화하고 매분 위치를 옮겨 번인을 막음. 캐릭터는 외곽선만, 분마다 도는 점 표시

## 폴더 구조

```
garmin-character-face/
├─ manifest.xml              앱 정보 (fr265s, fr265)
├─ monkey.jungle
├─ build.ps1 / build.sh      빌드 스크립트
├─ source/
│  ├─ MochiFaceApp.mc        앱 진입점, 설정 변경 처리
│  ├─ MochiFaceView.mc       화면 그리기 (픽셀/디지털/AOD)
│  ├─ Pix.mc                 픽셀 캐릭터·픽셀폰트·한글 날짜 그리기
│  ├─ Smooth.mc              디지털(벡터) 캐릭터 그리기
│  ├─ Settings.mc            설정 저장/불러오기
│  ├─ SettingsMenu.mc        워치 자체 설정 메뉴
│  └─ Sprites.mc             (자동 생성) 캐릭터·폰트·한글 데이터
├─ resources/                영어 문자열, 설정 정의, 아이콘
├─ resources-kor/            한국어 문자열 (워치 언어가 한국어면 자동 사용)
├─ tools/gen_sprites.py      캐릭터 그림 정의 → Sprites.mc / sprites.js 생성
└─ preview/index.html        브라우저 미리보기
```

## 1. SDK 설치 (처음 한 번)

1. <https://developer.garmin.com/connect-iq/sdk/> 에서 **SDK Manager**를 받아 실행합니다.
2. Garmin 계정으로 로그인합니다.
3. **SDK** 탭에서 최신 SDK를 설치하고 *Use as Active SDK*를 누릅니다.
4. **Devices** 탭에서 **Forerunner 265S**(원하면 265도)를 다운로드합니다.
5. (선택) VS Code에 **Monkey C** 확장을 설치합니다.

Java가 필요하다는 메시지가 나오면 JDK 17 이상을 설치하세요.

## 2. 빌드와 시뮬레이터

PowerShell에서 `garmin-character-face` 폴더로 이동한 뒤:

```powershell
.\build.ps1 -Run
```

- 빌드 결과: `bin\PixelPals.prg`
- 개발자 키: 기존 `keys\developer_key.der`를 그대로 씁니다. 없으면 자동으로 만듭니다.
- 실행 정책 오류가 나면: `powershell -ExecutionPolicy Bypass -File .\build.ps1 -Run`

시뮬레이터에서 확인할 것:

| 확인 항목 | 시뮬레이터 메뉴 |
|---|---|
| 설정 바꾸기 | File → Edit Persistent Storage → Edit Application.Properties data |
| AOD 화면 | Settings → Display Mode → Always On / 또는 Low Power Mode |
| 시간대별 배경 | Simulation → Time Simulator |
| 심박·걸음 값 | Simulation → Activity Data |

## 3. 워치에 설치 (사이드로드)

1. 워치를 USB로 PC에 연결합니다.
2. 탐색기에서 `Forerunner 265S\Internal Storage\GARMIN\APPS` 폴더를 엽니다.
3. `bin\PixelPals.prg`를 복사합니다.
4. 케이블을 뽑으면 워치가 앱을 설치합니다.
5. 워치에서 시계 화면을 길게 누르기 → **워치 페이스** → **Pixel Pals(픽셀 친구들)** 선택.

## CI 자동 빌드 (GitHub Actions)

`main`에 푸시하거나 PR을 열면 `.github/workflows/build.yml`이 실행됩니다.

- **check**: 스프라이트 생성 결과가 커밋된 파일과 같은지, 미리보기 JS 문법이 맞는지 검사합니다. 설정 없이 항상 돕니다.
- **build**: Connect IQ SDK를 받아 FR265S / FR265용으로 실제 컴파일하고, `.prg` 파일을 Actions 결과물(`PixelPals-prg`)로 올립니다.
  이 결과물을 받아 바로 워치에 복사해도 됩니다.

build 작업을 켜려면 저장소 **Settings → Secrets and variables → Actions → New repository secret**에서 두 값을 등록하세요.

| 이름 | 값 |
|---|---|
| `GARMIN_USERNAME` | Garmin 계정 이메일 |
| `GARMIN_PASSWORD` | Garmin 계정 비밀번호 |

SDK와 기기 파일은 Garmin 계정으로 로그인해야 받을 수 있어서 필요합니다. 비밀값이 없으면 build 작업은 경고만 남기고 건너뜁니다.
계정에 2단계 인증이 켜져 있으면 로그인이 실패할 수 있습니다.

## 4. 설정 바꾸는 방법

- **워치에서**: 시계 화면 길게 누르기 → 워치 페이스 → Pixel Pals → **사용자 지정(Customize)**
  항목을 누르면 선택지 목록이 열리고, 고르면 바로 저장됩니다.
- **휴대폰에서**: Garmin Connect 앱 → 기기 → 워치 페이스 → Pixel Pals → 설정
  (Connect IQ 스토어로 설치한 경우에만 표시됩니다. 사이드로드한 앱은 워치 메뉴를 사용하세요.)

## 5. 캐릭터 수정·추가

모든 그림은 `tools/gen_sprites.py` 한 파일에 있습니다.

- **픽셀 캐릭터**: 문자 격자로 그립니다. `K` = 외곽선(AOD에서 이 픽셀만 표시), `.` = 투명, 그 외 문자 = `palette`의 색.
  도롱이처럼 도형을 채운 뒤 외곽선을 자동으로 두르는 방식도 쓸 수 있습니다(`build_dorongi_grid`).
- **디지털 캐릭터**: `SMOOTH` 목록에 원·타원·호·선 도형으로 그립니다 (100x100 상자, 발바닥 y=100).
- **한글 글자**: `HANGUL`에 7x10 픽셀로 있습니다.

수정한 뒤 `python tools/gen_sprites.py`를 실행하면 워치용 `source/Sprites.mc`와
미리보기용 `preview/sprites.js`가 함께 갱신됩니다 (`build.ps1`도 자동 실행).
새 캐릭터를 추가하면 `Settings.mc`의 `CHARACTER_COUNT`·`COUNTS`, 문자열, `settings.xml` 목록도 늘려 주세요.

## 참고

- 꼬부기·파이리는 개인 사용 목적의 팬아트입니다. 도롱이는 사용자가 제공한 캐릭터 그림을 바탕으로 그렸습니다. 닌텐도/포켓몬 IP라서 Connect IQ 스토어에 공개 배포하면 안 됩니다. 스토어에 올리려면 모찌처럼 오리지널 캐릭터만 넣으세요.
- 워치페이스는 고전력 모드(손목을 들었을 때 약 10초)에만 1초마다 갱신되고, 그 외에는 1분마다 갱신됩니다. 애니메이션은 손목을 든 동안에만 움직입니다.
