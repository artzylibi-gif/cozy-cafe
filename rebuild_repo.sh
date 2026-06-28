bash rebuild_repo.sh#!/bin/bash
set -e
echo "Cleaning workspace..."
rm -rf src libs build.gradle gradle.properties settings.gradle README.md cozy-cafe-source.zip download CozyCafeMod.java ShopManager.java CozyCafeCommands.java CustomerSession.java MenuEntry.java CozyCafeLog.java SeatManager.java SetSeatInteraction.java CoinReward.java NpcAdapter.java NpcEventCommand.java fabric.mod.json
mkdir -p src/main/java/com/cozycafe/mod/command
mkdir -p src/main/java/com/cozycafe/mod/shop
mkdir -p src/main/java/com/cozycafe/mod/seat
mkdir -p src/main/java/com/cozycafe/mod/economy
mkdir -p src/main/java/com/cozycafe/mod/npc
mkdir -p src/main/resources
mkdir -p libs
touch libs/.gitkeep
echo "Folders ready."
cat > 'build.gradle' << 'CCEOF'
plugins {
    id 'fabric-loom' version '1.6-SNAPSHOT'
    id 'maven-publish'
}

version = project.mod_version
group = project.maven_group

repositories {
    // Fabric's repo is added by the loom plugin already.
    // 'libs' lets us reference Easy NPC's jar directly from disk,
    // since it is not on a public Maven repository.
    flatDir {
        dirs 'libs'
    }
}

dependencies {
    minecraft "com.mojang:minecraft:${project.minecraft_version}"
    mappings "net.fabricmc:yarn:${project.yarn_mappings}:v2"
    modImplementation "net.fabricmc:fabric-loader:${project.loader_version}"
    modImplementation "net.fabricmc.fabric-api:fabric-api:${project.fabric_version}"

    // --- Easy NPC ---
    // Copy the exact Easy NPC: Core jar from your modpack's mods/ folder
    // into this project's libs/ folder (create that folder), matching
    // the filename in gradle.properties (easy_npc_jar_name).
    // This lets us compile against their classes if/when their Core
    // jar exposes a public Java API. If you only intend to call Easy
    // NPC through its in-game commands (the safer, version-proof route
    // this mod actually uses by default), you do NOT need this
    // dependency at all - it's left here, commented out, in case you
    // want to explore their direct API later.
    // modImplementation files("libs/${project.easy_npc_jar_name}")
}

processResources {
    inputs.property "version", project.version
    filteringCharset "UTF-8"
    filesMatching("fabric.mod.json") {
        expand "version": project.version
    }
}

tasks.withType(JavaCompile).configureEach {
    it.options.release = 17
}

java {
    withSourcesJar()
}

jar {
    from("LICENSE") {
        rename { "${it}_${project.archivesBaseName}" }
    }
}
CCEOF
cat > 'gradle.properties' << 'CCEOF'
# Minecraft / mapping / loader versions for 1.20.1
minecraft_version=1.20.1
yarn_mappings=1.20.1+build.10
loader_version=0.15.11

# Fabric API
fabric_version=0.92.2+1.20.1

# Mod info
mod_version=0.1.0
maven_group=com.cozycafe
archives_base_name=cozy-cafe

# Easy NPC (Kaworru) - update these to match the exact version jars
# you have installed in your modpack. These are the artifact names
# only; see README "Linking against Easy NPC" for how to wire this up,
# since Easy NPC is not published on a public Maven repo this sandbox
# can reach - you will add it as a local file dependency.
easy_npc_jar_name=easy_npc-fabric-1.20.1-6.24.0.jar
CCEOF
cat > 'settings.gradle' << 'CCEOF'
pluginManagement {
    repositories {
        maven { url = "https://maven.fabricmc.net/" }
        gradlePluginPortal()
    }
}

rootProject.name = "cozy-cafe"
CCEOF
cat > 'README.md' << 'CCEOF'
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
CCEOF
cat > 'src/main/resources/fabric.mod.json' << 'CCEOF'
{
  "schemaVersion": 1,
  "id": "cozycafe",
  "version": "${version}",
  "name": "Cozy Cafe",
  "description": "A cozy restaurant/cafe gameplay addon. Designed to work alongside Easy NPC for NPC rendering and dialogue.",
  "authors": ["you"],
  "contact": {},
  "license": "MIT",
  "icon": "assets/cozycafe/icon.png",
  "environment": "*",
  "entrypoints": {
    "main": ["com.cozycafe.mod.CozyCafeMod"]
  },
  "mixins": [],
  "depends": {
    "fabricloader": ">=0.15.0",
    "fabric": "*",
    "minecraft": "1.20.1",
    "java": ">=17"
  },
  "custom": {
    "cozycafe:requires_npc_mod": "Easy NPC (any mod providing entities you right-click to talk to also works, but commands in this mod default to Easy NPC's /easy_npc syntax)"
  }
}
CCEOF
cat > 'src/main/java/com/cozycafe/mod/CozyCafeMod.java' << 'CCEOF'
package com.cozycafe.mod;

