import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// 사용자 설정 (Garmin Connect 앱 설정 + 워치 자체 메뉴 공용)
// 값은 Application.Properties 에 저장되어 재부팅 후에도 유지된다.
// 목록형 설정은 모두 "선택지 인덱스(Number)" 로 저장한다.
module Settings {
    // 목록형 설정 인덱스
    const STYLE = 0;        // 0 픽셀아트, 1 디지털
    const CHARACTER = 1;    // 전체판: 0 모찌, 1 도롱이, 2 매일 랜덤 / 스토어판: 0 모찌
    const CHAR_STYLE = 2;   // 0 자동(워치페이스 스타일), 1 픽셀아트, 2 디지털
    const CHAR_SIZE = 3;    // 0 작게, 1 보통, 2 크게
    const BACKGROUND = 4;   // 0 자동(시간대), 1 아침, 2 낮, 3 저녁, 4 밤, 5 심플(검정)
    const ACCENT = 5;       // 0 자동, 1 핑크, 2 하늘, 3 주황, 4 민트, 5 보라, 6 노랑
    const TIME_COLOR = 6;   // 0 흰색, 1 강조색
    const RING = 7;         // 0 걸음, 1 배터리, 2 Body Battery, 3 초, 4 끄기
    const SLOT1 = 8;        // 정보 칸 1~4 (DATA_*)
    const SLOT2 = 9;
    const SLOT3 = 10;
    const SLOT4 = 11;
    const SLEEP_AT = 12;    // 취침 시각 (SLEEP_HOURS 인덱스)
    const WAKE_AT = 13;     // 기상 시각 (WAKE_HOURS 인덱스)
    const DATE_LANG = 14;   // 날짜 언어: 0 워치 언어, 1 영어, 2 한국어
    const SCENERY = 15;     // 풍경: 0 풀밭, 1 바다, 2 도시, 3 설산, 4 벚꽃, 5 단풍, 6 우주, 7 계절 자동
    const LIST_COUNT = 16;

    // 정보 칸 데이터 종류
    const DATA_NONE = 0;
    const DATA_HR = 1;
    const DATA_BB = 2;
    const DATA_STEPS = 3;
    const DATA_BATTERY = 4;
    const DATA_CALORIES = 5;
    const DATA_DISTANCE = 6;
    const DATA_FLOORS = 7;
    const DATA_STRESS = 8;
    const DATA_TEMP = 9;
    const DATA_NOTIF = 10;


    var KEYS as Array<String> = ["Style", "Character", "CharStyle", "CharSize", "Background", "Accent",
        "TimeColor", "Ring", "Slot1", "Slot2", "Slot3", "Slot4", "SleepAt", "WakeAt", "DateLang", "Scenery"] as Array<String>;
    var COUNTS as Array<Number> = [2, 5, 3, 3, 6, 7, 2, 5, 11, 11, 11, 11, 5, 5, 3, 8] as Array<Number>;
    var DEFAULTS as Array<Number> = [0, 0, 0, 1, 0, 0, 0, 0, 1, 4, 2, 3, 2, 1, 0, 0] as Array<Number>;
    var SLEEP_HOURS as Array<Number> = [21, 22, 23, 0, 1] as Array<Number>;
    var WAKE_HOURS as Array<Number> = [5, 6, 7, 8, 9] as Array<Number>;

    var vals as Array<Number> = [0, 0, 0, 1, 0, 0, 0, 0, 1, 4, 2, 3, 2, 1, 0, 0] as Array<Number>;
    var showDate as Boolean = true;
    var animate as Boolean = true;
    var weatherFx as Boolean = true;

    function load() as Void {
        // 캐릭터 선택지 수는 빌드 판에 따라 다름 (전체판: 캐릭터 + 매일 랜덤, 스토어판: 모찌 1개)
        COUNTS[CHARACTER] = Sprites.CHARACTER_COUNT > 1 ? Sprites.CHARACTER_COUNT + 1 : 1;
        for (var i = 0; i < LIST_COUNT; i++) {
            var v = getNum(KEYS[i], DEFAULTS[i]);
            vals[i] = (v < 0 || v >= COUNTS[i]) ? DEFAULTS[i] : v;
        }
        showDate = getBool("ShowDate", true);
        animate = getBool("Animate", true);
        weatherFx = getBool("WeatherFx", true);
    }

    function get(i as Number) as Number {
        return vals[i];
    }

    function set(i as Number, v as Number) as Void {
        vals[i] = v;
        setVal(KEYS[i], v);
    }

    function setShowDate(v as Boolean) as Void {
        showDate = v;
        setVal("ShowDate", v);
    }

    function setWeatherFx(v as Boolean) as Void {
        weatherFx = v;
        setVal("WeatherFx", v);
    }

    function setAnimate(v as Boolean) as Void {
        animate = v;
        setVal("Animate", v);
    }

    // 실제로 그릴 캐릭터 (랜덤이면 날짜 기준으로 하루 동안 고정)
    function currentCharacter() as Number {
        var c = vals[CHARACTER];
        if (c < Sprites.CHARACTER_COUNT) {
            return c;
        }
        var days = Time.now().value() / 86400;
        return (days % Sprites.CHARACTER_COUNT).toNumber();
    }

    // 캐릭터를 부드러운(디지털) 그림으로 그릴지
    function smoothCharacter() as Boolean {
        var cs = vals[CHAR_STYLE];
        if (cs == 0) {
            return vals[STYLE] == 1;
        }
        return cs == 2;
    }

