import Toybox.Lang;
import Toybox.WatchUi;

// 워치에서 직접 여는 설정 메뉴
// (워치페이스 길게 누르기 → 워치 페이스 → 사용자 지정/Customize)
// 항목을 누를 때마다 다음 값으로 바뀌고 즉시 저장된다.
class SettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => Rez.Strings.MenuTitle});
        addItem(new WatchUi.MenuItem(Rez.Strings.StyleTitle, Settings.styleLabel(), :style, null));
        addItem(new WatchUi.MenuItem(Rez.Strings.CharTitle, Settings.characterLabel(), :character, null));
        addItem(new WatchUi.MenuItem(Rez.Strings.BgTitle, Settings.backgroundLabel(), :background, null));
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.AnimTitle, null, :animate, Settings.animate, null));
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id == :style) {
            Settings.style = (Settings.style + 1) % Settings.STYLE_COUNT;
            item.setSubLabel(Settings.styleLabel());
        } else if (id == :character) {
            Settings.character = (Settings.character + 1) % Settings.CHAR_COUNT;
            item.setSubLabel(Settings.characterLabel());
        } else if (id == :background) {
            Settings.background = (Settings.background + 1) % Settings.BG_COUNT;
            item.setSubLabel(Settings.backgroundLabel());
        } else if (id == :animate) {
            Settings.animate = (item as ToggleMenuItem).isEnabled();
        }
        Settings.save();
        WatchUi.requestUpdate();
    }
}
