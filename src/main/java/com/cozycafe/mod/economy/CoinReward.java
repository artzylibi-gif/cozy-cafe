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
