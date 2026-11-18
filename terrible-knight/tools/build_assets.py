"""Builds the game's sprite strips and backgrounds from the Legacy Collection pack.
Usage: python3 build_assets.py "<path to Legacy Collection/Assets>" <game dir>
Every animation becomes one horizontal strip PNG (frames side by side, equal size).
"""
import sys, os, re, glob
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
C = SRC + "/Gothicvania/Characters/"
E = SRC + "/Gothicvania/Environments/"
X = SRC + "/Explosions and Magic/"

def nat(s):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", s)]

def strip(name, pattern, canvas=None, offset=(0, 0)):
    files = sorted(glob.glob(pattern), key=nat)
    assert files, pattern
    ims = [Image.open(f).convert("RGBA") for f in files]
    w, h = canvas or ims[0].size
    out = Image.new("RGBA", (w * len(ims), h), (0, 0, 0, 0))
    for i, im in enumerate(ims):
        out.alpha_composite(im, (i * w + offset[0], offset[1]))
    path = f"{OUT}/assets/sprites/{name}.png"
    out.save(path)
    print(f"{name}: {len(ims)} x {w}x{h}")

def copy(name, path, crop=None, sub="bg"):
    im = Image.open(path).convert("RGBA")
    if crop:
        im = im.crop(crop)
    im.save(f"{OUT}/assets/{sub}/{name}.png")

def sheet(name, path):
    copy(name, path, sub="sprites")

os.makedirs(OUT + "/assets/sprites", exist_ok=True)
os.makedirs(OUT + "/assets/bg", exist_ok=True)
os.makedirs(OUT + "/assets/tiles", exist_ok=True)

K = C + "Terrible Knight/Sprites/"
strip("knight_idle", K + "Idle/*.png")
strip("knight_run", K + "Run/*.png")
strip("knight_jump", K + "Jump/*.png")
strip("knight_slash", K + "SwordSlash/*.png")
strip("knight_airslash", K + "AirSwordSlash/*.png")
strip("knight_hurt", K + "Hurt/*.png")
W = C + "WereWolf/Sprites/"
strip("wolf_idle", W + "Idle/*.png")
strip("wolf_run", W + "run/*.png")
strip("wolf_jump", W + "jump/*.png")
strip("wolf_fall", W + "fall/*.png")
sheet("dagger", C + "Terrible Knight/Projectiles/dagger.png")
H = C + "Bridge Heroine/Heroine base/Sprites/"
strip("heroine_idle", H + "idle/*.png")
strip("heroine_run", H + "run/*.png")
B = C + "Hell-Beast-Files/"
strip("hellbeast_idle", B + "Idle/Sprites/*.png")
strip("hellbeast_breath", B + "Breath/Sprites/*.png")
strip("hellbeast_burn", B + "Burn/Sprites/*.png")
strip("hellbeast_fireball", B + "Fireball/Sprites/*.png")
strip("nightmare_idle", C + "Nightmare-Files/Sprites/Idle/*.png")
strip("nightmare_run", C + "Nightmare-Files/Sprites/Run/*.png")
D = C + "Grotto-escape-2-boss-dragon/sprites/"
strip("dragon_idle", D + "idle/*.png")
strip("dragon_breath", D + "breath/*.png")
strip("dragon_tail", D + "tail/*.png")
strip("death_walk", C + "death/Sprites/walk/*.png")
strip("death_rise", C + "death/Sprites/rise/*.png")
M = C + "demon-Files/Sprites/"
# idle frames are 256x176; pad them into the 312x220 attack canvas so the body lines up
strip("demon_idle", M + "Idle/*.png", canvas=(312, 220), offset=(56, 44))
strip("demon_attack", M + "DemonAttack/*.png")
strip("demon_breath", M + "DemonAttackBreath/*.png")
strip("hound_run", C + "Hell-Hound-Files/Sprites/Run/*.png")
strip("hound_idle", C + "Hell-Hound-Files/Sprites/Idle/*.png")
strip("ghost_chase", C + "Ghost-Files/Sprites/Chase/*.png")
strip("ghost_appear", C + "Ghost-Files/Sprites/Appear/*.png")
strip("spirit", C + "enemy-ghost/Sprites/Particles/*.png")
strip("skull", C + "Fire-Skull-Files/Sprites/Fire/*.png")
strip("crow_fly", C + "crow/Sprites/fly/*.png")
strip("eye_fly", C + "flying-eye-demon/Sprites/*.png")
sheet("ogre_walk", C + "Ogre/Spritesheets/ogre-walk.png")
sheet("ogre_attack", C + "Ogre/Spritesheets/ogre-attack.png")
strip("fx_death", X + "EnemyDeath/Sprites/*.png")
strip("fx_hit", C + "Terrible Knight/Projectiles/Hit/Sprites/*.png")
strip("fx_fireball", X + "Grotto-escape-2-FX/sprites/fire-ball/*.png")
strip("fx_claw", X + "Grotto-escape-2-FX/sprites/slash-horizontal/*.png")
strip("fx_transform", X + "Grotto-escape-2-FX/sprites/slash-circular/*.png")

# Backgrounds (parallax layers, far -> near)
copy("forest_back", E + "HauntedForest/Layers/back.png")
copy("forest_middle", E + "HauntedForest/Layers/middle.png")
NT = E + "night-town-background-files/layers/night-town-background-"
for n in ["sky", "mountains", "clouds", "far-buildings", "town"]:
    copy("town_" + n.replace("-", "_"), NT + n + ".png")
copy("lava_back", E + "lava-background/PNG/background.png")
copy("lava_rocks", E + "lava-background/PNG/middle-rocks.png")
copy("cave_back", E + "caverns-files-web/layers/background.png")
copy("cave_walls", E + "caverns-files-web/layers/back-walls.png")
copy("horror_clouds", E + "Gothic-Horror-Files/PNG/layers/clouds.png")
copy("horror_town", E + "Gothic-Horror-Files/PNG/layers/town.png")
copy("castle_back", E + "Old-dark-Castle-tileset-Files/PNG/old-dark-castle-interior-background.png")
MD = E + "Mountain Dusk/version A/Layers/"
for n in ["sky", "far-mountains", "mountains", "trees"]:
    copy("dusk_" + n.replace("-", "_"), MD + n + ".png")

# Ground strips (tile horizontally)
copy("forest", E + "HauntedForest/Layers/tileset.png", (416, 50, 448, 98), "tiles")
copy("town", E + "Gothic-Castle-Files/PNG/layers/gothic-castle-tileset.png", (32, 32, 64, 64), "tiles")
copy("cave", E + "caverns-files-web/layers/tiles.png", (20, 238, 52, 270), "tiles")
copy("mist", E + "mist-forest-background/layers/mist-forest-background-tiles.png", (80, 26, 112, 64), "tiles")
