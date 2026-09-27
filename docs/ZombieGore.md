# Zombie Gore (R6) และอาวุธ

โปรเจกต์จริงอยู่ที่ `D:\Dead_City_Project\Dead-City` และ `default.project.json` ในโฟลเดอร์นี้ sync `src/server` ไปที่ `ServerScriptService.Server`.

## สคริปต์ที่ sync ผ่าน Rojo

- `src/server/GoreService.luau` -> `ServerScriptService.Server.GoreService` (ModuleScript)
- `src/server/ZombieGoreHandler.server.luau` -> `ServerScriptService.Server.ZombieGoreHandler` (Script)
- `src/server/ZombieGore.luau` -> compatibility module สำหรับสคริปต์เก่าที่ require ชื่อนี้

Handler ตั้งค่า NPC ที่ติด tag `Zombie` หรือ `zombie`, ตั้ง `BreakJointsOnDeath = false`, สร้าง `ReplicatedStorage.GoreRemotes.WeaponHit` และ `ServerStorage.GoreHitEvent`. `WeaponHit` ใช้ได้เฉพาะ Tool ที่ตั้ง `GoreRemoteEnabled = true`, `Damage`, `FireRate` Attributes และผ่านการตรวจ raycast จาก Server. Machete/Pistol สร้าง `GoreVisualHit` BindableEvent เป็นลูกของ Server Script ใน Tool แล้ว `ZombieGoreHandler` เชื่อม event เพื่อเรียก `GoreService.ApplyGore` เฉพาะภาพ. Tool ไม่ต้อง require module ข้าม sandbox. Damage ยังอยู่ที่ Script อาวุธเดิม ไม่มีการคูณหรือให้ซ้ำ และไม่ต้องเปิด Attribute นี้.

## โมเดลที่ต้องมีใน Studio

Rojo project นี้ไม่มี asset โมเดล Gore ใน filesystem. ต้องมีใน `ServerStorage` ของ place:

```text
Gore_Body_Folder
  Gor_Heads (หรือ Gore_Heads)
    Head (Model หรือ BasePart)
  Gore_Arms
    Left Arm (Model หรือ BasePart)
    Right Arm (Model หรือ BasePart)
  Gore_Chest
    Torso (Model หรือ BasePart)
  Gore_Legs (ถ้าต้องการขา)
    Left Leg
    Right Leg
```

Variant ชื่ออื่นใช้ได้ ถ้ากำหนด String Attribute `BodyPart` บน Model/BasePart เป็นชื่อชิ้น R6 ตรงตัว. รองรับ subfolder. ทุก template ต้อง `Archivable = true` และมีอย่างน้อยหนึ่ง `BasePart`. ตั้ง Pivot ที่จุดกึ่งกลางชิ้นเดิม; ใส่ `CFrameValue` ชื่อ `GoreOffset` ถ้าต้องชดเชยตำแหน่ง. ระบบเลือก template ตามชิ้นที่โดนจริง จึงไม่สุ่มแขนซ้ายไปใส่แขนขวา. หากไม่มี asset จะเตือนใน Output และคงชิ้นเดิมไว้; ไม่มีโมเดลให้แสดงโดยอัตโนมัติ.

ติด CollectionService tag `Zombie` หรือ `zombie` ที่ NPC **Model** R6 ที่มี Humanoid. ชิ้นส่วนเดิมต้องยังอยู่และ raycast/touch ได้. ระบบซ่อนชิ้นเดิมหลัง clone กับ weld สำเร็จ, คง Motor6D, และเลือดออกได้เมื่อโจมตีซ้ำโดยไม่ซ้อนโมเดล.

## Script ที่ต้องแทนใน Studio เอง

โฟลเดอร์ `weapons` อยู่นอก Rojo mapping และไม่ได้ sync เข้า Tool:

1. Machete: คัดลอก `weapons/MeleeWeapon.server.luau` ทั้งไฟล์แทน source ของ `Machete > MacheteScript` เดิม. เก็บ `Handle/Hit`, `Handle/Swing`, `ChopR6`/`ChopR15`. อย่าให้ script เก่ารันซ้อน.
2. Pistol: คัดลอก `weapons/GunScript_Server.server.luau` ทั้งไฟล์แทน source ของ `Pistol > GunScript_Server`. เก็บ child `ChangeAmmoAndClip`, `InflictTarget`, `IgniteScript` และ `Setting` เดิม.
3. Pistol: คัดลอก `weapons/GunScript_Local.client.luau` ทั้งไฟล์แทน source ของ `Pistol > GunScript_Local`. เก็บ child GUI/effect/animation objects เดิม. Client ต่อท้าย payload เดิมด้วย `HitPart`/`HitPosition` เท่านั้น; flow ยิง รีโหลด GUI เสียง Animation และ Dual grip ใช้แบบเดิม. Server จำกัดค่าดาเมจตาม `Setting`.

