require 'rake'
require 'rake/testtask'
require 'ci/reporter/rake/minitest'
require_relative "resources/hpxml"

desc 'update all measures'
task :update_measures do
  # Prevent NREL error regarding U: drive when not VPNed in
  ENV['HOME'] = 'C:' if !ENV['HOME'].nil? and ENV['HOME'].start_with? 'U:'
  ENV['HOMEDRIVE'] = 'C:\\' if !ENV['HOMEDRIVE'].nil? and ENV['HOMEDRIVE'].start_with? 'U:'

  # Apply rubocop
  command = "rubocop --auto-correct --format simple --only Layout"
  puts "Applying rubocop style to measures..."
  system(command)

  create_hpxmls

  puts "Done."
end

def create_hpxmls
  this_dir = File.dirname(__FILE__)
  tests_dir = File.join(this_dir, "tests")

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
    'invalid_files/hvac-distribution-multiple-attached-cooling.xml' => 'base-hvac-multiple.xml',
    'invalid_files/hvac-distribution-multiple-attached-heating.xml' => 'base-hvac-multiple.xml',
    'invalid_files/hvac-frac-load-served.xml' => 'base-hvac-multiple.xml',
    'invalid_files/missing-elements.xml' => 'base.xml',
    'invalid_files/missing-surfaces.xml' => 'base.xml',
    'invalid_files/net-area-negative-roof.xml' => 'base-enclosure-skylights.xml',
    'invalid_files/net-area-negative-wall.xml' => 'base.xml',
    'invalid_files/refrigerator-location.xml' => 'base.xml',
    'invalid_files/refrigerator-location-other.xml' => 'base.xml',
    'invalid_files/unattached-cfis.xml' => 'base.xml',
    'invalid_files/unattached-door.xml' => 'base.xml',
    'invalid_files/unattached-hvac-distribution.xml' => 'base.xml',
    'invalid_files/unattached-skylight.xml' => 'base-enclosure-skylights.xml',
    'invalid_files/unattached-window.xml' => 'base.xml',
    'invalid_files/water-heater-location.xml' => 'base.xml',
    'invalid_files/water-heater-location-other.xml' => 'base.xml',

    'base-addenda-exclude-g.xml' => 'base.xml',
    'base-addenda-exclude-g-e.xml' => 'base.xml',
    'base-addenda-exclude-g-e-a.xml' => 'base.xml',
    'base-appliances-dishwasher-ef.xml' => 'base.xml',
    'base-appliances-dryer-cef.xml' => 'base.xml',
    'base-appliances-gas.xml' => 'base.xml',
    'base-appliances-none.xml' => 'base.xml',
    'base-appliances-washer-imef.xml' => 'base.xml',
    'base-atticroof-cathedral.xml' => 'base.xml',
    'base-atticroof-conditioned.xml' => 'base.xml',
    'base-atticroof-flat.xml' => 'base.xml',
    'base-atticroof-vented.xml' => 'base.xml',
    'base-dhw-dwhr.xml' => 'base.xml',
    'base-dhw-low-flow-fixtures.xml' => 'base.xml',
    'base-dhw-multiple.xml' => 'base.xml',
    'base-dhw-none.xml' => 'base.xml',
    'base-dhw-recirc-demand.xml' => 'base.xml',
    'base-dhw-recirc-manual.xml' => 'base.xml',
    'base-dhw-recirc-nocontrol.xml' => 'base.xml',
    'base-dhw-recirc-temperature.xml' => 'base.xml',
    'base-dhw-recirc-timer.xml' => 'base.xml',
    'base-dhw-tank-gas.xml' => 'base.xml',
    'base-dhw-tank-heat-pump.xml' => 'base.xml',
    'base-dhw-tankless-electric.xml' => 'base.xml',
    'base-dhw-tankless-gas.xml' => 'base.xml',
    'base-dhw-tankless-oil.xml' => 'base.xml',
    'base-dhw-tankless-propane.xml' => 'base.xml',
    'base-dhw-tank-oil.xml' => 'base.xml',
    'base-dhw-tank-propane.xml' => 'base.xml',
    'base-dhw-uef.xml' => 'base.xml',
    'base-enclosure-2stories.xml' => 'base.xml',
    'base-enclosure-2stories-garage.xml' => 'base-enclosure-2stories.xml',
    'base-enclosure-garage.xml' => 'base.xml',
    'base-enclosure-infil-cfm50.xml' => 'base.xml',
    'base-enclosure-no-natural-ventilation.xml' => 'base.xml',
    'base-enclosure-overhangs.xml' => 'base.xml',
    'base-enclosure-skylights.xml' => 'base.xml',
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
    'base-enclosure-windows-interior-shading.xml' => 'base.xml',
    'base-foundation-multiple.xml' => 'base-foundation-unconditioned-basement.xml',
    'base-foundation-pier-beam.xml' => 'base.xml',
    'base-foundation-slab.xml' => 'base.xml',
    'base-foundation-unconditioned-basement.xml' => 'base.xml',
    'base-foundation-unconditioned-basement-assembly-r.xml' => 'base-foundation-unconditioned-basement.xml',
    'base-foundation-unconditioned-basement-above-grade.xml' => 'base-foundation-unconditioned-basement.xml',
    'base-foundation-unvented-crawlspace.xml' => 'base.xml',
    'base-foundation-vented-crawlspace.xml' => 'base.xml',
    'base-foundation-multiple-slab.xml' => 'base.xml',
    'base-hvac-air-to-air-heat-pump-1-speed.xml' => 'base.xml',
    'base-hvac-air-to-air-heat-pump-2-speed.xml' => 'base.xml',
    'base-hvac-air-to-air-heat-pump-var-speed.xml' => 'base.xml',
    'base-hvac-boiler-elec-only.xml' => 'base.xml',
    'base-hvac-boiler-gas-central-ac-1-speed.xml' => 'base.xml',
    'base-hvac-boiler-gas-only.xml' => 'base.xml',
    'base-hvac-boiler-gas-only-no-eae.xml' => 'base-hvac-boiler-gas-only.xml',
    'base-hvac-boiler-oil-only.xml' => 'base.xml',
    'base-hvac-boiler-propane-only.xml' => 'base.xml',
    'base-hvac-central-ac-only-1-speed.xml' => 'base.xml',
    'base-hvac-central-ac-only-2-speed.xml' => 'base.xml',
    'base-hvac-central-ac-only-var-speed.xml' => 'base.xml',
    'base-hvac-dse.xml' => 'base.xml',
    'base-hvac-ducts-in-conditioned-space.xml' => 'base.xml',
    'base-hvac-elec-resistance-only.xml' => 'base.xml',
    'base-hvac-furnace-elec-only.xml' => 'base.xml',
    'base-hvac-furnace-gas-central-ac-2-speed.xml' => 'base.xml',
    'base-hvac-furnace-gas-central-ac-var-speed.xml' => 'base.xml',
    'base-hvac-furnace-gas-only.xml' => 'base.xml',
    'base-hvac-furnace-gas-only-no-eae.xml' => 'base-hvac-furnace-gas-only.xml',
    'base-hvac-furnace-gas-room-ac.xml' => 'base.xml',
    'base-hvac-furnace-oil-only.xml' => 'base.xml',
    'base-hvac-furnace-propane-only.xml' => 'base.xml',
    'base-hvac-ground-to-air-heat-pump.xml' => 'base.xml',
    'base-hvac-ideal-air.xml' => 'base.xml',
    'base-hvac-mini-split-heat-pump-ducted.xml' => 'base.xml',
    'base-hvac-mini-split-heat-pump-ductless.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'base-hvac-mini-split-heat-pump-ductless-no-backup.xml' => 'base-hvac-mini-split-heat-pump-ductless.xml',
    'base-hvac-multiple.xml' => 'base.xml',
    'base-hvac-multiple-ducts.xml' => 'base.xml',
    'base-hvac-none.xml' => 'base.xml',
    'base-hvac-none-no-fuel-access.xml' => 'base-hvac-none.xml',
    'base-hvac-programmable-thermostat.xml' => 'base.xml',
    'base-hvac-room-ac-furnace-gas.xml' => 'base.xml',
    'base-hvac-room-ac-only.xml' => 'base.xml',
    'base-hvac-setpoints.xml' => 'base.xml',
    'base-hvac-stove-oil-only.xml' => 'base.xml',
    'base-hvac-stove-oil-only-no-eae.xml' => 'base-hvac-stove-oil-only.xml',
    'base-hvac-wall-furnace-elec-only.xml' => 'base.xml',
    'base-hvac-wall-furnace-propane-only.xml' => 'base.xml',
    'base-hvac-wall-furnace-propane-only-no-eae.xml' => 'base-hvac-wall-furnace-propane-only.xml',
    'base-infiltration-ach-natural.xml' => 'base.xml',
    'base-mechvent-balanced.xml' => 'base.xml',
    'base-mechvent-cfis.xml' => 'base.xml',
    'base-mechvent-erv.xml' => 'base.xml',
    'base-mechvent-exhaust.xml' => 'base.xml',
    'base-mechvent-hrv.xml' => 'base.xml',
    'base-mechvent-supply.xml' => 'base.xml',
    'base-misc-ceiling-fans.xml' => 'base.xml',
    'base-misc-lighting-none.xml' => 'base.xml',
    'base-misc-loads-detailed.xml' => 'base.xml',
    'base-misc-number-of-occupants.xml' => 'base.xml',
    'base-pv-array-1axis.xml' => 'base.xml',
    'base-pv-array-1axis-backtracked.xml' => 'base.xml',
    'base-pv-array-2axis.xml' => 'base.xml',
    'base-pv-array-fixed-open-rack.xml' => 'base.xml',
    'base-pv-module-premium.xml' => 'base.xml',
    'base-pv-module-standard.xml' => 'base.xml',
    'base-pv-module-thinfilm.xml' => 'base.xml',
    'base-pv-multiple.xml' => 'base.xml',
    'base-site-neighbors.xml' => 'base.xml',

    'cfis/base-cfis.xml' => 'base.xml',
    'cfis/base-hvac-air-to-air-heat-pump-1-speed-cfis.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'cfis/base-hvac-air-to-air-heat-pump-2-speed-cfis.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'cfis/base-hvac-air-to-air-heat-pump-var-speed-cfis.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'cfis/base-hvac-boiler-gas-central-ac-1-speed-cfis.xml' => 'base-hvac-boiler-gas-central-ac-1-speed.xml',
    'cfis/base-hvac-central-ac-only-1-speed-cfis.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'cfis/base-hvac-central-ac-only-2-speed-cfis.xml' => 'base-hvac-central-ac-only-2-speed.xml',
    'cfis/base-hvac-central-ac-only-var-speed-cfis.xml' => 'base-hvac-central-ac-only-var-speed.xml',
    'cfis/base-hvac-dse-cfis.xml' => 'base-hvac-dse.xml',
    'cfis/base-hvac-ducts-in-conditioned-space-cfis.xml' => 'base-hvac-ducts-in-conditioned-space.xml',
    'cfis/base-hvac-furnace-elec-only-cfis.xml' => 'base-hvac-furnace-elec-only.xml',
    'cfis/base-hvac-furnace-gas-central-ac-2-speed-cfis.xml' => 'base-hvac-furnace-gas-central-ac-2-speed.xml',
    'cfis/base-hvac-furnace-gas-central-ac-var-speed-cfis.xml' => 'base-hvac-furnace-gas-central-ac-var-speed.xml',
    'cfis/base-hvac-furnace-gas-only-cfis.xml' => 'base-hvac-furnace-gas-only.xml',
    'cfis/base-hvac-furnace-gas-room-ac-cfis.xml' => 'base-hvac-furnace-gas-room-ac.xml',
    'cfis/base-hvac-ground-to-air-heat-pump-cfis.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'cfis/base-hvac-room-ac-furnace-gas-cfis.xml' => 'base-hvac-room-ac-furnace-gas.xml',

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
    'hvac_autosizing/base-hvac-elec-resistance-only-autosize.xml' => 'base-hvac-elec-resistance-only.xml',
    'hvac_autosizing/base-hvac-furnace-elec-only-autosize.xml' => 'base-hvac-furnace-elec-only.xml',
    'hvac_autosizing/base-hvac-furnace-gas-central-ac-2-speed-autosize.xml' => 'base-hvac-furnace-gas-central-ac-2-speed.xml',
    'hvac_autosizing/base-hvac-furnace-gas-central-ac-var-speed-autosize.xml' => 'base-hvac-furnace-gas-central-ac-var-speed.xml',
    'hvac_autosizing/base-hvac-furnace-gas-only-autosize.xml' => 'base-hvac-furnace-gas-only.xml',
    'hvac_autosizing/base-hvac-furnace-gas-room-ac-autosize.xml' => 'base-hvac-furnace-gas-room-ac.xml',
    'hvac_autosizing/base-hvac-ground-to-air-heat-pump-autosize.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'hvac_autosizing/base-hvac-mini-split-heat-pump-ducted-autosize.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_autosizing/base-hvac-mini-split-heat-pump-ductless-autosize.xml' => 'base-hvac-mini-split-heat-pump-ductless.xml',
    'hvac_autosizing/base-hvac-room-ac-furnace-gas-autosize.xml' => 'base-hvac-room-ac-furnace-gas.xml',
    'hvac_autosizing/base-hvac-room-ac-only-autosize.xml' => 'base-hvac-room-ac-only.xml',
    'hvac_autosizing/base-hvac-stove-oil-only-autosize.xml' => 'base-hvac-stove-oil-only.xml',
    'hvac_autosizing/base-hvac-wall-furnace-elec-only-autosize.xml' => 'base-hvac-wall-furnace-elec-only.xml',
    'hvac_autosizing/base-hvac-wall-furnace-propane-only-autosize.xml' => 'base-hvac-wall-furnace-propane-only.xml',

    'hvac_base/base-base.xml' => 'base.xml',
    'hvac_base/base-hvac-air-to-air-heat-pump-1-speed-base.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_base/base-hvac-air-to-air-heat-pump-2-speed-base.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_base/base-hvac-air-to-air-heat-pump-var-speed-base.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_base/base-hvac-boiler-elec-only-base.xml' => 'base-hvac-boiler-elec-only.xml',
    'hvac_base/base-hvac-boiler-gas-only-base.xml' => 'base-hvac-boiler-gas-only.xml',
    'hvac_base/base-hvac-central-ac-only-1-speed-base.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'hvac_base/base-hvac-central-ac-only-2-speed-base.xml' => 'base-hvac-central-ac-only-2-speed.xml',
    'hvac_base/base-hvac-central-ac-only-var-speed-base.xml' => 'base-hvac-central-ac-only-var-speed.xml',
    'hvac_base/base-hvac-elec-resistance-only-base.xml' => 'base-hvac-elec-resistance-only.xml',
    'hvac_base/base-hvac-furnace-elec-only-base.xml' => 'base-hvac-furnace-elec-only.xml',
    'hvac_base/base-hvac-furnace-gas-central-ac-2-speed-base.xml' => 'base-hvac-furnace-gas-central-ac-2-speed.xml',
    'hvac_base/base-hvac-furnace-gas-central-ac-var-speed-base.xml' => 'base-hvac-furnace-gas-central-ac-var-speed.xml',
    'hvac_base/base-hvac-furnace-gas-only-base.xml' => 'base-hvac-furnace-gas-only.xml',
    'hvac_base/base-hvac-furnace-gas-room-ac-base.xml' => 'base-hvac-furnace-gas-room-ac.xml',
    'hvac_base/base-hvac-ground-to-air-heat-pump-base.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'hvac_base/base-hvac-mini-split-heat-pump-ducted-base.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_base/base-hvac-mini-split-heat-pump-ductless-base.xml' => 'base-hvac-mini-split-heat-pump-ductless.xml',
    'hvac_base/base-hvac-room-ac-only-base.xml' => 'base-hvac-room-ac-only.xml',
    'hvac_base/base-hvac-stove-oil-only-base.xml' => 'base-hvac-stove-oil-only.xml',
    'hvac_base/base-hvac-wall-furnace-elec-only-base.xml' => 'base-hvac-wall-furnace-elec-only.xml',
    'hvac_base/base-hvac-wall-furnace-propane-only-base.xml' => 'base-hvac-wall-furnace-propane-only.xml',

    'hvac_dse/base-dse-0.8.xml' => 'base.xml',
    'hvac_dse/base-hvac-air-to-air-heat-pump-1-speed-dse-0.8.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_dse/base-hvac-air-to-air-heat-pump-2-speed-dse-0.8.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_dse/base-hvac-air-to-air-heat-pump-var-speed-dse-0.8.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_dse/base-hvac-boiler-elec-only-dse-0.8.xml' => 'base-hvac-boiler-elec-only.xml',
    'hvac_dse/base-hvac-boiler-gas-only-dse-0.8.xml' => 'base-hvac-boiler-gas-only.xml',
    'hvac_dse/base-hvac-central-ac-only-1-speed-dse-0.8.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'hvac_dse/base-hvac-central-ac-only-2-speed-dse-0.8.xml' => 'base-hvac-central-ac-only-2-speed.xml',
    'hvac_dse/base-hvac-central-ac-only-var-speed-dse-0.8.xml' => 'base-hvac-central-ac-only-var-speed.xml',
    'hvac_dse/base-hvac-furnace-elec-only-dse-0.8.xml' => 'base-hvac-furnace-elec-only.xml',
    'hvac_dse/base-hvac-furnace-gas-central-ac-2-speed-dse-0.8.xml' => 'base-hvac-furnace-gas-central-ac-2-speed.xml',
    'hvac_dse/base-hvac-furnace-gas-central-ac-var-speed-dse-0.8.xml' => 'base-hvac-furnace-gas-central-ac-var-speed.xml',
    'hvac_dse/base-hvac-furnace-gas-only-dse-0.8.xml' => 'base-hvac-furnace-gas-only.xml',
    'hvac_dse/base-hvac-furnace-gas-room-ac-dse-0.8.xml' => 'base-hvac-furnace-gas-room-ac.xml',
    'hvac_dse/base-hvac-ground-to-air-heat-pump-dse-0.8.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'hvac_dse/base-hvac-mini-split-heat-pump-ducted-dse-0.8.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',

    'hvac_load_fracs/base-hvac-air-to-air-heat-pump-1-speed-zero-cool.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_load_fracs/base-hvac-air-to-air-heat-pump-1-speed-zero-heat.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_load_fracs/base-hvac-air-to-air-heat-pump-1-speed-zero-heat-cool.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_load_fracs/base-hvac-air-to-air-heat-pump-2-speed-zero-cool.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_load_fracs/base-hvac-air-to-air-heat-pump-2-speed-zero-heat.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_load_fracs/base-hvac-air-to-air-heat-pump-2-speed-zero-heat-cool.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_load_fracs/base-hvac-air-to-air-heat-pump-var-speed-zero-cool.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_load_fracs/base-hvac-air-to-air-heat-pump-var-speed-zero-heat.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_load_fracs/base-hvac-air-to-air-heat-pump-var-speed-zero-heat-cool.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_load_fracs/base-hvac-boiler-elec-only-zero-heat.xml' => 'base-hvac-boiler-elec-only.xml',
    'hvac_load_fracs/base-hvac-boiler-gas-only-zero-heat.xml' => 'base-hvac-boiler-gas-only.xml',
    'hvac_load_fracs/base-hvac-central-ac-only-1-speed-zero-cool.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'hvac_load_fracs/base-hvac-central-ac-only-2-speed-zero-cool.xml' => 'base-hvac-central-ac-only-2-speed.xml',
    'hvac_load_fracs/base-hvac-central-ac-only-var-speed-zero-cool.xml' => 'base-hvac-central-ac-only-var-speed.xml',
    'hvac_load_fracs/base-hvac-elec-resistance-only-zero-heat.xml' => 'base-hvac-elec-resistance-only.xml',
    'hvac_load_fracs/base-hvac-furnace-elec-only-zero-heat.xml' => 'base-hvac-furnace-elec-only.xml',
    'hvac_load_fracs/base-hvac-furnace-gas-only-zero-heat.xml' => 'base-hvac-furnace-gas-only.xml',
    'hvac_load_fracs/base-hvac-ground-to-air-heat-pump-zero-cool.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'hvac_load_fracs/base-hvac-ground-to-air-heat-pump-zero-heat.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'hvac_load_fracs/base-hvac-ground-to-air-heat-pump-zero-heat-cool.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'hvac_load_fracs/base-hvac-mini-split-heat-pump-ducted-zero-cool.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_load_fracs/base-hvac-mini-split-heat-pump-ducted-zero-heat.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_load_fracs/base-hvac-mini-split-heat-pump-ducted-zero-heat-cool.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_load_fracs/base-hvac-mini-split-heat-pump-ductless-zero-cool.xml' => 'base-hvac-mini-split-heat-pump-ductless.xml',
    'hvac_load_fracs/base-hvac-mini-split-heat-pump-ductless-zero-heat.xml' => 'base-hvac-mini-split-heat-pump-ductless.xml',
    'hvac_load_fracs/base-hvac-mini-split-heat-pump-ductless-zero-heat-cool.xml' => 'base-hvac-mini-split-heat-pump-ductless.xml',
    'hvac_load_fracs/base-hvac-room-ac-only-zero-cool.xml' => 'base-hvac-room-ac-only.xml',
    'hvac_load_fracs/base-hvac-stove-oil-only-zero-heat.xml' => 'base-hvac-stove-oil-only.xml',
    'hvac_load_fracs/base-hvac-wall-furnace-elec-only-zero-heat.xml' => 'base-hvac-wall-furnace-elec-only.xml',
    'hvac_load_fracs/base-hvac-wall-furnace-propane-only-zero-heat.xml' => 'base-hvac-wall-furnace-propane-only.xml',

    'hvac_multiple/base-hvac-air-to-air-heat-pump-1-speed-x3.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_multiple/base-hvac-air-to-air-heat-pump-2-speed-x3.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_multiple/base-hvac-air-to-air-heat-pump-var-speed-x3.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_multiple/base-hvac-boiler-elec-only-x3.xml' => 'base-hvac-boiler-elec-only.xml',
    'hvac_multiple/base-hvac-boiler-gas-only-x3.xml' => 'base-hvac-boiler-gas-only.xml',
    'hvac_multiple/base-hvac-central-ac-only-1-speed-x3.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'hvac_multiple/base-hvac-central-ac-only-2-speed-x3.xml' => 'base-hvac-central-ac-only-2-speed.xml',
    'hvac_multiple/base-hvac-central-ac-only-var-speed-x3.xml' => 'base-hvac-central-ac-only-var-speed.xml',
    'hvac_multiple/base-hvac-elec-resistance-only-x3.xml' => 'base-hvac-elec-resistance-only.xml',
    'hvac_multiple/base-hvac-furnace-elec-only-x3.xml' => 'base-hvac-furnace-elec-only.xml',
    'hvac_multiple/base-hvac-furnace-gas-only-x3.xml' => 'base-hvac-furnace-gas-only.xml',
    'hvac_multiple/base-hvac-ground-to-air-heat-pump-x3.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'hvac_multiple/base-hvac-mini-split-heat-pump-ducted-x3.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_multiple/base-hvac-mini-split-heat-pump-ductless-x3.xml' => 'base-hvac-mini-split-heat-pump-ductless.xml',
    'hvac_multiple/base-hvac-room-ac-only-x3.xml' => 'base-hvac-room-ac-only.xml',
    'hvac_multiple/base-hvac-stove-oil-only-x3.xml' => 'base-hvac-stove-oil-only.xml',
    'hvac_multiple/base-hvac-wall-furnace-elec-only-x3.xml' => 'base-hvac-wall-furnace-elec-only.xml',
    'hvac_multiple/base-hvac-wall-furnace-propane-only-x3.xml' => 'base-hvac-wall-furnace-propane-only.xml',

    'hvac_partial/base-50percent.xml' => 'base.xml',
    'hvac_partial/base-hvac-air-to-air-heat-pump-1-speed-50percent.xml' => 'base-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_partial/base-hvac-air-to-air-heat-pump-2-speed-50percent.xml' => 'base-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_partial/base-hvac-air-to-air-heat-pump-var-speed-50percent.xml' => 'base-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_partial/base-hvac-boiler-elec-only-50percent.xml' => 'base-hvac-boiler-elec-only.xml',
    'hvac_partial/base-hvac-boiler-gas-only-50percent.xml' => 'base-hvac-boiler-gas-only.xml',
    'hvac_partial/base-hvac-central-ac-only-1-speed-50percent.xml' => 'base-hvac-central-ac-only-1-speed.xml',
    'hvac_partial/base-hvac-central-ac-only-2-speed-50percent.xml' => 'base-hvac-central-ac-only-2-speed.xml',
    'hvac_partial/base-hvac-central-ac-only-var-speed-50percent.xml' => 'base-hvac-central-ac-only-var-speed.xml',
    'hvac_partial/base-hvac-elec-resistance-only-50percent.xml' => 'base-hvac-elec-resistance-only.xml',
    'hvac_partial/base-hvac-furnace-elec-only-50percent.xml' => 'base-hvac-furnace-elec-only.xml',
    'hvac_partial/base-hvac-furnace-gas-central-ac-2-speed-50percent.xml' => 'base-hvac-furnace-gas-central-ac-2-speed.xml',
    'hvac_partial/base-hvac-furnace-gas-central-ac-var-speed-50percent.xml' => 'base-hvac-furnace-gas-central-ac-var-speed.xml',
    'hvac_partial/base-hvac-furnace-gas-only-50percent.xml' => 'base-hvac-furnace-gas-only.xml',
    'hvac_partial/base-hvac-furnace-gas-room-ac-50percent.xml' => 'base-hvac-furnace-gas-room-ac.xml',
    'hvac_partial/base-hvac-ground-to-air-heat-pump-50percent.xml' => 'base-hvac-ground-to-air-heat-pump.xml',
    'hvac_partial/base-hvac-mini-split-heat-pump-ducted-50percent.xml' => 'base-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_partial/base-hvac-mini-split-heat-pump-ductless-50percent.xml' => 'base-hvac-mini-split-heat-pump-ductless.xml',
    'hvac_partial/base-hvac-room-ac-only-50percent.xml' => 'base-hvac-room-ac-only.xml',
    'hvac_partial/base-hvac-stove-oil-only-50percent.xml' => 'base-hvac-stove-oil-only.xml',
    'hvac_partial/base-hvac-wall-furnace-elec-only-50percent.xml' => 'base-hvac-wall-furnace-elec-only.xml',
    'hvac_partial/base-hvac-wall-furnace-propane-only-50percent.xml' => 'base-hvac-wall-furnace-propane-only.xml',

    'water_heating_multiple/base-dhw-tankless-electric-x3.xml' => 'base-dhw-tankless-electric.xml',
    'water_heating_multiple/base-dhw-tankless-gas-x3.xml' => 'base-dhw-tankless-gas.xml',
    'water_heating_multiple/base-dhw-tankless-oil-x3.xml' => 'base-dhw-tankless-oil.xml',
    'water_heating_multiple/base-dhw-tankless-propane-x3.xml' => 'base-dhw-tankless-propane.xml'
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

      hpxml_values = {}
      site_values = {}
      site_neighbors_values = []
      building_occupancy_values = {}
      building_construction_values = {}
      climate_and_risk_zones_values = {}
      air_infiltration_measurement_values = {}
      attics_values = []
      attics_roofs_values = []
      attics_floors_values = []
      attics_walls_values = []
      foundations_values = []
      foundations_framefloors_values = []
      foundations_walls_values = []
      foundations_slabs_values = []
      garages_values = []
      garages_ceilings_values = []
      garages_walls_values = []
      garages_slabs_values = []
      rim_joists_values = []
      walls_values = []
      windows_values = []
      skylights_values = []
      doors_values = []
      heating_systems_values = []
      cooling_systems_values = []
      heat_pumps_values = []
      hvac_control_values = {}
      hvac_distributions_values = []
      duct_leakage_measurements_values = []
      ducts_values = []
      ventilation_fans_values = []
      water_heating_systems_values = []
      hot_water_distribution_values = {}
      water_fixtures_values = []
      pv_systems_values = []
      clothes_washer_values = {}
      clothes_dryer_values = {}
      dishwasher_values = {}
      refrigerator_values = {}
      cooking_range_values = {}
      oven_values = {}
      lighting_values = {}
      ceiling_fans_values = []
      plug_loads_values = []
      misc_load_schedule_values = {}
      hpxml_files.each do |hpxml_file|
        hpxml_values = get_hpxml_file_hpxml_values(hpxml_file, hpxml_values)
        site_values = get_hpxml_file_site_values(hpxml_file, site_values)
        site_neighbors_values = get_hpxml_file_site_neighbor_values(hpxml_file, site_neighbors_values)
        building_occupancy_values = get_hpxml_file_building_occupancy_values(hpxml_file, building_occupancy_values)
        building_construction_values = get_hpxml_file_building_construction_values(hpxml_file, building_construction_values)
        climate_and_risk_zones_values = get_hpxml_file_climate_and_risk_zones_values(hpxml_file, climate_and_risk_zones_values)
        air_infiltration_measurement_values = get_hpxml_file_air_infiltration_measurement_values(hpxml_file, air_infiltration_measurement_values, building_construction_values)
        attics_values = get_hpxml_file_attics_values(hpxml_file, attics_values)
        attics_roofs_values = get_hpxml_file_attics_roofs_values(hpxml_file, attics_roofs_values)
        attics_floors_values = get_hpxml_file_attics_floors_values(hpxml_file, attics_floors_values)
        attics_walls_values = get_hpxml_file_attics_walls_values(hpxml_file, attics_walls_values)
        foundations_values = get_hpxml_file_foundations_values(hpxml_file, foundations_values)
        foundations_framefloors_values = get_hpxml_file_foundations_framefloors_values(hpxml_file, foundations_framefloors_values)
        foundations_walls_values = get_hpxml_file_foundations_walls_values(hpxml_file, foundations_walls_values)
        foundations_slabs_values = get_hpxml_file_foundations_slabs_values(hpxml_file, foundations_slabs_values)
        garages_values = get_hpxml_file_garages_values(hpxml_file, garages_values)
        garages_ceilings_values = get_hpxml_file_garages_ceilings_values(hpxml_file, garages_ceilings_values)
        garages_walls_values = get_hpxml_file_garages_walls_values(hpxml_file, garages_walls_values)
        garages_slabs_values = get_hpxml_file_garages_slabs_values(hpxml_file, garages_slabs_values)
        rim_joists_values = get_hpxml_file_rim_joists_values(hpxml_file, rim_joists_values)
        walls_values = get_hpxml_file_walls_values(hpxml_file, walls_values)
        windows_values = get_hpxml_file_windows_values(hpxml_file, windows_values)
        skylights_values = get_hpxml_file_skylights_values(hpxml_file, skylights_values)
        doors_values = get_hpxml_file_doors_values(hpxml_file, doors_values)
        heating_systems_values = get_hpxml_file_heating_systems_values(hpxml_file, heating_systems_values)
        cooling_systems_values = get_hpxml_file_cooling_systems_values(hpxml_file, cooling_systems_values)
        heat_pumps_values = get_hpxml_file_heat_pumps_values(hpxml_file, heat_pumps_values)
        hvac_control_values = get_hpxml_file_hvac_control_values(hpxml_file, hvac_control_values)
        hvac_distributions_values = get_hpxml_file_hvac_distributions_values(hpxml_file, hvac_distributions_values)
        duct_leakage_measurements_values = get_hpxml_file_duct_leakage_measurements_values(hpxml_file, duct_leakage_measurements_values)
        ducts_values = get_hpxml_file_ducts_values(hpxml_file, ducts_values)
        ventilation_fans_values = get_hpxml_file_ventilation_fan_values(hpxml_file, ventilation_fans_values)
        water_heating_systems_values = get_hpxml_file_water_heating_system_values(hpxml_file, water_heating_systems_values)
        hot_water_distribution_values = get_hpxml_file_hot_water_distribution_values(hpxml_file, hot_water_distribution_values)
        water_fixtures_values = get_hpxml_file_water_fixtures_values(hpxml_file, water_fixtures_values)
        pv_systems_values = get_hpxml_file_pv_system_values(hpxml_file, pv_systems_values)
        clothes_washer_values = get_hpxml_file_clothes_washer_values(hpxml_file, clothes_washer_values)
        clothes_dryer_values = get_hpxml_file_clothes_dryer_values(hpxml_file, clothes_dryer_values)
        dishwasher_values = get_hpxml_file_dishwasher_values(hpxml_file, dishwasher_values)
        refrigerator_values = get_hpxml_file_refrigerator_values(hpxml_file, refrigerator_values)
        cooking_range_values = get_hpxml_file_cooking_range_values(hpxml_file, cooking_range_values)
        oven_values = get_hpxml_file_oven_values(hpxml_file, oven_values)
        lighting_values = get_hpxml_file_lighting_values(hpxml_file, lighting_values)
        ceiling_fans_values = get_hpxml_file_ceiling_fan_values(hpxml_file, ceiling_fans_values)
        plug_loads_values = get_hpxml_file_plug_loads_values(hpxml_file, plug_loads_values)
        misc_load_schedule_values = get_hpxml_file_misc_load_schedule_values(hpxml_file, misc_load_schedule_values)
      end

      hpxml_doc = HPXML.create_hpxml(**hpxml_values)
      hpxml = hpxml_doc.elements["HPXML"]

      if File.exists? File.join(tests_dir, derivative)
        old_hpxml_doc = XMLHelper.parse_file(File.join(tests_dir, derivative))
        created_date_and_time = HPXML.get_hpxml_values(hpxml: old_hpxml_doc.elements["HPXML"])[:created_date_and_time]
        hpxml.elements["XMLTransactionHeaderInformation/CreatedDateAndTime"].text = created_date_and_time
      end

      HPXML.add_site(hpxml: hpxml, **site_values) unless site_values.nil?
      site_neighbors_values.each do |site_neighbor_values|
        HPXML.add_site_neighbor(hpxml: hpxml, **site_neighbor_values)
      end
      HPXML.add_building_occupancy(hpxml: hpxml, **building_occupancy_values) unless building_occupancy_values.empty?
      HPXML.add_building_construction(hpxml: hpxml, **building_construction_values)
      HPXML.add_climate_and_risk_zones(hpxml: hpxml, **climate_and_risk_zones_values)
      HPXML.add_air_infiltration_measurement(hpxml: hpxml, **air_infiltration_measurement_values)
      attics_values.each_with_index do |attic_values, i|
        attic = HPXML.add_attic(hpxml: hpxml, **attic_values)
        attics_roofs_values[i].each do |attic_roof_values|
          HPXML.add_attic_roof(attic: attic, **attic_roof_values)
        end
        attics_floors_values[i].each do |attic_floor_values|
          HPXML.add_attic_floor(attic: attic, **attic_floor_values)
        end
        attics_walls_values[i].each do |attic_wall_values|
          HPXML.add_attic_wall(attic: attic, **attic_wall_values)
        end
      end
      foundations_values.each_with_index do |foundation_values, i|
        foundation = HPXML.add_foundation(hpxml: hpxml, **foundation_values)
        foundations_framefloors_values[i].each do |foundation_framefloor_values|
          HPXML.add_foundation_framefloor(foundation: foundation, **foundation_framefloor_values)
        end
        foundations_walls_values[i].each do |foundation_wall_values|
          HPXML.add_foundation_wall(foundation: foundation, **foundation_wall_values)
        end
        foundations_slabs_values[i].each do |foundation_slab_values|
          HPXML.add_foundation_slab(foundation: foundation, **foundation_slab_values)
        end
      end
      garages_values.each_with_index do |garage_values, i|
        garage = HPXML.add_garage(hpxml: hpxml, **garage_values)
        garages_ceilings_values[i].each do |garage_ceiling_values|
          HPXML.add_garage_ceiling(garage: garage, **garage_ceiling_values)
        end
        garages_walls_values[i].each do |garage_wall_values|
          HPXML.add_garage_wall(garage: garage, **garage_wall_values)
        end
        garages_slabs_values[i].each do |garage_slab_values|
          HPXML.add_garage_slab(garage: garage, **garage_slab_values)
        end
      end
      rim_joists_values.each do |rim_joist_values|
        HPXML.add_rim_joist(hpxml: hpxml, **rim_joist_values)
      end
      walls_values.each do |wall_values|
        HPXML.add_wall(hpxml: hpxml, **wall_values)
      end
      windows_values.each do |window_values|
        HPXML.add_window(hpxml: hpxml, **window_values)
      end
      skylights_values.each do |skylight_values|
        HPXML.add_skylight(hpxml: hpxml, **skylight_values)
      end
      doors_values.each do |door_values|
        HPXML.add_door(hpxml: hpxml, **door_values)
      end
      heating_systems_values.each do |heating_system_values|
        HPXML.add_heating_system(hpxml: hpxml, **heating_system_values)
      end
      cooling_systems_values.each do |cooling_system_values|
        HPXML.add_cooling_system(hpxml: hpxml, **cooling_system_values)
      end
      heat_pumps_values.each do |heat_pump_values|
        HPXML.add_heat_pump(hpxml: hpxml, **heat_pump_values)
      end
      HPXML.add_hvac_control(hpxml: hpxml, **hvac_control_values) unless hvac_control_values.empty?
      hvac_distributions_values.each_with_index do |hvac_distribution_values, i|
        hvac_distribution = HPXML.add_hvac_distribution(hpxml: hpxml, **hvac_distribution_values)
        air_distribution = hvac_distribution.elements["DistributionSystemType/AirDistribution"]
        next if air_distribution.nil?

        duct_leakage_measurements_values[i].each do |duct_leakage_measurement_values|
          HPXML.add_duct_leakage_measurement(air_distribution: air_distribution, **duct_leakage_measurement_values)
        end
        ducts_values[i].each do |duct_values|
          HPXML.add_ducts(air_distribution: air_distribution, **duct_values)
        end
      end
      ventilation_fans_values.each do |ventilation_fan_values|
        HPXML.add_ventilation_fan(hpxml: hpxml, **ventilation_fan_values)
      end
      water_heating_systems_values.each do |water_heating_system_values|
        HPXML.add_water_heating_system(hpxml: hpxml, **water_heating_system_values)
      end
      HPXML.add_hot_water_distribution(hpxml: hpxml, **hot_water_distribution_values) unless hot_water_distribution_values.empty?
      water_fixtures_values.each do |water_fixture_values|
        HPXML.add_water_fixture(hpxml: hpxml, **water_fixture_values)
      end
      pv_systems_values.each do |pv_system_values|
        HPXML.add_pv_system(hpxml: hpxml, **pv_system_values)
      end
      HPXML.add_clothes_washer(hpxml: hpxml, **clothes_washer_values) unless clothes_washer_values.empty?
      HPXML.add_clothes_dryer(hpxml: hpxml, **clothes_dryer_values) unless clothes_dryer_values.empty?
      HPXML.add_dishwasher(hpxml: hpxml, **dishwasher_values) unless dishwasher_values.empty?
      HPXML.add_refrigerator(hpxml: hpxml, **refrigerator_values) unless refrigerator_values.empty?
      HPXML.add_cooking_range(hpxml: hpxml, **cooking_range_values) unless cooking_range_values.empty?
      HPXML.add_oven(hpxml: hpxml, **oven_values) unless oven_values.empty?
      HPXML.add_lighting(hpxml: hpxml, **lighting_values) unless lighting_values.empty?
      ceiling_fans_values.each do |ceiling_fan_values|
        HPXML.add_ceiling_fan(hpxml: hpxml, **ceiling_fan_values)
      end
      plug_loads_values.each do |plug_load_values|
        HPXML.add_plug_load(hpxml: hpxml, **plug_load_values)
      end
      HPXML.add_misc_loads_schedule(hpxml: hpxml, **misc_load_schedule_values) unless misc_load_schedule_values.empty?

      if ['invalid_files/missing-elements.xml'].include? derivative
        hpxml.elements["Building/BuildingDetails/BuildingSummary/BuildingConstruction"].elements.delete("NumberofConditionedFloors")
        hpxml.elements["Building/BuildingDetails/BuildingSummary/BuildingConstruction"].elements.delete("ConditionedFloorArea")
      end

      hpxml_path = File.join(tests_dir, derivative)

      # Validate file against HPXML schema
      schemas_dir = File.absolute_path(File.join(File.dirname(__FILE__), "hpxml_schemas"))
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
    abs_hpxml_files << File.join(tests_dir, hpxml_file)
    next unless hpxml_file.include? '/'

    dirs << hpxml_file.split('/')[0] + '/'
  end
  dirs.uniq.each do |dir|
    Dir["#{tests_dir}/#{dir}*.xml"].each do |xml|
      next if abs_hpxml_files.include? File.absolute_path(xml)

      puts "Warning: Extra HPXML file found at #{File.absolute_path(xml)}"
    end
  end
