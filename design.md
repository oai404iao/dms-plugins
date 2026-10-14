---
name: dms-plugin-design
description: Presentation of native DMS compact list popouts and vertically stacked settings forms; not marketing or documentation pages.
---

## 1. Scope and priority
- [MUST] Preserve DMS theme integration in compact popouts and settings forms.
- [MUST] Prioritize user requirements, accessible controls, readable content, then host conventions and decoration.
- [SHOULD] Apply the same semantic theme tokens in light and dark modes.

## 2. Brand and readers
- [MUST] Keep the interface native: use DMS fonts, surfaces and icons rather than an external service's marketing identity.
- [SHOULD] Keep desktop reading dense but legible: present primary text at `Theme.fontSizeMedium` and metadata at `Theme.fontSizeSmall`.
- [SHOULD] Use short, direct labels and neutral status messages.

## 3. Structure and composition
- [SHOULD] Compose list popouts as a left-aligned header, compact view controls and status area, and vertically scrolling list. Omit forms in reading-focused popouts.
- [SHOULD] Compose settings as a single column of labels, full-width controls and nearby help text.
- [SHOULD] Keep related controls on one row only when their text remains readable; keep the main text input full width.
- [SHOULD] Bound list scrolling inside its content region; wrap long primary text rather than shrinking it.
- [SHOULD] Decision: use a 460px popout and at most 360px list viewport for this compact implementation. Source: the reading-focused layout in `plugins/dankTodo/DankTodoWidget.qml`.
- [SHOULD] Keep row actions narrow and consistently aligned; let the primary text occupy the remaining width and wrap metadata beneath it.

## 4. Visual rules
- [SHOULD] Inherit the host font through `StyledText`; use bold only for headings.
- [MUST] Use `Theme.surfaceText` for primary text and `Theme.surfaceVariantText` for secondary text.
- [MUST] Use `Theme.error` for errors and `Theme.primary` for selection and focus.
- [SHOULD] Use `Theme.spacingXS` within tight groups, `Theme.spacingS` between related controls, and `Theme.spacingM` between groups.
- [SHOULD] Use `Theme.surfaceContainerHigh` for rows and inputs, `Theme.surfaceContainerHighest` for highlighted menu choices, and `Theme.cornerRadius` for surfaces.
- [MUST] Provide visible keyboard focus and meaningful names for icon-only controls.
- [SHOULD] Dim disabled controls and retain their layout positions.
- [SHOULD] Display loading and error copy beside the relevant controls; never substitute decorative success indicators for confirmed state.
- [SHOULD] Use native control motion; add no custom animation, illustration, chart or shadow.

## 5. Available primitives
| Role | Implementation | Source | Usage | Status |
|---|---|---|---|---|
| Text | `StyledText`, `Theme.fontSizeSmall/Medium/Large` | DMS `Widgets/StyledText.qml`, `Common/Theme.qml` | Body, metadata, headings | Implemented by host |
| Color | `Theme.surfaceText/surfaceVariantText/primary/onPrimary/error/outlineVariant` | DMS `Common/Theme.qml` | Semantic text, selection, borders | Implemented by host |
| Surface | `StyledRect`, `Theme.surfaceContainerHigh/surfaceContainerHighest/cornerRadius` | DMS `Widgets/StyledRect.qml`, `Common/Theme.qml` | Rows and menus; not nested decorative cards | Implemented by host |
| Spacing | `Theme.spacingXS/S/M/L` | DMS `Common/Theme.qml` | Related controls and groups | Implemented by host |
| Action | `DankButton`: `text`, `iconName`, `buttonHeight`, `backgroundColor`, `textColor` | DMS `Widgets/DankButton.qml` | Text and icon actions | Implemented by host |
| Input | `DankTextField`: `text`, `placeholderText`, `textEdited`, `accepted` | DMS `Widgets/DankTextField.qml` | Editable text | Implemented by host |
| Icon | `DankIcon`: `name`, `size`, `color` | DMS `Widgets/DankIcon.qml` | Functional Material Symbols | Implemented by host |
| Header | `PopoutComponent`: `headerText`, `detailsText`, `showCloseButton` | DMS `Modules/Plugins/PopoutComponent.qml` | Compact popout headers | Implemented by host |
| Selection | Qt Quick Controls `ComboBox`, themed content/delegate/`Popup` | `plugins/dankTodo/DankTodoSettings.qml` | Same-surface keyboard-accessible settings choices | Implemented |

- [MUST] Use only the public primitives listed above for this scoped interface; do not guess host properties.
- [SHOULD] Keep local layout styles inside the QML component; no new global style namespace is needed.
- [SHOULD] Change primitive widths, spacing and semantic color variants only through their public properties; do not replace their internal typography or behavior.

## 6. Copy and formats
- [SHOULD] Use sentence case labels and concise action verbs.
- [SHOULD] Keep one necessary explanation next to its control; omit repetitive footnotes.
- [SHOULD] Preserve identifiers verbatim, display date-only values as `YYYY-MM-DD`, and show compact local times as `HH:mm`.
- [MUST] Keep sensitive content out of visible status and error messages.

## 7. Anti-patterns
- [SHOULD] Do not introduce centered heroes or card grids in compact native interfaces.
- [SHOULD] Do not nest decorative cards or add colored icon tiles.
- [SHOULD] Do not introduce custom font families, literal palette colors or low-contrast primary text.
- [SHOULD] Do not turn ordinary metadata into pill badges.
- [MUST] Do not copy external marketing styles or logos.

## 8. Integration
- [SHOULD] Resolve DMS primitives through `qs.Common`, `qs.Widgets` and `qs.Modules.Plugins`.
- [SHOULD] Let DMS `Theme` and the proxied `DankCommon` components supply fonts and theme switching; do not add a parallel theme system.

## Glossary
| Name | Meaning |
|---|---|
| `StyledText` | Host-font text primitive |
| `StyledRect` | Host surface primitive |
| `DankButton` | Native action primitive |
| `DankTextField` | Native editable text primitive |
| `DankIcon` | Material Symbols icon primitive |
| `PopoutComponent` | Native compact header and content container |
| `ComboBox` | Keyboard-accessible selection control with an in-surface popup |
| `Theme` | Host typography, spacing and semantic color tokens |
