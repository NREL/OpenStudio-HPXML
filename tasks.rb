# frozen_string_literal: true

def create_hpxmls
  require_relative 'HPXMLtoOpenStudio/resources/constants'
  require_relative 'HPXMLtoOpenStudio/resources/hpxml'
  require_relative 'HPXMLtoOpenStudio/resources/meta_measure'
  require_relative 'HPXMLtoOpenStudio/resources/waterheater'

  this_dir = File.dirname(__FILE__)
  tests_dir = File.join(this_dir, 'workflow/sample_files')

  # Hash of HPXML -> Parent HPXML
  hpxmls_files = {
    'base.xml' => nil, # single-family detached
    'base-appliances-coal.xml' => 'base.xml',
    'base-appliances-dehumidifier.xml' => 'base-location-dallas-tx.xml',
    'base-appliances-dehumidifier-ief-portable.xml' => 'base-appliances-dehumidifier.xml',
    'base-appliances-dehumidifier-ief-whole-home.xml' => 'base-appliances-dehumidifier-ief-portable.xml',
    # 'base-appliances-dehumidifier-multiple.xml' => 'base-appliances-dehumidifier.xml',
    'base-appliances-gas.xml' => 'base.xml',
    'base-appliances-modified.xml' => 'base.xml',
    'base-appliances-none.xml' => 'base.xml',
    'base-appliances-oil.xml' => 'base.xml',
    'base-appliances-propane.xml' => 'base.xml',
    'base-appliances-wood.xml' => 'base.xml',
    # 'base-atticroof-cathedral.xml' => 'base.xml', # TODO: conditioned attic ceiling heights are greater than wall height
    # 'base-atticroof-conditioned.xml' => 'base.xml', # Not supporting attic kneewalls for now
    'base-atticroof-flat.xml' => 'base.xml',
    'base-atticroof-radiant-barrier.xml' => 'base-location-dallas-tx.xml',
    'base-atticroof-unvented-insulated-roof.xml' => 'base.xml',
    'base-atticroof-vented.xml' => 'base.xml',
    'base-bldgtype-multifamily.xml' => 'base.xml',
    # 'base-bldgtype-multifamily-adjacent-to-multifamily-buffer-space.xml' => 'base.xml', # Not supporting units adjacent to other MF spaces for now
    # 'base-bldgtype-multifamily-adjacent-to-multiple.xml' => 'base.xml', # Not supporting units adjacent to other MF spaces for now
    # 'base-bldgtype-multifamily-adjacent-to-non-freezing-space.xml' => 'base.xml', # Not supporting units adjacent to other MF spaces for now
    # 'base-bldgtype-multifamily-adjacent-to-other-heated-space.xml' => 'base.xml', # Not supporting units adjacent to other MF spaces for now
    # 'base-bldgtype-multifamily-adjacent-to-other-housing-unit.xml' => 'base.xml', # Not supporting units adjacent to other MF spaces for now
    # 'base-bldgtype-multifamily-shared-boiler-chiller-baseboard.xml' => 'base-bldgtype-multifamily.xml',
    # 'base-bldgtype-multifamily-shared-boiler-chiller-fan-coil.xml' => 'base-bldgtype-multifamily-shared-boiler-chiller-baseboard.xml',
    # 'base-bldgtype-multifamily-shared-boiler-chiller-fan-coil-ducted.xml' => 'base-bldgtype-multifamily-shared-boiler-chiller-fan-coil.xml',
    # 'base-bldgtype-multifamily-shared-boiler-chiller-water-loop-heat-pump.xml' => 'base-bldgtype-multifamily-shared-boiler-chiller-baseboard.xml',
    # 'base-bldgtype-multifamily-shared-boiler-cooling-tower-water-loop-heat-pump.xml' => 'base-bldgtype-multifamily-shared-boiler-chiller-water-loop-heat-pump.xml',
    'base-bldgtype-multifamily-shared-boiler-only-baseboard.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-shared-boiler-only-fan-coil.xml' => 'base-bldgtype-multifamily-shared-boiler-only-baseboard.xml',
    # 'base-bldgtype-multifamily-shared-boiler-only-fan-coil-ducted.xml' => 'base-bldgtype-multifamily-shared-boiler-only-fan-coil.xml',
    # 'base-bldgtype-multifamily-shared-boiler-only-fan-coil-eae.xml' => 'base-bldgtype-multifamily-shared-boiler-only-fan-coil.xml',
    # 'base-bldgtype-multifamily-shared-boiler-only-water-loop-heat-pump.xml' => 'base-bldgtype-multifamily-shared-boiler-only-baseboard.xml',
    # 'base-bldgtype-multifamily-shared-chiller-only-baseboard.xml' => 'base-bldgtype-multifamily.xml',
    # 'base-bldgtype-multifamily-shared-chiller-only-fan-coil.xml' => 'base-bldgtype-multifamily-shared-chiller-only-baseboard.xml',
    # 'base-bldgtype-multifamily-shared-chiller-only-fan-coil-ducted.xml' => 'base-bldgtype-multifamily-shared-chiller-only-fan-coil.xml',
    # 'base-bldgtype-multifamily-shared-chiller-only-water-loop-heat-pump.xml' => 'base-bldgtype-multifamily-shared-chiller-only-baseboard.xml',
    # 'base-bldgtype-multifamily-shared-cooling-tower-only-water-loop-heat-pump.xml' => 'base-bldgtype-multifamily-shared-chiller-only-water-loop-heat-pump.xml',
    # 'base-bldgtype-multifamily-shared-generator.xml' => 'base-bldgtype-multifamily.xml',
    # 'base-bldgtype-multifamily-shared-ground-loop-ground-to-air-heat-pump.xml' => 'base-bldgtype-multifamily.xml',
    # 'base-bldgtype-multifamily-shared-laundry-room.xml' => 'base-bldgtype-multifamily.xml', # Not going to support shared laundry room
    'base-bldgtype-multifamily-shared-mechvent.xml' => 'base-bldgtype-multifamily.xml',
    # 'base-bldgtype-multifamily-shared-mechvent-multiple.xml' => 'base.xml', # Not going to support > 2 MV systems
    'base-bldgtype-multifamily-shared-mechvent-preconditioning.xml' => 'base-bldgtype-multifamily-shared-mechvent.xml',
    'base-bldgtype-multifamily-shared-pv.xml' => 'base-bldgtype-multifamily.xml',
    'base-bldgtype-multifamily-shared-water-heater.xml' => 'base-bldgtype-multifamily.xml',
    # 'base-bldgtype-multifamily-shared-water-heater-recirc.xml' => 'base.xml', $ Not supporting shared recirculation for now
    'base-bldgtype-single-family-attached.xml' => 'base.xml',
    'base-bldgtype-single-family-attached-2stories.xml' => 'base-bldgtype-single-family-attached.xml',
    'base-dhw-combi-tankless.xml' => 'base-dhw-indirect.xml',
    'base-dhw-combi-tankless-outside.xml' => 'base-dhw-combi-tankless.xml',
    # 'base-dhw-desuperheater.xml' => 'base.xml', # Not supporting desuperheater for now
    # 'base-dhw-desuperheater-2-speed.xml' => 'base.xml', # Not supporting desuperheater for now
    # 'base-dhw-desuperheater-gshp.xml' => 'base.xml', # Not supporting desuperheater for now
    # 'base-dhw-desuperheater-hpwh.xml' => 'base.xml', # Not supporting desuperheater for now
    # 'base-dhw-desuperheater-tankless.xml' => 'base.xml', # Not supporting desuperheater for now
    # 'base-dhw-desuperheater-var-speed.xml' => 'base.xml', # Not supporting desuperheater for now
    'base-dhw-dwhr.xml' => 'base.xml',
    'base-dhw-indirect.xml' => 'base-hvac-boiler-gas-only.xml',
    # 'base-dhw-indirect-dse.xml' => 'base.xml', # Not going to support DSE
    'base-dhw-indirect-outside.xml' => 'base-dhw-indirect.xml',
    'base-dhw-indirect-standbyloss.xml' => 'base-dhw-indirect.xml',
    'base-dhw-indirect-with-solar-fraction.xml' => 'base-dhw-indirect.xml',
    'base-dhw-jacket-electric.xml' => 'base.xml',
    'base-dhw-jacket-gas.xml' => 'base-dhw-tank-gas.xml',
    'base-dhw-jacket-hpwh.xml' => 'base-dhw-tank-heat-pump.xml',
    'base-dhw-jacket-indirect.xml' => 'base-dhw-indirect.xml',
    'base-dhw-low-flow-fixtures.xml' => 'base.xml',
    # 'base-dhw-multiple.xml' => 'base.xml', # Not supporting multiple water heaters for now
    'base-dhw-none.xml' => 'base.xml',
    'base-dhw-recirc-demand.xml' => 'base.xml',
    'base-dhw-recirc-manual.xml' => 'base.xml',
    'base-dhw-recirc-nocontrol.xml' => 'base.xml',
    'base-dhw-recirc-temperature.xml' => 'base.xml',
    'base-dhw-recirc-timer.xml' => 'base.xml',
    'base-dhw-solar-direct-evacuated-tube.xml' => 'base.xml',
    'base-dhw-solar-direct-flat-plate.xml' => 'base.xml',
    'base-dhw-solar-direct-ics.xml' => 'base.xml',
    'base-dhw-solar-fraction.xml' => 'base.xml',
    'base-dhw-solar-indirect-flat-plate.xml' => 'base.xml',
    'base-dhw-solar-thermosyphon-flat-plate.xml' => 'base.xml',
    'base-dhw-tank-coal.xml' => 'base.xml',
    'base-dhw-tank-elec-uef.xml' => 'base.xml',
    'base-dhw-tank-gas.xml' => 'base.xml',
    'base-dhw-tank-gas-uef.xml' => 'base.xml',
    # 'base-dhw-tank-gas-uef-fhr.xml' => 'base-dhw-tank-gas-uef.xml', # Supporting Usage Bin instead of FHR
    'base-dhw-tank-gas-outside.xml' => 'base-dhw-tank-gas.xml',
    'base-dhw-tank-heat-pump.xml' => 'base.xml',
    'base-dhw-tank-heat-pump-outside.xml' => 'base.xml',
    'base-dhw-tank-heat-pump-uef.xml' => 'base-dhw-tank-heat-pump.xml',
    'base-dhw-tank-heat-pump-with-solar.xml' => 'base.xml',
    'base-dhw-tank-heat-pump-with-solar-fraction.xml' => 'base.xml',
    'base-dhw-tankless-electric.xml' => 'base.xml',
    'base-dhw-tankless-electric-outside.xml' => 'base.xml',
    'base-dhw-tankless-electric-uef.xml' => 'base-dhw-tankless-electric.xml',
    'base-dhw-tankless-gas.xml' => 'base.xml',
    'base-dhw-tankless-gas-uef.xml' => 'base-dhw-tankless-gas.xml',
    'base-dhw-tankless-gas-with-solar.xml' => 'base.xml',
    'base-dhw-tankless-gas-with-solar-fraction.xml' => 'base.xml',
    'base-dhw-tankless-propane.xml' => 'base.xml',
    'base-dhw-tank-oil.xml' => 'base.xml',
    'base-dhw-tank-wood.xml' => 'base.xml',
    'base-enclosure-2stories.xml' => 'base.xml',
    'base-enclosure-2stories-garage.xml' => 'base-enclosure-2stories.xml',
    'base-enclosure-beds-1.xml' => 'base.xml',
    'base-enclosure-beds-2.xml' => 'base.xml',
    'base-enclosure-beds-4.xml' => 'base.xml',
    'base-enclosure-beds-5.xml' => 'base.xml',
    'base-enclosure-garage.xml' => 'base.xml',
    'base-enclosure-infil-ach-house-pressure.xml' => 'base.xml',
    'base-enclosure-infil-cfm-house-pressure.xml' => 'base-enclosure-infil-cfm50.xml',
    'base-enclosure-infil-cfm50.xml' => 'base.xml',
    'base-enclosure-infil-flue.xml' => 'base.xml',
    'base-enclosure-infil-natural-ach.xml' => 'base.xml',
    # 'base-enclosure-orientations.xml' => 'base.xml',
    'base-enclosure-overhangs.xml' => 'base.xml',
    # 'base-enclosure-rooftypes.xml' => 'base.xml',
    # 'base-enclosure-skylights.xml' => 'base.xml', # There are no front roof surfaces, but 15.0 ft^2 of skylights were specified.
    # 'base-enclosure-skylights-shading.xml' => 'base-enclosure-skylights.xml", # Not going to support interior/exterior shading by facade
    # 'base-enclosure-split-level.xml' => 'base.xml',
    # 'base-enclosure-split-surfaces.xml' => 'base.xml',
    # 'base-enclosure-split-surfaces2.xml' => 'base.xml',
    # 'base-enclosure-walltypes.xml' => 'base.xml',
    # 'base-enclosure-windows-shading.xml' => 'base.xml', # Not going to support interior/exterior shading by facade
    'base-enclosure-windows-none.xml' => 'base.xml',
    'base-foundation-ambient.xml' => 'base.xml',
    # 'base-foundation-basement-garage.xml' => 'base.xml',
    # 'base-foundation-complex.xml' => 'base.xml', # Not going to support multiple foundation types
    'base-foundation-conditioned-basement-slab-insulation.xml' => 'base.xml',
    # 'base-foundation-conditioned-basement-wall-interior-insulation.xml' => 'base.xml',
    # 'base-foundation-multiple.xml' => 'base.xml', # Not going to support multiple foundation types
    'base-foundation-slab.xml' => 'base.xml',
    'base-foundation-unconditioned-basement.xml' => 'base.xml',
    # 'base-foundation-unconditioned-basement-above-grade.xml' => 'base.xml', # TODO: add foundation wall windows
    'base-foundation-unconditioned-basement-assembly-r.xml' => 'base-foundation-unconditioned-basement.xml',
    'base-foundation-unconditioned-basement-wall-insulation.xml' => 'base-foundation-unconditioned-basement.xml',
    'base-foundation-unvented-crawlspace.xml' => 'base.xml',
    'base-foundation-vented-crawlspace.xml' => 'base.xml',
    # 'base-foundation-walkout-basement.xml' => 'base.xml', # 1 kiva object instead of 4
    'base-hvac-air-to-air-heat-pump-1-speed.xml' => 'base.xml',
    'base-hvac-air-to-air-heat-pump-1-speed-cooling-only.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-air-to-air-heat-pump-1-speed-heating-only.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-air-to-air-heat-pump-2-speed.xml' => 'base.xml',
    'base-hvac-air-to-air-heat-pump-var-speed.xml' => 'base.xml',
    'base-hvac-autosize.xml' => 'base.xml',
    'base-hvac-autosize-air-to-air-heat-pump-1-speed.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-autosize-air-to-air-heat-pump-1-speed-cooling-only.xml' => 'base-hvac-air-to-air-heat-pump-1-speed-cooling-only.xml',
    'base-hvac-autosize-air-to-air-heat-pump-1-speed-heating-only.xml' => 'base-hvac-air-to-air-heat-pump-1-speed-heating-only.xml',
    'base-hvac-autosize-air-to-air-heat-pump-1-speed-manual-s-oversize-allowances.xml' => 'base-hvac-autosize-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-autosize-air-to-air-heat-pump-2-speed.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'base-hvac-autosize-air-to-air-heat-pump-2-speed-manual-s-oversize-allowances.xml' => 'base-hvac-autosize-air-to-air-heat-pump-2-speed.xml',
    'base-hvac-autosize-air-to-air-heat-pump-var-speed.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'base-hvac-autosize-air-to-air-heat-pump-var-speed-manual-s-oversize-allowances.xml' => 'base-hvac-autosize-air-to-air-heat-pump-var-speed.xml',
    'base-hvac-autosize-boiler-elec-only.xml' => 'base-hvac-boiler-elec-only.xml',
    'base-hvac-autosize-boiler-gas-central-ac-1-speed.xml' => 'base-hvac-boiler-gas-central-ac-1-speed.xml',
    'base-hvac-autosize-boiler-gas-only.xml' => 'base-hvac-boiler-gas-only.xml',
    'base-hvac-autosize-central-ac-only-1-speed.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'base-hvac-autosize-central-ac-only-2-speed.xml' => 'base-hvac-central-ac-only-2-speed.xml',
    'base-hvac-autosize-central-ac-only-var-speed.xml' => 'base-hvac-central-ac-only-var-speed.xml',
    'base-hvac-autosize-central-ac-plus-air-to-air-heat-pump-heating.xml' => 'base-hvac-central-ac-plus-air-to-air-heat-pump-heating.xml',
    'base-hvac-autosize-dual-fuel-air-to-air-heat-pump-1-speed.xml' => 'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-autosize-dual-fuel-mini-split-heat-pump-ducted.xml' => 'base-hvac-dual-fuel-mini-split-heat-pump-ducted.xml',
    'base-hvac-autosize-elec-resistance-only.xml' => 'base-hvac-elec-resistance-only.xml',
    'base-hvac-autosize-evap-cooler-furnace-gas.xml' => 'base-hvac-evap-cooler-furnace-gas.xml',
    'base-hvac-autosize-floor-furnace-propane-only.xml' => 'base-hvac-floor-furnace-propane-only.xml',
    'base-hvac-autosize-furnace-elec-only.xml' => 'base-hvac-furnace-elec-only.xml',
    'base-hvac-autosize-furnace-gas-central-ac-2-speed.xml' => 'base-hvac-furnace-gas-central-ac-2-speed.xml',
    'base-hvac-autosize-furnace-gas-central-ac-var-speed.xml' => 'base-hvac-furnace-gas-central-ac-var-speed.xml',
    'base-hvac-autosize-furnace-gas-only.xml' => 'base-hvac-furnace-gas-only.xml',
    'base-hvac-autosize-furnace-gas-room-ac.xml' => 'base-hvac-furnace-gas-room-ac.xml',
    'base-hvac-autosize-ground-to-air-heat-pump.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'base-hvac-autosize-ground-to-air-heat-pump-cooling-only.xml' => 'base-hvac-ground-to-air-heat-pump-cooling-only.xml',
    'base-hvac-autosize-ground-to-air-heat-pump-heating-only.xml' => 'base-hvac-ground-to-air-heat-pump-heating-only.xml',
    'base-hvac-autosize-ground-to-air-heat-pump-manual-s-oversize-allowances.xml' => 'base-hvac-autosize-ground-to-air-heat-pump.xml',
    'base-hvac-autosize-mini-split-heat-pump-ducted.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'base-hvac-autosize-mini-split-heat-pump-ducted-cooling-only.xml' => 'base-hvac-mini-split-heat-pump-ducted-cooling-only.xml',
    'base-hvac-autosize-mini-split-heat-pump-ducted-heating-only.xml' => 'base-hvac-mini-split-heat-pump-ducted-heating-only.xml',
    'base-hvac-autosize-mini-split-heat-pump-ducted-manual-s-oversize-allowances.xml' => 'base-hvac-autosize-mini-split-heat-pump-ducted.xml',
    'base-hvac-autosize-mini-split-air-conditioner-only-ducted.xml' => 'base-hvac-mini-split-air-conditioner-only-ducted.xml',
    'base-hvac-autosize-room-ac-only.xml' => 'base-hvac-room-ac-only.xml',
    'base-hvac-autosize-stove-oil-only.xml' => 'base-hvac-stove-oil-only.xml',
    'base-hvac-autosize-wall-furnace-elec-only.xml' => 'base-hvac-wall-furnace-elec-only.xml',
    'base-hvac-boiler-coal-only.xml' => 'base.xml',
    'base-hvac-boiler-elec-only.xml' => 'base.xml',
    'base-hvac-boiler-gas-central-ac-1-speed.xml' => 'base.xml',
    'base-hvac-boiler-gas-only.xml' => 'base.xml',
    'base-hvac-boiler-oil-only.xml' => 'base.xml',
    'base-hvac-boiler-propane-only.xml' => 'base.xml',
    'base-hvac-boiler-wood-only.xml' => 'base.xml',
    'base-hvac-central-ac-only-1-speed.xml' => 'base.xml',
    'base-hvac-central-ac-only-2-speed.xml' => 'base.xml',
    'base-hvac-central-ac-only-var-speed.xml' => 'base.xml',
    'base-hvac-central-ac-plus-air-to-air-heat-pump-heating.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    # 'base-hvac-dse.xml' => 'base.xml', # Not going to support DSE
    'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed-electric.xml' => 'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-dual-fuel-air-to-air-heat-pump-2-speed.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'base-hvac-dual-fuel-air-to-air-heat-pump-var-speed.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'base-hvac-dual-fuel-mini-split-heat-pump-ducted.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'base-hvac-ducts-leakage-percent.xml' => 'base.xml',
    # 'base-hvac-ducts-area-fractions.xml' => 'base-enclosure-2stories.xml',
    'base-hvac-elec-resistance-only.xml' => 'base.xml',
    'base-hvac-evap-cooler-furnace-gas.xml' => 'base.xml',
    'base-hvac-evap-cooler-only.xml' => 'base.xml',
    'base-hvac-evap-cooler-only-ducted.xml' => 'base.xml',
    'base-hvac-fireplace-wood-only.xml' => 'base.xml',
    'base-hvac-fixed-heater-gas-only.xml' => 'base.xml',
    'base-hvac-floor-furnace-propane-only.xml' => 'base.xml',
    'base-hvac-furnace-coal-only.xml' => 'base.xml',
    'base-hvac-furnace-elec-central-ac-1-speed.xml' => 'base.xml',
    'base-hvac-furnace-elec-only.xml' => 'base.xml',
    'base-hvac-furnace-gas-central-ac-2-speed.xml' => 'base.xml',
    'base-hvac-furnace-gas-central-ac-var-speed.xml' => 'base.xml',
    'base-hvac-furnace-gas-only.xml' => 'base.xml',
    'base-hvac-furnace-gas-room-ac.xml' => 'base.xml',
    'base-hvac-furnace-oil-only.xml' => 'base.xml',
    'base-hvac-furnace-propane-only.xml' => 'base.xml',
    'base-hvac-furnace-wood-only.xml' => 'base.xml',
    # 'base-hvac-furnace-x3-dse.xml' => 'base.xml', # Not going to support DSE
    'base-hvac-ground-to-air-heat-pump.xml' => 'base.xml',
    'base-hvac-ground-to-air-heat-pump-cooling-only.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'base-hvac-ground-to-air-heat-pump-heating-only.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'base-hvac-install-quality-air-to-air-heat-pump-1-speed.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-install-quality-air-to-air-heat-pump-2-speed.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'base-hvac-install-quality-air-to-air-heat-pump-var-speed.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'base-hvac-install-quality-furnace-gas-central-ac-1-speed.xml' => 'base.xml',
    'base-hvac-install-quality-furnace-gas-central-ac-2-speed.xml' => 'base-hvac-furnace-gas-central-ac-2-speed.xml',
    'base-hvac-install-quality-furnace-gas-central-ac-var-speed.xml' => 'base-hvac-furnace-gas-central-ac-var-speed.xml',
    'base-hvac-install-quality-furnace-gas-only.xml' => 'base-hvac-furnace-gas-only.xml',
    'base-hvac-install-quality-ground-to-air-heat-pump.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'base-hvac-install-quality-mini-split-heat-pump-ducted.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'base-hvac-install-quality-mini-split-air-conditioner-only-ducted.xml' => 'base-hvac-mini-split-air-conditioner-only-ducted.xml',
    'base-hvac-mini-split-air-conditioner-only-ducted.xml' => 'base.xml',
    'base-hvac-mini-split-air-conditioner-only-ductless.xml' => 'base-hvac-mini-split-air-conditioner-only-ducted.xml',
    'base-hvac-mini-split-heat-pump-ducted.xml' => 'base.xml',
    'base-hvac-mini-split-heat-pump-ducted-cooling-only.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'base-hvac-mini-split-heat-pump-ducted-heating-only.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'base-hvac-mini-split-heat-pump-ductless.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    # 'base-hvac-multiple.xml' => 'base.xml', # Not supporting multiple heating/cooling systems for now
    'base-hvac-none.xml' => 'base.xml',
    'base-hvac-portable-heater-gas-only.xml' => 'base.xml',
    # 'base-hvac-programmable-thermostat.xml' => 'base.xml',
    'base-hvac-programmable-thermostat-detailed.xml' => 'base.xml',
    'base-hvac-room-ac-only.xml' => 'base.xml',
    'base-hvac-room-ac-only-33percent.xml' => 'base.xml',
    'base-hvac-room-ac-only-ceer.xml' => 'base-hvac-room-ac-only.xml',
    'base-hvac-seasons.xml' => 'base.xml',
    'base-hvac-setpoints.xml' => 'base.xml',
    'base-hvac-stove-oil-only.xml' => 'base.xml',
    'base-hvac-stove-wood-pellets-only.xml' => 'base.xml',
    'base-hvac-undersized.xml' => 'base.xml',
    # 'base-hvac-undersized-allow-increased-fixed-capacities.xml' => 'base-hvac-undersized.xml',
    'base-hvac-wall-furnace-elec-only.xml' => 'base.xml',
    'base-lighting-ceiling-fans.xml' => 'base.xml',
    'base-lighting-holiday.xml' => 'base.xml',
    # 'base-lighting-none.xml' => 'base.xml', # No need to support no lighting
    'base-location-AMY-2012.xml' => 'base.xml',
    'base-location-baltimore-md.xml' => 'base-foundation-unvented-crawlspace.xml',
    'base-location-dallas-tx.xml' => 'base-foundation-slab.xml',
    'base-location-duluth-mn.xml' => 'base-foundation-unconditioned-basement.xml',
    'base-location-helena-mt.xml' => 'base.xml',
    'base-location-honolulu-hi.xml' => 'base-foundation-slab.xml',
    'base-location-miami-fl.xml' => 'base-foundation-slab.xml',
    'base-location-phoenix-az.xml' => 'base-foundation-slab.xml',
    'base-location-portland-or.xml' => 'base-foundation-vented-crawlspace.xml',
    'base-mechvent-balanced.xml' => 'base.xml',
    'base-mechvent-bath-kitchen-fans.xml' => 'base.xml',
    'base-mechvent-cfis.xml' => 'base.xml',
    # 'base-mechvent-cfis-dse.xml' => 'base.xml', # Not going to support DSE
    'base-mechvent-cfis-evap-cooler-only-ducted.xml' => 'base-hvac-evap-cooler-only-ducted.xml',
    'base-mechvent-erv.xml' => 'base.xml',
    'base-mechvent-erv-atre-asre.xml' => 'base.xml',
    'base-mechvent-exhaust.xml' => 'base.xml',
    'base-mechvent-exhaust-rated-flow-rate.xml' => 'base.xml',
    'base-mechvent-hrv.xml' => 'base.xml',
    'base-mechvent-hrv-asre.xml' => 'base.xml',
    # 'base-mechvent-multiple.xml' => 'base.xml', # Not going to support > 2 MV systems
    'base-mechvent-supply.xml' => 'base.xml',
    'base-mechvent-whole-house-fan.xml' => 'base.xml',
    'base-misc-defaults.xml' => 'base.xml',
    # 'base-misc-generators.xml' => 'base.xml', # Not supporting generators for now
    'base-misc-loads-large-uncommon.xml' => 'base.xml',
    'base-misc-loads-large-uncommon2.xml' => 'base-misc-loads-large-uncommon.xml',
    # 'base-misc-loads-none.xml' => 'base.xml', # No need to support no misc loads
    'base-misc-neighbor-shading.xml' => 'base.xml',
    'base-misc-shielding-of-home.xml' => 'base.xml',
    'base-misc-usage-multiplier.xml' => 'base.xml',
    # 'base-multiple-buildings.xml' => 'base.xml', # No need to support multiple buildings
    'base-pv.xml' => 'base.xml',
    'base-simcontrol-calendar-year-custom.xml' => 'base.xml',
    'base-simcontrol-daylight-saving-custom.xml' => 'base.xml',
    'base-simcontrol-daylight-saving-disabled.xml' => 'base.xml',
    'base-simcontrol-runperiod-1-month.xml' => 'base.xml',
    'base-simcontrol-timestep-10-mins.xml' => 'base.xml',
    'base-schedules-simple.xml' => 'base.xml',

    # FIXME: What do we do with these?
    # Extra test files that don't correspond with sample files
    # 'extra-auto.xml' => 'base.xml',
    # 'extra-pv-roofpitch.xml' => 'base.xml',
    # 'extra-dhw-solar-latitude.xml' => 'base.xml',
    # 'extra-second-refrigerator.xml' => 'base.xml',
    # 'extra-second-heating-system-portable-heater-to-heating-system.xml' => 'base.xml',
    # 'extra-second-heating-system-fireplace-to-heating-system.xml' => 'base-hvac-elec-resistance-only.xml',
    # 'extra-second-heating-system-boiler-to-heating-system.xml' => 'base-hvac-boiler-gas-central-ac-1-speed.xml',
    # 'extra-second-heating-system-portable-heater-to-heat-pump.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    # 'extra-second-heating-system-fireplace-to-heat-pump.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    # 'extra-second-heating-system-boiler-to-heat-pump.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    # 'extra-enclosure-windows-shading.xml' => 'base.xml',
    # 'extra-enclosure-garage-partially-protruded.xml' => 'base.xml',
    # 'extra-enclosure-garage-atticroof-conditioned.xml' => 'base-enclosure-garage.xml',
    # 'extra-enclosure-atticroof-conditioned-eaves-gable.xml' => 'base-foundation-slab.xml',
    # 'extra-enclosure-atticroof-conditioned-eaves-hip.xml' => 'extra-enclosure-atticroof-conditioned-eaves-gable.xml',
    # 'extra-zero-refrigerator-kwh.xml' => 'base.xml',
    # 'extra-zero-extra-refrigerator-kwh.xml' => 'base.xml',
    # 'extra-zero-freezer-kwh.xml' => 'base.xml',
    # 'extra-zero-clothes-washer-kwh.xml' => 'base.xml',
    # 'extra-zero-dishwasher-kwh.xml' => 'base.xml',
    # 'extra-bldgtype-single-family-attached-atticroof-flat.xml' => 'base-bldgtype-single-family-attached.xml',
    # 'extra-gas-pool-heater-with-zero-kwh.xml' => 'base.xml',
    # 'extra-gas-hot-tub-heater-with-zero-kwh.xml' => 'base.xml',
    # 'extra-no-rim-joists.xml' => 'base.xml',
    # 'extra-state-code-different-than-epw.xml' => 'base.xml',

    # 'extra-bldgtype-single-family-attached-atticroof-conditioned-eaves-gable.xml' => 'extra-bldgtype-single-family-attached-slab.xml',
    # 'extra-bldgtype-single-family-attached-atticroof-conditioned-eaves-hip.xml' => 'extra-bldgtype-single-family-attached-atticroof-conditioned-eaves-gable.xml',
    # 'extra-bldgtype-multifamily-eaves.xml' => 'extra-bldgtype-multifamily-slab.xml',

    # 'extra-bldgtype-single-family-attached-slab.xml' => 'base-bldgtype-single-family-attached.xml',
    # 'extra-bldgtype-single-family-attached-vented-crawlspace.xml' => 'base-bldgtype-single-family-attached.xml',
    # 'extra-bldgtype-single-family-attached-unvented-crawlspace.xml' => 'base-bldgtype-single-family-attached.xml',
    # 'extra-bldgtype-single-family-attached-unconditioned-basement.xml' => 'base-bldgtype-single-family-attached.xml',

    # 'extra-bldgtype-single-family-attached-double-loaded-interior.xml' => 'base-bldgtype-single-family-attached.xml',
    # 'extra-bldgtype-single-family-attached-single-exterior-front.xml' => 'base-bldgtype-single-family-attached.xml',
    # 'extra-bldgtype-single-family-attached-double-exterior.xml' => 'base-bldgtype-single-family-attached.xml',

    # 'extra-bldgtype-single-family-attached-slab-middle.xml' => 'extra-bldgtype-single-family-attached-slab.xml',
    # 'extra-bldgtype-single-family-attached-slab-right.xml' => 'extra-bldgtype-single-family-attached-slab.xml',
    # 'extra-bldgtype-single-family-attached-vented-crawlspace-middle.xml' => 'extra-bldgtype-single-family-attached-vented-crawlspace.xml',
    # 'extra-bldgtype-single-family-attached-vented-crawlspace-right.xml' => 'extra-bldgtype-single-family-attached-vented-crawlspace.xml',
    # 'extra-bldgtype-single-family-attached-unvented-crawlspace-middle.xml' => 'extra-bldgtype-single-family-attached-unvented-crawlspace.xml',
    # 'extra-bldgtype-single-family-attached-unvented-crawlspace-right.xml' => 'extra-bldgtype-single-family-attached-unvented-crawlspace.xml',
    # 'extra-bldgtype-single-family-attached-unconditioned-basement-middle.xml' => 'extra-bldgtype-single-family-attached-unconditioned-basement.xml',
    # 'extra-bldgtype-single-family-attached-unconditioned-basement-right.xml' => 'extra-bldgtype-single-family-attached-unconditioned-basement.xml',

    # 'extra-bldgtype-multifamily-slab.xml' => 'base-bldgtype-multifamily.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace.xml' => 'base-bldgtype-multifamily.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace.xml' => 'base-bldgtype-multifamily.xml',

    # 'extra-bldgtype-multifamily-double-loaded-interior.xml' => 'base-bldgtype-multifamily.xml',
    # 'extra-bldgtype-multifamily-single-exterior-front.xml' => 'base-bldgtype-multifamily.xml',
    # 'extra-bldgtype-multifamily-double-exterior.xml' => 'base-bldgtype-multifamily.xml',

    # 'extra-bldgtype-multifamily-slab-left-bottom.xml' => 'extra-bldgtype-multifamily-slab.xml',
    # 'extra-bldgtype-multifamily-slab-left-middle.xml' => 'extra-bldgtype-multifamily-slab.xml',
    # 'extra-bldgtype-multifamily-slab-left-top.xml' => 'extra-bldgtype-multifamily-slab.xml',
    # 'extra-bldgtype-multifamily-slab-middle-bottom.xml' => 'extra-bldgtype-multifamily-slab.xml',
    # 'extra-bldgtype-multifamily-slab-middle-middle.xml' => 'extra-bldgtype-multifamily-slab.xml',
    # 'extra-bldgtype-multifamily-slab-middle-top.xml' => 'extra-bldgtype-multifamily-slab.xml',
    # 'extra-bldgtype-multifamily-slab-right-bottom.xml' => 'extra-bldgtype-multifamily-slab.xml',
    # 'extra-bldgtype-multifamily-slab-right-middle.xml' => 'extra-bldgtype-multifamily-slab.xml',
    # 'extra-bldgtype-multifamily-slab-right-top.xml' => 'extra-bldgtype-multifamily-slab.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-left-bottom.xml' => 'extra-bldgtype-multifamily-vented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-left-middle.xml' => 'extra-bldgtype-multifamily-vented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-left-top.xml' => 'extra-bldgtype-multifamily-vented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-middle-bottom.xml' => 'extra-bldgtype-multifamily-vented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-middle-middle.xml' => 'extra-bldgtype-multifamily-vented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-middle-top.xml' => 'extra-bldgtype-multifamily-vented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-right-bottom.xml' => 'extra-bldgtype-multifamily-vented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-right-middle.xml' => 'extra-bldgtype-multifamily-vented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-right-top.xml' => 'extra-bldgtype-multifamily-vented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-left-bottom.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-left-middle.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-left-top.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-middle-bottom.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-middle-middle.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-middle-top.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-right-bottom.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-right-middle.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-right-top.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace.xml',

    # 'extra-bldgtype-multifamily-slab-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-slab.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-vented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace.xml',
    # 'extra-bldgtype-multifamily-slab-left-bottom-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-slab-left-bottom.xml',
    # 'extra-bldgtype-multifamily-slab-left-middle-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-slab-left-middle.xml',
    # 'extra-bldgtype-multifamily-slab-left-top-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-slab-left-top.xml',
    # 'extra-bldgtype-multifamily-slab-middle-bottom-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-slab-middle-bottom.xml',
    # 'extra-bldgtype-multifamily-slab-middle-middle-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-slab-middle-middle.xml',
    # 'extra-bldgtype-multifamily-slab-middle-top-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-slab-middle-top.xml',
    # 'extra-bldgtype-multifamily-slab-right-bottom-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-slab-right-bottom.xml',
    # 'extra-bldgtype-multifamily-slab-right-middle-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-slab-right-middle.xml',
    # 'extra-bldgtype-multifamily-slab-right-top-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-slab-right-top.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-left-bottom-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-vented-crawlspace-left-bottom.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-left-middle-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-vented-crawlspace-left-middle.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-left-top-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-vented-crawlspace-left-top.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-middle-bottom-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-vented-crawlspace-middle-bottom.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-middle-middle-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-vented-crawlspace-middle-middle.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-middle-top-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-vented-crawlspace-middle-top.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-right-bottom-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-vented-crawlspace-right-bottom.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-right-middle-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-vented-crawlspace-right-middle.xml',
    # 'extra-bldgtype-multifamily-vented-crawlspace-right-top-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-vented-crawlspace-right-top.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-left-bottom-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace-left-bottom.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-left-middle-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace-left-middle.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-left-top-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace-left-top.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-middle-bottom-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace-middle-bottom.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-middle-middle-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace-middle-middle.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-middle-top-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace-middle-top.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-right-bottom-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace-right-bottom.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-right-middle-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace-right-middle.xml',
    # 'extra-bldgtype-multifamily-unvented-crawlspace-right-top-double-loaded-interior.xml' => 'extra-bldgtype-multifamily-unvented-crawlspace-right-top.xml',

    # 'invalid_files/non-electric-heat-pump-water-heater.xml' => 'base.xml',
    # 'invalid_files/heating-system-and-heat-pump.xml' => 'base.xml',
    # 'invalid_files/cooling-system-and-heat-pump.xml' => 'base.xml',
    # 'invalid_files/non-integer-geometry-num-bathrooms.xml' => 'base.xml',
    # 'invalid_files/non-integer-ceiling-fan-quantity.xml' => 'base.xml',
    # 'invalid_files/single-family-detached-slab-non-zero-foundation-height.xml' => 'base.xml',
    # 'invalid_files/single-family-detached-finished-basement-zero-foundation-height.xml' => 'base.xml',
    # 'invalid_files/single-family-attached-ambient.xml' => 'base-bldgtype-single-family-attached.xml',
    # 'invalid_files/multifamily-bottom-slab-non-zero-foundation-height.xml' => 'base-bldgtype-multifamily.xml',
    # 'invalid_files/multifamily-bottom-crawlspace-zero-foundation-height.xml' => 'base-bldgtype-multifamily.xml',
    # 'invalid_files/slab-non-zero-foundation-height-above-grade.xml' => 'base.xml',
    # 'invalid_files/ducts-location-and-areas-not-same-type.xml' => 'base.xml',
    # 'invalid_files/second-heating-system-serves-majority-heat.xml' => 'base.xml',
    # 'invalid_files/second-heating-system-serves-total-heat-load.xml' => 'base.xml',
    # 'invalid_files/second-heating-system-but-no-primary-heating.xml' => 'base.xml',
    # 'invalid_files/single-family-attached-no-building-orientation.xml' => 'base-bldgtype-single-family-attached.xml',
    # 'invalid_files/multifamily-no-building-orientation.xml' => 'base-bldgtype-multifamily.xml',
    # 'invalid_files/vented-crawlspace-with-wall-and-ceiling-insulation.xml' => 'base.xml',
    # 'invalid_files/unvented-crawlspace-with-wall-and-ceiling-insulation.xml' => 'base.xml',
    # 'invalid_files/unconditioned-basement-with-wall-and-ceiling-insulation.xml' => 'base.xml',
    # 'invalid_files/vented-attic-with-floor-and-roof-insulation.xml' => 'base.xml',
    # 'invalid_files/unvented-attic-with-floor-and-roof-insulation.xml' => 'base.xml',
    # 'invalid_files/conditioned-basement-with-ceiling-insulation.xml' => 'base.xml',
    # 'invalid_files/conditioned-attic-with-floor-insulation.xml' => 'base.xml',
    # 'invalid_files/dhw-indirect-without-boiler.xml' => 'base.xml',
    # 'invalid_files/multipliers-without-tv-plug-loads.xml' => 'base.xml',
    # 'invalid_files/multipliers-without-other-plug-loads.xml' => 'base.xml',
    # 'invalid_files/multipliers-without-well-pump-plug-loads.xml' => 'base.xml',
    # 'invalid_files/multipliers-without-vehicle-plug-loads.xml' => 'base.xml',
    # 'invalid_files/multipliers-without-fuel-loads.xml' => 'base.xml',
    # 'invalid_files/foundation-wall-insulation-greater-than-height.xml' => 'base-foundation-vented-crawlspace.xml',
    # 'invalid_files/conditioned-attic-with-one-floor-above-grade.xml' => 'base.xml',
    # 'invalid_files/zero-number-of-bedrooms.xml' => 'base.xml',
    # 'invalid_files/single-family-detached-with-shared-system.xml' => 'base.xml',
    # 'invalid_files/rim-joist-height-but-no-assembly-r.xml' => 'base.xml',
    # 'invalid_files/rim-joist-assembly-r-but-no-height.xml' => 'base.xml',
  }

  puts "Generating #{hpxmls_files.size} HPXML files..."

  hpxml_docs = {}
  hpxmls_files.each do |derivative, parent|
    print '.'

    begin
      hpxml_files = [derivative]
      unless parent.nil?
        hpxml_files.unshift(parent)
      end
      while not parent.nil?
        next unless hpxmls_files.keys.include? parent

        unless hpxmls_files[parent].nil?
          hpxml_files.unshift(hpxmls_files[parent])
        end
        parent = hpxmls_files[parent]
      end

      args = {}
      hpxml_files.each do |hpxml_file|
        set_measure_argument_values(hpxml_file, args)
      end

      measures_dir = File.dirname(__FILE__)
      measures = { 'BuildResidentialHPXML' => [args] }
      model = OpenStudio::Model::Model.new
      runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

      # Apply measure
      success = apply_measures(measures_dir, measures, runner, model)

      # Report warnings/errors
      runner.result.stepErrors.each do |s|
        puts "Error: #{s}"
      end

      if not success
        puts "\nError: Did not successfully generate #{derivative}."
        exit!
      end

      hpxml_path = File.join(tests_dir, hpxml_files[-1])
      hpxml = HPXML.new(hpxml_path: hpxml_path, collapse_enclosure: false)

      hpxml.header.xml_generated_by = 'tasks.rb' # FIXME: Temporary
      hpxml.header.created_date_and_time = Time.new(2000, 1, 1).strftime('%Y-%m-%dT%H:%M:%S%:z') # Hard-code to prevent diffs

      # Collapse surfaces whose azimuth is a minor effect
      (hpxml.roofs + hpxml.rim_joists + hpxml.walls + hpxml.foundation_walls + hpxml.doors).each do |surface|
        surface.azimuth = nil
      end
      hpxml.collapse_enclosure_surfaces()

      # Renumber IDs after collapsing surfaces
      hpxml.walls.each_with_index do |wall, i|
        (hpxml.attics + hpxml.foundations).each do |attic_or_foundation|
          if not attic_or_foundation.attached_to_wall_idrefs.delete(wall.id).nil?
            attic_or_foundation.attached_to_wall_idrefs << "Wall#{i + 1}"
          end
        end
        wall.id = "Wall#{i + 1}"
        wall.insulation_id = "Wall#{i + 1}Insulation"
      end
      hpxml.windows.each_with_index do |window, i|
        window.id = "Window#{i + 1}"
      end

      # Set HVAC thermostat control type
      if hpxml.hvac_controls.size == 1
        hpxml.hvac_controls[0].control_type = HPXML::HVACControlTypeManual
      end

      # Set interior finish for surfaces
      (hpxml.roofs + hpxml.walls + hpxml.foundation_walls + hpxml.frame_floors).each do |surface|
        next unless [HPXML::LocationLivingSpace,
                     HPXML::LocationBasementConditioned].include? surface.interior_adjacent_to

        surface.interior_finish_type = HPXML::InteriorFinishGypsumBoard
      end

      hpxml.water_heating_systems.each do |water_heating_system|
        water_heating_system.heating_capacity = (Waterheater.get_default_heating_capacity(water_heating_system.fuel_type,
                                                                                          hpxml.building_construction.number_of_bedrooms,
                                                                                          hpxml.water_heating_systems.size,
                                                                                          hpxml.building_construction.number_of_bathrooms) * 1000.0).round
      end

      hpxml_doc = hpxml.to_oga()
      XMLHelper.write_file(hpxml_doc, hpxml_path)
      hpxml_docs[File.basename(derivative)] = hpxml_doc
    rescue Exception => e
      puts "\n#{e}\n#{e.backtrace.join('\n')}"
      puts "\nError: Did not successfully generate #{derivative}."
      exit!
    end
  end

  puts "\n"

  # Print warnings about extra files
  abs_hpxml_files = []
  dirs = [nil]
  hpxmls_files.keys.each do |hpxml_file|
    abs_hpxml_files << File.absolute_path(File.join(tests_dir, hpxml_file))
    next unless hpxml_file.include? '/'

    dirs << hpxml_file.split('/')[0] + '/'
  end
  dirs.uniq.each do |dir|
    Dir["#{tests_dir}/#{dir}*.xml"].each do |hpxml|
      next if abs_hpxml_files.include? File.absolute_path(hpxml)

      puts "Warning: Extra HPXML file found at #{File.absolute_path(hpxml)}"
    end
  end

  return hpxml_docs
