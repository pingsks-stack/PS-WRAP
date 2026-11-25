// PS-WRAP: preset รายเกม (per-game profiles)
// เริ่มสตรีมแล้วเกมที่ PS5 รายงานผ่าน discovery (titleId) มี preset → ใช้ค่าของ preset กับ session นั้นอัตโนมัติ
// - ฝั่งวิดีโอ (ความละเอียด/fps/bitrate ของ PS5 ในบ้าน): แก้ StreamSessionConnectInfo ของ session นั้นก่อนสร้าง StreamSession
//   → ไม่เขียนทับ setting หลัก
// - ฝั่ง overlay/facecam/instant replay: ตั้งค่าบน QmlMainWindow ตอน session เริ่ม แล้วคืนค่าเดิมตอนสตรีมจบ
//   (คืนเฉพาะช่องที่ผู้ใช้ไม่ได้เปลี่ยนเองระหว่างสตรีม)
// - เกมเดียวกันแต่คนละ title ID (ต่างโซน): preset เก็บ title ID อื่นไว้ใน titleIdAlso ได้ (คั่นด้วย ,)
// - เกมที่ยังไม่รู้ title ID (เช่นเกมใหม่): preset ตั้ง nameMatch ได้ — จับจากชื่อเกมที่ discovery รายงาน
//   แล้วจำ title ID จริงให้เองครั้งแรก (adopt) ครั้งต่อไปตรงตัว
// - preset แนะนำที่มากับตัวหน้า (builtInPresets — เช่น GTA 6): กดเดียวเพิ่มเข้าเป็น preset ของเรา แก้ต่อได้ทุกช่อง
// - ช่องที่ไม่ได้ตั้งใน preset = ใช้ค่าปัจจุบันตามปกติ · ไม่มี preset = ไม่เปลี่ยนอะไรเลย
// เก็บเป็น JSON ใน settings ของ profile ปัจจุบัน (key pswrap/gameProfiles — Settings::GetPsWrapGameProfiles)
#pragma once

#include <QObject>
#include <QPointer>
#include <QVariantList>
#include <QVariantMap>
#include <QJsonObject>

#include <functional>

class Settings;
class QmlBackend;
class StreamSession;
struct StreamSessionConnectInfo;

class PsWrapGameProfiles : public QObject
{
	Q_OBJECT
	// รายการ preset ทั้งหมด (เรียงตามชื่อ) — แต่ละตัวเป็น map: titleId, name + ช่องที่ตั้งไว้ (ดู fieldKeys())
	Q_PROPERTY(QVariantList profiles READ profiles NOTIFY profilesChanged)
	// เกมที่ PS5 ในบ้านกำลังรันอยู่ตอนนี้ (จาก discovery) — [{ titleId, name, host, console }]
	Q_PROPERTY(QVariantList runningGames READ runningGames NOTIFY runningGamesChanged)
	// สวิตช์รวม: ปิด = ไม่ใช้ preset ใดๆ ตอนเริ่มสตรีม
	Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
	// preset แนะนำที่มากับตัวโปรแกรม — [{ id, name, nameMatch, note, fields, installedKey }]
	Q_PROPERTY(QVariantList builtInPresets READ builtInPresets NOTIFY profilesChanged)
	// preset ที่ใช้กับสตรีมปัจจุบัน (ว่าง = ไม่มี) — ให้ UI ส่วนอื่นแสดง "Preset: <game>"
	Q_PROPERTY(QString activeProfileName READ activeProfileName NOTIFY activeProfileChanged)
	Q_PROPERTY(QString activeTitleId READ activeTitleId NOTIFY activeProfileChanged)

public:
	PsWrapGameProfiles(QObject *window, QmlBackend *backend, std::function<Settings *()> settings_getter);

	QVariantList profiles() const;
	QVariantList runningGames() const { return running_games; }
	QVariantList builtInPresets() const;
	bool enabled() const;
	void setEnabled(bool v);
	QString activeProfileName() const { return active_name; }
	QString activeTitleId() const { return active_title_id; }