end

def get_hpxml_file_hpxml_values(hpxml_file, hpxml_values)
  if ['base.xml'].include? hpxml_file
    hpxml_values = { :xml_type => "HPXML",
                     :xml_generated_by => "Rakefile",
                     :transaction => "create",
                     :software_program_used => nil,
                     :software_program_version => nil,
                     :eri_calculation_version => "2014AEG",
                     :building_id => "MyBuilding",
                     :event_type => "proposed workscope" }
  elsif ['base-addenda-exclude-g.xml'].include? hpxml_file
    hpxml_values[:eri_calculation_version] = "2014AE"
  elsif ['base-addenda-exclude-g-e.xml'].include? hpxml_file
    hpxml_values[:eri_calculation_version] = "2014A"
  elsif ['base-addenda-exclude-g-e-a.xml'].include? hpxml_file
    hpxml_values[:eri_calculation_version] = "2014"
  end
  return hpxml_values
end

def get_hpxml_file_site_values(hpxml_file, site_values)
  if ['base.xml'].include? hpxml_file
    site_values = { :fuels => ["electricity", "natural gas"] }
  elsif ['base-hvac-none-no-fuel-access.xml'].include? hpxml_file
    site_values[:fuels] = ["electricity"]
  elsif ['base-enclosure-no-natural-ventilation.xml'].include? hpxml_file
    site_values[:disable_natural_ventilation] = true
  end
  return site_values
