import Toybox.Lang;
import Toybox.WatchUi;

// 워치에서 직접 여는 설정 메뉴
// (시계 화면 길게 누르기 → 워치 페이스 → 사용자 지정/Customize)
// 목록형 항목은 누르면 선택지 목록이 열리고, 고르면 저장 후 돌아온다.
class SettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => Rez.Strings.MenuTitle});
        var order = [Settings.STYLE, Settings.CHARACTER, Settings.CHAR_STYLE, Settings.CHAR_SIZE,
                     Settings.BACKGROUND, Settings.ACCENT, Settings.TIME_COLOR, Settings.RING,
                     Settings.SLOT1, Settings.SLOT2, Settings.SLOT3, Settings.SLOT4] as Array<Number>;
        for (var n = 0; n < order.size(); n++) {
            var i = order[n];
            addItem(new WatchUi.MenuItem(Settings.title(i), Settings.label(i), i, null));
        }
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.DateTitle, null, :showDate, Settings.showDate, null));
        addItem(new WatchUi.MenuItem(Settings.title(Settings.DATE_LANG), Settings.label(Settings.DATE_LANG),
                                     Settings.DATE_LANG, null));
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.AnimTitle, null, :animate, Settings.animate, null));
        addItem(new WatchUi.MenuItem(Settings.title(Settings.SLEEP_AT), Settings.label(Settings.SLEEP_AT),
                                     Settings.SLEEP_AT, null));
        addItem(new WatchUi.MenuItem(Settings.title(Settings.WAKE_AT), Settings.label(Settings.WAKE_AT),
                                     Settings.WAKE_AT, null));
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id == :showDate) {
            Settings.setShowDate((item as ToggleMenuItem).isEnabled());
            WatchUi.requestUpdate();
        } else if (id == :animate) {
            Settings.setAnimate((item as ToggleMenuItem).isEnabled());
            WatchUi.requestUpdate();
        } else if (id instanceof Number) {
            var key = id as Number;
            var menu = new WatchUi.Menu2({:title => Settings.title(key)});
            var labels = Settings.labels(key);
            for (var v = 0; v < labels.size(); v++) {
                var sub = (v == Settings.get(key)) ? Rez.Strings.Selected : null;
                menu.addItem(new WatchUi.MenuItem(labels[v], sub, v, null));
            }
            WatchUi.pushView(menu, new OptionMenuDelegate(key, item), WatchUi.SLIDE_LEFT);
        }
    }
}

// 선택지 목록
class OptionMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _key as Number;
    private var _parent as MenuItem;

    function initialize(key as Number, parent as MenuItem) {
        Menu2InputDelegate.initialize();
        _key = key;
        _parent = parent;
    }

    function onSelect(item as MenuItem) as Void {
        Settings.set(_key, item.getId() as Number);
        _parent.setSubLabel(Settings.label(_key));
        WatchUi.requestUpdate();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