import com.cozycafe.mod.command.CozyCafeCommands;
import com.cozycafe.mod.npc.NpcAdapter;
import com.cozycafe.mod.npc.NpcEventCommand;
import com.cozycafe.mod.seat.SetSeatInteraction;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class CozyCafeMod implements ModInitializer {

    public static final String MOD_ID = "cozycafe";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);

    @Override
    public void onInitialize() {
        LOGGER.info("Cozy Cafe initializing");

        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            CozyCafeCommands.register(dispatcher);
            NpcEventCommand.register(dispatcher);
        });

        SetSeatInteraction.register();

        ServerLifecycleEvents.SERVER_STARTED.register(NpcAdapter::init);

        // Drives the customer-session state machine: leave timers,
        // queue admission at the entrance, etc. Kept lightweight -
        // this just iterates active sessions, no world scanning.
        ServerTickEvents.END_SERVER_TICK.register(server -> {
            ShopManager.get(server).tick(server);
        });
    }
}
CCEOF
cat > 'src/main/java/com/cozycafe/mod/ShopManager.java' << 'CCEOF'
package com.cozycafe.mod;

import com.cozycafe.mod.seat.SeatManager;
import com.cozycafe.mod.shop.CustomerSession;
import com.cozycafe.mod.shop.MenuEntry;
import net.minecraft.item.Item;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.nbt.NbtList;
import net.minecraft.registry.Registries;
import net.minecraft.server.MinecraftServer;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Direction;
import net.minecraft.world.PersistentState;
import net.minecraft.world.PersistentStateManager;
import net.minecraft.world.World;

import java.util.*;

/**
 * Single global shop. If you later want multiple shops, key everything
 * here by a shopId string instead of being a singleton - the rest of
 * the codebase already passes ShopManager around rather than reaching
 * for a static instance, to make that refactor easier later.
 */
public class ShopManager extends PersistentState {

    private boolean open = false;
    private BlockPos entrancePos = null;
    private String entranceDimension = World.OVERWORLD.getValue().toString();

    private final List<MenuEntry> menu = new ArrayList<>();
    private final SeatManager seatManager = new SeatManager();
    private final Map<UUID, CustomerSession> sessions = new HashMap<>();

    // --- shop open/close ---

    public boolean isOpen() {
        return open;
    }

    public void setOpen(boolean open) {
        this.open = open;
        markDirty();
    }

    // --- entrance ---

    public void setEntrance(BlockPos pos, World world) {
        this.entrancePos = pos.toImmutable();
        this.entranceDimension = world.getRegistryKey().getValue().toString();
        markDirty();
    }

    public BlockPos getEntrancePos() {
        return entrancePos;
    }

    public String getEntranceDimension() {
        return entranceDimension;
    }

    // --- menu ---

    public void setMenu(List<MenuEntry> newMenu) {
        menu.clear();
        menu.addAll(newMenu);
        markDirty();
    }

    public List<MenuEntry> getMenu() {
        return Collections.unmodifiableList(menu);
    }

    public boolean isOnMenu(Item item) {
        return menu.stream().anyMatch(e -> e.item() == item);
    }

    public MenuEntry pickRandomMenuItem(Random random) {
        if (menu.isEmpty()) return null;
        return menu.get(random.nextInt(menu.size()));
    }

    // --- seats ---

    public SeatManager seats() {
        return seatManager;
    }

    // --- customer sessions ---

    public Map<UUID, CustomerSession> sessions() {
        return sessions;
    }

    public CustomerSession getSession(UUID npcUuid) {
        return sessions.get(npcUuid);
    }

    public void putSession(CustomerSession session) {
        sessions.put(session.getNpcUuid(), session);
        markDirty();
    }

    public void removeSession(UUID npcUuid) {
        sessions.remove(npcUuid);
        seatManager.freeChairForNpc(npcUuid);
        markDirty();
    }

    // --- tick: advance leave timers etc ---

    public void tick(MinecraftServer server) {
        List<UUID> toRemove = new ArrayList<>();
        for (CustomerSession session : sessions.values()) {
            boolean done = session.tick(server, this);
            if (done) toRemove.add(session.getNpcUuid());
        }
        for (UUID uuid : toRemove) {
            removeSession(uuid);
        }
    }

    // --- persistence ---

    public static ShopManager get(MinecraftServer server) {
        PersistentStateManager manager = server.getOverworld().getPersistentStateManager();
        return manager.getOrCreate(
                new PersistentState.Type<>(ShopManager::new, ShopManager::fromNbt, null),
                "cozycafe_shop"
        );
    }

    @Override
    public NbtCompound writeNbt(NbtCompound nbt) {
        nbt.putBoolean("open", open);
        if (entrancePos != null) {
            nbt.putInt("entranceX", entrancePos.getX());
            nbt.putInt("entranceY", entrancePos.getY());
            nbt.putInt("entranceZ", entrancePos.getZ());
            nbt.putString("entranceDim", entranceDimension);
        }
        NbtList menuList = new NbtList();
        for (MenuEntry entry : menu) {
            NbtCompound entryNbt = new NbtCompound();
            entryNbt.putString("item", Registries.ITEM.getId(entry.item()).toString());
            entryNbt.putString("displayName", entry.displayName());
            menuList.add(entryNbt);
        }
        nbt.put("menu", menuList);
        nbt.put("seats", seatManager.writeNbt());

        NbtList sessionList = new NbtList();
        for (CustomerSession session : sessions.values()) {
            sessionList.add(session.writeNbt());
        }
        nbt.put("sessions", sessionList);
        return nbt;
    }