end

def get_hpxml_file_site_neighbor_values(hpxml_file, site_neighbors_values)
  if ['base-site-neighbors.xml'].include? hpxml_file
    site_neighbors_values << { :azimuth => 0,
                               :distance => 10 }
    site_neighbors_values << { :azimuth => 180,
                               :distance => 15 }
  elsif ['invalid_files/bad-site-neighbor-azimuth.xml'].include? hpxml_file
    site_neighbors_values[0][:azimuth] = 145
  end
  return site_neighbors_values
end

def get_hpxml_file_building_occupancy_values(hpxml_file, building_occupancy_values)
  if ['base-misc-number-of-occupants.xml'].include? hpxml_file
    building_occupancy_values = { :number_of_residents => 5 }
  end
  return building_occupancy_values
end

def get_hpxml_file_building_construction_values(hpxml_file, building_construction_values)
  if ['base.xml'].include? hpxml_file
    building_construction_values = { :number_of_conditioned_floors => 2,
                                     :number_of_conditioned_floors_above_grade => 1,
                                     :number_of_bedrooms => 3,
                                     :conditioned_floor_area => 2700,
                                     :conditioned_building_volume => 2700 * 8 }
  elsif ['base-foundation-pier-beam.xml',
         'base-foundation-slab.xml',
         'base-foundation-unconditioned-basement.xml',
         'base-foundation-unvented-crawlspace.xml',
         'base-foundation-vented-crawlspace.xml'].include? hpxml_file or
        hpxml_file.include? 'hvac_partial' or
        hpxml_file.include? 'hvac_multiple' or
        hpxml_file.include? 'hvac_base' or
        hpxml_file.include? 'hvac_dse' or
        hpxml_file.include? 'hvac_load_fracs'
    building_construction_values[:number_of_conditioned_floors] -= 1
    building_construction_values[:conditioned_floor_area] -= 1350
    building_construction_values[:conditioned_building_volume] -= 1350 * 8
  elsif ['base-hvac-ideal-air.xml'].include? hpxml_file
    building_construction_values[:use_only_ideal_air_system] = true
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    building_construction_values[:number_of_conditioned_floors] += 1
    building_construction_values[:number_of_conditioned_floors_above_grade] += 1
    building_construction_values[:conditioned_floor_area] += 900
    building_construction_values[:conditioned_building_volume] += 2250
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    building_construction_values[:conditioned_building_volume] += 10800
  elsif ['base-enclosure-2stories.xml'].include? hpxml_file
    building_construction_values[:number_of_conditioned_floors] += 1
    building_construction_values[:number_of_conditioned_floors_above_grade] += 1
    building_construction_values[:conditioned_floor_area] += 1350
    building_construction_values[:conditioned_building_volume] += 1350 * 8
  end
  return building_construction_values
end

def get_hpxml_file_climate_and_risk_zones_values(hpxml_file, climate_and_risk_zones_values)
  if ['base.xml'].include? hpxml_file
    climate_and_risk_zones_values = { :iecc2006 => "5B",
                                      :iecc2012 => "5B",
                                      :weather_station_id => "WeatherStation",
                                      :weather_station_name => "Denver, CO",
                                      :weather_station_wmo => "725650" }
  elsif ['invalid_files/bad-wmo.xml'].include? hpxml_file
    climate_and_risk_zones_values[:weather_station_wmo] = "999999"
  end
  return climate_and_risk_zones_values
end

def get_hpxml_file_air_infiltration_measurement_values(hpxml_file, air_infiltration_measurement_values, building_construction_values)
  infil_volume = building_construction_values[:conditioned_building_volume]
  if ['base.xml'].include? hpxml_file
    air_infiltration_measurement_values = { :id => "InfiltrationMeasurement",
                                            :house_pressure => 50,
                                            :unit_of_measure => "ACH",
                                            :air_leakage => 3.0 }
  elsif ['base-infiltration-ach-natural.xml'].include? hpxml_file
    air_infiltration_measurement_values = { :id => "InfiltrationMeasurement",
                                            :constant_ach_natural => 0.67 }
  elsif ['base-enclosure-infil-cfm50.xml'].include? hpxml_file
    air_infiltration_measurement_values = { :id => "InfiltrationMeasurement",
                                            :house_pressure => 50,
                                            :unit_of_measure => "CFM",
                                            :air_leakage => 3.0 / 60.0 * infil_volume }
  end
  air_infiltration_measurement_values[:infiltration_volume] = infil_volume
  return air_infiltration_measurement_values
end

def get_hpxml_file_attics_values(hpxml_file, attics_values)
  if ['base.xml'].include? hpxml_file
    attics_values = [{ :id => "Attic",
                       :attic_type => "UnventedAttic" }]
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    attics_values[0][:attic_type] = "VentedAttic"
    attics_values[0][:specific_leakage_area] = 0.003
  elsif ['base-atticroof-flat.xml'].include? hpxml_file
    attics_values[0][:attic_type] = "FlatRoof"
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    attics_values[0][:attic_type] = "ConditionedAttic"
    attics_values << { :id => "AtticBehindKneewall",
                       :attic_type => "UnventedAttic" }
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    attics_values[0][:attic_type] = "CathedralCeiling"
  end
  return attics_values
end

def get_hpxml_file_attics_roofs_values(hpxml_file, attics_roofs_values)
  if ['base.xml'].include? hpxml_file
    attics_roofs_values = [[{ :id => "AtticRoof",
                              :area => 1510,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :pitch => 6,
                              :radiant_barrier => false,
                              :insulation_assembly_r_value => 2.3 }]]
  elsif ['base-atticroof-flat.xml'].include? hpxml_file
    attics_roofs_values = [[{ :id => "AtticRoof",
                              :area => 1350,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :pitch => 0,
                              :radiant_barrier => false,
                              :insulation_assembly_r_value => 25.8 }]]
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    attics_roofs_values = [[{ :id => "AtticRoofCond",
                              :area => 1006,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :pitch => 6,
                              :radiant_barrier => false,
                              :insulation_assembly_r_value => 25.8 }]]
    attics_roofs_values << [{ :id => "AtticRoofUncond",
                              :area => 504,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :pitch => 6,
                              :radiant_barrier => false,
                              :insulation_assembly_r_value => 2.3 }]
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    attics_roofs_values[0][0][:insulation_assembly_r_value] = 25.8
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    attics_roofs_values[0] << { :id => "AtticRoofGarage",
                                :area => 670,
                                :solar_absorptance => 0.75,
                                :emittance => 0.9,
                                :pitch => 6,
                                :radiant_barrier => false,
                                :insulation_assembly_r_value => 2.3 }
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    attics_roofs_values[0][0][:insulation_assembly_r_value] = 25.8
  end
  return attics_roofs_values
end

def get_hpxml_file_attics_floors_values(hpxml_file, attics_floors_values)
  if ['base.xml'].include? hpxml_file
    attics_floors_values = [[{ :id => "AtticFloor",
                               :adjacent_to => "living space",
                               :area => 1350,
                               :insulation_assembly_r_value => 39.3 }]]
  elsif ['base-atticroof-flat.xml',
         'base-atticroof-cathedral.xml'].include? hpxml_file
    attics_floors_values[0].delete_at(0)
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    attics_floors_values = [[{ :id => "AtticFloorCond",
                               :adjacent_to => "living space",
                               :area => 900,
                               :insulation_assembly_r_value => 2.1 }]]
    attics_floors_values << [{ :id => "AtticFloorUncond",
                               :adjacent_to => "living space",
                               :area => 450,
                               :insulation_assembly_r_value => 39.3 }]
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    attics_floors_values[0] << { :id => "AtticFloorGarage",
                                 :adjacent_to => "garage",
                                 :area => 600,
                                 :insulation_assembly_r_value => 2.1 }
  end
  return attics_floors_values
end

