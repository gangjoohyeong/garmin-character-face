# Connect IQ 스토어 제출 자료 (스토어판: Mochi Pixel)

스토어에는 **스토어판**(`store.jungle`)을 올립니다. 캐릭터는 오리지널 캐릭터 모찌와 도롱이입니다.
전체판(`monkey.jungle`, Pixel Pals)은 앱 ID가 달라 개인 사이드로드용으로 따로 둡니다.

## 파일

| 항목 | 파일 |
|---|---|
| 업로드 패키지 | CI 결과물 **`MochiPixel-store-upload`** 의 `MochiPixel.iq` (본인 키 `DEVELOPER_KEY_B64` 로 서명됨), 또는 PC에서 `.\build.ps1 -Store -Release` |
| 스토어 아이콘 | `docs/store/icon-512.png` |
| 스크린샷 | `docs/store/screenshots/*.png` (360x360, `cd tools/check && npm run screens` 로 다시 생성) |

## 앱 이름

- 한국어: 모찌 픽셀
- English: Mochi Pixel

## 짧은 설명

- 한국어: 떡 캐릭터 모찌, 도마뱀 친구 도롱이와 하루를 함께 보내는 픽셀 워치페이스
- English: A pixel-art watch face with Mochi the rice cake and Dorongi the little lizard, living through your day

## 설명 (한국어)

작은 떡 캐릭터 **모찌**와 도마뱀 친구 **도롱이**가 여러분의 하루를 함께 보냅니다.

- 실제 일출·일몰에 맞춰 바뀌는 아침·낮·저녁·밤 픽셀 풍경, 날짜에 맞게 차고 기우는 달
- 손목을 들면 깜빡이고 숨 쉬고, 아침엔 하품하고, 밤엔 Zzz 잠드는 캐릭터 (매일 랜덤으로 바꿔 가며 볼 수도 있어요)
- 바다, 도시, 설산, 벚꽃, 단풍, 우주 풍경과 계절 자동 풍경
- 걸음 목표를 채우면 웃는 눈으로 축하해 줘요
- 비·눈 날씨 효과와 기온 표시
- 픽셀아트 / 디지털 두 가지 스타일, 캐릭터도 픽셀 또는 부드러운 그림으로 선택
- 정보 칸 4개를 원하는 데이터로: 심박, Body Battery, 걸음, 배터리, 칼로리, 거리, 오른 층수, 스트레스, 기온, 알림
- 강조색 7가지, 캐릭터 크기, 바깥 링(걸음/배터리/Body Battery/초), 날짜 한국어·영어
- 번인 걱정 없는 AOD(항상 켜짐) 화면

설정: 워치에서 시계 화면 길게 누르기 → 워치 페이스 → 사용자 지정, 또는 Garmin Connect 앱의 워치 페이스 설정.

## Description (English)

**Mochi**, a tiny rice-cake pal, and **Dorongi**, a little lizard friend, spend the day with you.

- Pixel-art morning, day, evening and night scenes that follow your real sunrise and sunset, with the current moon phase
- Your pal blinks and breathes when you raise your wrist, yawns in the morning and sleeps with Zzz at night (or pick a random pal each day)
- Seaside, city, snowy peaks, cherry blossom, autumn and space scenery, plus a seasonal mode
- Happy eyes when you reach your step goal
- Rain and snow effects, current temperature
- Pixel-art or digital face; pixel or smooth character
- Four configurable info fields: heart rate, Body Battery, steps, battery, calories, distance, floors, stress, temperature, notifications
- 7 accent colors, character size, outer ring (steps, battery, Body Battery, seconds), English or Korean date
- Burn-in-safe always-on display

Settings: long-press the watch face → Watch Face → Customize, or in Garmin Connect.

## 권한 설명

- **SensorHistory**: Body Battery와 스트레스 값을 정보 칸에 표시하기 위해 사용합니다. 데이터는 워치 밖으로 보내지 않습니다.

## 지원 기기

- Forerunner 265S (360x360), Forerunner 265 (416x416)

## 제출 전 체크리스트

- [ ] 시뮬레이터에서 스토어판 확인 (`.\build.ps1 -Store -Run`): 모찌·도롱이 선택과 표정이 정상인지
- [ ] 시뮬레이터 AOD 모드에서 번인 경고가 없는지 (Settings → Display Mode → Always On)
- [ ] 워치 메뉴와 Garmin Connect 설정이 모두 동작하는지
- [ ] 한국어 / 영어 기기 언어에서 글자가 깨지지 않는지
- [ ] 개발자 키(`keys\developer_key.der`) 백업 — 같은 키로만 업데이트를 올릴 수 있습니다
