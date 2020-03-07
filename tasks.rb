def create_hpxmls
  this_dir = File.dirname(__FILE__)
  sample_files_dir = File.join(this_dir, "workflow/sample_files")

  # Hash of HPXML -> Parent HPXML
  hpxmls_files = {
    'base.xml' => nil,

    'invalid_files/bad-wmo.xml' => 'base.xml',
    'invalid_files/bad-site-neighbor-azimuth.xml' => 'base-site-neighbors.xml',
    'invalid_files/cfis-with-hydronic-distribution.xml' => 'base-hvac-boiler-gas-only.xml',
    'invalid_files/clothes-washer-location.xml' => 'base.xml',
    'invalid_files/clothes-washer-location-other.xml' => 'base.xml',
    'invalid_files/clothes-dryer-location.xml' => 'base.xml',
    'invalid_files/clothes-dryer-location-other.xml' => 'base.xml',
    'invalid_files/dhw-frac-load-served.xml' => 'base-dhw-multiple.xml',
    'invalid_files/duct-location.xml' => 'base.xml',
    'invalid_files/duct-location-other.xml' => 'base.xml',
    'invalid_files/heat-pump-mixed-fixed-and-autosize-capacities.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'invalid_files/heat-pump-mixed-fixed-and-autosize-capacities2.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'invalid_files/heat-pump-mixed-fixed-and-autosize-capacities3.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'invalid_files/heat-pump-mixed-fixed-and-autosize-capacities4.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'invalid_files/hvac-invalid-distribution-system-type.xml' => 'base.xml',
    'invalid_files/hvac-distribution-multiple-attached-cooling.xml' => 'base-hvac-multiple.xml',
    'invalid_files/hvac-distribution-multiple-attached-heating.xml' => 'base-hvac-multiple.xml',
    'invalid_files/hvac-distribution-return-duct-leakage-missing.xml' => 'base-hvac-evap-cooler-only-ducted.xml',
    'invalid_files/hvac-dse-multiple-attached-cooling.xml' => 'base-hvac-dse.xml',
    'invalid_files/hvac-dse-multiple-attached-heating.xml' => 'base-hvac-dse.xml',
    'invalid_files/hvac-frac-load-served.xml' => 'base-hvac-multiple.xml',
    'invalid_files/invalid-relatedhvac-dhw-indirect.xml' => 'base-dhw-indirect.xml',
    'invalid_files/invalid-relatedhvac-desuperheater.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'invalid_files/invalid-timestep.xml' => 'base.xml',
    'invalid_files/invalid-window-height.xml' => 'base-enclosure-overhangs.xml',
    'invalid_files/invalid-window-interior-shading.xml' => 'base.xml',
    'invalid_files/mismatched-slab-and-foundation-wall.xml' => 'base.xml',
    'invalid_files/missing-elements.xml' => 'base.xml',
    'invalid_files/missing-surfaces.xml' => 'base.xml',
    'invalid_files/net-area-negative-roof.xml' => 'base-enclosure-skylights.xml',
    'invalid_files/net-area-negative-wall.xml' => 'base.xml',
    'invalid_files/orphaned-hvac-distribution.xml' => 'base-hvac-furnace-gas-room-ac.xml',
    'invalid_files/refrigerator-location.xml' => 'base.xml',
    'invalid_files/refrigerator-location-other.xml' => 'base.xml',
    'invalid_files/repeated-relatedhvac-dhw-indirect.xml' => 'base-dhw-indirect.xml',
    'invalid_files/repeated-relatedhvac-desuperheater.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'invalid_files/solar-thermal-system-with-combi-tankless.xml' => 'base-dhw-combi-tankless.xml',
    'invalid_files/solar-thermal-system-with-desuperheater.xml' => 'base-dhw-desuperheater.xml',
    'invalid_files/solar-thermal-system-with-dhw-indirect.xml' => 'base-dhw-combi-tankless.xml',
    'invalid_files/unattached-cfis.xml' => 'base.xml',
    'invalid_files/unattached-door.xml' => 'base.xml',
    'invalid_files/unattached-hvac-distribution.xml' => 'base.xml',
    'invalid_files/unattached-skylight.xml' => 'base-enclosure-skylights.xml',
    'invalid_files/unattached-solar-thermal-system.xml' => 'base-dhw-solar-indirect-flat-plate.xml',
    'invalid_files/unattached-window.xml' => 'base.xml',
    'invalid_files/water-heater-location.xml' => 'base.xml',
    'invalid_files/water-heater-location-other.xml' => 'base.xml',
    'invalid_files/slab-zero-exposed-perimeter.xml' => 'base.xml',

    'base-appliances-gas.xml' => 'base.xml',
    'base-appliances-wood.xml' => 'base.xml',
    'base-appliances-modified.xml' => 'base.xml',
    'base-appliances-none.xml' => 'base.xml',
    'base-appliances-oil.xml' => 'base.xml',
    'base-appliances-propane.xml' => 'base.xml',
    'base-atticroof-cathedral.xml' => 'base.xml',
    'base-atticroof-conditioned.xml' => 'base.xml',
    'base-atticroof-flat.xml' => 'base.xml',
    'base-atticroof-radiant-barrier.xml' => 'base-location-dallas-tx.xml',
    'base-atticroof-vented.xml' => 'base.xml',
    'base-atticroof-unvented-insulated-roof.xml' => 'base.xml',
    'base-dhw-combi-tankless.xml' => 'base-dhw-indirect.xml',
    'base-dhw-combi-tankless-outside.xml' => 'base-dhw-combi-tankless.xml',
    'base-dhw-desuperheater.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'base-dhw-desuperheater-tankless.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'base-dhw-desuperheater-2-speed.xml' => 'base-hvac-central-ac-only-2-speed.xml',
    'base-dhw-desuperheater-var-speed.xml' => 'base-hvac-central-ac-only-var-speed.xml',
    'base-dhw-desuperheater-gshp.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'base-dhw-dwhr.xml' => 'base.xml',
    'base-dhw-indirect.xml' => 'base-hvac-boiler-gas-only.xml',
    'base-dhw-indirect-dse.xml' => 'base-dhw-indirect.xml',
    'base-dhw-indirect-outside.xml' => 'base-dhw-indirect.xml',
    'base-dhw-indirect-standbyloss.xml' => 'base-dhw-indirect.xml',
    'base-dhw-low-flow-fixtures.xml' => 'base.xml',
    'base-dhw-multiple.xml' => 'base-hvac-boiler-gas-only.xml',
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
    'base-dhw-solar-indirect-evacuated-tube.xml' => 'base.xml',
    'base-dhw-solar-indirect-flat-plate.xml' => 'base.xml',
    'base-dhw-solar-thermosyphon-evacuated-tube.xml' => 'base.xml',
    'base-dhw-solar-thermosyphon-flat-plate.xml' => 'base.xml',
    'base-dhw-solar-thermosyphon-ics.xml' => 'base.xml',
    'base-dhw-tank-gas.xml' => 'base.xml',
    'base-dhw-tank-gas-outside.xml' => 'base-dhw-tank-gas.xml',
    'base-dhw-tank-heat-pump.xml' => 'base.xml',
    'base-dhw-tank-heat-pump-outside.xml' => 'base-dhw-tank-heat-pump.xml',
    'base-dhw-tank-heat-pump-with-solar.xml' => 'base-dhw-tank-heat-pump.xml',
    'base-dhw-tank-heat-pump-with-solar-fraction.xml' => 'base-dhw-tank-heat-pump.xml',
    'base-dhw-tank-oil.xml' => 'base.xml',
    'base-dhw-tank-propane.xml' => 'base.xml',
    'base-dhw-tank-wood.xml' => 'base.xml',
    'base-dhw-tankless-electric.xml' => 'base.xml',
    'base-dhw-tankless-electric-outside.xml' => 'base-dhw-tankless-electric.xml',
    'base-dhw-tankless-gas.xml' => 'base.xml',
    'base-dhw-tankless-gas-with-solar.xml' => 'base-dhw-tankless-gas.xml',
    'base-dhw-tankless-gas-with-solar-fraction.xml' => 'base-dhw-tankless-gas.xml',
    'base-dhw-tankless-oil.xml' => 'base.xml',
    'base-dhw-tankless-propane.xml' => 'base.xml',
    'base-dhw-tankless-wood.xml' => 'base.xml',
    'base-dhw-temperature.xml' => 'base.xml',
    'base-dhw-uef.xml' => 'base.xml',
    'base-dhw-jacket-electric.xml' => 'base.xml',
    'base-dhw-jacket-gas.xml' => 'base-dhw-tank-gas.xml',
    'base-dhw-jacket-indirect.xml' => 'base-dhw-indirect.xml',
    'base-dhw-jacket-hpwh.xml' => 'base-dhw-tank-heat-pump.xml',
    'base-enclosure-2stories.xml' => 'base.xml',
    'base-enclosure-2stories-garage.xml' => 'base-enclosure-2stories.xml',
    'base-enclosure-adiabatic-surfaces.xml' => 'base-foundation-ambient.xml',
    'base-enclosure-beds-1.xml' => 'base.xml',
    'base-enclosure-beds-2.xml' => 'base.xml',
    'base-enclosure-beds-4.xml' => 'base.xml',
    'base-enclosure-beds-5.xml' => 'base.xml',
    'base-enclosure-garage.xml' => 'base.xml',
    'base-enclosure-infil-cfm50.xml' => 'base.xml',
    'base-enclosure-overhangs.xml' => 'base.xml',
    'base-enclosure-skylights.xml' => 'base.xml',
    'base-enclosure-split-surfaces.xml' => 'base-enclosure-skylights.xml',
    'base-enclosure-walltype-cmu.xml' => 'base.xml',
    'base-enclosure-walltype-doublestud.xml' => 'base.xml',
    'base-enclosure-walltype-icf.xml' => 'base.xml',
    'base-enclosure-walltype-log.xml' => 'base.xml',
    'base-enclosure-walltype-sip.xml' => 'base.xml',
    'base-enclosure-walltype-solidconcrete.xml' => 'base.xml',
    'base-enclosure-walltype-steelstud.xml' => 'base.xml',
    'base-enclosure-walltype-stone.xml' => 'base.xml',
    'base-enclosure-walltype-strawbale.xml' => 'base.xml',
    'base-enclosure-walltype-structuralbrick.xml' => 'base.xml',
    'base-enclosure-windows-inoperable.xml' => 'base.xml',
    'base-enclosure-windows-interior-shading.xml' => 'base.xml',
    'base-enclosure-windows-none.xml' => 'base.xml',
    'base-foundation-multiple.xml' => 'base-foundation-unconditioned-basement.xml',
    'base-foundation-ambient.xml' => 'base.xml',
    'base-foundation-conditioned-basement-slab-insulation.xml' => 'base.xml',
    'base-foundation-conditioned-basement-wall-interior-insulation.xml' => 'base.xml',
    'base-foundation-slab.xml' => 'base.xml',
    'base-foundation-unconditioned-basement.xml' => 'base.xml',
    'base-foundation-unconditioned-basement-assembly-r.xml' => 'base-foundation-unconditioned-basement.xml',
    'base-foundation-unconditioned-basement-above-grade.xml' => 'base-foundation-unconditioned-basement.xml',
    'base-foundation-unconditioned-basement-wall-insulation.xml' => 'base-foundation-unconditioned-basement.xml',
    'base-foundation-unvented-crawlspace.xml' => 'base.xml',
    'base-foundation-vented-crawlspace.xml' => 'base.xml',
    'base-foundation-walkout-basement.xml' => 'base.xml',
    'base-foundation-complex.xml' => 'base.xml',
    'base-hvac-air-to-air-heat-pump-1-speed.xml' => 'base.xml',
    'base-hvac-air-to-air-heat-pump-1-speed-detailed.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-air-to-air-heat-pump-2-speed.xml' => 'base.xml',
    'base-hvac-air-to-air-heat-pump-2-speed-detailed.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'base-hvac-air-to-air-heat-pump-var-speed.xml' => 'base.xml',
    'base-hvac-air-to-air-heat-pump-var-speed-detailed.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'base-hvac-boiler-elec-only.xml' => 'base.xml',
    'base-hvac-boiler-gas-central-ac-1-speed.xml' => 'base.xml',
    'base-hvac-boiler-gas-only.xml' => 'base.xml',
    'base-hvac-boiler-gas-only-no-eae.xml' => 'base-hvac-boiler-gas-only.xml',
    'base-hvac-boiler-oil-only.xml' => 'base.xml',
    'base-hvac-boiler-propane-only.xml' => 'base.xml',
    'base-hvac-boiler-wood-only.xml' => 'base.xml',
    'base-hvac-central-ac-only-1-speed.xml' => 'base.xml',
    'base-hvac-central-ac-only-1-speed-detailed.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'base-hvac-central-ac-only-2-speed.xml' => 'base.xml',
    'base-hvac-central-ac-only-2-speed-detailed.xml' => 'base-hvac-central-ac-only-2-speed.xml',
    'base-hvac-central-ac-only-var-speed.xml' => 'base.xml',
    'base-hvac-central-ac-only-var-speed-detailed.xml' => 'base-hvac-central-ac-only-var-speed.xml',
    'base-hvac-central-ac-plus-air-to-air-heat-pump-heating.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'base-hvac-dse.xml' => 'base.xml',
    'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed-electric.xml' => 'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml',
    'base-hvac-dual-fuel-air-to-air-heat-pump-2-speed.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'base-hvac-dual-fuel-air-to-air-heat-pump-var-speed.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'base-hvac-dual-fuel-mini-split-heat-pump-ducted.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'base-hvac-ducts-in-conditioned-space.xml' => 'base.xml',
    'base-hvac-ducts-leakage-percent.xml' => 'base.xml',
    'base-hvac-ducts-locations.xml' => 'base-foundation-vented-crawlspace.xml',
    'base-hvac-ducts-multiple.xml' => 'base.xml',
    'base-hvac-ducts-outside.xml' => 'base.xml',
    'base-hvac-elec-resistance-only.xml' => 'base.xml',
    'base-hvac-evap-cooler-furnace-gas.xml' => 'base.xml',
    'base-hvac-evap-cooler-only.xml' => 'base.xml',
    'base-hvac-evap-cooler-only-ducted.xml' => 'base.xml',
    'base-hvac-flowrate.xml' => 'base.xml',
    'base-hvac-furnace-elec-only.xml' => 'base.xml',
    'base-hvac-furnace-gas-central-ac-2-speed.xml' => 'base.xml',
    'base-hvac-furnace-gas-central-ac-var-speed.xml' => 'base.xml',
    'base-hvac-furnace-gas-only.xml' => 'base.xml',
    'base-hvac-furnace-gas-only-no-eae.xml' => 'base-hvac-furnace-gas-only.xml',
    'base-hvac-furnace-gas-room-ac.xml' => 'base.xml',
    'base-hvac-furnace-oil-only.xml' => 'base.xml',
    'base-hvac-furnace-propane-only.xml' => 'base.xml',
    'base-hvac-furnace-wood-only.xml' => 'base.xml',
    'base-hvac-furnace-x3-dse.xml' => 'base.xml',
    'base-hvac-ground-to-air-heat-pump.xml' => 'base.xml',
    'base-hvac-ground-to-air-heat-pump-detailed.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'base-hvac-ideal-air.xml' => 'base.xml',
    'base-hvac-mini-split-heat-pump-ducted.xml' => 'base.xml',
    'base-hvac-mini-split-heat-pump-ducted-detailed.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'base-hvac-mini-split-heat-pump-ductless.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'base-hvac-mini-split-heat-pump-ductless-no-backup.xml' => 'base-hvac-mini-split-heat-pump-ductless.xml',
    'base-hvac-multiple.xml' => 'base.xml',
    'base-hvac-none.xml' => 'base.xml',
    'base-hvac-none-no-fuel-access.xml' => 'base-hvac-none.xml',
    'base-hvac-portable-heater-electric-only.xml' => 'base.xml',
    'base-hvac-programmable-thermostat.xml' => 'base.xml',
    'base-hvac-room-ac-only.xml' => 'base.xml',
    'base-hvac-room-ac-only-detailed.xml' => 'base-hvac-room-ac-only.xml',
    'base-hvac-setpoints.xml' => 'base.xml',
    'base-hvac-stove-oil-only.xml' => 'base.xml',
    'base-hvac-stove-oil-only-no-eae.xml' => 'base-hvac-stove-oil-only.xml',
    'base-hvac-stove-wood-only.xml' => 'base.xml',
    'base-hvac-undersized.xml' => 'base.xml',
    'base-hvac-wall-furnace-elec-only.xml' => 'base.xml',
    'base-hvac-wall-furnace-propane-only.xml' => 'base.xml',
    'base-hvac-wall-furnace-propane-only-no-eae.xml' => 'base-hvac-wall-furnace-propane-only.xml',
    'base-hvac-wall-furnace-wood-only.xml' => 'base.xml',
    'base-infiltration-ach-natural.xml' => 'base.xml',
    'base-location-baltimore-md.xml' => 'base.xml',
    'base-location-dallas-tx.xml' => 'base.xml',
    'base-location-duluth-mn.xml' => 'base.xml',
    'base-location-miami-fl.xml' => 'base.xml',
    'base-location-epw-filename.xml' => 'base.xml',
    'base-mechvent-balanced.xml' => 'base.xml',
    'base-mechvent-cfis.xml' => 'base.xml',
    'base-mechvent-cfis-evap-cooler-only-ducted.xml' => 'base-hvac-evap-cooler-only-ducted.xml',
    'base-mechvent-erv.xml' => 'base.xml',
    'base-mechvent-erv-atre-asre.xml' => 'base.xml',
    'base-mechvent-exhaust.xml' => 'base.xml',
    'base-mechvent-exhaust-rated-flow-rate.xml' => 'base.xml',
    'base-mechvent-hrv.xml' => 'base.xml',
    'base-mechvent-hrv-asre.xml' => 'base.xml',
    'base-mechvent-supply.xml' => 'base.xml',
    'base-misc-ceiling-fans.xml' => 'base.xml',
    'base-misc-lighting-none.xml' => 'base.xml',
    'base-misc-loads-detailed.xml' => 'base.xml',
    'base-misc-number-of-occupants.xml' => 'base.xml',
    'base-misc-timestep-10-mins.xml' => 'base.xml',
    'base-misc-timestep-60-mins.xml' => 'base.xml',
    'base-misc-whole-house-fan.xml' => 'base.xml',
    'base-pv.xml' => 'base.xml',
    'base-site-neighbors.xml' => 'base.xml',
    'base-version-2014.xml' => 'base.xml',
    'base-version-2014A.xml' => 'base.xml',
    'base-version-2014AE.xml' => 'base.xml',
    'base-version-2014AEG.xml' => 'base.xml',
    'base-version-latest.xml' => 'base.xml',

    'hvac_autosizing/base-autosize.xml' => 'base.xml',
    'hvac_autosizing/base-hvac-air-to-air-heat-pump-1-speed-autosize.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_autosizing/base-hvac-air-to-air-heat-pump-2-speed-autosize.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_autosizing/base-hvac-air-to-air-heat-pump-var-speed-autosize.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_autosizing/base-hvac-boiler-elec-only-autosize.xml' => 'base-hvac-boiler-elec-only.xml',
    'hvac_autosizing/base-hvac-boiler-gas-central-ac-1-speed-autosize.xml' => 'base-hvac-boiler-gas-central-ac-1-speed.xml',
    'hvac_autosizing/base-hvac-boiler-gas-only-autosize.xml' => 'base-hvac-boiler-gas-only.xml',
    'hvac_autosizing/base-hvac-central-ac-only-1-speed-autosize.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'hvac_autosizing/base-hvac-central-ac-only-2-speed-autosize.xml' => 'base-hvac-central-ac-only-2-speed.xml',
    'hvac_autosizing/base-hvac-central-ac-only-var-speed-autosize.xml' => 'base-hvac-central-ac-only-var-speed.xml',
    'hvac_autosizing/base-hvac-central-ac-plus-air-to-air-heat-pump-heating-autosize.xml' => 'base-hvac-central-ac-plus-air-to-air-heat-pump-heating.xml',
    'hvac_autosizing/base-hvac-dual-fuel-air-to-air-heat-pump-1-speed-autosize.xml' => 'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml',
    'hvac_autosizing/base-hvac-dual-fuel-mini-split-heat-pump-ducted-autosize.xml' => 'base-hvac-dual-fuel-mini-split-heat-pump-ducted.xml',
    'hvac_autosizing/base-hvac-elec-resistance-only-autosize.xml' => 'base-hvac-elec-resistance-only.xml',
    'hvac_autosizing/base-hvac-evap-cooler-furnace-gas-autosize.xml' => 'base-hvac-evap-cooler-furnace-gas.xml',
    'hvac_autosizing/base-hvac-furnace-elec-only-autosize.xml' => 'base-hvac-furnace-elec-only.xml',
    'hvac_autosizing/base-hvac-furnace-gas-central-ac-2-speed-autosize.xml' => 'base-hvac-furnace-gas-central-ac-2-speed.xml',
    'hvac_autosizing/base-hvac-furnace-gas-central-ac-var-speed-autosize.xml' => 'base-hvac-furnace-gas-central-ac-var-speed.xml',
    'hvac_autosizing/base-hvac-furnace-gas-only-autosize.xml' => 'base-hvac-furnace-gas-only.xml',
    'hvac_autosizing/base-hvac-furnace-gas-room-ac-autosize.xml' => 'base-hvac-furnace-gas-room-ac.xml',
    'hvac_autosizing/base-hvac-ground-to-air-heat-pump-autosize.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'hvac_autosizing/base-hvac-mini-split-heat-pump-ducted-autosize.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_autosizing/base-hvac-room-ac-only-autosize.xml' => 'base-hvac-room-ac-only.xml',
    'hvac_autosizing/base-hvac-stove-oil-only-autosize.xml' => 'base-hvac-stove-oil-only.xml',
    'hvac_autosizing/base-hvac-wall-furnace-elec-only-autosize.xml' => 'base-hvac-wall-furnace-elec-only.xml',
    'hvac_autosizing/base-hvac-wall-furnace-propane-only-autosize.xml' => 'base-hvac-wall-furnace-propane-only.xml',

    'hvac_base/base-base.xml' => 'base.xml',
    'hvac_base/base-hvac-air-to-air-heat-pump-1-speed-base.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_base/base-hvac-air-to-air-heat-pump-2-speed-base.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_base/base-hvac-air-to-air-heat-pump-var-speed-base.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_base/base-hvac-boiler-gas-only-base.xml' => 'base-hvac-boiler-gas-only.xml',
    'hvac_base/base-hvac-central-ac-only-1-speed-base.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'hvac_base/base-hvac-central-ac-only-2-speed-base.xml' => 'base-hvac-central-ac-only-2-speed.xml',
    'hvac_base/base-hvac-central-ac-only-var-speed-base.xml' => 'base-hvac-central-ac-only-var-speed.xml',
    'hvac_base/base-hvac-dual-fuel-air-to-air-heat-pump-1-speed-base.xml' => 'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml',
    'hvac_base/base-hvac-elec-resistance-only-base.xml' => 'base-hvac-elec-resistance-only.xml',
    'hvac_base/base-hvac-evap-cooler-only-base.xml' => 'base-hvac-evap-cooler-only.xml',
    'hvac_base/base-hvac-furnace-gas-central-ac-2-speed-base.xml' => 'base-hvac-furnace-gas-central-ac-2-speed.xml',
    'hvac_base/base-hvac-furnace-gas-central-ac-var-speed-base.xml' => 'base-hvac-furnace-gas-central-ac-var-speed.xml',
    'hvac_base/base-hvac-furnace-gas-only-base.xml' => 'base-hvac-furnace-gas-only.xml',
    'hvac_base/base-hvac-furnace-gas-room-ac-base.xml' => 'base-hvac-furnace-gas-room-ac.xml',
    'hvac_base/base-hvac-ground-to-air-heat-pump-base.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'hvac_base/base-hvac-ideal-air-base.xml' => 'base-hvac-ideal-air.xml',
    'hvac_base/base-hvac-mini-split-heat-pump-ducted-base.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_base/base-hvac-room-ac-only-base.xml' => 'base-hvac-room-ac-only.xml',
    'hvac_base/base-hvac-stove-oil-only-base.xml' => 'base-hvac-stove-oil-only.xml',
    'hvac_base/base-hvac-wall-furnace-propane-only-base.xml' => 'base-hvac-wall-furnace-propane-only.xml',

    'hvac_load_fracs/base-hvac-air-to-air-heat-pump-1-speed-zero-cool.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_load_fracs/base-hvac-air-to-air-heat-pump-1-speed-zero-heat.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_load_fracs/base-hvac-air-to-air-heat-pump-2-speed-zero-cool.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_load_fracs/base-hvac-air-to-air-heat-pump-2-speed-zero-heat.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_load_fracs/base-hvac-air-to-air-heat-pump-var-speed-zero-cool.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_load_fracs/base-hvac-air-to-air-heat-pump-var-speed-zero-heat.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_load_fracs/base-hvac-ground-to-air-heat-pump-zero-cool.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'hvac_load_fracs/base-hvac-ground-to-air-heat-pump-zero-heat.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'hvac_load_fracs/base-hvac-mini-split-heat-pump-ducted-zero-cool.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_load_fracs/base-hvac-mini-split-heat-pump-ducted-zero-heat.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',

    'hvac_multiple/base-hvac-air-to-air-heat-pump-1-speed-x3.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_multiple/base-hvac-air-to-air-heat-pump-2-speed-x3.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_multiple/base-hvac-air-to-air-heat-pump-var-speed-x3.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_multiple/base-hvac-boiler-gas-only-x3.xml' => 'base-hvac-boiler-gas-only.xml',
    'hvac_multiple/base-hvac-central-ac-only-1-speed-x3.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'hvac_multiple/base-hvac-central-ac-only-2-speed-x3.xml' => 'base-hvac-central-ac-only-2-speed.xml',
    'hvac_multiple/base-hvac-central-ac-only-var-speed-x3.xml' => 'base-hvac-central-ac-only-var-speed.xml',
    'hvac_multiple/base-hvac-dual-fuel-air-to-air-heat-pump-1-speed-x3.xml' => 'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml',
    'hvac_multiple/base-hvac-elec-resistance-only-x3.xml' => 'base-hvac-elec-resistance-only.xml',
    'hvac_multiple/base-hvac-evap-cooler-only-x3.xml' => 'base-hvac-evap-cooler-only.xml',
    'hvac_multiple/base-hvac-furnace-gas-only-x3.xml' => 'base-hvac-furnace-gas-only.xml',
    'hvac_multiple/base-hvac-ground-to-air-heat-pump-x3.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'hvac_multiple/base-hvac-mini-split-heat-pump-ducted-x3.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_multiple/base-hvac-room-ac-only-x3.xml' => 'base-hvac-room-ac-only.xml',
    'hvac_multiple/base-hvac-stove-oil-only-x3.xml' => 'base-hvac-stove-oil-only.xml',
    'hvac_multiple/base-hvac-wall-furnace-propane-only-x3.xml' => 'base-hvac-wall-furnace-propane-only.xml',

    'hvac_partial/base-33percent.xml' => 'base.xml',
    'hvac_partial/base-hvac-air-to-air-heat-pump-1-speed-33percent.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_partial/base-hvac-air-to-air-heat-pump-2-speed-33percent.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_partial/base-hvac-air-to-air-heat-pump-var-speed-33percent.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_partial/base-hvac-boiler-gas-only-33percent.xml' => 'base-hvac-boiler-gas-only.xml',
    'hvac_partial/base-hvac-central-ac-only-1-speed-33percent.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'hvac_partial/base-hvac-central-ac-only-2-speed-33percent.xml' => 'base-hvac-central-ac-only-2-speed.xml',
    'hvac_partial/base-hvac-central-ac-only-var-speed-33percent.xml' => 'base-hvac-central-ac-only-var-speed.xml',
    'hvac_partial/base-hvac-dual-fuel-air-to-air-heat-pump-1-speed-33percent.xml' => 'base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml',
    'hvac_partial/base-hvac-elec-resistance-only-33percent.xml' => 'base-hvac-elec-resistance-only.xml',
    'hvac_partial/base-hvac-evap-cooler-only-33percent.xml' => 'base-hvac-evap-cooler-only.xml',
    'hvac_partial/base-hvac-furnace-gas-central-ac-2-speed-33percent.xml' => 'base-hvac-furnace-gas-central-ac-2-speed.xml',
    'hvac_partial/base-hvac-furnace-gas-central-ac-var-speed-33percent.xml' => 'base-hvac-furnace-gas-central-ac-var-speed.xml',
    'hvac_partial/base-hvac-furnace-gas-only-33percent.xml' => 'base-hvac-furnace-gas-only.xml',
    'hvac_partial/base-hvac-furnace-gas-room-ac-33percent.xml' => 'base-hvac-furnace-gas-room-ac.xml',
    'hvac_partial/base-hvac-ground-to-air-heat-pump-33percent.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'hvac_partial/base-hvac-mini-split-heat-pump-ducted-33percent.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_partial/base-hvac-room-ac-only-33percent.xml' => 'base-hvac-room-ac-only.xml',
    'hvac_partial/base-hvac-stove-oil-only-33percent.xml' => 'base-hvac-stove-oil-only.xml',
    'hvac_partial/base-hvac-wall-furnace-propane-only-33percent.xml' => 'base-hvac-wall-furnace-propane-only.xml',
  }

  puts "Generating #{hpxmls_files.size} HPXML files..."

  hpxmls_files.each do |derivative, parent|
    print "."

    begin
      hpxml_files = [derivative]
      unless parent.nil?
        hpxml_files.unshift(parent)
      end
      while not parent.nil?
        if hpxmls_files.keys.include? parent
          unless hpxmls_files[parent].nil?
            hpxml_files.unshift(hpxmls_files[parent])
          end
          parent = hpxmls_files[parent]
        end
      end

      hpxml = HPXML.new
      hpxml_files.each do |hpxml_file|
        set_hpxml_header(hpxml_file, hpxml)
        set_hpxml_site(hpxml_file, hpxml)
        set_hpxml_neighbor_buildings(hpxml_file, hpxml)
        set_hpxml_building_occupancy(hpxml_file, hpxml)
        set_hpxml_building_construction(hpxml_file, hpxml)
        set_hpxml_climate_and_risk_zones(hpxml_file, hpxml)
        set_hpxml_attics(hpxml_file, hpxml)
        set_hpxml_foundations(hpxml_file, hpxml)
        set_hpxml_air_infiltration_measurements(hpxml_file, hpxml)
        set_hpxml_roofs(hpxml_file, hpxml)
        set_hpxml_rim_joists(hpxml_file, hpxml)
        set_hpxml_walls(hpxml_file, hpxml)
        set_hpxml_foundation_walls(hpxml_file, hpxml)
        set_hpxml_frame_floors(hpxml_file, hpxml)
        set_hpxml_slabs(hpxml_file, hpxml)
        set_hpxml_windows(hpxml_file, hpxml)
        set_hpxml_skylights(hpxml_file, hpxml)
        set_hpxml_doors(hpxml_file, hpxml)
        set_hpxml_heating_systems(hpxml_file, hpxml)
        set_hpxml_cooling_systems(hpxml_file, hpxml)
        set_hpxml_heat_pumps(hpxml_file, hpxml)
        set_hpxml_hvac_control(hpxml_file, hpxml)
        set_hpxml_hvac_distributions(hpxml_file, hpxml)
        set_hpxml_ventilation_fans(hpxml_file, hpxml)
        set_hpxml_water_heating_systems(hpxml_file, hpxml)
        set_hpxml_hot_water_distribution(hpxml_file, hpxml)
        set_hpxml_water_fixtures(hpxml_file, hpxml)
        set_hpxml_solar_thermal_system(hpxml_file, hpxml)
        set_hpxml_pv_systems(hpxml_file, hpxml)
        set_hpxml_clothes_washer(hpxml_file, hpxml)
        set_hpxml_clothes_dryer(hpxml_file, hpxml)
        set_hpxml_dishwasher(hpxml_file, hpxml)
        set_hpxml_refrigerator(hpxml_file, hpxml)
        set_hpxml_cooking_range(hpxml_file, hpxml)
        set_hpxml_oven(hpxml_file, hpxml)
        set_hpxml_lighting(hpxml_file, hpxml)
        set_hpxml_ceiling_fans(hpxml_file, hpxml)
        set_hpxml_plug_loads(hpxml_file, hpxml)
        set_hpxml_misc_load_schedule(hpxml_file, hpxml)
      end

      hpxml_doc = hpxml.to_rexml()

      if ['invalid_files/missing-elements.xml'].include? derivative
        hpxml_doc.elements["/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction"].elements.delete("NumberofConditionedFloors")
        hpxml_doc.elements["/HPXML/Building/BuildingDetails/BuildingSummary/BuildingConstruction"].elements.delete("ConditionedFloorArea")
      end

      hpxml_path = File.join(sample_files_dir, derivative)

      # Validate file against HPXML schema
      schemas_dir = File.absolute_path(File.join(File.dirname(__FILE__), "HPXMLtoOpenStudio/resources"))
      errors = XMLHelper.validate(hpxml_doc.to_s, File.join(schemas_dir, "HPXML.xsd"), nil)
      if errors.size > 0
        fail errors.to_s
      end

      XMLHelper.write_file(hpxml_doc, hpxml_path)
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
    abs_hpxml_files << File.absolute_path(File.join(sample_files_dir, hpxml_file))
    next unless hpxml_file.include? '/'

    dirs << hpxml_file.split('/')[0] + '/'
  end
  dirs.uniq.each do |dir|
    Dir["#{sample_files_dir}/#{dir}*.xml"].each do |xml|
      next if abs_hpxml_files.include? File.absolute_path(xml)

      puts "Warning: Extra HPXML file found at #{File.absolute_path(xml)}"
    end
  end