def get_hpxml_file_attics_walls_values(hpxml_file, attics_walls_values)
  if ['base.xml'].include? hpxml_file
    attics_walls_values = [[{ :id => "AtticGable",
                              :adjacent_to => "outside",
                              :wall_type => "WoodStud",
                              :area => 290,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_assembly_r_value => 4.0 }]]
  elsif ['base-atticroof-flat.xml'].include? hpxml_file
    attics_walls_values[0].delete_at(0)
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    attics_walls_values = [[{ :id => "AtticGableCond",
                              :adjacent_to => "outside",
                              :wall_type => "WoodStud",
                              :area => 240,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_assembly_r_value => 23.0 },
                            { :id => "AtticKneeWall",
                              :adjacent_to => "attic - unvented",
                              :wall_type => "WoodStud",
                              :area => 316,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_assembly_r_value => 23.0 }]]
    attics_walls_values << [{ :id => "AtticGableUncond",
                              :adjacent_to => "attic - unvented",
                              :wall_type => "WoodStud",
                              :area => 50,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_assembly_r_value => 4.0 }]
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    attics_walls_values[0][0][:insulation_assembly_r_value] = 23.0
  end
  return attics_walls_values
end

def get_hpxml_file_foundations_values(hpxml_file, foundations_values)
  if ['base.xml'].include? hpxml_file
    foundations_values = [{ :id => "Foundation",
                            :foundation_type => "ConditionedBasement" }]
  elsif ['base-foundation-pier-beam.xml'].include? hpxml_file
    foundations_values[0][:foundation_type] = "Ambient"
  elsif ['base-foundation-slab.xml'].include? hpxml_file or
        hpxml_file.include? 'hvac_partial' or
        hpxml_file.include? 'hvac_multiple' or
        hpxml_file.include? 'hvac_base' or
        hpxml_file.include? 'hvac_dse' or
        hpxml_file.include? 'hvac_load_fracs'
    foundations_values[0][:foundation_type] = "SlabOnGrade"
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    foundations_values[0][:foundation_type] = "UnconditionedBasement"
  elsif ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
    foundations_values[0][:foundation_type] = "UnventedCrawlspace"
  elsif ['base-foundation-vented-crawlspace.xml'].include? hpxml_file
    foundations_values[0][:foundation_type] = "VentedCrawlspace"
    foundations_values[0][:specific_leakage_area] = 0.00667
  elsif ['base-foundation-multiple.xml'].include? hpxml_file
    foundations_values << { :id => "Foundation2",
                            :foundation_type => "UnventedCrawlspace" }
  end
  return foundations_values
end

def get_hpxml_file_foundations_walls_values(hpxml_file, foundations_walls_values)
  if ['base.xml'].include? hpxml_file
    foundations_walls_values = [[{ :id => "FoundationWall",
                                   :height => 8,
                                   :area => 1200,
                                   :thickness => 8,
                                   :depth_below_grade => 7,
                                   :adjacent_to => "ground",
                                   :insulation_height => 8,
                                   :insulation_r_value => 8.9 }]]
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    foundations_walls_values[0][0][:insulation_height] = 4
  elsif ['base-foundation-unconditioned-basement-assembly-r.xml'].include? hpxml_file
    foundations_walls_values[0][0][:insulation_height] = nil
    foundations_walls_values[0][0][:insulation_r_value] = nil
    foundations_walls_values[0][0][:insulation_assembly_r_value] = 10.69
  elsif ['base-foundation-unconditioned-basement-above-grade.xml'].include? hpxml_file
    foundations_walls_values[0][0][:depth_below_grade] = 4
  elsif ['base-foundation-unvented-crawlspace.xml',
         'base-foundation-vented-crawlspace.xml'].include? hpxml_file
    foundations_walls_values[0][0][:height] /= 2.0
    foundations_walls_values[0][0][:area] /= 2.0
    foundations_walls_values[0][0][:depth_below_grade] = 3
    foundations_walls_values[0][0][:insulation_height] /= 2.0
  elsif ['base-foundation-multiple.xml'].include? hpxml_file
    foundations_walls_values[0][0][:area] = 600
    foundations_walls_values[0] << { :id => "FoundationWallInterzone",
                                     :height => 8,
                                     :area => 360,
                                     :thickness => 8,
                                     :depth_below_grade => 7,
                                     :adjacent_to => "crawlspace - unvented",
                                     :insulation_height => 0,
                                     :insulation_r_value => 0 }
    foundations_walls_values << [{ :id => "FoundationWallCrawlspace",
                                   :height => 4,
                                   :area => 600,
                                   :thickness => 8,
                                   :depth_below_grade => 3,
                                   :adjacent_to => "ground",
                                   :insulation_height => 4,
                                   :insulation_r_value => 8.9 }]
  elsif ['base-foundation-pier-beam.xml',
         'base-foundation-slab.xml'].include? hpxml_file or
        hpxml_file.include? 'hvac_partial' or
        hpxml_file.include? 'hvac_multiple' or
        hpxml_file.include? 'hvac_base' or
        hpxml_file.include? 'hvac_dse' or
        hpxml_file.include? 'hvac_load_fracs'
    foundations_walls_values = [[]]
  end
  return foundations_walls_values
end

def get_hpxml_file_foundations_slabs_values(hpxml_file, foundations_slabs_values)
  if ['base.xml'].include? hpxml_file
    foundations_slabs_values = [[{ :id => "FoundationSlab",
                                   :area => 1350,
                                   :thickness => 4,
                                   :exposed_perimeter => 150,
                                   :perimeter_insulation_depth => 0,
                                   :under_slab_insulation_width => 0,
                                   :depth_below_grade => 7,
                                   :perimeter_insulation_r_value => 0,
                                   :under_slab_insulation_r_value => 0,
                                   :carpet_fraction => 0,
                                   :carpet_r_value => 0 }]]
  elsif ['base-foundation-unconditioned-basement-above-grade.xml'].include? hpxml_file
    foundations_slabs_values[0][0][:depth_below_grade] = 4
  elsif ['base-foundation-slab.xml'].include? hpxml_file or
        hpxml_file.include? 'hvac_partial' or
        hpxml_file.include? 'hvac_multiple' or
        hpxml_file.include? 'hvac_base' or
        hpxml_file.include? 'hvac_dse' or
        hpxml_file.include? 'hvac_load_fracs'
    foundations_slabs_values[0][0][:under_slab_insulation_width] = nil
    foundations_slabs_values[0][0][:under_slab_insulation_spans_entire_slab] = true
    foundations_slabs_values[0][0][:depth_below_grade] = 0
    foundations_slabs_values[0][0][:under_slab_insulation_r_value] = 5
    foundations_slabs_values[0][0][:carpet_fraction] = 1
    foundations_slabs_values[0][0][:carpet_r_value] = 2.5
  elsif ['base-foundation-unvented-crawlspace.xml',
         'base-foundation-vented-crawlspace.xml'].include? hpxml_file
    foundations_slabs_values[0][0][:thickness] = 0
    foundations_slabs_values[0][0][:depth_below_grade] = 3
    foundations_slabs_values[0][0][:carpet_r_value] = 2.5
  elsif ['base-foundation-multiple.xml'].include? hpxml_file
    foundations_slabs_values[0][0][:area] = 675
    foundations_slabs_values[0][0][:exposed_perimeter] = 75
    foundations_slabs_values << [{ :id => "FoundationSlabCrawlspace",
                                   :area => 675,
                                   :thickness => 0,
                                   :exposed_perimeter => 75,
                                   :perimeter_insulation_depth => 0,
                                   :under_slab_insulation_width => 0,
                                   :depth_below_grade => 3,
                                   :perimeter_insulation_r_value => 0,
                                   :under_slab_insulation_r_value => 0,
                                   :carpet_fraction => 0,
                                   :carpet_r_value => 0 }]
  elsif ['base-foundation-pier-beam.xml'].include? hpxml_file
    foundations_slabs_values = [[]]
  elsif ['base-enclosure-2stories-garage.xml'].include? hpxml_file
    foundations_slabs_values[0][0][:area] -= 400
    foundations_slabs_values[0][0][:exposed_perimeter] -= 40
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    foundations_slabs_values[0][0][:exposed_perimeter] -= 30
  elsif ['base-foundation-multiple-slab.xml'].include? hpxml_file
    # Multiple slabs for the same (basement) foundation
    foundations_slabs_values[0][0][:area] = 450
    foundations_slabs_values[0][0][:exposed_perimeter] = 50
    foundations_slabs_values[0] << { :id => "FoundationSlab2",
                                     :area => 900,
                                     :thickness => 4,
                                     :exposed_perimeter => 100,
                                     :perimeter_insulation_depth => 0,
                                     :under_slab_insulation_width => 0,
                                     :depth_below_grade => 7,
                                     :perimeter_insulation_r_value => 0,
                                     :under_slab_insulation_r_value => 0,
                                     :carpet_fraction => 0,
                                     :carpet_r_value => 0 }
  end
  return foundations_slabs_values
end

def get_hpxml_file_foundations_framefloors_values(hpxml_file, foundations_framefloors_values)
  if ['base.xml'].include? hpxml_file
    foundations_framefloors_values = [[]]
  elsif ['base-foundation-pier-beam.xml',
         'base-foundation-unconditioned-basement.xml',
         'base-foundation-unvented-crawlspace.xml',
         'base-foundation-vented-crawlspace.xml'].include? hpxml_file
    foundations_framefloors_values = [[{ :id => "FoundationFrameFloor",
                                         :adjacent_to => "living space",
                                         :area => 1350,
                                         :insulation_assembly_r_value => 18.7 }]]
  elsif ['base-foundation-multiple.xml'].include? hpxml_file
    foundations_framefloors_values[0][0][:area] = 675
    foundations_framefloors_values << [{ :id => "FoundationFrameFloorCrawlspace",
                                         :adjacent_to => "living space",
                                         :area => 675,
                                         :insulation_assembly_r_value => 18.7 }]
  end
  return foundations_framefloors_values
end

def get_hpxml_file_garages_values(hpxml_file, garages_values)
  if ['base.xml'].include? hpxml_file
    garages_values = []
  elsif ['base-enclosure-2stories-garage.xml',
         'base-enclosure-garage.xml'].include? hpxml_file
    garages_values = [{ :id => "Garage" }]
  end
  return garages_values
end

def get_hpxml_file_garages_ceilings_values(hpxml_file, garages_ceilings_values)
  if ['base.xml'].include? hpxml_file
    garages_ceilings_values = [[]]
  elsif ['base-enclosure-2stories-garage.xml'].include? hpxml_file
    garages_ceilings_values = [[{ :id => "GarageCeiling",
                                  :adjacent_to => "living space",
                                  :area => 400,
                                  :insulation_assembly_r_value => 18.7 }]]
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    # surface specified in Attic/Floors element
  end
  return garages_ceilings_values
end

def get_hpxml_file_garages_walls_values(hpxml_file, garages_walls_values)
  if ['base.xml'].include? hpxml_file
    garages_walls_values = [[]]
  elsif ['base-enclosure-2stories-garage.xml'].include? hpxml_file
    # exterior surfaces below; interzonal surfaces specified in Walls element
    garages_walls_values = [[{ :id => "GarageWall",
                               :adjacent_to => "outside",
                               :wall_type => "WoodStud",
                               :area => 800,
                               :solar_absorptance => 0.75,
                               :emittance => 0.9,
                               :insulation_assembly_r_value => 4 }]]
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    # exterior surfaces below; interzonal surface specified in Walls element
    garages_walls_values = [[{ :id => "GarageWall",
                               :adjacent_to => "outside",
                               :wall_type => "WoodStud",
                               :area => 560,
                               :solar_absorptance => 0.75,
                               :emittance => 0.9,
                               :insulation_assembly_r_value => 4 }]]
  end
  return garages_walls_values
end

def get_hpxml_file_garages_slabs_values(hpxml_file, garages_slabs_values)
  if ['base-enclosure-2stories-garage.xml'].include? hpxml_file
    garages_slabs_values = [[{ :id => "GarageSlab",
                               :area => 400,
                               :thickness => 4,
                               :exposed_perimeter => 40,
                               :perimeter_insulation_depth => 0,
                               :under_slab_insulation_width => 0,
                               :perimeter_insulation_r_value => 0,
                               :under_slab_insulation_r_value => 0 }]]
  elsif ['base.xml'].include? hpxml_file
    garages_slabs_values = [[{ :id => "GarageSlab",
                               :area => 600,
                               :thickness => 4,
                               :exposed_perimeter => 70,
                               :perimeter_insulation_depth => 0,
                               :under_slab_insulation_width => 0,
                               :perimeter_insulation_r_value => 0,
                               :under_slab_insulation_r_value => 0 }]]
  end
  return garages_slabs_values
end

def get_hpxml_file_rim_joists_values(hpxml_file, rim_joists_values)
  if ['base.xml'].include? hpxml_file
    # TODO: Other geometry values (e.g., building volume) assume
    # no rim joists.
    rim_joists_values = [{ :id => "RimJoistFoundation",
                           :exterior_adjacent_to => "outside",
                           :interior_adjacent_to => "living space",
                           :area => 116,
                           :solar_absorptance => 0.75,
                           :emittance => 0.9,
                           :insulation_assembly_r_value => 23.0 }]
  elsif ['base-foundation-pier-beam.xml',
         'base-foundation-slab.xml'].include? hpxml_file or
        hpxml_file.include? 'hvac_partial' or
        hpxml_file.include? 'hvac_multiple' or
        hpxml_file.include? 'hvac_base' or
        hpxml_file.include? 'hvac_dse' or
        hpxml_file.include? 'hvac_load_fracs'
    rim_joists_values = []
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    for i in 0..rim_joists_values.size - 1
      rim_joists_values[i][:interior_adjacent_to] = "basement - unconditioned"
    end
  elsif ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
    for i in 0..rim_joists_values.size - 1
      rim_joists_values[i][:interior_adjacent_to] = "crawlspace - unvented"
    end
  elsif ['base-foundation-vented-crawlspace.xml'].include? hpxml_file
    for i in 0..rim_joists_values.size - 1
      rim_joists_values[i][:interior_adjacent_to] = "crawlspace - vented"
    end
  elsif ['base-foundation-multiple.xml'].include? hpxml_file
    rim_joists_values[0][:exterior_adjacent_to] = "crawlspace - unvented"
    rim_joists_values << { :id => "RimJoistCrawlspace",
                           :exterior_adjacent_to => "outside",
                           :interior_adjacent_to => "crawlspace - unvented",
                           :area => 81,
                           :solar_absorptance => 0.75,
                           :emittance => 0.9,
                           :insulation_assembly_r_value => 23.0 }
  elsif ['base-enclosure-2stories.xml'].include? hpxml_file
    rim_joists_values << { :id => "RimJoist2ndStory",
                           :exterior_adjacent_to => "outside",
                           :interior_adjacent_to => "living space",
                           :area => 116,
                           :solar_absorptance => 0.75,
                           :emittance => 0.9,
                           :insulation_assembly_r_value => 23.0 }
  end
  return rim_joists_values
end

