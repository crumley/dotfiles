-- test/b3sync-hammerspoon.lua -- brainsync.lua under a fake `hs`.
--
--   lua test/b3sync-hammerspoon.lua REPO      (run by test/b3sync-test.sh)
--
-- Hammerspoon cannot run in CI, and the parts of brainsync.lua most likely to
-- be subtly wrong are pure logic: which events count as leaving or arriving,
-- the debounce that makes lid-close one sync rather than two, the retry after
-- a failed arrival, which runs pass --settle 0, and the guards that keep the
-- module a no-op on a machine that has not opted in. This drives exactly that
-- logic through a stand-in `hs` with a hand-cranked clock. Whether the real
-- caffeinate watcher fires before a closing lid sleeps the machine is not
-- something a fake can answer.
--
-- Prints `ok <name>` / `FAIL <name>` per check; exits 1 on any failure.

local repo = arg[1] or "."
package.path = repo .. "/hammerspoon/.hammerspoon/?.lua;" .. package.path

local failures = 0
local function check(name, cond)
    if cond then
        print("ok " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name)
    end
end

-- ---------------------------------------------------------------------------
-- The fake
-- ---------------------------------------------------------------------------

local HOME = "/fakehome"
local W = { screensDidLock = 1, systemWillSleep = 2, systemDidWake = 3, screensDidUnlock = 4, screensaverDidStart = 5 }

local world

local function reset(opts)
    opts = opts or {}
    world = {
        now = 1000,
        files = opts.files or {},          -- path -> true (executable file)
        execute = opts.execute or {},      -- command -> output (status true); absent -> failure
        launches = {},                     -- { args = {...}, task = t }
        timers = {},
        hotkeys = {},
        alerts = {},
        watchers = {},
    }
end

