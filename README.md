# Terrence: Path of the Hero — starter project

## 1. Install Godot
Download **Godot 4.3** (or newer 4.x) from https://godotengine.org/download — pick the
"Standard" version, not .NET, unless you specifically want C#. It's a single
executable, no install needed.

## 2. Open the project
Launch Godot → **Import** → point it at this folder's `project.godot` file → **Import & Edit**.

## 3. Run it
Press **F5** (or the ▶ button, top right). The first time, Godot will ask which
scene is the main one — `scenes/MainMenu.tscn` is already set as default in
`project.godot`, so you can just hit F5 from now on.

To test a single screen in isolation (handy while tuning the map), open that
scene in the editor and press **F6**.

## What's already built

```
MainMenu  →  New Player  →  Register  →  PostLogin  →  New Game → Map → AreaScreen
          →  Log In      →  Login    →     ↑                        ↑
          →  High Scores (stub)        Continue (stub)      click any region
```

- **MainMenu** — your `menu.jpg` as background, 3 buttons.
- **Register** — Name / Password / Repeat Password. Validates: name not empty
  and not already taken, password not empty, password > 3 characters, no
  spaces in the password, and both password fields match.
- **Login** — Name / Password, checked against the same records.
- **PostLogin** — same background, now shows New Game / Continue / High Scores.
- **Map** — your `map.jpg`, with an invisible ~18×18px button generated over
  every region name, plus a Back button.
- **AreaScreen** — an empty placeholder that just shows which region you
  clicked. This is the "for now just opening empty screen" bit — build each
  region's real content here later.

## Where the player data lives
`PlayerManager.gd` is an **autoload** (a singleton, always loaded — see
`project.godot` → `[autoload]`), so any script can call
`PlayerManager.player_exists(...)`, `PlayerManager.register_player(...)`, etc.

It writes two things at runtime, under `user://` (a real folder Godot manages
for you — never inside your project folder, and it's the only place writable
once you export the game):

- `user://players.txt` — one line per player: `name|password`
- `user://players/<name>.txt` — a growing per-player file, currently just
  `name=`, `hero=`, `level=1`, `stats=` placeholders for you to fill in as
  you add hero selection, leveling, etc.

To find that folder on your machine while testing in the editor: **Project →
Open User Data Folder** in the Godot menu.

⚠️ Passwords are stored as plain text, exactly as you asked. That's fine for a
personal/learning project, but don't reuse a real password when testing, and
if this ever ships publicly you'd want to hash passwords instead of storing
them raw.

## Positioning the map buttons precisely
`scripts/Map.gd` has a `REGIONS` array — one `{"name": ..., "pos": Vector2(x, y)}`
entry per label, where `x` and `y` are **percentages of the screen** (0.0 to
1.0), not pixels. I estimated these by eye from your map image, so they're in
the right neighborhood but not pixel-perfect. Fastest way to fix them:

1. Open `scenes/Map.tscn`, press **F6** to run just that scene.
2. Click near a region's button — if it's off, note roughly how far off.
3. Nudge that region's `Vector2(x, y)` in `Map.gd` (right is +x, down is +y)
   and re-run. Repeat.

Since positions are percentages, they'll stay lined up on any screen size.

## Sizing / mobile
The project is set to a 1280×720 base resolution with `stretch/mode =
"canvas_items"`, which scales everything to fit the device screen while
keeping your UI code working in one consistent coordinate space — you don't
need to think about actual device resolution anywhere in the scripts above.

## Natural next steps
- Hero selection screen after "New Game", before the map.
- Wire `Continue` to read `PlayerManager.current_player_file()`.
- Give each region in `AreaScreen.gd` its own real scene instead of the
  shared placeholder.
- High scores: probably another `user://` text file, sorted on load.