def get_hpxml_file_walls_values(hpxml_file, walls_values)
  if ['base.xml'].include? hpxml_file
    walls_values = [{ :id => "Wall",
                      :exterior_adjacent_to => "outside",
                      :interior_adjacent_to => "living space",
                      :wall_type => "WoodStud",
                      :area => 1200,
                      :solar_absorptance => 0.75,
                      :emittance => 0.9,
                      :insulation_assembly_r_value => 23 }]
  elsif ['base-enclosure-walltype-cmu.xml'].include? hpxml_file
    for i in 0..walls_values.size - 1
      walls_values[i][:wall_type] = "ConcreteMasonryUnit"
      walls_values[i][:insulation_assembly_r_value] = 12
    end
  elsif ['base-enclosure-walltype-doublestud.xml'].include? hpxml_file
    for i in 0..walls_values.size - 1
      walls_values[i][:wall_type] = "DoubleWoodStud"
      walls_values[i][:insulation_assembly_r_value] = 28.7
    end
  elsif ['base-enclosure-walltype-icf.xml'].include? hpxml_file
    for i in 0..walls_values.size - 1
      walls_values[i][:wall_type] = "InsulatedConcreteForms"
      walls_values[i][:insulation_assembly_r_value] = 21
    end
  elsif ['base-enclosure-walltype-log.xml'].include? hpxml_file
    for i in 0..walls_values.size - 1
      walls_values[i][:wall_type] = "LogWall"
      walls_values[i][:insulation_assembly_r_value] = 7.1
    end
  elsif ['base-enclosure-walltype-sip.xml'].include? hpxml_file
    for i in 0..walls_values.size - 1
      walls_values[i][:wall_type] = "StructurallyInsulatedPanel"
      walls_values[i][:insulation_assembly_r_value] = 16.1
    end
  elsif ['base-enclosure-walltype-solidconcrete.xml'].include? hpxml_file
    for i in 0..walls_values.size - 1
      walls_values[i][:wall_type] = "SolidConcrete"
      walls_values[i][:insulation_assembly_r_value] = 1.35
    end
  elsif ['base-enclosure-walltype-steelstud.xml'].include? hpxml_file
    for i in 0..walls_values.size - 1
      walls_values[i][:wall_type] = "SteelFrame"
      walls_values[i][:insulation_assembly_r_value] = 8.1
    end
  elsif ['base-enclosure-walltype-stone.xml'].include? hpxml_file
    for i in 0..walls_values.size - 1
      walls_values[i][:wall_type] = "Stone"
      walls_values[i][:insulation_assembly_r_value] = 5.4
    end
  elsif ['base-enclosure-walltype-strawbale.xml'].include? hpxml_file
    for i in 0..walls_values.size - 1
      walls_values[i][:wall_type] = "StrawBale"
      walls_values[i][:insulation_assembly_r_value] = 58.8
    end
  elsif ['base-enclosure-walltype-structuralbrick.xml'].include? hpxml_file
    for i in 0..walls_values.size - 1
      walls_values[i][:wall_type] = "StructuralBrick"
      walls_values[i][:insulation_assembly_r_value] = 7.9
    end
  elsif ['invalid_files/missing-surfaces.xml'].include? hpxml_file
    walls_values << { :id => "WallGarage",
                      :exterior_adjacent_to => "living space",
                      :interior_adjacent_to => "garage",
                      :wall_type => "WoodStud",
                      :area => 100,
                      :solar_absorptance => 0.75,
                      :emittance => 0.9,
                      :insulation_assembly_r_value => 4 }
  elsif ['base-enclosure-2stories.xml'].include? hpxml_file
    for i in 0..walls_values.size - 1
      walls_values[i][:area] *= 2.0
    end
  elsif ['base-enclosure-2stories-garage.xml'].include? hpxml_file
    walls_values = [{ :id => "Wall",
                      :exterior_adjacent_to => "outside",
                      :interior_adjacent_to => "living space",
                      :wall_type => "WoodStud",
                      :area => 880,
                      :solar_absorptance => 0.75,
                      :emittance => 0.9,
                      :insulation_assembly_r_value => 23 },
                    { :id => "WallGarage",
                      :exterior_adjacent_to => "garage",
                      :interior_adjacent_to => "living space",
                      :wall_type => "WoodStud",
                      :area => 320,
                      :solar_absorptance => 0.75,
                      :emittance => 0.9,
                      :insulation_assembly_r_value => 23 }]
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    walls_values = [{ :id => "Wall",
                      :exterior_adjacent_to => "outside",
                      :interior_adjacent_to => "living space",
                      :wall_type => "WoodStud",
                      :area => 960,
                      :solar_absorptance => 0.75,
                      :emittance => 0.9,
                      :insulation_assembly_r_value => 23 },
                    { :id => "WallGarage",
                      :exterior_adjacent_to => "garage",
                      :interior_adjacent_to => "living space",
                      :wall_type => "WoodStud",
                      :area => 240,
                      :solar_absorptance => 0.75,
                      :emittance => 0.9,
                      :insulation_assembly_r_value => 23 }]
  end
  return walls_values
end

def get_hpxml_file_windows_values(hpxml_file, windows_values)
  if ['base.xml'].include? hpxml_file
    windows_values = [{ :id => "WindowNorth",
                        :area => 54,
                        :azimuth => 0,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "Wall" },
                      { :id => "WindowSouth",
                        :area => 54,
                        :azimuth => 180,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "Wall" },
                      { :id => "WindowEast",
                        :area => 36,
                        :azimuth => 90,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "Wall" },
                      { :id => "WindowWest",
                        :area => 36,
                        :azimuth => 270,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "Wall" }]
  elsif ['base-enclosure-overhangs.xml'].include? hpxml_file
    windows_values[0][:overhangs_depth] = 2.5
    windows_values[0][:overhangs_distance_to_top_of_window] = 0
    windows_values[0][:overhangs_distance_to_bottom_of_window] = 4
    windows_values[2][:overhangs_depth] = 1.5
    windows_values[2][:overhangs_distance_to_top_of_window] = 2
    windows_values[2][:overhangs_distance_to_bottom_of_window] = 6
    windows_values[3][:overhangs_depth] = 1.5
    windows_values[3][:overhangs_distance_to_top_of_window] = 2
    windows_values[3][:overhangs_distance_to_bottom_of_window] = 7
  elsif ['base-enclosure-windows-interior-shading.xml'].include? hpxml_file
    windows_values[0][:interior_shading_factor_summer] = 0.7
    windows_values[0][:interior_shading_factor_winter] = 0.85
    windows_values[1][:interior_shading_factor_summer] = 0.01
    windows_values[1][:interior_shading_factor_winter] = 0.99
    windows_values[2][:interior_shading_factor_summer] = 0.99
    windows_values[2][:interior_shading_factor_winter] = 0.01
    windows_values[3][:interior_shading_factor_summer] = 0.85
    windows_values[3][:interior_shading_factor_winter] = 0.7
  elsif ['invalid_files/net-area-negative-wall.xml'].include? hpxml_file
    windows_values[0][:area] = 1000
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    windows_values[0][:area] = 54
    windows_values[1][:area] = 54
    windows_values[2][:area] = 54
    windows_values[3][:area] = 54
    windows_values << { :id => "AtticGableWindowEast",
                        :area => 12,
                        :azimuth => 90,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "AtticGableCond" }
    windows_values << { :id => "AtticGableWindowWest",
                        :area => 12,
                        :azimuth => 270,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "AtticGableCond" }
  elsif ['base-atticroof-cathedral.xml'].include? hpxml_file
    windows_values[0][:area] = 54
    windows_values[1][:area] = 54
    windows_values[2][:area] = 54
    windows_values[3][:area] = 54
    windows_values << { :id => "AtticGableWindowEast",
                        :area => 12,
                        :azimuth => 90,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "AtticGable" }
    windows_values << { :id => "AtticGableWindowWest",
                        :area => 12,
                        :azimuth => 270,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "AtticGable" }
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    windows_values.delete_at(2)
    windows_values << { :id => "GarageWindowEast",
                        :area => 12,
                        :azimuth => 90,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "GarageWall" }
  elsif ['base-enclosure-2stories.xml'].include? hpxml_file
    windows_values[0][:area] = 108
    windows_values[1][:area] = 108
    windows_values[2][:area] = 72
    windows_values[3][:area] = 72
  elsif ['base-enclosure-2stories-garage'].include? hpxml_file
    windows_values[0][:area] = 84
    windows_values[1][:area] = 108
    windows_values[2][:area] = 72
    windows_values[3][:area] = 48
  elsif ['base-foundation-unconditioned-basement-above-grade.xml'].include? hpxml_file
    windows_values << { :id => "FoundationWindowNorth",
                        :area => 20,
                        :azimuth => 0,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "FoundationWall" }
    windows_values << { :id => "FoundationWindowSouth",
                        :area => 20,
                        :azimuth => 180,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "FoundationWall" }
    windows_values << { :id => "FoundationWindowEast",
                        :area => 10,
                        :azimuth => 90,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "FoundationWall" }
    windows_values << { :id => "FoundationWindowWest",
                        :area => 10,
                        :azimuth => 270,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "FoundationWall" }
  elsif ['invalid_files/unattached-window.xml'].include? hpxml_file
    windows_values[0][:wall_idref] = "foobar"
  end
  return windows_values
end

def get_hpxml_file_skylights_values(hpxml_file, skylights_values)
  if ['base-enclosure-skylights.xml'].include? hpxml_file
    skylights_values << { :id => "SkylightNorth",
                          :area => 15,
                          :azimuth => 0,
                          :ufactor => 0.33,
                          :shgc => 0.45,
                          :roof_idref => "AtticRoof" }
    skylights_values << { :id => "SkylightSouth",
                          :area => 15,
                          :azimuth => 180,
                          :ufactor => 0.35,
                          :shgc => 0.47,
                          :roof_idref => "AtticRoof" }
  elsif ['invalid_files/net-area-negative-roof.xml'].include? hpxml_file
    skylights_values[0][:area] = 4000
  elsif ['invalid_files/unattached-skylight.xml'].include? hpxml_file
    skylights_values[0][:roof_idref] = "foobar"
  end
  return skylights_values
end

def get_hpxml_file_doors_values(hpxml_file, doors_values)
  if ['base.xml'].include? hpxml_file
    doors_values = [{ :id => "DoorNorth",
                      :wall_idref => "Wall",
                      :area => 40,
                      :azimuth => 0,
                      :r_value => 4.4 },
                    { :id => "DoorSouth",
                      :wall_idref => "Wall",
                      :area => 40,
                      :azimuth => 180,
                      :r_value => 4.4 }]
  elsif ['base-enclosure-garage.xml',
         'base-enclosure-2stories-garage.xml'].include? hpxml_file
    doors_values << { :id => "GarageDoorSouth",
                      :wall_idref => "GarageWall",
                      :area => 70,
                      :azimuth => 180,
                      :r_value => 4.4 }
  elsif ['invalid_files/unattached-door.xml'].include? hpxml_file
    doors_values[0][:wall_idref] = "foobar"
  end
  return doors_values
end

def get_hpxml_file_heating_systems_values(hpxml_file, heating_systems_values)
  if ['base.xml'].include? hpxml_file
    heating_systems_values = [{ :id => "HeatingSystem",
                                :distribution_system_idref => "HVACDistribution",
                                :heating_system_type => "Furnace",
                                :heating_system_fuel => "natural gas",
                                :heating_capacity => 64000,
                                :heating_efficiency_afue => 0.92,
                                :fraction_heat_load_served => 1 }]
  elsif ['base-hvac-air-to-air-heat-pump-1-speed.xml',
         'base-hvac-air-to-air-heat-pump-2-speed.xml',
         'base-hvac-air-to-air-heat-pump-var-speed.xml',
         'base-hvac-central-ac-only-1-speed.xml',
         'base-hvac-central-ac-only-2-speed.xml',
         'base-hvac-central-ac-only-var-speed.xml',
         'base-hvac-ground-to-air-heat-pump.xml',
         'base-hvac-mini-split-heat-pump-ducted.xml',
         'base-hvac-mini-split-heat-pump-ductless-no-backup.xml',
         'base-hvac-ideal-air.xml',
         'base-hvac-none.xml',
         'base-hvac-room-ac-only.xml'].include? hpxml_file
    heating_systems_values = []
  elsif ['base-hvac-boiler-elec-only.xml'].include? hpxml_file
    heating_systems_values[0][:heating_system_type] = "Boiler"
    heating_systems_values[0][:heating_system_fuel] = "electricity"
    heating_systems_values[0][:heating_efficiency_afue] = 1
  elsif ['base-hvac-boiler-gas-central-ac-1-speed.xml',
         'base-hvac-boiler-gas-only.xml'].include? hpxml_file
    heating_systems_values[0][:heating_system_type] = "Boiler"
    heating_systems_values[0][:electric_auxiliary_energy] = 200
  elsif ['base-hvac-boiler-oil-only.xml'].include? hpxml_file
    heating_systems_values[0][:heating_system_type] = "Boiler"
    heating_systems_values[0][:heating_system_fuel] = "fuel oil"
  elsif ['base-hvac-boiler-propane-only.xml'].include? hpxml_file
    heating_systems_values[0][:heating_system_type] = "Boiler"
    heating_systems_values[0][:heating_system_fuel] = "propane"
  elsif ['base-hvac-elec-resistance-only.xml'].include? hpxml_file
    heating_systems_values[0][:distribution_system_idref] = nil
    heating_systems_values[0][:heating_system_type] = "ElectricResistance"
    heating_systems_values[0][:heating_system_fuel] = "electricity"
    heating_systems_values[0][:heating_efficiency_afue] = nil
    heating_systems_values[0][:heating_efficiency_percent] = 1
  elsif ['base-hvac-furnace-elec-only.xml'].include? hpxml_file
    heating_systems_values[0][:heating_system_fuel] = "electricity"
    heating_systems_values[0][:heating_efficiency_afue] = 1
  elsif ['base-hvac-furnace-gas-only.xml',
         'base-hvac-room-ac-furnace-gas.xml'].include? hpxml_file
    heating_systems_values[0][:electric_auxiliary_energy] = 700
  elsif ['base-hvac-furnace-gas-only-no-eae.xml',
         'base-hvac-boiler-gas-only-no-eae.xml',
         'base-hvac-stove-oil-only-no-eae.xml',
         'base-hvac-wall-furnace-propane-only-no-eae.xml'].include? hpxml_file
    heating_systems_values[0][:electric_auxiliary_energy] = nil
  elsif ['base-hvac-furnace-oil-only.xml'].include? hpxml_file
    heating_systems_values[0][:heating_system_fuel] = "fuel oil"
  elsif ['base-hvac-furnace-propane-only.xml'].include? hpxml_file
    heating_systems_values[0][:heating_system_fuel] = "propane"
  elsif ['base-hvac-multiple.xml'].include? hpxml_file
    heating_systems_values[0][:heating_system_type] = "Boiler"
    heating_systems_values[0][:heating_system_fuel] = "electricity"
    heating_systems_values[0][:heating_efficiency_afue] = 1
    heating_systems_values[0][:fraction_heat_load_served] = 0.1
    heating_systems_values << { :id => "HeatingSystem2",
                                :distribution_system_idref => "HVACDistribution2",
                                :heating_system_type => "Boiler",
                                :heating_system_fuel => "natural gas",
                                :heating_capacity => 64000,
                                :heating_efficiency_afue => 0.92,
                                :fraction_heat_load_served => 0.1,
                                :electric_auxiliary_energy => 200 }
    heating_systems_values << { :id => "HeatingSystem3",
                                :heating_system_type => "ElectricResistance",
                                :heating_system_fuel => "electricity",
                                :heating_capacity => 64000,
                                :heating_efficiency_percent => 1,
                                :fraction_heat_load_served => 0.1 }
    heating_systems_values << { :id => "HeatingSystem4",
                                :distribution_system_idref => "HVACDistribution3",
                                :heating_system_type => "Furnace",
                                :heating_system_fuel => "electricity",
                                :heating_capacity => 64000,
                                :heating_efficiency_afue => 1,
                                :fraction_heat_load_served => 0.1 }
    heating_systems_values << { :id => "HeatingSystem5",
                                :distribution_system_idref => "HVACDistribution4",
                                :heating_system_type => "Furnace",
                                :heating_system_fuel => "natural gas",
                                :heating_capacity => 64000,
                                :heating_efficiency_afue => 0.92,
                                :fraction_heat_load_served => 0.1,
                                :electric_auxiliary_energy => 700 }
    heating_systems_values << { :id => "HeatingSystem6",
                                :heating_system_type => "Stove",
                                :heating_system_fuel => "fuel oil",
                                :heating_capacity => 64000,
                                :heating_efficiency_percent => 0.8,
                                :fraction_heat_load_served => 0.1,
                                :electric_auxiliary_energy => 200 }
    heating_systems_values << { :id => "HeatingSystem7",
                                :heating_system_type => "WallFurnace",
                                :heating_system_fuel => "propane",
                                :heating_capacity => 64000,
                                :heating_efficiency_afue => 0.8,
                                :fraction_heat_load_served => 0.1,
                                :electric_auxiliary_energy => 200 }
  elsif ['invalid_files/hvac-frac-load-served.xml'].include? hpxml_file
    heating_systems_values[0][:fraction_heat_load_served] += 0.1
  elsif ['base-hvac-stove-oil-only.xml'].include? hpxml_file
    heating_systems_values[0][:distribution_system_idref] = nil
    heating_systems_values[0][:heating_system_type] = "Stove"
    heating_systems_values[0][:heating_system_fuel] = "fuel oil"
    heating_systems_values[0][:heating_efficiency_afue] = nil
    heating_systems_values[0][:heating_efficiency_percent] = 0.8
    heating_systems_values[0][:electric_auxiliary_energy] = 200
  elsif ['base-hvac-wall-furnace-elec-only.xml'].include? hpxml_file
    heating_systems_values[0][:distribution_system_idref] = nil
    heating_systems_values[0][:heating_system_type] = "WallFurnace"
    heating_systems_values[0][:heating_system_fuel] = "electricity"
    heating_systems_values[0][:heating_efficiency_afue] = 1.0
    heating_systems_values[0][:electric_auxiliary_energy] = 200
  elsif ['base-hvac-wall-furnace-propane-only.xml'].include? hpxml_file
    heating_systems_values[0][:distribution_system_idref] = nil
    heating_systems_values[0][:heating_system_type] = "WallFurnace"
    heating_systems_values[0][:heating_system_fuel] = "propane"
    heating_systems_values[0][:heating_efficiency_afue] = 0.8
    heating_systems_values[0][:electric_auxiliary_energy] = 200
  elsif ['invalid_files/unattached-hvac-distribution.xml'].include? hpxml_file
    heating_systems_values[0][:distribution_system_idref] = "foobar"
  elsif hpxml_file.include? 'hvac_autosizing' and not heating_systems_values.nil? and heating_systems_values.size > 0
    heating_systems_values[0][:heating_capacity] = -1
  elsif hpxml_file.include? '-zero-heat.xml' and not heating_systems_values.nil? and heating_systems_values.size > 0
    heating_systems_values[0][:fraction_heat_load_served] = 0
  elsif hpxml_file.include? 'hvac_multiple' and not heating_systems_values.nil? and heating_systems_values.size > 0
    heating_systems_values[0][:heating_capacity] /= 3.0
    heating_systems_values[0][:fraction_heat_load_served] = 0.333
    heating_systems_values[0][:electric_auxiliary_energy] /= 3.0 unless heating_systems_values[0][:electric_auxiliary_energy].nil?
    heating_systems_values << heating_systems_values[0].dup
    heating_systems_values[1][:id] = "SpaceHeat_ID2"
    heating_systems_values[1][:distribution_system_idref] = "HVACDistribution2" unless heating_systems_values[1][:distribution_system_idref].nil?
    heating_systems_values << heating_systems_values[0].dup
    heating_systems_values[2][:id] = "SpaceHeat_ID3"
    heating_systems_values[2][:distribution_system_idref] = "HVACDistribution3" unless heating_systems_values[2][:distribution_system_idref].nil?
  elsif hpxml_file.include? 'hvac_partial' and not heating_systems_values.nil? and heating_systems_values.size > 0
    heating_systems_values[0][:heating_capacity] /= 2.0
    heating_systems_values[0][:fraction_heat_load_served] = 0.5
    heating_systems_values[0][:electric_auxiliary_energy] /= 2.0 unless heating_systems_values[0][:electric_auxiliary_energy].nil?
  end
  return heating_systems_values
