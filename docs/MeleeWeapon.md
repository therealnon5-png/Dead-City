# Machete setup

คัดลอก `weapons/MeleeWeapon.server.luau` ทั้งไฟล์ไปแทน `Machete > MacheteScript` ใน Studio. โฟลเดอร์ `weapons` ไม่อยู่ใน Rojo mapping. เก็บ `Handle` พร้อมเสียง `Hit`/`Swing` และ `ChopR6`/`ChopR15` Animation. เปิด `CanTouch` บน Handle และชิ้นส่วน NPC. Script เรียก `ServerScriptService.Server.GoreService.RegisterHit` ครั้งเดียวต่อ Humanoid ต่อ swing; service จัดการ creator tag, damage, เลือด และโมเดล Gore.

รายละเอียด asset และการทดสอบอยู่ใน [ZombieGore.md](ZombieGore.md).
