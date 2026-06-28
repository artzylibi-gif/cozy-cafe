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
