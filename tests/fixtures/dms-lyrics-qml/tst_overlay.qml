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
    name: "MediaOverlayLyricsSettings"

    // The TestCase item itself stays effectively invisible, so the overlay is
    // hosted in its own shown window to make `visible`-driven logic observable.
    Window {
        id: hostWindow
        width: 800
        height: 600
        visible: true
    }

    Component {
        id: serviceComponent
        LyricsService {
        }
    }

    Component {
        id: overlayComponent
        MediaDropdownOverlay {
        }
    }

    SignalSpy {
        id: closeSpy
        signalName: "closeRequested"
    }

    SignalSpy {
        id: enteredSpy
        signalName: "panelEntered"
    }

    SignalSpy {
        id: exitedSpy
        signalName: "panelExited"
    }

    property var service: null
    property var overlay: null

    function init() {
        Fetcher.setDeferred(false);
        Fetcher.resetCalls();
        Fetcher.clearCache();
        SettingsData.pluginSettings = ({ "lyrics": {} });
        PluginService.pluginDaemonInstances = ({});
        MprisController.activePlayer = null;
    }

    function cleanup() {
        if (overlay) {
            overlay.destroy();
            overlay = null;
        }
        if (service) {
            service.destroy();
            service = null;
        }
        wait(0);
        closeSpy.target = null;
        enteredSpy.target = null;
        exitedSpy.target = null;
        PluginService.pluginDaemonInstances = ({});
        MprisController.activePlayer = null;
    }

    function makeService() {
        service = serviceComponent.createObject(testCase, {
            "pluginId": "lyrics",
            "pluginService": ({ "stub": true })
        });
        PluginService.pluginDaemonInstances = ({ "lyrics": service });
        return service;
    }

    function makeOverlay(props) {
        var spec = { "width": 800, "height": 600 };
        for (var k in props)
            spec[k] = props[k];
        overlay = overlayComponent.createObject(hostWindow.contentItem, spec);
        wait(1);
        return overlay;
    }

    // Spies must be retargeted after each overlay instance is created.
    function watchSignals() {
        closeSpy.target = overlay;
        enteredSpy.target = overlay;
        exitedSpy.target = overlay;
        closeSpy.clear();
        enteredSpy.clear();
        exitedSpy.clear();
    }

    function findLoader(parent) {
        for (var i = 0; i < parent.children.length; i++) {
            var child = parent.children[i];
            if (child && child.sourceComponent !== undefined)
                return child;
        }
        return null;
    }

    function findWindowBlur() {
        for (var i = 0; i < overlay.children.length; i++) {
            var child = overlay.children[i];
            if (child && child.blurEnabled !== undefined)
                return child;
        }
        return null;
    }

    function test_10_panel_size_and_right_anchor_side() {
        makeService();
        makeOverlay({
            dropdownType: 4,
            isRightEdge: true,
            availableBounds: Qt.rect(0, 0, 800, 600),
            anchorPos: Qt.point(200, 300)
        });
        var panel = overlay.activePanel;
        verify(panel !== null, "dropdown type 4 must select the lyrics settings panel");
        compare(panel.visible, true);
        compare(panel.width, 380);
        compare(panel.height, 560);
        compare(panel.x, 200, "right-side anchor keeps the panel left edge on the anchor");
        compare(panel.y, 20, "panel is vertically centred on the anchor");
    }

    function test_11_left_anchor_side_offsets_panel_leftwards() {
        makeService();
        makeOverlay({
            dropdownType: 4,
            isRightEdge: false,
            availableBounds: Qt.rect(0, 0, 800, 600),
            anchorPos: Qt.point(700, 300)
        });
        compare(overlay.activePanel.x, 320, "left-side anchor places the panel to its left");
    }

    function test_12_both_anchor_sides_clamp_into_bounds() {
        makeService();
        makeOverlay({
            dropdownType: 4,
            isRightEdge: true,
            availableBounds: Qt.rect(0, 0, 800, 600),
            anchorPos: Qt.point(0, 300)
        });
        compare(overlay.activePanel.x, 8, "right-side anchor clamps to the start edge");

        overlay.anchorPos = Qt.point(800, 300);
        compare(overlay.activePanel.x, 412, "right-side anchor clamps to the end edge");

        overlay.isRightEdge = false;
        overlay.anchorPos = Qt.point(0, 300);
        compare(overlay.activePanel.x, 8, "left-side anchor clamps to the start edge");
    }

    function test_13_vertical_anchor_clamps_into_bounds() {
        makeService();
        makeOverlay({
            dropdownType: 4,
            isRightEdge: true,
            availableBounds: Qt.rect(0, 0, 800, 600),
            anchorPos: Qt.point(200, 0)
        });
        compare(overlay.activePanel.y, 8, "top anchor clamps to the start edge");

        overlay.anchorPos = Qt.point(200, 600);
        compare(overlay.activePanel.y, 32, "bottom anchor clamps to the end edge");

        overlay.anchorPos = Qt.point(200, 300);
        compare(overlay.activePanel.y, 20);
    }

    function test_14_unknown_bounds_disable_clamping() {
        makeService();
        makeOverlay({
            dropdownType: 4,
            isRightEdge: true,
            availableBounds: Qt.rect(0, 0, 0, 0),
            anchorPos: Qt.point(900, 100)
        });
        var panel = overlay.activePanel;
        compare(panel.width, 380, "unknown bounds fall back to the natural width");
        compare(panel.height, 560, "unknown bounds fall back to the natural height");
        compare(panel.x, 900, "unknown bounds leave the anchor untouched");
        compare(panel.y, -180, "unknown bounds leave the anchor untouched");
    }

    function test_20_active_panel_and_blur_track_dropdown_type() {
        makeService();
        makeOverlay({
            dropdownType: 0,
            availableBounds: Qt.rect(0, 0, 800, 600),
            anchorPos: Qt.point(400, 300)
        });
        compare(overlay.activePanel, null);
        compare(overlay.overlayBlurActive, false);

        overlay.dropdownType = 4;
        var panel = overlay.activePanel;
        verify(panel !== null);
        compare(panel.visible, true);
        compare(overlay.overlayBlurActive, true, "an open panel must activate the window blur");

        var blur = findWindowBlur();
        verify(blur !== null, "overlay must host a window blur");
        compare(blur.blurEnabled, true);
        compare(Math.round(blur.blurX), Math.round(panel.x));
        compare(Math.round(blur.blurY), Math.round(panel.y));
        compare(Math.round(blur.blurWidth), Math.round(panel.width));
        compare(Math.round(blur.blurHeight), Math.round(panel.height));

        overlay.dropdownType = 0;
        compare(overlay.activePanel, null);
        compare(overlay.overlayBlurActive, false, "closing the panel must deactivate the blur");
        compare(blur.blurWidth, 0);
    }

    function test_30_settings_panel_works_without_player_or_lyrics() {
        var svc = makeService();
        compare(svc.hasPlayer, false);
        compare(svc.lyricsCount, 0);
        makeOverlay({
            dropdownType: 4,
            availableBounds: Qt.rect(0, 0, 600, 400),
            anchorPos: Qt.point(300, 200)
        });
        var panel = overlay.activePanel;
        verify(panel !== null);
        compare(panel.visible, true);

        var loader = findLoader(panel);
        verify(loader !== null, "panel must host the settings loader");
        verify(loader.item !== null, "settings view must instantiate without a player");
        compare(Fetcher.callCount(), 0, "opening settings must not fetch lyrics");
    }

    function test_40_removing_service_closes_panel() {
        makeService();
        makeOverlay({
            dropdownType: 4,
            availableBounds: Qt.rect(0, 0, 800, 600),
            anchorPos: Qt.point(400, 300)
        });
        watchSignals();
        var panel = overlay.activePanel;
        verify(panel.visible, "panel must be open before the service disappears");
        PluginService.pluginDaemonInstances = ({});
        compare(closeSpy.count, 1, "losing the lyrics service while open must request close");
        compare(panel.visible, false, "the panel must hide once its service is gone");
        compare(overlay.overlayBlurActive, false);
    }

    function test_41_removing_service_while_closed_is_silent() {
        makeService();
        makeOverlay({
            dropdownType: 0,
            availableBounds: Qt.rect(0, 0, 800, 600),
            anchorPos: Qt.point(400, 300)
        });
        watchSignals();
        PluginService.pluginDaemonInstances = ({});
        compare(closeSpy.count, 0, "a closed panel must not react to service removal");
    }

    function test_50_hover_inside_controls_stays_open() {
        makeService();
        makeOverlay({
            dropdownType: 4,
            availableBounds: Qt.rect(0, 0, 600, 400),
            anchorPos: Qt.point(300, 200)
        });
        var panel = overlay.activePanel;
        watchSignals();

        mouseMove(overlay, 2, 2);
        wait(20);
        enteredSpy.clear();
        exitedSpy.clear();
        closeSpy.clear();

        mouseMove(panel, panel.width / 2, panel.height / 2);
        wait(20);
        compare(enteredSpy.count, 0, "settings are click-dismissed, not hover-tracked");
        compare(exitedSpy.count, 0);
        compare(closeSpy.count, 0, "hover must never close the settings panel");

        mouseMove(panel, panel.width / 2, panel.height - 10);
        wait(20);
        compare(enteredSpy.count, 0);
        compare(exitedSpy.count, 0, "moving within the hosted settings must stay inside");
        compare(closeSpy.count, 0);

        mouseMove(overlay, 2, 2);
        wait(20);
        compare(exitedSpy.count, 0, "leaving settings must not arm a hover dismissal");
    }

    function test_51_click_inside_panel_margin_is_not_outside() {
        makeService();
        makeOverlay({
            dropdownType: 4,
            availableBounds: Qt.rect(0, 0, 800, 600),
            anchorPos: Qt.point(700, 300)
        });
        watchSignals();
        mouseClick(overlay.activePanel, 2, 2);
        compare(closeSpy.count, 0, "empty panel margins must not dismiss settings");
        mouseClick(overlay, 2, 2);
        compare(closeSpy.count, 1, "clicking outside the panel must request dismissal");
    }

    function test_52_overlay_escape_requests_close_only_for_lyrics() {
        makeService();
        makeOverlay({ dropdownType: 4 });
        watchSignals();
        hostWindow.requestActivate();
        tryCompare(hostWindow, "active", true);
        overlay.forceActiveFocus();
        tryCompare(overlay, "activeFocus", true);
        keyClick(Qt.Key_Escape);
        compare(closeSpy.count, 1);

        overlay.dropdownType = 3;
        closeSpy.clear();
        overlay.forceActiveFocus();
        keyClick(Qt.Key_Escape);
        compare(closeSpy.count, 0);
    }
}