end

def get_hpxml_file_cooling_systems_values(hpxml_file, cooling_systems_values)
  if ['base.xml'].include? hpxml_file
    cooling_systems_values = [{ :id => "CoolingSystem",
                                :distribution_system_idref => "HVACDistribution",
                                :cooling_system_type => "central air conditioning",
                                :cooling_system_fuel => "electricity",
                                :cooling_capacity => 48000,
                                :fraction_cool_load_served => 1,
                                :cooling_efficiency_seer => 13 }]
  elsif ['base-hvac-air-to-air-heat-pump-1-speed.xml',
         'base-hvac-air-to-air-heat-pump-2-speed.xml',
         'base-hvac-air-to-air-heat-pump-var-speed.xml',
         'base-hvac-boiler-elec-only.xml',
         'base-hvac-boiler-gas-only.xml',
         'base-hvac-boiler-oil-only.xml',
         'base-hvac-boiler-propane-only.xml',
         'base-hvac-elec-resistance-only.xml',
         'base-hvac-furnace-elec-only.xml',
         'base-hvac-furnace-gas-only.xml',
         'base-hvac-furnace-oil-only.xml',
         'base-hvac-furnace-propane-only.xml',
         'base-hvac-ground-to-air-heat-pump.xml',
         'base-hvac-mini-split-heat-pump-ducted.xml',
         'base-hvac-mini-split-heat-pump-ductless-no-backup.xml',
         'base-hvac-ideal-air.xml',
         'base-hvac-none.xml',
         'base-hvac-stove-oil-only.xml',
         'base-hvac-wall-furnace-elec-only.xml',
         'base-hvac-wall-furnace-propane-only.xml'].include? hpxml_file
    cooling_systems_values = []
  elsif ['base-hvac-boiler-gas-central-ac-1-speed.xml'].include? hpxml_file
    cooling_systems_values[0][:distribution_system_idref] = "HVACDistribution2"
  elsif ['base-hvac-furnace-gas-central-ac-2-speed.xml',
         'base-hvac-central-ac-only-2-speed.xml'].include? hpxml_file
    cooling_systems_values[0][:cooling_efficiency_seer] = 18
  elsif ['base-hvac-furnace-gas-central-ac-var-speed.xml',
         'base-hvac-central-ac-only-var-speed.xml'].include? hpxml_file
    cooling_systems_values[0][:cooling_efficiency_seer] = 24
  elsif ['base-hvac-furnace-gas-room-ac.xml',
         'base-hvac-room-ac-furnace-gas.xml',
         'base-hvac-room-ac-only.xml'].include? hpxml_file
    cooling_systems_values[0][:distribution_system_idref] = nil
    cooling_systems_values[0][:cooling_system_type] = "room air conditioner"
    cooling_systems_values[0][:cooling_efficiency_seer] = nil
    cooling_systems_values[0][:cooling_efficiency_eer] = 8.5
  elsif ['base-hvac-multiple.xml'].include? hpxml_file
    cooling_systems_values[0][:distribution_system_idref] = "HVACDistribution4"
    cooling_systems_values[0][:fraction_cool_load_served] = 0.2
    cooling_systems_values << { :id => "CoolingSystem2",
                                :cooling_system_type => "room air conditioner",
                                :cooling_system_fuel => "electricity",
                                :cooling_capacity => 48000,
                                :fraction_cool_load_served => 0.2,
                                :cooling_efficiency_eer => 8.5 }
  elsif ['invalid_files/hvac-frac-load-served.xml'].include? hpxml_file
    cooling_systems_values[0][:fraction_cool_load_served] += 0.2
  elsif hpxml_file.include? 'hvac_autosizing' and not cooling_systems_values.nil? and cooling_systems_values.size > 0
    cooling_systems_values[0][:cooling_capacity] = -1
  elsif hpxml_file.include? '-zero-cool.xml' and not cooling_systems_values.nil? and cooling_systems_values.size > 0
    cooling_systems_values[0][:fraction_cool_load_served] = 0
  elsif hpxml_file.include? 'hvac_multiple' and not cooling_systems_values.nil? and cooling_systems_values.size > 0
    cooling_systems_values[0][:cooling_capacity] /= 3.0
    cooling_systems_values[0][:fraction_cool_load_served] = 0.333
    cooling_systems_values << cooling_systems_values[0].dup
    cooling_systems_values[1][:id] = "SpaceCool_ID2"
    cooling_systems_values[1][:distribution_system_idref] = "HVACDistribution2" unless cooling_systems_values[1][:distribution_system_idref].nil?
    cooling_systems_values << cooling_systems_values[0].dup
    cooling_systems_values[2][:id] = "SpaceCool_ID3"
    cooling_systems_values[2][:distribution_system_idref] = "HVACDistribution3" unless cooling_systems_values[2][:distribution_system_idref].nil?
  elsif hpxml_file.include? 'hvac_partial' and not cooling_systems_values.nil? and cooling_systems_values.size > 0
    cooling_systems_values[0][:cooling_capacity] /= 2.0
    cooling_systems_values[0][:fraction_cool_load_served] = 0.5
  end
  return cooling_systems_values
end

def get_hpxml_file_heat_pumps_values(hpxml_file, heat_pumps_values)
  if ['base-hvac-air-to-air-heat-pump-1-speed.xml'].include? hpxml_file
    heat_pumps_values << { :id => "HeatPump",
                           :distribution_system_idref => "HVACDistribution",
                           :heat_pump_type => "air-to-air",
                           :heat_pump_fuel => "electricity",
                           :cooling_capacity => 48000,
                           :fraction_heat_load_served => 1,
                           :fraction_cool_load_served => 1,
                           :heating_efficiency_hspf => 7.7,
                           :cooling_efficiency_seer => 13 }
  elsif ['base-hvac-air-to-air-heat-pump-2-speed.xml'].include? hpxml_file
    heat_pumps_values << { :id => "HeatPump",
                           :distribution_system_idref => "HVACDistribution",
                           :heat_pump_type => "air-to-air",
                           :heat_pump_fuel => "electricity",
                           :cooling_capacity => 48000,
                           :fraction_heat_load_served => 1,
                           :fraction_cool_load_served => 1,
                           :heating_efficiency_hspf => 9.3,
                           :cooling_efficiency_seer => 18 }
  elsif ['base-hvac-air-to-air-heat-pump-var-speed.xml'].include? hpxml_file
    heat_pumps_values << { :id => "HeatPump",
                           :distribution_system_idref => "HVACDistribution",
                           :heat_pump_type => "air-to-air",
                           :heat_pump_fuel => "electricity",
                           :cooling_capacity => 48000,
                           :fraction_heat_load_served => 1,
                           :fraction_cool_load_served => 1,
                           :heating_efficiency_hspf => 10,
                           :cooling_efficiency_seer => 22 }
  elsif ['base-hvac-ground-to-air-heat-pump.xml'].include? hpxml_file
    heat_pumps_values << { :id => "HeatPump",
                           :distribution_system_idref => "HVACDistribution",
                           :heat_pump_type => "ground-to-air",
                           :heat_pump_fuel => "electricity",
                           :cooling_capacity => 48000,
                           :fraction_heat_load_served => 1,
                           :fraction_cool_load_served => 1,
                           :heating_efficiency_cop => 3.6,
                           :cooling_efficiency_eer => 16.6 }
  elsif ['base-hvac-mini-split-heat-pump-ducted.xml'].include? hpxml_file
    heat_pumps_values << { :id => "HeatPump",
                           :distribution_system_idref => "HVACDistribution",
                           :heat_pump_type => "mini-split",
                           :heat_pump_fuel => "electricity",
                           :cooling_capacity => 48000,
                           :fraction_heat_load_served => 1,
                           :fraction_cool_load_served => 1,
                           :heating_efficiency_hspf => 10,
                           :cooling_efficiency_seer => 19 }
  elsif ['base-hvac-mini-split-heat-pump-ductless.xml'].include? hpxml_file
    heat_pumps_values[0][:distribution_system_idref] = nil
  elsif ['base-hvac-mini-split-heat-pump-ductless-no-backup.xml'].include? hpxml_file
    heat_pumps_values[0][:backup_heating_capacity] = 0
  elsif ['base-hvac-multiple.xml'].include? hpxml_file
    heat_pumps_values << { :id => "HeatPump",
                           :distribution_system_idref => "HVACDistribution5",
                           :heat_pump_type => "air-to-air",
                           :heat_pump_fuel => "electricity",
                           :cooling_capacity => 48000,
                           :fraction_heat_load_served => 0.1,
                           :fraction_cool_load_served => 0.2,
                           :heating_efficiency_hspf => 7.7,
                           :cooling_efficiency_seer => 13 }
    heat_pumps_values << { :id => "HeatPump2",
                           :distribution_system_idref => "HVACDistribution6",
                           :heat_pump_type => "ground-to-air",
                           :heat_pump_fuel => "electricity",
                           :cooling_capacity => 48000,
                           :fraction_heat_load_served => 0.1,
                           :fraction_cool_load_served => 0.2,
                           :heating_efficiency_cop => 3.6,
                           :cooling_efficiency_eer => 16.6 }
    heat_pumps_values << { :id => "HeatPump3",
                           :heat_pump_type => "mini-split",
                           :heat_pump_fuel => "electricity",
                           :cooling_capacity => 48000,
                           :fraction_heat_load_served => 0.1,
                           :fraction_cool_load_served => 0.2,
                           :heating_efficiency_hspf => 10,
                           :cooling_efficiency_seer => 19 }
  elsif ['invalid_files/hvac-distribution-multiple-attached-heating.xml'].include? hpxml_file
    heat_pumps_values[0][:distribution_system_idref] = "HVACDistribution3"
  elsif ['invalid_files/hvac-distribution-multiple-attached-cooling.xml'].include? hpxml_file
    heat_pumps_values[0][:distribution_system_idref] = "HVACDistribution4"
  elsif hpxml_file.include? 'hvac_autosizing' and not heat_pumps_values.nil? and heat_pumps_values.size > 0
    heat_pumps_values[0][:cooling_capacity] = -1
  elsif hpxml_file.include? '-zero-heat-cool.xml' and not heat_pumps_values.nil? and heat_pumps_values.size > 0
    heat_pumps_values[0][:fraction_heat_load_served] = 0
    heat_pumps_values[0][:fraction_cool_load_served] = 0
  elsif hpxml_file.include? '-zero-heat.xml' and not heat_pumps_values.nil? and heat_pumps_values.size > 0
    heat_pumps_values[0][:fraction_heat_load_served] = 0
  elsif hpxml_file.include? '-zero-cool.xml' and not heat_pumps_values.nil? and heat_pumps_values.size > 0
    heat_pumps_values[0][:fraction_cool_load_served] = 0
  elsif hpxml_file.include? 'hvac_multiple' and not heat_pumps_values.nil? and heat_pumps_values.size > 0
    heat_pumps_values[0][:cooling_capacity] /= 3.0
    heat_pumps_values[0][:fraction_heat_load_served] = 0.333
    heat_pumps_values[0][:fraction_cool_load_served] = 0.333
    heat_pumps_values << heat_pumps_values[0].dup
    heat_pumps_values[1][:id] = "SpaceHeatPump_ID2"
    heat_pumps_values[1][:distribution_system_idref] = "HVACDistribution2" unless heat_pumps_values[1][:distribution_system_idref].nil?
    heat_pumps_values << heat_pumps_values[0].dup
    heat_pumps_values[2][:id] = "SpaceHeatPump_ID3"
    heat_pumps_values[2][:distribution_system_idref] = "HVACDistribution3" unless heat_pumps_values[2][:distribution_system_idref].nil?
  elsif hpxml_file.include? 'hvac_partial' and not heat_pumps_values.nil? and heat_pumps_values.size > 0
    heat_pumps_values[0][:cooling_capacity] /= 2.0
    heat_pumps_values[0][:fraction_heat_load_served] = 0.5
    heat_pumps_values[0][:fraction_cool_load_served] = 0.5
  end
  return heat_pumps_values
end

def get_hpxml_file_hvac_control_values(hpxml_file, hvac_control_values)
  if ['base.xml'].include? hpxml_file
    hvac_control_values = { :id => "HVACControl",
                            :control_type => "manual thermostat" }
  elsif ['base-hvac-none.xml'].include? hpxml_file
    hvac_control_values = {}
  elsif ['base-hvac-programmable-thermostat.xml'].include? hpxml_file
    hvac_control_values[:control_type] = "programmable thermostat"
  elsif ['base-hvac-setpoints.xml'].include? hpxml_file
    hvac_control_values[:setpoint_temp_heating_season] = 60
    hvac_control_values[:setpoint_temp_cooling_season] = 80
  end
  return hvac_control_values
end

def get_hpxml_file_hvac_distributions_values(hpxml_file, hvac_distributions_values)
  if ['base.xml'].include? hpxml_file
    hvac_distributions_values = [{ :id => "HVACDistribution",
                                   :distribution_system_type => "AirDistribution" }]
  elsif ['base-hvac-boiler-elec-only.xml',
         'base-hvac-boiler-gas-only.xml',
         'base-hvac-boiler-oil-only.xml',
         'base-hvac-boiler-propane-only.xml'].include? hpxml_file
    hvac_distributions_values[0][:distribution_system_type] = "HydronicDistribution"
  elsif ['base-hvac-boiler-gas-central-ac-1-speed.xml'].include? hpxml_file
    hvac_distributions_values[0][:distribution_system_type] = "HydronicDistribution"
    hvac_distributions_values << { :id => "HVACDistribution2",
                                   :distribution_system_type => "AirDistribution" }
  elsif ['base-hvac-none.xml',
         'base-hvac-elec-resistance-only.xml',
         'base-hvac-ideal-air.xml',
         'base-hvac-mini-split-heat-pump-ductless.xml',
         'base-hvac-room-ac-only.xml',
         'base-hvac-stove-oil-only.xml',
         'base-hvac-wall-furnace-elec-only.xml',
         'base-hvac-wall-furnace-propane-only.xml'].include? hpxml_file
    hvac_distributions_values = []
  elsif ['base-hvac-multiple.xml'].include? hpxml_file
    hvac_distributions_values[0][:distribution_system_type] = "HydronicDistribution"
    hvac_distributions_values << { :id => "HVACDistribution2",
                                   :distribution_system_type => "HydronicDistribution" }
    hvac_distributions_values << { :id => "HVACDistribution3",
                                   :distribution_system_type => "AirDistribution" }
    hvac_distributions_values << { :id => "HVACDistribution4",
                                   :distribution_system_type => "AirDistribution" }
    hvac_distributions_values << { :id => "HVACDistribution5",
                                   :distribution_system_type => "AirDistribution" }
    hvac_distributions_values << { :id => "HVACDistribution6",
                                   :distribution_system_type => "AirDistribution" }
  elsif ['base-hvac-dse.xml'].include? hpxml_file
    hvac_distributions_values[0][:distribution_system_type] = "DSE"
    hvac_distributions_values[0][:annual_heating_dse] = 0.75
    hvac_distributions_values[0][:annual_cooling_dse] = 0.75
  elsif hpxml_file.include? 'hvac_dse' and hpxml_file.include? 'dse-0.8.xml'
    hvac_distributions_values = [{ :id => "HVACDistribution",
                                   :distribution_system_type => "DSE",
                                   :annual_heating_dse => 0.8,
                                   :annual_cooling_dse => 0.8 }]
  elsif ['base-hvac-dse.xml'].include? hpxml_file or
        (hpxml_file.include? 'hvac_partial' and not hvac_distributions_values.empty?) or
        (hpxml_file.include? 'hvac_base' and not hvac_distributions_values.empty?)
    hvac_distributions_values = [{ :id => "HVACDistribution",
                                   :distribution_system_type => "DSE",
                                   :annual_heating_dse => 1,
                                   :annual_cooling_dse => 1 }]
  elsif hpxml_file.include? 'hvac_multiple' and not hvac_distributions_values.empty?
    hvac_distributions_values = [{ :id => "HVACDistribution",
                                   :distribution_system_type => "DSE",
                                   :annual_heating_dse => 1,
                                   :annual_cooling_dse => 1 }]
    hvac_distributions_values << hvac_distributions_values[0].dup
    hvac_distributions_values[1][:id] = "HVACDistribution2"
    hvac_distributions_values << hvac_distributions_values[0].dup
    hvac_distributions_values[2][:id] = "HVACDistribution3"
  end
  return hvac_distributions_values
