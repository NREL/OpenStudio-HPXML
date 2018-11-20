require "#{File.dirname(__FILE__)}/../../HPXMLtoOpenStudio/resources/airflow"
require "#{File.dirname(__FILE__)}/../../HPXMLtoOpenStudio/resources/geometry"
require "#{File.dirname(__FILE__)}/../../HPXMLtoOpenStudio/resources/xmlhelper"

class HEScoreRuleset
  def self.apply_ruleset(hpxml_doc)
    building = hpxml_doc.elements["/HPXML/Building"]

    # Create new BuildingDetails element
    orig_details = XMLHelper.delete_element(building, "BuildingDetails")
    new_details = XMLHelper.add_element(building, "BuildingDetails")

    # Global variables
    @nbeds = Float(XMLHelper.get_value(orig_details, "BuildingSummary/BuildingConstruction/NumberofBedrooms"))
    @cfa = Float(XMLHelper.get_value(orig_details, "BuildingSummary/BuildingConstruction/ConditionedFloorArea"))
    @ncfl_ag = Float(XMLHelper.get_value(orig_details, "BuildingSummary/BuildingConstruction/NumberofConditionedFloorsAboveGrade"))
    @ncfl = @ncfl_ag # Number above-grade stories plus any conditioned basement
    if not XMLHelper.get_value(orig_details, "Enclosure/Foundations/Foundation/FoundationType/Basement[Conditioned='true']").nil?
      @ncfl += 1
    end
    @nfl = @ncfl_ag # Number above-grade stories plus any basement
    if not XMLHelper.get_value(orig_details, "Enclosure/Foundations/Foundation/FoundationType/Basement").nil?
      @nfl += 1
    end

    # BuildingSummary
    new_summary = XMLHelper.add_element(new_details, "BuildingSummary")
    set_summary(new_summary, orig_details)

    # ClimateAndRiskZones
    XMLHelper.copy_element(new_details, orig_details, "ClimateandRiskZones")

    # Enclosure
    new_enclosure = XMLHelper.add_element(new_details, "Enclosure")
    set_enclosure_air_infiltration(new_enclosure, orig_details)
    set_enclosure_attics_roofs(new_enclosure, orig_details)
    set_enclosure_foundations(new_enclosure, orig_details)
    set_enclosure_rim_joists(new_enclosure, orig_details)
    set_enclosure_walls(new_enclosure, orig_details)
    set_enclosure_windows(new_enclosure, orig_details)
    set_enclosure_skylights(new_enclosure)
    set_enclosure_doors(new_enclosure, orig_details)

    # Systems
    new_systems = XMLHelper.add_element(new_details, "Systems")
    set_systems_hvac(new_systems, orig_details)
    set_systems_mechanical_ventilation(new_systems, orig_details)
    set_systems_water_heater(new_systems, orig_details)
    set_systems_water_heating_use(new_systems, orig_details)
    set_systems_photovoltaics(new_systems, orig_details)

    # Appliances
    new_appliances = XMLHelper.add_element(new_details, "Appliances")
    set_appliances_clothes_washer(new_appliances, orig_details)
    set_appliances_clothes_dryer(new_appliances, orig_details)
    set_appliances_dishwasher(new_appliances, orig_details)
    set_appliances_refrigerator(new_appliances, orig_details)
    set_appliances_cooking_range_oven(new_appliances, orig_details)

    # Lighting
    new_lighting = XMLHelper.add_element(new_details, "Lighting")
    set_lighting(new_lighting, orig_details)
    set_ceiling_fans(new_lighting, orig_details)
  end

  def self.set_summary(new_summary, orig_details)
    new_site = XMLHelper.add_element(new_summary, "Site")
    orig_site = orig_details.elements["BuildingSummary/Site"]
    XMLHelper.copy_element(new_site, orig_site, "FuelTypesAvailable") # FIXME: Need assumption
    extension = XMLHelper.add_element(new_site, "extension")
    XMLHelper.add_element(extension, "ShelterCoefficient", Airflow.get_default_shelter_coefficient())

    new_occupancy = XMLHelper.add_element(new_summary, "BuildingOccupancy")
    orig_occupancy = orig_details.elements["BuildingSummary/BuildingOccupancy"]
    XMLHelper.add_element(new_occupancy, "NumberofResidents", Geometry.get_occupancy_default_num(@nbeds))

    new_construction = XMLHelper.add_element(new_summary, "BuildingConstruction")
    orig_construction = orig_details.elements["BuildingSummary/BuildingConstruction"]
    XMLHelper.add_element(new_construction, "NumberofConditionedFloors", @ncfl)
    XMLHelper.add_element(new_construction, "NumberofConditionedFloorsAboveGrade", @ncfl_ag)
    XMLHelper.add_element(new_construction, "NumberofBedrooms", Integer(@nbeds))
    XMLHelper.add_element(new_construction, "ConditionedFloorArea", @cfa)
    XMLHelper.add_element(new_construction, "ConditionedBuildingVolume", @cfa * 8.0) # FIXME: Hard-coded
    XMLHelper.add_element(new_construction, "GaragePresent", false)
  end

  def self.set_enclosure_air_infiltration(new_enclosure, orig_details)
    cfm50 = XMLHelper.get_value(orig_details, "Enclosure/AirInfiltration/AirInfiltrationMeasurement[HousePressure='50']/BuildingAirLeakage[UnitofMeasure='CFM']/AirLeakage")
    desc = XMLHelper.get_value(orig_details, "Enclosure/AirInfiltration/AirInfiltrationMeasurement/LeakinessDescription")

    if not cfm50.nil?
      cfm50 = Float(cfm50)
    else
      # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/infiltration/infiltration
      if desc == "tight"
        # TODO
      elsif desc == "average"
        # TODO
      end
    end

    # TODO
  end

  def self.set_enclosure_attics_roofs(new_enclosure, orig_details)
    # TODO
  end

  def self.set_enclosure_foundations(new_enclosure, orig_details)
    # TODO
  end

  def self.set_enclosure_rim_joists(new_enclosure, orig_details)
    # No rim joists
  end

  def self.set_enclosure_walls(new_enclosure, orig_details)
    # TODO
  end

  def self.set_enclosure_windows(new_enclosure, orig_details)
    # TODO
  end

  def self.set_enclosure_skylights(new_enclosure)
    # TODO
  end

  def self.set_enclosure_doors(new_enclosure, orig_details)
    # TODO
  end

  def self.set_systems_hvac(new_systems, orig_details)
    new_hvac = XMLHelper.add_element(new_systems, "HVAC")
    new_hvac_plant = XMLHelper.add_element(new_hvac, "HVACPlant")

    # HeatingSystem
    orig_details.elements.each("Systems/HVAC/HVACPlant/HeatingSystem") do |orig_heating|
      hvac_type = orig_heating.elements["HeatingSystemType"].elements[1].name
      hvac_fuel = XMLHelper.get_value(orig_heating, "HeatingSystemFuel")

      new_heating = XMLHelper.add_element(new_hvac_plant, "HeatingSystem")
      XMLHelper.copy_element(new_heating, orig_heating, "SystemIdentifier")
      XMLHelper.copy_element(new_heating, orig_heating, "DistributionSystem")
      XMLHelper.copy_element(new_heating, orig_heating, "HeatingSystemType")
      XMLHelper.add_element(new_heating, "HeatingSystemFuel", hvac_fuel)
      XMLHelper.add_element(new_heating, "HeatingCapacity", -1) # Use Manual J auto-sizing
      heat_eff = XMLHelper.add_element(new_heating, "AnnualHeatingEfficiency")
      if ["Furnace", "WallFurnace", "Boiler"].include? hvac_type
        hvac_year = XMLHelper.get_value(orig_heating, "YearInstalled")
        hvac_afue = XMLHelper.get_value(orig_heating, "AnnualHeatingEfficiency[Units='AFUE']/Value")

        if not hvac_year.nil?
          if ["Furnace", "WallFurnace"].include? hvac_type
            hvac_afue = get_default_furnace_afue(Integer(hvac_year), hvac_type, hvac_fuel)
          else
            hvac_afue = get_default_boiler_afue(Integer(hvac_year), hvac_type, hvac_fuel)
          end
        else
          hvac_afue = Float(hvac_afue)
        end

        XMLHelper.add_element(heat_eff, "Units", "AFUE")
        XMLHelper.add_element(heat_eff, "Value", hvac_afue)
      else
        # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/heating-and-cooling-equipment/heating-and-cooling-equipment-efficiencies
        if hvac_type == "ElectricResistance"
          XMLHelper.add_element(heat_eff, "Units", "Percent")
          XMLHelper.add_element(heat_eff, "Value", 0.98) # FIXME: Verify
        elsif hvac_type == "Stove"
          XMLHelper.add_element(heat_eff, "Units", "Percent")
          if hvac_fuel == "wood"
            XMLHelper.add_element(heat_eff, "Value", 0.60) # FIXME: Verify
          elsif hvac_fuel == "wood pellets"
            XMLHelper.add_element(heat_eff, "Value", 0.78) # FIXME: Verify
          end
        end
      end
      XMLHelper.copy_element(new_heating, orig_heating, "FractionHeatLoadServed")
    end

    # CoolingSystem
    orig_details.elements.each("Systems/HVAC/HVACPlant/CoolingSystem") do |orig_cooling|
      hvac_type = XMLHelper.get_value(orig_cooling, "CoolingSystemType")

      new_cooling = XMLHelper.add_element(new_hvac_plant, "CoolingSystem")
      XMLHelper.copy_element(new_cooling, orig_cooling, "SystemIdentifier")
      XMLHelper.copy_element(new_cooling, orig_cooling, "DistributionSystem")
      XMLHelper.add_element(new_cooling, "CoolingSystemType", hvac_type)
      XMLHelper.add_element(new_cooling, "CoolingSystemFuel", "electricity")
      XMLHelper.add_element(new_cooling, "CoolingCapacity", -1) # Use Manual J auto-sizing
      XMLHelper.copy_element(new_cooling, orig_cooling, "FractionCoolLoadServed")
      cool_eff = XMLHelper.add_element(new_cooling, "AnnualCoolingEfficiency")
      if hvac_type == "central air conditioning"
        hvac_year = XMLHelper.get_value(orig_cooling, "YearInstalled")
        hvac_seer = XMLHelper.get_value(orig_cooling, "AnnualCoolingEfficiency[Units='SEER']/Value")

        if not hvac_year.nil?
          hvac_seer = get_default_central_ac_seer(Integer(hvac_year))
        else
          hvac_seer = Float(hvac_seer)
        end

        XMLHelper.add_element(cool_eff, "Units", "SEER")
        XMLHelper.add_element(cool_eff, "Value", hvac_seer)
      elsif hvac_type == "room air conditioning"
        hvac_year = XMLHelper.get_value(orig_cooling, "YearInstalled")
        hvac_eer = XMLHelper.get_value(orig_cooling, "AnnualCoolingEfficiency[Units='EER']/Value")

        if not hvac_year.nil?
          hvac_eer = get_default_room_ac_eer(Integer(hvac_year))
        else
          hvac_eer = Float(hvac_eer)
        end

        XMLHelper.add_element(cool_eff, "Units", "EER")
        XMLHelper.add_element(cool_eff, "Value", hvac_eer)
      end
    end

    # HeatPump
    orig_details.elements.each("Systems/HVAC/HVACPlant/HeatPump") do |orig_hp|
      hvac_type = XMLHelper.get_value(orig_hp, "HeatPumpType")

      new_hp = XMLHelper.add_element(new_hvac_plant, "HeatPump")
      XMLHelper.copy_element(new_hp, orig_hp, "SystemIdentifier")
      XMLHelper.copy_element(new_hp, orig_hp, "DistributionSystem")
      XMLHelper.add_element(new_hp, "HeatPumpType", hvac_type)
      XMLHelper.add_element(new_hp, "HeatingCapacity", -1) # Use Manual J auto-sizing
      XMLHelper.add_element(new_hp, "CoolingCapacity", -1) # Use Manual J auto-sizing
      XMLHelper.copy_element(new_hp, orig_hp, "FractionHeatLoadServed")
      XMLHelper.copy_element(new_hp, orig_hp, "FractionCoolLoadServed")
      cool_eff = XMLHelper.add_element(new_hp, "AnnualCoolingEfficiency")
      heat_eff = XMLHelper.add_element(new_hp, "AnnualHeatingEfficiency")
      if ["air-to-air", "mini-split"].include? hvac_type
        hvac_year = XMLHelper.get_value(orig_hp, "YearInstalled")
        hvac_seer = XMLHelper.get_value(orig_hp, "AnnualCoolingEfficiency[Units='SEER']/Value")
        hvac_hspf = XMLHelper.get_value(orig_hp, "AnnualHeatingEfficiency[Units='HSPF']/Value")

        if not hvac_year.nil?
          hvac_seer, hvac_hspf = get_default_ashp_seer_hspf(Integer(hvac_year))
        else
          hvac_seer = Float(hvac_seer)
          hvac_hspf = Float(hvac_hspf)
        end

        XMLHelper.add_element(cool_eff, "Units", "SEER")
        XMLHelper.add_element(cool_eff, "Value", hvac_seer)
        XMLHelper.add_element(heat_eff, "Units", "HSPF")
        XMLHelper.add_element(heat_eff, "Value", hvac_hspf)
      elsif hvac_type == "ground-to-air"
        hvac_year = XMLHelper.get_value(orig_hp, "YearInstalled")
        hvac_eer = XMLHelper.get_value(orig_hp, "AnnualCoolingEfficiency[Units='EER']/Value")
        hvac_cop = XMLHelper.get_value(orig_hp, "AnnualHeatingEfficiency[Units='COP']/Value")

        if not hvac_year.nil?
          hvac_eer, hvac_cop = get_default_gshp_eer_cop(Integer(hvac_year))
        else
          hvac_eer = Float(hvac_eer)
          hvac_cop = Float(hvac_cop)
        end

        XMLHelper.add_element(cool_eff, "Units", "EER")
        XMLHelper.add_element(cool_eff, "Value", hvac_eer)
        XMLHelper.add_element(heat_eff, "Units", "COP")
        XMLHelper.add_element(heat_eff, "Value", hvac_cop)
      end
    end

    # HVACControl
    new_hvac_control = XMLHelper.add_element(new_hvac, "HVACControl")
    sys_id = XMLHelper.add_element(new_hvac_control, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "HVACControl")
    XMLHelper.add_element(new_hvac_control, "ControlType", "manual thermostat")

    # HVACDistribution
    orig_details.elements.each("Systems/HVAC/HVACDistribution") do |orig_dist|
      ducts_sealed = Boolean(XMLHelper.get_value(orig_dist, "HVACDistributionImprovement/DuctSystemSealed"))

      # Leakage fraction of total air handler flow
      # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/thermal-distribution-efficiency/thermal-distribution-efficiency
      # FIXME: Total or to the outside?
      if ducts_sealed
        leakage_frac = 0.03
      else
        leakage_frac = 0.15
      end

      # Surface areas outside conditioned space
      # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/thermal-distribution-efficiency/thermal-distribution-efficiency
      supply_duct_area = 0.27 * @cfa
      return_duct_area = 0.05 * @nfl * @cfa

      new_dist = XMLHelper.add_element(new_hvac, "HVACDistribution")
      XMLHelper.copy_element(new_dist, orig_dist, "SystemIdentifier")

      # Supply duct leakage
      new_supply_measurement = XMLHelper.add_element(new_dist, "DistributionSystemType/AirDistribution/DuctLeakageMeasurement")
      XMLHelper.add_element(new_supply_measurement, "DuctType", "supply")
      new_supply_leakage = XMLHelper.add_element(new_supply_measurement, "DuctLeakage")
      XMLHelper.add_element(new_supply_leakage, "Units", "CFM25")
      XMLHelper.add_element(new_supply_leakage, "Value", 100) # FIXME: Hard-coded
      XMLHelper.add_element(new_supply_leakage, "TotalOrToOutside", "to outside") # FIXME: Hard-coded

      # Return duct leakage
      new_return_measurement = XMLHelper.add_element(new_dist, "DistributionSystemType/AirDistribution/DuctLeakageMeasurement")
      XMLHelper.add_element(new_return_measurement, "DuctType", "return")
      new_return_leakage = XMLHelper.add_element(new_return_measurement, "DuctLeakage")
      XMLHelper.add_element(new_return_leakage, "Units", "CFM25")
      XMLHelper.add_element(new_return_leakage, "Value", 100) # FIXME: Hard-coded
      XMLHelper.add_element(new_return_leakage, "TotalOrToOutside", "to outside") # FIXME: Hard-coded

      orig_dist.elements.each("DistributionSystemType/AirDistribution/Ducts") do |orig_duct|
        duct_location = XMLHelper.get_value(orig_duct, "DuctLocation")
        duct_frac_area = Float(XMLHelper.get_value(orig_duct, "FractionDuctArea"))
        duct_rvalue = Float(XMLHelper.get_value(orig_duct, "extension/hescore_ducts_insulated")) # FIXME: Why not use DuctInsulationRValue?

        next if duct_location == "conditioned space"

        # Supply duct
        new_supply_duct = XMLHelper.add_element(new_dist, "DistributionSystemType/AirDistribution/Ducts")
        XMLHelper.add_element(new_supply_duct, "DuctType", "supply")
        XMLHelper.add_element(new_supply_duct, "DuctInsulationRValue", duct_rvalue)
        XMLHelper.add_element(new_supply_duct, "DuctLocation", duct_location)
        XMLHelper.add_element(new_supply_duct, "DuctSurfaceArea", duct_frac_area * supply_duct_area)

        # Return duct
        new_return_duct = XMLHelper.add_element(new_dist, "DistributionSystemType/AirDistribution/Ducts")
        XMLHelper.add_element(new_supply_duct, "DuctType", "return")
        XMLHelper.add_element(new_return_duct, "DuctInsulationRValue", duct_rvalue)
        XMLHelper.add_element(new_return_duct, "DuctLocation", duct_location)
        XMLHelper.add_element(new_return_duct, "DuctSurfaceArea", duct_frac_area * return_duct_area)
      end
    end
  end

  def self.set_systems_mechanical_ventilation(new_systems, orig_details)
    # No mechanical ventilation
  end

  def self.set_systems_water_heater(new_systems, orig_details)
    new_water_heating = XMLHelper.add_element(new_systems, "WaterHeating")

    orig_details.elements.each("Systems/WaterHeating/WaterHeatingSystem") do |orig_wh_sys|
      wh_year = XMLHelper.get_value(orig_wh_sys, "YearInstalled")
      wh_ef = XMLHelper.get_value(orig_wh_sys, "EnergyFactor")
      wh_fuel = XMLHelper.get_value(orig_wh_sys, "FuelType")
      wh_type = XMLHelper.get_value(orig_wh_sys, "WaterHeaterType")

      if not wh_year.nil?
        wh_ef = get_default_water_heater_ef(Integer(wh_year), wh_fuel)
      else
        wh_ef = Float(wh_ef)
      end

      new_wh_sys = XMLHelper.add_element(new_water_heating, "WaterHeatingSystem")
      XMLHelper.copy_element(new_wh_sys, orig_wh_sys, "SystemIdentifier")
      XMLHelper.add_element(new_wh_sys, "FuelType", wh_fuel)
      XMLHelper.add_element(new_wh_sys, "WaterHeaterType", wh_type)
      XMLHelper.add_element(new_wh_sys, "Location", "conditioned space") # FIXME: Verify
      XMLHelper.add_element(new_wh_sys, "TankVolume", get_default_water_heater_volume(wh_fuel))
      XMLHelper.add_element(new_wh_sys, "FractionDHWLoadServed", 1.0)
      if wh_type == "storage water heater"
        XMLHelper.add_element(new_wh_sys, "HeatingCapacity", get_default_water_heater_capacity(wh_fuel))
      end
      XMLHelper.add_element(new_wh_sys, "EnergyFactor", wh_ef)
      if wh_type == "storage water heater" and XMLHelper.get_value(orig_wh_sys, "FuelType") != "electricity"
        XMLHelper.add_element(new_wh_sys, "RecoveryEfficiency", get_default_water_heater_re(wh_fuel))
      end
    end
  end

  def self.set_systems_water_heating_use(new_systems, orig_details)
    new_water_heating = new_systems.elements["WaterHeating"]

    new_hw_dist = XMLHelper.add_element(new_water_heating, "HotWaterDistribution")
    sys_id = XMLHelper.add_element(new_hw_dist, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "HotWaterDistribution")
    XMLHelper.add_element(new_hw_dist, "SystemType/Standard") # FIXME: Verify
    XMLHelper.add_element(new_hw_dist, "PipeInsulation/PipeRValue", 0) # FIXME: Verify

    new_fixture = XMLHelper.add_element(new_water_heating, "WaterFixture")
    sys_id = XMLHelper.add_element(new_fixture, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "ShowerHead")
    XMLHelper.add_element(new_fixture, "WaterFixtureType", "shower head")
    XMLHelper.add_element(new_fixture, "LowFlow", false) # FIXME: Verify
  end

  def self.set_systems_photovoltaics(new_systems, orig_details)
    pv_power = XMLHelper.get_value(orig_details, "Systems/Photovoltaics/PVSystem/MaxPowerOutput")
    pv_num_panels = XMLHelper.get_value(orig_details, "Systems/Photovoltaics/PVSystem/extension/hescore_num_panels")
    pv_orientation = XMLHelper.get_value(orig_details, "Systems/Photovoltaics/PVSystem/ArrayOrientation")

    if not pv_power.nil?
      pv_power = Float(pv_power)
    else
      pv_power = 3000.0 # FIXME: Hard-coded
    end

    new_pvs = XMLHelper.add_element(new_systems, "Photovoltaics")
    new_pv = XMLHelper.add_element(new_pvs, "PVSystem")
    sys_id = XMLHelper.add_element(new_pv, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "PVSystem")
    XMLHelper.add_element(new_pv, "ModuleType", "standard") # From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
    XMLHelper.add_element(new_pv, "ArrayType", "fixed roof mount") # FIXME: Verify. HEScore was using "fixed open rack"??
    XMLHelper.add_element(new_pv, "ArrayAzimuth", orientation_to_azimuth(pv_orientation))
    XMLHelper.add_element(new_pv, "ArrayTilt", 30) # From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
    XMLHelper.add_element(new_pv, "MaxPowerOutput", pv_power)
    XMLHelper.add_element(new_pv, "InverterEfficiency", 0.96) # From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
    XMLHelper.add_element(new_pv, "SystemLossesFraction", 0.14) # FIXME: Verify
  end

  def self.set_appliances_clothes_washer(new_appliances, orig_details)
    new_washer = XMLHelper.add_element(new_appliances, "ClothesWasher")
    sys_id = XMLHelper.add_element(new_washer, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "ClothesWasher")

    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_clothes_dryer(new_appliances, orig_details)
    new_dryer = XMLHelper.add_element(new_appliances, "ClothesDryer")
    sys_id = XMLHelper.add_element(new_dryer, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "ClothesDryer")
    XMLHelper.add_element(new_dryer, "FuelType", "electricity") # FIXME: Verify

    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_dishwasher(new_appliances, orig_details)
    new_dishwasher = XMLHelper.add_element(new_appliances, "Dishwasher")
    sys_id = XMLHelper.add_element(new_dishwasher, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "Dishwasher")

    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_refrigerator(new_appliances, orig_details)
    new_fridge = XMLHelper.add_element(new_appliances, "Refrigerator")
    sys_id = XMLHelper.add_element(new_fridge, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "Refrigerator")

    # Uses ERI Reference Home for performance
  end

  def self.set_appliances_cooking_range_oven(new_appliances, orig_details)
    new_range = XMLHelper.add_element(new_appliances, "CookingRange")
    sys_id = XMLHelper.add_element(new_range, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "CookingRange")
    XMLHelper.add_element(new_range, "FuelType", "electricity") # FIXME: Verify

    new_oven = XMLHelper.add_element(new_appliances, "Oven")
    sys_id = XMLHelper.add_element(new_oven, "SystemIdentifier")
    XMLHelper.add_attribute(sys_id, "id", "Oven")

    # Uses ERI Reference Home for performance
  end

  def self.set_lighting(new_lighting, orig_details)
    # Uses ERI Reference Home
  end

  def self.set_ceiling_fans(new_lighting, orig_details)
    # No ceiling fans
  end
