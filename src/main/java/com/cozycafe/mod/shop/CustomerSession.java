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