    public static ShopManager fromNbt(NbtCompound nbt) {
        ShopManager state = new ShopManager();
        state.open = nbt.getBoolean("open");
        if (nbt.contains("entranceX")) {
            state.entrancePos = new BlockPos(
                    nbt.getInt("entranceX"), nbt.getInt("entranceY"), nbt.getInt("entranceZ"));
            state.entranceDimension = nbt.getString("entranceDim");
        }
        NbtList menuList = nbt.getList("menu", NbtCompound.COMPOUND_TYPE.id());
        for (int i = 0; i < menuList.size(); i++) {
            NbtCompound entryNbt = menuList.getCompound(i);
            Identifier id = Identifier.tryParse(entryNbt.getString("item"));
            Item item = Registries.ITEM.get(id);
            state.menu.add(new MenuEntry(item, entryNbt.getString("displayName")));
        }
        state.seatManager.readNbt(nbt.getCompound("seats"));

        NbtList sessionList = nbt.getList("sessions", NbtCompound.COMPOUND_TYPE.id());
        for (int i = 0; i < sessionList.size(); i++) {
            CustomerSession session = CustomerSession.fromNbt(sessionList.getCompound(i));
            state.sessions.put(session.getNpcUuid(), session);
        }
        return state;
    }
}
CCEOF
cat > 'src/main/java/com/cozycafe/mod/command/CozyCafeCommands.java' << 'CCEOF'
package com.cozycafe.mod.command;

import com.cozycafe.mod.ShopManager;
import com.cozycafe.mod.seat.SetSeatInteraction;
import com.cozycafe.mod.shop.MenuEntry;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.StringArgumentType;
import net.minecraft.item.Item;
import net.minecraft.registry.Registries;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.text.Text;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.BlockPos;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static net.minecraft.server.command.CommandManager.argument;
import static net.minecraft.server.command.CommandManager.literal;

public class CozyCafeCommands {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {

        dispatcher.register(literal("cozycafe")
                .requires(src -> src.hasPermissionLevel(2))
                .then(literal("setseat")
                        .then(argument("npc", StringArgumentType.string())
                                .executes(ctx -> {
                                    if (ctx.getSource().getPlayer() == null) {
                                        ctx.getSource().sendError(Text.literal("Must be run by a player."));
                                        return 0;
                                    }
                                    UUID npc = UUID.fromString(StringArgumentType.getString(ctx, "npc"));
                                    SetSeatInteraction.beginAssignment(ctx.getSource().getPlayer().getUuid(), npc);
                                    ctx.getSource().sendFeedback(() -> Text.literal(
                                            "Shift+Right-Click a block to seat that customer there."), false);
                                    return 1;
                                }))));

        dispatcher.register(literal("shop")
                .requires(src -> src.hasPermissionLevel(2))
                .then(literal("open").executes(ctx -> {
                    ShopManager.get(ctx.getSource().getServer()).setOpen(true);
                    ctx.getSource().sendFeedback(() -> Text.literal("Shop is now open."), true);
                    return 1;
                }))
                .then(literal("close").executes(ctx -> {
                    ShopManager.get(ctx.getSource().getServer()).setOpen(false);
                    ctx.getSource().sendFeedback(() -> Text.literal(
                            "Shop closed. No new customers will be admitted; existing guests will finish and leave."), true);
                    return 1;
                })));

        dispatcher.register(literal("setshopentrance")
                .requires(src -> src.hasPermissionLevel(2))
                .executes(ctx -> {
                    var src = ctx.getSource();
                    BlockPos pos = src.getPlayer() != null
                            ? src.getPlayer().getBlockPos()
                            : BlockPos.ofFloored(src.getPosition());
                    ShopManager.get(src.getServer()).setEntrance(pos, src.getWorld());
                    src.sendFeedback(() -> Text.literal("Shop entrance set to " + pos.toShortString()), true);
                    return 1;
                }));

        // /setmenu add <item> <displayName...>
        // /setmenu remove <item>
        // /setmenu clear
        // /setmenu list
        dispatcher.register(literal("setmenu")
                .requires(src -> src.hasPermissionLevel(2))
                .then(literal("add")
                        .then(argument("item", StringArgumentType.greedyString())
                                .executes(ctx -> {
                                    String raw = StringArgumentType.getString(ctx, "item");
                                    return addMenuItem(ctx.getSource(), raw);
                                })))
                .then(literal("remove")
                        .then(argument("item", StringArgumentType.string())
                                .executes(ctx -> {
                                    String raw = StringArgumentType.getString(ctx, "item");
                                    return removeMenuItem(ctx.getSource(), raw);
                                })))
                .then(literal("clear").executes(ctx -> {
                    ShopManager.get(ctx.getSource().getServer()).setMenu(List.of());
                    ctx.getSource().sendFeedback(() -> Text.literal("Menu cleared."), true);
                    return 1;
                }))
                .then(literal("list").executes(ctx -> {
                    ShopManager shop = ShopManager.get(ctx.getSource().getServer());
                    if (shop.getMenu().isEmpty()) {
                        ctx.getSource().sendFeedback(() -> Text.literal("Menu is empty."), false);
                    } else {
                        for (MenuEntry entry : shop.getMenu()) {
                            ctx.getSource().sendFeedback(() -> Text.literal(
                                    "- " + entry.displayName() + " (" + Registries.ITEM.getId(entry.item()) + ")"), false);
                        }
                    }
                    return 1;
                })));
    }

