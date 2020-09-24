#*********************************************************************************
# URBANopt™, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC, and other
# contributors. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
#*********************************************************************************

require 'urbanopt/reporting'
require 'openstudio/common_measures'
require 'openstudio/model_articulation'

require 'json'
require 'rexml/document'

module URBANopt
  module Scenario
    class BaselineMapper < SimulationMapperBase

      # class level variables
      @@instance_lock = Mutex.new
      @@osw = nil
      @@geometry = nil

      def initialize()

        # do initialization of class variables in thread safe way
        @@instance_lock.synchronize do
          if @@osw.nil?

            # load the OSW for this class
            osw_path = File.join(File.dirname(__FILE__), 'base_workflow.osw')
            File.open(osw_path, 'r') do |file|
              @@osw = JSON.parse(file.read, symbolize_names: true)
            end

            # add any paths local to the project
            @@osw[:measure_paths] << File.join(File.dirname(__FILE__), '../measures/')
            @@osw[:measure_paths] << File.join(File.dirname(__FILE__), '../resources/hpxml-measures')
            @@osw[:file_paths] << File.join(File.dirname(__FILE__), '../weather/')

            # configures OSW with extension gem paths for measures and files, all extension gems must be
            # required before this
            @@osw = OpenStudio::Extension.configure_osw(@@osw)
          end
        end
      end

      def lookup_building_type(building_type, template, footprint_area, number_of_stories)
        if template.include? "DEER"
          case building_type
          when "Education"
            return "EPr"
          when "Enclosed mall"
            return "RtL"
          when "Food sales"
            return "RSD"
          when "Food service"
            return "RSD"
          when "Inpatient health care"
            return "Nrs"
          when "Laboratory"
            return "Hsp"
          when "Lodging"
            return "Htl"
          when "Mixed use"
            return "ECC"
          when "Mobile Home"
            return "DMo"
          when "Multifamily (2 to 4 units)"
            return "MFm"
          when "Multifamily (5 or more units)"
            return "MFm"
          when "Nonrefrigerated warehouse"
            return "SUn"
          when "Nursing"
            return "Nrs"
          when "Office"
            if footprint_area
              if footprint_area.to_f > 100000
                return "OfL"
              else
                return "OfS"
              end
            else
              raise "footprint_area required to map office building type"
            end
          when "Outpatient health care"
            return "Nrs"
          when "Public assembly"
            return "Asm"
          when "Public order and safety"
            return "Asm"
          when "Refrigerated warehouse"
            return "WRf"
          when "Religious worship"
            return "Asm"
          when "Retail other than mall"
            return "RtS"
          when "Service"
            return "MLI"
          when "Single-Family"
            return "MFm"
          when "Strip shopping mall"
            return "RtL"
          when "Vacant"
            return "SUn"
          else
           raise "building type #{building_type} cannot be mapped to a DEER building type"
          end

        else
          # default: ASHRAE
          case building_type
          when "Education"
            return 'SecondarySchool'
          when "Enclosed mall"
            return "RetailStripmall"
          when "Food sales"
            return "FullServiceRestaurant"
          when "Food service"
            return "FullServiceRestaurant"
          when "Inpatient health care"
            return "Hospital"
          when "Laboratory"
            return "Hospital"
          when "Lodging"
            if number_of_stories
              if number_of_stories.to_i > 3
                return "LargeHotel"
              else
                return "SmallHotel"
              end
            end
            return "LargeHotel"
          when "Mixed use"
            return "Mixed use"
          when "Mobile Home"
            return "MidriseApartment"
          when "Multifamily (2 to 4 units)"
            return "MidriseApartment"
          when "Multifamily (5 or more units)"
            return "MidriseApartment"
          when "Nonrefrigerated warehouse"
            return "Warehouse"
          when "Nursing"
            return "Outpatient"
          when "Office"
            if footprint_area
              if footprint_area.to_f < 20000
                value = "SmallOffice"
              elsif footprint_area.to_f > 100000
                value = "LargeOffice"
              else
                value = "MediumOffice"
              end
            else
              raise "Floor area required to map office building type"
            end
          when "Outpatient health care"
            return "Outpatient"
          when "Public assembly"
            return "MediumOffice"
          when "Public order and safety"
            return "MediumOffice"
          when "Refrigerated warehouse"
            return "Warehouse"
          when "Religious worship"
            return "MediumOffice"
          when "Retail other than mall"
            return "RetailStandalone"
          when "Service"
            return "MediumOffice"
          when "Single-Family"
            return "MidriseApartment"
          when "Strip shopping mall"
            return "RetailStripmall"
          when "Vacant"
            return "Warehouse"
          else
            raise "building type #{building_type} cannot be mapped to an ASHRAE building type"
          end
        end
      end

      def lookup_template_by_year_built(template,  year_built)

        if template.include? "DEER"
          if year_built <= 1996
            return 'DEER 1985'
          elsif year_built <= 2003
            return 'DEER 1996'
          elsif year_built <= 2007
            return 'DEER 2003'
          elsif year_built <= 2011
            return 'DEER 2007'
          elsif year_built <= 2014
            return 'DEER 2011'
          elsif year_built <= 2015
            return 'DEER 2014'
          elsif year_built <= 2017
            return 'DEER 2015'
          elsif year_built <= 2020
            return 'DEER 2017'
          else
            return 'DEER 2020'
          end
        else
          # ASHRAE
          if year_built < 1980
            return 'DOE Ref Pre-1980'
          elsif year_built <= 2004
            return 'DOE Ref 1980-2004'
          elsif year_built <= 2007
            return '90.1-2004'
          elsif year_built <= 2010
            return '90.1-2007'
          elsif year_built <= 2013
            return '90.1-2010'
          else
            return '90.1-2013'
          end
        end
      end

      def residential_building_types
        return [
          'Single-Family Detached',
          'Single-Family Attached',
          'Multifamily'
        ]
      end

      def commercial_building_types
        return [
          'Vacant',
          'Office',
          'Laboratory',
          'Nonrefrigerated warehouse',
          'Food sales',
          'Public order and safety',
          'Outpatient health care',
          'Refrigerated warehouse',
          'Religious worship',
          'Public assembly',
          'Education',
          'Food service',
          'Inpatient health care',
          'Nursing',
          'Lodging',
          'Strip shopping mall',
          'Enclosed mall',
          'Retail other than mall',
          'Service',
          'Uncovered Parking',
          'Covered Parking',
          'Mixed use'
        ]
      end

      def get_arg_default(arg)
        case arg.type.valueName.downcase
        when 'boolean'
          return arg.defaultValueAsBool
        when 'double'
          return arg.defaultValueAsDouble
        when 'integer'
          return arg.defaultValueAsInteger
        when 'string'
          return arg.defaultValueAsString
        when 'choice'
          return arg.defaultValueAsString
        end
      end

      def get_lookup_tsv(args, filepath)
        rows = []
        headers = []
        CSV.foreach(filepath, { :col_sep => "\t" }) do |row|
          if headers.empty?
            row.each do |header|
              next if header == 'Source'
              if args.keys.include?(header.gsub('Dependency=', '').to_sym)
                header = header.gsub('Dependency=', '')
              end
              unless header.include?('Dependency=')
                header = header.to_sym
              end
              headers << header
            end
            next
          end
          if headers.length != row.length
            row = row[0..-2] # leave out Source column
          end
          rows << headers.zip(row).to_h
        end
        return rows
      end

      def get_lookup_row(args, rows, template_vals)
        rows.each do |row|
          if row.keys.include?('Dependency=Climate Zone')
            next if row['Dependency=Climate Zone'] != template_vals[:climate_zone]
          end
          if row.keys.include?('Dependency=IECC Year')
            next if row['Dependency=IECC Year'] != template_vals[:iecc_year]
          end
          if row.keys.include?('Dependency=Template Month')
            next if row['Dependency=Template Month'] != template_vals[:t_month]
          end
          if row.keys.include?('Dependency=Template Year')
            next if row['Dependency=Template Year'] != template_vals[:t_year]
          end
          row.delete('Dependency=Climate Zone')
          row.delete('Dependency=IECC Year')
          row.delete('Dependency=Template Month')
          row.delete('Dependency=Template Year')

          row.each do |k, v|
            next unless v.nil?

            row.delete(k)
          end

          intersection = args.keys & row.keys
          return row if intersection.empty? # found the correct row

          skip = false
          intersection.each do |k|
            if args[k] != row[k]
              skip = true
            end
          end

          return row unless skip
        end
        return nil
      end

      def get_climate_zone_iecc(epw)
        headers = CSV.open(epw, 'r') { |csv| csv.first }
        wmo = headers[5]
        zones_csv = File.join(File.dirname(__FILE__), '../resources/hpxml-measures/HPXMLtoOpenStudio/resources/climate_zones.csv')
        CSV.foreach(zones_csv) do |row|
          if row[0].to_s == wmo.to_s
            return row[6].to_s
          end
        end
      end

      def create_osw(scenario, features, feature_names)

        if features.size != 1
          raise 'Baseline currently cannot simulate more than one feature.'
        end
        feature = features[0]
        feature_id = feature.id
        feature_type = feature.type

        # take the centroid of the vertices as the location of the building
        feature_vertices_coordinates = feature.feature_json[:geometry][:coordinates][0]
        feature_location = feature.find_feature_center(feature_vertices_coordinates).to_s

        feature_name = feature.name
        if feature_names.size == 1
          feature_name = feature_names[0]
        end

        # deep clone of @@osw before we configure it
        osw = Marshal.load(Marshal.dump(@@osw))

        # now we have the feature, we can look up its properties and set
        # arguments in the OSW
        osw[:name] = feature_name
        osw[:description] = feature_name

        if feature_type == 'Building'
          building_type = feature.building_type

          if residential_building_types.include? building_type
            debug = false

            args = {}

            # Simulation Control
            args[:simulation_control_timestep] = 60
            begin
              args[:simulation_control_timestep] = 60 / feature.timesteps_per_hour
            rescue
            end

            args[:simulation_control_begin_month] = 1
            args[:simulation_control_begin_day_of_month] = 1
            args[:simulation_control_end_month] = 12
            args[:simulation_control_end_day_of_month] = 31
            begin
              args[:simulation_control_begin_month] = feature.begin_date[5, 2].to_i
              args[:simulation_control_begin_day_of_month] = feature.begin_date[8, 2].to_i
              args[:simulation_control_end_month] = feature.end_date[5, 2].to_i
              args[:simulation_control_end_day_of_month] = feature.end_date[8, 2].to_i
            rescue
            end

            args[:weather_station_epw_filepath] = feature.weather_filename

            # Geometry
            args[:geometry_num_units] = 1
            case building_type
            when 'Single-Family Detached'
              args[:geometry_unit_type] = "single-family detached"
            when 'Single-Family Attached'
              args[:geometry_num_units] = feature.number_of_residential_units
              args[:geometry_unit_type] = "single-family attached"
            when 'Multifamily'
              args[:geometry_num_units] = feature.number_of_residential_units
              args[:geometry_unit_type] = "apartment unit"
            end

            args[:geometry_foundation_type] = "SlabOnGrade"
            args[:geometry_foundation_height] = 0.0
            case feature.foundation_type
            when 'crawlspace - vented'
              args[:geometry_foundation_type] = "VentedCrawlspace"
              args[:geometry_foundation_height] = 3.0
            when 'crawlspace - unvented'
              args[:geometry_foundation_type] = "UnventedCrawlspace"
              args[:geometry_foundation_height] = 3.0
            when 'basement - unconditioned'
              args[:geometry_foundation_type] = "UnconditionedBasement"
              args[:geometry_foundation_height] = 8.0
            when 'basement - conditioned'
              args[:geometry_foundation_type] = "ConditionedBasement"
              args[:geometry_foundation_height] = 8.0
            when 'ambient'
              args[:geometry_foundation_type] = "Ambient"
              args[:geometry_foundation_height] = 8.0
            end

            args[:geometry_attic_type] = "ConditionedAttic"
            args[:geometry_roof_type] = "flat"
            begin
              case feature.attic_type
              when 'attic - vented'
                args[:geometry_attic_type] = "VentedAttic"
                args[:geometry_roof_type] = "gable"
              when 'attic - unvented'
                args[:geometry_attic_type] = "UnventedAttic"
                args[:geometry_roof_type] = "gable"
              when 'attic - conditioned'
                args[:geometry_attic_type] = "ConditionedAttic"
                args[:geometry_roof_type] = "gable"
              end
            rescue
            end

            args[:geometry_num_floors_above_grade] = feature.number_of_stories_above_ground

            args[:geometry_cfa] = feature.floor_area / args[:geometry_num_units]

            args[:geometry_wall_height] = 8.0
            begin
              args[:geometry_wall_height] = feature.maximum_roof_height / args[:geometry_num_floors_above_grade]
            rescue
            end

            args[:geometry_num_bedrooms] = feature.number_of_bedrooms
            args[:geometry_num_bedrooms] /= args[:geometry_num_units]

            system_type = "Residential - furnace and central air conditioner"
            begin
              system_type = feature.system_type
            rescue
            end

            args[:heating_system_type] = "none"
            if system_type.include?('electric resistance')
              args[:heating_system_type] = "ElectricResistance"
            elsif system_type.include?('furnace')
              args[:heating_system_type] = "Furnace"
            elsif system_type.include?('boiler')
              args[:heating_system_type] = "Boiler"
            end

            args[:cooling_system_type] = "none"
            if system_type.include?('central air conditioner')
              args[:cooling_system_type] = "central air conditioner"
            elsif system_type.include?('room air conditioner')
              args[:cooling_system_type] = "room air conditioner"
            elsif system_type.include?('evaporative cooler')
              args[:cooling_system_type] = "evaporative cooler"
            end

            args[:heat_pump_type] = "none"
            if system_type.include?('air-to-air')
              args[:heat_pump_type] = "air-to-air"
            elsif system_type.include?('mini-split')
              args[:heat_pump_type] = "mini-split"
            elsif system_type.include?('ground-to-air')
              args[:heat_pump_type] = "ground-to-air"
            end

            args[:heating_system_fuel] = "natural gas"
            begin
              args[:heating_system_fuel] = feature.heating_system_fuel_type
            rescue
            end

            if args[:heating_system_type] == "ElectricResistance"
              args[:heating_system_fuel] = "electricity"
            end

            args[:cooking_range_oven_fuel_type] = args[:heating_system_fuel]
            args[:clothes_dryer_fuel_type] = args[:heating_system_fuel]

            args[:kitchen_fans_present] = true
            args[:bathroom_fans_present] = true

            args[:water_heater_fuel_type] = args[:heating_system_fuel]

            # Set occupancy schedule generation mode
            begin
              args[:schedules_type] = feature.schedules_type
              if feature.schedules_type == 'stochastic'
                begin
                  args[:building_id] = feature_id
                  args[:random_seed] = feature.random_seed
                rescue NoMethodError
                end
              end
            rescue NoMethodError
            end

            template = nil
            begin
              template = feature.template
            rescue
            end

            # IECC / EnergyStar / Other
            unless template.nil?
              if template.include?('Residential IECC')

                captures = template.match(/Residential IECC (?<iecc_year>\d+) - Customizable Template (?<t_month>\w+) (?<t_year>\d+)/)
                template_vals = Hash[captures.names.zip( captures.captures ) ]
                template_vals = Hash[template_vals.collect{ |k, v| [k.to_sym, v] }]

                epw = File.join(File.dirname(__FILE__), '../weather', feature.weather_filename)
                template_vals[:climate_zone] = get_climate_zone_iecc(epw)

                # ENCLOSURE

                enclosure_filepath = File.join(File.dirname(__FILE__), 'residential/enclosure.tsv')
                enclosure = get_lookup_tsv(args, enclosure_filepath)
                row = get_lookup_row(args, enclosure, template_vals)

                # Determine which surfaces to place insulation on
                if args[:geometry_foundation_type].include? 'Basement'
                  row[:foundation_wall_assembly_r] = row[:foundation_wall_assembly_r_basement]
                  row[:floor_assembly_r] = 2.1
                elsif args[:geometry_foundation_type].include? 'Crawlspace'
                  row[:foundation_wall_assembly_r] = row[:foundation_wall_assembly_r_crawlspace]
                  row[:floor_assembly_r] = 2.1
                end
                row.delete(:foundation_wall_assembly_r_basement)
                row.delete(:foundation_wall_assembly_r_crawlspace)
                if ["ConditionedAttic"].include?(args[:geometry_attic_type])
                  row[:roof_assembly_r] = row[:ceiling_assembly_r]
                  row[:ceiling_assembly_r] = 2.1
                end
                args.update(row) unless row.nil?

                # HVAC

                if args[:heating_system_type] != "none"
                  heating_system_filepath = File.join(File.dirname(__FILE__), 'residential/heating_system.tsv')
                  heating_system = get_lookup_tsv(args, heating_system_filepath)
                  row = get_lookup_row(args, heating_system, template_vals)
                  args.update(row) unless row.nil?
                end

                if args[:cooling_system_type] != "none"
                  cooling_system_filepath = File.join(File.dirname(__FILE__), 'residential/cooling_system.tsv')
                  cooling_system = get_lookup_tsv(args, cooling_system_filepath)
                  row = get_lookup_row(args, cooling_system, template_vals)
                  args.update(row) unless row.nil?
                end

                if args[:heat_pump_type] != "none"
                  heat_pump_filepath = File.join(File.dirname(__FILE__), 'residential/heat_pump.tsv')
                  heat_pump = get_lookup_tsv(args, heat_pump_filepath)
                  row = get_lookup_row(args, heat_pump, template_vals)
                  args.update(row) unless row.nil?
                end

                # APPLIANCES

                ['refrigerator', 'clothes_washer', 'dishwasher', 'clothes_dryer'].each do |appliance|
                  appliances_filepath = File.join(File.dirname(__FILE__), "residential/#{appliance}.tsv")
                  appliances = get_lookup_tsv(args, appliances_filepath)
                  row = get_lookup_row(args, appliances, template_vals)
                  args.update(row) unless row.nil?
                end

                # VENTILATION

                mechvent_filepath = File.join(File.dirname(__FILE__), "residential/mechanical_ventilation.tsv")
                mechvent = get_lookup_tsv(args, mechvent_filepath)
                row = get_lookup_row(args, mechvent, template_vals)
                args.update(row) unless row.nil?

                # WATER HEATER

                water_heater_filepath = File.join(File.dirname(__FILE__), 'residential/water_heater.tsv')
                water_heater = get_lookup_tsv(args, water_heater_filepath)
                row = get_lookup_row(args, water_heater, template_vals)
                args.update(row) unless row.nil?
              end
            end

            # Parse BuildResidentialModel measure xml so we can override defaults with template values
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialModel', '__SKIP__', false)
            measures_dir = File.absolute_path(File.join(File.dirname(__FILE__), '../resources/hpxml-measures'))
            measure_xml = File.read(File.join(measures_dir, 'BuildResidentialHPXML', 'measure.xml'))
            measure = REXML::Document.new(measure_xml).root
            measure.elements.each('arguments/argument') do |arg|
              arg_name = arg.elements['name'].text.to_sym
              next if [:hpxml_path, :weather_dir].include? arg_name
              # argument has not been set and so gets the default value
              if (!args.keys.include? arg_name) && arg.elements['default_value']
                arg_default = arg.elements['default_value'].text
                args[arg_name] = arg_default
              else
                if debug
                  if arg.elements['default_value']
                    arg_default = arg.elements['default_value'].text
                    if args[arg_name] != arg_default
                      puts "Overriding #{arg_name} default '#{arg_default}' with '#{args[arg_name]}'."
                    end
                  else
                    puts "Setting #{arg_name} to '#{args[arg_name]}'."
                  end
                end
              end

              if args.keys.include? arg_name
                OpenStudio::Extension.set_measure_argument(
                  osw, 'BuildResidentialModel', arg_name, args[arg_name]
                )
              end
            end

          elsif commercial_building_types.include? building_type

            OpenStudio::Extension.set_measure_argument(osw, 'set_run_period', '__SKIP__', false)
            # set_run_period
            begin
              timesteps_per_hour = feature.timesteps_per_hour
              if timesteps_per_hour
                OpenStudio::Extension.set_measure_argument(osw, 'set_run_period', 'timesteps_per_hour', timesteps_per_hour)
              end
            rescue StandardError
            end
            begin
              begin_date = feature.begin_date
              if begin_date
                # check date-only YYYY-MM-DD
                if begin_date.length > 10
                  begin_date = begin_date[0, 10]
                end
                OpenStudio::Extension.set_measure_argument(osw, 'set_run_period', 'begin_date', begin_date)
              end
            rescue StandardError
            end
            begin
              end_date = feature.end_date
              if end_date
                # check date-only YYYY-MM-DD
                if end_date.length > 10
                  end_date = end_date[0, 10]
                end
                OpenStudio::Extension.set_measure_argument(osw, 'set_run_period', 'end_date', end_date)
              end
            rescue StandardError
            end

            # convert to hash
            building_hash = feature.to_hash
            # check for detailed model filename
            OpenStudio::Extension.set_measure_argument(osw, 'PredictedMeanVote', '__SKIP__', false)
            if building_hash.key?(:detailed_model_filename)
              detailed_model_filename = building_hash[:detailed_model_filename]
              osw[:file_paths] << File.join(File.dirname(__FILE__), '../osm_building/')
              osw[:seed_file] = detailed_model_filename

              # skip PMV measure with detailed models:
              OpenStudio::Extension.set_measure_argument(osw, 'PredictedMeanVote', '__SKIP__', true)

            # in case detailed model filename is not present
            else

              building_type_1 = building_hash[:building_type]

              # lookup/map building type
              number_of_stories = building_hash[:number_of_stories]
              if building_hash.key?(:number_of_stories_above_ground)
                number_of_stories_above_ground = building_hash[:number_of_stories_above_ground]
                number_of_stories_below_ground = number_of_stories - number_of_stories_above_ground
              else
                number_of_stories_above_ground = number_of_stories
                number_of_stories_below_ground = 0
              end
              template = building_hash.key?(:template) ? building_hash[:template] : nil
              footprint_area = building_hash[:footprint_area]

              mapped_building_type_1 = lookup_building_type(building_type_1, template, footprint_area, number_of_stories)

              # process Mixed Use (for create_bar measure)
              if building_type_1 == 'Mixed use'
                # map mixed use types
                running_fraction = 0
                mixed_type_1 = building_hash[:mixed_type_1]
                mixed_type_2 = building_hash.key?(:mixed_type_2) ? building_hash[:mixed_type_2] : nil
                unless mixed_type_2.nil?
                  mixed_type_2_percentage = building_hash[:mixed_type_2_percentage]
                  mixed_type_2_fract_bldg_area = mixed_type_2_percentage * 0.01
                  running_fraction += mixed_type_2_fract_bldg_area
                end

                mixed_type_3 = building_hash.key?(:mixed_type_3) ? building_hash[:mixed_type_3] : nil
                unless mixed_type_3.nil?
                  mixed_type_3_percentage = building_hash[:mixed_type_3_percentage]
                  mixed_type_3_fract_bldg_area = mixed_type_3_percentage * 0.01
                  running_fraction += mixed_type_3_fract_bldg_area
                end

                mixed_type_4 = building_hash.key?(:mixed_type_4) ? building_hash[:mixed_type_4] : nil
                unless mixed_type_4.nil?
                  mixed_type_4_percentage = building_hash[:mixed_type_4_percentage]
                  mixed_type_4_fract_bldg_area = mixed_type_4_percentage * 0.01
                  running_fraction += mixed_type_4_fract_bldg_area
                end

                # potentially calculate from other inputs
                mixed_type_1_fract_bldg_area = building_hash.key?(:mixed_type_1_percentage) ? building_hash[:mixed_type_1_percentage] : (1 - running_fraction)

                # lookup mixed_use types
                footprint_1 = footprint_area * mixed_type_1_fract_bldg_area
                openstudio_mixed_type_1 = lookup_building_type(mixed_type_1, template, footprint_1, number_of_stories)
                unless mixed_type_2.nil?
                  footprint_2 = footprint_area * mixed_type_2_fract_bldg_area
                  openstudio_mixed_type_2 = lookup_building_type(mixed_type_2, template, footprint_2, number_of_stories)
                end
                unless mixed_type_3.nil?
                  footprint_3 = footprint_area * mixed_type_3_fract_bldg_area
                  openstudio_mixed_type_3 = lookup_building_type(mixed_type_3, template, footprint_3, number_of_stories)
                end
                unless mixed_type_4.nil?
                  footprint_4 = footprint_area * mixed_type_4_fract_bldg_area
                  openstudio_mixed_type_4 = lookup_building_type(mixed_type_4, template, footprint_4, number_of_stories)
                end
              end

              floor_height = 10
              # Map system type to openstudio system types
              # TODO: Map all system types
              if building_hash.key?(:system_type)
                system_type = building_hash[:system_type]
                case system_type
                when 'Fan coil district hot and chilled water'
                  system_type = 'Fan coil district chilled water with district hot water'
                when 'Fan coil air-cooled chiller and boiler'
                  system_type = 'Fan coil air-cooled chiller with boiler'
                when 'VAV with gas reheat'
                  system_type = 'VAV air-cooled chiller with gas boiler reheat'
                end
              else
                system_type = "Inferred"
              end

              def time_mapping(time)
                hour = time.split(':')[0]
                minute = time.split(':')[1]
                fraction = minute.to_f/60
                fraction_roundup = fraction.round(2)
                minute_fraction = fraction_roundup.to_s.split('.')[1]
                new_time = [hour, minute_fraction].join('.')
                return new_time
              end

              # ChangeBuildingLocation
              # set skip measure to false change building location
              OpenStudio::Extension.set_measure_argument(osw, 'ChangeBuildingLocation', '__SKIP__', false)

              # cec climate zone takes precedence
              cec_found = false
              begin
                cec_climate_zone = feature.cec_climate_zone
                if !cec_climate_zone.empty?
                  cec_climate_zone = "CEC T24-CEC" + cec_climate_zone
                  OpenStudio::Extension.set_measure_argument(osw, 'ChangeBuildingLocation', 'climate_zone', cec_climate_zone)
                  cec_found = true
                end
              rescue
              end
              if !cec_found
                begin
                  climate_zone = feature.climate_zone
                  if !climate_zone.empty?
                    climate_zone = "ASHRAE 169-2013-" + climate_zone
                    OpenStudio::Extension.set_measure_argument(osw, 'ChangeBuildingLocation', 'climate_zone', climate_zone)
                 end
                rescue
                end
              end

              # set weather file
              begin
                weather_filename = feature.weather_filename
                if !feature.weather_filename.nil? && !feature.weather_filename.empty?
                  OpenStudio::Extension.set_measure_argument(osw, 'ChangeBuildingLocation', 'weather_file_name', weather_filename)
                  puts "Setting weather_file_name to #{weather_filename} as specified in the FeatureFile"
                end
              rescue
                puts "No weather_file specified on feature"
                epw_file_path = Dir.glob(File.join(File.dirname(__FILE__), '../weather/*.epw'))[0]
                if !epw_file_path.nil? && !epw_file_path.empty?
                  epw_file_name = File.basename(epw_file_path)
                  OpenStudio::Extension.set_measure_argument(osw, 'ChangeBuildingLocation', 'weather_file_name', epw_file_name)
                  puts "Setting weather_file_name to first epw file found in the weather folder: #{epw_file_name}"
                else
                  puts "NO WEATHER FILES SPECIFIED...SIMULATIONS MAY FAIL"
                end
              end

              # set weekday start time
              begin
                weekday_start_time = feature.weekday_start_time
                if !feature.weekday_start_time.empty?
                  new_weekday_start_time = time_mapping(weekday_start_time)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'wkdy_op_hrs_start_time', new_weekday_start_time, 'create_typical_building_from_model 1')
                end
              rescue
              end

              # set weekday duration
              begin
                weekday_duration = feature.weekday_duration
                if !feature.weekday_duration.empty?
                  new_weekday_duration = time_mapping(weekday_duration)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'wkdy_op_hrs_duration', new_weekday_duration, 'create_typical_building_from_model 1')
                end
              rescue
              end

              # set weekend start time
              begin
                weekend_start_time = feature.weekend_start_time
                if !feature.weekend_start_time.empty?
                  new_weekend_start_time = time_mapping(weekend_start_time)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'wknd_op_hrs_start_time', new_weekend_start_time, 'create_typical_building_from_model 1')
                end
              rescue
              end

              # set weekend duration
              begin
                weekend_duration = feature.weekend_duration
                if !feature.weekend_duration.empty?
                  new_weekend_duration = time_mapping(weekend_duration)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'wknd_op_hrs_duration', new_weekend_duration, 'create_typical_building_from_model 1')
                end
              rescue
              end

              # template
              begin
                new_template = nil
                template = feature.template

                # can we override template with year_built info? (keeping same template family)
                if building_hash.key?(:year_built) && !building_hash[:year_built].nil? && !feature.template.empty?
                  new_template = lookup_template_by_year_built(template, year_built)
                elsif !feature.template.empty?
                  new_template = template
                end

                if new_template
                  OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'template', new_template)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'template', new_template, 'create_typical_building_from_model 1')
                  OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'template', new_template, 'create_typical_building_from_model 2')
                end
              rescue
              end

              # TODO: surface_elevation has no current mapping
              # TODO: tariff_filename has no current mapping

              # create a bar building, will have spaces tagged with individual space types given the
              # input building types
              # set skip measure to false
              OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', '__SKIP__', false)
              OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'single_floor_area', footprint_area)
              OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'floor_height', floor_height)
              OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'num_stories_above_grade', number_of_stories_above_ground)
              OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'num_stories_below_grade', number_of_stories_below_ground)

              OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_a', mapped_building_type_1)

              if building_type_1 == 'Mixed use'

                OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_a', openstudio_mixed_type_1)

                unless mixed_type_2.nil?
                  OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_b', openstudio_mixed_type_2)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_b_fract_bldg_area', mixed_type_2_fract_bldg_area)
                end
                unless mixed_type_3.nil?
                  OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_c', openstudio_mixed_type_3)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_c_fract_bldg_area', mixed_type_3_fract_bldg_area)
                end
                unless mixed_type_4.nil?
                  OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_d', openstudio_mixed_type_4)
                  OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_d_fract_bldg_area', mixed_type_4_fract_bldg_area)
                end
              end

              # calling create typical building the first time will create space types
              OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', '__SKIP__', false)
              OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'add_hvac', false, 'create_typical_building_from_model 1')

              # create a blended space type for each story
              OpenStudio::Extension.set_measure_argument(osw,
                'blended_space_type_from_model', '__SKIP__', false)
              OpenStudio::Extension.set_measure_argument(osw,
              'blended_space_type_from_model', 'blend_method', 'Building Story')

              # create geometry for the desired feature, this will reuse blended space types in the model for each story and remove the bar geometry
              OpenStudio::Extension.set_measure_argument(osw, 'urban_geometry_creation_zoning', '__SKIP__', false)
              OpenStudio::Extension.set_measure_argument(osw, 'urban_geometry_creation_zoning', 'geojson_file', scenario.feature_file.path)
              OpenStudio::Extension.set_measure_argument(osw, 'urban_geometry_creation_zoning', 'feature_id', feature_id)
              OpenStudio::Extension.set_measure_argument(osw, 'urban_geometry_creation_zoning', 'surrounding_buildings', 'ShadingOnly')

              # call create typical building a second time, do not touch space types, only add hvac
              OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', '__SKIP__', false)
              OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'system_type', system_type, 'create_typical_building_from_model 2')
            end

          else
            raise "Building type #{building_type} not currently supported."
          end # building type == residential or commercial

        end # feature_type == 'Building'

        # call the default feature reporting measure
        OpenStudio::Extension.set_measure_argument(osw, 'default_feature_reports', 'feature_id', feature_id)
        OpenStudio::Extension.set_measure_argument(osw, 'default_feature_reports', 'feature_name', feature_name)
        OpenStudio::Extension.set_measure_argument(osw, 'default_feature_reports', 'feature_type', feature_type)
        OpenStudio::Extension.set_measure_argument(osw, 'default_feature_reports', 'feature_location', feature_location)

        return osw
      end # create_osw
    end # BaselineMapper
  end # Scenario
end # URBANopt