	Q_INVOKABLE bool hasProfile(const QString &title_id) const;
	Q_INVOKABLE QVariantMap profile(const QString &title_id) const;   // ไม่มี = map ว่าง
	// บันทึก (สร้าง/แทนที่) ตาม titleId ใน map · ช่องที่ไม่มี/เป็น null = ไม่ตั้ง (ใช้ค่าปัจจุบัน)
	Q_INVOKABLE bool saveProfile(const QVariantMap &profile);
	Q_INVOKABLE void removeProfile(const QString &title_id);
	// preset ใหม่ที่ทุกช่องถูกตั้งเป็นค่าปัจจุบัน (สร้างจาก "setting ตอนนี้")
	Q_INVOKABLE QVariantMap snapshotCurrent(const QString &title_id, const QString &name) const;
	// window มี property นี้ไหม (clockOverlay / replayEnabled เพิ่มโดยงานอื่น — UI ซ่อนช่องที่ยังไม่มี)
	Q_INVOKABLE bool windowSupports(const QString &property) const;
	Q_INVOKABLE QStringList fieldKeys() const;

	// ---------- preset แนะนำ (built-in) ----------
	// draft ของ preset แนะนำ พร้อมเปิดในตัวแก้ (title_id ว่าง = ใช้ key ชั่วคราว builtin:<id> แล้วจับจากชื่อเกม)
	Q_INVOKABLE QVariantMap builtInPreset(const QString &id, const QString &title_id = QString()) const;
	// เพิ่ม preset แนะนำเข้ารายการทันที แล้วคืน key ที่เก็บ (ว่าง = ไม่สำเร็จ)
	Q_INVOKABLE QString addBuiltInPreset(const QString &id, const QString &title_id = QString());
	// key ของ preset ที่บันทึกไว้แล้วสำหรับ built-in นี้ (ว่าง = ยังไม่มี)
	Q_INVOKABLE QString installedKeyForBuiltIn(const QString &id) const;

	// เรียกจาก QmlBackend::createSession หลังรับ connect_info ก่อนสร้าง StreamSession
	// คืน true ถ้าแก้ video_profile (ผู้เรียกควร sync max fps ใหม่)
	bool prepareSession(StreamSessionConnectInfo &info, const QVariantList &hosts);

signals:
	void profilesChanged();
	void runningGamesChanged();
	void enabledChanged();
	void activeProfileChanged();

private:
	struct Applied { QByteArray prop; QVariant before; QVariant after; };

	Settings *settings() const { return settings_getter ? settings_getter() : nullptr; }
	void reloadIfSettingsChanged();
	void load();
	void store();
	void refreshRunningGames();
	// key ของ preset ที่ตรงกับเกมนี้: title ID ก่อน แล้วค่อยดู nameMatch
	QString matchKey(const QString &title_id, const QString &app) const;
	void onSessionChanged(StreamSession *s);
	void applyWindowFields(const QVariantMap &p);
	void restoreWindowFields();
	// จับได้จากชื่อ → ย้าย preset ไปอยู่ใต้ title ID จริง
	void adoptTitleId(const QString &key, const QString &title_id);
	static QVariantMap normalize(const QVariantMap &in);

	QPointer<QObject> window;
	QPointer<QmlBackend> backend;
	std::function<Settings *()> settings_getter;
	Settings *loaded_from = nullptr;
	QJsonObject data;                 // { "enabled": bool, "profiles": { "<titleId>": {...} } }

	QVariantList running_games;
	QVariantMap pending;              // preset ที่เลือกไว้ใน prepareSession รอ session เริ่ม
	QString active_name;
	QString active_title_id;
	QList<Applied> applied;           // ค่าที่ตั้งบน window ไปแล้ว (ไว้คืนตอนจบ)
};