end

def get_hpxml_file_duct_leakage_measurements_values(hpxml_file, duct_leakage_measurements_values)
  if ['base.xml'].include? hpxml_file
    duct_leakage_measurements_values = [[{ :duct_type => "supply",
                                           :duct_leakage_value => 75 },
                                         { :duct_type => "return",
                                           :duct_leakage_value => 25 }]]
  elsif ['base-hvac-boiler-gas-central-ac-1-speed.xml'].include? hpxml_file
    duct_leakage_measurements_values[0] = []
    duct_leakage_measurements_values << [{ :duct_type => "supply",
                                           :duct_leakage_value => 75 },
                                         { :duct_type => "return",
                                           :duct_leakage_value => 25 }]
  elsif ['base-hvac-mini-split-heat-pump-ducted.xml'].include? hpxml_file
    duct_leakage_measurements_values[0][0][:duct_leakage_value] = 15
    duct_leakage_measurements_values[0][1][:duct_leakage_value] = 5
  elsif ['base-hvac-multiple.xml'].include? hpxml_file
    duct_leakage_measurements_values[0] = []
    duct_leakage_measurements_values[1] = []
    duct_leakage_measurements_values << [{ :duct_type => "supply",
                                           :duct_leakage_value => 75 },
                                         { :duct_type => "return",
                                           :duct_leakage_value => 25 }]
    duct_leakage_measurements_values << [{ :duct_type => "supply",
                                           :duct_leakage_value => 75 },
                                         { :duct_type => "return",
                                           :duct_leakage_value => 25 }]
    duct_leakage_measurements_values << [{ :duct_type => "supply",
                                           :duct_leakage_value => 75 },
                                         { :duct_type => "return",
                                           :duct_leakage_value => 25 }]
    duct_leakage_measurements_values << [{ :duct_type => "supply",
                                           :duct_leakage_value => 75 },
                                         { :duct_type => "return",
                                           :duct_leakage_value => 25 }]
  elsif ['hvac_multiple/base-hvac-air-to-air-heat-pump-1-speed-x3.xml',
         'hvac_multiple/base-hvac-air-to-air-heat-pump-2-speed-x3.xml',
         'hvac_multiple/base-hvac-air-to-air-heat-pump-var-speed-x3.xml',
         'hvac_multiple/base-hvac-central-ac-only-1-speed-x3.xml',
         'hvac_multiple/base-hvac-central-ac-only-2-speed-x3.xml',
         'hvac_multiple/base-hvac-central-ac-only-var-speed-x3.xml',
         'hvac_multiple/base-hvac-furnace-elec-only-x3.xml',
         'hvac_multiple/base-hvac-furnace-gas-only-x3.xml',
         'hvac_multiple/base-hvac-ground-to-air-heat-pump-x3.xml',
         'hvac_multiple/base-hvac-mini-split-heat-pump-ducted-x3.xml'].include? hpxml_file
    duct_leakage_measurements_values[0][0][:duct_leakage_value] /= 3.0
    duct_leakage_measurements_values[0][1][:duct_leakage_value] /= 3.0
    duct_leakage_measurements_values << [{ :duct_type => "supply",
                                           :duct_leakage_value => duct_leakage_measurements_values[0][0][:duct_leakage_value] },
                                         { :duct_type => "return",
                                           :duct_leakage_value => duct_leakage_measurements_values[0][1][:duct_leakage_value] }]
    duct_leakage_measurements_values << [{ :duct_type => "supply",
                                           :duct_leakage_value => duct_leakage_measurements_values[0][0][:duct_leakage_value] },
                                         { :duct_type => "return",
                                           :duct_leakage_value => duct_leakage_measurements_values[0][1][:duct_leakage_value] }]
  end
  return duct_leakage_measurements_values
end

def get_hpxml_file_ducts_values(hpxml_file, ducts_values)
  if ['base.xml'].include? hpxml_file
    ducts_values = [[{ :duct_type => "supply",
                       :duct_insulation_r_value => 4,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 150 },
                     { :duct_type => "return",
                       :duct_insulation_r_value => 0,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 50 }]]
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    ducts_values[0][0][:duct_location] = "basement - unconditioned"
    ducts_values[0][1][:duct_location] = "basement - unconditioned"
  elsif ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
    ducts_values[0][0][:duct_location] = "crawlspace - unvented"
    ducts_values[0][1][:duct_location] = "crawlspace - unvented"
  elsif ['base-foundation-vented-crawlspace.xml'].include? hpxml_file
    ducts_values[0][0][:duct_location] = "crawlspace - vented"
    ducts_values[0][1][:duct_location] = "crawlspace - vented"
  elsif ['base-atticroof-flat.xml'].include? hpxml_file
    ducts_values[0][0][:duct_location] = "basement - conditioned"
    ducts_values[0][1][:duct_location] = "basement - conditioned"
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    ducts_values[0][0][:duct_location] = "attic - vented"
    ducts_values[0][1][:duct_location] = "attic - vented"
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    ducts_values[0][0][:duct_location] = "attic - conditioned"
    ducts_values[0][1][:duct_location] = "attic - conditioned"
  elsif ['base-enclosure-garage.xml',
         'invalid_files/duct-location.xml'].include? hpxml_file
    ducts_values[0][0][:duct_location] = "garage"
    ducts_values[0][1][:duct_location] = "garage"
  elsif ['invalid_files/duct-location-other.xml'].include? hpxml_file
    ducts_values[0][0][:duct_location] = "unconditioned space"
    ducts_values[0][1][:duct_location] = "unconditioned space"
  elsif ['base-hvac-ducts-in-conditioned-space.xml',
         'base-atticroof-cathedral.xml',
         'base-atticroof-conditioned.xml'].include? hpxml_file
    ducts_values[0][0][:duct_location] = "living space"
    ducts_values[0][1][:duct_location] = "living space"
  elsif ['base-hvac-boiler-gas-central-ac-1-speed.xml'].include? hpxml_file
    ducts_values[0] = []
    ducts_values << [{ :duct_type => "supply",
                       :duct_insulation_r_value => 4,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 150 },
                     { :duct_type => "return",
                       :duct_insulation_r_value => 0,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 50 }]
  elsif ['base-hvac-mini-split-heat-pump-ducted.xml'].include? hpxml_file
    ducts_values[0][0][:duct_insulation_r_value] = 0
    ducts_values[0][0][:duct_surface_area] = 30
    ducts_values[0][1][:duct_surface_area] = 10
  elsif ['base-hvac-multiple.xml'].include? hpxml_file
    ducts_values[0] = []
    ducts_values[1] = []
    ducts_values << [{ :duct_type => "supply",
                       :duct_insulation_r_value => 4,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 150 },
                     { :duct_type => "return",
                       :duct_insulation_r_value => 0,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 50 }]
    ducts_values << [{ :duct_type => "supply",
                       :duct_insulation_r_value => 4,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 150 },
                     { :duct_type => "return",
                       :duct_insulation_r_value => 0,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 50 }]
    ducts_values << [{ :duct_type => "supply",
                       :duct_insulation_r_value => 4,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 150 },
                     { :duct_type => "return",
                       :duct_insulation_r_value => 0,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 50 }]
    ducts_values << [{ :duct_type => "supply",
                       :duct_insulation_r_value => 4,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 150 },
                     { :duct_type => "return",
                       :duct_insulation_r_value => 0,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 50 }]
  elsif ['base-hvac-multiple-ducts.xml'].include? hpxml_file
    ducts_values[0] << { :duct_type => "supply",
                         :duct_insulation_r_value => 8,
                         :duct_location => "attic - unvented",
                         :duct_surface_area => 300 }
    ducts_values[0] << { :duct_type => "return",
                         :duct_insulation_r_value => 4,
                         :duct_location => "attic - unvented",
                         :duct_surface_area => 100 }
  elsif ['hvac_multiple/base-hvac-air-to-air-heat-pump-1-speed-x3.xml',
         'hvac_multiple/base-hvac-air-to-air-heat-pump-2-speed-x3.xml',
         'hvac_multiple/base-hvac-air-to-air-heat-pump-var-speed-x3.xml',
         'hvac_multiple/base-hvac-central-ac-only-1-speed-x3.xml',
         'hvac_multiple/base-hvac-central-ac-only-2-speed-x3.xml',
         'hvac_multiple/base-hvac-central-ac-only-var-speed-x3.xml',
         'hvac_multiple/base-hvac-furnace-elec-only-x3.xml',
         'hvac_multiple/base-hvac-furnace-gas-only-x3.xml',
         'hvac_multiple/base-hvac-ground-to-air-heat-pump-x3.xml',
         'hvac_multiple/base-hvac-mini-split-heat-pump-ducted-x3.xml'].include? hpxml_file
    ducts_values[0][0][:duct_surface_area] /= 3.0
    ducts_values[0][1][:duct_surface_area] /= 3.0
    ducts_values << [{ :duct_type => "supply",
                       :duct_insulation_r_value => ducts_values[0][0][:duct_insulation_r_value],
                       :duct_location => ducts_values[0][0][:duct_location],
                       :duct_surface_area => ducts_values[0][0][:duct_surface_area] },
                     { :duct_type => "return",
                       :duct_insulation_r_value => ducts_values[0][1][:duct_insulation_r_value],
                       :duct_location => ducts_values[0][1][:duct_location],
                       :duct_surface_area => ducts_values[0][1][:duct_surface_area] }]
    ducts_values << [{ :duct_type => "supply",
                       :duct_insulation_r_value => ducts_values[0][0][:duct_insulation_r_value],
                       :duct_location => ducts_values[0][0][:duct_location],
                       :duct_surface_area => ducts_values[0][0][:duct_surface_area] },
                     { :duct_type => "return",
                       :duct_insulation_r_value => ducts_values[0][1][:duct_insulation_r_value],
                       :duct_location => ducts_values[0][1][:duct_location],
                       :duct_surface_area => ducts_values[0][1][:duct_surface_area] }]
  end
  return ducts_values
end

def get_hpxml_file_ventilation_fan_values(hpxml_file, ventilation_fans_values)
  if ['base-mechvent-balanced.xml'].include? hpxml_file
    ventilation_fans_values << { :id => "MechanicalVentilation",
                                 :fan_type => "balanced",
                                 :rated_flow_rate => 110,
                                 :hours_in_operation => 24,
                                 :fan_power => 60 }
  elsif ['invalid_files/unattached-cfis.xml',
         'invalid_files/cfis-with-hydronic-distribution.xml',
         'base-mechvent-cfis.xml',
         'cfis/base-cfis.xml',
         'cfis/base-hvac-air-to-air-heat-pump-1-speed-cfis.xml',
         'cfis/base-hvac-air-to-air-heat-pump-2-speed-cfis.xml',
         'cfis/base-hvac-air-to-air-heat-pump-var-speed-cfis.xml',
         'cfis/base-hvac-central-ac-only-1-speed-cfis.xml',
         'cfis/base-hvac-central-ac-only-2-speed-cfis.xml',
         'cfis/base-hvac-central-ac-only-var-speed-cfis.xml',
         'cfis/base-hvac-dse-cfis.xml',
         'cfis/base-hvac-ducts-in-conditioned-space-cfis.xml',
         'cfis/base-hvac-furnace-elec-only-cfis.xml',
         'cfis/base-hvac-furnace-gas-central-ac-2-speed-cfis.xml',
         'cfis/base-hvac-furnace-gas-central-ac-var-speed-cfis.xml',
         'cfis/base-hvac-furnace-gas-only-cfis.xml',
         'cfis/base-hvac-furnace-gas-room-ac-cfis.xml',
         'cfis/base-hvac-ground-to-air-heat-pump-cfis.xml',
         'cfis/base-hvac-room-ac-furnace-gas-cfis.xml'].include? hpxml_file
    ventilation_fans_values << { :id => "MechanicalVentilation",
                                 :fan_type => "central fan integrated supply",
                                 :rated_flow_rate => 110,
                                 :hours_in_operation => 8,
                                 :fan_power => 300,
                                 :distribution_system_idref => "HVACDistribution" }
    if ['invalid_files/unattached-cfis.xml'].include? hpxml_file
      ventilation_fans_values[0][:distribution_system_idref] = "foobar"
    end
  elsif ['base-mechvent-erv.xml'].include? hpxml_file
    ventilation_fans_values << { :id => "MechanicalVentilation",
                                 :fan_type => "energy recovery ventilator",
                                 :rated_flow_rate => 110,
                                 :hours_in_operation => 24,
                                 :total_recovery_efficiency => 0.48,
                                 :sensible_recovery_efficiency => 0.72,
                                 :fan_power => 60 }
  elsif ['base-mechvent-exhaust.xml'].include? hpxml_file
    ventilation_fans_values << { :id => "MechanicalVentilation",
                                 :fan_type => "exhaust only",
                                 :rated_flow_rate => 110,
                                 :hours_in_operation => 24,
                                 :fan_power => 30 }
  elsif ['base-mechvent-hrv.xml'].include? hpxml_file
    ventilation_fans_values << { :id => "MechanicalVentilation",
                                 :fan_type => "heat recovery ventilator",
                                 :rated_flow_rate => 110,
                                 :hours_in_operation => 24,
                                 :sensible_recovery_efficiency => 0.72,
                                 :fan_power => 60 }
  elsif ['base-mechvent-supply.xml'].include? hpxml_file
    ventilation_fans_values << { :id => "MechanicalVentilation",
                                 :fan_type => "supply only",
                                 :rated_flow_rate => 110,
                                 :hours_in_operation => 24,
                                 :fan_power => 30 }
  elsif ['cfis/base-hvac-boiler-gas-central-ac-1-speed-cfis.xml'].include? hpxml_file
    ventilation_fans_values << { :id => "MechanicalVentilation",
                                 :fan_type => "central fan integrated supply",
                                 :rated_flow_rate => 110,
                                 :hours_in_operation => 8,
                                 :fan_power => 300,
                                 :distribution_system_idref => "HVACDistribution2" }
  end
  return ventilation_fans_values
end

