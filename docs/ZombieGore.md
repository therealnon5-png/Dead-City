# Zombie Gore (R6) และอาวุธ

โปรเจกต์จริงอยู่ที่ `D:\Dead_City_Project\Dead-City` และ `default.project.json` ในโฟลเดอร์นี้ sync `src/server` ไปที่ `ServerScriptService.Server`.

## สคริปต์ที่ sync ผ่าน Rojo

- `src/server/GoreService.luau` -> `ServerScriptService.Server.GoreService` (ModuleScript)
- `src/server/ZombieGoreHandler.server.luau` -> `ServerScriptService.Server.ZombieGoreHandler` (Script)
- `src/server/ZombieGore.luau` -> compatibility module สำหรับสคริปต์เก่าที่ require ชื่อนี้

Handler ตั้งค่า NPC ที่ติด tag `Zombie` หรือ `zombie`, ตั้ง `BreakJointsOnDeath = false`, สร้าง `ReplicatedStorage.GoreRemotes.WeaponHit` และ `ServerStorage.GoreHitEvent`. `WeaponHit` ใช้ได้เฉพาะ Tool ที่ตั้ง `GoreRemoteEnabled = true`, `Damage`, `FireRate` Attributes และผ่านการตรวจ raycast จาก Server. Machete/Pistol ในงานนี้เรียก `GoreService.RegisterHit` จาก Server Script ของตัวเองโดยตรง ไม่ต้องเปิด Attribute นี้.

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
3. Pistol: คัดลอก `weapons/GunScript_Local.client.luau` ทั้งไฟล์แทน source ของ `Pistol > GunScript_Local`. เก็บ child GUI/effect/animation objects เดิม. Client ส่ง `hitPart`/`hitPosition` เพิ่ม; Server ใช้ raycast และค่าดาเมจจาก `Setting`, ไม่เชื่อ damage จาก Client.

`WAP`, `VisualizeBulletScript`, `BulletVisualizerScript`, `nothing` และ `Setting` ไม่ต้องแก้สำหรับ Gore. Pistol ตามค่า Setting ที่ให้ (`ExplosiveEnabled = false`) ผ่านทาง hit ปกติ; ระบบนี้ยังไม่ได้รองรับการทำดาเมจแบบพื้นที่ของกระสุนระเบิด.

## ตรวจใน Studio

- หัว/แขนซ้าย/แขนขวา/อกของ R6 tagged zombie ขึ้นโมเดลตรงชิ้นและติดตาม animation; โจมตีซ้ำไม่ซ้อนโมเดล.
- ยิงหรือตีโดนโมเดล Gore ที่ติดแล้ว: damage และเลือดยังทำงาน.
- Lethal hit, zombie ตาย, corpse cleanup, unequip, reset character, ผู้เล่นสองคน, ammo/reload, teammate, ForceField.
- ลองเอา template ออกหนึ่งชิ้น: Output เตือนและไม่ซ่อนชิ้นเดิม.

`rojo build` ตรวจได้เพียงโครงสร้างและ source; ไม่ยืนยัน asset, hitbox, animation หรือผล runtime ใน Studio.
