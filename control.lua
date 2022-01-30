
--[[
Spider Trails control script © 2022 by asher_sky is licensed under Attribution-NonCommercial-ShareAlike 4.0 International. See LICENSE.txt for additional information
--]]

local speeds = {
  veryslow = 0.010,
  slow = 0.025,
  default = 0.050,
  fast = 0.100,
  veryfast = 0.200,
}

local palette = {
  light = {amplitude = 15, center = 240},           -- light
  pastel = {amplitude = 55, center = 200},          -- pastel <3
  default = {amplitude = 127.5, center = 127.5},    -- default (nyan)
  vibrant = {amplitude = 50, center = 100},         -- muted
  deep = {amplitude = 25, center = 50},             -- dark
}

local sin = math.sin
local pi_0 = 0 * math.pi / 3
local pi_2 = 2 * math.pi / 3
local pi_4 = 4 * math.pi / 3

function make_rainbow(event_tick, unit_number, settings, frequency, palette_choice)
  -- local frequency = speeds[settings["spidertron-trails-speed"]]
  local modifier = unit_number + event_tick
  -- local palette_choice = palette[settings["spidertron-trails-palette"]]
  local amplitude = palette_choice.amplitude
  local center = palette_choice.center
  return {
    r = sin(frequency*(modifier)+pi_0)*amplitude+center,
    g = sin(frequency*(modifier)+pi_2)*amplitude+center,
    b = sin(frequency*(modifier)+pi_4)*amplitude+center,
    a = 255,
  }
end

local function initialize_settings()
  if not global.settings then
    global.settings = {}
  end
  local settings = settings.global
  global.settings = {}
  global.settings["spidertron-trails-color"] = settings["spidertron-trails-color"].value
  global.settings["spidertron-trails-glow"] = settings["spidertron-trails-glow"].value
  global.settings["spidertron-trails-length"] = settings["spidertron-trails-length"].value
  global.settings["spidertron-trails-scale"] = settings["spidertron-trails-scale"].value
  global.settings["spidertron-trails-color-type"] = settings["spidertron-trails-color-type"].value
  global.settings["spidertron-trails-speed"] = settings["spidertron-trails-speed"].value
  global.settings["spidertron-trails-palette"] = settings["spidertron-trails-palette"].value
  global.settings["spidertron-trails-balance"] = settings["spidertron-trails-balance"].value
  global.settings["spidertron-trails-passengers-only"] = settings["spidertron-trails-passengers-only"].value
  global.settings["spidertron-trails-tiptoe-mode"] = settings["spidertron-trails-tiptoe-mode"].value
end

local function get_all_spiders()
  if not global.spiders then
    global.spiders = {}
  end
  for each, surface in pairs(game.surfaces) do
    local spiders = surface.find_entities_filtered{type={"spider-vehicle"}}
    for every, spider in pairs(spiders) do
      global.spiders[spider.unit_number] = {
        spider = spider,
        legs = spider.get_spider_legs(),
        leg_positions = {}
      }
      for each, leg in pairs(global.spiders[spider.unit_number].legs) do
        global.spiders[spider.unit_number].leg_positions[leg.name] = {
          position = leg.position,
          counter = 1,
        }
      end
    end
  end
end

local function add_spider(event)
  local spider = event.created_entity or event.entity
  global.spiders[spider.unit_number] = {
    spider = spider,
    legs = spider.get_spider_legs(),
    leg_positions = {}
  }
  for each, leg in pairs(global.spiders[spider.unit_number].legs) do
    global.spiders[spider.unit_number].leg_positions[leg.name] = {
      position = leg.position,
      counter = 1,
    }
  end
end

script.on_event(defines.events.on_built_entity, function(event)
  add_spider(event)
end,
{{filter = "type", type = "spider-vehicle"}})

script.on_event(defines.events.on_robot_built_entity, function(event)
  add_spider(event)
end,
{{filter = "type", type = "spider-vehicle"}})