def get_hpxml_file_water_heating_system_values(hpxml_file, water_heating_systems_values)
  if ['base.xml'].include? hpxml_file
    water_heating_systems_values = [{ :id => "WaterHeater",
                                      :fuel_type => "electricity",
                                      :water_heater_type => "storage water heater",
                                      :location => "living space",
                                      :tank_volume => 40,
                                      :fraction_dhw_load_served => 1,
                                      :heating_capacity => 18767,
                                      :energy_factor => 0.95 }]
  elsif ['base-dhw-multiple.xml'].include? hpxml_file
    water_heating_systems_values[0][:fraction_dhw_load_served] = 0.2
    water_heating_systems_values << { :id => "WaterHeater2",
                                      :fuel_type => "natural gas",
                                      :water_heater_type => "storage water heater",
                                      :location => "living space",
                                      :tank_volume => 50,
                                      :fraction_dhw_load_served => 0.2,
                                      :heating_capacity => 4500,
                                      :energy_factor => 0.59,
                                      :recovery_efficiency => 0.76 }
    water_heating_systems_values << { :id => "WaterHeater3",
                                      :fuel_type => "electricity",
                                      :water_heater_type => "heat pump water heater",
                                      :location => "living space",
                                      :tank_volume => 80,
                                      :fraction_dhw_load_served => 0.2,
                                      :energy_factor => 2.3 }
    water_heating_systems_values << { :id => "WaterHeater4",
                                      :fuel_type => "electricity",
                                      :water_heater_type => "instantaneous water heater",
                                      :location => "living space",
                                      :fraction_dhw_load_served => 0.2,
                                      :energy_factor => 0.99 }
    water_heating_systems_values << { :id => "WaterHeater5",
                                      :fuel_type => "natural gas",
                                      :water_heater_type => "instantaneous water heater",
                                      :location => "living space",
                                      :fraction_dhw_load_served => 0.2,
                                      :energy_factor => 0.82 }
  elsif ['invalid_files/dhw-frac-load-served.xml'].include? hpxml_file
    water_heating_systems_values[0][:fraction_dhw_load_served] += 0.15
  elsif ['base-dhw-tank-gas.xml'].include? hpxml_file
    water_heating_systems_values[0][:fuel_type] = "natural gas"
    water_heating_systems_values[0][:tank_volume] = 50
    water_heating_systems_values[0][:heating_capacity] = 4500
    water_heating_systems_values[0][:energy_factor] = 0.59
    water_heating_systems_values[0][:recovery_efficiency] = 0.76
  elsif ['base-dhw-tank-heat-pump.xml'].include? hpxml_file
    water_heating_systems_values[0][:water_heater_type] = "heat pump water heater"
    water_heating_systems_values[0][:tank_volume] = 80
    water_heating_systems_values[0][:heating_capacity] = nil
    water_heating_systems_values[0][:energy_factor] = 2.3
  elsif ['base-dhw-tankless-electric.xml'].include? hpxml_file
    water_heating_systems_values[0][:water_heater_type] = "instantaneous water heater"
    water_heating_systems_values[0][:tank_volume] = nil
    water_heating_systems_values[0][:heating_capacity] = nil
    water_heating_systems_values[0][:energy_factor] = 0.99
  elsif ['base-dhw-tankless-gas.xml'].include? hpxml_file
    water_heating_systems_values[0][:fuel_type] = "natural gas"
    water_heating_systems_values[0][:water_heater_type] = "instantaneous water heater"
    water_heating_systems_values[0][:tank_volume] = nil
    water_heating_systems_values[0][:heating_capacity] = nil
    water_heating_systems_values[0][:energy_factor] = 0.82
  elsif ['base-dhw-tankless-oil.xml'].include? hpxml_file
    water_heating_systems_values[0][:fuel_type] = "fuel oil"
    water_heating_systems_values[0][:water_heater_type] = "instantaneous water heater"
    water_heating_systems_values[0][:tank_volume] = nil
    water_heating_systems_values[0][:heating_capacity] = nil
    water_heating_systems_values[0][:energy_factor] = 0.82
  elsif ['base-dhw-tankless-propane.xml'].include? hpxml_file
    water_heating_systems_values[0][:fuel_type] = "propane"
    water_heating_systems_values[0][:water_heater_type] = "instantaneous water heater"
    water_heating_systems_values[0][:tank_volume] = nil
    water_heating_systems_values[0][:heating_capacity] = nil
    water_heating_systems_values[0][:energy_factor] = 0.82
  elsif ['base-dhw-tank-oil.xml'].include? hpxml_file
    water_heating_systems_values[0][:fuel_type] = "fuel oil"
    water_heating_systems_values[0][:tank_volume] = 50
    water_heating_systems_values[0][:heating_capacity] = 4500
    water_heating_systems_values[0][:energy_factor] = 0.59
    water_heating_systems_values[0][:recovery_efficiency] = 0.76
  elsif ['base-dhw-tank-propane.xml'].include? hpxml_file
    water_heating_systems_values[0][:fuel_type] = "propane"
    water_heating_systems_values[0][:tank_volume] = 50
    water_heating_systems_values[0][:heating_capacity] = 4500
    water_heating_systems_values[0][:energy_factor] = 0.59
    water_heating_systems_values[0][:recovery_efficiency] = 0.76
  elsif ['base-dhw-uef.xml'].include? hpxml_file
    water_heating_systems_values[0][:energy_factor] = nil
    water_heating_systems_values[0][:uniform_energy_factor] = 0.93
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    water_heating_systems_values[0][:location] = "basement - unconditioned"
  elsif ['base-foundation-unvented-crawlspace.xml'].include? hpxml_file
    water_heating_systems_values[0][:location] = "crawlspace - unvented"
  elsif ['base-foundation-vented-crawlspace.xml'].include? hpxml_file
    water_heating_systems_values[0][:location] = "crawlspace - vented"
  elsif ['base-foundation-slab.xml'].include? hpxml_file
    water_heating_systems_values[0][:location] = "living space"
  elsif ['base-atticroof-vented.xml'].include? hpxml_file
    water_heating_systems_values[0][:location] = "attic - vented"
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    water_heating_systems_values[0][:location] = "basement - conditioned"
  elsif ['invalid_files/water-heater-location.xml'].include? hpxml_file
    water_heating_systems_values[0][:location] = "crawlspace - vented"
  elsif ['invalid_files/water-heater-location-other.xml'].include? hpxml_file
    water_heating_systems_values[0][:location] = "unconditioned space"
  elsif ['base-enclosure-garage.xml'].include? hpxml_file
    water_heating_systems_values[0][:location] = "garage"
  elsif ['base-dhw-none.xml'].include? hpxml_file
    water_heating_systems_values = []
  elsif hpxml_file.include? 'water_heating_multiple' and not water_heating_systems_values.nil? and water_heating_systems_values.size > 0
    water_heating_systems_values[0][:fraction_dhw_load_served] = 0.333
    water_heating_systems_values << water_heating_systems_values[0].dup
    water_heating_systems_values[1][:id] = "WaterHeater2"
    water_heating_systems_values << water_heating_systems_values[0].dup
    water_heating_systems_values[2][:id] = "WaterHeater3"
  end
  return water_heating_systems_values
end

def get_hpxml_file_hot_water_distribution_values(hpxml_file, hot_water_distribution_values)
  if ['base.xml'].include? hpxml_file
    hot_water_distribution_values = { :id => "HotWaterDstribution",
                                      :system_type => "Standard",
                                      :standard_piping_length => 30,
                                      :pipe_r_value => 0.0 }
  elsif ['base-dhw-dwhr.xml'].include? hpxml_file
    hot_water_distribution_values[:dwhr_facilities_connected] = "all"
    hot_water_distribution_values[:dwhr_equal_flow] = true
    hot_water_distribution_values[:dwhr_efficiency] = 0.55
  elsif ['base-dhw-recirc-demand.xml'].include? hpxml_file
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "presence sensor demand control"
    hot_water_distribution_values[:recirculation_piping_length] = 30
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
    hot_water_distribution_values[:pipe_r_value] = 3
  elsif ['base-dhw-recirc-manual.xml'].include? hpxml_file
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "manual demand control"
    hot_water_distribution_values[:recirculation_piping_length] = 30
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
    hot_water_distribution_values[:pipe_r_value] = 3
  elsif ['base-dhw-recirc-nocontrol.xml'].include? hpxml_file
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "no control"
    hot_water_distribution_values[:recirculation_piping_length] = 30
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
  elsif ['base-dhw-recirc-temperature.xml'].include? hpxml_file
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "temperature"
    hot_water_distribution_values[:recirculation_piping_length] = 30
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
  elsif ['base-dhw-recirc-timer.xml'].include? hpxml_file
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "timer"
    hot_water_distribution_values[:recirculation_piping_length] = 30
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
  elsif ['base-dhw-none.xml'].include? hpxml_file
    hot_water_distribution_values = {}
  end
  return hot_water_distribution_values
end

def get_hpxml_file_water_fixtures_values(hpxml_file, water_fixtures_values)
  if ['base.xml'].include? hpxml_file
    water_fixtures_values = [{ :id => "WaterFixture",
                               :water_fixture_type => "shower head",
                               :low_flow => true },
                             { :id => "WaterFixture2",
                               :water_fixture_type => "faucet",
                               :low_flow => false }]
  elsif ['base-dhw-low-flow-fixtures.xml'].include? hpxml_file
    water_fixtures_values[1][:low_flow] = true
  elsif ['base-dhw-none.xml'].include? hpxml_file
    water_fixtures_values = []
  end
  return water_fixtures_values
end

def get_hpxml_file_pv_system_values(hpxml_file, pv_systems_values)
  if ['base-pv-array-1axis.xml'].include? hpxml_file
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "standard",
                           :location => "ground",
                           :tracking => "1-axis",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  elsif ['base-pv-array-1axis-backtracked.xml'].include? hpxml_file
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "standard",
                           :location => "ground",
                           :tracking => "1-axis backtracked",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  elsif ['base-pv-array-2axis.xml'].include? hpxml_file
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "standard",
                           :location => "ground",
                           :tracking => "2-axis",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  elsif ['base-pv-array-fixed-open-rack.xml'].include? hpxml_file
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "standard",
                           :location => "ground",
                           :tracking => "fixed",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  elsif ['base-pv-module-premium.xml'].include? hpxml_file
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "premium",
                           :location => "roof",
                           :tracking => "fixed",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  elsif ['base-pv-module-standard.xml'].include? hpxml_file
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "standard",
                           :location => "roof",
                           :tracking => "fixed",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  elsif ['base-pv-module-thinfilm.xml'].include? hpxml_file
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "thin film",
                           :location => "roof",
                           :tracking => "fixed",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  elsif ['base-pv-multiple.xml'].include? hpxml_file
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "standard",
                           :location => "roof",
                           :tracking => "fixed",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
    pv_systems_values << { :id => "PVSystem2",
                           :module_type => "standard",
                           :location => "roof",
                           :tracking => "fixed",
                           :array_azimuth => 90,
                           :array_tilt => 20,
                           :max_power_output => 1500,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  end
  return pv_systems_values
end

def get_hpxml_file_clothes_washer_values(hpxml_file, clothes_washer_values)
  if ['base.xml'].include? hpxml_file
    clothes_washer_values = { :id => "ClothesWasher",
                              :location => "living space",
                              :modified_energy_factor => 1.2,
                              :rated_annual_kwh => 387.0,
                              :label_electric_rate => 0.127,
                              :label_gas_rate => 1.003,
                              :label_annual_gas_cost => 24.0,
                              :capacity => 3.5 }
  elsif ['base-appliances-none.xml'].include? hpxml_file
    clothes_washer_values = {}
  elsif ['base-appliances-washer-imef.xml'].include? hpxml_file
    clothes_washer_values[:modified_energy_factor] = nil
    clothes_washer_values[:integrated_modified_energy_factor] = 0.73
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    clothes_washer_values[:location] = "basement - unconditioned"
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    clothes_washer_values[:location] = "basement - conditioned"
  elsif ['base-enclosure-garage.xml',
         'invalid_files/clothes-washer-location.xml'].include? hpxml_file
    clothes_washer_values[:location] = "garage"
  elsif ['invalid_files/clothes-washer-location-other.xml'].include? hpxml_file
    clothes_washer_values[:location] = "other"
  end
  return clothes_washer_values
end

def get_hpxml_file_clothes_dryer_values(hpxml_file, clothes_dryer_values)
  if ['base.xml'].include? hpxml_file
    clothes_dryer_values = { :id => "ClothesDryer",
                             :location => "living space",
                             :fuel_type => "electricity",
                             :energy_factor => 3.01,
                             :control_type => "timer" }
  elsif ['base-appliances-none.xml'].include? hpxml_file
    clothes_dryer_values = {}
  elsif ['base-appliances-dryer-cef.xml'].include? hpxml_file
    clothes_dryer_values = { :id => "ClothesDryer",
                             :location => "living space",
                             :fuel_type => "electricity",
                             :combined_energy_factor => 2.62,
                             :control_type => "moisture" }
  elsif ['base-appliances-gas.xml'].include? hpxml_file
    clothes_dryer_values = { :id => "ClothesDryer",
                             :location => "living space",
                             :fuel_type => "natural gas",
                             :energy_factor => 2.67,
                             :control_type => "moisture" }
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    clothes_dryer_values[:location] = "basement - unconditioned"
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    clothes_dryer_values[:location] = "basement - conditioned"
  elsif ['base-enclosure-garage.xml',
         'invalid_files/clothes-dryer-location.xml'].include? hpxml_file
    clothes_dryer_values[:location] = "garage"
  elsif ['invalid_files/clothes-dryer-location-other.xml'].include? hpxml_file
    clothes_dryer_values[:location] = "other"
  end
  return clothes_dryer_values
end

def get_hpxml_file_dishwasher_values(hpxml_file, dishwasher_values)
  if ['base.xml'].include? hpxml_file
    dishwasher_values = { :id => "Dishwasher",
                          :rated_annual_kwh => 100,
                          :place_setting_capacity => 12 }
  elsif ['base-appliances-none.xml'].include? hpxml_file
    dishwasher_values = {}
  elsif ['base-appliances-dishwasher-ef.xml'].include? hpxml_file
    dishwasher_values = { :id => "Dishwasher",
                          :energy_factor => 0.5,
                          :place_setting_capacity => 8 }
  end
  return dishwasher_values
end

def get_hpxml_file_refrigerator_values(hpxml_file, refrigerator_values)
  if ['base.xml'].include? hpxml_file
    refrigerator_values = { :id => "Refrigerator",
                            :location => "living space",
                            :rated_annual_kwh => 609 }
  elsif ['base-appliances-none.xml'].include? hpxml_file
    refrigerator_values = {}
  elsif ['base-foundation-unconditioned-basement.xml'].include? hpxml_file
    refrigerator_values[:location] = "basement - unconditioned"
  elsif ['base-atticroof-conditioned.xml'].include? hpxml_file
    refrigerator_values[:location] = "basement - conditioned"
  elsif ['base-enclosure-garage.xml',
         'invalid_files/refrigerator-location.xml'].include? hpxml_file
    refrigerator_values[:location] = "garage"
  elsif ['invalid_files/refrigerator-location-other.xml'].include? hpxml_file
    refrigerator_values[:location] = "other"
  end
  return refrigerator_values
end

def get_hpxml_file_cooking_range_values(hpxml_file, cooking_range_values)
  if ['base.xml'].include? hpxml_file
    cooking_range_values = { :id => "Range",
                             :fuel_type => "electricity",
                             :is_induction => true }
  elsif ['base-appliances-none.xml'].include? hpxml_file
    cooking_range_values = {}
  elsif ['base-appliances-gas.xml'].include? hpxml_file
    cooking_range_values[:fuel_type] = "natural gas"
    cooking_range_values[:is_induction] = false
  end
  return cooking_range_values
end

def get_hpxml_file_oven_values(hpxml_file, oven_values)
  if ['base.xml'].include? hpxml_file
    oven_values = { :id => "Oven",
                    :is_convection => true }
  elsif ['base-appliances-none.xml'].include? hpxml_file
    oven_values = {}
  end
  return oven_values
end

def get_hpxml_file_lighting_values(hpxml_file, lighting_values)
  if ['base.xml'].include? hpxml_file
    lighting_values = { :fraction_tier_i_interior => 0.5,
                        :fraction_tier_i_exterior => 0.5,
                        :fraction_tier_i_garage => 0.5,
                        :fraction_tier_ii_interior => 0.25,
                        :fraction_tier_ii_exterior => 0.25,
                        :fraction_tier_ii_garage => 0.25 }
  elsif ['base-misc-lighting-none.xml'].include? hpxml_file
    lighting_values = {}
  end
  return lighting_values
end

def get_hpxml_file_ceiling_fan_values(hpxml_file, ceiling_fans_values)
  if ['base-misc-ceiling-fans.xml'].include? hpxml_file
    ceiling_fans_values << { :id => "CeilingFan",
                             :efficiency => 100,
                             :quantity => 2 }
  end
  return ceiling_fans_values
end

def get_hpxml_file_plug_loads_values(hpxml_file, plug_loads_values)
  if ['base-misc-loads-detailed.xml'].include? hpxml_file
    plug_loads_values << { :id => "PlugLoadMisc",
                           :plug_load_type => "other",
                           :kWh_per_year => 7302,
                           :frac_sensible => 0.82,
                           :frac_latent => 0.18 }
    plug_loads_values << { :id => "PlugLoadMisc2",
                           :plug_load_type => "TV other",
                           :kWh_per_year => 400 }
  end
  return plug_loads_values
end

def get_hpxml_file_misc_load_schedule_values(hpxml_file, misc_load_schedule_values)
  if ['base-misc-loads-detailed.xml'].include? hpxml_file
    misc_load_schedule_values = { :weekday_fractions => "0.020, 0.020, 0.020, 0.020, 0.020, 0.034, 0.043, 0.085, 0.050, 0.030, 0.030, 0.041, 0.030, 0.025, 0.026, 0.026, 0.039, 0.042, 0.045, 0.070, 0.070, 0.073, 0.073, 0.066",
                                  :weekend_fractions => "0.020, 0.020, 0.020, 0.020, 0.020, 0.034, 0.043, 0.085, 0.050, 0.030, 0.030, 0.041, 0.030, 0.025, 0.026, 0.026, 0.039, 0.042, 0.045, 0.070, 0.070, 0.073, 0.073, 0.066",
                                  :monthly_multipliers => "1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0" }
  end
  return misc_load_schedule_values
end
