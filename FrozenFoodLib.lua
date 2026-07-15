
local item_sounds = require("__base__.prototypes.item_sounds")
local khaoslib_item = require("__khaoslib__.prototypes.item")
local khaoslib_list = require("__khaoslib__.common.list")
local khaoslib_recipe = require("__khaoslib__.prototypes.recipe")
local khaoslib_technology = require("__khaoslib__.prototypes.technology")

--- @class FrozenFoodLib
local FrozenFoodLib = {}

--- @class FrozenFoodLib.Settings
--- @field public spoilage "default"|"extra"|"off"
--- @field public recipe_size integer
--- @field public additional_categories data.RecipeCategoryID[]?
--- @field public thaw_categories data.RecipeCategoryID[]
--- @field public container_recipe "plastic"|"lds"
--- @field public container_ingredient data.ItemID
--- @field public biochamber_allow boolean
--- @field public biochamber_productivity boolean
--- @field public max_productivity number?
--- @field public freeze_time number
--- @field public freezer_efficiency number
--- @field public short_spoilage_time integer?
--- @field public long_spoilage_time integer?
--- @field public spoilage_target data.ItemID?
FrozenFoodLib.settings  = {
  spoilage = settings.startup["s6x-spoilage"].value,
  recipe_size = 2,
  container_recipe = settings.startup["s6x-container-recipe"].value,
  biochamber_allow = settings.startup["s6x-biochamber-allow"].value,
  biochamber_productivity = settings.startup["s6x-biochamber-productivity"].value,
  freeze_time = settings.startup["s6x-freeze-time"].value,
  freezer_efficiency = settings.startup["s6x-freezer-efficiency"].value,
  short_spoilage_time = 1440 * minute,
  long_spoilage_time = 1440 * minute * 2,
  spoilage_target = "s6x-freezer-burn"
}

if (FrozenFoodLib.settings.spoilage == "extra") then
  FrozenFoodLib.settings.short_spoilage_time = FrozenFoodLib.settings.short_spoilage_time--[[@cast -?]] * 10
  FrozenFoodLib.settings.long_spoilage_time = FrozenFoodLib.settings.long_spoilage_time--[[@cast -?]] * 10
elseif (FrozenFoodLib.settings.spoilage == "off") then
  FrozenFoodLib.settings.short_spoilage_time = nil
  FrozenFoodLib.settings.long_spoilage_time = nil
  FrozenFoodLib.settings.spoilage_target = nil
end

FrozenFoodLib.settings.container_ingredient = "plastic-bar"
if (FrozenFoodLib.settings.container_recipe == "lds") then
  FrozenFoodLib.settings.container_ingredient = "lds-container"
end

FrozenFoodLib.settings.additional_categories = nil
if (FrozenFoodLib.settings.biochamber_allow) then
  FrozenFoodLib.settings.additional_categories = {"organic"}
end

FrozenFoodLib.thaw_categories = util.table.deepcopy(FrozenFoodLib.settings.additional_categories or {})
khaoslib_list.add(FrozenFoodLib.thaw_categories, "advanced-crafting", "advanced-crafting", {index = 1})

FrozenFoodLib.settings.max_productivity = nil
if (not FrozenFoodLib.settings.biochamber_productivity) then
  FrozenFoodLib.settings.max_productivity = 0
end

--- @class FrozenFoodLib.FrozenFoodDefinition
--- @field public name data.ItemID The name of the item to freeze.
--- @field public icon string The path to the icon of the item to freeze, icon size must be 64x64.
--- @field public order data.Order The order of frozen item and freeze/thaw recipes.
--- @field public stack_size data.ItemCountType The stack size of the frozen item.
--- @field public weight data.Weight The weight of the frozen item in kg.
--- @field public default_import_location data.SpaceLocationID? The default import location of the frozen item. Defaults to Gleba.
--- @field public spoilage_time ("short"|"long")? The spoilage time of the frozen item. Defaults to short if not specified or undefined value.
--- @field public tint data.RecipeTints The crafting machine tints the thaw recipes. The primary color is used for the tinting the frozen container too.
--- @field public unlock "s6x-freeze-preservation"|"s6x-freeze-preservation-living"|data.TechnologyID? The technology to unlock the freeze/thaw recipes. Defaults to "s6x-freeze-preservation" if not specified.

