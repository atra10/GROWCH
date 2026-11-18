"""Generates scripts/maps.gd from simple segment descriptions.
Legend:  # solid   - one-way platform   P start   k checkpoint   v princess vision
         h hound   o ogre   c crow   e flying eye   g ghost   s fire skull   + heart
         A boss-arena left edge   X boss spawn
You can also edit scripts/maps.gd by hand: every string is one row (16 px tall)."""
import sys
ROWS = 14
GROUND = 11

class Map:
    def __init__(self):
        self.cols = []
    @property
    def x(self):
        return len(self.cols)
    def ground(self, n, top=GROUND):
        for _ in range(n):
            self.cols.append(["."] * top + ["#"] * (ROWS - top))
        return self
    def gap(self, n):
        for _ in range(n):
            self.cols.append(["."] * ROWS)
        return self
    def put(self, dx, row, ch, at=None):
        col = (self.x if at is None else at) + dx
        self.cols[col][row] = ch
        return self
    def plat(self, col, row, length):
        for i in range(length):
            self.cols[col + i][row] = "-"
        return self
    def top(self, col):
        for r in range(ROWS):
            if self.cols[col][r] == "#":
                return r
        return ROWS
    def mob(self, col, ch, row=None):
        """Place an entity at column col; walkers stand on the ground."""
        if row is None:
            row = self.top(col) - 1
        self.cols[col][row] = ch
        return self
    def arena(self, width=30, boss_col=22):
        a = self.x
        self.ground(width)
        self.mob(a, "A")
        self.mob(a + boss_col, "X")
        for r in range(ROWS):  # right wall
            self.cols[-1][r] = "#"
        return self
    def rows(self):
        return ["".join(c[r] for c in self.cols) for r in range(ROWS)]

def extra(m, a, b, flyer):
    """A longer mixed section: steps, a pit with a platform, and a few enemies."""
    s = m.x; m.ground(10); m.mob(s + 5, a)
    m.gap(4); m.plat(m.x - 3, 8, 2)
    s = m.x; m.ground(5, 9); m.ground(6, 8); m.ground(5, 9); m.mob(s + 8, b); m.mob(s + 6, flyer, 4)
    s = m.x; m.ground(12); m.mob(s + 4, flyer, 6); m.mob(s + 9, a)

def stage1():
    m = Map()
    m.ground(14); m.mob(3, "P"); m.mob(8, "v")
    s = m.x; m.ground(12); m.mob(s + 9, "h")
    m.gap(3)
    s = m.x; m.ground(10, 10); m.mob(s + 6, "h")
    s = m.x; m.ground(8); m.mob(s + 4, "c", 6)
    m.gap(4); m.plat(m.x - 3, 8, 2)
    s = m.x; m.ground(16); m.mob(s + 5, "h"); m.mob(s + 12, "h"); m.mob(s + 10, "c", 5)
    s = m.x; m.ground(6, 9); m.ground(6, 7); m.mob(s + 9, "+")
    m.ground(6, 9)
    s = m.x; m.ground(10); m.mob(s + 3, "k"); m.mob(s + 6, "v")
    m.gap(4); m.plat(m.x - 4, 8, 3)
    s = m.x; m.ground(14); m.mob(s + 4, "h"); m.mob(s + 8, "c", 5); m.mob(s + 11, "h")
    m.gap(3)
    s = m.x; m.ground(6, 10); m.gap(3); m.ground(6, 9); m.mob(s + 12, "c", 4)
    m.gap(3)
    extra(m, "h", "h", "c")
    s = m.x; m.ground(20); m.mob(s + 4, "h"); m.mob(s + 9, "h"); m.mob(s + 13, "h"); m.mob(s + 7, "c", 5); m.mob(s + 16, "+")
    s = m.x; m.ground(8); m.mob(s + 3, "k")
    m.arena()
    return m

def stage2():
    m = Map()
    m.ground(14); m.mob(3, "P"); m.mob(8, "v")
    s = m.x; m.ground(14); m.mob(s + 6, "g", 7); m.mob(s + 11, "h")
    s = m.x; m.ground(5, 9); m.ground(5, 7); m.ground(5, 9)
    m.plat(m.x - 12, 4, 4); m.mob(m.x - 11, "+", 3)
    s = m.x; m.ground(12); m.mob(s + 5, "e", 5); m.mob(s + 9, "g", 7)
    m.gap(4); m.plat(m.x - 3, 8, 2)
    s = m.x; m.ground(12); m.mob(s + 3, "k"); m.mob(s + 7, "v")
    s = m.x; m.ground(16); m.mob(s + 3, "h"); m.mob(s + 7, "g", 6); m.mob(s + 10, "h"); m.mob(s + 13, "e", 4)
    m.gap(3)
    s = m.x; m.ground(4, 10); m.gap(3); m.ground(4, 9); m.gap(3); m.ground(4, 8)
    m.mob(m.x - 2, "e", 3)
    extra(m, "h", "g", "e")
    s = m.x; m.ground(16, 8); m.mob(s + 4, "g", 4); m.mob(s + 9, "h"); m.mob(s + 13, "+")
    s = m.x; m.ground(4, 9); m.ground(4, 10)
    s = m.x; m.ground(18); m.mob(s + 3, "e", 5); m.mob(s + 6, "g", 7); m.mob(s + 10, "h"); m.mob(s + 14, "g", 6)
    s = m.x; m.ground(8); m.mob(s + 3, "k")
    m.arena()
    return m