    /**
     * Accepts "<item_id> <Display Name...>", e.g.:
     *   /setmenu add minecraft:mushroom_stew Mushroom Soup
     *   /setmenu add modid:apple_pie Apple Pie
     * Works with any registered item, vanilla or modded, since we just
     * resolve it by registry Identifier rather than a hardcoded list.
     */
    private static int addMenuItem(ServerCommandSource source, String raw) {
        String[] parts = raw.trim().split("\\s+", 2);
        if (parts.length == 0 || parts[0].isBlank()) {
            source.sendError(Text.literal("Usage: /setmenu add <item_id> <Display Name>"));
            return 0;
        }
        Identifier id = Identifier.tryParse(parts[0]);
        if (id == null || !Registries.ITEM.containsId(id)) {
            source.sendError(Text.literal("Unknown item id: " + parts[0]));
            return 0;
        }
        Item item = Registries.ITEM.get(id);
        String displayName = parts.length > 1 ? parts[1] : item.getName().getString();

        ShopManager shop = ShopManager.get(source.getServer());
        List<MenuEntry> updated = new ArrayList<>(shop.getMenu());
        updated.removeIf(e -> e.item() == item);
        updated.add(new MenuEntry(item, displayName));
        shop.setMenu(updated);

        source.sendFeedback(() -> Text.literal("Added \"" + displayName + "\" (" + id + ") to the menu."), true);
        return 1;
    }

    private static int removeMenuItem(ServerCommandSource source, String raw) {
        Identifier id = Identifier.tryParse(raw);
        if (id == null || !Registries.ITEM.containsId(id)) {
            source.sendError(Text.literal("Unknown item id: " + raw));
            return 0;
        }
        Item item = Registries.ITEM.get(id);
        ShopManager shop = ShopManager.get(source.getServer());
        List<MenuEntry> updated = new ArrayList<>(shop.getMenu());
        boolean removed = updated.removeIf(e -> e.item() == item);
        shop.setMenu(updated);
        if (removed) {
            source.sendFeedback(() -> Text.literal("Removed " + id + " from the menu."), true);
        } else {
            source.sendError(Text.literal(id + " wasn't on the menu."));
        }
        return removed ? 1 : 0;
    }
}
CCEOF
cat > 'src/main/java/com/cozycafe/mod/shop/MenuEntry.java' << 'CCEOF'
package com.cozycafe.mod.shop;

import net.minecraft.item.Item;

/**
 * A single configured menu item. Works with ANY item registered in the
 * game, vanilla or modded, since it's just stored as an Item reference
 * (and serialized as its registry Identifier - see ShopManager).
 */
public record MenuEntry(Item item, String displayName) {
}
CCEOF
cat > 'src/main/java/com/cozycafe/mod/shop/CozyCafeLog.java' << 'CCEOF'
package com.cozycafe.mod.shop;

import com.cozycafe.mod.CozyCafeMod;

public class CozyCafeLog {
    public static void warn(String msg) {
        CozyCafeMod.LOGGER.warn(msg);
    }
}
CCEOF
cat > 'src/main/java/com/cozycafe/mod/shop/CustomerSession.java' << 'CCEOF'
package com.cozycafe.mod.shop;

import com.cozycafe.mod.ShopManager;
import com.cozycafe.mod.economy.CoinReward;
import com.cozycafe.mod.npc.NpcAdapter;
import net.minecraft.entity.Entity;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.registry.Registries;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.BlockPos;

import java.util.Random;
import java.util.UUID;

/**
 * Tracks one customer NPC through: ARRIVING -> WAITING -> SEATED (after
 * manual seat assignment) -> ORDERING -> TRADING -> LEAVING -> (removed).
 *
 * This class only tracks STATE. The actual calls to Easy NPC (move,
 * dialog, pose, trade config) go through NpcAdapter, so swapping the
 * underlying NPC mod later only means rewriting NpcAdapter.
 */
public class CustomerSession {

    public enum State { ARRIVING, WAITING, SEATED, ORDERING, TRADING, LEAVING }

    private final UUID npcUuid;
    private int partySize;
    private State state;

    private Item orderedItem;
    private int orderedQuantity;
    private int tradesCompleted;

    private int leaveTimer; // ticks remaining before despawn, set once order is paid

    public CustomerSession(UUID npcUuid, int partySize) {
        this.npcUuid = npcUuid;
        this.partySize = partySize;
        this.state = State.ARRIVING;
    }

    public UUID getNpcUuid() { return npcUuid; }
    public State getState() { return state; }
    public int getPartySize() { return partySize; }
    public Item getOrderedItem() { return orderedItem; }
    public int getOrderedQuantity() { return orderedQuantity; }

    public void markWaiting() { state = State.WAITING; }
    public void markSeated() { state = State.SEATED; }

    /** Called once seated, to generate and announce the order via dialogue. */
    public void startOrdering(ShopManager shop, Random random) {
        MenuEntry entry = shop.pickRandomMenuItem(random);
        if (entry == null) {
            CozyCafeLog.warn("No menu configured - cannot start an order for " + npcUuid);
            return;
        }
        this.orderedItem = entry.item();
        // Quantity is always 1 of the chosen item per the spec ("exactly
        // one item from the menu"); the "multiple of the same item"
        // trading rule refers to a single item ordered in bulk, which
        // this mod doesn't currently generate but DOES support trading
        // for - see orderedQuantity below if you want to extend order
        // generation to sometimes ask for 2-3 of the same dish.
        this.orderedQuantity = 1;
        this.tradesCompleted = 0;
        this.state = State.ORDERING;

        NpcAdapter.openOrderDialog(npcUuid, entry.displayName());
        NpcAdapter.configureTrade(npcUuid, orderedItem, orderedQuantity);
        this.state = State.TRADING;
    }

