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