def stage3():
    m = Map()
    m.ground(14); m.mob(3, "P"); m.mob(8, "v")
    s = m.x; m.ground(14); m.mob(s + 7, "s", 6)
    m.gap(4); m.plat(m.x - 3, 8, 2)
    s = m.x; m.ground(12, 10); m.mob(s + 6, "h")
    m.gap(3)
    s = m.x; m.ground(14); m.mob(s + 3, "k"); m.mob(s + 6, "v"); m.mob(s + 11, "o")
    s = m.x; m.ground(6, 9); m.gap(4); m.plat(m.x - 3, 7, 2); m.ground(6, 9); m.mob(s + 4, "s", 4)
    s = m.x; m.ground(16); m.mob(s + 5, "o"); m.mob(s + 9, "s", 5); m.mob(s + 13, "+")
    m.gap(3)
    s = m.x; m.ground(4, 10); m.gap(2); m.ground(4, 8); m.gap(2); m.ground(4, 10)
    s = m.x; m.ground(18); m.mob(s + 4, "h"); m.mob(s + 8, "s", 4); m.mob(s + 12, "o"); m.mob(s + 15, "s", 6)
    extra(m, "o", "h", "s")
    s = m.x; m.ground(10, 9); m.mob(s + 5, "+")
    s = m.x; m.ground(8); m.mob(s + 3, "k")
    m.arena()
    return m

def stage4():
    m = Map()
    m.ground(14); m.mob(3, "P"); m.mob(8, "v")
    s = m.x; m.ground(14); m.mob(s + 5, "g", 7); m.mob(s + 10, "o")
    m.gap(4); m.plat(m.x - 3, 8, 2)
    s = m.x; m.ground(10, 10); m.mob(s + 5, "e", 5)
    m.gap(3)
    s = m.x; m.ground(14); m.mob(s + 3, "k"); m.mob(s + 6, "v"); m.mob(s + 10, "g", 6); m.mob(s + 12, "h")
    s = m.x; m.ground(5, 9); m.ground(5, 7); m.mob(s + 7, "s", 3); m.ground(5, 9)
    m.gap(4); m.plat(m.x - 4, 8, 3)
    s = m.x; m.ground(18); m.mob(s + 4, "o"); m.mob(s + 8, "g", 6); m.mob(s + 12, "h"); m.mob(s + 15, "e", 4); m.mob(s + 16, "+")
    m.gap(3)
    s = m.x; m.ground(4, 10); m.gap(3); m.ground(4, 9); m.gap(3); m.ground(6, 10); m.mob(s + 16, "g", 5)
    extra(m, "h", "o", "g")
    s = m.x; m.ground(16); m.mob(s + 4, "s", 5); m.mob(s + 8, "o"); m.mob(s + 12, "g", 6)
    s = m.x; m.ground(8); m.mob(s + 3, "k"); m.mob(s + 5, "+")
    m.arena()
    return m

def final():
    m = Map()
    m.ground(14); m.mob(3, "P"); m.mob(9, "v")
    s = m.x; m.ground(14); m.mob(s + 6, "g", 7); m.mob(s + 11, "s", 5)
    s = m.x; m.ground(5, 9); m.ground(5, 7); m.ground(5, 9); m.mob(s + 7, "+")
    s = m.x; m.ground(12); m.mob(s + 6, "k")
    m.arena(width=32, boss_col=22)
    return m

out = ["# Generated by tools/build_maps.py - one string per 16px row.", "extends RefCounted", ""]
for name, fn in [("STAGE1", stage1), ("STAGE2", stage2), ("STAGE3", stage3), ("STAGE4", stage4), ("FINAL", final)]:
    rows = fn().rows()
    out.append(f"const {name} := [")
    out += [f'\t"{r}",' for r in rows]
    out.append("]")
    out.append("")
    print(name, len(rows[0]), "columns")
out.append("const ALL := {" + ", ".join(f'"{n}": {n}' for n in ["STAGE1", "STAGE2", "STAGE3", "STAGE4", "FINAL"]) + "}")
out.append("")
open(sys.argv[1], "w").write("\n".join(out))