end

# TODO: Pull out methods below and make available for ERI use case

def get_default_furnace_afue(year, fuel)
  # FIXME: Verify
  # ANSI/RESNET/ICC 301 - Table 4.4.2(3) Default Values for Mechanical System Efficiency (Age-based)
  ending_years = [1959, 1969, 1974, 1983, 1987, 1991, 2005, 9999]
  default_afues = { "electricity" => [0.98, 0.98, 0.98, 0.98, 0.98, 0.98, 0.98, 0.98],
                    "natural gas" => [0.72, 0.72, 0.72, 0.72, 0.72, 0.76, 0.78, 0.78],
                    "propane" => [0.72, 0.72, 0.72, 0.72, 0.72, 0.76, 0.78, 0.78],
                    "fuel oil" => [0.60, 0.65, 0.72, 0.75, 0.80, 0.80, 0.80, 0.80] }[fuel]
  ending_years.zip(default_afues).each do |ending_year, default_afue|
    next if year > ending_year

    return default_afue
  end
  return nil
end

def get_default_boiler_afue(year, fuel)
  # FIXME: Verify
  # ANSI/RESNET/ICC 301 - Table 4.4.2(3) Default Values for Mechanical System Efficiency (Age-based)
  ending_years = [1959, 1969, 1974, 1983, 1987, 1991, 2005, 9999]
  default_afues = { "electricity" => [0.98, 0.98, 0.98, 0.98, 0.98, 0.98, 0.98, 0.98],
                    "natural gas" => [0.60, 0.60, 0.65, 0.65, 0.70, 0.77, 0.80, 0.80],
                    "propane" => [0.60, 0.60, 0.65, 0.65, 0.70, 0.77, 0.80, 0.80],
                    "fuel oil" => [0.60, 0.65, 0.72, 0.75, 0.80, 0.80, 0.80, 0.80] }[fuel]
  ending_years.zip(default_afues).each do |ending_year, default_afue|
    next if year > ending_year

    return default_afue
  end
  return nil
