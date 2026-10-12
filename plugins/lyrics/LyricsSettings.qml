import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "lyrics"
    property var transientSurfaceTracker: null
    readonly property var lyrics: PluginService.pluginDaemonInstances[pluginId] ?? null

    component TrackedSelectionSetting: Column {
        id: selection

        required property var settingsHost
        required property string settingKey
        required property string label
        property string description: ""
        required property var options
        property string defaultValue: ""
        property string value: defaultValue

        width: parent.width
        spacing: Theme.spacingS

        function loadValue() {
            if (settingsHost && settingsHost.pluginService)
                value = settingsHost.loadValue(settingKey, defaultValue);
        }

        Component.onCompleted: loadValue()

        readonly property var optionLabels: {
            const labels = [];
            for (let i = 0; i < options.length; i++)
                labels.push(options[i].label || options[i]);
            return labels;
        }

        readonly property var valueToLabel: {
            const map = {};
            for (let i = 0; i < options.length; i++) {
                const opt = options[i];
                if (typeof opt === "object")
                    map[opt.value] = opt.label;
                else
                    map[opt] = opt;
            }
            return map;
        }

        readonly property var labelToValue: {
            const map = {};
            for (let i = 0; i < options.length; i++) {
                const opt = options[i];
                if (typeof opt === "object")
                    map[opt.label] = opt.value;
                else
                    map[opt] = opt;
            }
            return map;
        }

        onValueChanged: {
            if (settingsHost)
                settingsHost.saveValue(settingKey, value);
        }

        DankDropdown {
            width: parent.width
            text: selection.label
            description: selection.description
            currentValue: selection.valueToLabel[selection.value] || selection.value
            options: selection.optionLabels
            transientSurfaceTracker: selection.settingsHost.transientSurfaceTracker
            onValueChanged: newValue => {
                selection.value = selection.labelToValue[newValue] || newValue;
            }
        }
    }

    StyledText {
        text: I18n.trFor("lyrics", "Lyrics settings")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("lyrics", "Applies to the music widget and media page. Track metadata is the fallback; no AI translation.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    ToggleSetting {
        settingKey: "showLyrics"
        label: I18n.trFor("lyrics", "Show lyrics")
        description: I18n.trFor("lyrics", "When off, show track metadata and the original media layout.")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showTranslation"
        label: I18n.trFor("lyrics", "Show translation")
        description: I18n.trFor("lyrics", "When off, both views show original lyrics only.")
        defaultValue: true
    }

    TrackedSelectionSetting {
        settingsHost: root
        settingKey: "translationLanguage"
        label: I18n.trFor("lyrics", "Available translation")
        description: root.lyrics?.translationAvailable
            ? I18n.trFor("lyrics", "The provider supplies one translation without a language tag.")
            : I18n.trFor("lyrics", "No translation available for this track; fetching is disabled when lyrics are off.")
        defaultValue: "source"
        options: root.lyrics?.availableTranslations ?? []
        visible: root.lyrics?.translationAvailable ?? false
        enabled: root.lyrics?.showTranslation ?? false
    }

    StyledText {
        width: parent.width
        visible: !(root.lyrics?.translationAvailable ?? false)
        text: I18n.trFor("lyrics", "No translation available for this track; fetching is disabled when lyrics are off.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    TrackedSelectionSetting {
        settingsHost: root
        settingKey: "lyricsSource"
        label: I18n.trFor("lyrics", "Lyrics source")
        description: I18n.trFor("lyrics", "Choose NetEase first for supplied translations; LRCLIB provides original lyrics only.")
        defaultValue: "netease"
        options: [
            { label: I18n.trFor("lyrics", "NetEase first"), value: "netease" },
            { label: I18n.trFor("lyrics", "LRCLIB first"), value: "lrclib" },
            { label: I18n.trFor("lyrics", "NetEase only"), value: "netease_only" },
            { label: I18n.trFor("lyrics", "LRCLIB only"), value: "lrclib_only" }
        ]
    }

    SliderSetting {
        settingKey: "maxWidth"
        label: I18n.trFor("lyrics", "Text width (px)")
        description: I18n.trFor("lyrics", "Maximum width of the lyric text; longer lines scroll horizontally.")
        minimum: 80
        maximum: 600
        defaultValue: 280
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("lyrics", "Uses DMS's MPRIS player; tracks without synced lyrics retain the normal music widget.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
}