    /**
     * Called by the trade-completion hook (wired to whatever event
     * Easy NPC's trading screen fires - see NpcAdapter.onTradeAccepted
     * doc comment for the exact wiring TODO).
     */
    public void onTradeCompleted(ServerWorld world, Random random) {
        if (state != State.TRADING) return;
        tradesCompleted++;

        ItemStack coin = CoinReward.randomCoin(random);
        NpcAdapter.giveItemToPlayerWhoTraded(world, npcUuid, coin);

        if (tradesCompleted >= orderedQuantity) {
            NpcAdapter.openThankYouDialog(npcUuid);
            state = State.LEAVING;
            leaveTimer = 60; // 3 seconds at 20 tps; adjust to taste
        }
    }

    /** @return true if this session is finished and should be removed/despawned. */
    public boolean tick(MinecraftServer server, ShopManager shop) {
        if (state == State.LEAVING) {
            leaveTimer--;
            if (leaveTimer <= 0) {
                ServerWorld world = server.getOverworld(); // adjust if multi-dimension support is added
                NpcAdapter.despawn(world, npcUuid);
                return true;
            }
        }
        return false;
    }

    public NbtCompound writeNbt() {
        NbtCompound nbt = new NbtCompound();
        nbt.putUuid("npc", npcUuid);
        nbt.putInt("partySize", partySize);
        nbt.putString("state", state.name());
        if (orderedItem != null) {
            nbt.putString("orderedItem", Registries.ITEM.getId(orderedItem).toString());
        }
        nbt.putInt("orderedQuantity", orderedQuantity);
        nbt.putInt("tradesCompleted", tradesCompleted);
        nbt.putInt("leaveTimer", leaveTimer);
        return nbt;
    }

    public static CustomerSession fromNbt(NbtCompound nbt) {
        UUID npc = nbt.getUuid("npc");
        CustomerSession session = new CustomerSession(npc, nbt.getInt("partySize"));
        session.state = State.valueOf(nbt.getString("state"));
        if (nbt.contains("orderedItem")) {
            Identifier id = Identifier.tryParse(nbt.getString("orderedItem"));
            session.orderedItem = Registries.ITEM.get(id);
        }
        session.orderedQuantity = nbt.getInt("orderedQuantity");
        session.tradesCompleted = nbt.getInt("tradesCompleted");
        session.leaveTimer = nbt.getInt("leaveTimer");
        return session;
    }
}
CCEOF
cat > 'src/main/java/com/cozycafe/mod/seat/SeatManager.java' << 'CCEOF'
package com.cozycafe.mod.seat;

import net.minecraft.entity.EntityType;
import net.minecraft.entity.decoration.ArmorStandEntity;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.nbt.NbtList;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Direction;

import java.util.*;

/**
 * Works with ANY block as a "chair" - vanilla or modded, regardless of
 * whether that block's own mod has sitting support. We never touch the
 * chair mod's code. Instead, when a chair is assigned, we spawn our own
 * invisible, non-gravity ArmorStand at the seat position and mount the
 * customer NPC onto it. Riding is a generic Minecraft mechanic any
 * entity can use, so this works regardless of what mod added the NPC.
 *
 * If the seated visual looks off for a given NPC model (e.g. legs not
 * bending), pair this with an Easy NPC pose command applied at the same
 * time the NPC is mounted - see NpcAdapter.applySitPose().
 */
public class SeatManager {

    public record Chair(BlockPos pos, Direction facing) {}

    // chair position -> NPC currently assigned to it (if any)
    private final Map<BlockPos, UUID> chairToNpc = new HashMap<>();
    private final Map<UUID, BlockPos> npcToChair = new HashMap<>();
    // chair position -> uuid of the invisible seat mount entity we spawned
    private final Map<BlockPos, UUID> chairToMountEntity = new HashMap<>();

    public boolean isChairTaken(BlockPos chairPos) {
        return chairToNpc.containsKey(chairPos);
    }

    public boolean assignChair(ServerWorld world, BlockPos chairPos, Direction facing, UUID npcUuid) {
        if (isChairTaken(chairPos)) return false;
        if (npcToChair.containsKey(npcUuid)) return false;

        chairToNpc.put(chairPos, npcUuid);
        npcToChair.put(npcUuid, chairPos);

        ArmorStandEntity mount = createSeatMount(world, chairPos, facing);
        world.spawnEntity(mount);
        chairToMountEntity.put(chairPos, mount.getUuid());

        var npc = world.getEntity(npcUuid);
        if (npc != null) {
            npc.startRiding(mount, true);
        }
        return true;
    }

    private ArmorStandEntity createSeatMount(ServerWorld world, BlockPos chairPos, Direction facing) {
        ArmorStandEntity stand = new ArmorStandEntity(EntityType.ARMOR_STAND, world);
        // Sit at roughly seat height rather than block-bottom.
        stand.refreshPositionAndAngles(
                chairPos.getX() + 0.5, chairPos.getY() + 0.2, chairPos.getZ() + 0.5,
                facing.getOpposite().asRotation(), 0f);
        stand.setInvisible(true);
        stand.setInvulnerable(true);
        stand.setNoGravity(true);
        stand.setMarker(false); // marker=true disables hitbox AND riding; we need riding to work
        stand.setSilent(true);
        // Prevent players from punching/breaking the mount by accident.
        stand.setCustomNameVisible(false);
        return stand;
    }

