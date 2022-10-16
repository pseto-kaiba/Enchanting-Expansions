local common = {}
local config = require("KKB.Enchanting Expansions.config")
common.stats = {}
---@type tes3mobileActor
common.currentEnchanter = nil
common.lastDisposition = 0
common.baseEP = 10.0
common.baseValue = 1000

---@type dispositionEventData
function common.saveDisposition(e)
    common.lastDisposition = math.max(math.min(e.disposition,100),0)
end

---@param mobile tes3mobileNPC
function common.getBarterStats(mobile)
    return {M=math.min(100, mobile.mercantile.current),L=math.min(100, mobile.luck.current)*0.1, P=math.min(10, 0.2*mobile.personality.current), F=mobile.fatigue.normalized}
end

---@param npc tes3mobileActor
---@param basePrice number
---@param selling boolean
function common.barterOffer(npc, basePrice, selling)
    if npc.actorType == tes3.actorType.creature then
        return math.max(1,basePrice)
    end
    local pcStats = common.getBarterStats(tes3.mobilePlayer)
    local npcStats = common.getBarterStats(npc)
    local pcTerm = (common.lastDisposition - 50 + pcStats.M + pcStats.L + pcStats.P) * pcStats.F
    local npcTerm = (npcStats.M + npcStats.L + npcStats.P) * npcStats.F
    local multiplier = 0.5
    if tes3.hasCodePatchFeature(tes3.codePatchFeature.mercantileFix) then
        multiplier = 0.3125
    end
    local buyTerm = 0.01 * (100 - multiplier * (pcTerm - npcTerm))
    local sellTerm = 0.01 * (50 - multiplier * (npcTerm - pcTerm))
    local x = buyTerm
    if selling==true then
            x = math.min(buyTerm, sellTerm)
    end
    local offerPrice
    if x < 1 then
        offerPrice = math.floor(x*basePrice)
    else
        offerPrice = basePrice + math.floor((x-1)*basePrice)
    end
    return math.max(1, offerPrice)
end

--Get total of all disallowed boosts
function common.disallowedBoosts(actor, effect_id, stat_id, allowed_boosts, stat_is_skill)
	local disallowed_total = 0
	local att_field = "attributeId"
	if stat_is_skill == true then
		att_field = "skill_id"
	end
	--Go through all of the player's active magic effects
	for _, activeEffect in pairs(actor:getActiveMagicEffects{effect=effect_id}) do
		--If effect and stat id match up and the boost is not allowed add it to sum
		if not allowed_boosts[activeEffect.instance.source.id] and activeEffect[att_field] == stat_id then
			disallowed_total = disallowed_total + activeEffect.magnitude
		end
	end
	return disallowed_total
end

--Get stats adjusted to remove non-constant effect enchant-relevant Fortify enchantments
--- @param actor tes3mobileActor
function common.getFortifyBoosts(actor)
	--Get current INT, LUCK, Enchant
	local cur_int = actor.intelligence.current
	local cur_luck = actor.luck.current
	local cur_ench = actor:getSkillStatistic(tes3.skill.enchant).current
	--Keep track of all CE enchantments affecting the player
	local active_CE_enchantments = {}

	for _, stack in pairs(actor.reference.object.equipment) do
		---@type tes3enchantment
		local enchantment = stack.object.enchantment
		--Only consider enchanted gear with CE enchantments
		if enchantment and enchantment.castType == tes3.enchantmentType.constant then
			active_CE_enchantments[enchantment.id] = true
		end
	end

	cur_int = cur_int - common.disallowedBoosts(actor, tes3.effect.fortifyAttribute, tes3.attribute.intelligence, active_CE_enchantments, false)
	cur_luck = cur_luck - common.disallowedBoosts(actor, tes3.effect.fortifyAttribute, tes3.attribute.luck, active_CE_enchantments, false)
	cur_ench = cur_ench - common.disallowedBoosts(actor, tes3.effect.fortifySkill, tes3.skill.enchant, active_CE_enchantments, true)
	return {Intelligence=cur_int, Luck=cur_luck, Enchant=cur_ench}
end

