class HEScoreValidator
  def self.run_validator(hpxml_doc)
    # A hash of hashes that defines the XML elements used by the Home Energy Score HPXML Use Case.
    #
    # Example:
    #
    # use_case = {
    #     nil => {
    #         'floor_area' => one,            # 1 element required always
    #         'garage_area' => zero_or_one,   # 0 or 1 elements required always
    #         'walls' => one_or_more,         # 1 or more elements required always
    #     },
    #     '/walls' => {
    #         'rvalue' => one,                # 1 element required if /walls element exists (conditional)
    #         'windows' => zero_or_one,       # 0 or 1 elements required if /walls element exists (conditional)
    #         'layers' => one_or_more,        # 1 or more elements required if /walls element exists (conditional)
    #     }
    # }
    #

    one = [1]
    zero = [0]
    zero_or_one = [0, 1]
    zero_or_more = nil
    one_or_more = []

    requirements = {

      # Root
      nil => {
        '/HPXML/SoftwareInfo/SoftwareProgramUsed' => one,
        '/HPXML/SoftwareInfo/SoftwareProgramVersion' => one,

        '/HPXML/Building' => one,

        '/HPXML/Building/BuildingDetails/BuildingSummary/Site[Surroundings="stand-alone" or Surroundings="attached on one side" or Surroundings="attached on two sides"]' => one,
        '/HPXML/Building/BuildingDetails/BuildingSummary/Site/OrientationOfFrontOfHome' => one,
        '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/YearBuilt' => one,
        '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction[ResidentialFacilityType="single-family detached" or ResidentialFacilityType="single-family attached"]' => one,
        '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofConditionedFloorsAboveGrade' => one,
        '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/AverageCeilingHeight' => one,
        '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/NumberofBedrooms' => one,
        '/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction/ConditionedFloorArea' => one,

        '/HPXML/Building/BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement' => one, # See [AirInfiltration]

        '/HPXML/Building/BuildingDetails/Enclosure/AtticAndRoof/Roofs/Roof' => one_or_more, # See [Roof]
        '/HPXML/Building/BuildingDetails/Enclosure/AtticAndRoof/Attics/Attic' => one_or_more, # See [Attic]
        '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation' => one_or_more, # See [Foundation]
        '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall' => one_or_more, # See [Wall]
        '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window' => one_or_more, # See [Window]
        '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight' => zero_or_more, # See [Skylight]

        '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant[HeatingSystem | CoolingSystem | HeatPump]' => zero_or_one, # See [HeatingSystem] or [CoolingSystem] or [HeatPump]
        '/HPXML/Building/BuildingDetails/Systems/WaterHeating' => one_or_more, # See [WaterHeatingSystem]
        '/HPXML/Building/BuildingDetails/Systems/Photovoltaics' => zero_or_one, # See [PVSystem]
      },

      # [AirInfiltration]
      'BuildingDetails/Enclosure/AirInfiltration/AirInfiltrationMeasurement' => {
        '[[HousePressure="50"]/BuildingAirLeakage[UnitofMeasure="CFM"]/AirLeakage] | [LeakinessDescription="tight" or LeakinessDescription="average"]' => one,
      },

      # [Roof]
      '/HPXML/Building/BuildingDetails/Enclosure/AtticAndRoof/Roofs/Roof' => {
        '[RoofColor="light" or RoofColor="medium" or RoofColor="medium dark" or RoofColor="dark" or RoofColor="white" or RoofColor="reflective"]' => one,
        'SolarAbsorptance' => one,
        '[RoofType="slate or tile shingles" or RoofType="wood shingles or shakes" or RoofType="asphalt or fiberglass shingles" or RoofType="plastic/rubber/synthetic sheeting" or RoofType="concrete"]' => one,
        'RadiantBarrier' => one,
        '/HPXML/Building/BuildingDetails/Enclosure/Skylights' => zero_or_one, # See [Skylight]
      },

      # [Attic]
      '/HPXML/Building/BuildingDetails/Enclosure/AtticAndRoof/Attics/Attic' => {
        'AttachedToRoof' => one,
        '[AtticType="vented attic" or AtticType="cape cod" or AtticType="cathedral ceiling"]' => one, # See [AtticType=Vented] or [AtticType=Cape] or [AtticType=Cathedral]
        'AtticRoofInsulation/Layer[InstallationType="cavity"]/NominalRValue' => one,
        'AtticRoofInsulation/Layer[InstallationType="continuous"]/NominalRValue' => zero_or_one,
      },

      ## [AtticType=Vented]
      '/HPXML/Building/BuildingDetails/Enclosure/AtticAndRoof/Attics/Attic[AtticType="vented attic"]' => {
        'AtticFloorInsulation/Layer[InstallationType="cavity"]/NominalRValue' => one,
        'Area' => one,
      },

      ## [AtticType=Cape]
      '/HPXML/Building/BuildingDetails/Enclosure/AtticAndRoof/Attics/Attic[AtticType="cape cod"]' => {
        'AtticFloorInsulation/Layer[InstallationType="cavity"]/NominalRValue' => one,
        'Area' => one,
      },

      ## [AtticType=Cathedral]
      '/HPXML/Building/BuildingDetails/Enclosure/AtticAndRoof/Attics/Attic[AtticType="cathedral ceiling"]' => {
      },

      # [Foundation]
      '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation' => {
        'FoundationType[Basement | Crawlspace | SlabOnGrade]' => one, # See [FoundationType=Basement] or [FoundationType=Crawl] or [FoundationType=Slab]
      },

      ## [FoundationType=Basement]
      '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation[FoundationType/Basement]' => {
        'FoundationType/Basement/Conditioned' => one,
        'FrameFloor/Area' => one,
        'FrameFloor/Insulation/Layer[InstallationType="cavity"]/NominalRValue' => one, # FIXME: Basement too?
        'FoundationWall/Insulation/Layer[InstallationType="continuous"]/NominalRValue' => one,
      },

      ## [FoundationType=Crawl]
      '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation[FoundationType/Crawlspace]' => {
        'FoundationType/Crawlspace/Vented' => one,
        'FrameFloor/Area' => one,
        'FrameFloor/Insulation/Layer[InstallationType="cavity"]/NominalRValue' => one, # FIXME: Basement too?
        'FoundationWall/Insulation/Layer[InstallationType="continuous"]/NominalRValue' => one,
      },

      ## [FoundationType=Slab]
      '/HPXML/Building/BuildingDetails/Enclosure/Foundations/Foundation[FoundationType/SlabOnGrade]' => {
        'Slab/Area' => one,
        'Slab/PerimeterInsulation/Layer[InstallationType="continuous"]/NominalRValue' => one,
      },

      # [Wall]
      '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall' => {
        'WallType[WoodStud | StructuralBrick | ConcreteMasonryUnit | StrawBale]' => one, # See [WallType=WoodStud] or [WallType=Brick] or [WallType=CMU] or [WallType=StrawBale]
        'Orientation' => one,
      },

      ## [WallType=WoodStud]
      '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall[WallType/WoodStud]' => {
        'WallType/WoodStud/OptimumValueEngineering' => one,
        '[Siding="wood siding" or Siding="stucco" or Siding="vinyl siding" or Siding="aluminum siding" or Siding="brick veneer"]' => one,
        'Insulation/Layer[InstallationType="cavity"]/NominalRValue' => one,
        'Insulation/Layer[InstallationType="continuous"]/NominalRValue' => zero_or_one,
      },

      ## [WallType=Brick]
      '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall[WallType/StructuralBrick]' => {
        'Siding' => zero,
        'Insulation/Layer[InstallationType="cavity"]/NominalRValue' => one,
        'Insulation/Layer[InstallationType="continuous"]/NominalRValue' => zero,
      },

      ## [WallType=CMU]
      '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall[WallType/ConcreteMasonryUnit]' => {
        '[count(Siding)=0 or Siding="stucco" or Siding="brick veneer"]' => one,
        'Insulation/Layer[InstallationType="cavity"]/NominalRValue' => one,
        'Insulation/Layer[InstallationType="continuous"]/NominalRValue' => zero,
      },

      ## [WallType=StrawBale]
      '/HPXML/Building/BuildingDetails/Enclosure/Walls/Wall[WallType/StrawBale]' => {
        '[Siding="stucco"]' => one,
        'Insulation/Layer[InstallationType="cavity"]/NominalRValue' => zero,
        'Insulation/Layer[InstallationType="continuous"]/NominalRValue' => zero,
      },

      # [Window]
      '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window' => {
        'Area' => one,
        'AttachedToWall' => one,
        '[FrameType | UFactor]' => one, # See [WindowType=Detailed] or [WindowType=Simple]
      },

      ## [WindowType=Detailed]
      '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window[FrameType]' => {
        '[FrameType/Aluminum/ThermalBreak | FrameType/Wood]' => one,
        '[GlassLayers="single-pane" or GlassLayers="double-pane" or GlassLayers="triple-pane"]' => one,
        '[count(GlassType)=0 or GlassType="tinted/reflective" or GlassType="reflective" or GlassType="low-e"]' => one,
        '[count(GasFill)=0 or GasFill="air" or GasFill="argon"]' => one,
      },

      ## [WindowType=Simple]
      '/HPXML/Building/BuildingDetails/Enclosure/Windows/Window[UFactor]' => {
        'SHGC' => one,
      },

      # [Skylight]
      '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight' => {
        'Area' => one,
        'Orientation' => one,
        'AttachedToRoof' => one,
        '[FrameType | UFactor]' => one, # See [SkylightType=Detailed] or [SkylightType=Simple]
      },

      ## [SkylightType=Detailed]
      '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight[FrameType]' => {
        '[FrameType/Aluminum/ThermalBreak | FrameType/Wood]' => one,
        '[GlassLayers="single-pane" or GlassLayers="double-pane" or GlassLayers="triple-pane"]' => one,
        '[count(GlassType)=0 or GlassType="tinted/reflective" or GlassType="reflective" or GlassType="low-e"]' => one,
        '[count(GasFill)=0 or GasFill="air" or GasFill="argon"]' => one,
      },

      ## [SkylightType=Simple]
      '/HPXML/Building/BuildingDetails/Enclosure/Skylights/Skylight[UFactor]' => {
        'SHGC' => one,
      },

      # [HeatingSystem]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem' => {
        'HeatingSystemType[ElectricResistance | Furnace | WallFurnace | Boiler | Stove]' => one, # See [HeatingType=Resistance] or [HeatingType=Furnace] or [HeatingType=WallFurnace] or [HeatingType=Boiler] or [HeatingType=Stove]
        'FractionHeatLoadServed' => one,
      },

      ## [HeatingType=Resistance]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/ElectricResistance]' => {
        'DistributionSystem' => zero,
      },

      ## [HeatingType=Furnace]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/Furnace]' => {
        'DistributionSystem' => one, # See [HVACDistribution]
        '[HeatingSystemFuel="electricity" or HeatingSystemFuel="natural gas" or HeatingSystemFuel="fuel oil" or HeatingSystemFuel="propane"]' => one,
        '[YearInstalled | AnnualHeatingEfficiency[Units="AFUE"]/Value]' => one,
      },

      ## [HeatingType=WallFurnace]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/WallFurnace]' => {
        'DistributionSystem' => zero,
        '[HeatingSystemFuel="electricity" or HeatingSystemFuel="natural gas" or HeatingSystemFuel="fuel oil" or HeatingSystemFuel="propane"]' => one,
        '[YearInstalled | AnnualHeatingEfficiency[Units="AFUE"]/Value]' => one,
      },

      ## [HeatingType=Boiler]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/Boiler]' => {
        'DistributionSystem' => zero,
        '[HeatingSystemFuel="electricity" or HeatingSystemFuel="natural gas" or HeatingSystemFuel="fuel oil" or HeatingSystemFuel="propane"]' => one,
        '[YearInstalled | AnnualHeatingEfficiency[Units="AFUE"]/Value]' => one,
      },

      ## [HeatingType=Stove]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatingSystem[HeatingSystemType/Stove]' => {
        'DistributionSystem' => zero,
        '[HeatingSystemFuel="wood" or HeatingSystemFuel="wood pellets"]' => one,
      },

      # [CoolingSystem]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem' => {
        '[CoolingSystemType="central air conditioning" or CoolingSystemType="room air conditioner" or CoolingSystemType="evaporative cooler"]' => one, # See [CoolingType=CentralAC] or [CoolingType=RoomAC] or [CoolingType=EvapCooler]
        'FractionCoolLoadServed' => one,
      },

      ## [CoolingType=CentralAC]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem[CoolingSystemType="central air conditioning"]' => {
        'DistributionSystem' => one, # See [HVACDistribution]
        '[YearInstalled | AnnualCoolingEfficiency[Units="SEER"]/Value]' => one,
      },

      ## [CoolingType=RoomAC]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem[CoolingSystemType="room air conditioning"]' => {
        'DistributionSystem' => zero,
        '[YearInstalled | AnnualCoolingEfficiency[Units="EER"]/Value]' => one,
      },

      ## [CoolingType=EvapCooler]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/CoolingSystem[CoolingSystemType="evaporative cooler"]' => {
        'DistributionSystem' => zero,
      },

      # [HeatPump]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump' => {
        '[HeatPumpType="air-to-air" or HeatPumpType="mini-split" or HeatPumpType="ground-to-air"]' => one, # See [HeatPumpType=ASHP] or [HeatPumpType=MSHP] or [HeatPumpType=GSHP]
        'FractionHeatLoadServed' => one,
        'FractionCoolLoadServed' => one,
      },

      ## [HeatPumpType=ASHP]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[HeatPumpType="air-to-air"]' => {
        'DistributionSystem' => one, # See [HVACDistribution]
        '[YearInstalled | AnnualCoolingEfficiency[Units="SEER"]/Value]' => one,
        '[YearInstalled | AnnualHeatingEfficiency[Units="HSPF"]/Value]' => one,
      },

      ## [HeatPumpType=MSHP]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[HeatPumpType="mini-split"]' => {
        # FIXME: 'DistributionSystem' => one, # See [HVACDistribution]
        '[YearInstalled | AnnualCoolingEfficiency[Units="SEER"]/Value]' => one,
        '[YearInstalled | AnnualHeatingEfficiency[Units="HSPF"]/Value]' => one,
      },

      ## [HeatPumpType=GSHP]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACPlant/HeatPump[HeatPumpType="ground-to-air"]' => {
        'DistributionSystem' => one, # See [HVACDistribution]
        '[YearInstalled | AnnualCoolingEfficiency[Units="EER"]/Value]' => one,
        '[YearInstalled | AnnualHeatingEfficiency[Units="COP"]/Value]' => one,
      },

      # [HVACDistribution]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution' => {
        'DistributionSystemType/AirDistribution/Ducts' => one_or_more, # See [HVACDuct]
        'HVACDistributionImprovement/DuctSystemSealed' => one,
      },

      ## [HVACDuct]
      '/HPXML/Building/BuildingDetails/Systems/HVAC/HVACDistribution/DistributionSystemType/AirDistribution/Ducts' => {
        '[DuctLocation="conditioned space" or DuctLocation="unconditioned basement" or DuctLocation="unvented crawlspace" or DuctLocation="vented crawlspace" or DuctLocation="unconditioned attic"]' => one,
        'FractionDuctArea' => one,
        'extension/hescore_ducts_insulated' => one,
      },

      # [WaterHeatingSystem]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem' => {
        '[WaterHeaterType="storage water heater" or WaterHeaterType="heat pump water heater"]' => one, # See [WHType=Tank] or [WHType=HeatPump]
      },

      ## [WHType=Tank]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="storage water heater"]' => {
        '[FuelType="natural gas" or FuelType="fuel oil" or FuelType="propane" or FuelType="electricity"]' => one, # If not electricity, see [WHType=FuelTank]
        '[YearInstalled | EnergyFactor]' => one,
      },

      ## [WHType=HeatPump]
      '/HPXML/Building/BuildingDetails/Systems/WaterHeating/WaterHeatingSystem[WaterHeaterType="heat pump water heater"]' => {
        'EnergyFactor' => one,
      },

      # [PVSystem]
      '/HPXML/Building/BuildingDetails/Systems/Photovoltaics/PVSystem' => {
        'ArrayOrientation' => one,
        '[MaxPowerOutput | extension/hescore_num_panels]' => one,
      },
    }

    # TODO: Make common across all validators
    # TODO: Profile code for runtime improvements
    errors = []
    requirements.each do |parent, requirement|
      if parent.nil? # Unconditional
        requirement.each do |child, expected_sizes|
          next if expected_sizes.nil?

          xpath = combine_into_xpath(parent, child)
          actual_size = REXML::XPath.first(hpxml_doc, "count(#{xpath})")
          check_number_of_elements(actual_size, expected_sizes, xpath, errors)
        end
      else # Conditional based on parent element existence
        next if hpxml_doc.elements[parent].nil? # Skip if parent element doesn't exist

        hpxml_doc.elements.each(parent) do |parent_element|
          requirement.each do |child, expected_sizes|
            next if expected_sizes.nil?

            xpath = combine_into_xpath(parent, child)
            actual_size = REXML::XPath.first(parent_element, "count(#{child})")
            check_number_of_elements(actual_size, expected_sizes, xpath, errors)
          end
        end
      end
    end

    return errors
  end

  def self.check_number_of_elements(actual_size, expected_sizes, xpath, errors)
    if expected_sizes.size > 0
      return if expected_sizes.include?(actual_size)

      errors << "Expected #{expected_sizes.to_s} element(s) but found #{actual_size.to_s} element(s) for xpath: #{xpath}"
    else
      return if actual_size > 0

      errors << "Expected 1 or more element(s) but found 0 elements for xpath: #{xpath}"
    end
  end

  def self.combine_into_xpath(parent, child)
    if parent.nil?
      return child
    elsif child.start_with?("[")
      return [parent, child].join('')
    end

    return [parent, child].join('/')
  end
end