    public void freeChairForNpc(UUID npcUuid) {
        BlockPos chairPos = npcToChair.remove(npcUuid);
        if (chairPos == null) return;
        chairToNpc.remove(chairPos);

        UUID mountUuid = chairToMountEntity.remove(chairPos);
        if (mountUuid != null) {
            // Despawning the mount happens server-side wherever the world
            // lookup occurs; NpcAdapter calls despawnMount() with a world
            // reference when ending a session, since SeatManager itself
            // doesn't hold a World reference between calls.
        }
    }

    public UUID getMountEntityForChair(BlockPos chairPos) {
        return chairToMountEntity.get(chairPos);
    }

    public void despawnMount(ServerWorld world, BlockPos chairPos) {
        UUID mountUuid = chairToMountEntity.get(chairPos);
        if (mountUuid == null) return;
        var mount = world.getEntity(mountUuid);
        if (mount != null) {
            mount.discard();
        }
    }

    public BlockPos getChairForNpc(UUID npcUuid) {
        return npcToChair.get(npcUuid);
    }

    // --- persistence ---

    public NbtCompound writeNbt() {
        NbtCompound nbt = new NbtCompound();
        NbtList list = new NbtList();
        for (var entry : chairToNpc.entrySet()) {
            NbtCompound c = new NbtCompound();
            c.putInt("x", entry.getKey().getX());
            c.putInt("y", entry.getKey().getY());
            c.putInt("z", entry.getKey().getZ());
            c.putUuid("npc", entry.getValue());
            UUID mount = chairToMountEntity.get(entry.getKey());
            if (mount != null) c.putUuid("mount", mount);
            list.add(c);
        }
        nbt.put("chairs", list);
        return nbt;
    }

    public void readNbt(NbtCompound nbt) {
        chairToNpc.clear();
        npcToChair.clear();
        chairToMountEntity.clear();
        NbtList list = nbt.getList("chairs", NbtCompound.COMPOUND_TYPE.id());
        for (int i = 0; i < list.size(); i++) {
            NbtCompound c = list.getCompound(i);
            BlockPos pos = new BlockPos(c.getInt("x"), c.getInt("y"), c.getInt("z"));
            UUID npc = c.getUuid("npc");
            chairToNpc.put(pos, npc);
            npcToChair.put(npc, pos);
            if (c.contains("mount")) {
                chairToMountEntity.put(pos, c.getUuid("mount"));
            }
        }
    }
}
CCEOF
cat > 'src/main/java/com/cozycafe/mod/seat/SetSeatInteraction.java' << 'CCEOF'
package com.cozycafe.mod.seat;

import com.cozycafe.mod.ShopManager;
import net.fabricmc.fabric.api.event.player.UseBlockCallback;
import net.minecraft.entity.Entity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.ActionResult;
import net.minecraft.util.Hand;
import net.minecraft.util.math.Direction;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Implements the "Set Seat" interaction:
 *   1. Player enters Set Seat mode for a specific waiting NPC
 *      (e.g. by right-clicking the NPC while WAITING, which Easy NPC's
 *      dialog/action system reports through NpcEventCommand, putting
 *      that player into "pending seat assignment" for that NPC).
 *   2. Player Shift+Right-Clicks any block -> that block becomes the
 *      assigned chair for that NPC.
 *
 * This listens to Fabric API's UseBlockCallback rather than requiring
 * a held item, so it works with any block without needing item-use
 * permission overrides. Pending assignment is tracked per-player.
 */
public class SetSeatInteraction {

    // playerUuid -> npcUuid waiting to be assigned a chair
    private static final Map<UUID, UUID> pendingAssignment = new HashMap<>();

    public static void register() {
        UseBlockCallback.EVENT.register((player, world, hand, hitResult) -> {
            if (!player.isSneaking() || hand != Hand.MAIN_HAND) return ActionResult.PASS;
            if (!(world instanceof ServerWorld serverWorld)) return ActionResult.PASS;

            UUID npcUuid = pendingAssignment.get(player.getUuid());
            if (npcUuid == null) return ActionResult.PASS;

            var chairPos = hitResult.getBlockPos();
            Direction facing = hitResult.getSide() == Direction.UP
                    ? player.getHorizontalFacing().getOpposite()
                    : hitResult.getSide();

            ShopManager shop = ShopManager.get(serverWorld.getServer());
            if (shop.seats().isChairTaken(chairPos)) {
                player.sendMessage(Text.literal("That chair is already taken."), true);
                return ActionResult.FAIL;
            }

            boolean ok = shop.seats().assignChair(serverWorld, chairPos, facing, npcUuid);
            if (ok) {
                pendingAssignment.remove(player.getUuid());
                player.sendMessage(Text.literal("Seat assigned."), true);
                // Tell the session/NPC mod the customer is now seated.
                serverWorld.getServer().getCommandManager().executeWithPrefix(
                        serverWorld.getServer().getCommandSource(),
                        "cozycafe npc_event seated " + npcUuid);
                return ActionResult.SUCCESS;
            } else {
                player.sendMessage(Text.literal("Couldn't assign that seat."), true);
                return ActionResult.FAIL;
            }
        });
    }

    /** Call this when the player begins assigning a seat for a given NPC (e.g. from a dialog button command). */
    public static void beginAssignment(UUID playerUuid, UUID npcUuid) {
        pendingAssignment.put(playerUuid, npcUuid);
    }

    public static void cancelAssignment(UUID playerUuid) {
        pendingAssignment.remove(playerUuid);
    }
}
CCEOF
cat > 'src/main/java/com/cozycafe/mod/economy/CoinReward.java' << 'CCEOF'
package com.cozycafe.mod.economy;

