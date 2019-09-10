def get_fuel_site_units(hes_resource_type)
  return { :electric => 'kWh',
           :natural_gas => 'kBtu',
           :lpg => 'kBtu',
           :fuel_oil => 'kBtu',
           :cord_wood => 'kBtu',
           :pellet_wood => 'kBtu',
           :hot_water => 'gallons' }[hes_resource_type]
end

def get_output_meter_requests
  # Mapping between HEScore output [end_use, resource_type] and a list of E+ output meters
  return {
    # Heating
    [:heating, :electric] => ["Heating:Electricity"],
    [:heating, :natural_gas] => ['Heating:Gas'],
    [:heating, :lpg] => ['Heating:Propane'],
    [:heating, :fuel_oil] => ['Heating:FuelOil#1'],
    [:heating, :cord_wood] => ['Heating:OtherFuel1'],
    [:heating, :pellet_wood] => ['Heating:OtherFuel2'],

    # Cooling
    [:cooling, :electric] => ["Cooling:Electricity"],

    # Hot Water
    [:hot_water, :electric] => ["WaterSystems:Electricity",
                                "Fans:Electricity",         # E.g., HPWH fan energy. Note: Heating and cooling fan/pump is subtracted out from here
                                "Pumps:Electricity"],       # E.g., Combi boiler pump energy for hot water. Note: Heating and cooling fan/pump is subtracted out from here
    [:hot_water, :natural_gas] => ["WaterSystems:Gas"],
    [:hot_water, :lpg] => ["WaterSystems:Propane"],
    [:hot_water, :fuel_oil] => ["WaterSystems:FuelOil#1"],

    # Large Appliances
    [:large_appliance, :electric] => ["#{Constants.ObjectNameRefrigerator}:InteriorEquipment:Electricity",
                                      "#{Constants.ObjectNameDishwasher}:InteriorEquipment:Electricity",
                                      "#{Constants.ObjectNameClothesWasher}:InteriorEquipment:Electricity",
                                      "#{Constants.ObjectNameClothesDryer}:InteriorEquipment:Electricity",
                                      "#{Constants.ObjectNameCookingRange}:InteriorEquipment:Electricity"],

    # Small Appliances
    # Note: large appliances are subtracted out from small appliances later
    [:small_appliance, :electric] => ["InteriorEquipment:Electricity"],

    # Lighting
    [:lighting, :electric] => ["InteriorLights:Electricity",
                               "ExteriorLights:Electricity"],

    # Circulation
    [:circulation, :electric] => [],

    # Generation
    [:generation, :electric] => ["ElectricityProduced:Facility"],

    # Hot Water
    # Note: Added later from Output Variables
    [:hot_water, :hot_water] => []
  }
end