end

def get_default_central_ac_seer(year)
  # FIXME: Verify
  # ANSI/RESNET/ICC 301 - Table 4.4.2(3) Default Values for Mechanical System Efficiency (Age-based)
  ending_years = [1959, 1969, 1974, 1983, 1987, 1991, 2005, 9999]
  default_seers = [9.0, 9.0, 9.0, 9.0, 9.0, 9.40, 10.0, 13.0]
  ending_years.zip(default_seers).each do |ending_year, default_seer|
    next if year > ending_year

    return default_seer
  end
  return nil
end

def get_default_room_ac_eer(year)
  # FIXME: Verify
  # ANSI/RESNET/ICC 301 - Table 4.4.2(3) Default Values for Mechanical System Efficiency (Age-based)
  ending_years = [1959, 1969, 1974, 1983, 1987, 1991, 2005, 9999]
  default_eers = [8.0, 8.0, 8.0, 8.0, 8.0, 8.10, 8.5, 8.5]
  ending_years.zip(default_eers).each do |ending_year, default_eer|
    next if year > ending_year

    return default_eer
  end
  return nil
end

def get_default_ashp_seer_hspf(year)
  # FIXME: Verify
  # ANSI/RESNET/ICC 301 - Table 4.4.2(3) Default Values for Mechanical System Efficiency (Age-based)
  ending_years = [1959, 1969, 1974, 1983, 1987, 1991, 2005, 9999]
  default_seers = [9.0, 9.0, 9.0, 9.0, 9.0, 9.40, 10.0, 13.0]
  default_hspfs = [6.5, 6.5, 6.5, 6.5, 6.5, 6.80, 6.80, 7.7]
  ending_years.zip(default_seers, default_hspfs).each do |ending_year, default_seer, default_hspf|
    next if year > ending_year

    return default_seer, default_hspf
  end
  return nil