end

def set_hpxml_header(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.header = HPXML::Header.new({ :xml_type => "HPXML",
                                       :xml_generated_by => "Rakefile",
                                       :transaction => "create",
                                       :building_id => "MyBuilding",
                                       :event_type => "proposed workscope",
                                       :created_date_and_time => Time.new(2000, 1, 1).strftime("%Y-%m-%dT%H:%M:%S%:z") }) # Hard-code to prevent diffs
  elsif ['base-version-2014.xml'].include? hpxml_file
    hpxml.header.eri_calculation_version = "2014"
  elsif ['base-version-2014A.xml'].include? hpxml_file
    hpxml.header.eri_calculation_version = "2014A"
  elsif ['base-version-2014AE.xml'].include? hpxml_file
    hpxml.header.eri_calculation_version = "2014AE"
  elsif ['base-version-2014AEG.xml'].include? hpxml_file
    hpxml.header.eri_calculation_version = "2014AEG"
  elsif ['base-version-latest.xml'].include? hpxml_file
    hpxml.header.eri_calculation_version = 'latest'
  elsif ['base-misc-timestep-10-mins.xml'].include? hpxml_file
    hpxml.header.timestep = 10
  elsif ['base-misc-timestep-60-mins.xml'].include? hpxml_file
    hpxml.header.timestep = 60
  elsif ['invalid_files/invalid-timestep.xml'].include? hpxml_file
    hpxml.header.timestep = 45
  end
end

def set_hpxml_site(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.site = HPXML::Site.new({ :fuels => ["electricity", "natural gas"] })
  elsif ['base-hvac-none-no-fuel-access.xml'].include? hpxml_file
    hpxml.site.fuels = ["electricity"]
  end
end

def set_hpxml_neighbor_buildings(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.neighbor_buildings = []
  elsif ['base-site-neighbors.xml'].include? hpxml_file
    hpxml.neighbor_buildings << HPXML::NeighborBuilding.new({ :azimuth => 0,
                                                              :distance => 10 })
    hpxml.neighbor_buildings << HPXML::NeighborBuilding.new({ :azimuth => 180,
                                                              :distance => 15,
                                                              :height => 12 })
  elsif ['invalid_files/bad-site-neighbor-azimuth.xml'].include? hpxml_file
    hpxml.neighbor_buildings[0].azimuth = 145
  end
end

def set_hpxml_building_occupancy(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.building_occupancy = nil
  elsif ['base-misc-number-of-occupants.xml'].include? hpxml_file
    hpxml.building_occupancy = HPXML::BuildingOccupancy.new({ :number_of_residents => 5 })
  end
end

def set_hpxml_building_construction(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.building_construction = HPXML::BuildingConstruction.new({ :number_of_conditioned_floors => 2,
                                                                    :number_of_conditioned_floors_above_grade => 1,
                                                                    :number_of_bedrooms => 3,
                                                                    :conditioned_floor_area => 2700,
                                                                    :conditioned_building_volume => 2700 * 8,
                                                                    :fraction_of_operable_window_area => 0.33 })
  elsif ['base-enclosure-beds-1.xml'].include? hpxml_file
    hpxml.building_construction.number_of_bedrooms = 1
  elsif ['base-enclosure-beds-2.xml'].include? hpxml_file
    hpxml.building_construction.number_of_bedrooms = 2
  elsif ['base-enclosure-beds-4.xml'].include? hpxml_file
    hpxml.building_construction.number_of_bedrooms = 4
  elsif ['base-enclosure-beds-5.xml'].include? hpxml_file
    hpxml.building_construction.number_of_bedrooms = 5
  elsif ['base-foundation-ambient.xml',
         'base-foundation-slab.xml',
         'base-foundation-unconditioned-basement.xml',
         'base-foundation-unvented-crawlspace.xml',
         'base-foundation-vented-crawlspace.xml'].include? hpxml_file
    hpxml.building_construction.number_of_conditioned_floors -= 1
    hpxml.building_construction.conditioned_floor_area -= 1350
    hpxml.building_construction.conditioned_building_volume -= 1350 * 8
  elsif ['base-hvac-ideal-air.xml'].include? hpxml_file
    hpxml.building_construction.use_only_ideal_air_system = true
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.building_construction.number_of_conditioned_floors += 1
    hpxml.building_construction.number_of_conditioned_floors_above_grade += 1
    hpxml.building_construction.conditioned_floor_area += 900
    hpxml.building_construction.conditioned_building_volume += 2250
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    hpxml.building_construction.conditioned_building_volume += 10800
  elsif ['base-enclosure-2stories.xml'].include? hpxml_file
    hpxml.building_construction.number_of_conditioned_floors += 1
    hpxml.building_construction.number_of_conditioned_floors_above_grade += 1
    hpxml.building_construction.conditioned_floor_area += 1350
    hpxml.building_construction.conditioned_building_volume += 1350 * 8
  elsif ['base-enclosure-windows-inoperable.xml'].include? hpxml_file
    hpxml.building_construction.fraction_of_operable_window_area = 0.0
  end
end

def set_hpxml_climate_and_risk_zones(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones = HPXML::ClimateandRiskZones.new({ :iecc2006 => "5B",
                                                                    :weather_station_id => "WeatherStation",
                                                                    :weather_station_name => "Denver, CO",
                                                                    :weather_station_wmo => "725650" })
  elsif ['base-location-baltimore-md.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones = HPXML::ClimateandRiskZones.new({ :iecc2006 => "4A",
                                                                    :weather_station_id => "WeatherStation",
                                                                    :weather_station_name => "Baltimore, MD",
                                                                    :weather_station_wmo => "724060" })
  elsif ['base-location-dallas-tx.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones = HPXML::ClimateandRiskZones.new({ :iecc2006 => "3A",
                                                                    :weather_station_id => "WeatherStation",
                                                                    :weather_station_name => "Dallas, TX",
                                                                    :weather_station_wmo => "722590" })
  elsif ['base-location-duluth-mn.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones = HPXML::ClimateandRiskZones.new({ :iecc2006 => "7",
                                                                    :weather_station_id => "WeatherStation",
                                                                    :weather_station_name => "Duluth, MN",
                                                                    :weather_station_wmo => "727450" })
  elsif ['base-location-miami-fl.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones = HPXML::ClimateandRiskZones.new({ :iecc2006 => "1A",
                                                                    :weather_station_id => "WeatherStation",
                                                                    :weather_station_name => "Miami, FL",
                                                                    :weather_station_wmo => "722020" })
  elsif ['base-location-epw-filename.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones.weather_station_wmo = nil
    hpxml.climate_and_risk_zones.weather_station_epw_filename = "USA_CO_Denver.Intl.AP.725650_TMY3.epw"
  elsif ['invalid_files/bad-wmo.xml'].include? hpxml_file
    hpxml.climate_and_risk_zones.weather_station_wmo = "999999"
  end
end

def set_hpxml_air_infiltration_measurements(hpxml_file, hpxml)
  infil_volume = hpxml.building_construction.conditioned_building_volume
  if ['base.xml'].include? hpxml_file
    hpxml.air_infiltration_measurements = [HPXML::AirInfiltrationMeasurement.new({ :id => "InfiltrationMeasurement",
                                                                                   :house_pressure => 50,
                                                                                   :unit_of_measure => "ACH",
                                                                                   :air_leakage => 3.0 })]
  elsif ['base-infiltration-ach-natural.xml'].include? hpxml_file
    hpxml.air_infiltration_measurements = [HPXML::AirInfiltrationMeasurement.new({ :id => "InfiltrationMeasurement",
                                                                                   :constant_ach_natural => 0.67 })]
  elsif ['base-enclosure-infil-cfm50.xml'].include? hpxml_file
    hpxml.air_infiltration_measurements = [HPXML::AirInfiltrationMeasurement.new({ :id => "InfiltrationMeasurement",
                                                                                   :house_pressure => 50,
                                                                                   :unit_of_measure => "CFM",
                                                                                   :air_leakage => 3.0 / 60.0 * infil_volume })]
  end
  hpxml.air_infiltration_measurements[0].infiltration_volume = infil_volume
end

def set_hpxml_attics(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.attics = []
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    hpxml.attics << HPXML::Attic.new({ :id => "VentedAttic",
                                       :attic_type => "VentedAttic",
                                       :vented_attic_sla => 0.003 })
  end
end

def set_hpxml_foundations(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.foundations = []
  elsif ['base-foundation-vented-crawlspace.xml'].include? hpxml_file
    hpxml.foundations << HPXML::Foundation.new({ :id => "VentedCrawlspace",
                                                 :foundation_type => "VentedCrawlspace",
                                                 :vented_crawlspace_sla => 0.00667 })
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.foundations << HPXML::Foundation.new({ :id => "UnconditionedBasement",
                                                 :foundation_type => "UnconditionedBasement",
                                                 :unconditioned_basement_thermal_boundary => "frame floor" })
  elsif ['base-foundation-unconditioned-basement-wall-insulation.xml'].include? hpxml_file
    hpxml.foundations[0].unconditioned_basement_thermal_boundary = "foundation wall"
  end
end

def set_hpxml_roofs(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.roofs = [HPXML::Roof.new({ :id => "Roof",
                                     :interior_adjacent_to => "attic - unvented",
                                     :area => 1510,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :pitch => 6,
                                     :radiant_barrier => false,
                                     :insulation_assembly_r_value => 2.3 })]
  elsif ['base-atticroof-flat.xml'].include? hpxml_file
    hpxml.roofs = [HPXML::Roof.new({ :id => "Roof",
                                     :interior_adjacent_to => "living space",
                                     :area => 1350,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :pitch => 0,
                                     :radiant_barrier => false,
                                     :insulation_assembly_r_value => 25.8 })]
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.roofs = [HPXML::Roof.new({ :id => "RoofCond",
                                     :interior_adjacent_to => "living space",
                                     :area => 1006,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :pitch => 6,
                                     :radiant_barrier => false,
                                     :insulation_assembly_r_value => 25.8 }),
                   HPXML::Roof.new({ :id => "RoofUncond",
                                     :interior_adjacent_to => "attic - unvented",
                                     :area => 504,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :pitch => 6,
                                     :radiant_barrier => false,
                                     :insulation_assembly_r_value => 2.3 })]
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    hpxml.roofs[0].interior_adjacent_to = "attic - vented"
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    hpxml.roofs[0].interior_adjacent_to = "living space"
    hpxml.roofs[0].insulation_assembly_r_value = 25.8
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    hpxml.roofs << HPXML::Roof.new({ :id => "RoofGarage",
                                     :interior_adjacent_to => "garage",
                                     :area => 670,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :pitch => 6,
                                     :radiant_barrier => false,
                                     :insulation_assembly_r_value => 2.3 })
  elsif ['base-atticroof-unvented-insulated-roof.xml'].include? hpxml_file
    hpxml.roofs[0].insulation_assembly_r_value = 25.8
  elsif ['base-enclosure-adiabatic-surfaces.xml'].include? hpxml_file
    hpxml.roofs = []
  elsif ['base-enclosure-split-surfaces.xml'].include? hpxml_file
    for n in 1..hpxml.roofs.size
      hpxml.roofs[n - 1].area /= 10.0
      for i in 2..10
        hpxml.roofs << hpxml.roofs[n - 1].dup
        hpxml.roofs[-1].id += i.to_s
      end
    end
  elsif ['base-atticroof-radiant-barrier.xml'].include? hpxml_file
    hpxml.roofs[0].radiant_barrier = true
  end
end

def set_hpxml_rim_joists(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    # TODO: Other geometry values (e.g., building volume) assume
    # no rim joists.
    hpxml.rim_joists = [HPXML::RimJoist.new({ :id => "RimJoistFoundation",
                                              :exterior_adjacent_to => "outside",
                                              :interior_adjacent_to => "basement - conditioned",
                                              :area => 116,
                                              :solar_absorptance => 0.7,
                                              :emittance => 0.92,
                                              :insulation_assembly_r_value => 23.0 })]
  elsif ['base-foundation-ambient.xml',
         'base-foundation-slab.xml'].include? hpxml_file
    hpxml.rim_joists = []
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    for i in 0..hpxml.rim_joists.size - 1
      hpxml.rim_joists[i].interior_adjacent_to = "basement - unconditioned"
      hpxml.rim_joists[i].insulation_assembly_r_value = 2.3
    end
  elsif ['base-foundation-unconditioned-basement-wall-insulation.xml'].include? hpxml_file
    for i in 0..hpxml.rim_joists.size - 1
      hpxml.rim_joists[i].insulation_assembly_r_value = 23.0
    end
  elsif ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
    for i in 0..hpxml.rim_joists.size - 1
      hpxml.rim_joists[i].interior_adjacent_to = "crawlspace - unvented"
    end
  elsif ['base-foundation-vented-crawlspace.xml'].include? hpxml_file
    for i in 0..hpxml.rim_joists.size - 1
      hpxml.rim_joists[i].interior_adjacent_to = "crawlspace - vented"
    end
  elsif ['base-foundation-multiple.xml'].include? hpxml_file
    hpxml.rim_joists[0].exterior_adjacent_to = "crawlspace - unvented"
    hpxml.rim_joists << HPXML::RimJoist.new({ :id => "RimJoistCrawlspace",
                                              :exterior_adjacent_to => "outside",
                                              :interior_adjacent_to => "crawlspace - unvented",
                                              :area => 81,
                                              :solar_absorptance => 0.7,
                                              :emittance => 0.92,
                                              :insulation_assembly_r_value => 2.3 })
  elsif ['base-enclosure-2stories.xml'].include? hpxml_file
    hpxml.rim_joists << HPXML::RimJoist.new({ :id => "RimJoist2ndStory",
                                              :exterior_adjacent_to => "outside",
                                              :interior_adjacent_to => "living space",
                                              :area => 116,
                                              :solar_absorptance => 0.7,
                                              :emittance => 0.92,
                                              :insulation_assembly_r_value => 23.0 })
  elsif ['base-enclosure-split-surfaces.xml'].include? hpxml_file
    for n in 1..hpxml.rim_joists.size
      hpxml.rim_joists[n - 1].area /= 10.0
      for i in 2..10
        hpxml.rim_joists << hpxml.rim_joists[n - 1].dup
        hpxml.rim_joists[-1].id += i.to_s
      end
    end
  end
end

def set_hpxml_walls(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.walls = [HPXML::Wall.new({ :id => "Wall",
                                     :exterior_adjacent_to => "outside",
                                     :interior_adjacent_to => "living space",
                                     :wall_type => "WoodStud",
                                     :area => 1200,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :insulation_assembly_r_value => 23 }),
                   HPXML::Wall.new({ :id => "WallAtticGable",
                                     :exterior_adjacent_to => "outside",
                                     :interior_adjacent_to => "attic - unvented",
                                     :wall_type => "WoodStud",
                                     :area => 290,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :insulation_assembly_r_value => 4.0 })]
  elsif ['base-atticroof-flat.xml'].include? hpxml_file
    hpxml.walls.delete_at(1)
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    hpxml.walls[1].interior_adjacent_to = "attic - vented"
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    hpxml.walls[1].interior_adjacent_to = "living space"
    hpxml.walls[1].insulation_assembly_r_value = 23.0
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.walls.delete_at(1)
    hpxml.walls << HPXML::Wall.new({ :id => "WallAtticKneeWall",
                                     :exterior_adjacent_to => "attic - unvented",
                                     :interior_adjacent_to => "living space",
                                     :wall_type => "WoodStud",
                                     :area => 316,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :insulation_assembly_r_value => 23.0 })
    hpxml.walls << HPXML::Wall.new({ :id => "WallAtticGableCond",
                                     :exterior_adjacent_to => "outside",
                                     :interior_adjacent_to => "living space",
                                     :wall_type => "WoodStud",
                                     :area => 240,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :insulation_assembly_r_value => 22.3 })
    hpxml.walls << HPXML::Wall.new({ :id => "WallAtticGableUncond",
                                     :exterior_adjacent_to => "outside",
                                     :interior_adjacent_to => "attic - unvented",
                                     :wall_type => "WoodStud",
                                     :area => 50,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :insulation_assembly_r_value => 4.0 })
  elsif ['base-enclosure-walltype-cmu.xml'].include? hpxml_file
    hpxml.walls[0].wall_type = "ConcreteMasonryUnit"
    hpxml.walls[0].insulation_assembly_r_value = 12
  elsif ['base-enclosure-walltype-doublestud.xml'].include? hpxml_file
    hpxml.walls[0].wall_type = "DoubleWoodStud"
    hpxml.walls[0].insulation_assembly_r_value = 28.7
  elsif ['base-enclosure-walltype-icf.xml'].include? hpxml_file
    hpxml.walls[0].wall_type = "InsulatedConcreteForms"
    hpxml.walls[0].insulation_assembly_r_value = 21
  elsif ['base-enclosure-walltype-log.xml'].include? hpxml_file
    hpxml.walls[0].wall_type = "LogWall"
    hpxml.walls[0].insulation_assembly_r_value = 7.1
  elsif ['base-enclosure-walltype-sip.xml'].include? hpxml_file
    hpxml.walls[0].wall_type = "StructurallyInsulatedPanel"
    hpxml.walls[0].insulation_assembly_r_value = 16.1
  elsif ['base-enclosure-walltype-solidconcrete.xml'].include? hpxml_file
    hpxml.walls[0].wall_type = "SolidConcrete"
    hpxml.walls[0].insulation_assembly_r_value = 1.35
  elsif ['base-enclosure-walltype-steelstud.xml'].include? hpxml_file
    hpxml.walls[0].wall_type = "SteelFrame"
    hpxml.walls[0].insulation_assembly_r_value = 8.1
  elsif ['base-enclosure-walltype-stone.xml'].include? hpxml_file
    hpxml.walls[0].wall_type = "Stone"
    hpxml.walls[0].insulation_assembly_r_value = 5.4
  elsif ['base-enclosure-walltype-strawbale.xml'].include? hpxml_file
    hpxml.walls[0].wall_type = "StrawBale"
    hpxml.walls[0].insulation_assembly_r_value = 58.8
  elsif ['base-enclosure-walltype-structuralbrick.xml'].include? hpxml_file
    hpxml.walls[0].wall_type = "StructuralBrick"
    hpxml.walls[0].insulation_assembly_r_value = 7.9
  elsif ['invalid_files/missing-surfaces.xml'].include? hpxml_file
    hpxml.walls << HPXML::Wall.new({ :id => "WallGarage",
                                     :exterior_adjacent_to => "garage",
                                     :interior_adjacent_to => "living space",
                                     :wall_type => "WoodStud",
                                     :area => 100,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :insulation_assembly_r_value => 4 })
  elsif ['base-enclosure-2stories.xml'].include? hpxml_file
    hpxml.walls[0].area *= 2.0
  elsif ['base-enclosure-2stories-garage.xml'].include? hpxml_file
    hpxml.walls = [HPXML::Wall.new({ :id => "Wall",
                                     :exterior_adjacent_to => "outside",
                                     :interior_adjacent_to => "living space",
                                     :wall_type => "WoodStud",
                                     :area => 880,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :insulation_assembly_r_value => 23 }),
                   HPXML::Wall.new({ :id => "WallGarageInterior",
                                     :exterior_adjacent_to => "garage",
                                     :interior_adjacent_to => "living space",
                                     :wall_type => "WoodStud",
                                     :area => 320,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :insulation_assembly_r_value => 23 }),
                   HPXML::Wall.new({ :id => "WallGarageExterior",
                                     :exterior_adjacent_to => "outside",
                                     :interior_adjacent_to => "garage",
                                     :wall_type => "WoodStud",
                                     :area => 800,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :insulation_assembly_r_value => 4 })]
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    hpxml.walls = [HPXML::Wall.new({ :id => "Wall",
                                     :exterior_adjacent_to => "outside",
                                     :interior_adjacent_to => "living space",
                                     :wall_type => "WoodStud",
                                     :area => 960,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :insulation_assembly_r_value => 23 }),
                   HPXML::Wall.new({ :id => "WallGarageInterior",
                                     :exterior_adjacent_to => "garage",
                                     :interior_adjacent_to => "living space",
                                     :wall_type => "WoodStud",
                                     :area => 240,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :insulation_assembly_r_value => 23 }),
                   HPXML::Wall.new({ :id => "WallGarageExterior",
                                     :exterior_adjacent_to => "outside",
                                     :interior_adjacent_to => "garage",
                                     :wall_type => "WoodStud",
                                     :area => 560,
                                     :solar_absorptance => 0.7,
                                     :emittance => 0.92,
                                     :insulation_assembly_r_value => 4 })]
  elsif ['base-atticroof-unvented-insulated-roof.xml'].include? hpxml_file
    hpxml.walls[1].insulation_assembly_r_value = 23
  elsif ['base-enclosure-adiabatic-surfaces.xml'].include? hpxml_file
    hpxml.walls.delete_at(1)
    hpxml.walls << hpxml.walls[0].dup
    hpxml.walls[0].area *= 0.35
    hpxml.walls[-1].area *= 0.65
    hpxml.walls[-1].id += "Adiabatic"
    hpxml.walls[-1].exterior_adjacent_to = "other housing unit"
    hpxml.walls[-1].insulation_assembly_r_value = 4
  elsif ['base-enclosure-split-surfaces.xml'].include? hpxml_file
    for n in 1..hpxml.walls.size
      hpxml.walls[n - 1].area /= 10.0
      for i in 2..10
        hpxml.walls << hpxml.walls[n - 1].dup
        hpxml.walls[-1].id += i.to_s
      end
    end
  end
end

def set_hpxml_foundation_walls(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.foundation_walls = [HPXML::FoundationWall.new({ :id => "FoundationWall",
                                                          :exterior_adjacent_to => "ground",
                                                          :interior_adjacent_to => "basement - conditioned",
                                                          :height => 8,
                                                          :area => 1200,
                                                          :thickness => 8,
                                                          :depth_below_grade => 7,
                                                          :insulation_interior_r_value => 0,
                                                          :insulation_interior_distance_to_top => 0,
                                                          :insulation_interior_distance_to_bottom => 0,
                                                          :insulation_exterior_distance_to_top => 0,
                                                          :insulation_exterior_distance_to_bottom => 8,
                                                          :insulation_exterior_r_value => 8.9 })]
  elsif ['base-foundation-conditioned-basement-wall-interior-insulation.xml'].include? hpxml_file
    hpxml.foundation_walls[0].insulation_interior_distance_to_top = 0
    hpxml.foundation_walls[0].insulation_interior_distance_to_bottom = 8
    hpxml.foundation_walls[0].insulation_interior_r_value = 10
    hpxml.foundation_walls[0].insulation_exterior_distance_to_top = 1
    hpxml.foundation_walls[0].insulation_exterior_distance_to_bottom = 8
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.foundation_walls[0].interior_adjacent_to = "basement - unconditioned"
    hpxml.foundation_walls[0].insulation_exterior_distance_to_bottom = 0
    hpxml.foundation_walls[0].insulation_exterior_r_value = 0
  elsif ['base-foundation-unconditioned-basement-wall-insulation.xml'].include? hpxml_file
    hpxml.foundation_walls[0].insulation_exterior_distance_to_bottom = 4
    hpxml.foundation_walls[0].insulation_exterior_r_value = 8.9
  elsif ['base-foundation-unconditioned-basement-assembly-r.xml'].include? hpxml_file
    hpxml.foundation_walls[0].insulation_exterior_distance_to_top = nil
    hpxml.foundation_walls[0].insulation_exterior_distance_to_bottom = nil
    hpxml.foundation_walls[0].insulation_exterior_r_value = nil
    hpxml.foundation_walls[0].insulation_interior_distance_to_top = nil
    hpxml.foundation_walls[0].insulation_interior_distance_to_bottom = nil
    hpxml.foundation_walls[0].insulation_interior_r_value = nil
    hpxml.foundation_walls[0].insulation_assembly_r_value = 10.69
  elsif ['base-foundation-unconditioned-basement-above-grade.xml'].include? hpxml_file
    hpxml.foundation_walls[0].depth_below_grade = 4
  elsif ['base-foundation-unvented-crawlspace.xml',
         'base-foundation-vented-crawlspace.xml'].include? hpxml_file
    if ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
      hpxml.foundation_walls[0].interior_adjacent_to = "crawlspace - unvented"
    else
      hpxml.foundation_walls[0].interior_adjacent_to = "crawlspace - vented"
    end
    hpxml.foundation_walls[0].height -= 4
    hpxml.foundation_walls[0].area /= 2.0
    hpxml.foundation_walls[0].depth_below_grade -= 4
    hpxml.foundation_walls[0].insulation_exterior_distance_to_bottom -= 4
  elsif ['base-foundation-multiple.xml'].include? hpxml_file
    hpxml.foundation_walls[0].area = 600
    hpxml.foundation_walls << HPXML::FoundationWall.new({ :id => "FoundationWallInterior",
                                                          :exterior_adjacent_to => "crawlspace - unvented",
                                                          :interior_adjacent_to => "basement - unconditioned",
                                                          :height => 8,
                                                          :area => 360,
                                                          :thickness => 8,
                                                          :depth_below_grade => 4,
                                                          :insulation_interior_r_value => 0,
                                                          :insulation_interior_distance_to_top => 0,
                                                          :insulation_interior_distance_to_bottom => 0,
                                                          :insulation_exterior_distance_to_top => 0,
                                                          :insulation_exterior_distance_to_bottom => 0,
                                                          :insulation_exterior_r_value => 0 })
    hpxml.foundation_walls << HPXML::FoundationWall.new({ :id => "FoundationWallCrawlspace",
                                                          :exterior_adjacent_to => "ground",
                                                          :interior_adjacent_to => "crawlspace - unvented",
                                                          :height => 4,
                                                          :area => 600,
                                                          :thickness => 8,
                                                          :depth_below_grade => 3,
                                                          :insulation_interior_r_value => 0,
                                                          :insulation_interior_distance_to_top => 0,
                                                          :insulation_interior_distance_to_bottom => 0,
                                                          :insulation_exterior_distance_to_top => 0,
                                                          :insulation_exterior_distance_to_bottom => 0,
                                                          :insulation_exterior_r_value => 0 })
  elsif ['base-foundation-ambient.xml',
         'base-foundation-slab.xml'].include? hpxml_file
    hpxml.foundation_walls = []
  elsif ['base-foundation-walkout-basement.xml'].include? hpxml_file
    hpxml.foundation_walls = [HPXML::FoundationWall.new({ :id => "FoundationWall1",
                                                          :exterior_adjacent_to => "ground",
                                                          :interior_adjacent_to => "basement - conditioned",
                                                          :height => 8,
                                                          :area => 480,
                                                          :thickness => 8,
                                                          :depth_below_grade => 7,
                                                          :insulation_interior_r_value => 0,
                                                          :insulation_interior_distance_to_top => 0,
                                                          :insulation_interior_distance_to_bottom => 0,
                                                          :insulation_exterior_distance_to_top => 0,
                                                          :insulation_exterior_distance_to_bottom => 8,
                                                          :insulation_exterior_r_value => 8.9 }),
                              HPXML::FoundationWall.new({ :id => "FoundationWall2",
                                                          :exterior_adjacent_to => "ground",
                                                          :interior_adjacent_to => "basement - conditioned",
                                                          :height => 4,
                                                          :area => 120,
                                                          :thickness => 8,
                                                          :depth_below_grade => 3,
                                                          :insulation_interior_r_value => 0,
                                                          :insulation_interior_distance_to_top => 0,
                                                          :insulation_interior_distance_to_bottom => 0,
                                                          :insulation_exterior_distance_to_top => 0,
                                                          :insulation_exterior_distance_to_bottom => 4,
                                                          :insulation_exterior_r_value => 8.9 }),
                              HPXML::FoundationWall.new({ :id => "FoundationWall3",
                                                          :exterior_adjacent_to => "ground",
                                                          :interior_adjacent_to => "basement - conditioned",
                                                          :height => 2,
                                                          :area => 60,
                                                          :thickness => 8,
                                                          :depth_below_grade => 1,
                                                          :insulation_interior_r_value => 0,
                                                          :insulation_interior_distance_to_top => 0,
                                                          :insulation_interior_distance_to_bottom => 0,
                                                          :insulation_exterior_distance_to_top => 0,
                                                          :insulation_exterior_distance_to_bottom => 2,
                                                          :insulation_exterior_r_value => 8.9 })]
  elsif ['base-foundation-complex.xml'].include? hpxml_file
    hpxml.foundation_walls = [HPXML::FoundationWall.new({ :id => "FoundationWall1",
                                                          :exterior_adjacent_to => "ground",
                                                          :interior_adjacent_to => "basement - conditioned",
                                                          :height => 8,
                                                          :area => 160,
                                                          :thickness => 8,
                                                          :depth_below_grade => 7,
                                                          :insulation_interior_r_value => 0,
                                                          :insulation_interior_distance_to_top => 0,
                                                          :insulation_interior_distance_to_bottom => 0,
                                                          :insulation_exterior_distance_to_top => 0,
                                                          :insulation_exterior_distance_to_bottom => 0,
                                                          :insulation_exterior_r_value => 0.0 }),
                              HPXML::FoundationWall.new({ :id => "FoundationWall2",
                                                          :exterior_adjacent_to => "ground",
                                                          :interior_adjacent_to => "basement - conditioned",
                                                          :height => 8,
                                                          :area => 240,
                                                          :thickness => 8,
                                                          :depth_below_grade => 7,
                                                          :insulation_interior_r_value => 0,
                                                          :insulation_interior_distance_to_top => 0,
                                                          :insulation_interior_distance_to_bottom => 0,
                                                          :insulation_exterior_distance_to_top => 0,
                                                          :insulation_exterior_distance_to_bottom => 8,
                                                          :insulation_exterior_r_value => 8.9 }),
                              HPXML::FoundationWall.new({ :id => "FoundationWall3",
                                                          :exterior_adjacent_to => "ground",
                                                          :interior_adjacent_to => "basement - conditioned",
                                                          :height => 4,
                                                          :area => 160,
                                                          :thickness => 8,
                                                          :depth_below_grade => 3,
                                                          :insulation_interior_r_value => 0,
                                                          :insulation_interior_distance_to_top => 0,
                                                          :insulation_interior_distance_to_bottom => 0,
                                                          :insulation_exterior_distance_to_top => 0,
                                                          :insulation_exterior_distance_to_bottom => 0,
                                                          :insulation_exterior_r_value => 0.0 }),
                              HPXML::FoundationWall.new({ :id => "FoundationWall4",
                                                          :exterior_adjacent_to => "ground",
                                                          :interior_adjacent_to => "basement - conditioned",
                                                          :height => 4,
                                                          :area => 120,
                                                          :thickness => 8,
                                                          :depth_below_grade => 3,
                                                          :insulation_interior_r_value => 0,
                                                          :insulation_interior_distance_to_top => 0,
                                                          :insulation_interior_distance_to_bottom => 0,
                                                          :insulation_exterior_distance_to_top => 0,
                                                          :insulation_exterior_distance_to_bottom => 4,
                                                          :insulation_exterior_r_value => 8.9 }),
                              HPXML::FoundationWall.new({ :id => "FoundationWall5",
                                                          :exterior_adjacent_to => "ground",
                                                          :interior_adjacent_to => "basement - conditioned",
                                                          :height => 4,
                                                          :area => 80,
                                                          :thickness => 8,
                                                          :depth_below_grade => 3,
                                                          :insulation_interior_r_value => 0,
                                                          :insulation_interior_distance_to_top => 0,
                                                          :insulation_interior_distance_to_bottom => 0,
                                                          :insulation_exterior_distance_to_top => 0,
                                                          :insulation_exterior_distance_to_bottom => 4,
                                                          :insulation_exterior_r_value => 8.9 })]
  elsif ['base-enclosure-split-surfaces.xml'].include? hpxml_file
    for n in 1..hpxml.foundation_walls.size
      hpxml.foundation_walls[n - 1].area /= 10.0
      for i in 2..10
        hpxml.foundation_walls << hpxml.foundation_walls[n - 1].dup
        hpxml.foundation_walls[-1].id += i.to_s
      end
    end
  elsif ['invalid_files/mismatched-slab-and-foundation-wall.xml'].include? hpxml_file
    hpxml.foundation_walls << hpxml.foundation_walls[0].dup
    hpxml.foundation_walls[1].id = "FoundationWall2"
    hpxml.foundation_walls[1].interior_adjacent_to = "garage"
  end
end

def set_hpxml_frame_floors(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.frame_floors = [HPXML::FrameFloor.new({ :id => "FloorBelowAttic",
                                                  :exterior_adjacent_to => "attic - unvented",
                                                  :interior_adjacent_to => "living space",
                                                  :area => 1350,
                                                  :insulation_assembly_r_value => 39.3 })]
  elsif ['base-atticroof-flat.xml',
         'base-atticroof-cathedral.xml'].include? hpxml_file
    hpxml.frame_floors.delete_at(0)
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    hpxml.frame_floors[0].exterior_adjacent_to = "attic - vented"
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.frame_floors[0].area = 450
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    hpxml.frame_floors << HPXML::FrameFloor.new({ :id => "FloorBetweenAtticGarage",
                                                  :exterior_adjacent_to => "attic - unvented",
                                                  :interior_adjacent_to => "garage",
                                                  :area => 600,
                                                  :insulation_assembly_r_value => 2.1 })
  elsif ['base-foundation-ambient.xml'].include? hpxml_file
    hpxml.frame_floors << HPXML::FrameFloor.new({ :id => "FloorAboveAmbient",
                                                  :exterior_adjacent_to => "outside",
                                                  :interior_adjacent_to => "living space",
                                                  :area => 1350,
                                                  :insulation_assembly_r_value => 18.7 })
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.frame_floors << HPXML::FrameFloor.new({ :id => "FloorAboveUncondBasement",
                                                  :exterior_adjacent_to => "basement - unconditioned",
                                                  :interior_adjacent_to => "living space",
                                                  :area => 1350,
                                                  :insulation_assembly_r_value => 18.7 })
  elsif ['base-foundation-unconditioned-basement-wall-insulation.xml'].include? hpxml_file
    hpxml.frame_floors[1].insulation_assembly_r_value = 2.1
  elsif ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
    hpxml.frame_floors << HPXML::FrameFloor.new({ :id => "FloorAboveUnventedCrawl",
                                                  :exterior_adjacent_to => "crawlspace - unvented",
                                                  :interior_adjacent_to => "living space",
                                                  :area => 1350,
                                                  :insulation_assembly_r_value => 18.7 })
  elsif ['base-foundation-vented-crawlspace.xml'].include? hpxml_file
    hpxml.frame_floors << HPXML::FrameFloor.new({ :id => "FloorAboveVentedCrawl",
                                                  :exterior_adjacent_to => "crawlspace - vented",
                                                  :interior_adjacent_to => "living space",
                                                  :area => 1350,
                                                  :insulation_assembly_r_value => 18.7 })
  elsif ['base-foundation-multiple.xml'].include? hpxml_file
    hpxml.frame_floors[1].area = 675
    hpxml.frame_floors << HPXML::FrameFloor.new({ :id => "FloorAboveUnventedCrawlspace",
                                                  :exterior_adjacent_to => "crawlspace - unvented",
                                                  :interior_adjacent_to => "living space",
                                                  :area => 675,
                                                  :insulation_assembly_r_value => 18.7 })
  elsif ['base-enclosure-2stories-garage.xml'].include? hpxml_file
    hpxml.frame_floors << HPXML::FrameFloor.new({ :id => "FloorAboveGarage",
                                                  :exterior_adjacent_to => "garage",
                                                  :interior_adjacent_to => "living space",
                                                  :area => 400,
                                                  :insulation_assembly_r_value => 18.7 })
  elsif ['base-atticroof-unvented-insulated-roof.xml'].include? hpxml_file
    hpxml.frame_floors[0].insulation_assembly_r_value = 2.1
  elsif ['base-enclosure-adiabatic-surfaces.xml'].include? hpxml_file
    hpxml.frame_floors = [HPXML::FrameFloor.new({ :id => "FloorAboveAdiabatic",
                                                  :exterior_adjacent_to => "other housing unit below",
                                                  :interior_adjacent_to => "living space",
                                                  :area => 1350,
                                                  :insulation_assembly_r_value => 2.1 }),
                          HPXML::FrameFloor.new({ :id => "FloorBelowAdiabatic",
                                                  :exterior_adjacent_to => "other housing unit above",
                                                  :interior_adjacent_to => "living space",
                                                  :area => 1350,
                                                  :insulation_assembly_r_value => 2.1 })]
  elsif ['base-enclosure-split-surfaces.xml'].include? hpxml_file
    for n in 1..hpxml.frame_floors.size
      hpxml.frame_floors[n - 1].area /= 10.0
      for i in 2..10
        hpxml.frame_floors << hpxml.frame_floors[n - 1].dup
        hpxml.frame_floors[-1].id += i.to_s
      end
    end
  end
end

def set_hpxml_slabs(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.slabs = [HPXML::Slab.new({ :id => "Slab",
                                     :interior_adjacent_to => "basement - conditioned",
                                     :area => 1350,
                                     :thickness => 4,
                                     :exposed_perimeter => 150,
                                     :perimeter_insulation_depth => 0,
                                     :under_slab_insulation_width => 0,
                                     :perimeter_insulation_r_value => 0,
                                     :under_slab_insulation_r_value => 0,
                                     :carpet_fraction => 0,
                                     :carpet_r_value => 0 })]
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.slabs[0].interior_adjacent_to = "basement - unconditioned"
  elsif ['base-foundation-conditioned-basement-slab-insulation.xml'].include? hpxml_file
    hpxml.slabs[0].under_slab_insulation_width = 4
    hpxml.slabs[0].under_slab_insulation_r_value = 10
  elsif ['base-foundation-slab.xml'].include? hpxml_file
    hpxml.slabs[0].interior_adjacent_to = "living space"
    hpxml.slabs[0].under_slab_insulation_width = nil
    hpxml.slabs[0].under_slab_insulation_spans_entire_slab = true
    hpxml.slabs[0].depth_below_grade = 0
    hpxml.slabs[0].under_slab_insulation_r_value = 5
    hpxml.slabs[0].carpet_fraction = 1
    hpxml.slabs[0].carpet_r_value = 2.5
  elsif ['base-foundation-unvented-crawlspace.xml',
         'base-foundation-vented-crawlspace.xml'].include? hpxml_file
    if ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
      hpxml.slabs[0].interior_adjacent_to = "crawlspace - unvented"
    else
      hpxml.slabs[0].interior_adjacent_to = "crawlspace - vented"
    end
    hpxml.slabs[0].thickness = 0
    hpxml.slabs[0].carpet_r_value = 2.5
  elsif ['base-foundation-multiple.xml'].include? hpxml_file
    hpxml.slabs[0].area = 675
    hpxml.slabs[0].exposed_perimeter = 75
    hpxml.slabs << HPXML::Slab.new({ :id => "SlabUnderCrawlspace",
                                     :interior_adjacent_to => "crawlspace - unvented",
                                     :area => 675,
                                     :thickness => 0,
                                     :exposed_perimeter => 75,
                                     :perimeter_insulation_depth => 0,
                                     :under_slab_insulation_width => 0,
                                     :perimeter_insulation_r_value => 0,
                                     :under_slab_insulation_r_value => 0,
                                     :carpet_fraction => 0,
                                     :carpet_r_value => 0 })
  elsif ['base-foundation-ambient.xml'].include? hpxml_file
    hpxml.slabs = []
  elsif ['base-enclosure-2stories-garage.xml'].include? hpxml_file
    hpxml.slabs[0].area -= 400
    hpxml.slabs[0].exposed_perimeter -= 40
    hpxml.slabs << HPXML::Slab.new({ :id => "SlabUnderGarage",
                                     :interior_adjacent_to => "garage",
                                     :area => 400,
                                     :thickness => 4,
                                     :exposed_perimeter => 40,
                                     :perimeter_insulation_depth => 0,
                                     :under_slab_insulation_width => 0,
                                     :depth_below_grade => 0,
                                     :perimeter_insulation_r_value => 0,
                                     :under_slab_insulation_r_value => 0,
                                     :carpet_fraction => 0,
                                     :carpet_r_value => 0 })
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    hpxml.slabs[0].exposed_perimeter -= 30
    hpxml.slabs << HPXML::Slab.new({ :id => "SlabUnderGarage",
                                     :interior_adjacent_to => "garage",
                                     :area => 600,
                                     :thickness => 4,
                                     :exposed_perimeter => 70,
                                     :perimeter_insulation_depth => 0,
                                     :under_slab_insulation_width => 0,
                                     :depth_below_grade => 0,
                                     :perimeter_insulation_r_value => 0,
                                     :under_slab_insulation_r_value => 0,
                                     :carpet_fraction => 0,
                                     :carpet_r_value => 0 })
  elsif ['base-foundation-complex.xml'].include? hpxml_file
    hpxml.slabs = [HPXML::Slab.new({ :id => "Slab1",
                                     :interior_adjacent_to => "basement - conditioned",
                                     :area => 675,
                                     :thickness => 4,
                                     :exposed_perimeter => 75,
                                     :perimeter_insulation_depth => 0,
                                     :under_slab_insulation_width => 0,
                                     :perimeter_insulation_r_value => 0,
                                     :under_slab_insulation_r_value => 0,
                                     :carpet_fraction => 0,
                                     :carpet_r_value => 0 }),
                   HPXML::Slab.new({ :id => "Slab2",
                                     :interior_adjacent_to => "basement - conditioned",
                                     :area => 405,
                                     :thickness => 4,
                                     :exposed_perimeter => 45,
                                     :perimeter_insulation_depth => 1,
                                     :under_slab_insulation_width => 0,
                                     :perimeter_insulation_r_value => 5,
                                     :under_slab_insulation_r_value => 0,
                                     :carpet_fraction => 0,
                                     :carpet_r_value => 0 }),
                   HPXML::Slab.new({ :id => "Slab3",
                                     :interior_adjacent_to => "basement - conditioned",
                                     :area => 270,
                                     :thickness => 4,
                                     :exposed_perimeter => 30,
                                     :perimeter_insulation_depth => 1,
                                     :under_slab_insulation_width => 0,
                                     :perimeter_insulation_r_value => 5,
                                     :under_slab_insulation_r_value => 0,
                                     :carpet_fraction => 0,
                                     :carpet_r_value => 0 })]
  elsif ['base-enclosure-split-surfaces.xml'].include? hpxml_file
    for n in 1..hpxml.slabs.size
      hpxml.slabs[n - 1].area /= 10.0
      hpxml.slabs[n - 1].exposed_perimeter /= 10.0
      for i in 2..10
        hpxml.slabs << hpxml.slabs[n - 1].dup
        hpxml.slabs[-1].id += i.to_s
      end
    end
  elsif ['invalid_files/mismatched-slab-and-foundation-wall.xml'].include? hpxml_file
    hpxml.slabs[0].interior_adjacent_to = "basement - unconditioned"
    hpxml.slabs[0].depth_below_grade = 7.0
  elsif ['invalid_files/slab-zero-exposed-perimeter.xml'].include? hpxml_file
    hpxml.slabs[0].exposed_perimeter = 0
  end
end

def set_hpxml_windows(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.windows = [HPXML::Window.new({ :id => "WindowNorth",
                                         :area => 108,
                                         :azimuth => 0,
                                         :ufactor => 0.33,
                                         :shgc => 0.45,
                                         :wall_idref => "Wall" }),
                     HPXML::Window.new({ :id => "WindowSouth",
                                         :area => 108,
                                         :azimuth => 180,
                                         :ufactor => 0.33,
                                         :shgc => 0.45,
                                         :wall_idref => "Wall" }),
                     HPXML::Window.new({ :id => "WindowEast",
                                         :area => 72,
                                         :azimuth => 90,
                                         :ufactor => 0.33,
                                         :shgc => 0.45,
                                         :wall_idref => "Wall" }),
                     HPXML::Window.new({ :id => "WindowWest",
                                         :area => 72,
                                         :azimuth => 270,
                                         :ufactor => 0.33,
                                         :shgc => 0.45,
                                         :wall_idref => "Wall" })]
  elsif ['base-enclosure-overhangs.xml'].include? hpxml_file
    hpxml.windows[0].overhangs_depth = 2.5
    hpxml.windows[0].overhangs_distance_to_top_of_window = 0
    hpxml.windows[0].overhangs_distance_to_bottom_of_window = 4
    hpxml.windows[2].overhangs_depth = 1.5
    hpxml.windows[2].overhangs_distance_to_top_of_window = 2
    hpxml.windows[2].overhangs_distance_to_bottom_of_window = 6
    hpxml.windows[3].overhangs_depth = 1.5
    hpxml.windows[3].overhangs_distance_to_top_of_window = 2
    hpxml.windows[3].overhangs_distance_to_bottom_of_window = 7
  elsif ['base-enclosure-windows-interior-shading.xml'].include? hpxml_file
    hpxml.windows[0].interior_shading_factor_summer = 0.7
    hpxml.windows[0].interior_shading_factor_winter = 0.85
    hpxml.windows[1].interior_shading_factor_summer = 0.01
    hpxml.windows[1].interior_shading_factor_winter = 0.99
    hpxml.windows[2].interior_shading_factor_summer = 0.0
    hpxml.windows[2].interior_shading_factor_winter = 0.5
    hpxml.windows[3].interior_shading_factor_summer = 1.0
    hpxml.windows[3].interior_shading_factor_winter = 1.0
  elsif ['invalid_files/invalid-window-interior-shading.xml'].include? hpxml_file
    hpxml.windows[0].interior_shading_factor_summer = 0.85
    hpxml.windows[0].interior_shading_factor_winter = 0.7
  elsif ['base-enclosure-windows-none.xml'].include? hpxml_file
    hpxml.windows = []
  elsif ['invalid_files/net-area-negative-wall.xml'].include? hpxml_file
    hpxml.windows[0].area = 1000
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.windows[0].area = 108
    hpxml.windows[1].area = 108
    hpxml.windows[2].area = 108
    hpxml.windows[3].area = 108
    hpxml.windows << HPXML::Window.new({ :id => "AtticGableWindowEast",
                                         :area => 12,
                                         :azimuth => 90,
                                         :ufactor => 0.33,
                                         :shgc => 0.45,
                                         :wall_idref => "WallAtticGableCond" })
    hpxml.windows << HPXML::Window.new({ :id => "AtticGableWindowWest",
                                         :area => 62,
                                         :azimuth => 270,
                                         :ufactor => 0.3,
                                         :shgc => 0.45,
                                         :wall_idref => "WallAtticGableCond" })
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    hpxml.windows[0].area = 108
    hpxml.windows[1].area = 108
    hpxml.windows[2].area = 108
    hpxml.windows[3].area = 108
    hpxml.windows << HPXML::Window.new({ :id => "AtticGableWindowEast",
                                         :area => 12,
                                         :azimuth => 90,
                                         :ufactor => 0.33,
                                         :shgc => 0.45,
                                         :wall_idref => "WallAtticGable" })
    hpxml.windows << HPXML::Window.new({ :id => "AtticGableWindowWest",
                                         :area => 12,
                                         :azimuth => 270,
                                         :ufactor => 0.33,
                                         :shgc => 0.45,
                                         :wall_idref => "WallAtticGable" })
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    hpxml.windows.delete_at(2)
    hpxml.windows << HPXML::Window.new({ :id => "GarageWindowEast",
                                         :area => 12,
                                         :azimuth => 90,
                                         :ufactor => 0.33,
                                         :shgc => 0.45,
                                         :wall_idref => "WallGarageExterior" })
  elsif ['base-enclosure-2stories.xml'].include? hpxml_file
    hpxml.windows[0].area = 216
    hpxml.windows[1].area = 216
    hpxml.windows[2].area = 144
    hpxml.windows[3].area = 144
  elsif ['base-enclosure-2stories-garage'].include? hpxml_file
    hpxml.windows[0].area = 168
    hpxml.windows[1].area = 216
    hpxml.windows[2].area = 144
    hpxml.windows[3].area = 96
  elsif ['base-foundation-unconditioned-basement-above-grade.xml'].include? hpxml_file
    hpxml.windows << HPXML::Window.new({ :id => "FoundationWindowNorth",
                                         :area => 20,
                                         :azimuth => 0,
                                         :ufactor => 0.33,
                                         :shgc => 0.45,
                                         :wall_idref => "FoundationWall" })
    hpxml.windows << HPXML::Window.new({ :id => "FoundationWindowSouth",
                                         :area => 20,
                                         :azimuth => 180,
                                         :ufactor => 0.33,
                                         :shgc => 0.45,
                                         :wall_idref => "FoundationWall" })
    hpxml.windows << HPXML::Window.new({ :id => "FoundationWindowEast",
                                         :area => 10,
                                         :azimuth => 90,
                                         :ufactor => 0.33,
                                         :shgc => 0.45,
                                         :wall_idref => "FoundationWall" })
    hpxml.windows << HPXML::Window.new({ :id => "FoundationWindowWest",
                                         :area => 10,
                                         :azimuth => 270,
                                         :ufactor => 0.33,
                                         :shgc => 0.45,
                                         :wall_idref => "FoundationWall" })
  elsif ['base-enclosure-adiabatic-surfaces.xml'].include? hpxml_file
    for n in 1..hpxml.windows.size
      hpxml.windows[n - 1].area *= 0.35
    end
  elsif ['invalid_files/unattached-window.xml'].include? hpxml_file
    hpxml.windows[0].wall_idref = "foobar"
  elsif ['base-enclosure-split-surfaces.xml'].include? hpxml_file
    area_adjustments = []
    for n in 1..hpxml.windows.size
      hpxml.windows[n - 1].area /= 10.0
      for i in 2..10
        hpxml.windows << hpxml.windows[n - 1].dup
        hpxml.windows[-1].id += i.to_s
        hpxml.windows[-1].wall_idref += i.to_s
      end
    end
  elsif ['base-foundation-walkout-basement.xml'].include? hpxml_file
    hpxml.windows << HPXML::Window.new({ :id => "FoundationWindow",
                                         :area => 20,
                                         :azimuth => 0,
                                         :ufactor => 0.33,
                                         :shgc => 0.45,
                                         :wall_idref => "FoundationWall3" })
  elsif ['invalid_files/invalid-window-height.xml'].include? hpxml_file
    hpxml.windows[2].overhangs_distance_to_bottom_of_window = hpxml.windows[2].overhangs_distance_to_top_of_window
  end
end

def set_hpxml_skylights(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.skylights = []
  elsif ['base-enclosure-skylights.xml'].include? hpxml_file
    hpxml.skylights << HPXML::Skylight.new({ :id => "SkylightNorth",
                                             :area => 45,
                                             :azimuth => 0,
                                             :ufactor => 0.33,
                                             :shgc => 0.45,
                                             :roof_idref => "Roof" })
    hpxml.skylights << HPXML::Skylight.new({ :id => "SkylightSouth",
                                             :area => 45,
                                             :azimuth => 180,
                                             :ufactor => 0.35,
                                             :shgc => 0.47,
                                             :roof_idref => "Roof" })
  elsif ['invalid_files/net-area-negative-roof.xml'].include? hpxml_file
    hpxml.skylights[0].area = 4000
  elsif ['invalid_files/unattached-skylight.xml'].include? hpxml_file
    hpxml.skylights[0].roof_idref = "foobar"
  elsif ['base-enclosure-split-surfaces.xml'].include? hpxml_file
    for n in 1..hpxml.skylights.size
      hpxml.skylights[n - 1].area /= 10.0
      for i in 2..10
        hpxml.skylights << hpxml.skylights[n - 1].dup
        hpxml.skylights[-1].id += i.to_s
        hpxml.skylights[-1].roof_idref += i.to_s if i % 2 == 0
      end
    end
  end
end

def set_hpxml_doors(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.doors = [HPXML::Door.new({ :id => "DoorNorth",
                                     :wall_idref => "Wall",
                                     :area => 40,
                                     :azimuth => 0,
                                     :r_value => 4.4 }),
                   HPXML::Door.new({ :id => "DoorSouth",
                                     :wall_idref => "Wall",
                                     :area => 40,
                                     :azimuth => 180,
                                     :r_value => 4.4 })]
  elsif ['base-enclosure-garage.xml',
         'base-enclosure-2stories-garage.xml'].include? hpxml_file
    hpxml.doors << HPXML::Door.new({ :id => "GarageDoorSouth",
                                     :wall_idref => "WallGarageExterior",
                                     :area => 70,
                                     :azimuth => 180,
                                     :r_value => 4.4 })
  elsif ['invalid_files/unattached-door.xml'].include? hpxml_file
    hpxml.doors[0].wall_idref = "foobar"
  elsif ['base-enclosure-split-surfaces.xml'].include? hpxml_file
    area_adjustments = []
    for n in 1..hpxml.doors.size
      hpxml.doors[n - 1].area /= 10.0
      for i in 2..10
        hpxml.doors << hpxml.doors[n - 1].dup
        hpxml.doors[-1].id += i.to_s
        hpxml.doors[-1].wall_idref += i.to_s
      end
    end
  end
end

def set_hpxml_heating_systems(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.heating_systems = [HPXML::HeatingSystem.new({ :id => "HeatingSystem",
                                                        :distribution_system_idref => "HVACDistribution",
                                                        :heating_system_type => "Furnace",
                                                        :heating_system_fuel => "natural gas",
                                                        :heating_capacity => 64000,
                                                        :heating_efficiency_afue => 0.92,
                                                        :fraction_heat_load_served => 1 })]
  elsif ['base-hvac-air-to-air-heat-pump-1-speed.xml',
         'base-hvac-air-to-air-heat-pump-2-speed.xml',
         'base-hvac-air-to-air-heat-pump-var-speed.xml',
         'base-hvac-central-ac-only-1-speed.xml',
         'base-hvac-central-ac-only-2-speed.xml',
         'base-hvac-central-ac-only-var-speed.xml',
         'base-hvac-evap-cooler-only.xml',
         'base-hvac-evap-cooler-only-ducted.xml',
         'base-hvac-ground-to-air-heat-pump.xml',
         'base-hvac-mini-split-heat-pump-ducted.xml',
         'base-hvac-mini-split-heat-pump-ductless-no-backup.xml',
         'base-hvac-ideal-air.xml',
         'base-hvac-none.xml',
         'base-hvac-room-ac-only.xml',
         'invalid_files/orphaned-hvac-distribution.xml'].include? hpxml_file
    hpxml.heating_systems = []
  elsif ['base-hvac-boiler-elec-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_type = "Boiler"
    hpxml.heating_systems[0].heating_system_fuel = "electricity"
    hpxml.heating_systems[0].heating_efficiency_afue = 1
  elsif ['base-hvac-boiler-gas-central-ac-1-speed.xml',
         'base-hvac-boiler-gas-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_type = "Boiler"
    hpxml.heating_systems[0].electric_auxiliary_energy = 200
  elsif ['base-hvac-boiler-oil-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_type = "Boiler"
    hpxml.heating_systems[0].heating_system_fuel = "fuel oil"
  elsif ['base-hvac-boiler-propane-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_type = "Boiler"
    hpxml.heating_systems[0].heating_system_fuel = "propane"
  elsif ['base-hvac-boiler-wood-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_type = "Boiler"
    hpxml.heating_systems[0].heating_system_fuel = "wood"
  elsif ['base-hvac-elec-resistance-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = nil
    hpxml.heating_systems[0].heating_system_type = "ElectricResistance"
    hpxml.heating_systems[0].heating_system_fuel = "electricity"
    hpxml.heating_systems[0].heating_efficiency_afue = nil
    hpxml.heating_systems[0].heating_efficiency_percent = 1
  elsif ['base-hvac-furnace-elec-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_fuel = "electricity"
    hpxml.heating_systems[0].heating_efficiency_afue = 1
  elsif ['base-hvac-furnace-gas-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].electric_auxiliary_energy = 700
  elsif ['base-hvac-furnace-gas-only-no-eae.xml',
         'base-hvac-boiler-gas-only-no-eae.xml',
         'base-hvac-stove-oil-only-no-eae.xml',
         'base-hvac-wall-furnace-propane-only-no-eae.xml'].include? hpxml_file
    hpxml.heating_systems[0].electric_auxiliary_energy = nil
  elsif ['base-hvac-furnace-oil-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_fuel = "fuel oil"
  elsif ['base-hvac-furnace-propane-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_fuel = "propane"
  elsif ['base-hvac-furnace-wood-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_fuel = "wood"
  elsif ['base-hvac-multiple.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_system_type = "Boiler"
    hpxml.heating_systems[0].heating_system_fuel = "electricity"
    hpxml.heating_systems[0].heating_efficiency_afue = 1
    hpxml.heating_systems[0].fraction_heat_load_served = 0.1
    hpxml.heating_systems[0].heating_capacity *= 0.1
    hpxml.heating_systems << HPXML::HeatingSystem.new({ :id => "HeatingSystem2",
                                                        :distribution_system_idref => "HVACDistribution2",
                                                        :heating_system_type => "Boiler",
                                                        :heating_system_fuel => "natural gas",
                                                        :heating_capacity => 6400,
                                                        :heating_efficiency_afue => 0.92,
                                                        :fraction_heat_load_served => 0.1,
                                                        :electric_auxiliary_energy => 200 })
    hpxml.heating_systems << HPXML::HeatingSystem.new({ :id => "HeatingSystem3",
                                                        :heating_system_type => "ElectricResistance",
                                                        :heating_system_fuel => "electricity",
                                                        :heating_capacity => 6400,
                                                        :heating_efficiency_percent => 1,
                                                        :fraction_heat_load_served => 0.1 })
    hpxml.heating_systems << HPXML::HeatingSystem.new({ :id => "HeatingSystem4",
                                                        :distribution_system_idref => "HVACDistribution3",
                                                        :heating_system_type => "Furnace",
                                                        :heating_system_fuel => "electricity",
                                                        :heating_capacity => 6400,
                                                        :heating_efficiency_afue => 1,
                                                        :fraction_heat_load_served => 0.1 })
    hpxml.heating_systems << HPXML::HeatingSystem.new({ :id => "HeatingSystem5",
                                                        :distribution_system_idref => "HVACDistribution4",
                                                        :heating_system_type => "Furnace",
                                                        :heating_system_fuel => "natural gas",
                                                        :heating_capacity => 6400,
                                                        :heating_efficiency_afue => 0.92,
                                                        :fraction_heat_load_served => 0.1,
                                                        :electric_auxiliary_energy => 700 })
    hpxml.heating_systems << HPXML::HeatingSystem.new({ :id => "HeatingSystem6",
                                                        :heating_system_type => "Stove",
                                                        :heating_system_fuel => "fuel oil",
                                                        :heating_capacity => 6400,
                                                        :heating_efficiency_percent => 0.8,
                                                        :fraction_heat_load_served => 0.1,
                                                        :electric_auxiliary_energy => 200 })
    hpxml.heating_systems << HPXML::HeatingSystem.new({ :id => "HeatingSystem7",
                                                        :heating_system_type => "WallFurnace",
                                                        :heating_system_fuel => "propane",
                                                        :heating_capacity => 6400,
                                                        :heating_efficiency_afue => 0.8,
                                                        :fraction_heat_load_served => 0.1,
                                                        :electric_auxiliary_energy => 200 })
  elsif ['invalid_files/hvac-frac-load-served.xml'].include? hpxml_file
    hpxml.heating_systems[0].fraction_heat_load_served += 0.1
  elsif ['base-hvac-portable-heater-electric-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = nil
    hpxml.heating_systems[0].heating_system_type = "PortableHeater"
    hpxml.heating_systems[0].heating_system_fuel = "electricity"
    hpxml.heating_systems[0].heating_efficiency_afue = nil
    hpxml.heating_systems[0].heating_efficiency_percent = 1.0
  elsif ['base-hvac-stove-oil-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = nil
    hpxml.heating_systems[0].heating_system_type = "Stove"
    hpxml.heating_systems[0].heating_system_fuel = "fuel oil"
    hpxml.heating_systems[0].heating_efficiency_afue = nil
    hpxml.heating_systems[0].heating_efficiency_percent = 0.8
    hpxml.heating_systems[0].electric_auxiliary_energy = 200
  elsif ['base-hvac-stove-wood-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = nil
    hpxml.heating_systems[0].heating_system_type = "Stove"
    hpxml.heating_systems[0].heating_system_fuel = "wood"
    hpxml.heating_systems[0].heating_efficiency_afue = nil
    hpxml.heating_systems[0].heating_efficiency_percent = 0.8
    hpxml.heating_systems[0].electric_auxiliary_energy = 200
  elsif ['base-hvac-wall-furnace-elec-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = nil
    hpxml.heating_systems[0].heating_system_type = "WallFurnace"
    hpxml.heating_systems[0].heating_system_fuel = "electricity"
    hpxml.heating_systems[0].heating_efficiency_afue = 1.0
    hpxml.heating_systems[0].electric_auxiliary_energy = 200
  elsif ['base-hvac-wall-furnace-propane-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = nil
    hpxml.heating_systems[0].heating_system_type = "WallFurnace"
    hpxml.heating_systems[0].heating_system_fuel = "propane"
    hpxml.heating_systems[0].heating_efficiency_afue = 0.8
    hpxml.heating_systems[0].electric_auxiliary_energy = 200
  elsif ['base-hvac-wall-furnace-wood-only.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = nil
    hpxml.heating_systems[0].heating_system_type = "WallFurnace"
    hpxml.heating_systems[0].heating_system_fuel = "wood"
    hpxml.heating_systems[0].heating_efficiency_afue = 0.8
    hpxml.heating_systems[0].electric_auxiliary_energy = 200
  elsif ['base-hvac-furnace-x3-dse.xml'].include? hpxml_file
    hpxml.heating_systems << hpxml.heating_systems[0].dup
    hpxml.heating_systems << hpxml.heating_systems[1].dup
    hpxml.heating_systems[1].id = "HeatingSystem2"
    hpxml.heating_systems[1].distribution_system_idref = "HVACDistribution2"
    hpxml.heating_systems[2].id = "HeatingSystem3"
    hpxml.heating_systems[2].distribution_system_idref = "HVACDistribution3"
    for i in 0..2
      hpxml.heating_systems[i].heating_capacity /= 3.0
      hpxml.heating_systems[i].fraction_heat_load_served = 0.333
    end
  elsif ['invalid_files/unattached-hvac-distribution.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = "foobar"
  elsif ['invalid_files/hvac-invalid-distribution-system-type.xml'].include? hpxml_file
    hpxml.heating_systems[0].distribution_system_idref = "HVACDistribution2"
  elsif ['invalid_files/hvac-dse-multiple-attached-heating.xml'].include? hpxml_file
    hpxml.heating_systems[0].fraction_heat_load_served = 0.5
    hpxml.heating_systems << hpxml.heating_systems[0].dup
    hpxml.heating_systems[1].id += "2"
  elsif ['base-hvac-undersized.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_capacity /= 10.0
  elsif ['base-hvac-flowrate.xml'].include? hpxml_file
    hpxml.heating_systems[0].heating_cfm = hpxml.heating_systems[0].heating_capacity * 360.0 / 12000.0
  elsif hpxml_file.include? 'hvac_autosizing' and not hpxml.heating_systems.nil? and hpxml.heating_systems.size > 0
    hpxml.heating_systems[0].heating_capacity = -1
  elsif hpxml_file.include? '-zero-heat.xml' and not hpxml.heating_systems.nil? and hpxml.heating_systems.size > 0
    hpxml.heating_systems[0].fraction_heat_load_served = 0
    hpxml.heating_systems[0].heating_capacity = 0
  elsif hpxml_file.include? 'hvac_multiple' and not hpxml.heating_systems.nil? and hpxml.heating_systems.size > 0
    hpxml.heating_systems[0].heating_capacity /= 3.0
    hpxml.heating_systems[0].fraction_heat_load_served = 0.333
    hpxml.heating_systems[0].electric_auxiliary_energy /= 3.0 unless hpxml.heating_systems[0].electric_auxiliary_energy.nil?
    hpxml.heating_systems << hpxml.heating_systems[0].dup
    hpxml.heating_systems[1].id = "HeatingSystem2"
    hpxml.heating_systems[1].distribution_system_idref = "HVACDistribution2" unless hpxml.heating_systems[1].distribution_system_idref.nil?
    hpxml.heating_systems << hpxml.heating_systems[0].dup
    hpxml.heating_systems[2].id = "HeatingSystem3"
    hpxml.heating_systems[2].distribution_system_idref = "HVACDistribution3" unless hpxml.heating_systems[2].distribution_system_idref.nil?
    if ['hvac_multiple/base-hvac-boiler-gas-only-x3.xml'].include? hpxml_file
      # Test a file where sum is slightly greater than 1
      hpxml.heating_systems[0].fraction_heat_load_served = 0.33
      hpxml.heating_systems[1].fraction_heat_load_served = 0.33
      hpxml.heating_systems[2].fraction_heat_load_served = 0.35
    end
  elsif hpxml_file.include? 'hvac_partial' and not hpxml.heating_systems.nil? and hpxml.heating_systems.size > 0
    hpxml.heating_systems[0].heating_capacity /= 3.0
    hpxml.heating_systems[0].fraction_heat_load_served = 0.333
    hpxml.heating_systems[0].electric_auxiliary_energy /= 3.0 unless hpxml.heating_systems[0].electric_auxiliary_energy.nil?
  end
end

def set_hpxml_cooling_systems(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.cooling_systems = [HPXML::CoolingSystem.new({ :id => "CoolingSystem",
                                                        :distribution_system_idref => "HVACDistribution",
                                                        :cooling_system_type => "central air conditioner",
                                                        :cooling_system_fuel => "electricity",
                                                        :cooling_capacity => 48000,
                                                        :fraction_cool_load_served => 1,
                                                        :cooling_efficiency_seer => 13 })]
  elsif ['base-hvac-air-to-air-heat-pump-1-speed.xml',
         'base-hvac-air-to-air-heat-pump-2-speed.xml',
         'base-hvac-air-to-air-heat-pump-var-speed.xml',
         'base-hvac-boiler-elec-only.xml',
         'base-hvac-boiler-gas-only.xml',
         'base-hvac-boiler-oil-only.xml',
         'base-hvac-boiler-propane-only.xml',
         'base-hvac-boiler-wood-only.xml',
         'base-hvac-elec-resistance-only.xml',
         'base-hvac-furnace-elec-only.xml',
         'base-hvac-furnace-gas-only.xml',
         'base-hvac-furnace-oil-only.xml',
         'base-hvac-furnace-propane-only.xml',
         'base-hvac-furnace-wood-only.xml',
         'base-hvac-ground-to-air-heat-pump.xml',
         'base-hvac-mini-split-heat-pump-ducted.xml',
         'base-hvac-mini-split-heat-pump-ductless-no-backup.xml',
         'base-hvac-ideal-air.xml',
         'base-hvac-none.xml',
         'base-hvac-stove-oil-only.xml',
         'base-hvac-stove-wood-only.xml',
         'base-hvac-wall-furnace-elec-only.xml',
         'base-hvac-wall-furnace-propane-only.xml',
         'base-hvac-wall-furnace-wood-only.xml'].include? hpxml_file
    hpxml.cooling_systems = []
  elsif ['base-hvac-central-ac-only-1-speed-detailed.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_shr = 0.7
    hpxml.cooling_systems[0].compressor_type = "single stage"
  elsif ['base-hvac-central-ac-only-2-speed-detailed.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_shr = 0.7
    hpxml.cooling_systems[0].compressor_type = "two stage"
  elsif ['base-hvac-central-ac-only-var-speed-detailed.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_shr = 0.7
    hpxml.cooling_systems[0].compressor_type = "variable speed"
  elsif ['base-hvac-room-ac-only-detailed.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_shr = 0.7
  elsif ['base-hvac-boiler-gas-central-ac-1-speed.xml'].include? hpxml_file
    hpxml.cooling_systems[0].distribution_system_idref = "HVACDistribution2"
  elsif ['base-hvac-furnace-gas-central-ac-2-speed.xml',
         'base-hvac-central-ac-only-2-speed.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_efficiency_seer = 18
  elsif ['base-hvac-furnace-gas-central-ac-var-speed.xml',
         'base-hvac-central-ac-only-var-speed.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_efficiency_seer = 24
  elsif ['base-hvac-furnace-gas-room-ac.xml',
         'base-hvac-room-ac-only.xml'].include? hpxml_file
    hpxml.cooling_systems[0].distribution_system_idref = nil
    hpxml.cooling_systems[0].cooling_system_type = "room air conditioner"
    hpxml.cooling_systems[0].cooling_efficiency_seer = nil
    hpxml.cooling_systems[0].cooling_efficiency_eer = 8.5
  elsif ['base-hvac-evap-cooler-only-ducted.xml',
         'base-hvac-evap-cooler-furnace-gas.xml',
         'base-hvac-evap-cooler-only.xml',
         'hvac_autosizing/base-hvac-evap-cooler-furnace-gas-autosize.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_system_type = "evaporative cooler"
    hpxml.cooling_systems[0].cooling_efficiency_seer = nil
    hpxml.cooling_systems[0].cooling_efficiency_eer = nil
    hpxml.cooling_systems[0].cooling_capacity = nil
    if ['base-hvac-evap-cooler-furnace-gas.xml',
        'hvac_autosizing/base-hvac-evap-cooler-furnace-gas-autosize.xml',
        'base-hvac-evap-cooler-only.xml'].include? hpxml_file
      hpxml.cooling_systems[0].distribution_system_idref = nil
    end
  elsif ['base-hvac-multiple.xml'].include? hpxml_file
    hpxml.cooling_systems[0].distribution_system_idref = "HVACDistribution4"
    hpxml.cooling_systems[0].fraction_cool_load_served = 0.2
    hpxml.cooling_systems[0].cooling_capacity *= 0.2
    hpxml.cooling_systems << HPXML::CoolingSystem.new({ :id => "CoolingSystem2",
                                                        :cooling_system_type => "room air conditioner",
                                                        :cooling_system_fuel => "electricity",
                                                        :cooling_capacity => 9600,
                                                        :fraction_cool_load_served => 0.2,
                                                        :cooling_efficiency_eer => 8.5 })
  elsif ['invalid_files/hvac-frac-load-served.xml'].include? hpxml_file
    hpxml.cooling_systems[0].fraction_cool_load_served += 0.2
  elsif ['invalid_files/hvac-dse-multiple-attached-cooling.xml'].include? hpxml_file
    hpxml.cooling_systems[0].fraction_cool_load_served = 0.5
    hpxml.cooling_systems << hpxml.cooling_systems[0].dup
    hpxml.cooling_systems[1].id += "2"
  elsif ['base-hvac-undersized.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_capacity /= 10.0
  elsif ['base-hvac-flowrate.xml'].include? hpxml_file
    hpxml.cooling_systems[0].cooling_cfm = hpxml.cooling_systems[0].cooling_capacity * 360.0 / 12000.0
  elsif hpxml_file.include? 'hvac_autosizing' and not hpxml.cooling_systems.nil? and hpxml.cooling_systems.size > 0
    hpxml.cooling_systems[0].cooling_capacity = -1
  elsif hpxml_file.include? '-zero-cool.xml' and not hpxml.cooling_systems.nil? and hpxml.cooling_systems.size > 0
    hpxml.cooling_systems[0].fraction_cool_load_served = 0
    hpxml.cooling_systems[0].cooling_capacity = 0
  elsif hpxml_file.include? 'hvac_multiple' and not hpxml.cooling_systems.nil? and hpxml.cooling_systems.size > 0
    hpxml.cooling_systems[0].cooling_capacity /= 3.0 unless hpxml.cooling_systems[0].cooling_capacity.nil?
    hpxml.cooling_systems[0].fraction_cool_load_served = 0.333
    hpxml.cooling_systems << hpxml.cooling_systems[0].dup
    hpxml.cooling_systems[1].id = "CoolingSystem2"
    hpxml.cooling_systems[1].distribution_system_idref = "HVACDistribution2" unless hpxml.cooling_systems[1].distribution_system_idref.nil?
    hpxml.cooling_systems << hpxml.cooling_systems[0].dup
    hpxml.cooling_systems[2].id = "CoolingSystem3"
    hpxml.cooling_systems[2].distribution_system_idref = "HVACDistribution3" unless hpxml.cooling_systems[2].distribution_system_idref.nil?
  elsif hpxml_file.include? 'hvac_partial' and not hpxml.cooling_systems.nil? and hpxml.cooling_systems.size > 0
    hpxml.cooling_systems[0].cooling_capacity /= 3.0 unless hpxml.cooling_systems[0].cooling_capacity.nil?
    hpxml.cooling_systems[0].fraction_cool_load_served = 0.333
  end
end

def set_hpxml_heat_pumps(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.heat_pumps = []
  elsif ['base-hvac-air-to-air-heat-pump-1-speed.xml',
         'base-hvac-central-ac-plus-air-to-air-heat-pump-heating.xml'].include? hpxml_file
    hpxml.heat_pumps << HPXML::HeatPump.new({ :id => "HeatPump",
                                              :distribution_system_idref => "HVACDistribution",
                                              :heat_pump_type => "air-to-air",
                                              :heat_pump_fuel => "electricity",
                                              :heating_capacity => 42000,
                                              :cooling_capacity => 48000,
                                              :backup_heating_fuel => "electricity",
                                              :backup_heating_capacity => 34121,
                                              :backup_heating_efficiency_percent => 1.0,
                                              :fraction_heat_load_served => 1,
                                              :fraction_cool_load_served => 1,
                                              :heating_efficiency_hspf => 7.7,
                                              :cooling_efficiency_seer => 13 })
    if hpxml_file == 'base-hvac-central-ac-plus-air-to-air-heat-pump-heating.xml'
      hpxml.heat_pumps[0].fraction_cool_load_served = 0
    end
  elsif ['base-hvac-air-to-air-heat-pump-2-speed.xml'].include? hpxml_file
    hpxml.heat_pumps << HPXML::HeatPump.new({ :id => "HeatPump",
                                              :distribution_system_idref => "HVACDistribution",
                                              :heat_pump_type => "air-to-air",
                                              :heat_pump_fuel => "electricity",
                                              :heating_capacity => 42000,
                                              :cooling_capacity => 48000,
                                              :backup_heating_fuel => "electricity",
                                              :backup_heating_capacity => 34121,
                                              :backup_heating_efficiency_percent => 1.0,
                                              :fraction_heat_load_served => 1,
                                              :fraction_cool_load_served => 1,
                                              :heating_efficiency_hspf => 9.3,
                                              :cooling_efficiency_seer => 18 })
  elsif ['base-hvac-air-to-air-heat-pump-var-speed.xml'].include? hpxml_file
    hpxml.heat_pumps << HPXML::HeatPump.new({ :id => "HeatPump",
                                              :distribution_system_idref => "HVACDistribution",
                                              :heat_pump_type => "air-to-air",
                                              :heat_pump_fuel => "electricity",
                                              :heating_capacity => 42000,
                                              :cooling_capacity => 48000,
                                              :backup_heating_fuel => "electricity",
                                              :backup_heating_capacity => 34121,
                                              :backup_heating_efficiency_percent => 1.0,
                                              :fraction_heat_load_served => 1,
                                              :fraction_cool_load_served => 1,
                                              :heating_efficiency_hspf => 10,
                                              :cooling_efficiency_seer => 22 })
  elsif ['base-hvac-ground-to-air-heat-pump.xml'].include? hpxml_file
    hpxml.heat_pumps << HPXML::HeatPump.new({ :id => "HeatPump",
                                              :distribution_system_idref => "HVACDistribution",
                                              :heat_pump_type => "ground-to-air",
                                              :heat_pump_fuel => "electricity",
                                              :heating_capacity => 42000,
                                              :cooling_capacity => 48000,
                                              :backup_heating_fuel => "electricity",
                                              :backup_heating_capacity => 34121,
                                              :backup_heating_efficiency_percent => 1.0,
                                              :fraction_heat_load_served => 1,
                                              :fraction_cool_load_served => 1,
                                              :heating_efficiency_cop => 3.6,
                                              :cooling_efficiency_eer => 16.6 })
  elsif ['base-hvac-mini-split-heat-pump-ducted.xml'].include? hpxml_file
    hpxml.heat_pumps << HPXML::HeatPump.new({ :id => "HeatPump",
                                              :distribution_system_idref => "HVACDistribution",
                                              :heat_pump_type => "mini-split",
                                              :heat_pump_fuel => "electricity",
                                              :heating_capacity => 52000,
                                              :cooling_capacity => 48000,
                                              :backup_heating_fuel => "electricity",
                                              :backup_heating_capacity => 34121,
                                              :backup_heating_efficiency_percent => 1.0,
                                              :fraction_heat_load_served => 1,
                                              :fraction_cool_load_served => 1,
                                              :heating_efficiency_hspf => 10,
                                              :cooling_efficiency_seer => 19 })
  elsif ['base-hvac-mini-split-heat-pump-ductless.xml'].include? hpxml_file
    hpxml.heat_pumps[0].distribution_system_idref = nil
  elsif ['base-hvac-mini-split-heat-pump-ductless-no-backup.xml'].include? hpxml_file
    hpxml.heat_pumps[0].backup_heating_fuel = nil
  elsif ['invalid_files/heat-pump-mixed-fixed-and-autosize-capacities.xml'].include? hpxml_file
    hpxml.heat_pumps[0].heating_capacity = -1
  elsif ['invalid_files/heat-pump-mixed-fixed-and-autosize-capacities2.xml'].include? hpxml_file
    hpxml.heat_pumps[0].cooling_capacity = -1
  elsif ['invalid_files/heat-pump-mixed-fixed-and-autosize-capacities3.xml'].include? hpxml_file
    hpxml.heat_pumps[0].cooling_capacity = -1
    hpxml.heat_pumps[0].heating_capacity = -1
    hpxml.heat_pumps[0].heating_capacity_17F = 25000
  elsif ['invalid_files/heat-pump-mixed-fixed-and-autosize-capacities4.xml'].include? hpxml_file
    hpxml.heat_pumps[0].backup_heating_capacity = -1
  elsif ['base-hvac-air-to-air-heat-pump-1-speed-detailed.xml'].include? hpxml_file
    hpxml.heat_pumps[0].heating_capacity_17F = hpxml.heat_pumps[0].heating_capacity * 0.630 # Based on OAT slope of default curves
    hpxml.heat_pumps[0].cooling_shr = 0.7
    hpxml.heat_pumps[0].compressor_type = "single stage"
  elsif ['base-hvac-air-to-air-heat-pump-2-speed-detailed.xml'].include? hpxml_file
    hpxml.heat_pumps[0].heating_capacity_17F = hpxml.heat_pumps[0].heating_capacity * 0.590 # Based on OAT slope of default curves
    hpxml.heat_pumps[0].cooling_shr = 0.7
    hpxml.heat_pumps[0].compressor_type = "two stage"
  elsif ['base-hvac-air-to-air-heat-pump-var-speed-detailed.xml'].include? hpxml_file
    hpxml.heat_pumps[0].heating_capacity_17F = hpxml.heat_pumps[0].heating_capacity * 0.640 # Based on OAT slope of default curves
    hpxml.heat_pumps[0].cooling_shr = 0.7
    hpxml.heat_pumps[0].compressor_type = "variable speed"
  elsif ['base-hvac-mini-split-heat-pump-ducted-detailed.xml'].include? hpxml_file
    f = 1.0 - (1.0 - 0.25) / (47.0 + 5.0) * (47.0 - 17.0)
    hpxml.heat_pumps[0].heating_capacity_17F = hpxml.heat_pumps[0].heating_capacity * f
    hpxml.heat_pumps[0].cooling_shr = 0.7
  elsif ['base-hvac-ground-to-air-heat-pump-detailed.xml'].include? hpxml_file
    hpxml.heat_pumps[0].cooling_shr = 0.7
  elsif ['base-hvac-multiple.xml'].include? hpxml_file
    hpxml.heat_pumps << HPXML::HeatPump.new({ :id => "HeatPump",
                                              :distribution_system_idref => "HVACDistribution5",
                                              :heat_pump_type => "air-to-air",
                                              :heat_pump_fuel => "electricity",
                                              :heating_capacity => 4800,
                                              :cooling_capacity => 4800,
                                              :backup_heating_fuel => "electricity",
                                              :backup_heating_capacity => 3412,
                                              :backup_heating_efficiency_percent => 1.0,
                                              :fraction_heat_load_served => 0.1,
                                              :fraction_cool_load_served => 0.2,
                                              :heating_efficiency_hspf => 7.7,
                                              :cooling_efficiency_seer => 13 })
    hpxml.heat_pumps << HPXML::HeatPump.new({ :id => "HeatPump2",
                                              :distribution_system_idref => "HVACDistribution6",
                                              :heat_pump_type => "ground-to-air",
                                              :heat_pump_fuel => "electricity",
                                              :heating_capacity => 4800,
                                              :cooling_capacity => 4800,
                                              :backup_heating_fuel => "electricity",
                                              :backup_heating_capacity => 3412,
                                              :backup_heating_efficiency_percent => 1.0,
                                              :fraction_heat_load_served => 0.1,
                                              :fraction_cool_load_served => 0.2,
                                              :heating_efficiency_cop => 3.6,
                                              :cooling_efficiency_eer => 16.6 })
    hpxml.heat_pumps << HPXML::HeatPump.new({ :id => "HeatPump3",
                                              :heat_pump_type => "mini-split",
                                              :heat_pump_fuel => "electricity",
                                              :heating_capacity => 4800,
                                              :cooling_capacity => 4800,
                                              :backup_heating_fuel => "electricity",
                                              :backup_heating_capacity => 3412,
                                              :backup_heating_efficiency_percent => 1.0,
                                              :fraction_heat_load_served => 0.1,
                                              :fraction_cool_load_served => 0.2,
                                              :heating_efficiency_hspf => 10,
                                              :cooling_efficiency_seer => 19 })
  elsif ['invalid_files/hvac-distribution-multiple-attached-heating.xml'].include? hpxml_file
    hpxml.heat_pumps[0].distribution_system_idref = "HVACDistribution3"
  elsif ['invalid_files/hvac-distribution-multiple-attached-cooling.xml'].include? hpxml_file
    hpxml.heat_pumps[0].distribution_system_idref = "HVACDistribution4"
  elsif ['base-hvac-dual-fuel-air-to-air-heat-pump-1-speed.xml',
         'base-hvac-dual-fuel-air-to-air-heat-pump-2-speed.xml',
         'base-hvac-dual-fuel-air-to-air-heat-pump-var-speed.xml',
         'base-hvac-dual-fuel-mini-split-heat-pump-ducted.xml'].include? hpxml_file
    hpxml.heat_pumps[0].backup_heating_fuel = "natural gas"
    hpxml.heat_pumps[0].backup_heating_capacity = 36000
    hpxml.heat_pumps[0].backup_heating_efficiency_percent = nil
    hpxml.heat_pumps[0].backup_heating_efficiency_afue = 0.95
    hpxml.heat_pumps[0].backup_heating_switchover_temp = 25
  elsif ['base-hvac-dual-fuel-air-to-air-heat-pump-1-speed-electric.xml'].include? hpxml_file
    hpxml.heat_pumps[0].backup_heating_fuel = "electricity"
    hpxml.heat_pumps[0].backup_heating_efficiency_afue = 1.0
  elsif hpxml_file.include? 'hvac_autosizing' and not hpxml.heat_pumps.nil? and hpxml.heat_pumps.size > 0
    hpxml.heat_pumps[0].cooling_capacity = -1
    hpxml.heat_pumps[0].heating_capacity = -1
    hpxml.heat_pumps[0].backup_heating_capacity = -1
  elsif hpxml_file.include? '-zero-heat.xml' and not hpxml.heat_pumps.nil? and hpxml.heat_pumps.size > 0
    hpxml.heat_pumps[0].fraction_heat_load_served = 0
    hpxml.heat_pumps[0].heating_capacity = 0
    hpxml.heat_pumps[0].backup_heating_capacity = 0
  elsif hpxml_file.include? '-zero-cool.xml' and not hpxml.heat_pumps.nil? and hpxml.heat_pumps.size > 0
    hpxml.heat_pumps[0].fraction_cool_load_served = 0
    hpxml.heat_pumps[0].cooling_capacity = 0
  elsif hpxml_file.include? 'hvac_multiple' and not hpxml.heat_pumps.nil? and hpxml.heat_pumps.size > 0
    hpxml.heat_pumps[0].cooling_capacity /= 3.0
    hpxml.heat_pumps[0].heating_capacity /= 3.0
    hpxml.heat_pumps[0].backup_heating_capacity /= 3.0
    hpxml.heat_pumps[0].fraction_heat_load_served = 0.333
    hpxml.heat_pumps[0].fraction_cool_load_served = 0.333
    hpxml.heat_pumps << hpxml.heat_pumps[0].dup
    hpxml.heat_pumps[1].id = "HeatPump2"
    hpxml.heat_pumps[1].distribution_system_idref = "HVACDistribution2" unless hpxml.heat_pumps[1].distribution_system_idref.nil?
    hpxml.heat_pumps << hpxml.heat_pumps[0].dup
    hpxml.heat_pumps[2].id = "HeatPump3"
    hpxml.heat_pumps[2].distribution_system_idref = "HVACDistribution3" unless hpxml.heat_pumps[2].distribution_system_idref.nil?
  elsif hpxml_file.include? 'hvac_partial' and not hpxml.heat_pumps.nil? and hpxml.heat_pumps.size > 0
    hpxml.heat_pumps[0].cooling_capacity /= 3.0
    hpxml.heat_pumps[0].heating_capacity /= 3.0
    hpxml.heat_pumps[0].backup_heating_capacity /= 3.0
    hpxml.heat_pumps[0].fraction_heat_load_served = 0.333
    hpxml.heat_pumps[0].fraction_cool_load_served = 0.333
  end
end

def set_hpxml_hvac_control(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.hvac_control = HPXML::HVACControl.new({ :id => "HVACControl",
                                                  :control_type => "manual thermostat",
                                                  :heating_setpoint_temp => 68,
                                                  :cooling_setpoint_temp => 78 })
  elsif ['base-hvac-none.xml'].include? hpxml_file
    hpxml.hvac_control = nil
  elsif ['base-hvac-programmable-thermostat.xml'].include? hpxml_file
    hpxml.hvac_control.control_type = "programmable thermostat"
    hpxml.hvac_control.heating_setback_temp = 66
    hpxml.hvac_control.heating_setback_hours_per_week = 7 * 7
    hpxml.hvac_control.heating_setback_start_hour = 23 # 11pm
    hpxml.hvac_control.cooling_setup_temp = 80
    hpxml.hvac_control.cooling_setup_hours_per_week = 6 * 7
    hpxml.hvac_control.cooling_setup_start_hour = 9 # 9am
  elsif ['base-hvac-setpoints.xml'].include? hpxml_file
    hpxml.hvac_control.heating_setpoint_temp = 60
    hpxml.hvac_control.cooling_setpoint_temp = 80
  elsif ['base-misc-ceiling-fans.xml'].include? hpxml_file
    hpxml.hvac_control.ceiling_fan_cooling_setpoint_temp_offset = 0.5
  end
end

def set_hpxml_hvac_distributions(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.hvac_distributions = [HPXML::HVACDistribution.new({ :id => "HVACDistribution",
                                                              :distribution_system_type => "AirDistribution" })]
    hpxml.hvac_distributions[0].duct_leakage_measurements = [HPXML::DuctLeakageMeasurement.new({ :duct_type => "supply",
                                                                                                 :duct_leakage_units => "CFM25",
                                                                                                 :duct_leakage_value => 75 }),
                                                             HPXML::DuctLeakageMeasurement.new({ :duct_type => "return",
                                                                                                 :duct_leakage_units => "CFM25",
                                                                                                 :duct_leakage_value => 25 })]
    hpxml.hvac_distributions[0].ducts = [HPXML::Duct.new({ :duct_type => "supply",
                                                           :duct_insulation_r_value => 4,
                                                           :duct_location => "attic - unvented",
                                                           :duct_surface_area => 150 }),
                                         HPXML::Duct.new({ :duct_type => "return",
                                                           :duct_insulation_r_value => 0,
                                                           :duct_location => "attic - unvented",
                                                           :duct_surface_area => 50 })]
  elsif ['base-hvac-boiler-elec-only.xml',
         'base-hvac-boiler-gas-only.xml',
         'base-hvac-boiler-oil-only.xml',
         'base-hvac-boiler-propane-only.xml',
         'base-hvac-boiler-wood-only.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].distribution_system_type = "HydronicDistribution"
    hpxml.hvac_distributions[0].duct_leakage_measurements = []
    hpxml.hvac_distributions[0].ducts = []
  elsif ['base-hvac-boiler-gas-central-ac-1-speed.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].distribution_system_type = "HydronicDistribution"
    hpxml.hvac_distributions[0].duct_leakage_measurements = []
    hpxml.hvac_distributions[0].ducts = []
    hpxml.hvac_distributions << HPXML::HVACDistribution.new({ :id => "HVACDistribution2",
                                                              :distribution_system_type => "AirDistribution" })
    hpxml.hvac_distributions[-1].duct_leakage_measurements = [HPXML::DuctLeakageMeasurement.new({ :duct_type => "supply",
                                                                                                  :duct_leakage_units => "CFM25",
                                                                                                  :duct_leakage_value => 75 }),
                                                              HPXML::DuctLeakageMeasurement.new({ :duct_type => "return",
                                                                                                  :duct_leakage_units => "CFM25",
                                                                                                  :duct_leakage_value => 25 })]
    hpxml.hvac_distributions[-1].ducts = [HPXML::Duct.new({ :duct_type => "supply",
                                                            :duct_insulation_r_value => 4,
                                                            :duct_location => "attic - unvented",
                                                            :duct_surface_area => 150 }),
                                          HPXML::Duct.new({ :duct_type => "return",
                                                            :duct_insulation_r_value => 0,
                                                            :duct_location => "attic - unvented",
                                                            :duct_surface_area => 50 })]
  elsif ['base-hvac-none.xml',
         'base-hvac-elec-resistance-only.xml',
         'base-hvac-evap-cooler-only.xml',
         'base-hvac-ideal-air.xml',
         'base-hvac-mini-split-heat-pump-ductless.xml',
         'base-hvac-room-ac-only.xml',
         'base-hvac-stove-oil-only.xml',
         'base-hvac-stove-wood-only.xml',
         'base-hvac-wall-furnace-elec-only.xml',
         'base-hvac-wall-furnace-propane-only.xml',
         'base-hvac-wall-furnace-wood-only.xml'].include? hpxml_file
    hpxml.hvac_distributions = []
  elsif ['base-hvac-multiple.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].distribution_system_type = "HydronicDistribution"
    hpxml.hvac_distributions[0].duct_leakage_measurements = []
    hpxml.hvac_distributions[0].ducts = []
    hpxml.hvac_distributions << HPXML::HVACDistribution.new({ :id => "HVACDistribution2",
                                                              :distribution_system_type => "HydronicDistribution",
                                                              :duct_leakage_measurements => [],
                                                              :ducts => [] })
    hpxml.hvac_distributions << HPXML::HVACDistribution.new({ :id => "HVACDistribution3",
                                                              :distribution_system_type => "AirDistribution" })
    hpxml.hvac_distributions[-1].duct_leakage_measurements = [HPXML::DuctLeakageMeasurement.new({ :duct_type => "supply",
                                                                                                  :duct_leakage_units => "CFM25",
                                                                                                  :duct_leakage_value => 75 }),
                                                              HPXML::DuctLeakageMeasurement.new({ :duct_type => "return",
                                                                                                  :duct_leakage_units => "CFM25",
                                                                                                  :duct_leakage_value => 25 })]
    hpxml.hvac_distributions[-1].ducts = [HPXML::Duct.new({ :duct_type => "supply",
                                                            :duct_insulation_r_value => 4,
                                                            :duct_location => "attic - unvented",
                                                            :duct_surface_area => 150 }),
                                          HPXML::Duct.new({ :duct_type => "return",
                                                            :duct_insulation_r_value => 0,
                                                            :duct_location => "attic - unvented",
                                                            :duct_surface_area => 50 })]
    hpxml.hvac_distributions << HPXML::HVACDistribution.new({ :id => "HVACDistribution4",
                                                              :distribution_system_type => "AirDistribution" })
    hpxml.hvac_distributions[-1].duct_leakage_measurements = [HPXML::DuctLeakageMeasurement.new({ :duct_type => "supply",
                                                                                                  :duct_leakage_units => "CFM25",
                                                                                                  :duct_leakage_value => 75 }),
                                                              HPXML::DuctLeakageMeasurement.new({ :duct_type => "return",
                                                                                                  :duct_leakage_units => "CFM25",
                                                                                                  :duct_leakage_value => 25 })]
    hpxml.hvac_distributions[-1].ducts = [HPXML::Duct.new({ :duct_type => "supply",
                                                            :duct_insulation_r_value => 4,
                                                            :duct_location => "attic - unvented",
                                                            :duct_surface_area => 150 }),
                                          HPXML::Duct.new({ :duct_type => "return",
                                                            :duct_insulation_r_value => 0,
                                                            :duct_location => "attic - unvented",
                                                            :duct_surface_area => 50 })]
    hpxml.hvac_distributions << HPXML::HVACDistribution.new({ :id => "HVACDistribution5",
                                                              :distribution_system_type => "AirDistribution" })
    hpxml.hvac_distributions[-1].duct_leakage_measurements = [HPXML::DuctLeakageMeasurement.new({ :duct_type => "supply",
                                                                                                  :duct_leakage_units => "CFM25",
                                                                                                  :duct_leakage_value => 75 }),
                                                              HPXML::DuctLeakageMeasurement.new({ :duct_type => "return",
                                                                                                  :duct_leakage_units => "CFM25",
                                                                                                  :duct_leakage_value => 25 })]
    hpxml.hvac_distributions[-1].ducts = [HPXML::Duct.new({ :duct_type => "supply",
                                                            :duct_insulation_r_value => 4,
                                                            :duct_location => "attic - unvented",
                                                            :duct_surface_area => 150 }),
                                          HPXML::Duct.new({ :duct_type => "return",
                                                            :duct_insulation_r_value => 0,
                                                            :duct_location => "attic - unvented",
                                                            :duct_surface_area => 50 })]
    hpxml.hvac_distributions << HPXML::HVACDistribution.new({ :id => "HVACDistribution6",
                                                              :distribution_system_type => "AirDistribution" })
    hpxml.hvac_distributions[-1].duct_leakage_measurements = [HPXML::DuctLeakageMeasurement.new({ :duct_type => "supply",
                                                                                                  :duct_leakage_units => "CFM25",
                                                                                                  :duct_leakage_value => 75 }),
                                                              HPXML::DuctLeakageMeasurement.new({ :duct_type => "return",
                                                                                                  :duct_leakage_units => "CFM25",
                                                                                                  :duct_leakage_value => 25 })]
    hpxml.hvac_distributions[-1].ducts = [HPXML::Duct.new({ :duct_type => "supply",
                                                            :duct_insulation_r_value => 4,
                                                            :duct_location => "attic - unvented",
                                                            :duct_surface_area => 150 }),
                                          HPXML::Duct.new({ :duct_type => "return",
                                                            :duct_insulation_r_value => 0,
                                                            :duct_location => "attic - unvented",
                                                            :duct_surface_area => 50 })]
  elsif ['base-hvac-dse.xml',
         'base-dhw-indirect-dse.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].distribution_system_type = "DSE"
    hpxml.hvac_distributions[0].annual_heating_dse = 0.8
    hpxml.hvac_distributions[0].annual_cooling_dse = 0.7
  elsif ['base-hvac-furnace-x3-dse.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].distribution_system_type = "DSE"
    hpxml.hvac_distributions[0].annual_heating_dse = 0.8
    hpxml.hvac_distributions[0].annual_cooling_dse = 0.7
    hpxml.hvac_distributions << hpxml.hvac_distributions[0].dup
    hpxml.hvac_distributions[1].id = "HVACDistribution2"
    hpxml.hvac_distributions[1].annual_cooling_dse = nil
    hpxml.hvac_distributions << hpxml.hvac_distributions[0].dup
    hpxml.hvac_distributions[2].id = "HVACDistribution3"
    hpxml.hvac_distributions[2].annual_cooling_dse = nil
  elsif ['base-hvac-mini-split-heat-pump-ducted.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].duct_leakage_measurements[0].duct_leakage_value = 15
    hpxml.hvac_distributions[0].duct_leakage_measurements[1].duct_leakage_value = 5
    hpxml.hvac_distributions[0].ducts[0].duct_insulation_r_value = 0
    hpxml.hvac_distributions[0].ducts[0].duct_surface_area = 30
    hpxml.hvac_distributions[0].ducts[1].duct_surface_area = 10
  elsif ['base-hvac-evap-cooler-only-ducted.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].duct_leakage_measurements.pop
    hpxml.hvac_distributions[0].ducts.pop
  elsif ['base-hvac-ducts-leakage-percent.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].duct_leakage_measurements = [HPXML::DuctLeakageMeasurement.new({ :duct_type => "supply",
                                                                                                 :duct_leakage_units => "Percent",
                                                                                                 :duct_leakage_value => 0.1 }),
                                                             HPXML::DuctLeakageMeasurement.new({ :duct_type => "return",
                                                                                                 :duct_leakage_units => "Percent",
                                                                                                 :duct_leakage_value => 0.05 })]
  elsif ['base-hvac-undersized.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].duct_leakage_measurements[0].duct_leakage_value /= 10.0
    hpxml.hvac_distributions[0].duct_leakage_measurements[1].duct_leakage_value /= 10.0
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = "basement - unconditioned"
    hpxml.hvac_distributions[0].ducts[1].duct_location = "basement - unconditioned"
  elsif ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = "crawlspace - unvented"
    hpxml.hvac_distributions[0].ducts[1].duct_location = "crawlspace - unvented"
  elsif ['base-foundation-vented-crawlspace.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = "crawlspace - vented"
    hpxml.hvac_distributions[0].ducts[1].duct_location = "crawlspace - vented"
  elsif ['base-atticroof-flat.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].duct_leakage_measurements[0].duct_leakage_value = 0.0
    hpxml.hvac_distributions[0].duct_leakage_measurements[1].duct_leakage_value = 0.0
    hpxml.hvac_distributions[0].ducts[0].duct_location = "basement - conditioned"
    hpxml.hvac_distributions[0].ducts[1].duct_location = "basement - conditioned"
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = "attic - vented"
    hpxml.hvac_distributions[0].ducts[1].duct_location = "attic - vented"
  elsif ['base-enclosure-garage.xml',
         'invalid_files/duct-location.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = "garage"
    hpxml.hvac_distributions[0].ducts[1].duct_location = "garage"
  elsif ['invalid_files/duct-location-other.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = "unconditioned space"
    hpxml.hvac_distributions[0].ducts[1].duct_location = "unconditioned space"
  elsif ['base-hvac-ducts-outside.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = "outside"
    hpxml.hvac_distributions[0].ducts[1].duct_location = "outside"
  elsif ['base-hvac-ducts-locations.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[1].duct_location = "attic - unvented"
  elsif ['base-hvac-ducts-multiple.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts << HPXML::Duct.new({ :duct_type => "supply",
                                                           :duct_insulation_r_value => 8,
                                                           :duct_location => "attic - unvented",
                                                           :duct_surface_area => 300 })
    hpxml.hvac_distributions[0].ducts << HPXML::Duct.new({ :duct_type => "supply",
                                                           :duct_insulation_r_value => 8,
                                                           :duct_location => "outside",
                                                           :duct_surface_area => 300 })
    hpxml.hvac_distributions[0].ducts << HPXML::Duct.new({ :duct_type => "return",
                                                           :duct_insulation_r_value => 4,
                                                           :duct_location => "attic - unvented",
                                                           :duct_surface_area => 100 })
    hpxml.hvac_distributions[0].ducts << HPXML::Duct.new({ :duct_type => "return",
                                                           :duct_insulation_r_value => 4,
                                                           :duct_location => "outside",
                                                           :duct_surface_area => 100 })
  elsif ['base-atticroof-conditioned.xml',
         'base-enclosure-adiabatic-surfaces.xml',
         'base-atticroof-cathedral.xml',
         'base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = "living space"
    hpxml.hvac_distributions[0].ducts[1].duct_location = "living space"
    hpxml.hvac_distributions[0].duct_leakage_measurements[0].duct_leakage_value = 0.0
    hpxml.hvac_distributions[0].duct_leakage_measurements[1].duct_leakage_value = 0.0

  elsif ['base-hvac-ducts-in-conditioned-space.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts[0].duct_location = "living space"
    hpxml.hvac_distributions[0].ducts[1].duct_location = "living space"
    # Test leakage to outside when all ducts in conditioned space
    # (e.g., ducts may be in floor cavities which have leaky rims)
    hpxml.hvac_distributions[0].duct_leakage_measurements[0].duct_leakage_value = 1.5
    hpxml.hvac_distributions[0].duct_leakage_measurements[1].duct_leakage_value = 1.5
  elsif (hpxml_file.include? 'hvac_partial' or hpxml_file.include? 'hvac_base') and not hpxml.hvac_distributions.empty?
    if not hpxml.hvac_distributions[0].duct_leakage_measurements.empty?
      hpxml.hvac_distributions[0].duct_leakage_measurements[0].duct_leakage_value = 0.0
      hpxml.hvac_distributions[0].duct_leakage_measurements[1].duct_leakage_value = 0.0
    end
    hpxml.hvac_distributions[0].ducts = []
  elsif hpxml_file.include? 'hvac_multiple' and not hpxml.hvac_distributions.empty?
    hpxml.hvac_distributions[0].ducts = []
    if not hpxml.hvac_distributions[0].duct_leakage_measurements.empty?
      hpxml.hvac_distributions[0].duct_leakage_measurements[0].duct_leakage_value = 0.0
      hpxml.hvac_distributions[0].duct_leakage_measurements[1].duct_leakage_value = 0.0
    end
    hpxml.hvac_distributions << hpxml.hvac_distributions[0].dup
    hpxml.hvac_distributions[1].id = "HVACDistribution2"
    hpxml.hvac_distributions << hpxml.hvac_distributions[0].dup
    hpxml.hvac_distributions[2].id = "HVACDistribution3"
  elsif ['invalid_files/hvac-invalid-distribution-system-type.xml'].include? hpxml_file
    hpxml.hvac_distributions << HPXML::HVACDistribution.new({ :id => "HVACDistribution2",
                                                              :distribution_system_type => "HydronicDistribution",
                                                              :duct_leakage_measurements => [],
                                                              :ducts => [] })
  elsif ['invalid_files/hvac-distribution-return-duct-leakage-missing.xml'].include? hpxml_file
    hpxml.hvac_distributions[0].ducts << HPXML::Duct.new({ :duct_type => "return",
                                                           :duct_insulation_r_value => 0,
                                                           :duct_location => "attic - unvented",
                                                           :duct_surface_area => 50 })
  end
end

def set_hpxml_ventilation_fans(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.ventilation_fans = []
  elsif ['base-mechvent-balanced.xml'].include? hpxml_file
    hpxml.ventilation_fans << HPXML::VentilationFan.new({ :id => "MechanicalVentilation",
                                                          :fan_type => "balanced",
                                                          :tested_flow_rate => 110,
                                                          :hours_in_operation => 24,
                                                          :fan_power => 60,
                                                          :used_for_whole_building_ventilation => true })
  elsif ['invalid_files/unattached-cfis.xml',
         'invalid_files/cfis-with-hydronic-distribution.xml',
         'base-mechvent-cfis.xml',
         'base-mechvent-cfis-evap-cooler-only-ducted.xml'].include? hpxml_file
    hpxml.ventilation_fans << HPXML::VentilationFan.new({ :id => "MechanicalVentilation",
                                                          :fan_type => "central fan integrated supply",
                                                          :tested_flow_rate => 330,
                                                          :hours_in_operation => 8,
                                                          :fan_power => 300,
                                                          :used_for_whole_building_ventilation => true,
                                                          :distribution_system_idref => "HVACDistribution" })
    if ['invalid_files/unattached-cfis.xml'].include? hpxml_file
      hpxml.ventilation_fans[0].distribution_system_idref = "foobar"
    end
  elsif ['base-mechvent-erv.xml'].include? hpxml_file
    hpxml.ventilation_fans << HPXML::VentilationFan.new({ :id => "MechanicalVentilation",
                                                          :fan_type => "energy recovery ventilator",
                                                          :tested_flow_rate => 110,
                                                          :hours_in_operation => 24,
                                                          :total_recovery_efficiency => 0.48,
                                                          :sensible_recovery_efficiency => 0.72,
                                                          :fan_power => 60,
                                                          :used_for_whole_building_ventilation => true })
  elsif ['base-mechvent-erv-atre-asre.xml'].include? hpxml_file
    hpxml.ventilation_fans << HPXML::VentilationFan.new({ :id => "MechanicalVentilation",
                                                          :fan_type => "energy recovery ventilator",
                                                          :tested_flow_rate => 110,
                                                          :hours_in_operation => 24,
                                                          :total_recovery_efficiency_adjusted => 0.526,
                                                          :sensible_recovery_efficiency_adjusted => 0.79,
                                                          :fan_power => 60,
                                                          :used_for_whole_building_ventilation => true })
  elsif ['base-mechvent-exhaust.xml'].include? hpxml_file
    hpxml.ventilation_fans << HPXML::VentilationFan.new({ :id => "MechanicalVentilation",
                                                          :fan_type => "exhaust only",
                                                          :tested_flow_rate => 110,
                                                          :hours_in_operation => 24,
                                                          :fan_power => 30,
                                                          :used_for_whole_building_ventilation => true })
  elsif ['base-mechvent-exhaust-rated-flow-rate.xml'].include? hpxml_file
    hpxml.ventilation_fans << HPXML::VentilationFan.new({ :id => "MechanicalVentilation",
                                                          :fan_type => "exhaust only",
                                                          :rated_flow_rate => 110,
                                                          :hours_in_operation => 24,
                                                          :fan_power => 30,
                                                          :used_for_whole_building_ventilation => true })
  elsif ['base-mechvent-hrv.xml'].include? hpxml_file
    hpxml.ventilation_fans << HPXML::VentilationFan.new({ :id => "MechanicalVentilation",
                                                          :fan_type => "heat recovery ventilator",
                                                          :tested_flow_rate => 110,
                                                          :hours_in_operation => 24,
                                                          :sensible_recovery_efficiency => 0.72,
                                                          :fan_power => 60,
                                                          :used_for_whole_building_ventilation => true })
  elsif ['base-mechvent-hrv-asre.xml'].include? hpxml_file
    hpxml.ventilation_fans << HPXML::VentilationFan.new({ :id => "MechanicalVentilation",
                                                          :fan_type => "heat recovery ventilator",
                                                          :tested_flow_rate => 110,
                                                          :hours_in_operation => 24,
                                                          :sensible_recovery_efficiency_adjusted => 0.790,
                                                          :fan_power => 60,
                                                          :used_for_whole_building_ventilation => true })
  elsif ['base-mechvent-supply.xml'].include? hpxml_file
    hpxml.ventilation_fans << HPXML::VentilationFan.new({ :id => "MechanicalVentilation",
                                                          :fan_type => "supply only",
                                                          :tested_flow_rate => 110,
                                                          :hours_in_operation => 24,
                                                          :fan_power => 30,
                                                          :used_for_whole_building_ventilation => true })
  elsif ['base-misc-whole-house-fan.xml'].include? hpxml_file
    hpxml.ventilation_fans << HPXML::VentilationFan.new({ :id => "WholeHouseFan",
                                                          :rated_flow_rate => 4500,
                                                          :fan_power => 300,
                                                          :used_for_seasonal_cooling_load_reduction => true })
  end
end

def set_hpxml_water_heating_systems(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.water_heating_systems = [HPXML::WaterHeatingSystem.new({ :id => "WaterHeater",
                                                                   :fuel_type => "electricity",
                                                                   :water_heater_type => "storage water heater",
                                                                   :location => "living space",
                                                                   :tank_volume => 40,
                                                                   :fraction_dhw_load_served => 1,
                                                                   :heating_capacity => 18767,
                                                                   :energy_factor => 0.95 })]
  elsif ['base-dhw-multiple.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fraction_dhw_load_served = 0.2
    hpxml.water_heating_systems << HPXML::WaterHeatingSystem.new({ :id => "WaterHeater2",
                                                                   :fuel_type => "natural gas",
                                                                   :water_heater_type => "storage water heater",
                                                                   :location => "living space",
                                                                   :tank_volume => 50,
                                                                   :fraction_dhw_load_served => 0.2,
                                                                   :heating_capacity => 40000,
                                                                   :energy_factor => 0.59,
                                                                   :recovery_efficiency => 0.76 })
    hpxml.water_heating_systems << HPXML::WaterHeatingSystem.new({ :id => "WaterHeater3",
                                                                   :fuel_type => "electricity",
                                                                   :water_heater_type => "heat pump water heater",
                                                                   :location => "living space",
                                                                   :tank_volume => 80,
                                                                   :fraction_dhw_load_served => 0.2,
                                                                   :energy_factor => 2.3 })
    hpxml.water_heating_systems << HPXML::WaterHeatingSystem.new({ :id => "WaterHeater4",
                                                                   :fuel_type => "electricity",
                                                                   :water_heater_type => "instantaneous water heater",
                                                                   :location => "living space",
                                                                   :fraction_dhw_load_served => 0.2,
                                                                   :energy_factor => 0.99 })
    hpxml.water_heating_systems << HPXML::WaterHeatingSystem.new({ :id => "WaterHeater5",
                                                                   :fuel_type => "natural gas",
                                                                   :water_heater_type => "instantaneous water heater",
                                                                   :location => "living space",
                                                                   :fraction_dhw_load_served => 0.1,
                                                                   :energy_factor => 0.82 })
    hpxml.water_heating_systems << HPXML::WaterHeatingSystem.new({ :id => "WaterHeater6",
                                                                   :water_heater_type => "space-heating boiler with storage tank",
                                                                   :location => "living space",
                                                                   :tank_volume => 50,
                                                                   :fraction_dhw_load_served => 0.1,
                                                                   :related_hvac => "HeatingSystem" })
  elsif ['invalid_files/dhw-frac-load-served.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fraction_dhw_load_served += 0.15
  elsif ['base-dhw-tank-gas.xml',
         'base-dhw-tank-gas-outside.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fuel_type = "natural gas"
    hpxml.water_heating_systems[0].tank_volume = 50
    hpxml.water_heating_systems[0].heating_capacity = 40000
    hpxml.water_heating_systems[0].energy_factor = 0.59
    hpxml.water_heating_systems[0].recovery_efficiency = 0.76
    if hpxml_file == 'base-dhw-tank-gas-outside.xml'
      hpxml.water_heating_systems[0].location = "other exterior"
    end
  elsif ['base-dhw-tank-wood.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fuel_type = "wood"
    hpxml.water_heating_systems[0].tank_volume = 50
    hpxml.water_heating_systems[0].heating_capacity = 40000
    hpxml.water_heating_systems[0].energy_factor = 0.59
    hpxml.water_heating_systems[0].recovery_efficiency = 0.76
  elsif ['base-dhw-tank-heat-pump.xml',
         'base-dhw-tank-heat-pump-outside.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].water_heater_type = "heat pump water heater"
    hpxml.water_heating_systems[0].tank_volume = 80
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].energy_factor = 2.3
    if hpxml_file == 'base-dhw-tank-heat-pump-outside.xml'
      hpxml.water_heating_systems[0].location = "other exterior"
    end
  elsif ['base-dhw-tankless-electric.xml',
         'base-dhw-tankless-electric-outside.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].water_heater_type = "instantaneous water heater"
    hpxml.water_heating_systems[0].tank_volume = nil
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].energy_factor = 0.99
    if hpxml_file == 'base-dhw-tankless-electric-outside.xml'
      hpxml.water_heating_systems[0].location = "other exterior"
    end
  elsif ['base-dhw-tankless-gas.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fuel_type = "natural gas"
    hpxml.water_heating_systems[0].water_heater_type = "instantaneous water heater"
    hpxml.water_heating_systems[0].tank_volume = nil
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].energy_factor = 0.82
  elsif ['base-dhw-tankless-oil.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fuel_type = "fuel oil"
    hpxml.water_heating_systems[0].water_heater_type = "instantaneous water heater"
    hpxml.water_heating_systems[0].tank_volume = nil
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].energy_factor = 0.82
  elsif ['base-dhw-tankless-propane.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fuel_type = "propane"
    hpxml.water_heating_systems[0].water_heater_type = "instantaneous water heater"
    hpxml.water_heating_systems[0].tank_volume = nil
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].energy_factor = 0.82
  elsif ['base-dhw-tankless-wood.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fuel_type = "wood"
    hpxml.water_heating_systems[0].water_heater_type = "instantaneous water heater"
    hpxml.water_heating_systems[0].tank_volume = nil
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].energy_factor = 0.82
  elsif ['base-dhw-tank-oil.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fuel_type = "fuel oil"
    hpxml.water_heating_systems[0].tank_volume = 50
    hpxml.water_heating_systems[0].heating_capacity = 40000
    hpxml.water_heating_systems[0].energy_factor = 0.59
    hpxml.water_heating_systems[0].recovery_efficiency = 0.76
  elsif ['base-dhw-tank-propane.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fuel_type = "propane"
    hpxml.water_heating_systems[0].tank_volume = 50
    hpxml.water_heating_systems[0].heating_capacity = 40000
    hpxml.water_heating_systems[0].energy_factor = 0.59
    hpxml.water_heating_systems[0].recovery_efficiency = 0.76
  elsif ['base-dhw-uef.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].energy_factor = nil
    hpxml.water_heating_systems[0].uniform_energy_factor = 0.93
  elsif ['base-dhw-desuperheater.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].uses_desuperheater = true
    hpxml.water_heating_systems[0].related_hvac = "CoolingSystem"
  elsif ['base-dhw-desuperheater-tankless.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].water_heater_type = "instantaneous water heater"
    hpxml.water_heating_systems[0].tank_volume = nil
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].energy_factor = 0.99
    hpxml.water_heating_systems[0].uses_desuperheater = true
    hpxml.water_heating_systems[0].related_hvac = "CoolingSystem"
  elsif ['base-dhw-desuperheater-2-speed.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].uses_desuperheater = true
    hpxml.water_heating_systems[0].related_hvac = "CoolingSystem"
  elsif ['base-dhw-desuperheater-var-speed.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].uses_desuperheater = true
    hpxml.water_heating_systems[0].related_hvac = "CoolingSystem"
  elsif ['base-dhw-desuperheater-gshp.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].uses_desuperheater = true
    hpxml.water_heating_systems[0].related_hvac = "HeatPump"
  elsif ['base-dhw-jacket-electric.xml',
         'base-dhw-jacket-indirect.xml',
         'base-dhw-jacket-gas.xml',
         'base-dhw-jacket-hpwh.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].jacket_r_value = 10.0
  elsif ['base-dhw-indirect.xml',
         'base-dhw-indirect-outside.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].water_heater_type = "space-heating boiler with storage tank"
    hpxml.water_heating_systems[0].tank_volume = 50
    hpxml.water_heating_systems[0].heating_capacity = nil
    hpxml.water_heating_systems[0].energy_factor = nil
    hpxml.water_heating_systems[0].fuel_type = nil
    hpxml.water_heating_systems[0].related_hvac = "HeatingSystem"
    if hpxml_file == 'base-dhw-indirect-outside.xml'
      hpxml.water_heating_systems[0].location = "other exterior"
    end
  elsif ['base-dhw-indirect-standbyloss.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].standby_loss = 1.0
  elsif ['base-dhw-combi-tankless.xml',
         'base-dhw-combi-tankless-outside.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].water_heater_type = "space-heating boiler with tankless coil"
    hpxml.water_heating_systems[0].tank_volume = nil
    if hpxml_file == 'base-dhw-combi-tankless-outside.xml'
      hpxml.water_heating_systems[0].location = "other exterior"
    end
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = "basement - unconditioned"
  elsif ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = "crawlspace - unvented"
  elsif ['base-foundation-vented-crawlspace.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = "crawlspace - vented"
  elsif ['base-foundation-slab.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = "living space"
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = "attic - vented"
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = "basement - conditioned"
  elsif ['invalid_files/water-heater-location.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = "crawlspace - vented"
  elsif ['invalid_files/water-heater-location-other.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = "unconditioned space"
  elsif ['invalid_files/invalid-relatedhvac-desuperheater.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].uses_desuperheater = true
    hpxml.water_heating_systems[0].related_hvac = "CoolingSystem_bad"
  elsif ['invalid_files/repeated-relatedhvac-desuperheater.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fraction_dhw_load_served = 0.5
    hpxml.water_heating_systems[0].uses_desuperheater = true
    hpxml.water_heating_systems[0].related_hvac = "CoolingSystem"
    hpxml.water_heating_systems << hpxml.water_heating_systems[0].dup
    hpxml.water_heating_systems[1].id = "WaterHeater2"
  elsif ['invalid_files/invalid-relatedhvac-dhw-indirect.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].related_hvac = "HeatingSystem_bad"
  elsif ['invalid_files/repeated-relatedhvac-dhw-indirect.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].fraction_dhw_load_served = 0.5
    hpxml.water_heating_systems << hpxml.water_heating_systems[0].dup
    hpxml.water_heating_systems[1].id = "WaterHeater2"
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].location = "garage"
  elsif ['base-dhw-temperature.xml'].include? hpxml_file
    hpxml.water_heating_systems[0].temperature = 130.0
  elsif ['base-dhw-none.xml'].include? hpxml_file
    hpxml.water_heating_systems = []
  end
end

def set_hpxml_hot_water_distribution(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.hot_water_distribution = HPXML::HotWaterDistribution.new({ :id => "HotWaterDstribution",
                                                                     :system_type => "Standard",
                                                                     :standard_piping_length => 50, # Chosen to test a negative EC_adj
                                                                     :pipe_r_value => 0.0 })
  elsif ['base-dhw-dwhr.xml'].include? hpxml_file
    hpxml.hot_water_distribution.dwhr_facilities_connected = "all"
    hpxml.hot_water_distribution.dwhr_equal_flow = true
    hpxml.hot_water_distribution.dwhr_efficiency = 0.55
  elsif ['base-dhw-recirc-demand.xml'].include? hpxml_file
    hpxml.hot_water_distribution.system_type = "Recirculation"
    hpxml.hot_water_distribution.recirculation_control_type = "presence sensor demand control"
    hpxml.hot_water_distribution.recirculation_piping_length = 50
    hpxml.hot_water_distribution.recirculation_branch_piping_length = 50
    hpxml.hot_water_distribution.recirculation_pump_power = 50
    hpxml.hot_water_distribution.pipe_r_value = 3
  elsif ['base-dhw-recirc-manual.xml'].include? hpxml_file
    hpxml.hot_water_distribution.system_type = "Recirculation"
    hpxml.hot_water_distribution.recirculation_control_type = "manual demand control"
    hpxml.hot_water_distribution.recirculation_piping_length = 50
    hpxml.hot_water_distribution.recirculation_branch_piping_length = 50
    hpxml.hot_water_distribution.recirculation_pump_power = 50
    hpxml.hot_water_distribution.pipe_r_value = 3
  elsif ['base-dhw-recirc-nocontrol.xml'].include? hpxml_file
    hpxml.hot_water_distribution.system_type = "Recirculation"
    hpxml.hot_water_distribution.recirculation_control_type = "no control"
    hpxml.hot_water_distribution.recirculation_piping_length = 50
    hpxml.hot_water_distribution.recirculation_branch_piping_length = 50
    hpxml.hot_water_distribution.recirculation_pump_power = 50
  elsif ['base-dhw-recirc-temperature.xml'].include? hpxml_file
    hpxml.hot_water_distribution.system_type = "Recirculation"
    hpxml.hot_water_distribution.recirculation_control_type = "temperature"
    hpxml.hot_water_distribution.recirculation_piping_length = 50
    hpxml.hot_water_distribution.recirculation_branch_piping_length = 50
    hpxml.hot_water_distribution.recirculation_pump_power = 50
  elsif ['base-dhw-recirc-timer.xml'].include? hpxml_file
    hpxml.hot_water_distribution.system_type = "Recirculation"
    hpxml.hot_water_distribution.recirculation_control_type = "timer"
    hpxml.hot_water_distribution.recirculation_piping_length = 50
    hpxml.hot_water_distribution.recirculation_branch_piping_length = 50
    hpxml.hot_water_distribution.recirculation_pump_power = 50
  elsif ['base-dhw-none.xml'].include? hpxml_file
    hpxml.hot_water_distribution = nil
  end
end

def set_hpxml_water_fixtures(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.water_fixtures = [HPXML::WaterFixture.new({ :id => "WaterFixture",
                                                      :water_fixture_type => "shower head",
                                                      :low_flow => true }),
                            HPXML::WaterFixture.new({ :id => "WaterFixture2",
                                                      :water_fixture_type => "faucet",
                                                      :low_flow => false })]
  elsif ['base-dhw-low-flow-fixtures.xml'].include? hpxml_file
    hpxml.water_fixtures[1].low_flow = true
  elsif ['base-dhw-none.xml'].include? hpxml_file
    hpxml.water_fixtures = []
  end
end

def set_hpxml_solar_thermal_system(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.solar_thermal_system = nil
  elsif ['base-dhw-solar-fraction.xml',
         'base-dhw-multiple.xml',
         'base-dhw-tank-heat-pump-with-solar-fraction.xml',
         'base-dhw-tankless-gas-with-solar-fraction.xml',
         'invalid_files/solar-thermal-system-with-combi-tankless.xml',
         'invalid_files/solar-thermal-system-with-desuperheater.xml',
         'invalid_files/solar-thermal-system-with-dhw-indirect.xml'].include? hpxml_file
    hpxml.solar_thermal_system = HPXML::SolarThermalSystem.new({ :id => "SolarThermalSystem",
                                                                 :system_type => "hot water",
                                                                 :water_heating_system_idref => "WaterHeater",
                                                                 :solar_fraction => 0.65 })
  elsif ['base-dhw-solar-direct-flat-plate.xml',
         'base-dhw-solar-indirect-flat-plate.xml',
         'base-dhw-solar-thermosyphon-flat-plate.xml',
         'base-dhw-tank-heat-pump-with-solar.xml',
         'base-dhw-tankless-gas-with-solar.xml'].include? hpxml_file
    hpxml.solar_thermal_system = HPXML::SolarThermalSystem.new({ :id => "SolarThermalSystem",
                                                                 :system_type => "hot water",
                                                                 :collector_area => 40,
                                                                 :collector_type => "single glazing black",
                                                                 :collector_azimuth => 180,
                                                                 :collector_tilt => 20,
                                                                 :collector_frta => 0.77,
                                                                 :collector_frul => 0.793,
                                                                 :storage_volume => 60,
                                                                 :water_heating_system_idref => "WaterHeater" })
    if hpxml_file == 'base-dhw-solar-direct-flat-plate.xml'
      hpxml.solar_thermal_system.collector_loop_type = "liquid direct"
    elsif hpxml_file == 'base-dhw-solar-thermosyphon-flat-plate.xml'
      hpxml.solar_thermal_system.collector_loop_type = "passive thermosyphon"
    else
      hpxml.solar_thermal_system.collector_loop_type = "liquid indirect"
    end
  elsif ['base-dhw-solar-indirect-evacuated-tube.xml',
         'base-dhw-solar-direct-evacuated-tube.xml',
         'base-dhw-solar-thermosyphon-evacuated-tube.xml'].include? hpxml_file
    hpxml.solar_thermal_system = HPXML::SolarThermalSystem.new({ :id => "SolarThermalSystem",
                                                                 :system_type => "hot water",
                                                                 :collector_area => 40,
                                                                 :collector_type => "evacuated tube",
                                                                 :collector_azimuth => 180,
                                                                 :collector_tilt => 20,
                                                                 :collector_frta => 0.50,
                                                                 :collector_frul => 0.2799,
                                                                 :storage_volume => 60,
                                                                 :water_heating_system_idref => "WaterHeater" })
    if hpxml_file == 'base-dhw-solar-direct-evacuated-tube.xml'
      hpxml.solar_thermal_system.collector_loop_type = "liquid direct"
    elsif hpxml_file == 'base-dhw-solar-thermosyphon-evacuated-tube.xml'
      hpxml.solar_thermal_system.collector_loop_type = "passive thermosyphon"
    else
      hpxml.solar_thermal_system.collector_loop_type = "liquid indirect"
    end
  elsif ['base-dhw-solar-direct-ics.xml',
         'base-dhw-solar-thermosyphon-ics.xml'].include? hpxml_file
    hpxml.solar_thermal_system = HPXML::SolarThermalSystem.new({ :id => "SolarThermalSystem",
                                                                 :system_type => "hot water",
                                                                 :collector_area => 40,
                                                                 :collector_type => "integrated collector storage",
                                                                 :collector_azimuth => 180,
                                                                 :collector_tilt => 20,
                                                                 :collector_frta => 0.77,
                                                                 :collector_frul => 0.793,
                                                                 :storage_volume => 60,
                                                                 :water_heating_system_idref => "WaterHeater" })
    if hpxml_file == 'base-dhw-solar-direct-ics.xml'
      hpxml.solar_thermal_system.collector_loop_type = "liquid direct"
    elsif hpxml_file == 'base-dhw-solar-thermosyphon-ics.xml'
      hpxml.solar_thermal_system.collector_loop_type = "passive thermosyphon"
    end
  elsif ['invalid_files/unattached-solar-thermal-system.xml'].include? hpxml_file
    hpxml.solar_thermal_system.water_heating_system_idref = "foobar"
  end
end

def set_hpxml_pv_systems(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.pv_systems = []
  elsif ['base-pv.xml'].include? hpxml_file
    hpxml.pv_systems << HPXML::PVSystem.new({ :id => "PVSystem",
                                              :module_type => "standard",
                                              :location => "roof",
                                              :tracking => "fixed",
                                              :array_azimuth => 180,
                                              :array_tilt => 20,
                                              :max_power_output => 4000,
                                              :inverter_efficiency => 0.96,
                                              :system_losses_fraction => 0.14 })
    hpxml.pv_systems << HPXML::PVSystem.new({ :id => "PVSystem2",
                                              :module_type => "premium",
                                              :location => "roof",
                                              :tracking => "fixed",
                                              :array_azimuth => 90,
                                              :array_tilt => 20,
                                              :max_power_output => 1500,
                                              :inverter_efficiency => 0.96,
                                              :system_losses_fraction => 0.14 })
  end
end

def set_hpxml_clothes_washer(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.clothes_washer = HPXML::ClothesWasher.new({ :id => "ClothesWasher",
                                                      :location => "living space",
                                                      :modified_energy_factor => 0.8,
                                                      :rated_annual_kwh => 700.0,
                                                      :label_electric_rate => 0.10,
                                                      :label_gas_rate => 0.60,
                                                      :label_annual_gas_cost => 25.0,
                                                      :capacity => 3.0 })
  elsif ['base-appliances-none.xml'].include? hpxml_file
    hpxml.clothes_washer = nil
  elsif ['base-appliances-modified.xml'].include? hpxml_file
    hpxml.clothes_washer.modified_energy_factor = nil
    hpxml.clothes_washer.integrated_modified_energy_factor = 0.73
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.clothes_washer.location = "basement - unconditioned"
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.clothes_washer.location = "basement - conditioned"
  elsif ['base-enclosure-garage.xml',
         'invalid_files/clothes-washer-location.xml'].include? hpxml_file
    hpxml.clothes_washer.location = "garage"
  elsif ['invalid_files/clothes-washer-location-other.xml'].include? hpxml_file
    hpxml.clothes_washer.location = "other"
  end
end

def set_hpxml_clothes_dryer(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.clothes_dryer = HPXML::ClothesDryer.new({ :id => "ClothesDryer",
                                                    :location => "living space",
                                                    :fuel_type => "electricity",
                                                    :energy_factor => 2.95,
                                                    :control_type => "timer" })
  elsif ['base-appliances-none.xml'].include? hpxml_file
    hpxml.clothes_dryer = nil
  elsif ['base-appliances-modified.xml'].include? hpxml_file
    hpxml.clothes_dryer = HPXML::ClothesDryer.new({ :id => "ClothesDryer",
                                                    :location => "living space",
                                                    :fuel_type => "electricity",
                                                    :combined_energy_factor => 2.62,
                                                    :control_type => "moisture" })
  elsif ['base-appliances-gas.xml',
         'base-appliances-propane.xml',
         'base-appliances-oil.xml'].include? hpxml_file
    hpxml.clothes_dryer = HPXML::ClothesDryer.new({ :id => "ClothesDryer",
                                                    :location => "living space",
                                                    :energy_factor => 2.67,
                                                    :control_type => "moisture" })
    if hpxml_file == 'base-appliances-gas.xml'
      hpxml.clothes_dryer.fuel_type = "natural gas"
    elsif hpxml_file == 'base-appliances-propane.xml'
      hpxml.clothes_dryer.fuel_type = "propane"
    elsif hpxml_file == 'base-appliances-oil.xml'
      hpxml.clothes_dryer.fuel_type = "fuel oil"
    end
  elsif ['base-appliances-wood.xml'].include? hpxml_file
    hpxml.clothes_dryer = HPXML::ClothesDryer.new({ :id => "ClothesDryer",
                                                    :location => "living space",
                                                    :fuel_type => "wood",
                                                    :energy_factor => 2.67,
                                                    :control_type => "moisture" })
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.clothes_dryer.location = "basement - unconditioned"
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.clothes_dryer.location = "basement - conditioned"
  elsif ['base-enclosure-garage.xml',
         'invalid_files/clothes-dryer-location.xml'].include? hpxml_file
    hpxml.clothes_dryer.location = "garage"
  elsif ['invalid_files/clothes-dryer-location-other.xml'].include? hpxml_file
    hpxml.clothes_dryer.location = "other"
  end
end

def set_hpxml_dishwasher(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.dishwasher = HPXML::Dishwasher.new({ :id => "Dishwasher",
                                               :rated_annual_kwh => 450,
                                               :place_setting_capacity => 12 })
  elsif ['base-appliances-none.xml'].include? hpxml_file
    hpxml.dishwasher = nil
  elsif ['base-appliances-modified.xml'].include? hpxml_file
    hpxml.dishwasher = HPXML::Dishwasher.new({ :id => "Dishwasher",
                                               :energy_factor => 0.5,
                                               :place_setting_capacity => 12 })
  end
end

def set_hpxml_refrigerator(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.refrigerator = HPXML::Refrigerator.new({ :id => "Refrigerator",
                                                   :location => "living space",
                                                   :rated_annual_kwh => 650 })
  elsif ['base-appliances-modified.xml'].include? hpxml_file
    hpxml.refrigerator.adjusted_annual_kwh = 600
  elsif ['base-appliances-none.xml'].include? hpxml_file
    hpxml.refrigerator = nil
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    hpxml.refrigerator.location = "basement - unconditioned"
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    hpxml.refrigerator.location = "basement - conditioned"
  elsif ['base-enclosure-garage.xml',
         'invalid_files/refrigerator-location.xml'].include? hpxml_file
    hpxml.refrigerator.location = "garage"
  elsif ['invalid_files/refrigerator-location-other.xml'].include? hpxml_file
    hpxml.refrigerator.location = "other"
  end
end

def set_hpxml_cooking_range(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.cooking_range = HPXML::CookingRange.new({ :id => "Range",
                                                    :fuel_type => "electricity",
                                                    :is_induction => false })
  elsif ['base-appliances-none.xml'].include? hpxml_file
    hpxml.cooking_range = nil
  elsif ['base-appliances-gas.xml'].include? hpxml_file
    hpxml.cooking_range.fuel_type = "natural gas"
    hpxml.cooking_range.is_induction = false
  elsif ['base-appliances-propane.xml'].include? hpxml_file
    hpxml.cooking_range.fuel_type = "propane"
    hpxml.cooking_range.is_induction = false
  elsif ['base-appliances-oil.xml'].include? hpxml_file
    hpxml.cooking_range.fuel_type = "fuel oil"
  elsif ['base-appliances-wood.xml'].include? hpxml_file
    hpxml.cooking_range.fuel_type = "wood"
    hpxml.cooking_range.is_induction = false
  end
end

def set_hpxml_oven(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.oven = HPXML::Oven.new({ :id => "Oven",
                                   :is_convection => false })
  elsif ['base-appliances-none.xml'].include? hpxml_file
    hpxml.oven = nil
  end
end

def set_hpxml_lighting(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.lighting = HPXML::Lighting.new({ :fraction_tier_i_interior => 0.5,
                                           :fraction_tier_i_exterior => 0.5,
                                           :fraction_tier_i_garage => 0.5,
                                           :fraction_tier_ii_interior => 0.25,
                                           :fraction_tier_ii_exterior => 0.25,
                                           :fraction_tier_ii_garage => 0.25 })
  elsif ['base-misc-lighting-none.xml'].include? hpxml_file
    hpxml.lighting = nil
  end
end

def set_hpxml_ceiling_fans(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.ceiling_fans = []
  elsif ['base-misc-ceiling-fans.xml'].include? hpxml_file
    hpxml.ceiling_fans << HPXML::CeilingFan.new({ :id => "CeilingFan",
                                                  :efficiency => 100,
                                                  :quantity => 2 })
  end
end

def set_hpxml_plug_loads(hpxml_file, hpxml)
  if ['base-misc-loads-detailed.xml'].include? hpxml_file
    hpxml.plug_loads = [HPXML::PlugLoad.new({ :id => "PlugLoadMisc",
                                              :plug_load_type => "other",
                                              :kWh_per_year => 7302,
                                              :frac_sensible => 0.82,
                                              :frac_latent => 0.18 }),
                        HPXML::PlugLoad.new({ :id => "PlugLoadMisc2",
                                              :plug_load_type => "TV other",
                                              :kWh_per_year => 400 })]
  else
    hpxml.plug_loads = [HPXML::PlugLoad.new({ :id => "PlugLoadMisc",
                                              :plug_load_type => "other" }),
                        HPXML::PlugLoad.new({ :id => "PlugLoadMisc2",
                                              :plug_load_type => "TV other" })]
  end
end

def set_hpxml_misc_load_schedule(hpxml_file, hpxml)
  if ['base.xml'].include? hpxml_file
    hpxml.misc_load_schedule = nil
  elsif ['base-misc-loads-detailed.xml'].include? hpxml_file
    hpxml.misc_load_schedule = HPXML::MiscLoads.new({ :weekday_fractions => "0.020, 0.020, 0.020, 0.020, 0.020, 0.034, 0.043, 0.085, 0.050, 0.030, 0.030, 0.041, 0.030, 0.025, 0.026, 0.026, 0.039, 0.042, 0.045, 0.070, 0.070, 0.073, 0.073, 0.066",
                                                      :weekend_fractions => "0.020, 0.020, 0.020, 0.020, 0.020, 0.034, 0.043, 0.085, 0.050, 0.030, 0.030, 0.041, 0.030, 0.025, 0.026, 0.026, 0.039, 0.042, 0.045, 0.070, 0.070, 0.073, 0.073, 0.066",
                                                      :monthly_multipliers => "1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0" })
  end
end

def download_epws
  weather_dir = File.join(File.dirname(__FILE__), "weather")

  require 'net/http'
  require 'tempfile'

  tmpfile = Tempfile.new("epw")

  url = URI.parse("http://s3.amazonaws.com/epwweatherfiles/tmy3s-cache-csv.zip")
  http = Net::HTTP.new(url.host, url.port)

  params = { 'User-Agent' => 'curl/7.43.0', 'Accept-Encoding' => 'identity' }
  request = Net::HTTP::Get.new(url.path, params)
  request.content_type = 'application/zip, application/octet-stream'

  http.request request do |response|
    total = response.header["Content-Length"].to_i
    if total == 0
      fail "Did not successfully download zip file."
    end

    size = 0
    progress = 0
    open tmpfile, 'wb' do |io|
      response.read_body do |chunk|
        io.write chunk
        size += chunk.size
        new_progress = (size * 100) / total
        unless new_progress == progress
          puts "Downloading %s (%3d%%) " % [url.path, new_progress]
        end
        progress = new_progress
      end
    end
  end

  puts "Extracting weather files..."
  unzip_file = OpenStudio::UnzipFile.new(tmpfile.path.to_s)
  unzip_file.extractAllFiles(OpenStudio::toPath(weather_dir))

  num_epws_actual = Dir[File.join(weather_dir, "*.epw")].count
  puts "#{num_epws_actual} weather files are available in the weather directory."
  puts "Completed."
  exit!
end

command_list = [:update_measures, :cache_weather, :create_release_zips, :update_version, :download_weather]

def display_usage(command_list)
  puts "Usage: openstudio #{File.basename(__FILE__)} [COMMAND]\nCommands:\n  " + command_list.join("\n  ")
end

if ARGV.size == 0
  puts "ERROR: Missing command."
  display_usage(command_list)
  exit!
elsif ARGV.size > 1
  puts "ERROR: Too many commands."
  display_usage(command_list)
  exit!
elsif not command_list.include? ARGV[0].to_sym
  puts "ERROR: Invalid command '#{ARGV[0]}'."
  display_usage(command_list)
  exit!
end

if ARGV[0].to_sym == :update_measures
  require 'openstudio'
  require_relative "HPXMLtoOpenStudio/resources/hpxml"

  # Prevent NREL error regarding U: drive when not VPNed in
  ENV['HOME'] = 'C:' if !ENV['HOME'].nil? and ENV['HOME'].start_with? 'U:'
  ENV['HOMEDRIVE'] = 'C:\\' if !ENV['HOMEDRIVE'].nil? and ENV['HOMEDRIVE'].start_with? 'U:'

  # Apply rubocop
  command = "rubocop --auto-correct --format simple --only Layout"
  puts "Applying rubocop style to measures..."
  system(command)

  # Update measures XMLs
  command = "#{OpenStudio.getOpenStudioCLI} measure -t '#{File.dirname(__FILE__)}'"
  puts "Updating measure.xmls..."
  system(command, [:out, :err] => File::NULL)

  create_hpxmls

  puts "Done."
end

if ARGV[0].to_sym == :cache_weather
  require 'openstudio'
  require_relative 'HPXMLtoOpenStudio/resources/weather'

  OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Fatal)
  runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
  puts "Creating cache *.csv for weather files..."

  Dir["weather/*.epw"].each do |epw|
    next if File.exists? epw.gsub(".epw", ".cache")

    puts "Processing #{epw}..."
    model = OpenStudio::Model::Model.new
    epw_file = OpenStudio::EpwFile.new(epw)
    OpenStudio::Model::WeatherFile.setWeatherFile(model, epw_file).get
    weather = WeatherProcess.new(model, runner)
    File.open(epw.gsub(".epw", "-cache.csv"), "wb") do |file|
      weather.dump_to_csv(file)
    end
  end
end

if ARGV[0].to_sym == :download_weather
  download_epws
end

if ARGV[0].to_sym == :update_version
  version_change = { :from => "0.7.0",
                     :to => "0.8.0" }

  file_names = ['workflow/run_simulation.rb']

  file_names.each do |file_name|
    text = File.read(file_name)
    new_contents = text.gsub(version_change[:from], version_change[:to])

    # To write changes to the file, use:
    File.open(file_name, "w") { |file| file.puts new_contents }
  end

  puts "Done. Now check all changed files before committing."
end

if ARGV[0].to_sym == :create_release_zips
  require 'openstudio'

  # Generate documentation
  puts "Generating documentation..."
  command = "sphinx-build -b singlehtml docs/source documentation"
  begin
    `#{command}`
    if not File.exists? File.join(File.dirname(__FILE__), "documentation", "index.html")
      puts "Documentation was not successfully generated. Aborting..."
      exit!
    end
  rescue
    puts "Command failed: '#{command}'. Perhaps sphinx needs to be installed?"
    exit!
  end

  files = ["HPXMLtoOpenStudio/measure.*",
           "HPXMLtoOpenStudio/resources/*.*",
           "SimulationOutputReport/measure.*",
           "SimulationOutputReport/resources/*.*",
           "weather/*.*",
           "workflow/*.*",
           "workflow/sample_files/*.xml",
           "documentation/index.html",
           "documentation/_static/**/*.*"]

  # Only include files under git version control
  command = "git ls-files"
  begin
    git_files = `#{command}`
  rescue
    puts "Command failed: '#{command}'. Perhaps git needs to be installed?"
    exit!
  end

  release_map = { File.join(File.dirname(__FILE__), "release-minimal.zip") => false,
                  File.join(File.dirname(__FILE__), "release-full.zip") => true }

  release_map.keys.each do |zip_path|
    File.delete(zip_path) if File.exists? zip_path
  end

  # Check if we need to download weather files for the full release zip
  num_epws_expected = File.readlines(File.join("weather", "data.csv")).size - 1
  num_epws_local = 0
  files.each do |f|
    Dir[f].each do |file|
      next unless file.end_with? ".epw"

      num_epws_local += 1
    end
  end

  # Make sure we have the full set of weather files
  if num_epws_local < num_epws_expected
    puts "Fetching all weather files..."
    command = "#{OpenStudio.getOpenStudioCLI} #{__FILE__} download_weather"
    log = `#{command}`
  end

  # Create zip files
  release_map.each do |zip_path, include_all_epws|
    puts "Creating #{zip_path}..."
    zip = OpenStudio::ZipFile.new(zip_path, false)
    files.each do |f|
      Dir[f].each do |file|
        if file.start_with? "documentation"
          # always include
        elsif include_all_epws
          if not git_files.include? file and not file.start_with? "weather"
            next
          end
        else
          if not git_files.include? file
            next
          end
        end

        zip.addFile(file, File.join("OpenStudio-HPXML", file))
      end
    end
    puts "Wrote file at #{zip_path}."
  end

  # Cleanup
  FileUtils.rm_r(File.join(File.dirname(__FILE__), "documentation"))

  puts "Done."
end
