# Dungeon test leak baseline

On Godot 4.7.2 headless, `tests/dungeon_overhaul.gd` passes at foundation
commit 199ac7d but reports one dummy material, shader, mesh, texture and
render instance, five ObjectDB instances and one resource still in use at
exit. The same warnings appeared with the preliminary site-manager changes.
Their underlying ownership has not been established. They are not evidence
of a regression introduced by those changes.
