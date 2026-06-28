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
