import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

import org.streetpea.chiaking

import "controls" as C

// PS-WRAP: หน้า Settings › Game presets — preset รายเกม (C++: PsWrapGameProfiles = Chiaki.window.gameProfiles)
// - เกมที่ PS5 กำลังรัน (จาก discovery) → สร้าง preset จาก setting ปัจจุบัน / แบบว่าง / แก้ของเดิม
// - preset แนะนำที่มากับตัวโปรแกรม (gp.builtInPresets — เช่น GTA 6) → กดเดียวเพิ่ม แล้วแก้ต่อได้
// - รายการ preset ที่บันทึกไว้ → แก้ / ลบ
// - ตัวแก้: ทุกช่องมี "Keep current" = ไม่ตั้ง (ใช้ค่าปกติ) · ช่องที่ window ยังไม่มี (clock/replay) ซ่อนเอง
// - นำทางด้วยจอย/คีย์: ↑↓ ไล่ตาม focus chain ของ controls/ (ไม่มีกริดซับซ้อน)
Item {
    id: page

    property real uiScale: 1.0
    property int labelWidth: 270
    property int controlWidth: 400
    property var confirm: null                   // (title, text, callback) — root.showConfirmDialog ของ Main
    readonly property alias flick: presetsFlick
    readonly property Item firstItem: enableCheck

    readonly property QtObject gp: Chiaki.window.gameProfiles

    // ตัวแก้ preset (ว่าง = ไม่ได้แก้อยู่)
    property var draft: null
    readonly property bool editing: draft !== null

    function openEditor(p) {
        draft = Object.assign({}, p);
        nameField.text = draft.name || "";
        Qt.callLater(() => nameField.forceActiveFocus(Qt.TabFocusReason));
    }
    function closeEditor() {
        draft = null;
        presetsFlick.contentY = 0;
        Qt.callLater(() => enableCheck.forceActiveFocus(Qt.TabFocusReason));
    }
    function setField(key, value) {
        let d = Object.assign({}, draft);
        if (value === undefined || value === null || value === -1)
            delete d[key];
        else
            d[key] = value;
        draft = d;
    }
    function fieldValue(key) {
        return draft && draft[key] !== undefined && draft[key] !== null ? draft[key] : -1;
    }

    readonly property var resolutionNames: ["", qsTr("360p"), qsTr("540p"), qsTr("720p"), qsTr("1080p")]
    readonly property var fxNames: [qsTr("None"), qsTr("Sunglasses"), qsTr("Mustache"), qsTr("Clown nose"), qsTr("Crown"), qsTr("Bane mask"), qsTr("Party (glasses + mustache + crown)"), qsTr("Samurai mask"), qsTr("Ninja"), qsTr("Ghost (Tsushima)"), qsTr("Samurai armor (kabuto + mask)"), qsTr("Samurai armor (photo)"), qsTr("Jin mask (private)"), qsTr("Jin mask + headband (private)")]
    readonly property var bgNames: [qsTr("Keep"), qsTr("Remove green screen"), qsTr("Remove blue screen"), qsTr("AI remove (no green screen)")]

    // เทียบ nameMatch กับชื่อเกม — กฎเดียวกับ nameMatches() ฝั่ง C++ (contains ไม่สนใจตัวเล็กใหญ่ หลายคำคั่นด้วย ,)
    function nameMatches(patterns, app) {
        if (!patterns || !app)
            return false;
        const hay = app.toLowerCase();
        return patterns.split(",").map(x => x.trim().toLowerCase()).filter(x => x.length > 0)
                       .some(x => hay.indexOf(x) >= 0);
    }

    // เทียบ title ID เฉพาะส่วนหน้า (PPSA01547_00 → PPSA01547) — กฎเดียวกันกับ titleIdInList() ฝั่ง C++
    function baseTitleId(id) {
        const t = (id || "").trim().toUpperCase();
        const u = t.indexOf("_");
        return u > 0 ? t.substring(0, u) : t;
    }

    function titleIdInList(list, titleId) {
        if (!list || !titleId)
            return false;
        const want = page.baseTitleId(titleId);
        return list.split(",").map(x => page.baseTitleId(x)).filter(x => x.length > 0)
                   .some(x => x === want);
    }

    // key ของ preset ที่คุมเกมนี้อยู่ (title ID ก่อน แล้วค่อย nameMatch) · "" = ยังไม่มี
    function presetKeyForGame(game) {
        if (!page.gp || !game)
            return "";
        const list = page.gp.profiles;
        for (const p of list)
            if (p.titleId === game.titleId)
                return p.titleId;
        for (const p of list)
            if (page.titleIdInList(p.titleIdAlso || "", game.titleId || ""))
                return p.titleId;
        for (const p of list)
            if (page.nameMatches(p.nameMatch || "", game.name || ""))
                return p.titleId;
        return "";
    }

    // title ID ของเกมที่รันอยู่แล้วและตรงกับ nameMatch นี้ · "" = ไม่เจอ (เกมยังไม่รัน)
    function runningTitleIdFor(nameMatch) {
        if (!page.gp)
            return "";
        for (const g of page.gp.runningGames)
            if (page.nameMatches(nameMatch || "", g.name || ""))
                return g.titleId;
        return "";
    }

    readonly property string builtInKeyPrefix: "builtin:"

    function titleIdText(titleId) {
        return titleId.indexOf(page.builtInKeyPrefix) === 0
            ? qsTr("Title ID not known yet — matched by game name")
            : titleId;
    }

    function bitrateText(kbps) {
        return kbps === 0 ? qsTr("Auto (by resolution)") : qsTr("%1 Mbps").arg(Math.round(kbps / 100) / 10);
    }

    // สรุปช่องที่ preset ตั้งไว้ (แสดงในรายการ)
    function summary(p) {
        let parts = [];
        if (p.resolution !== undefined) parts.push(resolutionNames[p.resolution] || "");
        if (p.fps !== undefined) parts.push(qsTr("%1 fps").arg(p.fps));
        if (p.bitrate !== undefined) parts.push(bitrateText(p.bitrate));
        if (p.frameGen !== undefined) parts.push(p.frameGen ? qsTr("Frame Gen") : qsTr("No Frame Gen"));
        const flags = [["padOverlay", qsTr("Controller")], ["pad3d", qsTr("3D Pad")], ["camOverlay", qsTr("Facecam")],
                       ["statsOverlay", qsTr("Stats")], ["micOverlay", qsTr("Mic")], ["clockOverlay", qsTr("Clock")],
                       ["chatOverlay", qsTr("Chat")], ["replayEnabled", qsTr("Replay")]];
        for (const f of flags)
            if (p[f[0]] !== undefined) parts.push((p[f[0]] ? "+" : "−") + f[1]);
        if (p.replaySeconds !== undefined) parts.push(qsTr("Replay %1 s").arg(p.replaySeconds));
        if (p.camFx !== undefined) parts.push(qsTr("Effect: %1").arg(fxNames[p.camFx] || p.camFx));
        if (p.camBackground !== undefined) parts.push(qsTr("Background: %1").arg(bgNames[p.camBackground] || p.camBackground));
        if (p.titleIdAlso) parts.push(qsTr("Also: %1").arg(p.titleIdAlso));
        if (p.nameMatch) parts.push(qsTr("Matches: %1").arg(p.nameMatch));
        return parts.length ? parts.join(" · ") : qsTr("No overrides (uses current settings)");
    }

    // การ์ดพื้นหลังแบบเดียวกับหน้าอื่นของ SettingsDialog
    component Card: Rectangle {
        id: card
        default property alias content: cardCol.data
        property string title: ""
        Layout.fillWidth: true
        implicitHeight: cardCol.implicitHeight + Theme.space4 * 2
        radius: Theme.radiusCard
        color: Theme.surface
        border.width: 1
        border.color: Theme.border
        ColumnLayout {
            id: cardCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.space4 }
            spacing: Theme.space3
            RowLayout {
                Layout.fillWidth: true
                visible: card.title.length > 0
                spacing: Theme.space2
                Rectangle { Layout.preferredWidth: 4; Layout.preferredHeight: Math.round(Theme.fontLabel * page.uiScale); radius: 2; color: Theme.accent }
                Label {
                    Layout.fillWidth: true
                    text: card.title.toUpperCase()
                    font.pixelSize: Theme.fontCaption
                    font.letterSpacing: 1.2
                    font.weight: Font.DemiBold
                    color: Theme.textMuted
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ช่องเลือกค่าแบบ "Keep current" + ตัวเลือก · options = [{ text, value }] (value -1 = ไม่ตั้ง)
    component FieldRow: RowLayout {
        id: row
        property string label: ""
        property string key: ""
        property var options: []
        readonly property alias combo: fieldCombo
        Layout.fillWidth: true
        spacing: Theme.space4
        Label {
            Layout.preferredWidth: page.labelWidth
            Layout.maximumWidth: page.labelWidth
            wrapMode: Text.WordWrap
            color: Theme.text
            text: row.label
        }
        C.ComboBox {
            id: fieldCombo
            Layout.preferredWidth: page.controlWidth
            model: [{ text: qsTr("Keep current"), value: -1 }].concat(row.options)
            textRole: "text"
            valueRole: "value"
            onActivated: (index) => page.setField(row.key, model[index].value)
        }
        // ตั้ง index แบบ imperative (ผู้ใช้เลือกแล้ว binding ของ currentIndex จะหลุด) — callLater ให้ model ใหม่ (bitrate) มาก่อน
        function sync() {
            fieldCombo.currentIndex = page.editing ? Math.max(0, fieldCombo.indexOfValue(page.fieldValue(row.key))) : 0;
        }
        Connections {
            target: page
            function onDraftChanged() { Qt.callLater(row.sync) }
        }
        Component.onCompleted: sync()
    }

    readonly property var boolOptions: [{ text: qsTr("On"), value: true }, { text: qsTr("Off"), value: false }]

    Flickable {
        id: presetsFlick
        anchors {
            fill: parent
            topMargin: 32
            bottomMargin: 20
        }
        clip: true
        contentWidth: width
        contentHeight: content.height + Theme.space12
        flickableDirection: Flickable.AutoFlickIfNeeded
        ScrollBar.vertical: C.SlimScrollBar {
            policy: ScrollBar.AlwaysOn
            visible: presetsFlick.contentHeight > presetsFlick.height
        }

        ColumnLayout {
            id: content
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                leftMargin: Theme.space8
                rightMargin: Theme.space8
            }
            spacing: Theme.space4

            // ---------- สวิตช์รวม + สถานะ ----------
            Card {
                C.CheckBox {
                    id: enableCheck
                    text: qsTr("Apply game presets automatically when a stream starts")
                    firstInFocusChain: true
                    Layout.maximumWidth: content.width - Theme.space8
                    checked: page.gp ? page.gp.enabled : false
                    onClicked: if (page.gp) page.gp.enabled = checked   // C.CheckBox: Enter/✕ ส่ง clicked ไม่ส่ง toggled
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontCaption
                    color: Theme.textMuted
                    text: qsTr("PS-WRAP reads the game your PS5 is running when you connect and applies its preset for that stream only. Fields left on \"Keep current\" use your normal settings. Resolution, FPS and bitrate apply to local PS5 streams.")
                }
                Label {
                    Layout.fillWidth: true
                    visible: page.gp && page.gp.activeProfileName.length > 0
                    font.pixelSize: Theme.fontLabel
                    font.weight: Font.DemiBold
                    color: Theme.success
                    text: page.gp ? qsTr("Preset in use: %1").arg(page.gp.activeProfileName) : ""
                }
            }

            // ---------- ตัวแก้ preset ----------
            Card {
                visible: page.editing
                title: qsTr("Edit preset")
                Label {
                    Layout.fillWidth: true
                    font.pixelSize: Theme.fontCaption
                    color: Theme.textMuted
                    text: page.editing ? qsTr("Title ID: %1").arg(page.titleIdText(page.draft.titleId)) : ""
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space4
                    Label {
                        Layout.preferredWidth: page.labelWidth
                        Layout.maximumWidth: page.labelWidth
                        color: Theme.text
                        text: qsTr("Name")
                    }
                    C.TextField {
                        id: nameField
                        Layout.preferredWidth: page.controlWidth
                        text: page.editing ? (page.draft.name || "") : ""
                        onEditingFinished: page.setField("name", text)
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space4
                    Label {
                        Layout.preferredWidth: page.labelWidth
                        Layout.maximumWidth: page.labelWidth
                        wrapMode: Text.WordWrap
                        color: Theme.text
                        text: qsTr("Other title IDs")
                    }
                    C.TextField {
                        id: alsoField
                        Layout.preferredWidth: page.controlWidth
                        text: page.editing ? (page.draft.titleIdAlso || "") : ""
                        placeholderText: qsTr("e.g. PPSA29660, PPSA38500")
                        onEditingFinished: page.setField("titleIdAlso", text.trim().length > 0 ? text.trim() : null)
                    }
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontCaption
                    color: Theme.textMuted
                    text: qsTr("The same game has a different title ID in some regions. List the others here, separated by a comma, and this one preset covers them all.")
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space4
                    Label {
                        Layout.preferredWidth: page.labelWidth
                        Layout.maximumWidth: page.labelWidth
                        wrapMode: Text.WordWrap
                        color: Theme.text
                        text: qsTr("Match by game name")
                    }
                    C.TextField {
                        id: matchField
                        Layout.preferredWidth: page.controlWidth
                        text: page.editing ? (page.draft.nameMatch || "") : ""
                        placeholderText: qsTr("e.g. gta 6, grand theft auto vi")
                        onEditingFinished: page.setField("nameMatch", text.trim().length > 0 ? text.trim() : null)
                    }
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontCaption
                    color: Theme.textMuted
                    text: qsTr("Used when the title ID does not match — handy for a game whose ID you do not know yet, or for other regions. Separate names with a comma. The first time it matches, PS-WRAP remembers the real title ID.")
                }
                FieldRow {
                    label: qsTr("Resolution (local PS5)")
                    key: "resolution"
                    options: [{ text: qsTr("360p"), value: 1 }, { text: qsTr("540p"), value: 2 }, { text: qsTr("720p"), value: 3 }, { text: qsTr("1080p"), value: 4 }]
                }
                FieldRow {
                    label: qsTr("FPS (local PS5)")
                    key: "fps"
                    options: [{ text: qsTr("30 fps"), value: 30 }, { text: qsTr("60 fps"), value: 60 }]
                }
                FieldRow {
                    label: qsTr("Bitrate (local PS5)")
                    key: "bitrate"
                    options: {
                        let list = [0, 5000, 10000, 15000, 20000, 25000, 30000, 40000, 50000, 70000, 100000];
                        const cur = page.fieldValue("bitrate");
                        if (cur > 0 && list.indexOf(cur) < 0) {
                            list.push(cur);
                            list.sort((a, b) => a - b);
                        }
                        return list.map(v => ({ text: page.bitrateText(v), value: v }));
                    }
                }
                FieldRow {
                    label: qsTr("Frame Gen (60 → 120)")
                    key: "frameGen"
                    options: page.boolOptions
                    visible: page.gp ? page.gp.windowSupports("frameGen") : false
                }
                FieldRow { label: qsTr("Controller overlay"); key: "padOverlay"; options: page.boolOptions }
                FieldRow {
                    label: qsTr("3D controller overlay")
                    key: "pad3d"
                    options: page.boolOptions
                    visible: page.gp ? page.gp.windowSupports("pad3d") : false
                }
                FieldRow { label: qsTr("Facecam overlay"); key: "camOverlay"; options: page.boolOptions }
                FieldRow { label: qsTr("Stats overlay"); key: "statsOverlay"; options: page.boolOptions }
                FieldRow { label: qsTr("Mic spectrum overlay"); key: "micOverlay"; options: page.boolOptions }
                FieldRow {
                    label: qsTr("Clock overlay")
                    key: "clockOverlay"
                    options: page.boolOptions
                    visible: page.gp ? page.gp.windowSupports("clockOverlay") : false
                }
                FieldRow {
                    label: qsTr("Facecam effect")
                    key: "camFx"
                    options: page.fxNames.map((t, i) => ({ text: t, value: i }))
                }
                FieldRow {
                    label: qsTr("Facecam background")
                    key: "camBackground"
                    options: page.bgNames.map((t, i) => ({ text: t, value: i }))
                }
                FieldRow {
                    label: qsTr("Live chat overlay")
                    key: "chatOverlay"
                    options: page.boolOptions
                    visible: page.gp ? page.gp.windowSupports("chatOverlay") : false
                }
                FieldRow {
                    label: qsTr("Instant Replay")
                    key: "replayEnabled"
                    options: page.boolOptions
                    visible: page.gp ? page.gp.windowSupports("replayEnabled") : false
                }
                FieldRow {
                    label: qsTr("Instant Replay length")
                    key: "replaySeconds"
                    options: [30, 45, 60, 90, 120].map(v => ({ text: qsTr("%1 s").arg(v), value: v }))
                    visible: page.gp ? page.gp.windowSupports("replaySeconds") : false
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.space4
                    C.Button {
                        text: qsTr("Save preset")
                        highlighted: true
                        onClicked: {
                            let d = Object.assign({}, page.draft);
                            d.name = nameField.text;
                            const a = alsoField.text.trim();
                            if (a.length > 0)
                                d.titleIdAlso = a;
                            else
                                delete d.titleIdAlso;
                            const m = matchField.text.trim();
                            if (m.length > 0)
                                d.nameMatch = m;
                            else
                                delete d.nameMatch;
                            if (page.gp && page.gp.saveProfile(d))
                                page.closeEditor();
                        }
                    }
                    C.Button {
                        text: qsTr("Cancel")
                        lastInFocusChain: true
                        onClicked: page.closeEditor()
                    }
                }
            }

            // ---------- preset แนะนำที่มากับตัวโปรแกรม ----------
            Card {
                visible: !page.editing && page.gp && page.gp.builtInPresets.length > 0
                title: qsTr("Recommended presets")
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontCaption
                    color: Theme.textMuted
                    text: qsTr("Ready-made presets that come with PS-WRAP. Adding one makes it yours — every field stays editable, and it works before you ever launch the game.")
                }
                Repeater {
                    model: page.gp ? page.gp.builtInPresets : []
                    delegate: ColumnLayout {
                        id: biRow
                        required property var modelData
                        readonly property string installed: modelData.installedKey
                        readonly property string runningId: page.runningTitleIdFor(modelData.nameMatch)
                        Layout.fillWidth: true
                        spacing: Theme.space2
                        Label {
                            Layout.fillWidth: true
                            text: biRow.modelData.name + (biRow.installed.length > 0 ? "  " + qsTr("(added)") : "")
                            font.pixelSize: Theme.fontBody
                            font.weight: Font.DemiBold
                            color: Theme.text
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: biRow.modelData.note
                            wrapMode: Text.WordWrap
                            font.pixelSize: Theme.fontCaption
                            color: Theme.textMuted
                        }
                        Label {
                            Layout.fillWidth: true
                            text: page.summary(biRow.modelData.fields)
                            wrapMode: Text.WordWrap
                            font.pixelSize: Theme.fontCaption
                            color: Theme.textMuted
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: biRow.modelData.titleIds.length > 0
                            text: qsTr("Title IDs: %1").arg(biRow.modelData.titleIds)
                            wrapMode: Text.WordWrap
                            font.pixelSize: Theme.fontCaption
                            color: Theme.textMuted
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: biRow.installed.length === 0 && biRow.runningId.length > 0
                            text: qsTr("Running now on your PS5 — it will be saved under %1.").arg(biRow.runningId)
                            wrapMode: Text.WordWrap
                            font.pixelSize: Theme.fontCaption
                            color: Theme.success
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.space4
                            C.Button {
                                visible: biRow.installed.length === 0
                                text: qsTr("Add preset")
                                highlighted: true
                                onClicked: {
                                    // เกมรันอยู่ = เก็บด้วย title ID จริงเลย · ไม่รัน = key ชั่วคราว รอ nameMatch จับ
                                    const key = page.gp.addBuiltInPreset(biRow.modelData.id, biRow.runningId);
                                    if (key.length > 0)
                                        page.openEditor(page.gp.profile(key));
                                }
                            }
                            C.Button {
                                visible: biRow.installed.length > 0
                                text: qsTr("Edit preset")
                                onClicked: page.openEditor(page.gp.profile(biRow.installed))
                            }
                        }
                    }
                }
            }

            // ---------- เกมที่ PS5 รันอยู่ ----------
            Card {
                visible: !page.editing
                title: qsTr("Running now")
                Label {
                    Layout.fillWidth: true
                    visible: !page.gp || page.gp.runningGames.length === 0
                    wrapMode: Text.WordWrap
                    color: Theme.textMuted
                    text: qsTr("No game detected. Start a game on your PS5 and it appears here once discovery sees it.")
                }
                Repeater {
                    model: page.gp ? page.gp.runningGames : []
                    delegate: ColumnLayout {
                        id: runRow
                        required property var modelData
                        // ผูกกับ profiles (property มี NOTIFY) → คิดใหม่เมื่อรายการ preset เปลี่ยน · นับ preset ที่จับด้วยชื่อเกมด้วย
                        readonly property string presetKey: page.gp && page.gp.profiles ? page.presetKeyForGame(modelData) : ""
                        readonly property bool has: presetKey.length > 0
                        Layout.fillWidth: true
                        spacing: Theme.space2
                        Label {
                            Layout.fillWidth: true
                            text: modelData.name
                            font.pixelSize: Theme.fontBody
                            font.weight: Font.DemiBold
                            color: Theme.text
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: qsTr("%1 · on %2").arg(modelData.titleId).arg(modelData.console)
                            font.pixelSize: Theme.fontCaption
                            color: Theme.textMuted
                            elide: Text.ElideRight
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.space4
                            C.Button {
                                visible: runRow.has
                                text: qsTr("Edit preset")
                                onClicked: page.openEditor(page.gp.profile(runRow.presetKey))
                            }
                            C.Button {
                                visible: !runRow.has
                                text: qsTr("Create from current settings")
                                highlighted: true
                                onClicked: page.openEditor(page.gp.snapshotCurrent(modelData.titleId, modelData.name))
                            }
                            C.Button {
                                visible: !runRow.has
                                text: qsTr("Create empty preset")
                                onClicked: page.openEditor({ titleId: modelData.titleId, name: modelData.name })
                            }
                        }
                    }
                }
            }

            // ---------- preset ที่บันทึกไว้ ----------
            Card {
                visible: !page.editing
                title: qsTr("Saved presets")
                Label {
                    Layout.fillWidth: true
                    visible: !page.gp || page.gp.profiles.length === 0
                    wrapMode: Text.WordWrap
                    color: Theme.textMuted
                    text: qsTr("No presets yet.")
                }
                Repeater {
                    model: page.gp ? page.gp.profiles : []
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.space4
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                Layout.fillWidth: true
                                text: modelData.name + (page.gp && page.gp.activeTitleId === modelData.titleId ? "  " + qsTr("(in use)") : "")
                                font.pixelSize: Theme.fontBody
                                font.weight: Font.DemiBold
                                color: Theme.text
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                text: page.titleIdText(modelData.titleId) + " · " + page.summary(modelData)
                                font.pixelSize: Theme.fontCaption
                                color: Theme.textMuted
                                wrapMode: Text.WordWrap
                            }
                        }
                        C.Button {
                            text: qsTr("Edit")
                            onClicked: page.openEditor(modelData)
                        }
                        C.Button {
                            text: qsTr("Delete")
                            Material.accent: Material.Red
                            onClicked: {
                                const tid = modelData.titleId;
                                if (page.confirm)
                                    page.confirm(qsTr("Delete preset"), qsTr("Delete the preset for %1?").arg(modelData.name), () => page.gp.removeProfile(tid));
                                else
                                    page.gp.removeProfile(tid);
                            }
                        }
                    }
                }
            }
        }
    }
}
