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
