import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

// 사용자 설정 (Garmin Connect 앱 설정 + 워치 자체 메뉴 공용)
// 값은 Application.Properties 에 저장되어 재부팅 후에도 유지된다.
module Settings {
    const STYLE_COUNT = 2;   // 0 픽셀아트, 1 디지털
    const CHAR_COUNT = 4;    // 0 모찌, 1 꼬부기, 2 파이리, 3 매일 랜덤
    const BG_COUNT = 6;      // 0 자동(시간대), 1 아침, 2 낮, 3 저녁, 4 밤, 5 심플(검정)

    var style as Number = 0;
    var character as Number = 0;
    var background as Number = 0;
    var animate as Boolean = true;

    function load() as Void {
        style = clamp(getNum("Style", 0), STYLE_COUNT);
        character = clamp(getNum("Character", 0), CHAR_COUNT);
        background = clamp(getNum("Background", 0), BG_COUNT);
        var a = getVal("Animate");
        animate = (a instanceof Boolean) ? a : true;
    }

    function save() as Void {
        setVal("Style", style);
        setVal("Character", character);
        setVal("Background", background);
        setVal("Animate", animate);
    }

    // 실제로 그릴 캐릭터 (랜덤이면 날짜 기준으로 하루 동안 고정)
    function currentCharacter() as Number {
        if (character < 3) {
            return character;
        }
        var days = Time.now().value() / 86400;
        return (days % 3).toNumber();
    }

    // ---- 메뉴 라벨 ----
    function styleLabel() as ResourceId {
        return ([Rez.Strings.StylePixel, Rez.Strings.StyleDigital] as Array<ResourceId>)[style];
    }

    function characterLabel() as ResourceId {
        return ([Rez.Strings.CharMochi, Rez.Strings.CharSquirtle, Rez.Strings.CharCharmander,
                 Rez.Strings.CharRandom] as Array<ResourceId>)[character];
    }

    function backgroundLabel() as ResourceId {
        return ([Rez.Strings.BgAuto, Rez.Strings.BgMorning, Rez.Strings.BgDay,
                 Rez.Strings.BgEvening, Rez.Strings.BgNight, Rez.Strings.BgSimple] as Array<ResourceId>)[background];
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

    function clamp(v as Number, n as Number) as Number {
        return (v < 0 || v >= n) ? 0 : v;
    }
}
