# frozen_string_literal: true

# Map between HES resource_type and HES units
def get_units_map
  return { 'electric' => 'kWh',
           'natural_gas' => 'kBtu',
           'lpg' => 'kBtu',
           'fuel_oil' => 'kBtu',
           'cord_wood' => 'kBtu',
           'pellet_wood' => 'kBtu',
           'hot_water' => 'gallons' }
end

# Map between reporting measure end use and HEScore [end_use, resource_type]
def get_output_map
  return { 'End Use: Electricity: Heating' => ['heating', 'electric'],
           'End Use: Electricity: Heating Fans/Pumps' => ['heating', 'electric'],
           'End Use: Natural Gas: Heating' => ['heating', 'natural_gas'],
           'End Use: Propane: Heating' => ['heating', 'lpg'],
           'End Use: Fuel Oil: Heating' => ['heating', 'fuel_oil'],
           'End Use: Wood Cord: Heating' => ['heating', 'cord_wood'],
           'End Use: Wood Pellets: Heating' => ['heating', 'pellet_wood'],
           'End Use: Electricity: Cooling' => ['cooling', 'electric'],
           'End Use: Electricity: Cooling Fans/Pumps' => ['cooling', 'electric'],
           'End Use: Electricity: Hot Water' => ['hot_water', 'electric'],
           'End Use: Natural Gas: Hot Water' => ['hot_water', 'natural_gas'],
           'End Use: Propane: Hot Water' => ['hot_water', 'lpg'],
           'End Use: Fuel Oil: Hot Water' => ['hot_water', 'fuel_oil'],
           'End Use: Electricity: Refrigerator' => ['large_appliance', 'electric'],
           'End Use: Electricity: Dishwasher' => ['large_appliance', 'electric'],
           'End Use: Electricity: Clothes Washer' => ['large_appliance', 'electric'],
           'End Use: Electricity: Clothes Dryer' => ['large_appliance', 'electric'],
           'End Use: Electricity: Range/Oven' => ['small_appliance', 'electric'],
           'End Use: Electricity: Television' => ['small_appliance', 'electric'],
           'End Use: Electricity: Plug Loads' => ['small_appliance', 'electric'],
           'End Use: Electricity: Lighting Interior' => ['lighting', 'electric'],
           'End Use: Electricity: Lighting Garage' => ['lighting', 'electric'],
           'End Use: Electricity: Lighting Exterior' => ['lighting', 'electric'],
           'End Use: Electricity: PV' => ['generation', 'electric'],
           'Hot Water: Clothes Washer' => ['hot_water', 'hot_water'],
           'Hot Water: Dishwasher' => ['hot_water', 'hot_water'],
           'Hot Water: Fixtures' => ['hot_water', 'hot_water'],
           'Hot Water: Distribution Waste' => ['hot_water', 'hot_water'] }
end
