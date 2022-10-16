local config = require("KKB.Enchanting Expansions.config")
-- Setup MCM.
local function registerModConfig()
	mwse.mcm.registerMCM(require("KKB.Enchanting Expansions.mcm"))
end
event.register("modConfigReady", registerModConfig)
local common = require("KKB.Enchanting Expansions.common")
local enchanting = require("KKB.Enchanting Expansions.enchanting")


local function onLoaded(e)
    if not tes3.player.data.KKB_EE then
        tes3.player.data.KKB_EE = {}
    end
end


---@param e calcSpellmakingPriceEventData
local function logSpellPrice(e)
     mwse.log("Price: "..e.price)
end


---@param e calcSpellmakingSpellPointCostEventData
local function logSpellCost(e)
     mwse.log("SPC: "..e.spellPointCost)
end


local function initialized()
	mwse.log("Kukaibo's enchanting mod loaded!")
    event.register("calcSpellPrice", logSpellPrice)
    event.register("calcSpellmakingSpellPointCost", logSpellCost)
    common.buildIconPaths()
    event.register("loaded", onLoaded)
    event.register("uiActivated", enchanting.openMenu, {filter="MenuEnchantment"})
    event.register("uiActivated", enchanting.grabNPC, {filter="MenuDialog"})
    event.register("disposition", common.saveDisposition)
    event.register("equip", function(e)
            if not e.item.isSoulGem then 
                return 
            end
            enchanting.prepareChanges(nil) 
        end)
    event.register("enchantedItemCreated", enchanting.onEnchant)
    event.register("enchantedItemCreateFailed", enchanting.onFailEnchant)
    if not tes3.hasCodePatchFeature(tes3.codePatchFeature.spellmakerEnchantMultipleEffects) then
        tes3.messageBox("WARNING: Enchanting Expansions will not work properly without the Spellmaker/enchant multiple effects MCP patch!")
        mwse.log("WARNING: Enchanting Expansions will not work properly without the Spellmaker/enchant multiple effects MCP patch!")
    end
    common.baseEP = tes3.findGMST("fEnchantmentMult").value
    common.baseValue = tes3.findGMST("fEnchantmentValueMult").value
    tes3.findGMST("fEnchantmentValueMult").value = 0
end
event.register("initialized", initialized)