local config = require("KKB.Enchanting Expansions.config")

local function saveConfig()
	mwse.saveConfig("KKB.Enchanting Expansions", config)
end


local easyMCMConfig = {
	name = "Enchanting Expansions",
	template = "Template",
	pages = {
		{
			label = "Base Settings",
			class = "SideBarPage",
			components = {
				{
					label = "Use base values?",
					class = "OnOffButton",
					description = "When enabled, stat values higher than the base will not contribute to enchanting chance.",
					variable = {
						id = "useBaseValues",
						class = "TableVariable",
						table = config,
					},
				},
				{
					label = "Base + constant effect values?",
					class = "OnOffButton",
					description = "When enabled along with the above setting, Constant Effect enchantment Fortify Attribute/Skill effects are also allowed to contribute.",
					variable = {
						id = "useBaseConstValues",
						class = "TableVariable",
						table = config,
					},
				},
				{
					label = "Make school effects cheaper",
					class = "OnOffButton",
					description = "Makes effects cheaper when enchanting if the enchanter's base level in the corresponding school is high enough. Max 25% (configurable) discount at 100 skill.",
					variable = {
						id = "scaleMagicPotency",
						class = "TableVariable",
						table = config,
					},
				},
				{
					label = "School effect multiplier",
					class="TextField",
					description = "Default value=0.25",
					variable = {
						id = "scaleMagic",
						class = "TableVariable",
						numbersOnly=true,
						table = config
					}
				},
				{
					label = "Increase enchanting points with higher enchant skill",
					class = "OnOffButton",
					description = "Increases enchanting points on gear with higher base enchant level. Max 33.4% (configurable) increase at level 100.",
					variable = {
						id = "scaleEnchantPotency",
						class = "TableVariable",
						table = config,
					},
				},
				{
					label = "Enchant points multiplier",
					class="TextField",
					description = "Default value=0.3333",
					variable = {
						id = "scaleEnchant",
						class = "TableVariable",
						numbersOnly=true,
						table = config
					}
				},
				{
					label = "Faster enchant progress",
					class = "OnOffButton",
					description = "Enchantments that are more likely to fail give more skill progress. Failed enchantments give 25% (configurable) the progress of successful ones.",
					variable = {
						id = "scaleFailPotency",
						class = "TableVariable",
						table = config,
					},
				},
				{
					label = "Fail progress multiplier",
					class="TextField",
					description = "Default value=0.25",
					variable = {
						id = "scaleFail",
						class = "TableVariable",
						numbersOnly=true,
						table = config
					}
				},
			},
			sidebarComponents = {
				{
					label = "Enchanting Expansions",
					class = "Info",
					text = "This mods aims to make self-enchanting viable by fixing the self-enchant chance and removing the cumulative stacking that punishes multiple effects on the same enchantment. Optional changes include:\nLimiting enchanting stats to base/base+constant effect Fortify Attribute/Skill enchantments\nDiscounting magic effects based on skill in the school\nIncreasing enchant capacity based on player enchant skill."
				}
			},
		},
	onClose = saveConfig,
	}
}

return easyMCMConfig
