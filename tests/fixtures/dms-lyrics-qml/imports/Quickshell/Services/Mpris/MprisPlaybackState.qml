pragma Singleton
import QtQuick

QtObject {
    readonly property bool isStub: true
    enum Enum { Stopped, Playing, Paused }
}