end

def set_measure_argument_values(hpxml_file, args)
  args['hpxml_path'] = "../workflow/sample_files/#{hpxml_file}"

  if ['base.xml'].include? hpxml_file
    args['simulation_control_timestep'] = '60'
    args['weather_station_epw_filepath'] = 'USA_CO_Denver.Intl.AP.725650_TMY3.epw'
    args['site_type'] = HPXML::SiteTypeSuburban
    args['geometry_unit_type'] = HPXML::ResidentialTypeSFD
    args['geometry_unit_cfa'] = 2700.0
    args['geometry_num_floors_above_grade'] = 1
    args['geometry_wall_height'] = 8.0
    args['geometry_unit_orientation'] = 180.0
    args['geometry_unit_aspect_ratio'] = 1.5
    args['geometry_corridor_position'] = 'Double-Loaded Interior'
    args['geometry_corridor_width'] = 10.0
    args['geometry_inset_width'] = 0.0
    args['geometry_inset_depth'] = 0.0
    args['geometry_inset_position'] = 'Right'
    args['geometry_balcony_depth'] = 0.0
    args['geometry_garage_width'] = 0.0
    args['geometry_garage_depth'] = 20.0
    args['geometry_garage_protrusion'] = 0.0
    args['geometry_garage_position'] = 'Right'
    args['geometry_foundation_type'] = HPXML::FoundationTypeBasementConditioned
    args['geometry_foundation_height'] = 8.0
    args['geometry_foundation_height_above_grade'] = 1.0
    args['geometry_rim_joist_height'] = 9.25
    args['geometry_roof_type'] = 'gable'
    args['geometry_roof_pitch'] = '6:12'
    args['geometry_attic_type'] = HPXML::AtticTypeUnvented
    args['geometry_eaves_depth'] = 0
    args['geometry_unit_num_bedrooms'] = 3
    args['geometry_unit_num_bathrooms'] = '2'
    args['geometry_unit_num_occupants'] = '3'
    args['geometry_has_flue_or_chimney'] = Constants.Auto
    args['floor_over_foundation_assembly_r'] = 0
    args['floor_over_garage_assembly_r'] = 0
    args['foundation_wall_insulation_r'] = 8.9
    args['foundation_wall_insulation_distance_to_top'] = '0.0'
    args['foundation_wall_insulation_distance_to_bottom'] = '8.0'
    args['foundation_wall_thickness'] = '8.0'
    args['rim_joist_assembly_r'] = 23.0
    args['slab_perimeter_insulation_r'] = 0
    args['slab_perimeter_depth'] = 0
    args['slab_under_insulation_r'] = 0
    args['slab_under_width'] = 0
    args['slab_thickness'] = '4.0'
    args['slab_carpet_fraction'] = '0.0'
    args['slab_carpet_r'] = '0.0'
    args['ceiling_assembly_r'] = 39.3
    args['roof_material_type'] = HPXML::RoofTypeAsphaltShingles
    args['roof_color'] = HPXML::ColorMedium
    args['roof_assembly_r'] = 2.3
    args['roof_radiant_barrier'] = false
    args['roof_radiant_barrier_grade'] = '1'
    args['neighbor_front_distance'] = 0
    args['neighbor_back_distance'] = 0
    args['neighbor_left_distance'] = 0
    args['neighbor_right_distance'] = 0
    args['neighbor_front_height'] = Constants.Auto
    args['neighbor_back_height'] = Constants.Auto
    args['neighbor_left_height'] = Constants.Auto
    args['neighbor_right_height'] = Constants.Auto
    args['wall_type'] = HPXML::WallTypeWoodStud
    args['wall_siding_type'] = HPXML::SidingTypeWood
    args['wall_color'] = HPXML::ColorMedium
    args['wall_assembly_r'] = 23
    args['window_front_wwr'] = 0
    args['window_back_wwr'] = 0
    args['window_left_wwr'] = 0
    args['window_right_wwr'] = 0
    args['window_area_front'] = 108.0
    args['window_area_back'] = 108.0
    args['window_area_left'] = 72.0
    args['window_area_right'] = 72.0
    args['window_aspect_ratio'] = 1.333
    args['window_fraction_operable'] = 0.67
    args['window_ufactor'] = 0.33
    args['window_shgc'] = 0.45
    args['window_interior_shading_winter'] = 0.85
    args['window_interior_shading_summer'] = 0.7
    args['overhangs_front_depth'] = 0
    args['overhangs_back_depth'] = 0
    args['overhangs_left_depth'] = 0
    args['overhangs_right_depth'] = 0
    args['overhangs_front_distance_to_top_of_window'] = 0
    args['overhangs_back_distance_to_top_of_window'] = 0
    args['overhangs_left_distance_to_top_of_window'] = 0
    args['overhangs_right_distance_to_top_of_window'] = 0
    args['skylight_area_front'] = 0
    args['skylight_area_back'] = 0
    args['skylight_area_left'] = 0
    args['skylight_area_right'] = 0
    args['skylight_ufactor'] = 0.33
    args['skylight_shgc'] = 0.45
    args['door_area'] = 40.0
    args['door_rvalue'] = 4.4
    args['air_leakage_units'] = HPXML::UnitsACH
    args['air_leakage_house_pressure'] = 50
    args['air_leakage_value'] = 3
    args['site_shielding_of_home'] = Constants.Auto
    args['heating_system_type'] = HPXML::HVACTypeFurnace
    args['heating_system_fuel'] = HPXML::FuelTypeNaturalGas
    args['heating_system_heating_efficiency'] = 0.92
    args['heating_system_heating_capacity'] = '36000.0'
    args['heating_system_fraction_heat_load_served'] = 1
    args['cooling_system_type'] = HPXML::HVACTypeCentralAirConditioner
    args['cooling_system_cooling_efficiency_type'] = HPXML::UnitsSEER
    args['cooling_system_cooling_efficiency'] = 13.0
    args['cooling_system_cooling_compressor_type'] = HPXML::HVACCompressorTypeSingleStage
    args['cooling_system_cooling_sensible_heat_fraction'] = 0.73
    args['cooling_system_cooling_capacity'] = '24000.0'
    args['cooling_system_fraction_cool_load_served'] = 1
    args['cooling_system_is_ducted'] = false
    args['heat_pump_type'] = 'none'
    args['heat_pump_heating_efficiency_type'] = HPXML::UnitsHSPF
    args['heat_pump_heating_efficiency'] = 7.7
    args['heat_pump_cooling_efficiency_type'] = HPXML::UnitsSEER
    args['heat_pump_cooling_efficiency'] = 13.0
    args['heat_pump_cooling_compressor_type'] = HPXML::HVACCompressorTypeSingleStage
    args['heat_pump_cooling_sensible_heat_fraction'] = 0.73
    args['heat_pump_heating_capacity'] = '36000.0'
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = '36000.0'
    args['heat_pump_fraction_heat_load_served'] = 1
    args['heat_pump_fraction_cool_load_served'] = 1
    args['heat_pump_backup_fuel'] = 'none'
    args['heat_pump_backup_heating_efficiency'] = 1
    args['heat_pump_backup_heating_capacity'] = '36000.0'
    args['hvac_control_heating_weekday_setpoint'] = '68'
    args['hvac_control_heating_weekend_setpoint'] = '68'
    args['hvac_control_cooling_weekday_setpoint'] = '78'
    args['hvac_control_cooling_weekend_setpoint'] = '78'
    args['ducts_leakage_units'] = HPXML::UnitsCFM25
    args['ducts_supply_leakage_to_outside_value'] = 75.0
    args['ducts_return_leakage_to_outside_value'] = 25.0
    args['ducts_supply_insulation_r'] = 4.0
    args['ducts_return_insulation_r'] = 0.0
    args['ducts_supply_location'] = HPXML::LocationAtticUnvented
    args['ducts_return_location'] = HPXML::LocationAtticUnvented
    args['ducts_supply_surface_area'] = '150.0'
    args['ducts_return_surface_area'] = '50.0'
    args['ducts_number_of_return_registers'] = '2'
    args['heating_system_2_type'] = 'none'
    args['heating_system_2_fuel'] = HPXML::FuelTypeElectricity
    args['heating_system_2_heating_efficiency'] = 1.0
    args['heating_system_2_heating_capacity'] = Constants.Auto
    args['heating_system_2_fraction_heat_load_served'] = 0.25
    args['mech_vent_fan_type'] = 'none'
    args['mech_vent_flow_rate'] = '110'
    args['mech_vent_hours_in_operation'] = '24'
    args['mech_vent_recovery_efficiency_type'] = 'Unadjusted'
    args['mech_vent_total_recovery_efficiency'] = 0.48
    args['mech_vent_sensible_recovery_efficiency'] = 0.72
    args['mech_vent_fan_power'] = '30'
    args['mech_vent_num_units_served'] = 1
    args['mech_vent_2_fan_type'] = 'none'
    args['mech_vent_2_flow_rate'] = 110
    args['mech_vent_2_hours_in_operation'] = '24'
    args['mech_vent_2_recovery_efficiency_type'] = 'Unadjusted'
    args['mech_vent_2_total_recovery_efficiency'] = 0.48
    args['mech_vent_2_sensible_recovery_efficiency'] = 0.72
    args['mech_vent_2_fan_power'] = '30'
    args['kitchen_fans_quantity'] = '0'
    args['bathroom_fans_quantity'] = '0'
    args['whole_house_fan_present'] = false
    args['whole_house_fan_flow_rate'] = '4500'
    args['whole_house_fan_power'] = '300'
    args['water_heater_type'] = HPXML::WaterHeaterTypeStorage
    args['water_heater_fuel_type'] = HPXML::FuelTypeElectricity
    args['water_heater_location'] = HPXML::LocationLivingSpace
    args['water_heater_tank_volume'] = '40'
    args['water_heater_efficiency_type'] = 'EnergyFactor'
    args['water_heater_efficiency'] = 0.95
    args['water_heater_recovery_efficiency'] = '0.76'
    args['water_heater_standby_loss'] = 0
    args['water_heater_jacket_rvalue'] = 0
    args['water_heater_setpoint_temperature'] = '125'
    args['water_heater_num_units_served'] = 1
    args['hot_water_distribution_system_type'] = HPXML::DHWDistTypeStandard
    args['hot_water_distribution_standard_piping_length'] = '50'
    args['hot_water_distribution_recirc_control_type'] = HPXML::DHWRecirControlTypeNone
    args['hot_water_distribution_recirc_piping_length'] = '50'
    args['hot_water_distribution_recirc_branch_piping_length'] = '50'
    args['hot_water_distribution_recirc_pump_power'] = '50'
    args['hot_water_distribution_pipe_r'] = '0.0'
    args['dwhr_facilities_connected'] = 'none'
    args['dwhr_equal_flow'] = true
    args['dwhr_efficiency'] = 0.55
    args['water_fixtures_shower_low_flow'] = true
    args['water_fixtures_sink_low_flow'] = false
    args['water_fixtures_usage_multiplier'] = 1.0
    args['solar_thermal_system_type'] = 'none'
    args['solar_thermal_collector_area'] = 40.0
    args['solar_thermal_collector_loop_type'] = HPXML::SolarThermalLoopTypeDirect
    args['solar_thermal_collector_type'] = HPXML::SolarThermalTypeEvacuatedTube
    args['solar_thermal_collector_azimuth'] = 180
    args['solar_thermal_collector_tilt'] = '20'
    args['solar_thermal_collector_rated_optical_efficiency'] = 0.5
    args['solar_thermal_collector_rated_thermal_losses'] = 0.2799
    args['solar_thermal_storage_volume'] = Constants.Auto
    args['solar_thermal_solar_fraction'] = 0
    args['pv_system_module_type'] = 'none'
    args['pv_system_location'] = Constants.Auto
    args['pv_system_tracking'] = Constants.Auto
    args['pv_system_array_azimuth'] = 180
    args['pv_system_array_tilt'] = '20'
    args['pv_system_max_power_output'] = 4000
    args['pv_system_inverter_efficiency'] = 0.96
    args['pv_system_system_losses_fraction'] = 0.14
    args['pv_system_num_units_served'] = 1
    args['pv_system_2_module_type'] = 'none'
    args['pv_system_2_location'] = Constants.Auto
    args['pv_system_2_tracking'] = Constants.Auto
    args['pv_system_2_array_azimuth'] = 180
    args['pv_system_2_array_tilt'] = '20'
    args['pv_system_2_max_power_output'] = 4000
    args['pv_system_2_inverter_efficiency'] = 0.96
    args['pv_system_2_system_losses_fraction'] = 0.14
    args['pv_system_2_num_units_served'] = 1
    args['lighting_interior_fraction_cfl'] = 0.4
    args['lighting_interior_fraction_lfl'] = 0.1
    args['lighting_interior_fraction_led'] = 0.25
    args['lighting_interior_usage_multiplier'] = 1.0
    args['lighting_exterior_fraction_cfl'] = 0.4
    args['lighting_exterior_fraction_lfl'] = 0.1
    args['lighting_exterior_fraction_led'] = 0.25
    args['lighting_exterior_usage_multiplier'] = 1.0
    args['lighting_garage_fraction_cfl'] = 0.4
    args['lighting_garage_fraction_lfl'] = 0.1
    args['lighting_garage_fraction_led'] = 0.25
    args['lighting_garage_usage_multiplier'] = 1.0
    args['holiday_lighting_present'] = false
    args['holiday_lighting_daily_kwh'] = Constants.Auto
    args['dehumidifier_type'] = 'none'
    args['dehumidifier_efficiency_type'] = 'EnergyFactor'
    args['dehumidifier_efficiency'] = 1.8
    args['dehumidifier_capacity'] = 40
    args['dehumidifier_rh_setpoint'] = 0.5
    args['dehumidifier_fraction_dehumidification_load_served'] = 1
    args['clothes_washer_location'] = HPXML::LocationLivingSpace
    args['clothes_washer_efficiency_type'] = 'IntegratedModifiedEnergyFactor'
    args['clothes_washer_efficiency'] = '1.21'
    args['clothes_washer_rated_annual_kwh'] = '380.0'
    args['clothes_washer_label_electric_rate'] = '0.12'
    args['clothes_washer_label_gas_rate'] = '1.09'
    args['clothes_washer_label_annual_gas_cost'] = '27.0'
    args['clothes_washer_label_usage'] = '6.0'
    args['clothes_washer_capacity'] = '3.2'
    args['clothes_washer_usage_multiplier'] = 1.0
    args['clothes_dryer_location'] = HPXML::LocationLivingSpace
    args['clothes_dryer_fuel_type'] = HPXML::FuelTypeElectricity
    args['clothes_dryer_efficiency_type'] = 'CombinedEnergyFactor'
    args['clothes_dryer_efficiency'] = '3.73'
    args['clothes_dryer_vented_flow_rate'] = '150.0'
    args['clothes_dryer_usage_multiplier'] = 1.0
    args['dishwasher_location'] = HPXML::LocationLivingSpace
    args['dishwasher_efficiency_type'] = 'RatedAnnualkWh'
    args['dishwasher_efficiency'] = '307'
    args['dishwasher_label_electric_rate'] = '0.12'
    args['dishwasher_label_gas_rate'] = '1.09'
    args['dishwasher_label_annual_gas_cost'] = '22.32'
    args['dishwasher_label_usage'] = '4.0'
    args['dishwasher_place_setting_capacity'] = '12'
    args['dishwasher_usage_multiplier'] = 1.0
    args['refrigerator_location'] = HPXML::LocationLivingSpace
    args['refrigerator_rated_annual_kwh'] = '650.0'
    args['refrigerator_usage_multiplier'] = 1.0
    args['extra_refrigerator_location'] = 'none'
    args['extra_refrigerator_rated_annual_kwh'] = Constants.Auto
    args['extra_refrigerator_usage_multiplier'] = 1.0
    args['freezer_location'] = 'none'
    args['freezer_rated_annual_kwh'] = Constants.Auto
    args['freezer_usage_multiplier'] = 1.0
    args['cooking_range_oven_location'] = HPXML::LocationLivingSpace
    args['cooking_range_oven_fuel_type'] = HPXML::FuelTypeElectricity
    args['cooking_range_oven_is_induction'] = false
    args['cooking_range_oven_is_convection'] = false
    args['cooking_range_oven_usage_multiplier'] = 1.0
    args['ceiling_fan_present'] = false
    args['ceiling_fan_efficiency'] = Constants.Auto
    args['ceiling_fan_quantity'] = Constants.Auto
    args['ceiling_fan_cooling_setpoint_temp_offset'] = 0
    args['misc_plug_loads_television_annual_kwh'] = '620.0'
    args['misc_plug_loads_television_usage_multiplier'] = 1.0
    args['misc_plug_loads_other_annual_kwh'] = '2457.0'
    args['misc_plug_loads_other_frac_sensible'] = '0.855'
    args['misc_plug_loads_other_frac_latent'] = '0.045'
    args['misc_plug_loads_other_usage_multiplier'] = 1.0
    args['misc_plug_loads_well_pump_present'] = false
    args['misc_plug_loads_well_pump_annual_kwh'] = Constants.Auto
    args['misc_plug_loads_well_pump_usage_multiplier'] = 0.0
    args['misc_plug_loads_vehicle_present'] = false
    args['misc_plug_loads_vehicle_annual_kwh'] = Constants.Auto
    args['misc_plug_loads_vehicle_usage_multiplier'] = 0.0
    args['misc_fuel_loads_grill_present'] = false
    args['misc_fuel_loads_grill_fuel_type'] = HPXML::FuelTypeNaturalGas
    args['misc_fuel_loads_grill_annual_therm'] = Constants.Auto
    args['misc_fuel_loads_grill_usage_multiplier'] = 0.0
    args['misc_fuel_loads_lighting_present'] = false
    args['misc_fuel_loads_lighting_fuel_type'] = HPXML::FuelTypeNaturalGas
    args['misc_fuel_loads_lighting_annual_therm'] = Constants.Auto
    args['misc_fuel_loads_lighting_usage_multiplier'] = 0.0
    args['misc_fuel_loads_fireplace_present'] = false
    args['misc_fuel_loads_fireplace_fuel_type'] = HPXML::FuelTypeNaturalGas
    args['misc_fuel_loads_fireplace_annual_therm'] = Constants.Auto
    args['misc_fuel_loads_fireplace_frac_sensible'] = Constants.Auto
    args['misc_fuel_loads_fireplace_frac_latent'] = Constants.Auto
    args['misc_fuel_loads_fireplace_usage_multiplier'] = 0.0
    args['pool_present'] = false
    args['pool_pump_annual_kwh'] = Constants.Auto
    args['pool_pump_usage_multiplier'] = 1.0
    args['pool_heater_type'] = HPXML::HeaterTypeElectricResistance
    args['pool_heater_annual_kwh'] = Constants.Auto
    args['pool_heater_annual_therm'] = Constants.Auto
    args['pool_heater_usage_multiplier'] = 1.0
    args['hot_tub_present'] = false
    args['hot_tub_pump_annual_kwh'] = Constants.Auto
    args['hot_tub_pump_usage_multiplier'] = 1.0
    args['hot_tub_heater_type'] = HPXML::HeaterTypeElectricResistance
    args['hot_tub_heater_annual_kwh'] = Constants.Auto
    args['hot_tub_heater_annual_therm'] = Constants.Auto
    args['hot_tub_heater_usage_multiplier'] = 1.0
  end

  # Appliances
  if ['base-appliances-coal.xml'].include? hpxml_file
    args['clothes_dryer_fuel_type'] = HPXML::FuelTypeCoal
    args['clothes_dryer_efficiency'] = '3.3'
    args['clothes_dryer_vented_flow_rate'] = Constants.Auto
    args['cooking_range_oven_fuel_type'] = HPXML::FuelTypeCoal
  elsif ['base-appliances-dehumidifier.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = '24000.0'
    args['dehumidifier_type'] = HPXML::DehumidifierTypePortable
  elsif ['base-appliances-dehumidifier-ief-portable.xml'].include? hpxml_file
    args['dehumidifier_efficiency_type'] = 'IntegratedEnergyFactor'
    args['dehumidifier_efficiency'] = '1.5'
  elsif ['base-appliances-dehumidifier-ief-whole-home.xml'].include? hpxml_file
    args['dehumidifier_type'] = HPXML::DehumidifierTypeWholeHome
  elsif ['base-appliances-gas.xml'].include? hpxml_file
    args['clothes_dryer_fuel_type'] = HPXML::FuelTypeNaturalGas
    args['clothes_dryer_efficiency'] = '3.3'
    args['clothes_dryer_vented_flow_rate'] = Constants.Auto
    args['cooking_range_oven_fuel_type'] = HPXML::FuelTypeNaturalGas
  elsif ['base-appliances-modified.xml'].include? hpxml_file
    args['clothes_washer_efficiency_type'] = 'ModifiedEnergyFactor'
    args['clothes_washer_efficiency'] = '1.65'
    args['clothes_dryer_efficiency_type'] = 'EnergyFactor'
    args['clothes_dryer_efficiency'] = '4.29'
    args['clothes_dryer_vented_flow_rate'] = '0.0'
    args['dishwasher_efficiency_type'] = 'EnergyFactor'
    args['dishwasher_efficiency'] = 0.7
    args['dishwasher_place_setting_capacity'] = '6'
  elsif ['base-appliances-none.xml'].include? hpxml_file
    args['clothes_washer_location'] = 'none'
    args['clothes_dryer_location'] = 'none'
    args['dishwasher_location'] = 'none'
    args['refrigerator_location'] = 'none'
    args['cooking_range_oven_location'] = 'none'
  elsif ['base-appliances-oil.xml'].include? hpxml_file
    args['clothes_dryer_fuel_type'] = HPXML::FuelTypeOil
    args['clothes_dryer_efficiency'] = '3.3'
    args['clothes_dryer_vented_flow_rate'] = Constants.Auto
    args['cooking_range_oven_fuel_type'] = HPXML::FuelTypeOil
  elsif ['base-appliances-propane.xml'].include? hpxml_file
    args['clothes_dryer_fuel_type'] = HPXML::FuelTypePropane
    args['clothes_dryer_efficiency'] = '3.3'
    args['clothes_dryer_vented_flow_rate'] = Constants.Auto
    args['cooking_range_oven_fuel_type'] = HPXML::FuelTypePropane
  elsif ['base-appliances-wood.xml'].include? hpxml_file
    args['clothes_dryer_fuel_type'] = HPXML::FuelTypeWoodCord
    args['clothes_dryer_efficiency'] = '3.3'
    args['clothes_dryer_vented_flow_rate'] = Constants.Auto
    args['cooking_range_oven_fuel_type'] = HPXML::FuelTypeWoodCord
  end

  # Attic/roof
  if ['base-atticroof-flat.xml'].include? hpxml_file
    args['geometry_roof_type'] = 'flat'
    args['roof_assembly_r'] = 25.8
    args['ducts_supply_leakage_to_outside_value'] = 0.0
    args['ducts_return_leakage_to_outside_value'] = 0.0
    args['ducts_supply_location'] = HPXML::LocationBasementConditioned
    args['ducts_return_location'] = HPXML::LocationBasementConditioned
  elsif ['base-atticroof-radiant-barrier.xml'].include? hpxml_file
    args['roof_radiant_barrier'] = true
    args['roof_radiant_barrier_grade'] = '2'
    args['ceiling_assembly_r'] = 8.7
  elsif ['base-atticroof-unvented-insulated-roof.xml'].include? hpxml_file
    args['ceiling_assembly_r'] = 2.1
    args['roof_assembly_r'] = 25.8
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    args['geometry_attic_type'] = HPXML::AtticTypeVented
    args['water_heater_location'] = HPXML::LocationAtticVented
    args['ducts_supply_location'] = HPXML::LocationAtticVented
    args['ducts_return_location'] = HPXML::LocationAtticVented
  end

  # Single-Family Attached
  if ['base-bldgtype-single-family-attached.xml'].include? hpxml_file
    args['geometry_unit_type'] = HPXML::ResidentialTypeSFA
    args['geometry_unit_cfa'] = 1800.0
    args['geometry_corridor_position'] = 'None'
    args['geometry_building_num_units'] = 3
    args['geometry_unit_horizontal_location'] = 'Left'
    args['window_front_wwr'] = 0.18
    args['window_back_wwr'] = 0.18
    args['window_left_wwr'] = 0.18
    args['window_right_wwr'] = 0.18
    args['window_area_front'] = 0
    args['window_area_back'] = 0
    args['window_area_left'] = 0
    args['window_area_right'] = 0
    args['heating_system_heating_capacity'] = '24000.0'
    args['misc_plug_loads_other_annual_kwh'] = '1638.0'
  elsif ['base-bldgtype-single-family-attached-2stories.xml'].include? hpxml_file
    args['geometry_num_floors_above_grade'] = 2
    args['geometry_unit_cfa'] = 2700.0
    args['heating_system_heating_capacity'] = '48000.0'
    args['cooling_system_cooling_capacity'] = '36000.0'
    args['ducts_supply_surface_area'] = '112.5'
    args['ducts_return_surface_area'] = '37.5'
    args['ducts_number_of_return_registers'] = '3'
    args['misc_plug_loads_other_annual_kwh'] = '2457.0'
  end

  # Multifamily
  if ['base-bldgtype-multifamily.xml'].include? hpxml_file
    args['geometry_unit_type'] = HPXML::ResidentialTypeApartment
    args['geometry_unit_cfa'] = 900.0
    args['geometry_corridor_position'] = 'None'
    args['geometry_foundation_type'] = HPXML::FoundationTypeBasementUnconditioned
    args['geometry_unit_level'] = 'Middle'
    args['geometry_unit_horizontal_location'] = 'Left'
    args['geometry_building_num_units'] = 6
    args['geometry_building_num_bedrooms'] = 6 * 3
    args['geometry_num_floors_above_grade'] = 3
    args['window_front_wwr'] = 0.18
    args['window_back_wwr'] = 0.18
    args['window_left_wwr'] = 0.18
    args['window_right_wwr'] = 0.18
    args['window_area_front'] = 0
    args['window_area_back'] = 0
    args['window_area_left'] = 0
    args['window_area_right'] = 0
    args['heating_system_heating_capacity'] = '12000.0'
    args['cooling_system_cooling_capacity'] = '12000.0'
    args['ducts_supply_leakage_to_outside_value'] = 0.0
    args['ducts_return_leakage_to_outside_value'] = 0.0
    args['ducts_supply_location'] = HPXML::LocationLivingSpace
    args['ducts_return_location'] = HPXML::LocationLivingSpace
    args['ducts_supply_insulation_r'] = 0.0
    args['ducts_return_insulation_r'] = 0.0
    args['ducts_number_of_return_registers'] = '1'
    args['door_area'] = 20.0
    args['misc_plug_loads_other_annual_kwh'] = '819.0'
  elsif ['base-bldgtype-multifamily-shared-boiler-only-baseboard.xml'].include? hpxml_file
    args['heating_system_type'] = "Shared #{HPXML::HVACTypeBoiler} w/ Baseboard"
    args['cooling_system_type'] = 'none'
  elsif ['base-bldgtype-multifamily-shared-boiler-only-fan-coil.xml'].include? hpxml_file
    args['heating_system_type'] = "Shared #{HPXML::HVACTypeBoiler} w/ Ductless Fan Coil"
    args['cooling_system_type'] = 'none'
  elsif ['base-bldgtype-multifamily-shared-mechvent.xml'].include? hpxml_file
    args['mech_vent_fan_type'] = HPXML::MechVentTypeSupply
    args['mech_vent_flow_rate'] = '800'
    args['mech_vent_fan_power'] = '240'
    args['mech_vent_num_units_served'] = 10
    args['mech_vent_shared_frac_recirculation'] = 0.5
    args['mech_vent_2_fan_type'] = HPXML::MechVentTypeExhaust
    args['mech_vent_2_flow_rate'] = 72
    args['mech_vent_2_fan_power'] = '26'
  elsif ['base-bldgtype-multifamily-shared-mechvent-preconditioning.xml'].include? hpxml_file
    args['mech_vent_shared_preheating_fuel'] = HPXML::FuelTypeNaturalGas
    args['mech_vent_shared_preheating_efficiency'] = 0.92
    args['mech_vent_shared_preheating_fraction_heat_load_served'] = 0.7
    args['mech_vent_shared_precooling_fuel'] = HPXML::FuelTypeElectricity
    args['mech_vent_shared_precooling_efficiency'] = 4.0
    args['mech_vent_shared_precooling_fraction_cool_load_served'] = 0.8
  elsif ['base-bldgtype-multifamily-shared-pv.xml'].include? hpxml_file
    args['pv_system_num_units_served'] = 6
    args['pv_system_location'] = HPXML::LocationGround
    args['pv_system_module_type'] = HPXML::PVModuleTypeStandard
    args['pv_system_tracking'] = HPXML::PVTrackingTypeFixed
    args['pv_system_array_azimuth'] = 225
    args['pv_system_array_tilt'] = '30'
    args['pv_system_max_power_output'] = 30000
    args['pv_system_inverter_efficiency'] = 0.96
    args['pv_system_system_losses_fraction'] = 0.14
  elsif ['base-bldgtype-multifamily-shared-water-heater.xml'].include? hpxml_file
    args['water_heater_fuel_type'] = HPXML::FuelTypeNaturalGas
    args['water_heater_num_units_served'] = 6
    args['water_heater_tank_volume'] = '120'
    args['water_heater_efficiency'] = 0.59
    args['water_heater_recovery_efficiency'] = '0.76'
  end

  # DHW
  if ['base-dhw-combi-tankless.xml'].include? hpxml_file
    args['water_heater_type'] = HPXML::WaterHeaterTypeCombiTankless
    args['water_heater_tank_volume'] = Constants.Auto
  elsif ['base-dhw-combi-tankless-outside.xml'].include? hpxml_file
    args['water_heater_location'] = HPXML::LocationOtherExterior
  elsif ['base-dhw-dwhr.xml'].include? hpxml_file
    args['dwhr_facilities_connected'] = HPXML::DWHRFacilitiesConnectedAll
  elsif ['base-dhw-indirect.xml'].include? hpxml_file
    args['water_heater_type'] = HPXML::WaterHeaterTypeCombiStorage
    args['water_heater_tank_volume'] = '50'
  elsif ['base-dhw-indirect-outside.xml'].include? hpxml_file
    args['water_heater_location'] = HPXML::LocationOtherExterior
  elsif ['base-dhw-indirect-standbyloss.xml'].include? hpxml_file
    args['water_heater_standby_loss'] = 1.0
  elsif ['base-dhw-indirect-with-solar-fraction.xml'].include? hpxml_file
    args['solar_thermal_system_type'] = 'hot water'
    args['solar_thermal_solar_fraction'] = 0.65
  elsif ['base-dhw-jacket-electric.xml'].include? hpxml_file
    args['water_heater_jacket_rvalue'] = 10.0
  elsif ['base-dhw-jacket-gas.xml'].include? hpxml_file
    args['water_heater_jacket_rvalue'] = 10.0
  elsif ['base-dhw-jacket-hpwh.xml'].include? hpxml_file
    args['water_heater_jacket_rvalue'] = 10.0
  elsif ['base-dhw-jacket-indirect.xml'].include? hpxml_file
    args['water_heater_jacket_rvalue'] = 10.0
  elsif ['base-dhw-low-flow-fixtures.xml'].include? hpxml_file
    args['water_fixtures_sink_low_flow'] = true
  elsif ['base-dhw-none.xml'].include? hpxml_file
    args['water_heater_type'] = 'none'
    args['dishwasher_location'] = 'none'
  elsif ['base-dhw-recirc-demand.xml'].include? hpxml_file
    args['hot_water_distribution_system_type'] = HPXML::DHWDistTypeRecirc
    args['hot_water_distribution_recirc_control_type'] = HPXML::DHWRecirControlTypeSensor
    args['hot_water_distribution_pipe_r'] = '3.0'
  elsif ['base-dhw-recirc-manual.xml'].include? hpxml_file
    args['hot_water_distribution_system_type'] = HPXML::DHWDistTypeRecirc
    args['hot_water_distribution_recirc_control_type'] = HPXML::DHWRecirControlTypeManual
    args['hot_water_distribution_pipe_r'] = '3.0'
  elsif ['base-dhw-recirc-nocontrol.xml'].include? hpxml_file
    args['hot_water_distribution_system_type'] = HPXML::DHWDistTypeRecirc
  elsif ['base-dhw-recirc-temperature.xml'].include? hpxml_file
    args['hot_water_distribution_system_type'] = HPXML::DHWDistTypeRecirc
    args['hot_water_distribution_recirc_control_type'] = HPXML::DHWRecirControlTypeTemperature
  elsif ['base-dhw-recirc-timer.xml'].include? hpxml_file
    args['hot_water_distribution_system_type'] = HPXML::DHWDistTypeRecirc
    args['hot_water_distribution_recirc_control_type'] = HPXML::DHWRecirControlTypeTimer
  elsif ['base-dhw-solar-direct-evacuated-tube.xml'].include? hpxml_file
    args['solar_thermal_system_type'] = 'hot water'
    args['solar_thermal_storage_volume'] = '60'
  elsif ['base-dhw-solar-direct-flat-plate.xml'].include? hpxml_file
    args['solar_thermal_system_type'] = 'hot water'
    args['solar_thermal_collector_type'] = HPXML::SolarThermalTypeSingleGlazing
    args['solar_thermal_collector_rated_optical_efficiency'] = 0.77
    args['solar_thermal_collector_rated_thermal_losses'] = 0.793
    args['solar_thermal_storage_volume'] = '60'
  elsif ['base-dhw-solar-direct-ics.xml'].include? hpxml_file
    args['solar_thermal_system_type'] = 'hot water'
    args['solar_thermal_collector_type'] = HPXML::SolarThermalTypeICS
    args['solar_thermal_collector_rated_optical_efficiency'] = 0.77
    args['solar_thermal_collector_rated_thermal_losses'] = 0.793
    args['solar_thermal_storage_volume'] = '60'
  elsif ['base-dhw-solar-fraction.xml'].include? hpxml_file
    args['solar_thermal_system_type'] = 'hot water'
    args['solar_thermal_solar_fraction'] = 0.65
  elsif ['base-dhw-solar-indirect-flat-plate.xml'].include? hpxml_file
    args['solar_thermal_system_type'] = 'hot water'
    args['solar_thermal_collector_loop_type'] = HPXML::SolarThermalLoopTypeIndirect
    args['solar_thermal_collector_type'] = HPXML::SolarThermalTypeSingleGlazing
    args['solar_thermal_collector_rated_optical_efficiency'] = 0.77
    args['solar_thermal_collector_rated_thermal_losses'] = 0.793
    args['solar_thermal_storage_volume'] = '60'
  elsif ['base-dhw-solar-thermosyphon-flat-plate.xml'].include? hpxml_file
    args['solar_thermal_system_type'] = 'hot water'
    args['solar_thermal_collector_loop_type'] = HPXML::SolarThermalLoopTypeThermosyphon
    args['solar_thermal_collector_type'] = HPXML::SolarThermalTypeSingleGlazing
    args['solar_thermal_collector_rated_optical_efficiency'] = 0.77
    args['solar_thermal_collector_rated_thermal_losses'] = 0.793
    args['solar_thermal_storage_volume'] = '60'
  elsif ['base-dhw-tank-coal.xml'].include? hpxml_file
    args['water_heater_fuel_type'] = HPXML::FuelTypeCoal
    args['water_heater_tank_volume'] = '50'
    args['water_heater_efficiency'] = 0.59
  elsif ['base-dhw-tank-elec-uef.xml'].include? hpxml_file
    args['water_heater_tank_volume'] = '30'
    args['water_heater_efficiency_type'] = 'UniformEnergyFactor'
    args['water_heater_efficiency'] = 0.93
    args['water_heater_usage_bin'] = HPXML::WaterHeaterUsageBinLow
    args['water_heater_recovery_efficiency'] = 0.98
  elsif ['base-dhw-tank-gas.xml'].include? hpxml_file
    args['water_heater_fuel_type'] = HPXML::FuelTypeNaturalGas
    args['water_heater_tank_volume'] = '50'
    args['water_heater_efficiency'] = 0.59
  elsif ['base-dhw-tank-gas-uef.xml'].include? hpxml_file
    args['water_heater_fuel_type'] = HPXML::FuelTypeNaturalGas
    args['water_heater_tank_volume'] = '30'
    args['water_heater_efficiency_type'] = 'UniformEnergyFactor'
    args['water_heater_efficiency'] = 0.59
    args['water_heater_usage_bin'] = HPXML::WaterHeaterUsageBinMedium
    args['water_heater_recovery_efficiency'] = 0.75
  elsif ['base-dhw-tank-gas-outside.xml'].include? hpxml_file
    args['water_heater_location'] = HPXML::LocationOtherExterior
  elsif ['base-dhw-tank-heat-pump.xml'].include? hpxml_file
    args['water_heater_type'] = HPXML::WaterHeaterTypeHeatPump
    args['water_heater_tank_volume'] = '80'
    args['water_heater_efficiency'] = 2.3
  elsif ['base-dhw-tank-heat-pump-outside.xml'].include? hpxml_file
    args['water_heater_type'] = HPXML::WaterHeaterTypeHeatPump
    args['water_heater_location'] = HPXML::LocationOtherExterior
    args['water_heater_tank_volume'] = '80'
    args['water_heater_efficiency'] = 2.3
  elsif ['base-dhw-tank-heat-pump-uef.xml'].include? hpxml_file
    args['water_heater_tank_volume'] = '50'
    args['water_heater_efficiency_type'] = 'UniformEnergyFactor'
    args['water_heater_efficiency'] = 3.75
    args['water_heater_usage_bin'] = HPXML::WaterHeaterUsageBinMedium
  elsif ['base-dhw-tank-heat-pump-with-solar.xml'].include? hpxml_file
    args['water_heater_type'] = HPXML::WaterHeaterTypeHeatPump
    args['water_heater_tank_volume'] = '80'
    args['water_heater_efficiency'] = 2.3
    args['solar_thermal_system_type'] = 'hot water'
    args['solar_thermal_collector_loop_type'] = HPXML::SolarThermalLoopTypeIndirect
    args['solar_thermal_collector_type'] = HPXML::SolarThermalTypeSingleGlazing
    args['solar_thermal_collector_rated_optical_efficiency'] = 0.77
    args['solar_thermal_collector_rated_thermal_losses'] = 0.793
    args['solar_thermal_storage_volume'] = '60'
  elsif ['base-dhw-tank-heat-pump-with-solar-fraction.xml'].include? hpxml_file
    args['water_heater_type'] = HPXML::WaterHeaterTypeHeatPump
    args['water_heater_tank_volume'] = '80'
    args['water_heater_efficiency'] = 2.3
    args['solar_thermal_system_type'] = 'hot water'
    args['solar_thermal_solar_fraction'] = 0.65
  elsif ['base-dhw-tankless-electric.xml'].include? hpxml_file
    args['water_heater_type'] = HPXML::WaterHeaterTypeTankless
    args['water_heater_tank_volume'] = Constants.Auto
    args['water_heater_efficiency'] = 0.99
  elsif ['base-dhw-tankless-electric-outside.xml'].include? hpxml_file
    args['water_heater_type'] = HPXML::WaterHeaterTypeTankless
    args['water_heater_location'] = HPXML::LocationOtherExterior
    args['water_heater_tank_volume'] = Constants.Auto
    args['water_heater_efficiency'] = 0.99
  elsif ['base-dhw-tankless-electric-uef.xml'].include? hpxml_file
    args['water_heater_efficiency_type'] = 'UniformEnergyFactor'
    args['water_heater_efficiency'] = 0.98
  elsif ['base-dhw-tankless-gas.xml'].include? hpxml_file
    args['water_heater_type'] = HPXML::WaterHeaterTypeTankless
    args['water_heater_fuel_type'] = HPXML::FuelTypeNaturalGas
    args['water_heater_tank_volume'] = Constants.Auto
    args['water_heater_efficiency'] = 0.82
  elsif ['base-dhw-tankless-gas-uef.xml'].include? hpxml_file
    args['water_heater_efficiency_type'] = 'UniformEnergyFactor'
    args['water_heater_efficiency'] = 0.93
  elsif ['base-dhw-tankless-gas-with-solar.xml'].include? hpxml_file
    args['water_heater_type'] = HPXML::WaterHeaterTypeTankless
    args['water_heater_fuel_type'] = HPXML::FuelTypeNaturalGas
    args['water_heater_tank_volume'] = Constants.Auto
    args['water_heater_efficiency'] = 0.82
    args['solar_thermal_system_type'] = 'hot water'
    args['solar_thermal_collector_loop_type'] = HPXML::SolarThermalLoopTypeIndirect
    args['solar_thermal_collector_type'] = HPXML::SolarThermalTypeSingleGlazing
    args['solar_thermal_collector_rated_optical_efficiency'] = 0.77
    args['solar_thermal_collector_rated_thermal_losses'] = 0.793
    args['solar_thermal_storage_volume'] = '60'
  elsif ['base-dhw-tankless-gas-with-solar-fraction.xml'].include? hpxml_file
    args['water_heater_type'] = HPXML::WaterHeaterTypeTankless
    args['water_heater_fuel_type'] = HPXML::FuelTypeNaturalGas
    args['water_heater_tank_volume'] = Constants.Auto
    args['water_heater_efficiency'] = 0.82
    args['solar_thermal_system_type'] = 'hot water'
    args['solar_thermal_solar_fraction'] = 0.65
  elsif ['base-dhw-tankless-propane.xml'].include? hpxml_file
    args['water_heater_type'] = HPXML::WaterHeaterTypeTankless
    args['water_heater_fuel_type'] = HPXML::FuelTypePropane
    args['water_heater_tank_volume'] = Constants.Auto
    args['water_heater_efficiency'] = 0.82
  elsif ['base-dhw-tank-oil.xml'].include? hpxml_file
    args['water_heater_fuel_type'] = HPXML::FuelTypeOil
    args['water_heater_tank_volume'] = '50'
    args['water_heater_efficiency'] = 0.59
  elsif ['base-dhw-tank-wood.xml'].include? hpxml_file
    args['water_heater_fuel_type'] = HPXML::FuelTypeWoodCord
    args['water_heater_tank_volume'] = '50'
    args['water_heater_efficiency'] = 0.59
  end

  # Enclosure
  if ['base-enclosure-2stories.xml'].include? hpxml_file
    args['geometry_unit_cfa'] = 4050.0
    args['geometry_num_floors_above_grade'] = 2
    args['window_area_front'] = 216.0
    args['window_area_back'] = 216.0
    args['window_area_left'] = 144.0
    args['window_area_right'] = 144.0
    args['heating_system_heating_capacity'] = '48000.0'
    args['cooling_system_cooling_capacity'] = '36000.0'
    args['ducts_supply_surface_area'] = '112.5'
    args['ducts_return_surface_area'] = '37.5'
    args['ducts_number_of_return_registers'] = '3'
    args['misc_plug_loads_other_annual_kwh'] = '3685.5'
  elsif ['base-enclosure-2stories-garage.xml'].include? hpxml_file
    args['geometry_unit_cfa'] = 3250.0
    args['geometry_garage_width'] = 20.0
    args['ducts_supply_surface_area'] = '112.5'
    args['ducts_return_surface_area'] = '37.5'
    args['misc_plug_loads_other_annual_kwh'] = '2957.5'
    args['floor_over_garage_assembly_r'] = 39.3
  elsif ['base-enclosure-beds-1.xml'].include? hpxml_file
    args['geometry_unit_num_bedrooms'] = 1
    args['geometry_unit_num_bathrooms'] = '1'
    args['geometry_unit_num_occupants'] = '1'
    args['misc_plug_loads_television_annual_kwh'] = '482.0'
  elsif ['base-enclosure-beds-2.xml'].include? hpxml_file
    args['geometry_unit_num_bedrooms'] = 2
    args['geometry_unit_num_bathrooms'] = '1'
    args['geometry_unit_num_occupants'] = '2'
    args['misc_plug_loads_television_annual_kwh'] = '551.0'
  elsif ['base-enclosure-beds-4.xml'].include? hpxml_file
    args['geometry_unit_num_bedrooms'] = 4
    args['geometry_unit_num_occupants'] = '4'
    args['misc_plug_loads_television_annual_kwh'] = '689.0'
  elsif ['base-enclosure-beds-5.xml'].include? hpxml_file
    args['geometry_unit_num_bedrooms'] = 5
    args['geometry_unit_num_bathrooms'] = '3'
    args['geometry_unit_num_occupants'] = '5'
    args['misc_plug_loads_television_annual_kwh'] = '758.0'
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    args['geometry_garage_width'] = 30.0
    args['geometry_garage_protrusion'] = 1.0
    args['window_area_front'] = 12.0
    args['ducts_supply_location'] = HPXML::LocationGarage
    args['ducts_return_location'] = HPXML::LocationGarage
    args['water_heater_location'] = HPXML::LocationGarage
    args['clothes_washer_location'] = HPXML::LocationGarage
    args['clothes_dryer_location'] = HPXML::LocationGarage
    args['dishwasher_location'] = HPXML::LocationGarage
    args['refrigerator_location'] = HPXML::LocationGarage
    args['cooking_range_oven_location'] = HPXML::LocationGarage
  elsif ['base-enclosure-infil-ach-house-pressure.xml'].include? hpxml_file
    args['air_leakage_house_pressure'] = 45
    args['air_leakage_value'] = 2.8014
  elsif ['base-enclosure-infil-cfm-house-pressure.xml'].include? hpxml_file
    args['air_leakage_house_pressure'] = 45
    args['air_leakage_value'] = 1008.5039999999999
  elsif ['base-enclosure-infil-cfm50.xml'].include? hpxml_file
    args['air_leakage_units'] = HPXML::UnitsCFM
    args['air_leakage_value'] = 1080
  elsif ['base-enclosure-infil-flue.xml'].include? hpxml_file
    args['geometry_has_flue_or_chimney'] = 'true'
  elsif ['base-enclosure-infil-natural-ach.xml'].include? hpxml_file
    args['air_leakage_units'] = HPXML::UnitsACHNatural
    args['air_leakage_value'] = 0.2
  elsif ['base-enclosure-other-heated-space.xml'].include? hpxml_file
    args['geometry_unit_type'] = HPXML::ResidentialTypeApartment
    args['ducts_supply_location'] = HPXML::LocationOtherHeatedSpace
    args['ducts_return_location'] = HPXML::LocationOtherHeatedSpace
    args['water_heater_location'] = HPXML::LocationOtherHeatedSpace
    args['clothes_washer_location'] = HPXML::LocationOtherHeatedSpace
    args['clothes_dryer_location'] = HPXML::LocationOtherHeatedSpace
    args['dishwasher_location'] = HPXML::LocationOtherHeatedSpace
    args['refrigerator_location'] = HPXML::LocationOtherHeatedSpace
    args['cooking_range_oven_location'] = HPXML::LocationOtherHeatedSpace
  elsif ['base-enclosure-other-housing-unit.xml'].include? hpxml_file
    args['geometry_unit_type'] = HPXML::ResidentialTypeApartment
    args['ducts_supply_location'] = HPXML::LocationOtherHousingUnit
    args['ducts_return_location'] = HPXML::LocationOtherHousingUnit
    args['water_heater_location'] = HPXML::LocationOtherHousingUnit
    args['clothes_washer_location'] = HPXML::LocationOtherHousingUnit
    args['clothes_dryer_location'] = HPXML::LocationOtherHousingUnit
    args['dishwasher_location'] = HPXML::LocationOtherHousingUnit
    args['refrigerator_location'] = HPXML::LocationOtherHousingUnit
    args['cooking_range_oven_location'] = HPXML::LocationOtherHousingUnit
  elsif ['base-enclosure-other-multifamily-buffer-space.xml'].include? hpxml_file
    args['geometry_unit_type'] = HPXML::ResidentialTypeApartment
    args['ducts_supply_location'] = HPXML::LocationOtherMultifamilyBufferSpace
    args['ducts_return_location'] = HPXML::LocationOtherMultifamilyBufferSpace
    args['water_heater_location'] = HPXML::LocationOtherMultifamilyBufferSpace
    args['clothes_washer_location'] = HPXML::LocationOtherMultifamilyBufferSpace
    args['clothes_dryer_location'] = HPXML::LocationOtherMultifamilyBufferSpace
    args['dishwasher_location'] = HPXML::LocationOtherMultifamilyBufferSpace
    args['refrigerator_location'] = HPXML::LocationOtherMultifamilyBufferSpace
    args['cooking_range_oven_location'] = HPXML::LocationOtherMultifamilyBufferSpace
  elsif ['base-enclosure-other-non-freezing-space.xml'].include? hpxml_file
    args['geometry_unit_type'] = HPXML::ResidentialTypeApartment
    args['ducts_supply_location'] = HPXML::LocationOtherNonFreezingSpace
    args['ducts_return_location'] = HPXML::LocationOtherNonFreezingSpace
    args['water_heater_location'] = HPXML::LocationOtherNonFreezingSpace
    args['clothes_washer_location'] = HPXML::LocationOtherNonFreezingSpace
    args['clothes_dryer_location'] = HPXML::LocationOtherNonFreezingSpace
    args['dishwasher_location'] = HPXML::LocationOtherNonFreezingSpace
    args['refrigerator_location'] = HPXML::LocationOtherNonFreezingSpace
    args['cooking_range_oven_location'] = HPXML::LocationOtherNonFreezingSpace
  elsif ['base-enclosure-overhangs.xml'].include? hpxml_file
    args['overhangs_front_distance_to_top_of_window'] = 1.0
    args['overhangs_back_depth'] = 2.5
    args['overhangs_left_depth'] = 1.5
    args['overhangs_left_distance_to_top_of_window'] = 2.0
    args['overhangs_right_depth'] = 1.5
    args['overhangs_right_distance_to_top_of_window'] = 2.0
  elsif ['base-enclosure-windows-none.xml'].include? hpxml_file
    args['window_area_front'] = 0
    args['window_area_back'] = 0
    args['window_area_left'] = 0
    args['window_area_right'] = 0
  end

  # Foundation
  if ['base-foundation-ambient.xml'].include? hpxml_file
    args['geometry_unit_cfa'] = 1350.0
    args['geometry_foundation_type'] = HPXML::FoundationTypeAmbient
    args.delete('geometry_rim_joist_height')
    args['floor_over_foundation_assembly_r'] = 18.7
    args.delete('rim_joist_assembly_r')
    args['ducts_number_of_return_registers'] = '1'
    args['misc_plug_loads_other_annual_kwh'] = '1228.5'
  elsif ['base-foundation-conditioned-basement-slab-insulation.xml'].include? hpxml_file
    args['slab_under_insulation_r'] = 10
    args['slab_under_width'] = 4
  elsif ['base-foundation-conditioned-basement-wall-interior-insulation.xml'].include? hpxml_file
    args['foundation_wall_insulation_r'] = 18.9
    args['foundation_wall_insulation_distance_to_top'] = '1.0'
  elsif ['base-foundation-slab.xml'].include? hpxml_file
    args['geometry_unit_cfa'] = 1350.0
    args['geometry_foundation_type'] = HPXML::FoundationTypeSlab
    args['geometry_foundation_height'] = 0.0
    args['geometry_foundation_height_above_grade'] = 0.0
    args['foundation_wall_insulation_distance_to_bottom'] = Constants.Auto
    args['slab_under_insulation_r'] = 5
    args['slab_under_width'] = 999
    args['slab_carpet_fraction'] = '1.0'
    args['slab_carpet_r'] = '2.5'
    args['ducts_supply_location'] = HPXML::LocationUnderSlab
    args['ducts_return_location'] = HPXML::LocationUnderSlab
    args['ducts_number_of_return_registers'] = '1'
    args['misc_plug_loads_other_annual_kwh'] = '1228.5'
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    args['geometry_unit_cfa'] = 1350.0
    args['geometry_foundation_type'] = HPXML::FoundationTypeBasementUnconditioned
    args['floor_over_foundation_assembly_r'] = 18.7
    args['foundation_wall_insulation_r'] = 0
    args['foundation_wall_insulation_distance_to_bottom'] = '0.0'
    args['rim_joist_assembly_r'] = 4.0
    args['ducts_supply_location'] = HPXML::LocationBasementUnconditioned
    args['ducts_return_location'] = HPXML::LocationBasementUnconditioned
    args['ducts_number_of_return_registers'] = '1'
    args['water_heater_location'] = HPXML::LocationBasementUnconditioned
    args['clothes_washer_location'] = HPXML::LocationBasementUnconditioned
    args['clothes_dryer_location'] = HPXML::LocationBasementUnconditioned
    args['dishwasher_location'] = HPXML::LocationBasementUnconditioned
    args['refrigerator_location'] = HPXML::LocationBasementUnconditioned
    args['cooking_range_oven_location'] = HPXML::LocationBasementUnconditioned
    args['misc_plug_loads_other_annual_kwh'] = '1228.5'
  elsif ['base-foundation-unconditioned-basement-above-grade.xml'].include? hpxml_file
    args['geometry_unit_cfa'] = 1350.0
    args['geometry_foundation_type'] = HPXML::FoundationTypeBasementUnconditioned
    args['geometry_foundation_height_above_grade'] = 4.0
    args['foundation_wall_insulation_r'] = 0
    args['foundation_wall_insulation_distance_to_bottom'] = '0.0'
    args['ducts_supply_location'] = HPXML::LocationBasementUnconditioned
    args['ducts_return_location'] = HPXML::LocationBasementUnconditioned
    args['water_heater_location'] = HPXML::LocationBasementUnconditioned
    args['clothes_washer_location'] = HPXML::LocationBasementUnconditioned
    args['clothes_dryer_location'] = HPXML::LocationBasementUnconditioned
    args['dishwasher_location'] = HPXML::LocationBasementUnconditioned
    args['refrigerator_location'] = HPXML::LocationBasementUnconditioned
    args['cooking_range_oven_location'] = HPXML::LocationBasementUnconditioned
    args['misc_plug_loads_other_annual_kwh'] = '1228.5'
  elsif ['base-foundation-unconditioned-basement-assembly-r.xml'].include? hpxml_file
    args['foundation_wall_assembly_r'] = 10.69
  elsif ['base-foundation-unconditioned-basement-wall-insulation.xml'].include? hpxml_file
    args['floor_over_foundation_assembly_r'] = 2.1
    args['foundation_wall_insulation_r'] = 8.9
    args['foundation_wall_insulation_distance_to_bottom'] = '4.0'
    args['rim_joist_assembly_r'] = 23.0
  elsif ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
    args['geometry_unit_cfa'] = 1350.0
    args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceUnvented
    args['geometry_foundation_height'] = 4.0
    args['floor_over_foundation_assembly_r'] = 18.7
    args['foundation_wall_insulation_distance_to_bottom'] = '4.0'
    args['slab_carpet_r'] = '2.5'
    args['ducts_supply_location'] = HPXML::LocationCrawlspaceUnvented
    args['ducts_return_location'] = HPXML::LocationCrawlspaceUnvented
    args['ducts_number_of_return_registers'] = '1'
    args['water_heater_location'] = HPXML::LocationCrawlspaceUnvented
    args['misc_plug_loads_other_annual_kwh'] = '1228.5'
  elsif ['base-foundation-vented-crawlspace.xml'].include? hpxml_file
    args['geometry_unit_cfa'] = 1350.0
    args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceVented
    args['geometry_foundation_height'] = 4.0
    args['floor_over_foundation_assembly_r'] = 18.7
    args['foundation_wall_insulation_distance_to_bottom'] = '4.0'
    args['slab_carpet_r'] = '2.5'
    args['ducts_supply_location'] = HPXML::LocationCrawlspaceVented
    args['ducts_return_location'] = HPXML::LocationCrawlspaceVented
    args['ducts_number_of_return_registers'] = '1'
    args['water_heater_location'] = HPXML::LocationCrawlspaceVented
    args['misc_plug_loads_other_annual_kwh'] = '1228.5'
  elsif ['base-foundation-walkout-basement.xml'].include? hpxml_file
    args['geometry_foundation_height_above_grade'] = 5.0
    args['foundation_wall_insulation_distance_to_bottom'] = '4.0'
  end

  # HVAC
  if ['base-hvac-air-to-air-heat-pump-1-speed.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
    args['cooling_system_type'] = 'none'
    args['heat_pump_type'] = HPXML::HVACTypeHeatPumpAirToAir
    args['heat_pump_heating_capacity_17_f'] = '22680.0'
    args['heat_pump_backup_fuel'] = HPXML::FuelTypeElectricity
  elsif ['base-hvac-air-to-air-heat-pump-1-speed-cooling-only.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = '0.0'
    args['heat_pump_heating_capacity_17_f'] = '0.0'
    args['heat_pump_fraction_heat_load_served'] = 0
    args['heat_pump_backup_fuel'] = 'none'
  elsif ['base-hvac-air-to-air-heat-pump-1-speed-heating-only.xml'].include? hpxml_file
    args['heat_pump_cooling_capacity'] = '0.0'
    args['heat_pump_fraction_cool_load_served'] = 0
  elsif ['base-hvac-air-to-air-heat-pump-2-speed.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
    args['cooling_system_type'] = 'none'
    args['heat_pump_type'] = HPXML::HVACTypeHeatPumpAirToAir
    args['heat_pump_heating_efficiency'] = 9.3
    args['heat_pump_cooling_compressor_type'] = HPXML::HVACCompressorTypeTwoStage
    args['heat_pump_heating_capacity_17_f'] = '21240.0'
    args['heat_pump_cooling_efficiency'] = 18.0
    args['heat_pump_backup_fuel'] = HPXML::FuelTypeElectricity
  elsif ['base-hvac-air-to-air-heat-pump-var-speed.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
    args['cooling_system_type'] = 'none'
    args['heat_pump_type'] = HPXML::HVACTypeHeatPumpAirToAir
    args['heat_pump_heating_efficiency'] = 10.0
    args['heat_pump_cooling_compressor_type'] = HPXML::HVACCompressorTypeVariableSpeed
    args['heat_pump_cooling_sensible_heat_fraction'] = 0.78
    args['heat_pump_heating_capacity_17_f'] = '23040.0'
    args['heat_pump_cooling_efficiency'] = 22.0
    args['heat_pump_backup_fuel'] = HPXML::FuelTypeElectricity
  elsif ['base-hvac-autosize.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-air-to-air-heat-pump-1-speed.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.AutoMaxLoad
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-air-to-air-heat-pump-1-speed-cooling-only.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.AutoMaxLoad
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-air-to-air-heat-pump-1-speed-heating-only.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.AutoMaxLoad
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-air-to-air-heat-pump-1-speed-manual-s-oversize-allowances.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.Auto
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-air-to-air-heat-pump-2-speed.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.AutoMaxLoad
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-air-to-air-heat-pump-2-speed-manual-s-oversize-allowances.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.Auto
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-air-to-air-heat-pump-var-speed.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.AutoMaxLoad
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-air-to-air-heat-pump-var-speed-manual-s-oversize-allowances.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.Auto
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-boiler-elec-only.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-boiler-gas-central-ac-1-speed.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-boiler-gas-only.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-central-ac-only-1-speed.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-central-ac-only-2-speed.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-central-ac-only-var-speed.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-central-ac-plus-air-to-air-heat-pump-heating.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
    args['heat_pump_heating_capacity'] = Constants.AutoMaxLoad
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-dual-fuel-air-to-air-heat-pump-1-speed.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.AutoMaxLoad
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-dual-fuel-mini-split-heat-pump-ducted.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.AutoMaxLoad
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-elec-resistance-only.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-evap-cooler-furnace-gas.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-floor-furnace-propane-only.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-furnace-elec-only.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-furnace-gas-central-ac-2-speed.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-furnace-gas-central-ac-var-speed.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-furnace-gas-only.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-furnace-gas-room-ac.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-ground-to-air-heat-pump.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.AutoMaxLoad
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-ground-to-air-heat-pump-cooling-only.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.AutoMaxLoad
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-ground-to-air-heat-pump-heating-only.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.AutoMaxLoad
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-ground-to-air-heat-pump-manual-s-oversize-allowances.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.Auto
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-mini-split-heat-pump-ducted.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.AutoMaxLoad
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-mini-split-heat-pump-ducted-cooling-only.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.AutoMaxLoad
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-mini-split-heat-pump-ducted-heating-only.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.AutoMaxLoad
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-mini-split-heat-pump-ducted-manual-s-oversize-allowances.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = Constants.Auto
    args['heat_pump_heating_capacity_17_f'] = Constants.Auto
    args['heat_pump_backup_heating_capacity'] = Constants.Auto
    args['heat_pump_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-mini-split-air-conditioner-only-ducted.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-room-ac-only.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-stove-oil-only.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-autosize-wall-furnace-elec-only.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = Constants.Auto
    args['cooling_system_cooling_capacity'] = Constants.Auto
  elsif ['base-hvac-boiler-coal-only.xml'].include? hpxml_file
    args['heating_system_type'] = HPXML::HVACTypeBoiler
    args['heating_system_fuel'] = HPXML::FuelTypeCoal
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-boiler-elec-only.xml'].include? hpxml_file
    args['heating_system_type'] = HPXML::HVACTypeBoiler
    args['heating_system_fuel'] = HPXML::FuelTypeElectricity
    args['heating_system_heating_efficiency'] = 0.98
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-boiler-gas-central-ac-1-speed.xml'].include? hpxml_file
    args['heating_system_type'] = HPXML::HVACTypeBoiler
  elsif ['base-hvac-boiler-gas-only.xml'].include? hpxml_file
    args['heating_system_type'] = HPXML::HVACTypeBoiler
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-boiler-oil-only.xml'].include? hpxml_file
    args['heating_system_type'] = HPXML::HVACTypeBoiler
    args['heating_system_fuel'] = HPXML::FuelTypeOil
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-boiler-propane-only.xml'].include? hpxml_file
    args['heating_system_type'] = HPXML::HVACTypeBoiler
    args['heating_system_fuel'] = HPXML::FuelTypePropane
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-boiler-wood-only.xml'].include? hpxml_file
    args['heating_system_type'] = HPXML::HVACTypeBoiler
    args['heating_system_fuel'] = HPXML::FuelTypeWoodCord
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-central-ac-only-1-speed.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
  elsif ['base-hvac-central-ac-only-2-speed.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
    args['cooling_system_cooling_efficiency'] = 18.0
    args['cooling_system_cooling_compressor_type'] = HPXML::HVACCompressorTypeTwoStage
  elsif ['base-hvac-central-ac-only-var-speed.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
    args['cooling_system_cooling_efficiency'] = 24.0
    args['cooling_system_cooling_compressor_type'] = HPXML::HVACCompressorTypeVariableSpeed
    args['cooling_system_cooling_sensible_heat_fraction'] = 0.78
  elsif ['base-hvac-central-ac-plus-air-to-air-heat-pump-heating.xml'].include? hpxml_file
    args['heat_pump_type'] = HPXML::HVACTypeHeatPumpAirToAir
    args['heat_pump_heating_efficiency'] = 7.7
    args['heat_pump_heating_capacity_17_f'] = '22680.0'
    args['heat_pump_fraction_cool_load_served'] = 0
    args['heat_pump_backup_fuel'] = HPXML::FuelTypeElectricity
  elsif ['base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml'].include? hpxml_file
    args['cooling_system_type'] = 'none'
    args['heat_pump_heating_efficiency'] = 7.7
    args['heat_pump_heating_capacity_17_f'] = '22680.0'
    args['heat_pump_backup_fuel'] = HPXML::FuelTypeNaturalGas
    args['heat_pump_backup_heating_efficiency'] = 0.95
    args['heat_pump_backup_heating_switchover_temp'] = 25
  elsif ['base-hvac-dual-fuel-air-to-air-heat-pump-1-speed-electric.xml'].include? hpxml_file
    args['heat_pump_backup_fuel'] = HPXML::FuelTypeElectricity
    args['heat_pump_backup_heating_efficiency'] = 1.0
  elsif ['base-hvac-dual-fuel-air-to-air-heat-pump-2-speed.xml'].include? hpxml_file
    args['heat_pump_backup_fuel'] = HPXML::FuelTypeNaturalGas
    args['heat_pump_backup_heating_efficiency'] = 0.95
    args['heat_pump_backup_heating_switchover_temp'] = 25
  elsif ['base-hvac-dual-fuel-air-to-air-heat-pump-var-speed.xml'].include? hpxml_file
    args['heat_pump_backup_fuel'] = HPXML::FuelTypeNaturalGas
    args['heat_pump_backup_heating_efficiency'] = 0.95
    args['heat_pump_backup_heating_switchover_temp'] = 25
  elsif ['base-hvac-dual-fuel-mini-split-heat-pump-ducted.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = '36000.0'
    args['heat_pump_heating_capacity_17_f'] = '20423.0'
    args['heat_pump_backup_fuel'] = HPXML::FuelTypeNaturalGas
    args['heat_pump_backup_heating_efficiency'] = 0.95
    args['heat_pump_backup_heating_switchover_temp'] = 25
  elsif ['base-hvac-ducts-leakage-percent.xml'].include? hpxml_file
    args['ducts_leakage_units'] = HPXML::UnitsPercent
    args['ducts_supply_leakage_to_outside_value'] = 0.1
    args['ducts_return_leakage_to_outside_value'] = 0.05
  elsif ['base-hvac-elec-resistance-only.xml'].include? hpxml_file
    args['heating_system_type'] = HPXML::HVACTypeElectricResistance
    args['heating_system_fuel'] = HPXML::FuelTypeElectricity
    args['heating_system_heating_efficiency'] = 1.0
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-evap-cooler-furnace-gas.xml'].include? hpxml_file
    args['cooling_system_type'] = HPXML::HVACTypeEvaporativeCooler
    args.delete('cooling_system_cooling_compressor_type')
    args.delete('cooling_system_cooling_sensible_heat_fraction')
  elsif ['base-hvac-evap-cooler-only.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
    args['cooling_system_type'] = HPXML::HVACTypeEvaporativeCooler
    args.delete('cooling_system_cooling_compressor_type')
    args.delete('cooling_system_cooling_sensible_heat_fraction')
  elsif ['base-hvac-evap-cooler-only-ducted.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
    args['cooling_system_type'] = HPXML::HVACTypeEvaporativeCooler
    args.delete('cooling_system_cooling_compressor_type')
    args.delete('cooling_system_cooling_sensible_heat_fraction')
    args['cooling_system_is_ducted'] = true
    args['ducts_return_leakage_to_outside_value'] = 0.0
  elsif ['base-hvac-fireplace-wood-only.xml'].include? hpxml_file
    args['heating_system_type'] = HPXML::HVACTypeFireplace
    args['heating_system_fuel'] = HPXML::FuelTypeWoodCord
    args['heating_system_heating_efficiency'] = 0.8
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-fixed-heater-gas-only.xml'].include? hpxml_file
    args['heating_system_type'] = HPXML::HVACTypeFixedHeater
    args['heating_system_heating_efficiency'] = 1.0
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-floor-furnace-propane-only.xml'].include? hpxml_file
    args['heating_system_type'] = HPXML::HVACTypeFloorFurnace
    args['heating_system_fuel'] = HPXML::FuelTypePropane
    args['heating_system_heating_efficiency'] = 0.8
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-furnace-coal-only.xml'].include? hpxml_file
    args['heating_system_fuel'] = HPXML::FuelTypeCoal
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-furnace-elec-central-ac-1-speed.xml'].include? hpxml_file
    args['heating_system_fuel'] = HPXML::FuelTypeElectricity
    args['heating_system_heating_efficiency'] = 1.0
  elsif ['base-hvac-furnace-elec-only.xml'].include? hpxml_file
    args['heating_system_fuel'] = HPXML::FuelTypeElectricity
    args['heating_system_heating_efficiency'] = 0.98
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-furnace-gas-central-ac-2-speed.xml'].include? hpxml_file
    args['cooling_system_cooling_efficiency'] = 18.0
    args['cooling_system_cooling_compressor_type'] = HPXML::HVACCompressorTypeTwoStage
  elsif ['base-hvac-furnace-gas-central-ac-var-speed.xml'].include? hpxml_file
    args['cooling_system_cooling_efficiency'] = 24.0
    args['cooling_system_cooling_compressor_type'] = HPXML::HVACCompressorTypeVariableSpeed
    args['cooling_system_cooling_sensible_heat_fraction'] = 0.78
  elsif ['base-hvac-furnace-gas-only.xml'].include? hpxml_file
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-furnace-gas-room-ac.xml'].include? hpxml_file
    args['cooling_system_type'] = HPXML::HVACTypeRoomAirConditioner
    args['cooling_system_cooling_efficiency_type'] = HPXML::UnitsEER
    args['cooling_system_cooling_efficiency'] = 8.5
    args.delete('cooling_system_cooling_compressor_type')
    args['cooling_system_cooling_sensible_heat_fraction'] = 0.65
  elsif ['base-hvac-furnace-oil-only.xml'].include? hpxml_file
    args['heating_system_fuel'] = HPXML::FuelTypeOil
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-furnace-propane-only.xml'].include? hpxml_file
    args['heating_system_fuel'] = HPXML::FuelTypePropane
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-furnace-wood-only.xml'].include? hpxml_file
    args['heating_system_fuel'] = HPXML::FuelTypeWoodCord
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-mini-split-air-conditioner-only-ducted.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
    args['cooling_system_type'] = HPXML::HVACTypeMiniSplitAirConditioner
    args['cooling_system_cooling_efficiency'] = 19.0
    args.delete('cooling_system_cooling_compressor_type')
    args['cooling_system_is_ducted'] = true
    args['ducts_supply_leakage_to_outside_value'] = 15.0
    args['ducts_return_leakage_to_outside_value'] = 5.0
    args['ducts_supply_insulation_r'] = 0.0
    args['ducts_supply_surface_area'] = '30.0'
    args['ducts_return_surface_area'] = '10.0'
  elsif ['base-hvac-mini-split-air-conditioner-only-ductless.xml'].include? hpxml_file
    args['cooling_system_is_ducted'] = false
  elsif ['base-hvac-ground-to-air-heat-pump.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
    args['cooling_system_type'] = 'none'
    args['heat_pump_type'] = HPXML::HVACTypeHeatPumpGroundToAir
    args['heat_pump_heating_efficiency_type'] = HPXML::UnitsCOP
    args['heat_pump_heating_efficiency'] = 3.6
    args['heat_pump_cooling_efficiency_type'] = HPXML::UnitsEER
    args['heat_pump_cooling_efficiency'] = 16.6
    args.delete('heat_pump_cooling_compressor_type')
    args['heat_pump_backup_fuel'] = HPXML::FuelTypeElectricity
  elsif ['base-hvac-ground-to-air-heat-pump-cooling-only.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = '0.0'
    args['heat_pump_fraction_heat_load_served'] = 0
    args['heat_pump_backup_fuel'] = 'none'
  elsif ['base-hvac-ground-to-air-heat-pump-heating-only.xml'].include? hpxml_file
    args['heat_pump_cooling_capacity'] = '0.0'
    args['heat_pump_fraction_cool_load_served'] = 0
  elsif ['base-hvac-seasons.xml'].include? hpxml_file
    args['hvac_control_heating_season_period'] = 'Nov 1 - Jun 30'
    args['hvac_control_cooling_season_period'] = 'Jun 1 - Oct 31'
  elsif ['base-hvac-install-quality-air-to-air-heat-pump-1-speed.xml'].include? hpxml_file
    args['heat_pump_airflow_defect_ratio'] = -0.25
    args['heat_pump_charge_defect_ratio'] = -0.25
  elsif ['base-hvac-install-quality-air-to-air-heat-pump-2-speed.xml'].include? hpxml_file
    args['heat_pump_airflow_defect_ratio'] = -0.25
    args['heat_pump_charge_defect_ratio'] = -0.25
  elsif ['base-hvac-install-quality-air-to-air-heat-pump-var-speed.xml'].include? hpxml_file
    args['heat_pump_airflow_defect_ratio'] = -0.25
    args['heat_pump_charge_defect_ratio'] = -0.25
  elsif ['base-hvac-install-quality-furnace-gas-central-ac-1-speed.xml'].include? hpxml_file
    args['heating_system_airflow_defect_ratio'] = -0.25
    args['cooling_system_airflow_defect_ratio'] = -0.25
    args['cooling_system_charge_defect_ratio'] = -0.25
  elsif ['base-hvac-install-quality-furnace-gas-central-ac-2-speed.xml'].include? hpxml_file
    args['heating_system_airflow_defect_ratio'] = -0.25
    args['cooling_system_airflow_defect_ratio'] = -0.25
    args['cooling_system_charge_defect_ratio'] = -0.25
  elsif ['base-hvac-install-quality-furnace-gas-central-ac-var-speed.xml'].include? hpxml_file
    args['heating_system_airflow_defect_ratio'] = -0.25
    args['cooling_system_airflow_defect_ratio'] = -0.25
    args['cooling_system_charge_defect_ratio'] = -0.25
  elsif ['base-hvac-install-quality-furnace-gas-only.xml'].include? hpxml_file
    args['heating_system_airflow_defect_ratio'] = -0.25
  elsif ['base-hvac-install-quality-ground-to-air-heat-pump.xml'].include? hpxml_file
    args['heat_pump_airflow_defect_ratio'] = -0.25
    args['heat_pump_charge_defect_ratio'] = -0.25
  elsif ['base-hvac-install-quality-mini-split-heat-pump-ducted.xml'].include? hpxml_file
    args['heat_pump_airflow_defect_ratio'] = -0.25
    args['heat_pump_charge_defect_ratio'] = -0.25
  elsif ['base-hvac-install-quality-mini-split-air-conditioner-only-ducted.xml'].include? hpxml_file
    args['cooling_system_airflow_defect_ratio'] = -0.25
    args['cooling_system_charge_defect_ratio'] = -0.25
  elsif ['base-hvac-mini-split-heat-pump-ducted.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
    args['cooling_system_type'] = 'none'
    args['heat_pump_type'] = HPXML::HVACTypeHeatPumpMiniSplit
    args['heat_pump_heating_capacity_17_f'] = '20423.0'
    args['heat_pump_heating_efficiency'] = 10.0
    args['heat_pump_cooling_efficiency'] = 19.0
    args.delete('heat_pump_cooling_compressor_type')
    args['heat_pump_backup_fuel'] = HPXML::FuelTypeElectricity
    args['heat_pump_is_ducted'] = true
    args['ducts_supply_leakage_to_outside_value'] = 15.0
    args['ducts_return_leakage_to_outside_value'] = 5.0
    args['ducts_supply_insulation_r'] = 0.0
    args['ducts_supply_surface_area'] = '30.0'
    args['ducts_return_surface_area'] = '10.0'
  elsif ['base-hvac-mini-split-heat-pump-ducted-cooling-only.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = '0'
    args['heat_pump_heating_capacity_17_f'] = '0'
    args['heat_pump_fraction_heat_load_served'] = 0
    args['heat_pump_backup_fuel'] = 'none'
  elsif ['base-hvac-mini-split-heat-pump-ducted-heating-only.xml'].include? hpxml_file
    args['heat_pump_cooling_capacity'] = '0'
    args['heat_pump_fraction_cool_load_served'] = 0
    args['heat_pump_backup_fuel'] = HPXML::FuelTypeElectricity
  elsif ['base-hvac-mini-split-heat-pump-ductless.xml'].include? hpxml_file
    args['heat_pump_backup_fuel'] = 'none'
    args['heat_pump_is_ducted'] = false
  elsif ['base-hvac-none.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-portable-heater-gas-only.xml'].include? hpxml_file
    args['heating_system_type'] = HPXML::HVACTypePortableHeater
    args['heating_system_heating_efficiency'] = 1.0
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-programmable-thermostat-detailed.xml'].include? hpxml_file
    args['hvac_control_heating_weekday_setpoint'] = '64, 64, 64, 64, 64, 64, 64, 70, 70, 66, 66, 66, 66, 66, 66, 66, 66, 68, 68, 68, 68, 68, 64, 64'
    args['hvac_control_heating_weekend_setpoint'] = '68, 68, 68, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70, 70'
    args['hvac_control_cooling_weekday_setpoint'] = '80, 80, 80, 80, 80, 80, 80, 75, 75, 80, 80, 80, 80, 80, 80, 80, 80, 78, 78, 78, 78, 78, 80, 80'
    args['hvac_control_cooling_weekend_setpoint'] = '78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78, 78'
  elsif ['base-hvac-room-ac-only.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
    args['cooling_system_type'] = HPXML::HVACTypeRoomAirConditioner
    args['cooling_system_cooling_efficiency_type'] = HPXML::UnitsEER
    args['cooling_system_cooling_efficiency'] = 8.5
    args.delete('cooling_system_cooling_compressor_type')
    args['cooling_system_cooling_sensible_heat_fraction'] = 0.65
  elsif ['base-hvac-room-ac-only-ceer.xml'].include? hpxml_file
    args['cooling_system_cooling_efficiency_type'] = HPXML::UnitsCEER
    args['cooling_system_cooling_efficiency'] = 8.4
  elsif ['base-hvac-room-ac-only-33percent.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
    args['cooling_system_type'] = HPXML::HVACTypeRoomAirConditioner
    args['cooling_system_cooling_efficiency_type'] = HPXML::UnitsEER
    args['cooling_system_cooling_efficiency'] = 8.5
    args.delete('cooling_system_cooling_compressor_type')
    args['cooling_system_cooling_sensible_heat_fraction'] = 0.65
    args['cooling_system_fraction_cool_load_served'] = 0.33
    args['cooling_system_cooling_capacity'] = '8000.0'
  elsif ['base-hvac-setpoints.xml'].include? hpxml_file
    args['hvac_control_heating_weekday_setpoint'] = '60'
    args['hvac_control_heating_weekend_setpoint'] = '60'
    args['hvac_control_cooling_weekday_setpoint'] = '80'
    args['hvac_control_cooling_weekend_setpoint'] = '80'
  elsif ['base-hvac-stove-oil-only.xml'].include? hpxml_file
    args['heating_system_type'] = HPXML::HVACTypeStove
    args['heating_system_fuel'] = HPXML::FuelTypeOil
    args['heating_system_heating_efficiency'] = 0.8
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-stove-wood-pellets-only.xml'].include? hpxml_file
    args['heating_system_type'] = HPXML::HVACTypeStove
    args['heating_system_fuel'] = HPXML::FuelTypeWoodPellets
    args['heating_system_heating_efficiency'] = 0.8
    args['cooling_system_type'] = 'none'
  elsif ['base-hvac-undersized.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = '3600.0'
    args['cooling_system_cooling_capacity'] = '2400.0'
    args['ducts_supply_leakage_to_outside_value'] = 7.5
    args['ducts_return_leakage_to_outside_value'] = 2.5
  elsif ['base-hvac-wall-furnace-elec-only.xml'].include? hpxml_file
    args['heating_system_type'] = HPXML::HVACTypeWallFurnace
    args['heating_system_fuel'] = HPXML::FuelTypeElectricity
    args['heating_system_heating_efficiency'] = 0.98
    args['cooling_system_type'] = 'none'
  end

  # Lighting
  if ['base-lighting-ceiling-fans.xml'].include? hpxml_file
    args['ceiling_fan_present'] = true
    args['ceiling_fan_efficiency'] = '100.0'
    args['ceiling_fan_quantity'] = '4'
    args['ceiling_fan_cooling_setpoint_temp_offset'] = 0.5
  elsif ['base-lighting-holiday.xml'].include? hpxml_file
    args['holiday_lighting_present'] = true
    args['holiday_lighting_daily_kwh'] = '1.1'
    args['holiday_lighting_period'] = 'Nov 24 - Jan 6'
  end

  # Location
  if ['base-location-AMY-2012.xml'].include? hpxml_file
    args['weather_station_epw_filepath'] = 'US_CO_Boulder_AMY_2012.epw'
  elsif ['base-location-baltimore-md.xml'].include? hpxml_file
    args['weather_station_epw_filepath'] = 'USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw'
    args['heating_system_heating_capacity'] = '24000.0'
  elsif ['base-location-dallas-tx.xml'].include? hpxml_file
    args['weather_station_epw_filepath'] = 'USA_TX_Dallas-Fort.Worth.Intl.AP.722590_TMY3.epw'
    args['heating_system_heating_capacity'] = '24000.0'
  elsif ['base-location-duluth-mn.xml'].include? hpxml_file
    args['weather_station_epw_filepath'] = 'USA_MN_Duluth.Intl.AP.727450_TMY3.epw'
  elsif ['base-location-helena-mt.xml'].include? hpxml_file
    args['weather_station_epw_filepath'] = 'USA_MT_Helena.Rgnl.AP.727720_TMY3.epw'
    args['heating_system_heating_capacity'] = '48000.0'
  elsif ['base-location-honolulu-hi.xml'].include? hpxml_file
    args['weather_station_epw_filepath'] = 'USA_HI_Honolulu.Intl.AP.911820_TMY3.epw'
    args['heating_system_heating_capacity'] = '12000.0'
  elsif ['base-location-miami-fl.xml'].include? hpxml_file
    args['weather_station_epw_filepath'] = 'USA_FL_Miami.Intl.AP.722020_TMY3.epw'
    args['heating_system_heating_capacity'] = '12000.0'
  elsif ['base-location-phoenix-az.xml'].include? hpxml_file
    args['weather_station_epw_filepath'] = 'USA_AZ_Phoenix-Sky.Harbor.Intl.AP.722780_TMY3.epw'
    args['heating_system_heating_capacity'] = '24000.0'
  elsif ['base-location-portland-or.xml'].include? hpxml_file
    args['weather_station_epw_filepath'] = 'USA_OR_Portland.Intl.AP.726980_TMY3.epw'
    args['heating_system_heating_capacity'] = '24000.0'
  end

  # Mechanical Ventilation
  if ['base-mechvent-balanced.xml'].include? hpxml_file
    args['mech_vent_fan_type'] = HPXML::MechVentTypeBalanced
    args['mech_vent_fan_power'] = '60'
  elsif ['base-mechvent-bath-kitchen-fans.xml'].include? hpxml_file
    args['kitchen_fans_quantity'] = '1'
    args['kitchen_fans_flow_rate'] = '100.0'
    args['kitchen_fans_hours_in_operation'] = '1.5'
    args['kitchen_fans_power'] = '30.0'
    args['kitchen_fans_start_hour'] = '18'
    args['bathroom_fans_quantity'] = '2'
    args['bathroom_fans_flow_rate'] = '50.0'
    args['bathroom_fans_hours_in_operation'] = '1.5'
    args['bathroom_fans_power'] = '15.0'
    args['bathroom_fans_start_hour'] = '7'
  elsif ['base-mechvent-cfis.xml'].include? hpxml_file
    args['mech_vent_fan_type'] = HPXML::MechVentTypeCFIS
    args['mech_vent_flow_rate'] = '330'
    args['mech_vent_hours_in_operation'] = '8'
    args['mech_vent_fan_power'] = '300'
  elsif ['base-mechvent-cfis-evap-cooler-only-ducted.xml'].include? hpxml_file
    args['mech_vent_fan_type'] = HPXML::MechVentTypeCFIS
    args['mech_vent_flow_rate'] = '330'
    args['mech_vent_hours_in_operation'] = '8'
    args['mech_vent_fan_power'] = '300'
  elsif ['base-mechvent-erv.xml'].include? hpxml_file
    args['mech_vent_fan_type'] = HPXML::MechVentTypeERV
    args['mech_vent_fan_power'] = '60'
  elsif ['base-mechvent-erv-atre-asre.xml'].include? hpxml_file
    args['mech_vent_fan_type'] = HPXML::MechVentTypeERV
    args['mech_vent_recovery_efficiency_type'] = 'Adjusted'
    args['mech_vent_total_recovery_efficiency'] = 0.526
    args['mech_vent_sensible_recovery_efficiency'] = 0.79
    args['mech_vent_fan_power'] = '60'
  elsif ['base-mechvent-exhaust.xml'].include? hpxml_file
    args['mech_vent_fan_type'] = HPXML::MechVentTypeExhaust
  elsif ['base-mechvent-exhaust-rated-flow-rate.xml'].include? hpxml_file
    args['mech_vent_fan_type'] = HPXML::MechVentTypeExhaust
  elsif ['base-mechvent-hrv.xml'].include? hpxml_file
    args['mech_vent_fan_type'] = HPXML::MechVentTypeHRV
    args['mech_vent_fan_power'] = '60'
  elsif ['base-mechvent-hrv-asre.xml'].include? hpxml_file
    args['mech_vent_fan_type'] = HPXML::MechVentTypeHRV
    args['mech_vent_recovery_efficiency_type'] = 'Adjusted'
    args['mech_vent_sensible_recovery_efficiency'] = 0.79
    args['mech_vent_fan_power'] = '60'
  elsif ['base-mechvent-supply.xml'].include? hpxml_file
    args['mech_vent_fan_type'] = HPXML::MechVentTypeSupply
  elsif ['base-mechvent-whole-house-fan.xml'].include? hpxml_file
    args['whole_house_fan_present'] = true
  end

  # Misc
  if ['base-misc-defaults.xml'].include? hpxml_file
    args.delete('simulation_control_timestep')
    args.delete('site_type')
    args['geometry_unit_num_bathrooms'] = Constants.Auto
    args['geometry_unit_num_occupants'] = Constants.Auto
    args['foundation_wall_insulation_distance_to_top'] = Constants.Auto
    args['foundation_wall_insulation_distance_to_bottom'] = Constants.Auto
    args['foundation_wall_thickness'] = Constants.Auto
    args['slab_thickness'] = Constants.Auto
    args['slab_carpet_fraction'] = Constants.Auto
    args.delete('roof_material_type')
    args['roof_color'] = HPXML::ColorLight
    args.delete('roof_material_type')
    args['roof_radiant_barrier'] = false
    args.delete('wall_siding_type')
    args['wall_color'] = HPXML::ColorMedium
    args.delete('window_fraction_operable')
    args.delete('window_interior_shading_winter')
    args.delete('window_interior_shading_summer')
    args.delete('cooling_system_cooling_compressor_type')
    args.delete('cooling_system_cooling_sensible_heat_fraction')
    args['mech_vent_fan_type'] = HPXML::MechVentTypeExhaust
    args['mech_vent_hours_in_operation'] = Constants.Auto
    args['mech_vent_fan_power'] = Constants.Auto
    args['ducts_supply_location'] = Constants.Auto
    args['ducts_return_location'] = Constants.Auto
    args['ducts_supply_surface_area'] = Constants.Auto
    args['ducts_return_surface_area'] = Constants.Auto
    args['kitchen_fans_quantity'] = Constants.Auto
    args['bathroom_fans_quantity'] = Constants.Auto
    args['water_heater_location'] = Constants.Auto
    args['water_heater_tank_volume'] = Constants.Auto
    args['water_heater_setpoint_temperature'] = Constants.Auto
    args['hot_water_distribution_standard_piping_length'] = Constants.Auto
    args['hot_water_distribution_pipe_r'] = Constants.Auto
    args['solar_thermal_system_type'] = 'hot water'
    args['solar_thermal_collector_type'] = HPXML::SolarThermalTypeSingleGlazing
    args['solar_thermal_collector_rated_optical_efficiency'] = 0.77
    args['solar_thermal_collector_rated_thermal_losses'] = 0.793
    args['pv_system_module_type'] = Constants.Auto
    args.delete('pv_system_inverter_efficiency')
    args.delete('pv_system_system_losses_fraction')
    args['clothes_washer_location'] = Constants.Auto
    args['clothes_washer_efficiency'] = Constants.Auto
    args['clothes_washer_rated_annual_kwh'] = Constants.Auto
    args['clothes_washer_label_electric_rate'] = Constants.Auto
    args['clothes_washer_label_gas_rate'] = Constants.Auto
    args['clothes_washer_label_annual_gas_cost'] = Constants.Auto
    args['clothes_washer_label_usage'] = Constants.Auto
    args['clothes_washer_capacity'] = Constants.Auto
    args['clothes_dryer_location'] = Constants.Auto
    args['clothes_dryer_efficiency'] = Constants.Auto
    args['clothes_dryer_vented_flow_rate'] = Constants.Auto
    args['dishwasher_location'] = Constants.Auto
    args['dishwasher_efficiency'] = Constants.Auto
    args['dishwasher_label_electric_rate'] = Constants.Auto
    args['dishwasher_label_gas_rate'] = Constants.Auto
    args['dishwasher_label_annual_gas_cost'] = Constants.Auto
    args['dishwasher_label_usage'] = Constants.Auto
    args['dishwasher_place_setting_capacity'] = Constants.Auto
    args['refrigerator_location'] = Constants.Auto
    args['refrigerator_rated_annual_kwh'] = Constants.Auto
    args['cooking_range_oven_location'] = Constants.Auto
    args.delete('cooking_range_oven_is_induction')
    args.delete('cooking_range_oven_is_convection')
    args['ceiling_fan_present'] = true
    args['misc_plug_loads_television_annual_kwh'] = Constants.Auto
    args['misc_plug_loads_other_annual_kwh'] = Constants.Auto
    args['misc_plug_loads_other_frac_sensible'] = Constants.Auto
    args['misc_plug_loads_other_frac_latent'] = Constants.Auto
    args['mech_vent_flow_rate'] = Constants.Auto
    args['kitchen_fans_flow_rate'] = Constants.Auto
    args['bathroom_fans_flow_rate'] = Constants.Auto
    args['whole_house_fan_present'] = true
    args['whole_house_fan_flow_rate'] = Constants.Auto
    args['whole_house_fan_power'] = Constants.Auto
  elsif ['base-misc-loads-large-uncommon.xml'].include? hpxml_file
    args['extra_refrigerator_location'] = Constants.Auto
    args['extra_refrigerator_rated_annual_kwh'] = '700.0'
    args['freezer_location'] = HPXML::LocationLivingSpace
    args['freezer_rated_annual_kwh'] = '300.0'
    args['misc_plug_loads_well_pump_present'] = true
    args['misc_plug_loads_well_pump_annual_kwh'] = '475.0'
    args['misc_plug_loads_well_pump_usage_multiplier'] = 1.0
    args['misc_plug_loads_vehicle_present'] = true
    args['misc_plug_loads_vehicle_annual_kwh'] = '1500.0'
    args['misc_plug_loads_vehicle_usage_multiplier'] = 1.0
    args['misc_fuel_loads_grill_present'] = true
    args['misc_fuel_loads_grill_fuel_type'] = HPXML::FuelTypePropane
    args['misc_fuel_loads_grill_annual_therm'] = '25.0'
    args['misc_fuel_loads_grill_usage_multiplier'] = 1.0
    args['misc_fuel_loads_lighting_present'] = true
    args['misc_fuel_loads_lighting_annual_therm'] = '28.0'
    args['misc_fuel_loads_lighting_usage_multiplier'] = 1.0
    args['misc_fuel_loads_fireplace_present'] = true
    args['misc_fuel_loads_fireplace_fuel_type'] = HPXML::FuelTypeWoodCord
    args['misc_fuel_loads_fireplace_annual_therm'] = '55.0'
    args['misc_fuel_loads_fireplace_frac_sensible'] = '0.5'
    args['misc_fuel_loads_fireplace_frac_latent'] = '0.1'
    args['misc_fuel_loads_fireplace_usage_multiplier'] = 1.0
    args['pool_present'] = true
    args['pool_heater_type'] = HPXML::HeaterTypeGas
    args['pool_pump_annual_kwh'] = '2700.0'
    args['pool_heater_annual_therm'] = '500.0'
    args['hot_tub_present'] = true
    args['hot_tub_pump_annual_kwh'] = '1000.0'
    args['hot_tub_heater_annual_kwh'] = '1300.0'
  elsif ['base-misc-loads-large-uncommon2.xml'].include? hpxml_file
    args['pool_heater_type'] = HPXML::TypeNone
    args['hot_tub_heater_type'] = HPXML::HeaterTypeHeatPump
    args['hot_tub_heater_annual_kwh'] = '260.0'
    args['misc_fuel_loads_grill_fuel_type'] = HPXML::FuelTypeOil
    args['misc_fuel_loads_fireplace_fuel_type'] = HPXML::FuelTypeWoodPellets
  elsif ['base-misc-neighbor-shading.xml'].include? hpxml_file
    args['neighbor_back_distance'] = 10
    args['neighbor_front_distance'] = 15
    args['neighbor_front_height'] = '12'
  elsif ['base-misc-shielding-of-home.xml'].include? hpxml_file
    args['site_shielding_of_home'] = HPXML::ShieldingWellShielded
  elsif ['base-misc-usage-multiplier.xml'].include? hpxml_file
    args['water_fixtures_usage_multiplier'] = 0.9
    args['lighting_interior_usage_multiplier'] = 0.9
    args['lighting_exterior_usage_multiplier'] = 0.9
    args['lighting_garage_usage_multiplier'] = 0.9
    args['clothes_washer_usage_multiplier'] = 0.9
    args['clothes_dryer_usage_multiplier'] = 0.9
    args['dishwasher_usage_multiplier'] = 0.9
    args['refrigerator_usage_multiplier'] = 0.9
    args['freezer_location'] = HPXML::LocationLivingSpace
    args['freezer_rated_annual_kwh'] = '300.0'
    args['freezer_usage_multiplier'] = 0.9
    args['cooking_range_oven_usage_multiplier'] = 0.9
    args['misc_plug_loads_television_usage_multiplier'] = 0.9
    args['misc_plug_loads_other_usage_multiplier'] = 0.9
    args['pool_present'] = true
    args['pool_pump_annual_kwh'] = '2700.0'
    args['pool_pump_usage_multiplier'] = 0.9
    args['pool_heater_type'] = HPXML::HeaterTypeGas
    args['pool_heater_annual_therm'] = '500.0'
    args['pool_heater_usage_multiplier'] = 0.9
    args['hot_tub_present'] = true
    args['hot_tub_pump_annual_kwh'] = '1000.0'
    args['hot_tub_pump_usage_multiplier'] = 0.9
    args['hot_tub_heater_type'] = HPXML::HeaterTypeElectricResistance
    args['hot_tub_heater_annual_kwh'] = '1300.0'
    args['hot_tub_heater_usage_multiplier'] = 0.9
    args['misc_fuel_loads_grill_present'] = true
    args['misc_fuel_loads_grill_fuel_type'] = HPXML::FuelTypePropane
    args['misc_fuel_loads_grill_annual_therm'] = '25.0'
    args['misc_fuel_loads_grill_usage_multiplier'] = 0.9
    args['misc_fuel_loads_lighting_present'] = true
    args['misc_fuel_loads_lighting_annual_therm'] = '28.0'
    args['misc_fuel_loads_lighting_usage_multiplier'] = 0.9
    args['misc_fuel_loads_fireplace_present'] = true
    args['misc_fuel_loads_fireplace_fuel_type'] = HPXML::FuelTypeWoodCord
    args['misc_fuel_loads_fireplace_annual_therm'] = '55.0'
    args['misc_fuel_loads_fireplace_frac_sensible'] = '0.5'
    args['misc_fuel_loads_fireplace_frac_latent'] = '0.1'
    args['misc_fuel_loads_fireplace_usage_multiplier'] = 0.9
  end

  # PV
  if ['base-pv.xml'].include? hpxml_file
    args['pv_system_module_type'] = HPXML::PVModuleTypeStandard
    args['pv_system_location'] = HPXML::LocationRoof
    args['pv_system_tracking'] = HPXML::PVTrackingTypeFixed
    args['pv_system_2_module_type'] = HPXML::PVModuleTypePremium
    args['pv_system_2_location'] = HPXML::LocationRoof
    args['pv_system_2_tracking'] = HPXML::PVTrackingTypeFixed
    args['pv_system_2_array_azimuth'] = 90
    args['pv_system_2_max_power_output'] = 1500
  end

  # Simulation Control
  if ['base-simcontrol-calendar-year-custom.xml'].include? hpxml_file
    args['simulation_control_run_period_calendar_year'] = 2008
  elsif ['base-simcontrol-daylight-saving-custom.xml'].include? hpxml_file
    args['simulation_control_daylight_saving_enabled'] = true
    args['simulation_control_daylight_saving_period'] = 'Mar 10 - Nov 6'
  elsif ['base-simcontrol-daylight-saving-disabled.xml'].include? hpxml_file
    args['simulation_control_daylight_saving_enabled'] = false
  elsif ['base-simcontrol-runperiod-1-month.xml'].include? hpxml_file
    args['simulation_control_run_period'] = 'Jan 1 - Jan 31'
  elsif ['base-simcontrol-timestep-10-mins.xml'].include? hpxml_file
    args['simulation_control_timestep'] = '10'
  end

  # Extras
  if ['extra-auto.xml'].include? hpxml_file
    args['geometry_unit_num_occupants'] = Constants.Auto
    args['ducts_supply_location'] = Constants.Auto
    args['ducts_return_location'] = Constants.Auto
    args['ducts_supply_surface_area'] = Constants.Auto
    args['ducts_return_surface_area'] = Constants.Auto
    args['water_heater_location'] = Constants.Auto
    args['water_heater_tank_volume'] = Constants.Auto
    args['hot_water_distribution_standard_piping_length'] = Constants.Auto
    args['clothes_washer_location'] = Constants.Auto
    args['clothes_dryer_location'] = Constants.Auto
    args['refrigerator_location'] = Constants.Auto
  elsif ['extra-pv-roofpitch.xml'].include? hpxml_file
    args['pv_system_module_type'] = HPXML::PVModuleTypeStandard
    args['pv_system_2_module_type'] = HPXML::PVModuleTypeStandard
    args['pv_system_array_tilt'] = 'roofpitch'
    args['pv_system_2_array_tilt'] = 'roofpitch+15'
  elsif ['extra-dhw-solar-latitude.xml'].include? hpxml_file
    args['solar_thermal_system_type'] = 'hot water'
    args['solar_thermal_collector_tilt'] = 'latitude-15'
  elsif ['extra-second-refrigerator.xml'].include? hpxml_file
    args['extra_refrigerator_location'] = HPXML::LocationLivingSpace
  elsif ['extra-second-heating-system-portable-heater-to-heating-system.xml'].include? hpxml_file
    args['heating_system_fuel'] = HPXML::FuelTypeElectricity
    args['heating_system_heating_capacity'] = '48000.0'
    args['heating_system_fraction_heat_load_served'] = 0.75
    args['ducts_supply_leakage_to_outside_value'] = 0.0
    args['ducts_return_leakage_to_outside_value'] = 0.0
    args['ducts_supply_location'] = HPXML::LocationLivingSpace
    args['ducts_return_location'] = HPXML::LocationLivingSpace
    args['heating_system_2_type'] = HPXML::HVACTypePortableHeater
    args['heating_system_2_heating_capacity'] = '16000.0'
  elsif ['extra-second-heating-system-fireplace-to-heating-system.xml'].include? hpxml_file
    args['heating_system_heating_capacity'] = '48000.0'
    args['heating_system_fraction_heat_load_served'] = 0.75
    args['heating_system_2_type'] = HPXML::HVACTypeFireplace
    args['heating_system_2_heating_capacity'] = '16000.0'
  elsif ['extra-second-heating-system-boiler-to-heating-system.xml'].include? hpxml_file
    args['heating_system_fraction_heat_load_served'] = 0.75
    args['heating_system_2_type'] = HPXML::HVACTypeBoiler
  elsif ['extra-second-heating-system-portable-heater-to-heat-pump.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = '48000.0'
    args['heat_pump_fraction_heat_load_served'] = 0.75
    args['ducts_supply_leakage_to_outside_value'] = 0.0
    args['ducts_return_leakage_to_outside_value'] = 0.0
    args['ducts_supply_location'] = HPXML::LocationLivingSpace
    args['ducts_return_location'] = HPXML::LocationLivingSpace
    args['heating_system_2_type'] = HPXML::HVACTypePortableHeater
    args['heating_system_2_heating_capacity'] = '16000.0'
  elsif ['extra-second-heating-system-fireplace-to-heat-pump.xml'].include? hpxml_file
    args['heat_pump_heating_capacity'] = '48000.0'
    args['heat_pump_fraction_heat_load_served'] = 0.75
    args['heating_system_2_type'] = HPXML::HVACTypeFireplace
    args['heating_system_2_heating_capacity'] = '16000.0'
  elsif ['extra-second-heating-system-boiler-to-heat-pump.xml'].include? hpxml_file
    args['heat_pump_fraction_heat_load_served'] = 0.75
    args['heating_system_2_type'] = HPXML::HVACTypeBoiler
  elsif ['extra-enclosure-windows-shading.xml'].include? hpxml_file
    args['window_interior_shading_winter'] = 0.99
    args['window_interior_shading_summer'] = 0.01
    args['window_exterior_shading_winter'] = 0.9
    args['window_exterior_shading_summer'] = 0.1
  elsif ['extra-enclosure-garage-partially-protruded.xml'].include? hpxml_file
    args['geometry_garage_width'] = 12
    args['geometry_garage_protrusion'] = 0.5
  elsif ['extra-enclosure-garage-atticroof-conditioned.xml'].include? hpxml_file
    args['geometry_unit_cfa'] = 4500.0
    args['geometry_num_floors_above_grade'] = 2
    args['geometry_attic_type'] = HPXML::AtticTypeConditioned
    args['floor_over_garage_assembly_r'] = 39.3
  elsif ['extra-enclosure-atticroof-conditioned-eaves-gable.xml'].include? hpxml_file
    args['geometry_unit_cfa'] = 4500.0
    args['geometry_num_floors_above_grade'] = 2
    args['geometry_attic_type'] = HPXML::AtticTypeConditioned
    args['geometry_eaves_depth'] = 2
  elsif ['extra-enclosure-atticroof-conditioned-eaves-hip.xml'].include? hpxml_file
    args['geometry_roof_type'] = 'hip'
  elsif ['extra-zero-refrigerator-kwh.xml'].include? hpxml_file
    args['refrigerator_rated_annual_kwh'] = '0'
  elsif ['extra-zero-extra-refrigerator-kwh.xml'].include? hpxml_file
    args['extra_refrigerator_rated_annual_kwh'] = '0'
  elsif ['extra-zero-freezer-kwh.xml'].include? hpxml_file
    args['freezer_rated_annual_kwh'] = '0'
  elsif ['extra-zero-clothes-washer-kwh.xml'].include? hpxml_file
    args['clothes_washer_rated_annual_kwh'] = '0'
    args['clothes_dryer_location'] = 'none'
  elsif ['extra-zero-dishwasher-kwh.xml'].include? hpxml_file
    args['dishwasher_efficiency'] = '0'
  elsif ['extra-bldgtype-single-family-attached-atticroof-flat.xml'].include? hpxml_file
    args['geometry_roof_type'] = 'flat'
    args['ducts_supply_leakage_to_outside_value'] = 0.0
    args['ducts_return_leakage_to_outside_value'] = 0.0
    args['ducts_supply_location'] = HPXML::LocationBasementConditioned
    args['ducts_return_location'] = HPXML::LocationBasementConditioned
  elsif ['extra-gas-pool-heater-with-zero-kwh.xml'].include? hpxml_file
    args['pool_present'] = true
    args['pool_heater_type'] = HPXML::HeaterTypeGas
    args['pool_heater_annual_kwh'] = 0
  elsif ['extra-gas-hot-tub-heater-with-zero-kwh.xml'].include? hpxml_file
    args['hot_tub_present'] = true
    args['hot_tub_heater_type'] = HPXML::HeaterTypeGas
    args['hot_tub_heater_annual_kwh'] = 0
  elsif ['extra-no-rim-joists.xml'].include? hpxml_file
    args.delete('geometry_rim_joist_height')
    args.delete('rim_joist_assembly_r')
  elsif ['extra-state-code-different-than-epw.xml'].include? hpxml_file
    args['site_state_code'] = 'WY'

  elsif ['extra-bldgtype-single-family-attached-atticroof-conditioned-eaves-gable.xml'].include? hpxml_file
    args['geometry_num_floors_above_grade'] = 2
    args['geometry_attic_type'] = HPXML::AtticTypeConditioned
    args['geometry_eaves_depth'] = 2
    args['ducts_supply_location'] = HPXML::LocationLivingSpace
    args['ducts_return_location'] = HPXML::LocationLivingSpace
  elsif ['extra-bldgtype-single-family-attached-atticroof-conditioned-eaves-hip.xml'].include? hpxml_file
    args['geometry_roof_type'] = 'hip'
  elsif ['extra-bldgtype-multifamily-eaves.xml'].include? hpxml_file
    args['geometry_eaves_depth'] = 2

  elsif ['extra-bldgtype-single-family-attached-slab.xml'].include? hpxml_file
    args['geometry_foundation_type'] = HPXML::FoundationTypeSlab
    args['geometry_foundation_height'] = 0.0
    args['geometry_foundation_height_above_grade'] = 0.0
    args['foundation_wall_insulation_distance_to_bottom'] = Constants.Auto
  elsif ['extra-bldgtype-single-family-attached-vented-crawlspace.xml'].include? hpxml_file
    args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceVented
    args['geometry_foundation_height'] = 4.0
    args['floor_over_foundation_assembly_r'] = 18.7
    args['foundation_wall_insulation_distance_to_bottom'] = '4.0'
  elsif ['extra-bldgtype-single-family-attached-unvented-crawlspace.xml'].include? hpxml_file
    args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceUnvented
    args['geometry_foundation_height'] = 4.0
    args['floor_over_foundation_assembly_r'] = 18.7
    args['foundation_wall_insulation_distance_to_bottom'] = '4.0'
  elsif ['extra-bldgtype-single-family-attached-unconditioned-basement.xml'].include? hpxml_file
    args['geometry_foundation_type'] = HPXML::FoundationTypeBasementUnconditioned
    args['floor_over_foundation_assembly_r'] = 18.7
    args['foundation_wall_insulation_r'] = 0
    args['foundation_wall_insulation_distance_to_bottom'] = '0.0'

  elsif ['extra-bldgtype-single-family-attached-double-loaded-interior.xml'].include? hpxml_file
    args['geometry_building_num_units'] = 4
    args['geometry_corridor_position'] = 'Double-Loaded Interior'
  elsif ['extra-bldgtype-single-family-attached-single-exterior-front.xml'].include? hpxml_file
    args['geometry_corridor_position'] = 'Single Exterior (Front)'
  elsif ['extra-bldgtype-single-family-attached-double-exterior.xml'].include? hpxml_file
    args['geometry_building_num_units'] = 4
    args['geometry_corridor_position'] = 'Double Exterior'

  elsif ['extra-bldgtype-single-family-attached-slab-middle.xml',
         'extra-bldgtype-single-family-attached-vented-crawlspace-middle.xml',
         'extra-bldgtype-single-family-attached-unvented-crawlspace-middle.xml',
         'extra-bldgtype-single-family-attached-unconditioned-basement-middle.xml'].include? hpxml_file
    args['geometry_unit_horizontal_location'] = 'Middle'
  elsif ['extra-bldgtype-single-family-attached-slab-right.xml',
         'extra-bldgtype-single-family-attached-vented-crawlspace-right.xml',
         'extra-bldgtype-single-family-attached-unvented-crawlspace-right.xml',
         'extra-bldgtype-single-family-attached-unconditioned-basement-right.xml'].include? hpxml_file
    args['geometry_unit_horizontal_location'] = 'Right'

  elsif ['extra-bldgtype-multifamily-slab.xml'].include? hpxml_file
    args['geometry_building_num_units'] = 18
    args['geometry_foundation_type'] = HPXML::FoundationTypeSlab
    args['geometry_foundation_height'] = 0.0
    args['geometry_foundation_height_above_grade'] = 0.0
    args['foundation_wall_insulation_distance_to_bottom'] = Constants.Auto
  elsif ['extra-bldgtype-multifamily-vented-crawlspace.xml'].include? hpxml_file
    args['geometry_building_num_units'] = 18
    args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceVented
    args['geometry_foundation_height'] = 4.0
    args['floor_over_foundation_assembly_r'] = 18.7
    args['foundation_wall_insulation_distance_to_bottom'] = '4.0'
  elsif ['extra-bldgtype-multifamily-unvented-crawlspace.xml'].include? hpxml_file
    args['geometry_building_num_units'] = 18
    args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceUnvented
    args['geometry_foundation_height'] = 4.0
    args['floor_over_foundation_assembly_r'] = 18.7
    args['foundation_wall_insulation_distance_to_bottom'] = '4.0'

  elsif ['extra-bldgtype-multifamily-double-loaded-interior.xml'].include? hpxml_file
    args['geometry_building_num_units'] = 18
    args['geometry_corridor_position'] = 'Double-Loaded Interior'
  elsif ['extra-bldgtype-multifamily-single-exterior-front.xml'].include? hpxml_file
    args['geometry_building_num_units'] = 18
    args['geometry_corridor_position'] = 'Single Exterior (Front)'
  elsif ['extra-bldgtype-multifamily-double-exterior.xml'].include? hpxml_file
    args['geometry_building_num_units'] = 18
    args['geometry_corridor_position'] = 'Double Exterior'

  elsif ['extra-bldgtype-multifamily-slab-left-bottom.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-left-bottom.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-left-bottom.xml'].include? hpxml_file
    args['geometry_unit_horizontal_location'] = 'Left'
    args['geometry_unit_level'] = 'Bottom'
  elsif ['extra-bldgtype-multifamily-slab-left-middle.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-left-middle.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-left-middle.xml'].include? hpxml_file
    args['geometry_unit_horizontal_location'] = 'Left'
    args['geometry_unit_level'] = 'Middle'
  elsif ['extra-bldgtype-multifamily-slab-left-top.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-left-top.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-left-top.xml'].include? hpxml_file
    args['geometry_unit_horizontal_location'] = 'Left'
    args['geometry_unit_level'] = 'Top'
  elsif ['extra-bldgtype-multifamily-slab-middle-bottom.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-middle-bottom.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-middle-bottom.xml'].include? hpxml_file
    args['geometry_unit_horizontal_location'] = 'Middle'
    args['geometry_unit_level'] = 'Bottom'
  elsif ['extra-bldgtype-multifamily-slab-middle-middle.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-middle-middle.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-middle-middle.xml'].include? hpxml_file
    args['geometry_unit_horizontal_location'] = 'Middle'
    args['geometry_unit_level'] = 'Middle'
  elsif ['extra-bldgtype-multifamily-slab-middle-top.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-middle-top.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-middle-top.xml'].include? hpxml_file
    args['geometry_unit_horizontal_location'] = 'Middle'
    args['geometry_unit_level'] = 'Top'
  elsif ['extra-bldgtype-multifamily-slab-right-bottom.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-right-bottom.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-right-bottom.xml'].include? hpxml_file
    args['geometry_unit_horizontal_location'] = 'Right'
    args['geometry_unit_level'] = 'Bottom'
  elsif ['extra-bldgtype-multifamily-slab-right-middle.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-right-middle.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-right-middle.xml'].include? hpxml_file
    args['geometry_unit_horizontal_location'] = 'Right'
    args['geometry_unit_level'] = 'Middle'
  elsif ['extra-bldgtype-multifamily-slab-right-top.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-right-top.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-right-top.xml'].include? hpxml_file
    args['geometry_unit_horizontal_location'] = 'Right'
    args['geometry_unit_level'] = 'Top'

  elsif ['extra-bldgtype-multifamily-slab-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-slab-left-bottom-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-slab-left-middle-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-slab-left-top-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-slab-middle-bottom-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-slab-middle-middle-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-slab-middle-top-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-slab-right-bottom-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-slab-right-middle-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-slab-right-top-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-left-bottom-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-left-middle-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-left-top-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-middle-bottom-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-middle-middle-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-middle-top-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-right-bottom-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-right-middle-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-vented-crawlspace-right-top-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-left-bottom-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-left-middle-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-left-top-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-middle-bottom-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-middle-middle-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-middle-top-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-right-bottom-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-right-middle-double-loaded-interior.xml',
         'extra-bldgtype-multifamily-unvented-crawlspace-right-top-double-loaded-interior.xml'].include? hpxml_file
    args['geometry_corridor_position'] = 'Double-Loaded Interior'
  end

  # Warnings/Errors
  if ['invalid_files/non-electric-heat-pump-water-heater.xml'].include? hpxml_file
    args['water_heater_type'] = HPXML::WaterHeaterTypeHeatPump
    args['water_heater_fuel_type'] = HPXML::FuelTypeNaturalGas
    args['water_heater_efficiency'] = 2.3
  elsif ['invalid_files/heating-system-and-heat-pump.xml'].include? hpxml_file
    args['cooling_system_type'] = 'none'
    args['heat_pump_type'] = HPXML::HVACTypeHeatPumpAirToAir
  elsif ['invalid_files/cooling-system-and-heat-pump.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
    args['heat_pump_type'] = HPXML::HVACTypeHeatPumpAirToAir
  elsif ['invalid_files/non-integer-geometry-num-bathrooms.xml'].include? hpxml_file
    args['geometry_unit_num_bathrooms'] = '1.5'
  elsif ['invalid_files/non-integer-ceiling-fan-quantity.xml'].include? hpxml_file
    args['ceiling_fan_quantity'] = '0.5'
  elsif ['invalid_files/single-family-detached-slab-non-zero-foundation-height.xml'].include? hpxml_file
    args['geometry_foundation_type'] = HPXML::FoundationTypeSlab
    args['geometry_foundation_height_above_grade'] = 0.0
  elsif ['invalid_files/single-family-detached-finished-basement-zero-foundation-height.xml'].include? hpxml_file
    args['geometry_foundation_height'] = 0.0
    args['foundation_wall_insulation_distance_to_bottom'] = Constants.Auto
  elsif ['invalid_files/single-family-attached-ambient.xml'].include? hpxml_file
    args['geometry_foundation_type'] = HPXML::FoundationTypeAmbient
    args.delete('geometry_rim_joist_height')
    args.delete('rim_joist_assembly_r')
  elsif ['invalid_files/multifamily-bottom-slab-non-zero-foundation-height.xml'].include? hpxml_file
    args['geometry_foundation_type'] = HPXML::FoundationTypeSlab
    args['geometry_foundation_height_above_grade'] = 0.0
    args['geometry_unit_level'] = 'Bottom'
  elsif ['invalid_files/multifamily-bottom-crawlspace-zero-foundation-height.xml'].include? hpxml_file
    args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceUnvented
    args['geometry_foundation_height'] = 0.0
    args['geometry_unit_level'] = 'Bottom'
    args['foundation_wall_insulation_distance_to_bottom'] = Constants.Auto
  elsif ['invalid_files/slab-non-zero-foundation-height-above-grade.xml'].include? hpxml_file
    args['geometry_foundation_type'] = HPXML::FoundationTypeSlab
    args['geometry_foundation_height'] = 0.0
    args['foundation_wall_insulation_distance_to_bottom'] = Constants.Auto
  elsif ['invalid_files/ducts-location-and-areas-not-same-type.xml'].include? hpxml_file
    args['ducts_supply_location'] = Constants.Auto
  elsif ['invalid_files/second-heating-system-serves-majority-heat.xml'].include? hpxml_file
    args['heating_system_fraction_heat_load_served'] = 0.4
    args['heating_system_2_type'] = HPXML::HVACTypeFireplace
    args['heating_system_2_fraction_heat_load_served'] = 0.6
  elsif ['invalid_files/second-heating-system-serves-total-heat-load.xml'].include? hpxml_file
    args['heating_system_2_type'] = HPXML::HVACTypeFireplace
    args['heating_system_2_fraction_heat_load_served'] = 1.0
  elsif ['invalid_files/second-heating-system-but-no-primary-heating.xml'].include? hpxml_file
    args['heating_system_type'] = 'none'
    args['heating_system_2_type'] = HPXML::HVACTypeFireplace
  elsif ['invalid_files/single-family-attached-no-building-orientation.xml'].include? hpxml_file
    args.delete('geometry_building_num_units')
    args.delete('geometry_unit_horizontal_location')
  elsif ['invalid_files/multifamily-no-building-orientation.xml'].include? hpxml_file
    args.delete('geometry_building_num_units')
    args.delete('geometry_unit_level')
    args.delete('geometry_unit_horizontal_location')
  elsif ['invalid_files/vented-crawlspace-with-wall-and-ceiling-insulation.xml'].include? hpxml_file
    args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceVented
    args['geometry_foundation_height'] = 3.0
    args['floor_over_foundation_assembly_r'] = 10
    args['foundation_wall_insulation_distance_to_bottom'] = '0.0'
    args['foundation_wall_assembly_r'] = 10
  elsif ['invalid_files/unvented-crawlspace-with-wall-and-ceiling-insulation.xml'].include? hpxml_file
    args['geometry_foundation_type'] = HPXML::FoundationTypeCrawlspaceUnvented
    args['geometry_foundation_height'] = 3.0
    args['floor_over_foundation_assembly_r'] = 10
    args['foundation_wall_insulation_distance_to_bottom'] = '0.0'
    args['foundation_wall_assembly_r'] = 10
  elsif ['invalid_files/unconditioned-basement-with-wall-and-ceiling-insulation.xml'].include? hpxml_file
    args['geometry_foundation_type'] = HPXML::FoundationTypeBasementUnconditioned
    args['floor_over_foundation_assembly_r'] = 10
    args['foundation_wall_assembly_r'] = 10
  elsif ['invalid_files/vented-attic-with-floor-and-roof-insulation.xml'].include? hpxml_file
    args['geometry_attic_type'] = HPXML::AtticTypeVented
    args['roof_assembly_r'] = 10
    args['ducts_supply_location'] = HPXML::LocationAtticVented
    args['ducts_return_location'] = HPXML::LocationAtticVented
  elsif ['invalid_files/unvented-attic-with-floor-and-roof-insulation.xml'].include? hpxml_file
    args['geometry_attic_type'] = HPXML::AtticTypeUnvented
    args['roof_assembly_r'] = 10
  elsif ['invalid_files/conditioned-basement-with-ceiling-insulation.xml'].include? hpxml_file
    args['geometry_foundation_type'] = HPXML::FoundationTypeBasementConditioned
    args['floor_over_foundation_assembly_r'] = 10
  elsif ['invalid_files/conditioned-attic-with-floor-insulation.xml'].include? hpxml_file
    args['geometry_num_floors_above_grade'] = 2
    args['geometry_attic_type'] = HPXML::AtticTypeConditioned
    args['ducts_supply_location'] = HPXML::LocationLivingSpace
    args['ducts_return_location'] = HPXML::LocationLivingSpace
  elsif ['invalid_files/dhw-indirect-without-boiler.xml'].include? hpxml_file
    args['water_heater_type'] = HPXML::WaterHeaterTypeCombiStorage
  elsif ['invalid_files/multipliers-without-tv-plug-loads.xml'].include? hpxml_file
    args['misc_plug_loads_television_annual_kwh'] = '0.0'
  elsif ['invalid_files/multipliers-without-other-plug-loads.xml'].include? hpxml_file
    args['misc_plug_loads_other_annual_kwh'] = '0.0'
  elsif ['invalid_files/multipliers-without-well-pump-plug-loads.xml'].include? hpxml_file
    args['misc_plug_loads_well_pump_annual_kwh'] = '0.0'
    args['misc_plug_loads_well_pump_usage_multiplier'] = 1.0
  elsif ['invalid_files/multipliers-without-vehicle-plug-loads.xml'].include? hpxml_file
    args['misc_plug_loads_vehicle_annual_kwh'] = '0.0'
    args['misc_plug_loads_vehicle_usage_multiplier'] = 1.0
  elsif ['invalid_files/multipliers-without-fuel-loads.xml'].include? hpxml_file
    args['misc_fuel_loads_grill_usage_multiplier'] = 1.0
    args['misc_fuel_loads_lighting_usage_multiplier'] = 1.0
    args['misc_fuel_loads_fireplace_usage_multiplier'] = 1.0
  elsif ['invalid_files/foundation-wall-insulation-greater-than-height.xml'].include? hpxml_file
    args['floor_over_foundation_assembly_r'] = 0
    args['foundation_wall_insulation_distance_to_bottom'] = '6.0'
  elsif ['invalid_files/conditioned-attic-with-one-floor-above-grade.xml'].include? hpxml_file
    args['geometry_attic_type'] = HPXML::AtticTypeConditioned
    args['ceiling_assembly_r'] = 0.0
  elsif ['invalid_files/zero-number-of-bedrooms.xml'].include? hpxml_file
    args['geometry_unit_num_bedrooms'] = 0
  elsif ['invalid_files/single-family-detached-with-shared-system.xml'].include? hpxml_file
    args['heating_system_type'] = "Shared #{HPXML::HVACTypeBoiler} w/ Baseboard"
  elsif ['invalid_files/rim-joist-height-but-no-assembly-r.xml'].include? hpxml_file
    args.delete('rim_joist_assembly_r')
  elsif ['invalid_files/rim-joist-assembly-r-but-no-height.xml'].include? hpxml_file
    args.delete('geometry_rim_joist_height')
  end
end

def download_epws
  require_relative 'HPXMLtoOpenStudio/resources/util'

  require 'tempfile'
  tmpfile = Tempfile.new('epw')

  UrlResolver.fetch('https://data.nrel.gov/system/files/128/tmy3s-cache-csv.zip', tmpfile)

  puts 'Extracting weather files...'
  weather_dir = File.join(File.dirname(__FILE__), 'weather')
  unzip_file = OpenStudio::UnzipFile.new(tmpfile.path.to_s)
  unzip_file.extractAllFiles(OpenStudio::toPath(weather_dir))

  num_epws_actual = Dir[File.join(weather_dir, '*.epw')].count
  puts "#{num_epws_actual} weather files are available in the weather directory."
  puts 'Completed.'
  exit!
end

def get_elements_from_sample_files(hpxml_docs)
  elements_being_used = []
  hpxml_docs.each do |xml, hpxml_doc|
    root = XMLHelper.get_element(hpxml_doc, '/HPXML')
    root.each_node do |node|
      next unless node.is_a?(Oga::XML::Element)

      ancestors = []
      node.each_ancestor do |parent_node|
        ancestors << ['h:', parent_node.name].join()
      end
      parent_element_xpath = ancestors.reverse
      child_element_xpath = ['h:', node.name].join()
      element_xpath = [parent_element_xpath, child_element_xpath].join('/')

      next if element_xpath.include? 'extension'

      elements_being_used << element_xpath if not elements_being_used.include? element_xpath
    end
  end

  return elements_being_used
end

def create_schematron_hpxml_validator(hpxml_docs)
  puts 'Generating HPXMLvalidator.xml...'
  elements_in_sample_files = get_elements_from_sample_files(hpxml_docs)

  base_elements_xsd = File.read(File.join(File.dirname(__FILE__), 'HPXMLtoOpenStudio', 'resources', 'BaseElements.xsd'))
  base_elements_xsd_doc = Oga.parse_xml(base_elements_xsd)

  # construct dictionary for enumerations and min/max values of HPXML data types
  hpxml_data_types_xsd = File.read(File.join(File.dirname(__FILE__), 'HPXMLtoOpenStudio', 'resources', 'HPXMLDataTypes.xsd'))
  hpxml_data_types_xsd_doc = Oga.parse_xml(hpxml_data_types_xsd)
  hpxml_data_types_dict = {}
  hpxml_data_types_xsd_doc.xpath('//xs:simpleType | //xs:complexType').each do |simple_type_element|
    enums = []
    simple_type_element.xpath('xs:restriction/xs:enumeration').each do |enum|
      enums << enum.get('value')
    end
    minInclusive_element = simple_type_element.at_xpath('xs:restriction/xs:minInclusive')
    min_inclusive = minInclusive_element.get('value') if not minInclusive_element.nil?
    maxInclusive_element = simple_type_element.at_xpath('xs:restriction/xs:maxInclusive')
    max_inclusive = maxInclusive_element.get('value') if not maxInclusive_element.nil?
    minExclusive_element = simple_type_element.at_xpath('xs:restriction/xs:minExclusive')
    min_exclusive = minExclusive_element.get('value') if not minExclusive_element.nil?
    maxExclusive_element = simple_type_element.at_xpath('xs:restriction/xs:maxExclusive')
    max_exclusive = maxExclusive_element.get('value') if not maxExclusive_element.nil?

    simple_type_element_name = simple_type_element.get('name')
    hpxml_data_types_dict[simple_type_element_name] = {}
    hpxml_data_types_dict[simple_type_element_name][:enums] = enums
    hpxml_data_types_dict[simple_type_element_name][:min_inclusive] = min_inclusive
    hpxml_data_types_dict[simple_type_element_name][:max_inclusive] = max_inclusive
    hpxml_data_types_dict[simple_type_element_name][:min_exclusive] = min_exclusive
    hpxml_data_types_dict[simple_type_element_name][:max_exclusive] = max_exclusive
  end

  # construct HPXMLvalidator.xml
  hpxml_validator = XMLHelper.create_doc(version = '1.0', encoding = 'UTF-8')
  root = XMLHelper.add_element(hpxml_validator, 'sch:schema')
  XMLHelper.add_attribute(root, 'xmlns:sch', 'http://purl.oclc.org/dsdl/schematron')
  XMLHelper.add_element(root, 'sch:title', 'HPXML Schematron Validator: HPXML.xsd', :string)
  name_space = XMLHelper.add_element(root, 'sch:ns')
  XMLHelper.add_attribute(name_space, 'uri', 'http://hpxmlonline.com/2019/10')
  XMLHelper.add_attribute(name_space, 'prefix', 'h')
  pattern = XMLHelper.add_element(root, 'sch:pattern')

  # construct complexType and group elements dictionary
  complex_type_or_group_dict = {}
  ['//xs:complexType', '//xs:group', '//xs:element'].each do |param|
    base_elements_xsd_doc.xpath(param).each do |param_type|
      next if param_type.name == 'element' && (not ['XMLTransactionHeaderInformation', 'ProjectStatus', 'SoftwareInfo'].include?(param_type.get('name')))
      next if param_type.get('name').nil?

      param_type_name = param_type.get('name')
      complex_type_or_group_dict[param_type_name] = {}

      param_type.each_node do |element|
        next unless element.is_a? Oga::XML::Element
        next unless (element.name == 'element' || element.name == 'group')
        next if element.name == 'element' && (element.get('name').nil? && element.get('ref').nil?)
        next if element.name == 'group' && element.get('ref').nil?

        ancestors = []
        element.each_ancestor do |node|
          next if node.get('name').nil?
          next if node.get('name') == param_type.get('name') # exclude complexType name from element xpath

          ancestors << node.get('name')
        end

        parent_element_names = ancestors.reverse
        if element.name == 'element'
          child_element_name = element.get('name')
          child_element_name = element.get('ref') if child_element_name.nil? # Backup
          element_type = element.get('type')
          element_type = element.get('ref') if element_type.nil? # Backup
        elsif element.name == 'group'
          child_element_name = nil # exclude group name from the element's xpath
          element_type = element.get('ref')
        end
        element_xpath = parent_element_names.push(child_element_name)
        complex_type_or_group_dict[param_type_name][element_xpath] = element_type
      end
    end
  end

  element_xpaths = {}
  top_level_elements_of_interest = elements_in_sample_files.map { |e| e.split('/')[1].gsub('h:', '') }.uniq
  top_level_elements_of_interest.each do |element|
    top_level_element = []
    top_level_element << element
    top_level_element_type = element
    get_element_full_xpaths(element_xpaths, complex_type_or_group_dict, top_level_element, top_level_element_type)
  end

  # Add enumeration and min/max numeric values
  rules = {}
  element_xpaths.each do |element_xpath, element_type|
    next if element_type.nil?

    # Skip element xpaths not being used in sample files
    element_xpath_with_prefix = element_xpath.compact.map { |e| "h:#{e}" }
    context_xpath = element_xpath_with_prefix.join('/').chomp('/')
    next unless elements_in_sample_files.any? { |item| item.include? context_xpath }

    hpxml_data_type_name = [element_type, '_simple'].join() # FUTURE: This may need to be improved later since enumeration and minimum/maximum values cannot be guaranteed to always be placed within simpleType.
    hpxml_data_type = hpxml_data_types_dict[hpxml_data_type_name]
    hpxml_data_type = hpxml_data_types_dict[element_type] if hpxml_data_type.nil? # Backup
    if hpxml_data_type.nil?
      fail "Could not find data type name for '#{element_type}'."
    end

    next if hpxml_data_type[:enums].empty? && hpxml_data_type[:min_inclusive].nil? && hpxml_data_type[:max_inclusive].nil? && hpxml_data_type[:min_exclusive].nil? && hpxml_data_type[:max_exclusive].nil?

    element_name = context_xpath.split('/')[-1]
    context_xpath = context_xpath.split('/')[0..-2].join('/').chomp('/').prepend('/h:HPXML/')
    rule = rules[context_xpath]
    if rule.nil?
      # Need new rule
      rule = XMLHelper.add_element(pattern, 'sch:rule')
      XMLHelper.add_attribute(rule, 'context', context_xpath)
      rules[context_xpath] = rule
    end

    if not hpxml_data_type[:enums].empty?
      assertion = XMLHelper.add_element(rule, 'sch:assert', "Expected #{element_name.gsub('h:', '')} to be \"#{hpxml_data_type[:enums].join('" or "')}\"", :string)
      XMLHelper.add_attribute(assertion, 'role', 'ERROR')
      XMLHelper.add_attribute(assertion, 'test', "#{element_name}[#{hpxml_data_type[:enums].map { |e| "text()=\"#{e}\"" }.join(' or ')}] or not(#{element_name})")
    else
      if hpxml_data_type[:min_inclusive]
        assertion = XMLHelper.add_element(rule, 'sch:assert', "Expected #{element_name.gsub('h:', '')} to be greater than or equal to #{hpxml_data_type[:min_inclusive]}", :string)
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "number(#{element_name}) &gt;= #{hpxml_data_type[:min_inclusive]} or not(#{element_name})")
      end
      if hpxml_data_type[:max_inclusive]
        assertion = XMLHelper.add_element(rule, 'sch:assert', "Expected #{element_name.gsub('h:', '')} to be less than or equal to #{hpxml_data_type[:max_inclusive]}", :string)
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "number(#{element_name}) &lt;= #{hpxml_data_type[:max_inclusive]} or not(#{element_name})")
      end
      if hpxml_data_type[:min_exclusive]
        assertion = XMLHelper.add_element(rule, 'sch:assert', "Expected #{element_name.gsub('h:', '')} to be greater than #{hpxml_data_type[:min_exclusive]}", :string)
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "number(#{element_name}) &gt; #{hpxml_data_type[:min_exclusive]} or not(#{element_name})")
      end
      if hpxml_data_type[:max_exclusive]
        assertion = XMLHelper.add_element(rule, 'sch:assert', "Expected #{element_name.gsub('h:', '')} to be less than #{hpxml_data_type[:max_exclusive]}", :string)
        XMLHelper.add_attribute(assertion, 'role', 'ERROR')
        XMLHelper.add_attribute(assertion, 'test', "number(#{element_name}) &lt; #{hpxml_data_type[:max_exclusive]} or not(#{element_name})")
      end
    end
  end

  # Add ID/IDref checks
  # TODO: Dynamically obtain these lists
  id_names = ['SystemIdentifier',
              'BuildingID']
  idref_names = ['AttachedToRoof',
                 'AttachedToFrameFloor',
                 'AttachedToSlab',
                 'AttachedToFoundationWall',
                 'AttachedToWall',
                 'AttachedToRimJoist',
                 'DistributionSystem',
                 'AttachedToHVACDistributionSystem',
                 'RelatedHVACSystem',
                 'ConnectedTo']
  elements_in_sample_files.each do |element_xpath|
    element_name = element_xpath.split('/')[-1].gsub('h:', '')
    context_xpath = "/#{element_xpath.split('/')[0..-2].join('/')}"
    if id_names.include? element_name
      rule = rules[context_xpath]
      if rule.nil?
        # Need new rule
        rule = XMLHelper.add_element(pattern, 'sch:rule')
        XMLHelper.add_attribute(rule, 'context', context_xpath)
        rules[context_xpath] = rule
      end
      assertion = XMLHelper.add_element(rule, 'sch:assert', "Expected id attribute for #{element_name}", :string)
      XMLHelper.add_attribute(assertion, 'role', 'ERROR')
      XMLHelper.add_attribute(assertion, 'test', "count(h:#{element_name}[@id]) = 1 or not (h:#{element_name})")
    elsif idref_names.include?(element_name) && (not context_xpath.end_with? 'h:Attic') && (not context_xpath.end_with? 'h:Foundation')
      rule = rules[context_xpath]
      if rule.nil?
        # Need new rule
        rule = XMLHelper.add_element(pattern, 'sch:rule')
        XMLHelper.add_attribute(rule, 'context', context_xpath)
        rules[context_xpath] = rule
      end
      assertion = XMLHelper.add_element(rule, 'sch:assert', "Expected idref attribute for #{element_name}", :string)
      XMLHelper.add_attribute(assertion, 'role', 'ERROR')
      XMLHelper.add_attribute(assertion, 'test', "count(h:#{element_name}[@idref]) = 1 or not(h:#{element_name})")
    end
  end

  XMLHelper.write_file(hpxml_validator, File.join(File.dirname(__FILE__), 'HPXMLtoOpenStudio', 'resources', 'HPXMLvalidator.xml'))
end

def get_element_full_xpaths(element_xpaths, complex_type_or_group_dict, element_xpath, element_type)
  if not complex_type_or_group_dict.keys.include? element_type
    element_xpaths[element_xpath] = element_type
  else
    complex_type_or_group = deep_copy_object(complex_type_or_group_dict[element_type])
    complex_type_or_group.each do |k, v|
      child_element_xpath = k.unshift(element_xpath).flatten!
      child_element_type = v

      if not complex_type_or_group_dict.keys.include? child_element_type
        element_xpaths[child_element_xpath] = child_element_type
        next
      end

      get_element_full_xpaths(element_xpaths, complex_type_or_group_dict, child_element_xpath, child_element_type)
    end
  end
end

def deep_copy_object(obj)
  return Marshal.load(Marshal.dump(obj))
end

command_list = [:update_measures, :update_hpxmls, :cache_weather, :create_release_zips, :download_weather]

def display_usage(command_list)
  puts "Usage: openstudio #{File.basename(__FILE__)} [COMMAND]\nCommands:\n  " + command_list.join("\n  ")
end

if ARGV.size == 0
  puts 'ERROR: Missing command.'
  display_usage(command_list)
  exit!
elsif ARGV.size > 1
  puts 'ERROR: Too many commands.'
  display_usage(command_list)
  exit!
elsif not command_list.include? ARGV[0].to_sym
  puts "ERROR: Invalid command '#{ARGV[0]}'."
  display_usage(command_list)
  exit!
end

if ARGV[0].to_sym == :update_measures
  # Prevent NREL error regarding U: drive when not VPNed in
  ENV['HOME'] = 'C:' if !ENV['HOME'].nil? && ENV['HOME'].start_with?('U:')
  ENV['HOMEDRIVE'] = 'C:\\' if !ENV['HOMEDRIVE'].nil? && ENV['HOMEDRIVE'].start_with?('U:')

  # Apply rubocop
  cops = ['Layout',
          'Lint/DeprecatedClassMethods',
          'Lint/RedundantStringCoercion',
          'Style/AndOr',
          'Style/FrozenStringLiteralComment',
          'Style/HashSyntax',
          'Style/Next',
          'Style/NilComparison',
          'Style/RedundantParentheses',
          'Style/RedundantSelf',
          'Style/ReturnNil',
          'Style/SelfAssignment',
          'Style/StringLiterals',
          'Style/StringLiteralsInInterpolation']
  commands = ["\"require 'rubocop/rake_task'\"",
              "\"RuboCop::RakeTask.new(:rubocop) do |t| t.options = ['--auto-correct', '--format', 'simple', '--only', '#{cops.join(',')}'] end\"",
              '"Rake.application[:rubocop].invoke"']
  command = "#{OpenStudio.getOpenStudioCLI} -e #{commands.join(' -e ')}"
  puts 'Applying rubocop auto-correct to measures...'
  system(command)

  # Update measures XMLs
  puts 'Updating measure.xmls...'
  require 'oga'
  require_relative 'HPXMLtoOpenStudio/resources/xmlhelper'
  Dir['**/measure.xml'].each do |measure_xml|
    for n_attempt in 1..5 # For some reason CLI randomly generates errors, so try multiple times; FIXME: Fix CLI so this doesn't happen
      measure_dir = File.dirname(measure_xml)
      command = "#{OpenStudio.getOpenStudioCLI} measure -u '#{measure_dir}'"
      system(command, [:out, :err] => File::NULL)

      # Check for error
      xml_doc = XMLHelper.parse_file(measure_xml)
      err_val = XMLHelper.get_value(xml_doc, '/measure/error', :string)
      if err_val.nil?
        err_val = XMLHelper.get_value(xml_doc, '/error', :string)
      end
      if err_val.nil?
        break # Successfully updated
      else
        if n_attempt == 5
          fail "#{measure_xml}: #{err_val}" # Error generated all 5 times, fail
        else
          # Remove error from measure XML, try again
          new_lines = File.readlines(measure_xml).select { |l| !l.include?('<error>') }
          File.open(measure_xml, 'w') do |file|
            file.puts new_lines
          end
        end
      end
    end
  end

  puts 'Done.'
end

if ARGV[0].to_sym == :update_hpxmls
  # Prevent NREL error regarding U: drive when not VPNed in
  ENV['HOME'] = 'C:' if !ENV['HOME'].nil? && ENV['HOME'].start_with?('U:')
  ENV['HOMEDRIVE'] = 'C:\\' if !ENV['HOMEDRIVE'].nil? && ENV['HOMEDRIVE'].start_with?('U:')

  # Create sample/test HPXMLs
  hpxml_docs = create_hpxmls()

  # Create Schematron file that reflects HPXML schema
  create_schematron_hpxml_validator(hpxml_docs)
end

if ARGV[0].to_sym == :cache_weather
  require_relative 'HPXMLtoOpenStudio/resources/weather'

  OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Fatal)
  runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
  puts 'Creating cache *.csv for weather files...'

  Dir['weather/*.epw'].each do |epw|
    next if File.exist? epw.gsub('.epw', '.cache')

    puts "Processing #{epw}..."
    model = OpenStudio::Model::Model.new
    epw_file = OpenStudio::EpwFile.new(epw)
    OpenStudio::Model::WeatherFile.setWeatherFile(model, epw_file).get
    weather = WeatherProcess.new(model, runner)
    File.open(epw.gsub('.epw', '-cache.csv'), 'wb') do |file|
      weather.dump_to_csv(file)
    end
  end
end

if ARGV[0].to_sym == :download_weather
  download_epws
end

if ARGV[0].to_sym == :create_release_zips
  require_relative 'HPXMLtoOpenStudio/resources/version'

  release_map = { File.join(File.dirname(__FILE__), "OpenStudio-HPXML-v#{Version::OS_HPXML_Version}-minimal.zip") => false,
                  File.join(File.dirname(__FILE__), "OpenStudio-HPXML-v#{Version::OS_HPXML_Version}-full.zip") => true }

  release_map.keys.each do |zip_path|
    File.delete(zip_path) if File.exist? zip_path
  end

  if ENV['CI']
    # CI doesn't have git, so default to everything
    git_files = Dir['**/*.*']
  else
    # Only include files under git version control
    command = 'git ls-files'
    begin
      git_files = `#{command}`
    rescue
      puts "Command failed: '#{command}'. Perhaps git needs to be installed?"
      exit!
    end
  end

  files = ['Changelog.md',
           'LICENSE.md',
           'BuildResidentialHPXML/measure.*',
           'BuildResidentialHPXML/resources/*.*',
           'BuildResidentialScheduleFile/measure.*',
           'BuildResidentialScheduleFile/resources/*.*',
           'HPXMLtoOpenStudio/measure.*',
           'HPXMLtoOpenStudio/resources/*.*',
           'ReportSimulationOutput/measure.*',
           'ReportSimulationOutput/resources/*.*',
           'ReportHPXMLOutput/measure.*',
           'ReportHPXMLOutput/resources/*.*',
           'weather/*.*',
           'workflow/*.*',
           'workflow/sample_files/*.xml',
           'workflow/tests/*test*.rb',
           'workflow/tests/ASHRAE_Standard_140/*.xml',
           'workflow/tests/base_results/*.csv',
           'documentation/index.html',
           'documentation/_static/**/*.*']

  if not ENV['CI']
    # Generate documentation
    puts 'Generating documentation...'
    command = 'sphinx-build -b singlehtml docs/source documentation'
    begin
      `#{command}`
      if not File.exist? File.join(File.dirname(__FILE__), 'documentation', 'index.html')
        puts 'Documentation was not successfully generated. Aborting...'
        exit!
      end
    rescue
      puts "Command failed: '#{command}'. Perhaps sphinx needs to be installed?"
      exit!
    end
    FileUtils.rm_r(File.join(File.dirname(__FILE__), 'documentation', '_static', 'fonts'))

    # Check if we need to download weather files for the full release zip
    num_epws_expected = 1011
    num_epws_local = 0
    files.each do |f|
      Dir[f].each do |file|
        next unless file.end_with? '.epw'

        num_epws_local += 1
      end
    end

    # Make sure we have the full set of weather files
    if num_epws_local < num_epws_expected
      puts 'Fetching all weather files...'
      command = "#{OpenStudio.getOpenStudioCLI} #{__FILE__} download_weather"
      log = `#{command}`
    end
  end

  # Create zip files
  release_map.each do |zip_path, include_all_epws|
    puts "Creating #{zip_path}..."
    zip = OpenStudio::ZipFile.new(zip_path, false)
    files.each do |f|
      Dir[f].each do |file|
        if file.start_with? 'documentation'
          # always include
        elsif include_all_epws
          if (not git_files.include? file) && (not file.start_with? 'weather')
            next
          end
        else
          if not git_files.include? file
            next
          end
        end

        zip.addFile(file, File.join('OpenStudio-HPXML', file))
      end
    end
    puts "Wrote file at #{zip_path}."
  end

  # Cleanup
  if not ENV['CI']
    FileUtils.rm_r(File.join(File.dirname(__FILE__), 'documentation'))
  end

  puts 'Done.'
end