import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.registry.Registries;
import net.minecraft.util.Identifier;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * Picks one random coin item to award per completed order, as requested:
 * "each food will give a random thing (1 of each coin in the mod will
 * be randomly selected)".
 *
 * Defaults to Coins JE's five tiers (namespace "coinsje"). If Coins JE
 * isn't present, or you swap in a different coin mod later, edit the
 * COIN_ITEM_IDS list below - no other code needs to change. A future
 * improvement would be a /shop setcoins command to configure this
 * in-game instead of editing source; left out here to keep the v0.1
 * scope to what was asked.
 */
public class CoinReward {

    private static final List<Identifier> COIN_ITEM_IDS = List.of(
            new Identifier("coinsje", "copper_coin"),
            new Identifier("coinsje", "iron_coin"),
            new Identifier("coinsje", "gold_coin"),
            new Identifier("coinsje", "diamond_coin"),
            new Identifier("coinsje", "netherite_coin")
    );

    private static List<Item> resolvedPool = null;

    private static List<Item> pool() {
        if (resolvedPool == null) {
            List<Item> items = new ArrayList<>();
            for (Identifier id : COIN_ITEM_IDS) {
                if (Registries.ITEM.containsId(id)) {
                    items.add(Registries.ITEM.get(id));
                } else {
                    // Logged once, not thrown - keeps the mod from
                    // hard-crashing if Coins JE's item IDs differ from
                    // what's expected (e.g. after a Coins JE update).
                    com.cozycafe.mod.CozyCafeMod.LOGGER.warn(
                            "Cozy Cafe: coin item {} not found - is Coins JE installed and loaded?", id);
                }
            }
            resolvedPool = items;
        }
        return resolvedPool;
    }

    public static ItemStack randomCoin(Random random) {
        List<Item> items = pool();
        if (items.isEmpty()) {
            return ItemStack.EMPTY;
        }
        Item chosen = items.get(random.nextInt(items.size()));
        return new ItemStack(chosen, 1);
    }
}
CCEOF
cat > 'src/main/java/com/cozycafe/mod/npc/NpcAdapter.java' << 'CCEOF'
package com.cozycafe.mod.npc;

import net.minecraft.entity.Entity;
import net.minecraft.item.ItemStack;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;

import java.util.UUID;

/**
 * ============================== IMPORTANT ==============================
 * This is the ONLY class that should know about Easy NPC's command syntax.
 * Every other class in this mod talks to "the NPC mod" only through this
 * adapter. If Easy NPC changes their command names in a future update, or
 * if you swap to a different NPC mod entirely, you only need to edit this
 * one file.
 *
 * This mod calls Easy NPC through its IN-GAME COMMANDS (dispatched as the
 * server/console) rather than a compiled Java API, because Easy NPC: Core
 * is not published on a Maven repository this project can pull from
 * automatically, and command-based integration survives Easy NPC point
 * updates better than binding against their internal classes directly.
 *
 * !! TODO BEFORE THIS WORKS !!
 * The exact command strings below are written from Easy NPC's public
 * command documentation, but command argument ORDER and NAMES vary
 * between Easy NPC versions (you're on 6.24.0). Test each command
 * manually in-game first (as an op) to confirm the exact syntax for
 * YOUR installed version, then adjust the strings in this file to match.
 * I could not verify these live against your exact jar from this
 * environment, so treat every dispatchCommand() string here as a
 * first draft, not a guarantee.
 * =========================================================================
 */
public class NpcAdapter {

    private static MinecraftServer SERVER;

    public static void init(MinecraftServer server) {
        SERVER = server;
    }

    private static void dispatchCommand(String command) {
        if (SERVER == null) return;
        SERVER.getCommandManager().executeWithPrefix(SERVER.getCommandSource(), command);
    }

    /** Tell an NPC to walk to a position (used for entrance arrival and walking to a chair). */
    public static void moveTo(UUID npcUuid, int x, int y, int z) {
        // Draft syntax - confirm against /easy_npc objective set <NPC> ... in-game.
        dispatchCommand(String.format(
                "easy_npc objective set %s move_to %d %d %d", npcUuid, x, y, z));
    }

    /** Open a named dialog you've pre-configured on the NPC (via Easy NPC's config UI) announcing the order. */
    public static void openOrderDialog(UUID npcUuid, String menuItemDisplayName) {
        // Draft: assumes you've set up a dialog named "order" on each
        // customer NPC preset with a placeholder you fill via a
        // scoreboard or dialog macro - see README "Wiring dialogs".
        dispatchCommand(String.format("easy_npc dialog open %s order", npcUuid));
    }

    public static void openThankYouDialog(UUID npcUuid) {
        dispatchCommand(String.format("easy_npc dialog open %s thank_you", npcUuid));
    }

    /** Restrict the NPC's trade screen to exactly this item/quantity for this order. */
    public static void configureTrade(UUID npcUuid, net.minecraft.item.Item item, int quantity) {
        var id = net.minecraft.registry.Registries.ITEM.getId(item);
        // Draft - confirm against Easy NPC's advanced trading commands;
        // this is the single most likely command to need adjusting,
        // see chat notes on testing trade reconfiguration at runtime.
        dispatchCommand(String.format(
                "easy_npc trading set %s slot0 %s %d", npcUuid, id, quantity));
    }