    // 날짜를 한글로 표시할지
    function koreanDate() as Boolean {
        var l = vals[DATE_LANG];
        if (l == 0) {
            return System.getDeviceSettings().systemLanguage == System.LANGUAGE_KOR;
        }
        return l == 2;
    }

    function sleepHour() as Number {
        return SLEEP_HOURS[vals[SLEEP_AT]];
    }

    function wakeHour() as Number {
        return WAKE_HOURS[vals[WAKE_AT]];
    }

    // ---- 메뉴 라벨 ----
    function title(i as Number) as ResourceId {
        return ([Rez.Strings.StyleTitle, Rez.Strings.CharTitle, Rez.Strings.CharStyleTitle,
                 Rez.Strings.CharSizeTitle, Rez.Strings.BgTitle, Rez.Strings.AccentTitle,
                 Rez.Strings.TimeColorTitle, Rez.Strings.RingTitle, Rez.Strings.Slot1Title,
                 Rez.Strings.Slot2Title, Rez.Strings.Slot3Title, Rez.Strings.Slot4Title,
                 Rez.Strings.SleepTitle, Rez.Strings.WakeTitle, Rez.Strings.DateLangTitle,
                 Rez.Strings.SceneryTitle] as Array<ResourceId>)[i];
    }

    function labels(i as Number) as Array<ResourceId> {
        if (i == STYLE) {
            return [Rez.Strings.StylePixel, Rez.Strings.StyleDigital] as Array<ResourceId>;
        } else if (i == CHARACTER) {
            var names = Sprites.characterNames();
            if (names.size() > 1) {
                names.add(Rez.Strings.CharRandom);
            }
            return names;
        } else if (i == CHAR_STYLE) {
            return [Rez.Strings.CharStyleAuto, Rez.Strings.StylePixel, Rez.Strings.StyleDigital] as Array<ResourceId>;
        } else if (i == CHAR_SIZE) {
            return [Rez.Strings.SizeS, Rez.Strings.SizeM, Rez.Strings.SizeL] as Array<ResourceId>;
        } else if (i == BACKGROUND) {
            return [Rez.Strings.BgAuto, Rez.Strings.BgMorning, Rez.Strings.BgDay,
                    Rez.Strings.BgEvening, Rez.Strings.BgNight, Rez.Strings.BgSimple] as Array<ResourceId>;
        } else if (i == ACCENT) {
            return [Rez.Strings.ColorAuto, Rez.Strings.ColorPink, Rez.Strings.ColorSky, Rez.Strings.ColorOrange,
                    Rez.Strings.ColorMint, Rez.Strings.ColorPurple, Rez.Strings.ColorYellow] as Array<ResourceId>;
        } else if (i == TIME_COLOR) {
            return [Rez.Strings.ColorWhite, Rez.Strings.ColorAccent] as Array<ResourceId>;
        } else if (i == RING) {
            return [Rez.Strings.DataSteps, Rez.Strings.DataBattery, Rez.Strings.DataBB,
                    Rez.Strings.RingSeconds, Rez.Strings.Off] as Array<ResourceId>;
        } else if (i == SLEEP_AT) {
            return [Rez.Strings.H21, Rez.Strings.H22, Rez.Strings.H23, Rez.Strings.H0, Rez.Strings.H1] as Array<ResourceId>;
        } else if (i == SCENERY) {
            return [Rez.Strings.ScnMeadow, Rez.Strings.ScnSea, Rez.Strings.ScnCity, Rez.Strings.ScnSnow,
                    Rez.Strings.ScnCherry, Rez.Strings.ScnAutumn, Rez.Strings.ScnSpace,
                    Rez.Strings.ScnSeason] as Array<ResourceId>;
        } else if (i == DATE_LANG) {
            return [Rez.Strings.LangAuto, Rez.Strings.LangEng, Rez.Strings.LangKor] as Array<ResourceId>;
        } else if (i == WAKE_AT) {
            return [Rez.Strings.H5, Rez.Strings.H6, Rez.Strings.H7, Rez.Strings.H8, Rez.Strings.H9] as Array<ResourceId>;
        }
        // 정보 칸
        return [Rez.Strings.DataNone, Rez.Strings.DataHR, Rez.Strings.DataBB, Rez.Strings.DataSteps,
                Rez.Strings.DataBattery, Rez.Strings.DataCalories, Rez.Strings.DataDistance,
                Rez.Strings.DataFloors, Rez.Strings.DataStress, Rez.Strings.DataTemp,
                Rez.Strings.DataNotif] as Array<ResourceId>;
    }

    function label(i as Number) as ResourceId {
        return labels(i)[vals[i]];
    }

    // ---- 내부 ----
    function getVal(key as String) {
        try {
            return Application.Properties.getValue(key);
        } catch (e) {
            return null;
        }
    }

    function setVal(key as String, v) as Void {
        try {
            Application.Properties.setValue(key, v);
        } catch (e) {
        }
    }

    function getNum(key as String, def as Number) as Number {
        var v = getVal(key);
        if (v instanceof Number) {
            return v;
        }
        if (v instanceof Long || v instanceof Float || v instanceof Double) {
            return v.toNumber();
        }
        return def;
    }

    function getBool(key as String, def as Boolean) as Boolean {
        var v = getVal(key);
        return (v instanceof Boolean) ? v : def;
    }
}
