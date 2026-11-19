# Light Up the Block - porch decorating prototype

Rojo project. The place is built at runtime (no .rbxl committed).

## Open in Studio
1. Install Rojo 7.4.x (CLI + Studio plugin).
2. `cd light-up-the-block && rojo serve`
3. Studio: new Baseplate place, Plugins > Rojo > Connect.
4. Test with Play (F5), or Test > Clients and Servers > 2 Players.
Offline alternative: `rojo build -o LightUpTheBlock.rbxl`, then open the file.

## Controls
Tap/click a glowing point, then a second point. Confirm (E), Cancel (X), Color (C), Undo (Z).

## Unit tests
`luau tests/StrandMath.spec.luau`
