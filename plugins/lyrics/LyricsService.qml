pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import "LyricsFetcher.js" as Fetcher

Item {
    id: root

    required property string pluginId
    required property var pluginService
    property bool initialized: false

    readonly property var preferences: SettingsData.pluginSettings[pluginId] ?? ({})
    readonly property string lyricsSource: preferences.lyricsSource ?? "netease"
    readonly property int maxWidth: Math.max(80, Math.min(600, preferences.maxWidth ?? 280))
    readonly property bool showLyrics: preferences.showLyrics ?? true
    readonly property bool showTranslation: preferences.showTranslation ?? true
    readonly property string translationLanguage: preferences.translationLanguage ?? "source"
    readonly property bool useTranslation: showTranslation && translationLanguage === "source"

    property string originalLine: ""
    property string translatedLine: ""
    property int currentIndex: -1
    property string currentSongKey: ""
    property bool translationAvailable: false
    readonly property string currentLine: showLyrics ? Fetcher.preferredText({
        text: originalLine, translation: translatedLine
    }, useTranslation) : ""
    readonly property var availableTranslations: translationAvailable
        ? [{ label: I18n.trFor("lyrics", "Provider translation"), value: "source" }] : []

    readonly property var player: MprisController.activePlayer
    readonly property bool hasPlayer: !!player
    readonly property bool playing: hasPlayer && player.isPlaying
    readonly property bool stopped: hasPlayer && player.playbackState === MprisPlaybackState.Stopped

    ListModel {
        id: lyricsModel
    }

    readonly property int lyricsCount: lyricsModel.count
    property Component lyricsView: Component {
        LyricsView {
            model: lyricsModel
            activeIndex: root.currentIndex
            showTranslation: root.useTranslation
        }
    }
    property Component settingsView: Component {
        Flickable {
            id: settingsFlickable
            property var transientSurfaceTracker: null
            clip: true
            contentWidth: width
            contentHeight: options.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            LyricsSettings {
                id: options
                width: parent.width
                pluginService: root.pluginService
                transientSurfaceTracker: settingsFlickable.transientSurfaceTracker
            }
        }
    }

    function clearAll() {
        Fetcher.cancelPending();
        currentSongKey = "";
        lyricsModel.clear();
        originalLine = "";
        translatedLine = "";
        currentIndex = -1;
        translationAvailable = false;
    }

    function songChanged() {
        if (!initialized)
            return;
        // Derived bindings can lag onPlayerChanged during player removal.
        const currentPlayer = player;
        if (!currentPlayer || currentPlayer.playbackState === MprisPlaybackState.Stopped || !showLyrics) {
            clearAll();
            return;
        }
        const title = currentPlayer.trackTitle || "";
        const artist = currentPlayer.trackArtist || "";
        if (title === "") {
            clearAll();
            return;
        }
        const album = currentPlayer.trackAlbum || "";
        const duration = (currentPlayer.lengthSupported && currentPlayer.length > 0) ? Math.round(currentPlayer.length) : 0;
        const key = JSON.stringify([artist, title, album, duration]);
        if (key === currentSongKey)
            return;
        clearAll();
        currentSongKey = key;

        Fetcher.fetchLyrics(lyricsSource, title, artist, album, duration, function (lyrics) {
            if (key !== currentSongKey || !showLyrics)
                return;
            lyricsModel.clear();
            for (let i = 0; i < lyrics.length; i++)
                lyricsModel.append(lyrics[i]);
            translationAvailable = lyrics.some(line => line.translation !== "");
            currentIndex = -1;
            updateSync();
        });
    }

    function updateSync() {
        const currentPlayer = player;
        if (!initialized || !currentPlayer || lyricsModel.count === 0)
            return;
        let position = currentPlayer.position || 0;
        // Quickshell can extrapolate past the duration when a repeated track
        // does not emit Seeked. Keep the lyric clock in the current loop.
        const length = (currentPlayer.lengthSupported && currentPlayer.length > 0) ? currentPlayer.length : 0;
        if (length > 0 && position >= length)
            position %= length;
        let index = -1;
        for (let i = 0; i < lyricsModel.count; i++) {
            if (lyricsModel.get(i).time > position + 0.2)
                break;
            index = i;
        }
        if (index === currentIndex)
            return;
        currentIndex = index;
        originalLine = index >= 0 ? lyricsModel.get(index).text : "";
        translatedLine = index >= 0 ? lyricsModel.get(index).translation : "";
    }

    Timer {
        interval: 250
        repeat: true
        running: root.playing && root.showLyrics && lyricsModel.count > 0
        onTriggered: {
            root.player?.positionChanged();
            root.updateSync();
        }
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { root.songChanged(); }
        function onTrackArtistChanged() { root.songChanged(); }
        function onTrackAlbumChanged() { root.songChanged(); }
        function onLengthChanged() { root.songChanged(); }
        function onPositionChanged() { root.updateSync(); }
    }

    onPlayerChanged: songChanged()
    onPlayingChanged: updateSync()
    onStoppedChanged: songChanged()
    onShowLyricsChanged: songChanged()
    onLyricsSourceChanged: {
        if (initialized) {
            Fetcher.clearCache();
            clearAll();
            songChanged();
        }
    }
    Component.onCompleted: {
        initialized = true;
        songChanged();
    }
    Component.onDestruction: Fetcher.cancelPending()
}
