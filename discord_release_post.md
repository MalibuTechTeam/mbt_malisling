# mbt_malisling 2.1.0 — Draw Style

**Pick your draw animation by watching it play on your own character.**

**New**
• **Live Picker** — Placement → Draw Style. The panel hides, a camera frames your ped, every holster animation plays on demand. Keep one per slot, per direction.
• **Clip + duration saved together** — slots were playing a fragment of a longer animation (19% for the pistol, 28% for the rifle). Now measured and stored, so it plays whole.
• **Per-job draw styles** — gesture only, never timing. No job draws faster than another.
• **Placed second-rifle position**, tuned separately for male and female.
• `/mbt_animaudit` (debug) — which animations exist on your build, how long each runs, which slots are cutting theirs short.

**Fixed**
• Drawing one of two slung weapons took **both** off the body.
• Drawing while the prop wasn't showing (spawning, concealed, hidden by job) recorded nothing — putting it away never brought it back.
• `ox_inventory` patch didn't update when it changed; the marker is now a hash of the patch itself.
• `Hidden by Job` showed no jobs on some servers.
• A style removed from `default.lua` could make the config permanently unsavable.

**Changed**
• Draw Style moved to the **Placement** page, with the other in-world editors.
• `Hidden by Job` no longer leads with a destructive red button.

**Upgrading**
• Drop the folder in and **restart the server** — the ox_inventory patch changed and ox must recompile it. All settings kept.
• ⚠️ Not tested this release: the **qb-inventory** path. Shared code with ox, verified there.
