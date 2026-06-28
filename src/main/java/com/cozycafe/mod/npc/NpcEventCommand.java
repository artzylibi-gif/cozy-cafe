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
