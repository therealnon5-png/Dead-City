// node tests/inventory-controller-regression.cjs <absolute node_modules path>
// Controller behavior with mocked Roblox services; viewport rendering needs Studio.
const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(path.join(process.argv[2], 'fengari'));
const source = fs.readFileSync(path.join(__dirname, '../src/client/InventoryController.client.luau'), 'utf8');
const serverSource = fs.readFileSync(path.join(__dirname, '../src/server/InventoryRemote.server.luau'), 'utf8');
const mock = `
table.clear = function(t) for k in pairs(t) do t[k] = nil end end
typeof = type
local function signal()
    local s = { listeners = {} }
    function s:Connect(fn)
        local connection = { active = true, fn = fn }
        function connection:Disconnect() self.active = false end
        table.insert(self.listeners, connection)
        return connection
    end
    function s:Fire(...)
        for _, c in ipairs(self.listeners) do if c.active then c.fn(...) end end
    end
    return s
end
local function node(name, class)
    local n = { Name = name, ClassName = class, children = {}, attributes = {}, signals = {}, ChildAdded = signal(), ChildRemoved = signal(), DescendantAdded = signal(), DescendantRemoving = signal(), Activated = signal() }
    function n:IsA(c) return self.ClassName == c or (c == 'GuiButton' and self.ClassName == 'TextButton') end
    function n:GetChildren() return self.children end
    function n:GetDescendants()
        local result = {}
        for _, child in ipairs(self.children) do
            table.insert(result, child)
            for _, descendant in ipairs(child:GetDescendants()) do table.insert(result, descendant) end
        end
        return result
    end
    function n:FindFirstChild(wanted, recursive)
        for _, child in ipairs(recursive and self:GetDescendants() or self.children) do
            if child.Name == wanted then return child end
        end
    end
    function n:WaitForChild(wanted) return assert(self:FindFirstChild(wanted), wanted) end
    function n:GetAttribute(key) return self.attributes[key] end
    function n:SetAttribute(key, value) self.attributes[key] = value end
    function n:GetPropertyChangedSignal(key)
        self.signals[key] = self.signals[key] or signal()
        return self.signals[key]
    end
    function n:Destroy() self.destroyed = true end
    return n
end
local player = node('Player', 'Player')
player.Character = node('Character', 'Model')
player.CharacterAdded, player.CharacterRemoving = signal(), signal()
local pg, inventory = node('PlayerGui', 'PlayerGui'), node('InventoryGui', 'ScreenGui')
local close, frame, viewport = node('CloseButton', 'TextButton'), node('CharacterFrame', 'Frame'), node('ViewportFrame', 'ViewportFrame')
player.children = {pg}; pg.children = {inventory}; inventory.children = {close, frame}; frame.children = {viewport}
local input = { focused = false, InputBegan = signal() }
function input:GetFocusedTextBox() return self.focused end
local gui = { MenuIsOpen = false, MenuOpened = signal() }
local actions, render = {}, {}
function actions:BindActionAtPriority(name, callback) self.callback = callback end
function actions:UnbindAction() self.callback = nil end
function render:BindToRenderStep(name, priority, callback) self.callback = callback end
function render:UnbindFromRenderStep() self.callback = nil end
local services = { Players = {LocalPlayer = player}, ContextActionService = actions, UserInputService = input, GuiService = gui, RunService = render, ReplicatedStorage = node('ReplicatedStorage', 'ReplicatedStorage') }
game = {}; function game:GetService(name) return assert(services[name], name) end
Enum = { CameraType = {Scriptable = 'Scriptable', Custom = 'Custom'}, MouseBehavior = {Default = 'Default', LockCenter = 'LockCenter'}, ContextActionResult = {Pass = 'Pass', Sink = 'Sink'}, UserInputState = {Begin = 'Begin'}, ContextActionPriority = {High = {Value = 3000}}, RenderPriority = {Camera = {Value = 200}}, KeyCode = {I = 'I'} }
workspace = { CurrentCamera = {CameraType = 'Custom'} }
local createdRemote, replies = nil, {}
Instance = {}; function Instance.new(class)
    local object = node(class, class)
    if class == 'RemoteEvent' then
        createdRemote = object
        object.OnClientEvent, object.OnServerEvent = signal(), signal()
        function object:FireServer(enabled, revision) self.OnServerEvent:Fire(player, enabled, revision) end
        function object:FireClient(target, enabled, revision)
            assert(target == player, 'Remote must target the requesting player only')
            table.insert(replies, {enabled, revision})
        end
    end
    return object
end
UDim2 = {}; function UDim2.fromOffset(x,y) return {x,y} end
script = {Parent = node('Client', 'Folder'), Destroying = signal()}
script.Parent.children = previewMode == 'missing' and {} or {node('InventoryPreview', 'ModuleScript')}
local created, destroyed = 0, 0
require = function()
    if previewMode == 'broken' then error('Broken preview module') end
    return { new = function(v, c)
        assert(v == viewport and c == player.Character)
        created = created + 1
        return { Step = function() end, Destroy = function() destroyed = destroyed + 1 end }
    end }
end
local warnings = {}
warn = function(message) table.insert(warnings, message) end
`;
const checks = `
local function pressI() input.InputBegan:Fire({KeyCode = 'I'}, true) end
assert(inventory.Enabled == false, 'Starts closed')
assert(actions.callback('', 'Begin') == 'Sink')
assert(not inventory.Enabled, 'Zoom blocker must not double-toggle')
pressI()
assert(inventory.Enabled and player:GetAttribute('InventoryOpen'), 'I opens inventory')
assert(workspace.CurrentCamera.CameraType == 'Scriptable' and input.MouseBehavior == 'Default', 'Open releases mouse and pauses view')
assert(created == (previewMode == 'normal' and 1 or 0), 'Preview failures do not block open')
local staleReply = replies[#replies]
close.Activated:Fire()
assert(not inventory.Enabled and workspace.CurrentCamera.CameraType == 'Custom', 'Close restores camera')
createdRemote.OnClientEvent:Fire(staleReply[1], staleReply[2])
assert(not inventory.Enabled, 'Delayed open reply must not undo close')
assert(input.MouseBehavior == 'LockCenter' and destroyed == created, 'Close releases preview and restores capture')
input.focused = true
pressI()
assert(actions.callback('', 'Begin') == 'Pass' and not inventory.Enabled, 'Typing I does not toggle')
input.focused = false
pressI(); pressI()
assert(not inventory.Enabled, 'Second I closes inventory')
pressI(); player.CharacterRemoving:Fire()
assert(not inventory.Enabled and not player:GetAttribute('InventoryOpen'), 'Respawn closes inventory')
pressI(); gui.MenuOpened:Fire()
assert(not inventory.Enabled, 'Escape menu closes inventory')
local count = #replies
createdRemote:FireServer('invalid', 3)
createdRemote:FireServer(true, -1)
assert(#replies == count, 'Server rejects invalid payloads')
script.Destroying:Fire()
assert(created == destroyed and not actions.callback and not render.callback, 'Cleanup releases resources')
`;
for (const mode of ['normal', 'missing', 'broken']) {
    const L = lauxlib.luaL_newstate();
    lualib.luaL_openlibs(L);
    const serverHook = '\nassert(createdRemote and createdRemote.Name == "InventoryToggle", "Server creates remote"); services.ReplicatedStorage.children = {createdRemote}\n';
    const status = lauxlib.luaL_dostring(L, to_luastring(`local previewMode = '${mode}'\n` + mock + '\n' + serverSource + serverHook + source + '\n' + checks));
    if (status !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
    console.log('PASS:', mode, 'preview; I, close, remote creation/validation, stale replies, typing, respawn and cleanup');
}
