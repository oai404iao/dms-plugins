pragma Singleton
import QtQuick

QtObject {
    property var activePlayer: null
    property var availablePlayers: []

    function isIdle(player) {
        return false;
    }
}
