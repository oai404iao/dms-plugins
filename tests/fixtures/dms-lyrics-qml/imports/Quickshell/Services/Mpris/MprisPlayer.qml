import QtQuick
import Quickshell.Services.Mpris

QtObject {
    property bool isPlaying: false
    property int playbackState: MprisPlaybackState.Paused
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackAlbum: ""
    property bool lengthSupported: true
    property real length: 0
    property real position: 0
}