end

def get_default_gshp_eer_cop(year)
  # FIXME: Verify
  # ANSI/RESNET/ICC 301 - Table 4.4.2(3) Default Values for Mechanical System Efficiency (Age-based)
  ending_years = [1959, 1969, 1974, 1983, 1987, 1991, 2005, 9999]
  default_eers = [8.00, 8.00, 8.00, 11.00, 11.00, 12.00, 14.0, 13.4]
  default_cops = [2.30, 2.30, 2.30, 2.50, 2.60, 2.70, 3.00, 3.1]
  ending_years.zip(default_eers, default_cops).each do |ending_year, default_eer, default_cop|
    next if year > ending_year

    return default_eer, default_cop
  end
  return nil
end

def get_default_water_heater_ef(year, fuel)
  # FIXME: Verify
  # ANSI/RESNET/ICC 301 - Table 4.4.2(3) Default Values for Mechanical System Efficiency (Age-based)
  ending_years = [1959, 1969, 1974, 1983, 1987, 1991, 2005, 9999]
  default_efs = { "electricity" => [0.86, 0.86, 0.86, 0.86, 0.86, 0.87, 0.88, 0.92],
                  "natural gas" => [0.50, 0.50, 0.50, 0.50, 0.55, 0.56, 0.56, 0.59],
                  "propane" => [0.50, 0.50, 0.50, 0.50, 0.55, 0.56, 0.56, 0.59],
                  "fuel oil" => [0.47, 0.47, 0.47, 0.48, 0.49, 0.54, 0.56, 0.51] }[fuel]
  ending_years.zip(defaults_efs).each do |ending_year, default_ef|
    next if year > ending_year

    return default_ef
  end
  return nil
