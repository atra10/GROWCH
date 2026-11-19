# The Terrible Knight

A short (about 15-20 minutes) 2D action platformer for **Godot 4.3+**, made with the free
*Legacy Collection* pixel art by Luis Zuno (Ansimuz), CC0.

**Story.** A cursed werewolf becomes the Terrible Knight under the full moon, but only for
a few moments at a time. A vision of the princess guides him through four stages, each
guarded by a boss:

| Stage | Place | Boss |
|---|---|---|
| 1 | The Haunted Forest | Hell Beast |
| 2 | The Night Town | Nightmare |
| 3 | The Burning Caverns | Dragon |
| 4 | The Graveyard Mist | Death |
| Final | The Black Castle | The princess... who becomes the Demon |

## Running it on Android (Godot Android editor)

1. Copy the whole `terrible-knight` folder (or unzip `terrible-knight.zip`) to your phone,
   for example to `Documents/terrible-knight`.
2. Open the Godot editor app, tap **Import**, and pick the `project.godot` file in that folder.
3. Wait for the first import to finish, then press **Run** (the play button, top right).

The game is landscape. On-screen buttons: left/right arrows move, the blue chevron button jumps,
the red button attacks, and the moon button (above jump) transforms / throws daggers.
Tap anywhere to advance dialogue.
On a PC: arrows or A/D move, Space jumps, J or X attacks, L or C is the moon button, Esc or P pauses.
The pause button (top-right) or the Android Back button opens the pause menu: Resume, Restart from checkpoint, Quit to title. The game also pauses when you switch apps.

## Wolf and Knight

You play as the **werewolf** most of the time:
faster, jumps higher, attacks with a short lunge + claw slash (1 damage).

Every enemy you kill (and every hit on a boss) fills the **moon meter** under your hearts.
When it says **FULL MOON!**, tap the moon button to become the **Terrible Knight for 30 seconds**:

- sword slash: 2 damage, longer reach
- the moon button now throws **daggers**
- armour: every hit only costs half a heart

When the 30 seconds run out you turn back into the wolf and the meter starts filling again.
The meter carries over between stages, so you can save a full moon for a boss.

## Controls and rules

- 4 hearts (each heart is 2 hits). Red hearts heal.
- Falling into a pit costs one heart and puts you back on the ledge.
- If you die you restart at the last checkpoint. Bosses always have a checkpoint right before them.
- Dialogue you have already seen is skipped when you retry.

## Project layout

```
project.godot          settings (384x216 pixel view, stretches to any screen)
scenes/main.tscn       the only scene; everything else is built in code
scripts/game.gd        autoload: story text, stage list, animation table, scene flow
scripts/level.gd       builds a stage from its map, camera, checkpoints, visions, boss arena
scripts/player.gd      the hero: werewolf and Terrible Knight forms
scripts/dagger.gd      the knight's thrown dagger
scripts/enemy.gd       hound, ogre, crow, flying eye, ghost, fire skull
scripts/boss.gd        Hell Beast, Nightmare, Dragon, Death, Demon
scripts/maps.gd        the level layouts (one text row per 16 px)
scripts/cutscene.gd    intro (wolf -> knight) and ending
scripts/hud.gd         hearts, boss bar, touch buttons
scripts/dialogue.gd    princess dialogue box
tools/                 Python scripts that rebuilt the art and maps (not needed to play)
```

## Easy things to change

- **Story text:** all dialogue is in `scripts/game.gd` (`STAGES`, `INTRO_LINES_*`, `ENDING_LINES`).
- **Levels:** edit `scripts/maps.gd` directly. `#` ground, `-` thin platform, `P` start,
  `k` checkpoint, `v` princess vision, `h` hound, `o` ogre, `c` crow, `e` eye, `g` ghost,
  `s` fire skull, `+` heart, `A` boss arena starts here, `X` boss.
  Or edit `tools/build_maps.py` and run `python3 tools/build_maps.py scripts/maps.gd`.
- **Moon:** `MOON_PER_KILL`, `MOON_PER_BOSS_HIT` and `KNIGHT_TIME` in `game.gd`.
- **Wolf / knight stats:** `FORMS` at the top of `player.gd`.
- **Difficulty:** `MAX_HP` in `game.gd`, `max_hp` per boss in `boss.gd`, `hp` per enemy in `enemy.gd`.

There is no sound yet: the art pack doesn't include any.

## Debug options (PC only)

Run from a terminal: `godot --path . -- --stage=2 --god --autoplay`
(`--stage=N` 0-4 jumps to a stage, 5 = ending, -1 = intro; `--cp=X` start at x position;
`--god` no damage; `--autoplay` a simple bot plays.)

## Credits

Art: Legacy Collection by Luis Zuno (@ansimuz), CC0 public domain.