--- @param def FrozenFoodLib.FrozenFoodDefinition
function FrozenFoodLib.create_frozen_food(def)
  khaoslib_item:load {
    type = "item",
    name = "s6x-frozen-" ..def.name,
    subgroup = "freeze-thaw-processes",
    order = "zzx-" .. def.order,
    stack_size = def.stack_size,
    weight = def.weight * kg,
    spoil_ticks = (def.spoilage_time == "long" and FrozenFoodLib.settings.long_spoilage_time or FrozenFoodLib.settings.short_spoilage_time) --[[@as integer?]],
    spoil_result = FrozenFoodLib.settings.spoilage_target,
		default_import_location = def.default_import_location or "gleba",
		inventory_move_sound = item_sounds.plastic_inventory_move,
		pick_sound = item_sounds.plastic_inventory_pickup,
		drop_sound = item_sounds.plastic_inventory_move,
		random_tint_color = item_tints.plastic
  } :set_icons {
			{icon = "__FrozenFood__/graphics/icons/frozen-box.png", icon_size = 64},
      --- @diagnostic disable-next-line: need-check-nil
			{icon = "__FrozenFood__/graphics/icons/auto/frozen-overlay.png", icon_size = 64, tint = {def.tint.primary.r, def.tint.primary.g, def.tint.primary.b, 0.25}},
			{icon = def.icon, icon_size = 64, scale = 0.25, shift = {0, -1}, tint = {1.0, 1.0, 1.0, 0.5}},
  } :commit()

  local flouroketone_amount = def.unlock == "s6x-freeze-preservation-living" and 2 or 1
  khaoslib_recipe:load {
    type = "recipe",
    name = "s6x-frozen-" .. def.name,
		subgroup = "freeze-thaw-processes",
    order = "zzy-" .. def.order,
    energy_required = FrozenFoodLib.settings.freeze_time,
		main_product = "s6x-frozen-" .. def.name,
		auto_recycle = false,
		allow_productivity = false,
		allow_quality = false,
		allow_decomposition = false,
		enabled = false,
  } :set_icons {
			{icon = "__FrozenFood__/graphics/icons/frozen-box.png", icon_size = 64},
      --- @diagnostic disable-next-line: need-check-nil
			{icon = "__FrozenFood__/graphics/icons/auto/frozen-overlay.png", icon_size = 64, tint = {def.tint.primary.r, def.tint.primary.g, def.tint.primary.b, 0.25}},
			{icon = def.icon, icon_size = 64, scale = 0.25, shift = {0, -1}, tint = {1.0, 1.0, 1.0, 0.5}},
  } :set_ingredients {
    {type = "item", name = def.name, amount = FrozenFoodLib.settings.recipe_size, ignored_by_stats = FrozenFoodLib.settings.recipe_size},
    {type = "item", name = "s6x-frozen-box", amount = FrozenFoodLib.settings.recipe_size, ignored_by_stats = FrozenFoodLib.settings.recipe_size},
    {type = "fluid", name = "fluoroketone-cold", amount = flouroketone_amount, ignored_by_stats = flouroketone_amount},
  } :set_results {
    {type = "item", name = "s6x-frozen-" .. def.name, amount = FrozenFoodLib.settings.recipe_size, ignored_by_stats = FrozenFoodLib.settings.recipe_size},
    {type = "fluid", name = "fluoroketone-hot", amount = flouroketone_amount, ignored_by_stats = flouroketone_amount},
  } :set_crafting_machine_tint {
    primary = {r = 0.56, g = 0.837, b = 0.837, a = 1.000},
    secondary = {r = 0.398, g = 0.732, b = 0.681, a = 1.000}, -- #65baadff
    tertiary = {r = 0.337, g = 0.306, b = 0.306, a = 1.000}, -- #554e4eff
    quaternary = {r = 0.436, g = 0.743, b = 0.711, a = 1.000}, -- #6fbdb5ff
  } :set_categories {"cryogenics"}
    :commit()

  khaoslib_recipe:load {
    type = "recipe",
    name = "s6x-thaw-" .. def.name,
    subgroup = "freeze-thaw-processes",
    order = "zzz-" .. def.order,
		auto_recycle = false,
		energy_required = 1,
    maximum_productivity = FrozenFoodLib.settings.max_productivity,
		allow_productivity = false,
		allow_quality = false,
		allow_decomposition = false,
		enabled = false,
  } :set_icons {
      {icon = def.icon, icon_size = 64},
			{icon = "__FrozenFood__/graphics/icons/frozen-box.png", icon_size = 64, scale = 0.25, shift = {-8, -8}},
			{icon = def.icon, icon_size = 64, scale = 0.125, shift = {-8, -8}, tint = {1.0, 1.0, 1.0, 0.5}},
  } :set_ingredients {
    {type = "item", name = "s6x-frozen-" .. def.name, amount = 1, ignored_by_stats = 1},
  } :set_results {
    {type = "item", name = def.name, amount = 1, ignored_by_stats = 1, probability = FrozenFoodLib.settings.freezer_efficiency},
    {type = "item", name = "s6x-frozen-box", amount = 1, ignored_by_stats = 1}
  } :set_crafting_machine_tint(def.tint)
    :set_categories(FrozenFoodLib.thaw_categories)
    :commit()

  khaoslib_technology:load(def.unlock or "s6x-freeze-preservation")
    :add_unlock_recipe("s6x-frozen-" .. def.name)
    :add_unlock_recipe("s6x-thaw-" .. def.name)
    :commit()
end

return FrozenFoodLib