`WAP`, `qPerfectionWeld`, `VisualizeBulletScript`, `BulletVisualizerScript`, `nothing`, `Model.casing`, `Model.reload` และ `Setting` ใช้ของ Tool เดิม. Client เก็บ branch ยิงปกติ/ระเบิด/เจาะทะลุเดิมไว้และยังส่ง payload เก่าครบ. การแก้ครั้งนี้เป็นการเชื่อมภาพ Gore: ammo/reload และ hit detection ยังใช้ protocol เดิมของอาวุธ ไม่ใช่ระบบยิงที่ Server ตรวจสอบครบทั้ง ammo, cadence และ line of sight. ยังต้องทดสอบจริงใน Studio โดยเฉพาะโหมดที่ Setting ปัจจุบันปิดอยู่.

## ตรวจใน Studio

- หัว/แขนซ้าย/แขนขวา/อกของ R6 tagged zombie ขึ้นโมเดลตรงชิ้นและติดตาม animation; โจมตีซ้ำไม่ซ้อนโมเดล.
- ยิงหรือตีจุดที่มี Gore แล้ว: hitbox R6 เดิมยังรับ damage และเลือดออก. Client ปืนข้าม cosmetic Gore และไม่ข้าม hitbox โปร่งใสที่มี `GoreHitbox`.
- Lethal hit, zombie ตาย, corpse cleanup, unequip, reset character, ผู้เล่นสองคน, ammo/reload, teammate, ForceField.
- ลองเอา template ออกหนึ่งชิ้น: Output เตือนและไม่ซ่อนชิ้นเดิม.

`rojo build` ตรวจได้เพียงโครงสร้างและ source; ไม่ยืนยัน asset, hitbox, animation หรือผล runtime ใน Studio.

## การแก้ regression ของ Tool

เวอร์ชันก่อนหน้าโหลด Gore ก่อนเชื่อม event/สร้าง Animation, เปลี่ยน protocol ammo/reload และลบ Dual grip. เวอร์ชันนี้คืน flow ต้นฉบับและให้ Tool ส่ง event ภายใน sandbox; Handler ที่อยู่นอก sandbox เป็นผู้โหลด Gore. ถ้า Handler ไม่พร้อม damage และ event ของอาวุธยังทำงาน ส่วนภาพ Gore จะยังไม่ขึ้น. Machete ยังคง 20 damage ทุกส่วนและ cooldown 0.8 วินาที; Pistol ใช้ BaseDamage/HeadshotDamageMultiplier เดิม ไม่มี limb multiplier เพิ่ม. ต่อ Unequipped ที่ต้นฉบับมีฟังก์ชันแต่ไม่ได้เชื่อม เพื่อไม่ให้ event Machete ซ้อนเมื่อ equip ซ้ำ.

## ผลตรวจ regression (2026-09-27)

- Lua syntax parser ผ่านทั้งสามไฟล์ Tool.
- `tests/weapon-gore-regression.cjs`: mock ผ่าน 6 กรณี (ปืน/มีด x listener พร้อม/ขาด/event error). ตรวจ startup Animation/events, Gore ก่อน damage, damage เดิมไม่ซ้ำ, payload ปืนเก่า, protocol reload เดิม และ equip มีดซ้ำ.
- เทียบ `GunScript_Local` กับไฟล์แนบต้นฉบับ: เปลี่ยนเฉพาะ ray filter สำหรับ Gore และเพิ่ม Hit/EndPos ท้าย payload สองจุด. ส่วน Reload, UI, Model.casing, Model.reload, visualizer, Animation และ Dual code คงเดิม.
- Rojo build ผ่าน; ไม่ได้ตรวจ runtime Roblox, โมเดล/เสียง/Animation permission หรือการเล่นจริงใน Studio.
- เรียก mock ด้วย `node tests/weapon-gore-regression.cjs <node_modules ที่ติดตั้ง luaparse และ fengari>`.

`GoreVisualHit` สร้างเป็นลูกของ `MacheteScript` หรือ `GunScript_Server` ตอน Script เริ่มทำงาน จึงไม่ต้องสร้างด้วยมือ. จุดนี้รองรับกรณีที่ Sandboxed ตั้งอยู่บน Script เอง. `ZombieGoreHandler` จะติดตาม Script/Tool ใน Backpack/Character และตรวจผู้ถือ, NPC tag, ระยะ และ raycast ของ Pistol ก่อนใส่ภาพ Gore. ถ้า Studio ยังแสดงข้อความ sandbox ให้ดูว่า Rojo sync `ZombieGoreHandler` เวอร์ชันนี้แล้ว และ Tool Script ไม่มี `require(GoreService)` เก่าค้างอยู่.
