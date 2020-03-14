def get_fuel_site_units(hes_resource_type)
  return { 'electric' => 'kWh',
           'natural_gas' => 'kBtu',
           'lpg' => 'kBtu',
           'fuel_oil' => 'kBtu',
           'cord_wood' => 'kBtu',
           'pellet_wood' => 'kBtu',
           'hot_water' => 'gallons' }[hes_resource_type]
end

def get_output_meter_requests
  # Mapping between HEScore output [end_use, resource_type] and a list of E+ output meters
  return {
    # Heating Energy
    ['heating', 'electric'] => ['Heating:Electricity'],
    ['heating', 'natural_gas'] => ['Heating:Gas'],
    ['heating', 'lpg'] => ['Heating:Propane'],
    ['heating', 'fuel_oil'] => ['Heating:FuelOil#1'],
    ['heating', 'cord_wood'] => ['Heating:OtherFuel1'],
    ['heating', 'pellet_wood'] => ['Heating:OtherFuel2'],

    # Cooling Energy
    ['cooling', 'electric'] => ['Cooling:Electricity'],

    # Hot Water Energy
    ['hot_water', 'electric'] => ['WaterSystems:Electricity',
                                  'Fans:Electricity',         # Note: Heating/cooling fan energy is later subtracted out from here
                                  'Pumps:Electricity'],       # Note: Heating/cooling pump energy is later subtracted out from here
    ['hot_water', 'natural_gas'] => ['WaterSystems:Gas'],
    ['hot_water', 'lpg'] => ['WaterSystems:Propane'],
    ['hot_water', 'fuel_oil'] => ['WaterSystems:FuelOil#1'],

    # Large Appliances Energy
    # Note: All large appliances in the HEScore model are currently assumed to be electric.
    # Note: These appliances (intentionally excluding range/oven) are later subtracted out from small appliances.
    ['large_appliance', 'electric'] => ["#{Constants.ObjectNameRefrigerator}:InteriorEquipment:Electricity",
                                        "#{Constants.ObjectNameDishwasher}:InteriorEquipment:Electricity",
                                        "#{Constants.ObjectNameClothesWasher}:InteriorEquipment:Electricity",
                                        "#{Constants.ObjectNameClothesDryer}:InteriorEquipment:Electricity"],

    # Small Appliances Energy
    ['small_appliance', 'electric'] => ['InteriorEquipment:Electricity'],

    # Lighting Energy
    ['lighting', 'electric'] => ['InteriorLights:Electricity',
                                 'ExteriorLights:Electricity'],

    # Circulation Energy
    ['circulation', 'electric'] => [],

    # Generation Energy
    ['generation', 'electric'] => ['ElectricityProduced:Facility'],

    # Hot Water Volume
    ['hot_water', 'hot_water'] => [] # Note: Hot water in gallons is later added via Output Variables
  }
end
