// Run: node tests/weapon-gore-regression.cjs <directory containing luaparse and fengari>
// A small Lua mock validates integration contracts; it is not a Studio test.
const fs = require('fs');
const path = require('path');
const modules = process.argv[2];
const parser = require(path.join(modules, 'luaparse'));
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(path.join(modules, 'fengari'));
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, 'weapons', name), 'utf8').replace(/^\uFEFF/, '');
for (const name of ['MeleeWeapon.server.luau', 'GunScript_Server.server.luau', 'GunScript_Local.client.luau']) {
    parser.parse(read(name), { luaVersion: '5.3' });
    console.log('Syntax PASS:', name);
}
parser.parse(fs.readFileSync(path.join(root, 'src/server/ZombieGoreHandler.server.luau'), 'utf8'), { luaVersion: '5.3' });
console.log('Syntax PASS: ZombieGoreHandler.server.luau');
for (const name of ['MeleeWeapon.server.luau', 'GunScript_Server.server.luau']) {
    if (read(name).includes('require(module)') || read(name).includes('require(GoreService)')) {
        throw new Error(name + ' still requires GoreService across sandbox containers');
    }
}
const mock = `
local function signal()
    local s = { listeners = {} }
    function s:Connect(fn)
        local c = { fn = fn, active = true }
        function c:Disconnect() self.active = false end
        table.insert(self.listeners, c)
        return c
    end
    s.connect = s.Connect
    function s:Fire(...)
        for _, c in ipairs(self.listeners) do if c.active then c.fn(...) end end
    end
    return s
end
local function node(name, class)
    local n = { Name = name, ClassName = class, children = {}, kind = 'Instance' }
    function n:IsA(c) return self.ClassName == c or (c == 'BasePart' and self.ClassName == 'Part') end
    function n:FindFirstChild(k) return self.children[k] end
    function n:WaitForChild(k) assert(self.children[k], 'Unexpected wait: ' .. k) return self.children[k] end
    function n:FindFirstChildOfClass(c)
        for _, v in pairs(self.children) do if v:IsA(c) then return v end end
    end
    function n:GetChildren() local t = {} for _, v in pairs(self.children) do table.insert(t, v) end return t end
    function n:IsDescendantOf(p)
        local current = self.Parent
        while current do if current == p then return true end current = current.Parent end
        return false
    end
    function n:Destroy() self.destroyed = true end
    return n
end
local function child(parent, name, class)
    local n = node(name, class) n.Parent = parent parent.children[name] = n return n
end
local v = { kind = 'Vector3', Magnitude = 1 }
v.Unit = v
setmetatable(v, { __sub = function() return v end, __mul = function() return v end })
function typeof(x) return type(x) == 'table' and x.kind or type(x) end
workspace = node('Workspace', 'Workspace') Workspace = workspace Workspace.FilteringEnabled = true
local char = child(workspace, 'Character', 'Model')
local owner = { Character = char, Neutral = true }
local h = child(char, 'Humanoid', 'Humanoid') h.Health = 100 h.RigType = { Name = 'R6' }
function h:LoadAnimation()
    return { Play = function() end, Stop = function() end, Destroy = function() end }
end
local target = child(workspace, 'Zombie', 'Model')
local victim = child(target, 'Humanoid', 'Humanoid') victim.Health = 100
local damageCalls, goreCalls, warningCalls, order = 0, 0, 0, {}
function victim:TakeDamage(amount)
    damageCalls = damageCalls + 1 self.Health = self.Health - amount table.insert(order, 'damage')
end
local head = child(target, 'Head', 'Part') head.Position = v head.Size = v
local torso = child(target, 'HumanoidRootPart', 'Part') torso.Position = v
local tool = child(char, 'Tool', 'Tool')
tool.Equipped = signal() tool.Unequipped = signal() tool.Activated = signal()
local handle = child(tool, 'Handle', 'Part') handle.Position = v handle.Touched = signal()
for _, name in ipairs({'Hit', 'Swing'}) do local sound = child(handle, name, 'Sound') function sound:Play() end end
child(tool, 'ChopR6', 'Animation')
child(tool, 'VisualizeBullet', 'RemoteEvent')
local setting = child(tool, 'Setting', 'ModuleScript')
script = child(tool, 'Script', 'Script')
local goreEvent = child(script, 'GoreVisualHit', 'BindableEvent')
function goreEvent:Fire()
    if MODE == 'broken' then error('Bindable bridge failed') end
    if MODE == 'ready' then goreCalls = goreCalls + 1 table.insert(order, 'gore') end
end
for _, name in ipairs({'ChangeAmmoAndClip', 'InflictTarget'}) do
    local remote = child(script, name, 'RemoteEvent') remote.OnServerEvent = signal()
end
local sss = node('ServerScriptService', 'ServerScriptService')
local server = child(sss, 'Server', 'Folder')
local module = node('GoreService', 'ModuleScript')
if MODE ~= 'missing' then server.children.GoreService = module end
local settings = { DualEnabled = false, AmmoPerClip = 8, LimitedClipEnabled = false,
    Clips = 10, MaxClip = 10, IdleAnimationID = 123, FireAnimationID = 456,
    BaseDamage = 15, HeadshotEnabled = true, HeadshotDamageMultiplier = 3,
    Knockback = 0, Lifesteal = 0, FlamingBullet = false, Radius = 8 }
function require(m)
    if m == setting then return settings end
    if MODE == 'broken' then error('Broken Gore module') end
    return { GetZombie = function() return target, victim, head end,
        ApplyHit = function() goreCalls = goreCalls + 1 table.insert(order, 'gore') return true end }
end
local players = {}
function players:GetPlayerFromCharacter(c) if c == char then return owner end end
local debris = { AddItem = function() end }
game = { Players = players, Debris = debris }
function game:GetService(name)
    return ({Players = players, Debris = debris, ServerScriptService = sss})[name]
end
local created = {}
Instance = { new = function(c, parent)
    local n = node('', c) n.Parent = parent table.insert(created, n) return n
end }
function warn() warningCalls = warningCalls + 1 end
local delayed
function delay(_, fn) delayed = fn end
Random = { new = function() return { NextNumber = function() return 0 end } end }
`;
const gunAssertions = `
assert(#tool.Equipped.listeners == 1, 'Gun did not initialize equipment')
local sawIdle, sawFire = false, false
for _, n in ipairs(created) do sawIdle = sawIdle or n.Name == 'IdleAnim' sawFire = sawFire or n.Name == 'FireAnim' end
assert(sawIdle and sawFire, 'Gun animation initialization blocked')
tool.Equipped:Fire()
script.children.InflictTarget.OnServerEvent:Fire(owner, victim, torso, 9999, v, 999, 999, true, head, v)
assert(victim.Health == 55 and damageCalls == 1, 'Headshot changed or damage applied twice')
-- Original client with no Gore metadata must still deal ordinary damage.
script.children.InflictTarget.OnServerEvent:Fire(owner, victim, torso, 15, v, 0, 0, false)
assert(victim.Health == 40 and damageCalls == 2, 'Original payload rejected')
script.children.ChangeAmmoAndClip.OnServerEvent:Fire(owner, 7, 0)
script.children.ChangeAmmoAndClip.OnServerEvent:Fire(owner, 8, 0)
for _, n in ipairs(created) do if n.Name == 'Ammo' then assert(n.Value == 8, 'Original reload protocol broken') end end
`;
const meleeAssertions = `
tool.Equipped:Fire()
tool.Activated:Fire()
handle.Touched:Fire(head)
handle.Touched:Fire(head)
assert(victim.Health == 80 and damageCalls == 1, 'Machete damage duplicated or multiplied')
tool.Unequipped:Fire()
delayed()
tool.Equipped:Fire()
tool.Activated:Fire()
handle.Touched:Fire(head)
assert(victim.Health == 60 and damageCalls == 2, 'Re-equipping duplicated damage')
`;
for (const mode of ['ready', 'missing', 'broken']) {
    for (const [name, assertions] of [['GunScript_Server.server.luau', gunAssertions], ['MeleeWeapon.server.luau', meleeAssertions]]) {
        const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
        const check = mode === 'ready'
            ? "assert(goreCalls > 0 and order[1] == 'gore', 'Gore must precede damage'); assert(warningCalls == 0)"
            : mode === 'broken'
                ? "assert(goreCalls == 0 and warningCalls > 0, 'Broken bridge must be reported')"
                : "assert(goreCalls == 0 and warningCalls == 0, 'Missing listener must not block weapon')";
        const code = `local MODE = '${mode}'\n` + mock + '\n' + read(name) + '\n' + assertions + '\n' + check;
        const status = lauxlib.luaL_dostring(L, to_luastring(code));
        if (status !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
        console.log('Mock PASS:', name, mode);
    }
}
