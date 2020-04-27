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
  return { 'Electricity: Heating' => ['heating', 'electric'],
           'Electricity: Heating Fans/Pumps' => ['heating', 'electric'],
           'Natural Gas: Heating' => ['heating', 'natural_gas'],
           'Propane: Heating' => ['heating', 'lpg'],
           'Fuel Oil: Heating' => ['heating', 'fuel_oil'],
           'Wood: Heating' => ['heating', 'cord_wood'],
           'Wood Pellets: Heating' => ['heating', 'pellet_wood'],
           'Electricity: Cooling' => ['cooling', 'electric'],
           'Electricity: Cooling Fans/Pumps' => ['cooling', 'electric'],
           'Electricity: Hot Water' => ['hot_water', 'electric'],
           'Natural Gas: Hot Water' => ['hot_water', 'natural_gas'],
           'Propane: Hot Water' => ['hot_water', 'lpg'],
           'Fuel Oil: Hot Water' => ['hot_water', 'fuel_oil'],
           'Electricity: Refrigerator' => ['large_appliance', 'electric'],
           'Electricity: Dishwasher' => ['large_appliance', 'electric'],
           'Electricity: Clothes Washer' => ['large_appliance', 'electric'],
           'Electricity: Clothes Dryer' => ['large_appliance', 'electric'],
           'Electricity: Range/Oven' => ['small_appliance', 'electric'],
           'Electricity: Television' => ['small_appliance', 'electric'],
           'Electricity: Plug Loads' => ['small_appliance', 'electric'],
           'Electricity: Lighting Interior' => ['lighting', 'electric'],
           'Electricity: Lighting Garage' => ['lighting', 'electric'],
           'Electricity: Lighting Exterior' => ['lighting', 'electric'],
           'Electricity: PV' => ['generation', 'electric'] }
end