local function newTask(path, callback, args)
    local t = { path = path, callback = callback, args = args }
    function t:start()
        world.launches[#world.launches + 1] = self
        return self
    end
    function t:finish(code, out)
        self.callback(code, out or "", "")
    end
    return t
end

hs = {
    logger = {
        new = function()
            local l = {}
            for _, level in ipairs({ "d", "i", "w", "e", "f" }) do
                l[level] = function() end
            end
            return l
        end,
    },
    fs = {
        attributes = function(path)
            if world.files[path] then
                return { mode = "file", permissions = "rwxr-xr-x" }
            end
            return nil
        end,
    },
    execute = function(cmd)
        local out = world.execute[cmd]
        if out == nil then
            return "", nil, "exit", 1
        end
        return out, true, "exit", 0
    end,
    timer = {
        secondsSinceEpoch = function()
            return world.now
        end,
        doAfter = function(seconds, fn)
            local t = { at = world.now + seconds, fn = fn, stopped = false }
            function t:stop()
                self.stopped = true
            end
            world.timers[#world.timers + 1] = t
            return t
        end,
    },
    task = { new = newTask },
    caffeinate = {
        watcher = setmetatable({
            new = function(fn)
                local w = { fn = fn, running = false }
                function w:start() self.running = true; return self end
                function w:stop() self.running = false; return self end
                world.watchers[#world.watchers + 1] = w
                return w
            end,
        }, { __index = W }),
    },
    hotkey = {
        bind = function(mods, key, fn)
            local h = { mods = mods, key = key, fn = fn }
            function h:delete() end
            world.hotkeys[#world.hotkeys + 1] = h
            return h
        end,
    },
    alert = {
        show = function(msg)
            world.alerts[#world.alerts + 1] = msg
        end,
    },
}
os.getenv = (function(real)
    return function(name)
        if name == "HOME" then
            return HOME
        end
        return real(name)
    end
end)(os.getenv)

-- Advance the clock, firing any timer that comes due.
local function advance(seconds)
    world.now = world.now + seconds
    for _, t in ipairs(world.timers) do
        if not t.stopped and not t.fired and t.at <= world.now then
            t.fired = true
            t.fn()
        end
    end
end

local function fire(event)
    world.watchers[#world.watchers].fn(event)
end

local function joined(args)
    return table.concat(args, " ")
end

local function hasSettleZero(launch)
    return joined(launch.args):find("--settle 0", 1, true) ~= nil
end

local RUNNER = HOME .. "/bin/b3-sync-runner"
local BUN_B3 = HOME .. "/.bun/bin/b3"

local function load()
    package.loaded.brainsync = nil
    return require("brainsync")
end

local function enabled(settings, files)
    reset({ files = files or { [RUNNER] = true, [BUN_B3] = true } })
    local m = load()
    local started = m.start(settings or { brainSync = true })
    return m, started
end

-- ---------------------------------------------------------------------------
-- Guards
-- ---------------------------------------------------------------------------

reset({ files = { [RUNNER] = true, [BUN_B3] = true } })
local m = load()
check("no opt-in: start() returns false", m.start({}) == false)
check("no opt-in: no watcher, no hotkey", #world.watchers == 0 and #world.hotkeys == 0)
check("no settings table at all is the same no-op", load().start(nil) == false)

reset({ files = { [BUN_B3] = true } })
check("opted in but the runner is not linked: a no-op", load().start({ brainSync = true }) == false)
check("... with no watcher", #world.watchers == 0)

reset({ files = { [RUNNER] = true } })
check("opted in but no b3 anywhere: a no-op", load().start({ brainSync = true }) == false)
check("... with no watcher", #world.watchers == 0)

-- Resolution order and sources.
reset({ files = { [RUNNER] = true, ["/somewhere/brew/bin/b3"] = true },
    execute = { ["brew --prefix 2>/dev/null"] = "/somewhere/brew\n" } })
check("b3 is found under Homebrew's own prefix", load().resolveB3() == "/somewhere/brew/bin/b3")

reset({ files = { [RUNNER] = true, ["/opt/x/b3"] = true },
    execute = { ["command -v b3 2>/dev/null"] = "Welcome to fish\n/opt/x/b3\n" } })
check("b3 is found on the login shell's PATH, past a greeting", load().resolveB3() == "/opt/x/b3")

reset({ files = { [HOME .. "/bin/b3"] = true, [BUN_B3] = true } })
check("~/bin is preferred to ~/.bun/bin", load().resolveB3() == HOME .. "/bin/b3")

-- ---------------------------------------------------------------------------
-- Enabled
-- ---------------------------------------------------------------------------

m, started = enabled()
check("opted in with b3 and the runner: enabled", started == true)
check("a caffeinate watcher is started", #world.watchers == 1 and world.watchers[1].running)
check("the default hotkey is hyper+shift+B",
    #world.hotkeys == 1 and world.hotkeys[1].key == "B"
    and joined(world.hotkeys[1].mods) == "ctrl cmd option shift")

-- Leaving: lid close is lock, then sleep a second later.
fire(W.screensDidLock)
advance(1)
fire(W.systemWillSleep)
check("lock + sleep is one leaving sync", #world.launches == 1)
local leave = world.launches[1]
check("it goes through the login shell to ~/bin/b3-sync-runner",
    leave.path == "/bin/sh" and leave.args[1] == "-lc"
    and leave.args[2] == 'exec "$HOME/bin/b3-sync-runner" "$@"')
check("the leaving sync passes --settle 0", hasSettleZero(leave))
check("and says why", joined(leave.args):find("--reason leave", 1, true) ~= nil)
leave:finish(0, "ok: committed 1, pulled 0, pushed 1\n")
check("a transition shows no alert", #world.alerts == 0)

-- Arriving: wake, then unlock once the password is typed.
advance(3600)
fire(W.systemDidWake)
check("arriving waits for the network rather than syncing at once", #world.launches == 1)
advance(m.arriveDelaySeconds)
check("then syncs", #world.launches == 2)
local arrive = world.launches[2]
check("the arriving sync keeps the default settle", not hasSettleZero(arrive))
check("and says why", joined(arrive.args):find("--reason arrive", 1, true) ~= nil)
advance(20)
fire(W.screensDidUnlock)
advance(m.arriveDelaySeconds)
check("wake + unlock is one arriving sync", #world.launches == 2)
arrive:finish(0, "ok: already converged\n")

-- A failed arrival does not swallow the next arrive event.
m, started = enabled()
fire(W.systemDidWake)
advance(m.arriveDelaySeconds)
world.launches[1]:finish(1, "error: b3 sync exited 1: pull failed\n")
advance(10)
fire(W.screensDidUnlock)
advance(m.arriveDelaySeconds)
check("an arrival that failed (no network yet) is retried on unlock", #world.launches == 2)

-- The other kind resets the window: lock, unlock, lock inside a minute.
m, started = enabled()
fire(W.screensDidLock)
advance(10)
fire(W.screensDidUnlock)
advance(m.arriveDelaySeconds)
advance(10)
fire(W.screensDidLock)
check("lock -> unlock -> lock is three syncs", #world.launches == 3)

-- Leaving cancels an arrival still waiting out its delay.
m, started = enabled()
fire(W.systemDidWake)
advance(1)
fire(W.systemWillSleep)
advance(m.arriveDelaySeconds + 1)
check("a leave inside the arrival delay cancels the arrival", #world.launches == 1 and hasSettleZero(world.launches[1]))

-- Past the window, the same kind syncs again.
m, started = enabled()
fire(W.screensDidLock)
world.launches[1]:finish(0, "ok\n")
advance(m.debounceSeconds + 1)
fire(W.screensDidLock)
check("the same kind after the window syncs again", #world.launches == 2)

-- Events that are neither leaving nor arriving.
m, started = enabled()
fire(W.screensaverDidStart)
advance(60)
check("other caffeinate events start nothing", #world.launches == 0)

-- ---------------------------------------------------------------------------
-- On demand
-- ---------------------------------------------------------------------------

m, started = enabled()
world.hotkeys[1].fn()
check("the hotkey starts a sync", #world.launches == 1)
check("with --settle 0: the key was pressed on purpose", hasSettleZero(world.launches[1]))
check("labelled hotkey", joined(world.launches[1].args):find("--reason hotkey", 1, true) ~= nil)
world.launches[1]:finish(0, "ok: committed 0, pulled 3, pushed 0\n")
check("and shows the runner's summary in an alert",
    world.alerts[#world.alerts] == "b3 sync: ok: committed 0, pulled 3, pushed 0")

world.hotkeys[1].fn()
world.launches[2]:finish(0, "queued: a sync is already running\nok: already converged\n")
check("two summaries (a queued run followed) are joined on one line",
    world.alerts[#world.alerts] == "b3 sync: queued: a sync is already running / ok: already converged")

check("BrainSync.run() is the same sync without a hotkey", m.run() == "started" and hasSettleZero(world.launches[3]))

m, started = enabled({ brainSync = true, brainSyncHotkey = false })
check("brainSyncHotkey = false binds no hotkey", started and #world.hotkeys == 0)

m, started = enabled({ brainSync = true, brainSyncHotkey = { mods = { "cmd", "alt" }, key = "S" } })
check("brainSyncHotkey chooses the chord",
    #world.hotkeys == 1 and world.hotkeys[1].key == "S" and joined(world.hotkeys[1].mods) == "cmd alt")

reset({ files = {} })
m = load()
check("run() on a machine that is not enabled says so and starts nothing",
    m.run() == "disabled" and #world.launches == 0)

if failures > 0 then
    os.exit(1)
end