end

def get_default_water_heater_volume(fuel)
  # FIXME: Verify
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/water-heater-energy-consumption/user-inputs-to-the-water-heater-model
  return { "electricity" => 50,
           "natural gas" => 40,
           "propane" => 40,
           "fuel oil" => 32 }[fuel]
end

def get_default_water_heater_re(fuel)
  # FIXME: Verify
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/water-heater-energy-consumption/user-inputs-to-the-water-heater-model
  return { "electricity" => 0.98,
           "natural gas" => 0.76,
           "propane" => 0.76,
           "fuel oil" => 0.76 }[fuel]
end

def get_default_water_heater_capacity(fuel)
  # FIXME: Verify
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/water-heater-energy-consumption/user-inputs-to-the-water-heater-model
  return { "electricity" => UnitConversions.convert(4.5, "kwh", "btu"),
           "natural gas" => 38000,
           "propane" => 38000,
           "fuel oil" => UnitConversions.convert(0.65, "gal", "btu", Constants.FuelTypeOil) }[fuel]
end

def orientation_to_azimuth(orientation)
  return { "northeast" => 45,
           "east" => 90,
           "southeast" => 135,
           "south" => 180,
           "southwest" => 225,
           "west" => 270,
           "northwest" => 315,
           "north" => 0 }[orientation]
end
