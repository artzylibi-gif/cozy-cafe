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
