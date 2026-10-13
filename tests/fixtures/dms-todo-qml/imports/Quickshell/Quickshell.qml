pragma Singleton
import QtQuick

QtObject {
    readonly property bool isStub: true
    property var commands: []
    function env(key) {
        return key === "XDG_CONFIG_HOME" ? "/fixture/config" : "/fixture/home";
    }
    function execDetached(command) {
        commands = commands.concat([command]);
    }
}
