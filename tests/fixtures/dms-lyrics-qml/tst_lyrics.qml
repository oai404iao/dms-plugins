import QtQuick
import QtTest
import "plugin"
import qs.Common
import qs.Services
import Quickshell.Services.Mpris
import "plugin/LyricsFetcher.js" as Fetcher

TestCase {
    id: testCase
    name: "LyricsServiceIntegration"

    Component {
        id: serviceComponent
        LyricsService {
        }
    }

    Component {
        id: playerComponent
        MprisPlayer {
        }
    }

    property var service: null
    property var player: null
    property var view: null

    function init() {
        Fetcher.setDeferred(false);
        Fetcher.resetCalls();
        Fetcher.clearCache();
        SettingsData.pluginSettings = ({});
        I18n.pluginTranslations = ({});
    }

    function cleanup() {
        if (view) {
            view.destroy();
            view = null;
        }
        if (service) {
            service.destroy();
            service = null;
        }
        // QML destroy() is processed by the event loop; flush it so the next
        // test never observes a half-deleted service.
        wait(0);
        if (player) {
            player.destroy();
            player = null;
        }
        MprisController.activePlayer = null;
    }

    function makePlayer(props) {
        var p = playerComponent.createObject(testCase);
        for (var k in props)
            p[k] = props[k];
        if (p.length === 0)
            p.length = 180;
        player = p;
        MprisController.activePlayer = p;
        return p;
    }

    function translatedPlayer(position) {
        return makePlayer({
            playbackState: MprisPlaybackState.Paused,
            trackTitle: "Translated Track",
            trackArtist: "Fixture Artist",
            trackAlbum: "Fixture Album",
            position: position === undefined ? 1.5 : position
        });
    }

    function makeService(pluginSettings) {
        SettingsData.pluginSettings = ({ "lyrics": pluginSettings || {} });
        service = serviceComponent.createObject(testCase, {
            "pluginId": "lyrics",
            "pluginService": ({ "stub": true })
        });
        return service;
    }

    // Replaces the whole pluginSettings value so the service's `preferences`
    // binding re-evaluates, mirroring a live settings write.
    function setPrefs(patch) {
        var current = SettingsData.pluginSettings.lyrics || {};
        var next = {};
        for (var k in current)
            next[k] = current[k];
        for (var j in patch)
            next[j] = patch[j];
        SettingsData.pluginSettings = ({ "lyrics": next });
    }

    function test_00_stub_module_is_shadowing_real_quickshell() {
        // Guards against silently loading the system Quickshell.Services.Mpris.
        verify(MprisPlaybackState.isStub, "stub Mpris module must shadow the installed one");
        compare(MprisPlaybackState.Stopped, 0);
        compare(MprisPlaybackState.Playing, 1);
        compare(MprisPlaybackState.Paused, 2);
    }

    function test_01_initialized_startup_without_player() {
        var s = makeService({});
        verify(s.initialized, "initialized must be true after Component.onCompleted");
        compare(s.showLyrics, true);
        compare(s.showTranslation, true);
        compare(s.translationLanguage, "source");
        compare(s.useTranslation, true);
        compare(s.hasPlayer, false);
        compare(s.playing, false);
        compare(s.stopped, false);
        compare(s.maxWidth, 280);
        compare(s.lyricsCount, 0);
        compare(s.currentIndex, -1);
        compare(s.currentLine, "");
        compare(s.currentSongKey, "");
        compare(s.availableTranslations.length, 0);
        compare(Fetcher.callCount(), 0);
    }

    function test_02_paused_player_fetches_and_prefers_translation() {
        translatedPlayer(1.5);
        var s = makeService({
            showLyrics: true,
            showTranslation: true,
            translationLanguage: "source"
        });
        compare(Fetcher.callCount(), 1, "one fetch must be requested for a new track");
        compare(Fetcher.lastCall().title, "Translated Track");
        compare(s.initialized, true);
        compare(s.hasPlayer, true);
        compare(s.playing, false);
        compare(s.stopped, false);
        compare(s.lyricsCount, 3);
        verify(s.currentSongKey !== "", "song key must be set once a fetch is scheduled");
        compare(s.translationAvailable, true);
        compare(s.availableTranslations.length, 1);
        compare(s.availableTranslations[0].value, "source");
        compare(s.currentIndex, 0);
        compare(s.originalLine, "原文一");
        compare(s.translatedLine, "译文一");
        compare(s.currentLine, "译文一");
    }

    function test_03_show_translation_false_falls_back_to_original() {
        translatedPlayer(1.5);
        var s = makeService({
            showLyrics: true,
            showTranslation: false,
            translationLanguage: "source"
        });
        compare(s.useTranslation, false);
        compare(s.lyricsCount, 3);
        compare(s.translationAvailable, true);
        compare(s.availableTranslations.length, 1);
        compare(s.availableTranslations[0].value, "source");
        compare(s.originalLine, "原文一");
        compare(s.translatedLine, "译文一");
        compare(s.currentLine, "原文一");
    }

    function test_04_original_fallback_when_provider_supplies_no_translation() {
        makePlayer({
            playbackState: MprisPlaybackState.Paused,
            trackTitle: "Plain Track",
            trackArtist: "Fixture Artist",
            position: 1.5
        });
        var s = makeService({
            showLyrics: true,
            showTranslation: true,
            translationLanguage: "source"
        });
        compare(s.lyricsCount, 2);
        compare(s.translationAvailable, false);
        compare(s.availableTranslations.length, 0, "no translation means no language option");
        compare(s.originalLine, "Original One");
        compare(s.translatedLine, "");
        compare(s.currentLine, "Original One");
    }

    function test_05_foreign_translation_language_never_applies() {
        translatedPlayer(1.5);
        var s = makeService({
            showLyrics: true,
            showTranslation: true,
            translationLanguage: "zh"
        });
        compare(s.useTranslation, false);
        compare(s.currentLine, "原文一");
        // Only the single provider-supplied translation is ever offered.
        compare(s.availableTranslations.length, 1);
        compare(s.availableTranslations[0].value, "source");
    }

    function test_06_show_lyrics_false_defers_fetch_while_paused() {
        translatedPlayer(1.5);
        var s = makeService({
            showLyrics: false,
            showTranslation: true,
            translationLanguage: "source"
        });
        verify(s.initialized, "startup still completes with lyrics disabled");
        compare(s.showLyrics, false);
        compare(Fetcher.callCount(), 0, "must not fetch while showLyrics is false");
        compare(s.lyricsCount, 0);
        compare(s.currentSongKey, "");
        compare(s.currentLine, "");
        compare(s.availableTranslations.length, 0);
        // Metadata churn while disabled must not start a request either.
        player.trackTitle = "Another Track";
        player.position = 30;
        compare(Fetcher.callCount(), 0);
        compare(s.lyricsCount, 0);
    }

    function test_07_resume_fetches_after_enabling_show_lyrics() {
        translatedPlayer(1.5);
        var s = makeService({
            showLyrics: false,
            showTranslation: true,
            translationLanguage: "source"
        });
        compare(s.lyricsCount, 0);
        setPrefs({ showLyrics: true });
        compare(s.showLyrics, true);
        compare(Fetcher.callCount(), 1, "enabling lyrics must schedule a fetch");
        compare(s.lyricsCount, 3);
        compare(s.currentLine, "译文一");
        setPrefs({ showLyrics: false });
        compare(s.lyricsCount, 0);
        compare(s.currentLine, "");
        compare(s.currentSongKey, "");
    }

    function test_08_inflight_response_ignored_after_lyrics_disabled() {
        translatedPlayer(1.5);
        Fetcher.setDeferred(true);
        var s = makeService({
            showLyrics: true,
            showTranslation: true,
            translationLanguage: "source"
        });
        compare(Fetcher.callCount(), 1);
        compare(s.lyricsCount, 0, "response is still in flight");
        setPrefs({ showLyrics: false });
        Fetcher.deliver();
        compare(s.lyricsCount, 0, "late response must be ignored while lyrics are off");
        compare(s.currentLine, "");
        setPrefs({ showLyrics: true });
        compare(Fetcher.callCount(), 2);
        Fetcher.deliver();
        compare(s.lyricsCount, 3);
        compare(s.currentLine, "译文一");
    }

    function test_09_source_change_refetches_with_new_provider() {
        translatedPlayer(1.5);
        var s = makeService({
            showLyrics: true,
            showTranslation: true,
            translationLanguage: "source",
            lyricsSource: "netease"
        });
        compare(s.translationAvailable, true);
        setPrefs({ lyricsSource: "lrclib_only" });
        compare(s.lyricsSource, "lrclib_only");
        compare(s.translationAvailable, false, "lrclib fixture carries no translation");
        compare(s.lyricsCount, 3);
        compare(s.currentLine, "原文一");
    }

    function test_10_stopped_player_clears_lyrics() {
        translatedPlayer(1.5);
        var s = makeService({
            showLyrics: true,
            showTranslation: true,
            translationLanguage: "source"
        });
        compare(s.lyricsCount, 3);
        player.playbackState = MprisPlaybackState.Stopped;
        compare(s.stopped, true);
        compare(s.lyricsCount, 0);
        compare(s.currentSongKey, "");
        compare(s.currentLine, "");
    }

    function test_11_view_follows_service_live() {
        translatedPlayer(1.5);
        var s = makeService({
            showLyrics: true,
            showTranslation: true,
            translationLanguage: "source"
        });
        view = s.lyricsView.createObject(s, { "width": 300, "height": 200 });
        verify(view !== null, "lyricsView component must instantiate");
        compare(view.count, 3, "view model must mirror the service ListModel");
        compare(view.currentIndex, s.currentIndex);
        compare(view.currentIndex, 0);
        compare(view.showTranslation, true);

        player.position = 2.5;
        s.updateSync();
        compare(s.currentIndex, 1);
        compare(view.currentIndex, 1, "view must follow the service index live");
        compare(s.currentLine, "译文二");

        setPrefs({ showTranslation: false });
        compare(s.useTranslation, false);
        compare(view.showTranslation, false, "translation visibility must follow the preference live");
        compare(s.currentLine, "原文二");

        player.trackTitle = "Plain Track";
        compare(s.lyricsCount, 2, "view model must follow a track change");
        compare(view.count, 2);
    }

    function test_12_player_removed_clears_stale_lyrics() {
        translatedPlayer(1.5);
        var s = makeService({
            showLyrics: true,
            showTranslation: true,
            translationLanguage: "source"
        });
        compare(s.lyricsCount, 3);
        MprisController.activePlayer = null;
        compare(s.hasPlayer, false);
        compare(s.playing, false);
        compare(s.stopped, false);
        compare(s.lyricsCount, 0, "removing the active player must clear the previous lyrics");
        compare(s.originalLine, "");
        compare(s.translatedLine, "");
        compare(s.currentSongKey, "");
    }

    function test_13_max_width_preference_is_clamped() {
        makeService({ maxWidth: 10 });
        compare(service.maxWidth, 80, "below-range width clamps to the minimum");
        setPrefs({ maxWidth: 5000 });
        compare(service.maxWidth, 600, "above-range width clamps to the maximum");
        setPrefs({ maxWidth: 320 });
        compare(service.maxWidth, 320);
    }

    function test_14_ui_locale_changes_without_changing_lyrics() {
        translatedPlayer(1.5);
        var s = makeService({});
        compare(s.availableTranslations[0].label, "Provider translation");
        I18n.pluginTranslations = ({
            lyrics: { "Provider translation": { "Provider translation": "来源译文" } }
        });
        compare(s.availableTranslations[0].label, "来源译文");
        compare(s.availableTranslations[0].value, "source");
        compare(s.currentLine, "译文一");
        I18n.pluginTranslations = ({});
        compare(s.availableTranslations[0].label, "Provider translation");
        compare(s.currentLine, "译文一");
        compare(Fetcher.callCount(), 1);
    }
}