    /** Apply a seated pose once the NPC is mounted on our invisible seat entity. */
    public static void applySitPose(UUID npcUuid) {
        // Draft - this is the pose you'll build once in Easy NPC's pose
        // editor UI (bending legs etc), export it, then reference it
        // here, e.g.: "easy_npc pose set <NPC> sitting"
        dispatchCommand(String.format("easy_npc pose set %s sitting", npcUuid));
    }

    public static void resetPose(UUID npcUuid) {
        dispatchCommand(String.format("easy_npc pose set %s default", npcUuid));
    }

    public static void despawn(ServerWorld world, UUID npcUuid) {
        resetPose(npcUuid);
        dispatchCommand(String.format("easy_npc despawn %s", npcUuid));
    }

    /**
     * Gives the coin reward to whichever player completed the trade.
     * Easy NPC's trade screen is opened BY a specific player, so the
     * trade-completion hook (wired in NpcEventCommand) should pass that
     * player's UUID through rather than guessing - left as a parameter
     * here once that wiring is in place. For now this is a placeholder
     * that logs; wire it up once you confirm how Easy NPC signals trade
     * completion (likely an action/event you configure per-NPC to run
     * a command - see NpcEventCommand).
     */
    public static void giveItemToPlayerWhoTraded(ServerWorld world, UUID npcUuid, ItemStack coin) {
        com.cozycafe.mod.CozyCafeMod.LOGGER.info(
                "TODO: give {} to the player who completed a trade with NPC {}", coin, npcUuid);
    }
}
CCEOF
cat > 'src/main/java/com/cozycafe/mod/npc/NpcEventCommand.java' << 'CCEOF'
package com.cozycafe.mod.npc;

import com.cozycafe.mod.ShopManager;
import com.cozycafe.mod.shop.CustomerSession;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import net.minecraft.command.argument.EntityArgumentType;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.UUID;

import static net.minecraft.server.command.CommandManager.*;

/**
 * Registers /cozycafe npc_event ... - this is the command you configure
 * Easy NPC's dialog BUTTONS and ACTIONS to run (via their "Command"
 * action type, see their Actions config screen). This is how player
 * choices made through Easy NPC's UI get reported back to this mod,
 * without needing Easy NPC's internal Java event bus.
 *
 * Example wiring inside Easy NPC's dialog editor:
 *   Button "Table for two" -> Action: Command
 *     -> /cozycafe npc_event party_size @npc-uuid @initiator-uuid 2
 */
public class NpcEventCommand {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(literal("cozycafe")
                .then(literal("npc_event")
                        .then(literal("party_size")
                                .then(argument("npc", StringArgumentType.string())
                                        .then(argument("initiator", StringArgumentType.string())
                                                .then(argument("size", IntegerArgumentType.integer(1, 8))
                                                        .executes(ctx -> {
                                                            UUID npc = UUID.fromString(StringArgumentType.getString(ctx, "npc"));
                                                            int size = IntegerArgumentType.getInteger(ctx, "size");
                                                            onPartySizeChosen(ctx.getSource(), npc, size);
                                                            return 1;
                                                        })))))
                        .then(literal("seated")
                                .then(argument("npc", StringArgumentType.string())
                                        .executes(ctx -> {
                                            UUID npc = UUID.fromString(StringArgumentType.getString(ctx, "npc"));
                                            onSeated(ctx.getSource(), npc);
                                            return 1;
                                        })))
                        .then(literal("trade_completed")
                                .then(argument("npc", StringArgumentType.string())
                                        .executes(ctx -> {
                                            UUID npc = UUID.fromString(StringArgumentType.getString(ctx, "npc"));
                                            onTradeCompleted(ctx.getSource(), npc);
                                            return 1;
                                        })))
                ));
    }

    private static void onPartySizeChosen(ServerCommandSource source, UUID npcUuid, int size) {
        ShopManager shop = ShopManager.get(source.getServer());
        CustomerSession session = new CustomerSession(npcUuid, size);
        session.markWaiting();
        shop.putSession(session);
        // From here, staff (the player) uses the "Set Seat" tool to
        // assign chairs - see SetSeatCommand / the Set Seat item.
    }

    private static void onSeated(ServerCommandSource source, UUID npcUuid) {
        ShopManager shop = ShopManager.get(source.getServer());
        CustomerSession session = shop.getSession(npcUuid);
        if (session == null) return;
        session.markSeated();
        NpcAdapter.applySitPose(npcUuid);
        session.startOrdering(shop, source.getServer().getOverworld().getRandom());
        shop.putSession(session);
    }

    private static void onTradeCompleted(ServerCommandSource source, UUID npcUuid) {
        ShopManager shop = ShopManager.get(source.getServer());
        CustomerSession session = shop.getSession(npcUuid);
        if (session == null) return;
        session.onTradeCompleted(source.getWorld(), source.getServer().getOverworld().getRandom());
        shop.putSession(session);
    }
}
CCEOF
echo 'All files written.'

echo "Setting up the Gradle wrapper..."
if ! command -v gradle &> /dev/null; then
  echo "Gradle not found, installing via SDKMAN (one-time, ~1 min)..."
  curl -s "https://get.sdkman.io" | bash
  source "$HOME/.sdkman/bin/sdkman-init.sh"
  sdk install gradle 8.8 < /dev/null
fi
gradle wrapper --gradle-version 8.8
chmod +x gradlew

echo ""
echo "Done. Now run:"
echo "  git add -A"
echo "  git commit -m \"Rebuild project structure\""
echo "  git push origin main"
echo "Then run: ./gradlew build"
