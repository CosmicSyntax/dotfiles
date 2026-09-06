pragma Singleton
import QtQuick

QtObject {
    readonly property string fontFamily: "GoogleSansCode Nerd Font"
    
    // Optional: You can centralize your Nord theme palette here too
    readonly property color bgDark: "#2e3440"
    readonly property color bgLight: "#3b4252"
    readonly property color fgMain: "#eceff4"
    readonly property color accent: "#81a1c1"
}
