package com.cozycafe.mod.shop;

import net.minecraft.item.Item;

/**
 * A single configured menu item. Works with ANY item registered in the
 * game, vanilla or modded, since it's just stored as an Item reference
 * (and serialized as its registry Identifier - see ShopManager).
 */
public record MenuEntry(Item item, String displayName) {
}
