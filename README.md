# Cozy Cafe — addon mod for Fabric 1.20.1

This is a SOURCE PROJECT, not a finished jar. You need to compile it
once on your own machine (one terminal command, see below) to get a
`.jar` you can drop into your modpack's `mods` folder.

## 1. One-time setup (only needed once, ever)

1. Install **Java 17** (e.g. Adoptium Temurin 17): https://adoptium.net/
2. Install **IntelliJ IDEA Community Edition** (free): https://www.jetbrains.com/idea/download/
   (VS Code with the "Extension Pack for Java" works too, IntelliJ is just the most common choice for Fabric modding.)
3. You do NOT need to install Gradle separately — this project includes
   a Gradle wrapper that downloads the correct Gradle version
   automatically the first time you build.

## 2. Building the jar

1. Unzip this project anywhere on your computer.
2. Open the folder in IntelliJ ("Open" -> select the `cozy-cafe` folder).
   IntelliJ will detect it's a Gradle project and start downloading
   dependencies automatically (Fabric Loader, Fabric API, Minecraft
   1.20.1 libraries and mappings). This first step takes a few minutes
   and needs an internet connection.
3. Once it's done importing, open a terminal in IntelliJ (or any
   terminal, `cd`'d into the `cozy-cafe` folder) and run:

   - Windows: `gradlew.bat build`
   - Mac/Linux: `./gradlew build`

4. When it finishes, your jar is at:
   `build/libs/cozy-cafe-0.1.0.jar`

5. Copy that file into your modpack's `mods` folder, alongside Easy NPC.

If step 3 fails with errors, paste me the error output and I'll help
you fix it — that's normal for a first build and almost always a
version-mismatch or missing-file issue, not something wrong with you.

## 3. What this mod does (matches what we discussed)

- `/shop open` / `/shop close` — toggles customer admission
- `/setshopentrance` — sets the waiting spot (run while standing on the block)
- `/setmenu add <item_id> <Display Name>` — e.g. `/setmenu add minecraft:mushroom_stew Mushroom Soup`
  works with any item from any installed mod
- `/setmenu remove <item_id>`, `/setmenu clear`, `/setmenu list`
- `/cozycafe setseat <npc-uuid>` then **Shift+Right-Click any block** —
  assigns that block as the customer's chair. Works with vanilla blocks
  or any chair mod's blocks, since it doesn't rely on the chair mod at
  all — see "How sitting works" below.
- Random coin reward from Coins JE (copper/iron/gold/diamond/netherite,
  one picked at random) per completed order, as you asked.

## 4. How sitting works (no chair mod cooperation needed)

When a chair is assigned, the mod spawns its own invisible, harmless
"seat" entity at that exact spot and mounts the customer NPC onto it
(the same general mechanic vanilla uses for boats/saddles). This means
ANY block works as a chair — vanilla stairs, a chair mod's chair,
anything — because we never touch that block mod's code.

## 5. What you still need to do before this fully works — IMPORTANT

I built this against Easy NPC's *publicly documented* command syntax,
but I could not run or test it against your actual installed jar from
my side (no access to download/run Minecraft + Easy NPC here). Three
things to check/adjust, all isolated in
`src/main/java/com/cozycafe/mod/npc/NpcAdapter.java`:

1. **Trade configuration command** (`configureTrade`) — confirm the
   exact `/easy_npc trading set ...` syntax for reconfiguring a trade
   slot at runtime on your version (6.24.0). Test it manually in-game
   as an op first.
2. **Sitting pose command** (`applySitPose`) — build a "sitting" pose
   once using Easy NPC's in-game pose editor (bend the legs etc.),
   note what command/preset name it saves under, and put that name
   into `applySitPose()`.
3. **Dialogs** — create two named dialogs per customer NPC preset in
   Easy NPC's config UI: one for taking the order (`order`) and one
   for the thank-you (`thank_you`), matching the names used in
   `NpcAdapter.openOrderDialog` / `openThankYouDialog`. Add a dialog
   BUTTON action of type "Command" to your party-size dialog that runs:

   ```
   /cozycafe npc_event party_size <npc-uuid> <initiator-uuid> 1
   ```

   (one button per party size: 1, 2, 3 — change the trailing number)

4. **Trade-completion hook** — find whichever Easy NPC action/event
   fires when a trade is accepted (likely an action type tied to the
   trading screen, or an `on_trade` style event if their version has
   one) and configure it to run:

   ```
   /cozycafe npc_event trade_completed <npc-uuid>
   ```

   This is the one piece I'd flag as "go test this first" — if Easy
   NPC's version doesn't expose a trade-completion hook cleanly, the
   fallback is building a small custom `ScreenHandler` trade GUI of our
   own instead of using theirs, which I can build next once you
   confirm which way you need to go.

None of this requires touching any other file — it's all isolated in
`NpcAdapter.java` and the dialog/action setup inside Easy NPC's own UI.

## 6. Known gaps / next steps (didn't block delivery, but worth knowing)

- Orders are always exactly 1 of 1 menu item for now, matching "NPC
  requests exactly one item." If you want some customers to order
  *multiples* of the same dish (the "I'll have 3 Apple Pies" case the
  trading rules anticipate), that's a 2-line change in
  `CustomerSession.startOrdering` — happy to add it once the rest is
  confirmed working.
- `giveItemToPlayerWhoTraded` currently just logs — it needs the actual
  player UUID, which depends on how step 4 above is wired (Easy NPC's
  trade event should tell you which player opened the trade).
- Multi-dimension support (entrance/chairs across different worlds) is
  not handled — everything assumes the overworld for simplicity, matching a single-shop setup.
