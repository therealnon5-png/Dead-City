# Machete setup

คัดลอก `weapons/MeleeWeapon.server.luau` ทั้งไฟล์ไปแทน Source ของ `Machete > MacheteScript` ใน Studio. โฟลเดอร์ `weapons` ไม่อยู่ใน Rojo mapping. เก็บ `Handle` พร้อมเสียง `Hit`/`Swing` และ `ChopR6`/`ChopR15` Animation. เปิด `CanTouch` บน Handle และชิ้นส่วน NPC.

Script ใช้ flow ต้นฉบับ: creator tag, damage 20, cooldown 0.8 วินาที, เสียง และ animation เดิม. แทรก `GoreVisualHit:Fire` ก่อน `TakeDamage` เพื่อให้ `ZombieGoreHandler` จัดการภาพ Gore ภายนอก sandbox. ไม่เรียก `RegisterHit` จึงไม่ทำ damage ซ้ำและไม่เปลี่ยน damage แขน/หัว. ถ้า handler ไม่พร้อม damage ของอาวุธยังทำงาน. เชื่อม `Unequipped` ที่ต้นฉบับขาด เพื่อเก็บกวาด event/animation หลังเลิกถือ.

รายละเอียด asset และการทดสอบอยู่ใน [ZombieGore.md](ZombieGore.md).
