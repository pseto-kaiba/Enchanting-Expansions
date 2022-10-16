local config = require("KKB.Enchanting Expansions.config")
local common = require("KKB.Enchanting Expansions.common")
local enchanting = {}
enchanting.costs = {}
enchanting.playerStats = {}
enchanting.currentChance = 1
enchanting.currentCost = 0
enchanting.currentCastCost = 0
enchanting.currentPrice = 0
enchanting.savedEnchant = 5
enchanting.enchantMenu = nil


function enchanting.magicDiscount(skill)
    local x1 = 5
    local x2 = 100
    local y1 = 0
    local y2 = config.scaleMagic
    local x = math.max(5, common.currentEnchanter:getSkillStatistic(skill).base)
    x = math.min(x, 100)
    local slope = (y2-y1)/(x2-x1)
    return slope * (x-x1)
end

function enchanting.enchantDiscount()
    local x1 = 5
    local x2 = 100
    local y1 = 0
    local y2 = config.scaleEnchant
    local x = math.max(5, common.currentEnchanter:getSkillStatistic(tes3.skill.enchant).base)
    x = math.min(x, 100)
    local slope = (y2-y1)/(x2-x1)
    return slope * (x-x1)
end

--Updates enchanting discount
function enchanting.updateDiscount()
    if config.scaleEnchantPotency == true then
        tes3.findGMST("fEnchantmentMult").value = (1.00 + enchanting.enchantDiscount()) * common.baseEP
    else
        tes3.findGMST("fEnchantmentMult").value = common.baseEP
    end
end

function enchanting.prepareChanges(dMenu)
    --NPC enchanter
    if dMenu then
        --mwse.log("I3 - NPC")
        common.currentEnchanter = dMenu:getPropertyObject("PartHyperText_actor")
    else
    --Player enchanter
        --mwse.log("I3 - PC")
        common.currentEnchanter = tes3.mobilePlayer
    end
    common.stats = common.getStats(common.currentEnchanter)
    enchanting.updateDiscount()
end

