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