--Retrieves an actor's skills and attributes relevant to enchanting
--Wrapper function that, depending on toggle, gets either current stats, min(current,base) stats or current with all non-CE Fortify stats subtracted
--For the six spell school skills, always get base stats
--- @param actor tes3mobileActor
function common.getStats(actor)
	local stats = {Intelligence=actor.intelligence.current, Luck=actor.luck.current, Enchant=actor:getSkillStatistic(tes3.skill.enchant).current}
	if config.useBaseValues == false then
	--Current stats
	elseif config.useBaseConstValues == false then
	--Base stats
		stats.Intelligence = math.min(stats.Intelligence, actor.intelligence.base)
		stats.Luck = math.min(stats.Luck, actor.luck.base)
		stats.Enchant = math.min(stats.Enchant, actor:getSkillStatistic(tes3.skill.enchant).base)
	else
	--Base+CE stats
		stats = common.getFortifyBoosts(actor)
	end
    stats.Destruction = actor:getSkillStatistic(tes3.skill.destruction).base
    stats.Illusion = actor:getSkillStatistic(tes3.skill.illusion).base
    stats.Mysticism = actor:getSkillStatistic(tes3.skill.mysticism).base
    stats.Restoration = actor:getSkillStatistic(tes3.skill.restoration).base
    stats.Conjuration = actor:getSkillStatistic(tes3.skill.conjuration).base
    stats.Alteration = actor:getSkillStatistic(tes3.skill.alteration).base
    stats.FatigueTerm = math.min(actor.fatigue.normalized, 1.0)
	return stats
end

--Quadratic curve fit used for enchant chance formula
--The gist of it is: 
--Take the current enchantment's point value and divide it by 3. We call this value the (T)arget.
--Let your (S)tats be fatigueTerm (capped at 1.0) * (Enchant + 0.2*Intelligence + 0.1*Alchemy) / 1.3
--If S <= T, enchant chance is 0. So, let's say we're trying to fully enchant an exquisite amulet (120 poins). We'd need 40 Enchant, Intelligence and Luck to even have a chance of suceeding.
--If S == T + 10, enchant chance is 0.25
--S == T + 20, enchant chance is 0.5
--S == T + 50, enchant chance is 0.75
--S >= T + 100, enchant chance is 1.0
--Interpolate between these points for other values

function common.eval(a,b,c,x)
    return a + (b + c * x) * x
end

function common.regression(xa,ya)
    local n = #xa

    local xm = 0.0
    local ym = 0.0
    local x2m = 0.0
    local x3m = 0.0
    local x4m = 0.0
    local xym = 0.0
    local x2ym = 0.0

    for i=1,n do
        xm = xm + xa[i]
        ym = ym + ya[i]
        x2m = x2m + xa[i] * xa[i]
        x3m = x3m + xa[i] * xa[i] * xa[i]
        x4m = x4m + xa[i] * xa[i] * xa[i] * xa[i]
        xym = xym + xa[i] * ya[i]
        x2ym = x2ym + xa[i] * xa[i] * ya[i]
    end
    xm = xm / n
    ym = ym / n
    x2m = x2m / n
    x3m = x3m / n
    x4m = x4m / n
    xym = xym / n
    x2ym = x2ym / n

    local sxx = x2m - xm * xm
    local sxy = xym - xm * ym
    local sxx2 = x3m - xm * x2m
    local sx2x2 = x4m - x2m * x2m
    local sx2y = x2ym - x2m * ym

    local b = (sxy * sx2x2 - sx2y * sxx2) / (sxx * sx2x2 - sxx2 * sxx2)
    local c = (sx2y * sxx - sxy * sxx2) / (sxx * sx2x2 - sxx2 * sxx2)
    local a = ym - b * xm - c * x2m

    return a,b,c
end

function common.calcChance(enchantPoints, constant)
    local S = common.stats.FatigueTerm*(common.stats.Enchant + 0.2 * common.stats.Intelligence + 0.1*common.stats.Luck) / 1.3
    local T = enchantPoints / 3
    if S <= T - 10 then return 0 end
    if S >= T + 100 then return 1.0 end
    local X = {T,T+10,T+20,T+50,T+100}
    local Y = {0,0.25,0.5,0.75,1.0}
    local a,b,c = common.regression(X,Y)
    local val = a + b * S + c * S * S
    if constant == true then
        val = val * tes3.findGMST("fEnchantmentConstantChanceMult").value
    end
    return val
end

common.icons = {}
function common.buildIconPaths()
    for _, effectID in pairs(tes3.effect) do
        local eff = tes3.getMagicEffect(effectID)
        common.icons["Icons\\"..eff.icon] = effectID
    end
end


return common