class HPXML

  def self.add_site(building_summary:, fuels: [], shelter_coefficient: nil)
    site = XMLHelper.add_element(building_summary, "Site")
    unless fuels.empty?
      fuel_types_available = XMLHelper.add_element(site, "FuelTypesAvailable")
      fuels.each do |fuel|
        XMLHelper.add_element(fuel_types_available, "Fuel", fuel)
      end
    end
    unless shelter_coefficient.nil?    
      extension = XMLHelper.add_element(site, "extension")
      XMLHelper.add_element(extension, "ShelterCoefficient", shelter_coefficient)
    end

    return site
  end

  def self.add_building_occupancy(building_summary:, number_of_residents: nil)
    building_occupancy = XMLHelper.add_element(building_summary, "BuildingOccupancy")
    XMLHelper.add_element(building_occupancy, "NumberofResidents", number_of_residents) unless number_of_residents.nil?

    return building_occupancy
  end

  def self.add_building_construction(building_summary:, ncfl: nil, ncfl_ag: nil, nbeds: nil, cfa: nil, cvolume: nil, garage_present: nil)
    building_construction = XMLHelper.add_element(building_summary, "BuildingConstruction")
    XMLHelper.add_element(building_construction, "NumberofConditionedFloors", ncfl) unless ncfl.nil?
    XMLHelper.add_element(building_construction, "NumberofConditionedFloorsAboveGrade", ncfl_ag) unless ncfl_ag.nil?
    XMLHelper.add_element(building_construction, "NumberofBedrooms", nbeds) unless nbeds.nil?
    XMLHelper.add_element(building_construction, "ConditionedFloorArea", cfa) unless cfa.nil?
    XMLHelper.add_element(building_construction, "ConditionedBuildingVolume", cvolume) unless cvolume.nil?
    XMLHelper.add_element(building_construction, "GaragePresent", false) unless garage_present.nil?

    return building_construction
  end

end