script.on_event(defines.events.script_raised_built, function(event)
  add_spider(event)
end,
{{filter = "type", type = "spider-vehicle"}})

script.on_event(defines.events.on_runtime_mod_setting_changed, function()
  initialize_settings()
end)

script.on_configuration_changed(function()
  initialize_settings()
  get_all_spiders()
end)

script.on_init(function()
  initialize_settings()
  get_all_spiders()
end)

local function make_trails(settings, event)
  local sprite = settings["spidertron-trails-color"]
  local light = settings["spidertron-trails-glow"]
  if sprite or light then
    local length = tonumber(settings["spidertron-trails-length"])
    local scale = tonumber(settings["spidertron-trails-scale"])
    local color_mode = settings["spidertron-trails-color-type"]
    local passengers_only = settings["spidertron-trails-passengers-only"]
    local frequency = speeds[settings["spidertron-trails-speed"]]
    local palette_choice = palette[settings["spidertron-trails-palette"]]
    local tiptoe_mode = settings["spidertron-trails-tiptoe-mode"]
    local groups = global.spiders
    if groups then
      for unit_number, spider_group in pairs(groups) do
        local spider = spider_group.spider
        if not spider.valid then
          global.spiders[unit_number] = nil
        else
          if (spider.speed ~= 0) then
            local passengers = false
            if passengers_only then
              if spider.passengers[1] then
                passengers = true
              end
            end
            if passengers or (not passengers_only) then
              local event_tick = event.tick
              local color = {}
              if color_mode == "spidertron" then
                color = spider.color
                color.a = 1
              else
                color = make_rainbow(event_tick, unit_number, settings, frequency, palette_choice)
              end
              for each, leg in pairs(spider_group.legs) do
                local leg_name = leg.name
                local leg_position = spider_group.leg_positions[leg_name]
                local last_position = leg_position.position
                local counter = leg_position.counter
                local current_position = leg.position
                local leg_surface = leg.surface
                local same_position = last_position and (last_position.x == current_position.x) and (last_position.y == current_position.y)
                local counter_is_less_than_goal = counter and (counter < 15)
                if ((not same_position) and (not tiptoe_mode)) or (same_position and counter_is_less_than_goal) then
                  if sprite then
                    sprite = rendering.draw_sprite{
                      sprite = "spidertron-trail",
                      target = current_position,
                      surface = leg_surface,
                      x_scale = scale,
                      y_scale = scale,
                      render_layer = "radius-visualization",
                      time_to_live = length,
                      tint = color,
                    }
                  end
                  if light then
                    light = rendering.draw_light{
                      sprite = "spidertron-trail",
                      target = current_position,
                      surface = leg_surface,
                      intensity = .175,
                      scale = scale * 1.75,
                      render_layer = "light-effect",
                      time_to_live = length,
                      color = color,
                    }
                  end
                end
                global.spiders[unit_number].leg_positions[leg_name].position = current_position
                if counter and counter < 15 then
                  global.spiders[unit_number].leg_positions[leg_name].counter = counter + 1
                else
                  global.spiders[unit_number].leg_positions[leg_name].counter = 1
                end
              end
            end
          end
        end
      end
    end
  end
end

script.on_event(defines.events.on_tick, function(event)
  if not global.settings then
    initialize_settings()
  end
  local settings = global.settings
  if settings["spidertron-trails-balance"] == "super-pretty" then
    make_trails(settings, event)
  end
end)

script.on_nth_tick(2, function(event)
  local settings = global.settings
  if settings["spidertron-trails-balance"] == "pretty" then
    make_trails(settings, event)
  end
end)

script.on_nth_tick(3, function(event)
  local settings = global.settings
  if settings["spidertron-trails-balance"] == "balanced" then
    make_trails(settings, event)
  end
end)

script.on_nth_tick(4, function(event)
  local settings = global.settings
  if settings["spidertron-trails-balance"] == "performance" then
    make_trails(settings, event)
  end
end)
