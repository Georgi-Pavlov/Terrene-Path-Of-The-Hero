# Terrence: Path of the Hero

A turn-based hero RPG built in Godot 4, where you recruit a hero, fight your way through a world of zones, and level up while every *other* hero in that world is quietly doing the exact same thing in the background.

---

## About the Game

Pick a hero from any unlocked zone, choose their starting skill, and fight your way through turn-based battles - moving, attacking, casting skills, or using items - to clear every stage. Defeat a zone's final stage and you may be challenged to a duel by one of its other heroes; win, and you unlock the next zone.

But you're not the only one adventuring. Every rival hero on the map is simultaneously grinding their own home zone, leveling up, learning skills, and dueling their own rivals - all simulated in the background. Once a hero clears their home turf, they go looking for a fight elsewhere: picking a target zone, grinding through it, and challenging its hero when they arrive. Heroes rise, fall, and get replaced as targets over the course of a run, and you'll get notified the next time you check the map.

### Key Features

- **Turn-based combat** - movement, attacks, skills, and items, with range and targeting that actually matter.
- **Hero recruitment** - pick a hero and a starting skill; that choice is locked in for the run.
- **Leveling & itemization** - earn XP and gold from kills, spend gold at the Shop, and grow your stats and skills.
- **A living world** - every rival hero levels up, fights, and dies in the background, whether you're watching or not.
- **Hero duels & bounties** - clearing a zone can trigger a duel against its hero, with rewards scaled to that hero's own progress.
- **Freedom & invasion** - a hero who clears their home zone sets out to invade another, targeting, re-targeting, and dueling across the map.
- **"While you were away"** - a one-time notification queue on the map surfaces kills and zone wipes that happened since your last visit.
- **World Status screen** - a full at-a-glance view of every zone, every hero in it, and whether they're still alive.
- **High scores** - your best XP is saved when a run ends.

---

## How to Play

Each zone on the map with a green dot offers one or more heroes - browse them with the arrows, pick a skill, and press Accept. Your hero and that skill are locked in for the rest of the run; starting over requires a fresh "New Game."

Fight enemies in turn-based battles. Each turn you may use only one of: movement, attack, skill, or item. Enemies will chase or flee, and you can only attack what's in range - ranged heroes and skills require choosing a target as well.

Killing enemies earns XP (for leveling up) and gold (to spend at the Shop). Potions and stat-boost items can be used any time, free of your turn's move/attack allowance.

Clear every stage in a zone and you may be challenged to a duel by one of that zone's rival heroes - win it and you unlock the next zone, plus take their bounty in XP and gold. Every other hero on the map is doing the same thing in the background, and once a hero clears their own zone they'll go hunt for a new one to invade. Check the map after a battle for news of anyone who's fallen, and use the World Status screen (next to the Shop) to see the state of the entire world at a glance.

If your HP reaches zero, your run ends and your best XP is saved as a high score before you're returned to the main menu.

---

## Tech Stack

- **Engine:** [Godot 4](https://godotengine.org/) (GDScript)
- **Persistence:** Local per-player save files under `user://players/`

## Project Structure

```
res://
├── scenes/
│   ├── Map.tscn            # World map, zone navigation, World Status/Shop entry points
│   ├── Shop.tscn           # Item shop
│   ├── WorldStatus.tscn    # Full zone/hero status overview
│   └── ...                 # Battle, hero-select, login, etc.
├── scripts/
│   ├── GameManager.gd      # Zone/hero/enemy static data, XP & skill tables, stage/hero-fight logic
│   ├── PlayerManager.gd    # Player + NPC hero state, save/load, event queue
│   ├── EnemyHeroManager.gd # Rival hero simulation: leveling, shopping, combat, invasion AI
│   ├── Map.gd
│   ├── Shop.gd
│   ├── WorldStatus.gd
│   └── battle.gd           # Player battle flow
└── assets/                 # Sprites, portraits, zone backgrounds, music
```

## Running the Project

1. Install [Godot 4.x](https://godotengine.org/download).
2. Clone this repository.
3. Open the project folder in Godot (`project.godot`).
4. Press **Run** (F5).

## Contributing

Issues and pull requests are welcome. If you're adding a new hero, zone, or system, please keep gameplay-affecting balance changes (XP tables, item costs, bounty formulas) called out clearly in your PR description.

## License

[MIT](LICENSE) - update this section if you're using a different license.
