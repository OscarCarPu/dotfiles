-- Default-sink order: headphones > BT speakers > TV (if plugged) > dock screens > computer.
-- Runs between find-best-default-node and apply-default-node.

log = Log.open_topic ("s-default-nodes")
cutils = require ("common-utils")
nutils = require ("node-utils")

local INTEL_CARD = "alsa_card.pci-0000_00_1f.3"
local HP_FORM_FACTORS = { headphone = true, headset = true, ["hands-free"] = true }

local function device_by_id (id)
  if not id then return nil end
  return cutils.get_object_manager ("device"):lookup {
    Constraint { "bound-id", "=", id, type = "gobject" },
  }
end

-- active Route of the device that carries this node
local function active_route (node_props)
  local dev = device_by_id (node_props ["device.id"])
  local cpd = tonumber (node_props ["card.profile.device"])
  if not dev or not cpd then return nil end
  for p in dev:iterate_params ("Route") do
    local r = cutils.parseParam (p, "Route")
    if r and r.device == cpd then return r end
  end
end

local function hdmi_plugged ()
  local dev = cutils.get_object_manager ("device"):lookup {
    Constraint { "device.name", "=", INTEL_CARD },
  }
  if not dev then return false end
  for p in dev:iterate_params ("EnumRoute") do
    local r = cutils.parseParam (p, "EnumRoute")
    if r and r.name and r.name:find ("^hdmi%-output") and r.available == "yes" then
      return true
    end
  end
  return false
end

local function tier (np, hdmi)
  local name = np ["node.name"] or ""

  if name:find ("^bluez_output%.") then
    local dev = device_by_id (np ["device.id"])
    local ff = dev and dev.properties ["device.form-factor"]
    return HP_FORM_FACTORS [ff] and 4 or 3
  end

  if name:find ("^alsa_output%.pci%-") then
    local r = active_route (np)
    -- fallback if 3.0a shows the port doesn't flip: check that the speaker
    -- route is "no" via EnumRoute instead
    if r and r.name == "analog-output-headphones" and r.available ~= "no" then
      return 4
    end
    return 1
  end

  if name == "alsa_output.hdmi-tv" then
    return hdmi and 2.5 or 0
  end

  if name:find ("^alsa_output%.usb%-DisplayLink") then
    return 2
  end

  return 0
end

SimpleEventHook {
  name = "custom/audio-order",
  after = "default-nodes/find-best-default-node",
  before = "default-nodes/apply-default-node",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "select-default-node" },
      Constraint { "default-node.type", "=", "audio.sink" },
    },
  },
  execute = function (event)
    -- user picked a sink by hand (find-selected adds 30000): respect it
    if (event:get_data ("selected-node-priority") or 0) >= 30000 then
      return
    end

    local nodes = event:get_data ("available-nodes")
    nodes = nodes and nodes:parse ()
    if not nodes then return end

    local hdmi = hdmi_plugged ()
    local best, best_tier, best_rank = nil, 0, nil
    for _, np in ipairs (nodes) do
      if np ["media.class"] == "Audio/Sink" then
        local t = tier (np, hdmi)
        local rank = nutils.get_node_ranking (np)
        if t > best_tier or
           (t == best_tier and t > 0 and nutils.compare_nodes (rank, best_rank)) then
          best, best_tier, best_rank = np ["node.name"], t, rank
        end
      end
    end

    if best then
      log:info ("audio-order: tier " .. best_tier .. " -> " .. best)
      event:set_data ("selected-node", best)
    end
  end
}:register ()
