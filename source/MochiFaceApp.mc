import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class MochiFaceApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        Settings.load();
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() {
        return [new MochiFaceView()];
    }

    // Garmin Connect 앱에서 설정을 바꿨을 때
    function onSettingsChanged() as Void {
        Settings.load();
        WatchUi.requestUpdate();
    }

    // 워치에서 직접 여는 설정 메뉴
    function getSettingsView() {
        return [new SettingsMenu(), new SettingsMenuDelegate()];
    }
}
