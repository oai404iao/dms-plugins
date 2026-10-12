import QtQuick
import QtQuick.Window
import QtTest
import "plugin"
import "overlay"
import qs.Common
import qs.Services
import "plugin/LyricsFetcher.js" as Fetcher

TestCase {
    id: testCase
    name: "LyricsSettingsDismissal"

    Window {
        id: hostWindow
        width: 1000
        height: 700
        visible: true
    }

    Component {
        id: serviceComponent
        LyricsService {}
    }
    Component {
        id: dashComponent
        DankDashPopout {}
    }

    property var service: null
    property var dash: null

    function init() {
        Fetcher.setDeferred(false);
        Fetcher.resetCalls();
        Fetcher.clearCache();
        SettingsData.pluginSettings = ({ lyrics: {} });
        PluginService.pluginDaemonInstances = ({});
        MprisController.activePlayer = null;
        service = serviceComponent.createObject(testCase, {
            pluginId: "lyrics", pluginService: ({ stub: true })
        });
        verify(service !== null);
        PluginService.pluginDaemonInstances = ({ lyrics: service });
        dash = dashComponent.createObject(hostWindow.contentItem, {
            width: 1000, height: 700, currentTabId: "media"
        });
        verify(dash !== null);
        dash.dashVisible = true;
        hostWindow.requestActivate();
        tryCompare(hostWindow, "active", true);
        tryVerify(() => dash.__mediaTabRef !== null);
        verify(dash.contentLoader.item !== null);
        verify(dash.overlayLoader.item !== null);
    }

    function cleanup() {
        if (dash) {
            dash.dashVisible = false;
            dash.destroy();
            dash = null;
        }
        PluginService.pluginDaemonInstances = ({});
        if (service) {
            service.destroy();
            service = null;
        }
        wait(0);
    }

    function openSettings() {
        dash.__mediaTabRef.showLyricsDropdown(Qt.point(700, 350), null, true);
        compare(dash.__dropdownType, 4);
        compare(dash.hoverDismissSuspended, true);
        compare(dash.overlayLoader.item.activePanel.visible, true);
        var loader = settingsLoader();
        verify(loader !== null && loader.item !== null);
        return loader.item;
    }

    function settingsLoader() {
        var panel = dash.overlayLoader.item.activePanel;
        if (!panel)
            return null;
        for (var i = 0; i < panel.children.length; i++) {
            if (panel.children[i].sourceComponent !== undefined)
                return panel.children[i];
        }
        return null;
    }

    function findDropdown(item, label) {
        if (item.isLifecycleMock === true && item.text === label)
            return item;
        for (var i = 0; i < item.children.length; i++) {
            var result = findDropdown(item.children[i], label);
            if (result)
                return result;
        }
        return null;
    }

    function sourceDropdown() {
        var result = findDropdown(settingsLoader().item, "Lyrics source");
        verify(result !== null, "the real LyricsSettings must instantiate its source selector");
        return result;
    }

    function focusForKeys(item) {
        hostWindow.requestActivate();
        tryCompare(hostWindow, "active", true);
        item.forceActiveFocus();
        tryCompare(item, "activeFocus", true);
    }

    function test_10_real_selectors_defaults_save_reload_and_tracker() {
        service.translationAvailable = true;
        var view = openSettings();
        var source = sourceDropdown();
        var translation = findDropdown(view, "Available translation");
        verify(translation !== null);
        compare(source.currentValue, "NetEase first");
        compare(source.options.length, 4);
        compare(translation.currentValue, "Provider translation");
        compare(translation.options.length, 1);
        compare(source.transientSurfaceTracker, dash.transientSurfaceTracker);
        compare(translation.transientSurfaceTracker, dash.transientSurfaceTracker);

        source.menuOpen = true;
        translation.menuOpen = true;
        compare(dash.transientSurfaceTracker.entries.length, 2);
        dash.transientSurfaceTracker.closeAll();
        compare(source.menuOpen, false, "tracker close requests must close source menus");
        compare(translation.menuOpen, false, "tracker close requests must close translation menus");
        compare(dash.transientSurfaceTracker.active, false);

        source.select("LRCLIB only");
        compare(SettingsData.pluginSettings.lyrics.lyricsSource, "lrclib_only");
        compare(service.lyricsSource, "lrclib_only");
        // A source change clears provider translations until another fetch completes.
        service.translationAvailable = true;
        translation.select("Provider translation");
        compare(SettingsData.pluginSettings.lyrics.translationLanguage, "source");

        SettingsData.pluginSettings = ({
            lyrics: { lyricsSource: "lrclib", translationLanguage: "other" }
        });
        compare(source.currentValue, "LRCLIB first");
        compare(translation.currentValue, "other");
        service.translationAvailable = true;
        translation.select("Provider translation");
        compare(service.translationLanguage, "source");

        dash.__hideDropdowns();
        openSettings();
        source = sourceDropdown();
        compare(source.currentValue, "LRCLIB first", "reopening must load persisted preferences");
        translation = findDropdown(settingsLoader().item, "Available translation");
        compare(translation.currentValue, "Provider translation");
        compare(translation.transientSurfaceTracker, dash.transientSurfaceTracker);
    }

    function test_11_destroying_settings_unregisters_open_menus() {
        openSettings();
        sourceDropdown().menuOpen = true;
        compare(dash.transientSurfaceTracker.active, true);
        // Direct unload exercises dropdown destruction independently of closeAll().
        var loader = settingsLoader();
        loader.active = false;
        compare(loader.item, null);
        compare(dash.transientSurfaceTracker.active, false);
    }

    function test_20_lyrics_ignores_button_and_panel_exit() {
        openSettings();
        var loader = settingsLoader();
        sourceDropdown().menuOpen = true;
        dash.__mediaTabRef.dropdownButtonExited();
        dash.overlayLoader.item.panelExited();
        wait(450);
        compare(dash.__dropdownType, 4, "lyrics settings must survive the 400ms hover timeout");
        verify(loader.item !== null);
        compare(sourceDropdown().menuOpen, true);
        compare(dash.transientSurfaceTracker.active, true);
    }

    function test_21_switching_from_volume_cancels_pending_timer() {
        dash.__showVolumeDropdown(Qt.point(700, 350), true, null, []);
        dash.__startCloseTimer();
        wait(50);
        openSettings();
        wait(450);
        compare(dash.__dropdownType, 4);
        verify(settingsLoader().item !== null);
    }

    function test_22_stale_timer_cannot_close_lyrics() {
        openSettings();
        var timer = null;
        var resources = dash.resources;
        for (var i = 0; i < resources.length; i++) {
            if (resources[i].interval === 400)
                timer = resources[i];
        }
        verify(timer !== null, "must exercise the production 400ms Timer");
        timer.restart();
        wait(450);
        compare(dash.__dropdownType, 4, "a stale timer firing must still leave lyrics open");
    }

    function test_23_original_dropdowns_still_hover_close_data() {
        return [{ tag: "volume", type: 1 }, { tag: "devices", type: 2 }, { tag: "players", type: 3 }];
    }

    function test_23_original_dropdowns_still_hover_close(data) {
        if (data.type === 1)
            dash.__showVolumeDropdown(Qt.point(700, 350), true, null, []);
        else if (data.type === 2)
            dash.__showAudioDevicesDropdown(Qt.point(700, 350), true);
        else
            dash.__showPlayersDropdown(Qt.point(700, 350), true, null, []);
        compare(dash.__dropdownType, data.type);
        compare(dash.hoverDismissSuspended, false);
        dash.__mediaTabRef.dropdownButtonExited();
        tryCompare(dash, "__dropdownType", 0, 1000);
        compare(dash.dashVisible, true);
    }

    function test_24_settings_blocks_media_shortcuts_and_tab_switches() {
        var media = dash.__mediaTabRef;
        focusForKeys(dash.contentLoader.item);
        keyClick(Qt.Key_M);
        compare(media.shortcutCount, 1, "the fixture must detect normal media shortcut dispatch");
        media.shortcutCount = 0;
        openSettings();
        compare(sourceDropdown().menuOpen, false);
        wait(450);
        compare(dash.dashVisible, true);
        compare(dash.hoverDismissSuspended, true, "settings context protects the parent even with no menu open");
        focusForKeys(dash.contentLoader.item);
        var keys = [Qt.Key_Up, Qt.Key_Down, Qt.Key_M, Qt.Key_Space, Qt.Key_Tab, Qt.Key_Backtab];
        for (var i = 0; i < keys.length; i++)
            keyClick(keys[i]);
        compare(media.shortcutCount, 0);
        compare(dash.currentTabId, "media");
        compare(dash.__dropdownType, 4);
        compare(dash.dashVisible, true);
    }

    function test_30_explicit_dismissal_closes_tracked_menus_data() {
        return [
            { tag: "outside", action: "outside" },
            { tag: "same-button-hide-signal", action: "button" },
            { tag: "main-content-scrim", action: "scrim" },
            { tag: "escape-from-main", action: "escape" },
            { tag: "escape-from-overlay", action: "overlayEscape" },
            { tag: "tab-change", action: "tab" },
            { tag: "daemon-removal", action: "daemon" },
            { tag: "dash-hide", action: "hide" }
        ];
    }

    function test_30_explicit_dismissal_closes_tracked_menus(data) {
        openSettings();
        var overlay = dash.overlayLoader.item;
        var loader = settingsLoader();
        sourceDropdown().menuOpen = true;
        compare(dash.transientSurfaceTracker.active, true);
        compare(dash.transientSurfaceTracker.closeCount, 0);

        switch (data.action) {
        case "outside":
            mouseClick(overlay, 990, 690);
            break;
        case "button":
            dash.__mediaTabRef.hideDropdowns();
            break;
        case "scrim":
            // The mock puts both surfaces in one window; isolate the main scrim.
            overlay.enabled = false;
            mouseClick(dash.contentLoader.item, 30, 30);
            break;
        case "escape":
            focusForKeys(dash.contentLoader.item);
            keyClick(Qt.Key_Escape);
            break;
        case "overlayEscape":
            focusForKeys(overlay);
            keyClick(Qt.Key_Escape);
            break;
        case "tab":
            dash.currentTabId = "overview";
            break;
        case "daemon":
            PluginService.pluginDaemonInstances = ({});
            break;
        case "hide":
            dash.dashVisible = false;
            break;
        }
        compare(dash.__dropdownType, 0);
        compare(dash.hoverDismissSuspended, false);
        compare(dash.transientSurfaceTracker.active, false);
        compare(dash.transientSurfaceTracker.closeCount, 1, "dismissal must close menus before unloading");
        if (data.action !== "hide")
            compare(loader.item, null, "closing lyrics must unload the real settings view");
        compare(dash.dashVisible, data.action !== "hide");
        if (data.action === "escape" || data.action === "overlayEscape") {
            compare(dash.currentTabId, "media", "first Escape must preserve the media page");
            focusForKeys(dash.contentLoader.item);
            keyClick(Qt.Key_Escape);
            compare(dash.dashVisible, false, "second Escape must close the media page");
        }
    }
}