--Save old effect costs, also apply discount
---@param e uiActivatedEventData
function enchanting.openMenu(e)
    enchanting.enchantMenu = e.element
    enchanting.playerStats = common.getStats(tes3.mobilePlayer)
    for _, effectId in pairs(tes3.effect) do
        local effect = tes3.getMagicEffect(effectId)
        enchanting.costs[effectId] = effect.baseMagickaCost
        if config.scaleMagicPotency == true then
            local skills = {tes3.skill.alteration, tes3.skill.conjuration, tes3.skill.destruction, tes3.skill.illusion, tes3.skill.mysticism, tes3.skill.restoration}
            effect.baseMagickaCost = (1.0 - enchanting.magicDiscount(skills[effect.school + 1])) * effect.baseMagickaCost
        end
    end

    local costContainer = enchanting.enchantMenu:findChild("MenuEnchantment_Cost")
    local chargeCostContainer = enchanting.enchantMenu:findChild("MenuEnchantment_EnchantmentCost")
    local curCharge = enchanting.enchantMenu:findChild("MenuEnchantment_currentcharge")
    costContainer.visible = false
    chargeCostContainer.visible = false
    curCharge.visible = false
    enchanting.costLabel = costContainer.parent:createLabel{id="KKB_EE:EnchChanceCostLabel", text="0"}
    if common.currentEnchanter.actorType == tes3.actorType.player then
        enchanting.costLabel.text = "0%"
    end
    enchanting.chargeCostLabel = chargeCostContainer.parent:createLabel{id="KKB_EE:EnchChargeLabel", text="1"}
    chargeCostContainer.parent:reorderChildren(chargeCostContainer, enchanting.chargeCostLabel, 1)
    enchanting.chargeCostLabel.borderLeft = 115
    
    
    enchanting.chargeCostLabel.positionX = chargeCostContainer.positionX
    enchanting.costLabel.positionX = costContainer.positionX
    enchanting.curChargeLabel = curCharge.parent:createLabel{id="KKB_EE:EnchCurCharge", text="0"}
    enchanting.curChargeLabel.positionX = curCharge.positionX
    curCharge.parent:reorderChildren(curCharge, enchanting.curChargeLabel, 1)
    enchanting.enchantMenu:updateLayout()


    e.element:findChild("MenuEnchantment_Buybutton"):registerBefore("click", function()
        --local costContainer = e.element:findChild("MenuEnchantment_Cost")
        mwse.log("Enchanting info dump START")
        mwse.log("Current cost: "..enchanting.currentCost)
        mwse.log("Current chance: "..enchanting.currentChance)
        mwse.log("Current cast cost: "..enchanting.currentCastCost)
        mwse.log("Current price: "..enchanting.currentPrice)
        mwse.log("Enchanting info dump END")
        --if tes3.mobilePlayer == common.currentEnchanter and costContainer:getPropertyFloat("MenuEnchantment_Cost")>0 then
        if common.currentEnchanter.actorType == tes3.actorType.player then
            local roll = math.random()
            mwse.log("Roll vs chance: "..roll.." vs "..enchanting.currentChance)
            if roll < enchanting.currentChance then
                tes3.findGMST("fEnchantmentChanceMult").value = -1000
                --costContainer:setPropertyFloat("MenuEnchantment_Cost", 10000)
            else
                tes3.findGMST("fEnchantmentChanceMult").value = 1000
                --costContainer:setPropertyFloat("MenuEnchantment_Cost", -10000)
            end
            tes3ui.updateEnchantingMenu()
        --elseif costContainer:getPropertyInt("MenuEnchantment_Effect")>0 then
        else
            local available_gold = tes3.getItemCount{reference=tes3.mobilePlayer, item="gold_001"}
            if available_gold < enchanting.currentPrice then
                tes3.messageBox("You don't have enough gold to buy this enchantment.")
                return false
            else
                tes3.removeItem{reference=tes3.mobilePlayer, item="gold_001", count=enchanting.currentPrice}
                common.currentEnchanter.barterGold = common.currentEnchanter.barterGold + enchanting.currentPrice
            end
            --costContainer:setPropertyInt("MenuEnchantment_Effect", common.barterOffer(common.currentEnchanter, enchanting.currentCost * tes3.findGMST("fEnchantmentValueMult").value, false))
        end

        local soulCharge = enchanting.enchantMenu:findChild("MenuEnchantment_soulcharge")
        local soulVal = soulCharge:getPropertyInt("MenuEnchantment_Effect")
        if enchanting.currentCastCost > soulVal then
            tes3.messageBox(tes3.findGMST("sEnchantmentMenu10").value)
            return false
        end
        --soulCharge:getPropertyInt("MenuEnchantment_Effect")
        local currentCharge = enchanting.enchantMenu:findChild("MenuEnchantment_currentcharge")
        if currentCharge then
            currentCharge:setPropertyInt("MenuEnchantment_Effect", enchanting.currentCastCost)
        end
        local enCharge = enchanting.enchantMenu:findChild("MenuEnchantment_EnchantmentCharge")
        if enCharge then
            enCharge:setPropertyInt("MenuEnchantment_Effect", enchanting.currentCost)
        end

        local maxCharge = enchanting.enchantMenu:findChild("MenuEnchantment_EnchantmentCharge")
        if maxCharge then
            maxCharge:setPropertyInt("MenuEnchantment_Effect", enchanting.currentCost + 1)
        end
        --local curCharge = enchanting.enchantMenu:findChild("MenuEnchantment_currentcharge")
        --curCharge:setPropertyInt("MenuEnchantment_Effect", enchanting.currentCost)
        --local chargeCostContainer = e.element:findChild("MenuEnchantment_EnchantmentCost")
        --if chargeCostContainer:getPropertyInt("MenuEnchantmentEffect")>0 then
        --chargeCostContainer:setPropertyInt("MenuEnchantmentEffect", enchanting.currentCastCost)
        --timer.frame.delayOneFrame(function() end)
       -- end
    end)

    --event.register("mouseButtonUp", enchanting.forceGUI)
    --event.register("mouseButtonDown", enchanting.forceGUI)
    --event.register("mouseButtonAxis", enchanting.forceGUI)
    event.register("uiActivated", enchanting.GUI_menu_updaters, {filter="MenuSetValues"})
    for id, effectItem in pairs(enchanting.enchantMenu:findChild("MenuEnchantment_EffectsScroll").children[1].children[1].children) do
        effectItem:registerBefore("click",  function(e)
            local effItems = enchanting.enchantMenu:findChild("MenuEnchantment_effectsContainer").children[2].children[1].children[1].children
            local n = #effItems
            --mwse.log("n="..n)
            if n < 8 then
                event.register("uiActivated", function(e)
                        --mwse.log(e.element:findChild("MenuSetValues_OkButton"))
                        --mwse.log("EI1: "..#effItems)
                        local okBtn = e.element:findChild("MenuSetValues_OkButton")
                        while (not okBtn or not okBtn.visible) do 
                            timer.frame.delayOneFrame(function() end)
                            okBtn = e.element:findChild("MenuSetValues_OkButton")
                        end
                        okBtn:triggerEvent("click")
                        --timer.frame.delayOneFrame(function() end)
                        --while #effItems == n do
                            --timer.frame.delayOneFrame(function() end)
                        --end
                        --mwse.log("EI2: "..#effItems)
                        local effItems = enchanting.enchantMenu:findChild("MenuEnchantment_effectsContainer").children[2].children[1].children[1].children
                        while #effItems == n do 
                            effItems = enchanting.enchantMenu:findChild("MenuEnchantment_effectsContainer").children[2].children[1].children[1].children
                            timer.frame.delayOneFrame(function() end)
                        end
                        effItems[#effItems]:triggerEvent("click")
                        --effItems[n+1]:triggerEvent("click")
                    end, {doOnce=true, filter="MenuSetValues"})
                --effItems = enchanting.enchantMenu:findChild("MenuEnchantment_effectsContainer").children[2].children[1].children[1].children
                --timer.frame.delayOneFrame(function() effItems[n+1]:triggerEvent("click") end)
            end
            enchanting.forceGUI{}
        end
    )
    end
    enchanting.enchantMenu:findChild("MenuEnchantment_casttype"):registerAfter("click", enchanting.forceGUI)
    enchanting.enchantMenu:findChild("MenuEnchantment_Item"):registerAfter("click", enchanting.forceGUI)
    enchanting.enchantMenu:findChild("MenuEnchantment_SoulGem"):registerAfter("click", enchanting.forceGUI)
    --event.register("enterFrame", enchanting.forceGUI)
    enchanting.forceGUI({})

    e.element:registerAfter("destroy", enchanting.cleanUp)
end

---@param e enchantedItemCreatedEventData
function enchanting.onEnchant(e)
    if config.scaleFailPotency == true and e.enchanter.actorType==tes3.actorType.player then
        local base_Raise = tes3.getSkill(tes3.skill.enchant).actions[2]
        local multiplier = math.max(0, 1/enchanting.currentChance - 1)
        mwse.log("Extra xp: "..multiplier*base_Raise)
        local playerProgress = tes3.mobilePlayer.skillProgress[tes3.skill.enchant+1] + multiplier * base_Raise
        tes3.mobilePlayer.skillProgress[tes3.skill.enchant+1] = playerProgress
    end
    local ench = e.object.enchantment
    if ench.castType and ench.castType ~= tes3.enchantmentType.constant and ench.chargeCost and ench.chargeCost > 0 then
        ench.chargeCost = enchanting.currentCost
    end
end

---@param e enchantedItemCreateFailedEventData
function enchanting.onFailEnchant(e)
    if config.scaleFailPotency == true and common.currentEnchanter.actorType==tes3.actorType.player then
        local base_Raise = tes3.getSkill(tes3.skill.enchant).actions[2]
        local multiplier = math.max(0, 1/enchanting.currentChance - 1) * config.scaleFail
        local playerProgress = tes3.mobilePlayer.skillProgress[tes3.skill.enchant+1] + multiplier * base_Raise
        mwse.log("Extra xp: "..multiplier*base_Raise)
        tes3.mobilePlayer.skillProgress[tes3.skill.enchant+1] = playerProgress
    end
end

---@param e mouseButtonUpEventData
function enchanting.forceGUI(e)
    --mwse.log("Updating!")
    enchanting.currentCost, _, enchanting.currentChance, enchanting.currentCastCost = enchanting.calcCosts(enchanting.enchantMenu)
    --local costContainer = enchanting.enchantMenu:findChild("MenuEnchantment_Cost")
    local costContainer = enchanting.costLabel
    
    --if tes3.mobilePlayer == common.currentEnchanter and costContainer:getPropertyFloat("MenuEnchantment_Cost")>0 then
    if common.currentEnchanter.actorType == tes3.actorType.player then
        costContainer.text = string.format("%.2f%%",enchanting.currentChance * 100)
    --elseif costContainer:getPropertyInt("MenuEnchantment_Effect")>0 then
    else
        enchanting.currentPrice = common.barterOffer(common.currentEnchanter, enchanting.currentCost * common.baseValue, false)
        costContainer.text = enchanting.currentPrice
    end

    enchanting.curChargeLabel.text = enchanting.currentCost

    --local chargeCostContainer = enchanting.enchantMenu:findChild("MenuEnchantment_EnchantmentCost")
    local chargeCostContainer = enchanting.chargeCostLabel
    --if chargeCostContainer:getPropertyInt("MenuEnchantmentEffect")>0 then
    chargeCostContainer.text = enchanting.currentCastCost 
    --end
    --enchanting.enchantMenu:updateLayout()

end

function enchanting.calcCosts(M)
    local base_dur = tes3.findGMST("fEnchantmentConstantDurationMult").value
    local range_multiplier = 1.0
    --local const_chance = 
    local constant = M:findChild("MenuEnchantment_casttype"):getPropertyInt("MenuEnchantment_casttype") == tes3.enchantmentType.constant
    local total_cost = 0
    for id, effectItem in pairs(M:findChild("MenuEnchantment_effectsContainer").children[2].children[1].children[1].children) do
        if effectItem and effectItem.children[2] and effectItem.children[2].children[1] then
            local duration = base_dur
            if constant == false then
                duration = effectItem:getPropertyInt("MenuEnchantment_Duration")
                duration = math.max(duration, 1)
            end
            local targetWord = tes3.findGMST("sRangeTarget").value
            local words = {}
            local fullEffectName = effectItem.children[2].children[1].text
            for word in fullEffectName:gmatch("%S+") do
                table.insert(words,word)
            end
            if words[#words] == targetWord then
                range_multiplier = 1.5
            end
            local effect = tes3.getMagicEffect(common.icons[effectItem.children[1].contentPath])
            local minMagnitude = effectItem:getPropertyInt("MenuEnchantment_MagLow")
            local maxMagnitude = effectItem:getPropertyInt("MenuEnchantment_MagHigh")
            local area = effectItem:getPropertyInt("MenuEnchantment_Area")
            area = math.max(1, area)
    
            local x = 0.05 * (math.max(1, minMagnitude) + math.max(1, maxMagnitude)) * effect.baseMagickaCost * duration
            if tes3.hasCodePatchFeature(tes3.codePatchFeature.spellmakerAreaEffectCost) then
                x = x * (1 + area*area/400)
            else
                x = x + 0.05 * area
            end
            x = x * range_multiplier
            total_cost = total_cost + x * tes3.findGMST("fEffectCostMult").value
        end
    end

    local cast_cost = total_cost
    if tes3.hasCodePatchFeature(tes3.codePatchFeature.enchantedItemRebalance) then
        --mwse.log("Pre CC calc 1: "..cast_cost)
        cast_cost = total_cost * (1.0 - enchanting.playerStats.Enchant * 0.004)
        --mwse.log("Post CC calc 1: "..cast_cost)
    else
        --mwse.log("Pre CC calc 2: "..cast_cost)
        cast_cost = total_cost * (1.1 - enchanting.playerStats.Enchant * 0.01)
       -- mwse.log("Post CC calc 2: "..cast_cost)
    end
    cast_cost = math.floor(cast_cost)
    cast_cost = math.max(1, cast_cost)

    total_cost = math.floor(total_cost)
    total_cost = math.max(total_cost, 1)
    local chance = common.calcChance(total_cost, constant)
    return total_cost, constant, chance, cast_cost
end


---@param e uiActivatedEventData
function enchanting.grabNPC(e)
    --mwse.log("I1")
    local enchButton = e.element:findChild("MenuDialog_service_enchanting")
    if enchButton then
        --mwse.log("I2")
        enchButton:registerBefore("click", function() enchanting.prepareChanges(e.element) end)
    end
end

---@param e uiActivatedEventData
function enchanting.GUI_menu_updaters(e)
    --mwse.log("In")
    --mwse.log(e.element)
    local m=tes3ui.findMenu("MenuSetValues")
    if not m then return end
    --mwse.log(m)
    --mwse.log("In.")
    enchanting.forceGUI{}
    local clickIDs = {"MenuSetValues_Range", "MenuSetValues_OkButton", "MenuSetValues_Deletebutton", "MenuSetValues_Cancelbutton"}
    local scrollIDs = {"MenuSetValues_MagLowSlider", "MenuSetValues_MagHighSlider","MenuSetValues_DurationSlider","MenuSetValues_AreaSlider"}
    --[[
    m:findChild("MenuSetValues_Range"):registerAfter("click", enchanting.forceGUI)
    m:findChild("MenuSetValues_OkButton"):registerAfter("click", enchanting.forceGUI)
    m:findChild("MenuSetValues_Deletebutton"):registerAfter("click", enchanting.forceGUI)
    m:findChild("MenuSetValues_Cancelbutton"):registerAfter("click", enchanting.forceGUI)
    m:findChild("MenuSetValues_MagLowSlider"):registerAfter("PartScrollBar_changed", enchanting.forceGUI)
    m:findChild("MenuSetValues_MagHighSlider"):registerAfter("PartScrollBar_changed", enchanting.forceGUI)
    m:findChild("MenuSetValues_DurationSlider"):registerAfter("PartScrollBar_changed", enchanting.forceGUI)
    m:findChild("MenuSetValues_AreaSlider"):registerAfter("PartScrollBar_changed", enchanting.forceGUI)
    ]]
    for _, id in pairs(clickIDs) do
        local child = m:findChild(id)
        if child then
            child:registerAfter("click", enchanting.forceGUI)
        end
    end
    for _, id in pairs(scrollIDs) do
        local child = m:findChild(id)
        if child then
            child:registerAfter("PartScrollBar_changed", enchanting.forceGUI)
        end
    end
    m:registerAfter("destroy", enchanting.forceGUI)
end

---@param e tes3uiEventData
function enchanting.cleanUp(e)
    for _, effectId in pairs(tes3.effect) do
        tes3.getMagicEffect(effectId).baseMagickaCost = enchanting.costs[effectId]
    end
    common.currentEnchanter = tes3.mobilePlayer
    --event.unregister("mouseButtonUp", enchanting.forceGUI)
    --event.unregister("mouseButtonDown", enchanting.forceGUI)
    --event.unregister("mouseAxis", enchanting.forceGUI)
    event.unregister("uiActivated", enchanting.GUI_menu_updaters, {filter="MenuSetValues"})
    --event.unregister("enterFrame", enchanting.forceGUI)
    e.forwardSource:unregisterAfter("destroy", enchanting.cleanUp)
end

return enchanting