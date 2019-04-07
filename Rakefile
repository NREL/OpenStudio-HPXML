require 'rake'
require 'rake/testtask'
require 'ci/reporter/rake/minitest'
require_relative "resources/hpxml"

desc 'update all measures'
task :update_measures do
  # Apply rubocop
  command = "rubocop --auto-correct --format simple --only Layout"
  puts "Applying rubocop style to measures..."
  system(command)

  create_hpxmls
end

def create_hpxmls
  puts "Generating HPXML files..."

  this_dir = File.dirname(__FILE__)
  tests_dir = File.join(this_dir, "tests")

  # Hash of HPXML -> Parent HPXML
  hpxmls_files = {
    'valid.xml' => nil,
    'invalid_files/invalid-bad-wmo.xml' => 'valid.xml',
    'invalid_files/invalid-missing-elements.xml' => 'valid.xml',
    'invalid_files/invalid-missing-surfaces.xml' => 'valid.xml',
    'invalid_files/invalid-net-area-negative-roof.xml' => 'valid-enclosure-skylights.xml',
    'invalid_files/invalid-net-area-negative-wall.xml' => 'valid.xml',
    'invalid_files/invalid-unattached-cfis.xml.skip' => 'valid.xml',
    'invalid_files/invalid-unattached-door.xml' => 'valid.xml',
    'invalid_files/invalid-unattached-hvac.xml.skip' => 'valid.xml',
    'invalid_files/invalid-unattached-skylight.xml' => 'valid-enclosure-skylights.xml',
    'invalid_files/invalid-unattached-window.xml' => 'valid.xml',
    'valid-addenda-exclude-g.xml' => 'valid.xml',
    'valid-addenda-exclude-g-e.xml' => 'valid.xml',
    'valid-addenda-exclude-g-e-a.xml' => 'valid.xml',
    'valid-appliances-dishwasher-ef.xml' => 'valid.xml',
    'valid-appliances-dryer-cef.xml' => 'valid.xml',
    'valid-appliances-gas.xml' => 'valid.xml',
    'valid-appliances-in-basement.xml' => 'valid.xml',
    'valid-appliances-none.xml' => 'valid.xml',
    'valid-appliances-washer-imef.xml' => 'valid.xml',
    'valid-atticroof-cathedral.xml' => 'valid.xml',
    'valid-atticroof-conditioned.xml' => 'valid.xml',
    'valid-atticroof-flat.xml' => 'valid.xml',
    'valid-atticroof-vented.xml' => 'valid.xml',
    'valid-dhw-dwhr.xml' => 'valid.xml',
    'valid-dhw-location-attic.xml' => 'valid.xml',
    'valid-dhw-low-flow-fixtures.xml' => 'valid.xml',
    'valid-dhw-multiple.xml' => 'valid.xml',
    'valid-dhw-none.xml' => 'valid.xml',
    'valid-dhw-recirc-demand.xml' => 'valid.xml',
    'valid-dhw-recirc-manual.xml' => 'valid.xml',
    'valid-dhw-recirc-nocontrol.xml' => 'valid.xml',
    'valid-dhw-recirc-temperature.xml' => 'valid.xml',
    'valid-dhw-recirc-timer.xml' => 'valid.xml',
    'valid-dhw-recirc-timer-reference.xml' => 'valid-dhw-recirc-timer.xml',
    'valid-dhw-standard-reference.xml' => 'valid.xml',
    'valid-dhw-tank-gas.xml' => 'valid.xml',
    'valid-dhw-tank-heat-pump.xml' => 'valid.xml',
    'valid-dhw-tankless-electric.xml' => 'valid.xml',
    'valid-dhw-tankless-gas.xml' => 'valid.xml',
    'valid-dhw-tankless-oil.xml' => 'valid.xml',
    'valid-dhw-tankless-propane.xml' => 'valid.xml',
    'valid-dhw-tank-oil.xml' => 'valid.xml',
    'valid-dhw-tank-propane.xml' => 'valid.xml',
    'valid-dhw-uef.xml' => 'valid.xml',
    'valid-enclosure-doors-reference.xml' => 'valid.xml',
    'valid-enclosure-multiple-walls.xml' => 'valid.xml',
    'valid-enclosure-no-natural-ventilation.xml' => 'valid.xml',
    'valid-enclosure-orientation-45.xml' => 'valid.xml',
    'valid-enclosure-overhangs.xml' => 'valid.xml',
    'valid-enclosure-skylights.xml' => 'valid.xml',
    'valid-enclosure-walltype-cmu.xml' => 'valid.xml',
    'valid-enclosure-walltype-doublestud.xml' => 'valid.xml',
    'valid-enclosure-walltype-icf.xml' => 'valid.xml',
    'valid-enclosure-walltype-log.xml' => 'valid.xml',
    'valid-enclosure-walltype-sip.xml' => 'valid.xml',
    'valid-enclosure-walltype-solidconcrete.xml' => 'valid.xml',
    'valid-enclosure-walltype-steelstud.xml' => 'valid.xml',
    'valid-enclosure-walltype-stone.xml' => 'valid.xml',
    'valid-enclosure-walltype-strawbale.xml' => 'valid.xml',
    'valid-enclosure-walltype-structuralbrick.xml' => 'valid.xml',
    'valid-enclosure-walltype-woodstud-reference.xml' => 'valid.xml',
    'valid-enclosure-windows-interior-shading.xml' => 'valid.xml',
    'valid-foundation-conditioned-basement-reference.xml' => 'valid.xml',
    'valid-foundation-pier-beam.xml' => 'valid.xml',
    'valid-foundation-pier-beam-reference.xml' => 'valid-foundation-pier-beam.xml',
    'valid-foundation-slab.xml' => 'valid.xml',
    'valid-foundation-slab-reference.xml' => 'valid-foundation-slab.xml',
    'valid-foundation-unconditioned-basement.xml' => 'valid.xml',
    'valid-foundation-unconditioned-basement-reference.xml' => 'valid-foundation-unconditioned-basement.xml',
    'valid-foundation-unvented-crawlspace.xml' => 'valid.xml',
    'valid-foundation-unvented-crawlspace-reference.xml' => 'valid-foundation-unvented-crawlspace.xml',
    'valid-foundation-vented-crawlspace.xml' => 'valid.xml',
    'valid-foundation-vented-crawlspace-reference.xml' => 'valid-foundation-vented-crawlspace.xml',
    'valid-hvac-air-to-air-heat-pump-1-speed.xml' => 'valid.xml',
    'valid-hvac-air-to-air-heat-pump-2-speed.xml' => 'valid.xml',
    'valid-hvac-air-to-air-heat-pump-var-speed.xml' => 'valid.xml',
    'valid-hvac-boiler-elec-only.xml' => 'valid.xml',
    'valid-hvac-boiler-gas-central-ac-1-speed.xml' => 'valid.xml',
    'valid-hvac-boiler-gas-only.xml' => 'valid.xml',
    'valid-hvac-boiler-gas-only-no-eae.xml' => 'valid-hvac-boiler-gas-only.xml',
    'valid-hvac-boiler-oil-only.xml' => 'valid.xml',
    'valid-hvac-boiler-propane-only.xml' => 'valid.xml',
    'valid-hvac-central-ac-only-1-speed.xml' => 'valid.xml',
    'valid-hvac-central-ac-only-2-speed.xml' => 'valid.xml',
    'valid-hvac-central-ac-only-var-speed.xml' => 'valid.xml',
    'valid-hvac-elec-resistance-only.xml' => 'valid.xml',
    'valid-hvac-furnace-elec-only.xml' => 'valid.xml',
    'valid-hvac-furnace-gas-central-ac-2-speed.xml' => 'valid.xml',
    'valid-hvac-furnace-gas-central-ac-var-speed.xml' => 'valid.xml',
    'valid-hvac-furnace-gas-only.xml' => 'valid.xml',
    'valid-hvac-furnace-gas-only-no-eae.xml' => 'valid-hvac-furnace-gas-only.xml',
    'valid-hvac-furnace-gas-room-ac.xml' => 'valid.xml',
    'valid-hvac-furnace-oil-only.xml' => 'valid.xml',
    'valid-hvac-furnace-propane-only.xml' => 'valid.xml',
    'valid-hvac-ground-to-air-heat-pump.xml' => 'valid.xml',
    'valid-hvac-ideal-air.xml' => 'valid.xml',
    'valid-hvac-mini-split-heat-pump-ducted.xml' => 'valid.xml',
    'valid-hvac-mini-split-heat-pump-ductless.xml' => 'valid-hvac-mini-split-heat-pump-ducted.xml',
    'valid-hvac-mini-split-heat-pump-ductless-no-backup.xml' => 'valid-hvac-mini-split-heat-pump-ductless.xml',
    'valid-hvac-multiple.xml' => 'valid.xml',
    'valid-hvac-none.xml' => 'valid.xml',
    'valid-hvac-none-no-fuel-access.xml' => 'valid-hvac-none.xml',
    'valid-hvac-programmable-thermostat.xml' => 'valid.xml',
    'valid-hvac-room-ac-furnace-gas.xml' => 'valid.xml',
    'valid-hvac-room-ac-only.xml' => 'valid.xml',
    'valid-hvac-setpoints.xml' => 'valid.xml',
    'valid-hvac-stove-oil-only.xml' => 'valid.xml',
    'valid-hvac-stove-oil-only-no-eae.xml' => 'valid-hvac-stove-oil-only.xml',
    'valid-hvac-wall-furnace-propane-only.xml' => 'valid.xml',
    'valid-hvac-wall-furnace-propane-only-no-eae.xml' => 'valid-hvac-wall-furnace-propane-only.xml',
    'valid-infiltration-ach-natural.xml' => 'valid.xml',
    'valid-mechvent-balanced.xml' => 'valid.xml',
    'valid-mechvent-cfis.xml' => 'valid.xml',
    'valid-mechvent-erv.xml' => 'valid.xml',
    'valid-mechvent-exhaust.xml' => 'valid.xml',
    'valid-mechvent-hrv.xml' => 'valid.xml',
    'valid-mechvent-supply.xml' => 'valid.xml',
    'valid-misc-appliances-in-basement.xml' => 'valid.xml',
    'valid-misc-ceiling-fans.xml' => 'valid.xml',
    'valid-misc-ceiling-fans-reference.xml' => 'valid-misc-ceiling-fans.xml',
    'valid-misc-lighting-default.xml' => 'valid.xml',
    'valid-misc-lighting-none.xml' => 'valid.xml',
    'valid-misc-loads-detailed.xml' => 'valid.xml',
    'valid-misc-number-of-occupants.xml' => 'valid.xml',
    'valid-pv-array-1axis.xml' => 'valid.xml',
    'valid-pv-array-1axis-backtracked.xml' => 'valid.xml',
    'valid-pv-array-2axis.xml' => 'valid.xml',
    'valid-pv-array-fixed-open-rack.xml' => 'valid.xml',
    'valid-pv-module-premium.xml' => 'valid.xml',
    'valid-pv-module-standard.xml' => 'valid.xml',
    'valid-pv-module-thinfilm.xml.skip' => 'valid.xml',
    'valid-pv-multiple.xml' => 'valid.xml',
    'cfis/valid-cfis.xml' => 'valid.xml',
    'cfis/valid-hvac-air-to-air-heat-pump-1-speed-cfis.xml' => 'valid-hvac-air-to-air-heat-pump-1-speed.xml',
    'cfis/valid-hvac-air-to-air-heat-pump-2-speed-cfis.xml' => 'valid-hvac-air-to-air-heat-pump-2-speed.xml',
    'cfis/valid-hvac-air-to-air-heat-pump-var-speed-cfis.xml' => 'valid-hvac-air-to-air-heat-pump-var-speed.xml',
    'cfis/valid-hvac-boiler-gas-central-ac-1-speed-cfis.xml' => 'valid-hvac-boiler-gas-central-ac-1-speed.xml',
    'cfis/valid-hvac-central-ac-only-1-speed-cfis.xml' => 'valid-hvac-central-ac-only-1-speed.xml',
    'cfis/valid-hvac-central-ac-only-2-speed-cfis.xml' => 'valid-hvac-central-ac-only-2-speed.xml',
    'cfis/valid-hvac-central-ac-only-var-speed-cfis.xml' => 'valid-hvac-central-ac-only-var-speed.xml',
    'cfis/valid-hvac-furnace-elec-only-cfis.xml' => 'valid-hvac-furnace-elec-only.xml',
    'cfis/valid-hvac-furnace-gas-central-ac-2-speed-cfis.xml' => 'valid-hvac-furnace-gas-central-ac-2-speed.xml',
    'cfis/valid-hvac-furnace-gas-central-ac-var-speed-cfis.xml' => 'valid-hvac-furnace-gas-central-ac-var-speed.xml',
    'cfis/valid-hvac-furnace-gas-only-cfis.xml' => 'valid-hvac-furnace-gas-only.xml',
    'cfis/valid-hvac-furnace-gas-room-ac-cfis.xml' => 'valid-hvac-furnace-gas-room-ac.xml',
    'cfis/valid-hvac-ground-to-air-heat-pump-cfis.xml' => 'valid-hvac-ground-to-air-heat-pump.xml',
    'cfis/valid-hvac-room-ac-furnace-gas-cfis.xml' => 'valid-hvac-room-ac-furnace-gas.xml',
    'hvac_autosizing/valid-autosize.xml' => 'valid.xml',
    'hvac_autosizing/valid-hvac-air-to-air-heat-pump-1-speed-autosize.xml' => 'valid-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_autosizing/valid-hvac-air-to-air-heat-pump-2-speed-autosize.xml' => 'valid-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_autosizing/valid-hvac-air-to-air-heat-pump-var-speed-autosize.xml' => 'valid-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_autosizing/valid-hvac-boiler-elec-only-autosize.xml' => 'valid-hvac-boiler-elec-only.xml',
    'hvac_autosizing/valid-hvac-boiler-gas-central-ac-1-speed-autosize.xml' => 'valid-hvac-boiler-gas-central-ac-1-speed.xml',
    'hvac_autosizing/valid-hvac-boiler-gas-only-autosize.xml' => 'valid-hvac-boiler-gas-only.xml',
    'hvac_autosizing/valid-hvac-central-ac-only-1-speed-autosize.xml' => 'valid-hvac-central-ac-only-1-speed.xml',
    'hvac_autosizing/valid-hvac-central-ac-only-2-speed-autosize.xml' => 'valid-hvac-central-ac-only-2-speed.xml',
    'hvac_autosizing/valid-hvac-central-ac-only-var-speed-autosize.xml' => 'valid-hvac-central-ac-only-var-speed.xml',
    'hvac_autosizing/valid-hvac-elec-resistance-only-autosize.xml' => 'valid-hvac-elec-resistance-only.xml',
    'hvac_autosizing/valid-hvac-furnace-elec-only-autosize.xml' => 'valid-hvac-furnace-elec-only.xml',
    'hvac_autosizing/valid-hvac-furnace-gas-central-ac-2-speed-autosize.xml' => 'valid-hvac-furnace-gas-central-ac-2-speed.xml',
    'hvac_autosizing/valid-hvac-furnace-gas-central-ac-var-speed-autosize.xml' => 'valid-hvac-furnace-gas-central-ac-var-speed.xml',
    'hvac_autosizing/valid-hvac-furnace-gas-only-autosize.xml' => 'valid-hvac-furnace-gas-only.xml',
    'hvac_autosizing/valid-hvac-furnace-gas-room-ac-autosize.xml' => 'valid-hvac-furnace-gas-room-ac.xml',
    'hvac_autosizing/valid-hvac-ground-to-air-heat-pump-autosize.xml' => 'valid-hvac-ground-to-air-heat-pump.xml',
    'hvac_autosizing/valid-hvac-mini-split-heat-pump-ducted-autosize.xml' => 'valid-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_autosizing/valid-hvac-mini-split-heat-pump-ductless-autosize.xml' => 'valid-hvac-mini-split-heat-pump-ductless.xml',
    'hvac_autosizing/valid-hvac-room-ac-furnace-gas-autosize.xml' => 'valid-hvac-room-ac-furnace-gas.xml',
    'hvac_autosizing/valid-hvac-room-ac-only-autosize.xml' => 'valid-hvac-room-ac-only.xml',
    'hvac_autosizing/valid-hvac-stove-oil-only-autosize.xml' => 'valid-hvac-stove-oil-only.xml',
    'hvac_autosizing/valid-hvac-wall-furnace-propane-only-autosize.xml' => 'valid-hvac-wall-furnace-propane-only.xml',
    'hvac_dse/valid-dse-0.8.xml' => 'valid.xml',
    'hvac_dse/valid-dse-1.0.xml' => 'hvac_dse/valid-dse-0.8.xml',
    'hvac_dse/valid-hvac-air-to-air-heat-pump-1-speed-dse-0.8.xml' => 'valid-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_dse/valid-hvac-air-to-air-heat-pump-1-speed-dse-1.0.xml' => 'hvac_dse/valid-hvac-air-to-air-heat-pump-1-speed-dse-0.8.xml',
    'hvac_dse/valid-hvac-air-to-air-heat-pump-2-speed-dse-0.8.xml' => 'valid-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_dse/valid-hvac-air-to-air-heat-pump-2-speed-dse-1.0.xml' => 'hvac_dse/valid-hvac-air-to-air-heat-pump-2-speed-dse-0.8.xml',
    'hvac_dse/valid-hvac-air-to-air-heat-pump-var-speed-dse-0.8.xml' => 'valid-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_dse/valid-hvac-air-to-air-heat-pump-var-speed-dse-1.0.xml' => 'hvac_dse/valid-hvac-air-to-air-heat-pump-var-speed-dse-0.8.xml',
    'hvac_dse/valid-hvac-boiler-elec-only-dse-0.8.xml' => 'valid-hvac-boiler-elec-only.xml',
    'hvac_dse/valid-hvac-boiler-elec-only-dse-1.0.xml' => 'hvac_dse/valid-hvac-boiler-elec-only-dse-0.8.xml',
    'hvac_dse/valid-hvac-boiler-gas-only-dse-0.8.xml' => 'valid-hvac-boiler-gas-only.xml',
    'hvac_dse/valid-hvac-boiler-gas-only-dse-1.0.xml' => 'hvac_dse/valid-hvac-boiler-gas-only-dse-0.8.xml',
    'hvac_dse/valid-hvac-central-ac-only-1-speed-dse-0.8.xml' => 'valid-hvac-central-ac-only-1-speed.xml',
    'hvac_dse/valid-hvac-central-ac-only-1-speed-dse-1.0.xml' => 'hvac_dse/valid-hvac-central-ac-only-1-speed-dse-0.8.xml',
    'hvac_dse/valid-hvac-central-ac-only-2-speed-dse-0.8.xml' => 'valid-hvac-central-ac-only-2-speed.xml',
    'hvac_dse/valid-hvac-central-ac-only-2-speed-dse-1.0.xml' => 'hvac_dse/valid-hvac-central-ac-only-2-speed-dse-0.8.xml',
    'hvac_dse/valid-hvac-central-ac-only-var-speed-dse-0.8.xml' => 'valid-hvac-central-ac-only-var-speed.xml',
    'hvac_dse/valid-hvac-central-ac-only-var-speed-dse-1.0.xml' => 'hvac_dse/valid-hvac-central-ac-only-var-speed-dse-0.8.xml',
    'hvac_dse/valid-hvac-furnace-elec-only-dse-0.8.xml' => 'valid-hvac-furnace-elec-only.xml',
    'hvac_dse/valid-hvac-furnace-elec-only-dse-1.0.xml' => 'hvac_dse/valid-hvac-furnace-elec-only-dse-0.8.xml',
    'hvac_dse/valid-hvac-furnace-gas-central-ac-2-speed-dse-0.8.xml' => 'valid-hvac-furnace-gas-central-ac-2-speed.xml',
    'hvac_dse/valid-hvac-furnace-gas-central-ac-2-speed-dse-1.0.xml' => 'hvac_dse/valid-hvac-furnace-gas-central-ac-2-speed-dse-0.8.xml',
    'hvac_dse/valid-hvac-furnace-gas-central-ac-var-speed-dse-0.8.xml' => 'valid-hvac-furnace-gas-central-ac-var-speed.xml',
    'hvac_dse/valid-hvac-furnace-gas-central-ac-var-speed-dse-1.0.xml' => 'hvac_dse/valid-hvac-furnace-gas-central-ac-var-speed-dse-0.8.xml',
    'hvac_dse/valid-hvac-furnace-gas-only-dse-0.8.xml' => 'valid-hvac-furnace-gas-only.xml',
    'hvac_dse/valid-hvac-furnace-gas-only-dse-1.0.xml' => 'hvac_dse/valid-hvac-furnace-gas-only-dse-0.8.xml',
    'hvac_dse/valid-hvac-furnace-gas-room-ac-dse-0.8.xml' => 'valid-hvac-furnace-gas-room-ac.xml',
    'hvac_dse/valid-hvac-furnace-gas-room-ac-dse-1.0.xml' => 'hvac_dse/valid-hvac-furnace-gas-room-ac-dse-0.8.xml',
    'hvac_dse/valid-hvac-ground-to-air-heat-pump-dse-0.8.xml.skip' => 'valid-hvac-ground-to-air-heat-pump.xml',
    'hvac_dse/valid-hvac-ground-to-air-heat-pump-dse-1.0.xml.skip' => 'hvac_dse/valid-hvac-ground-to-air-heat-pump-dse-0.8.xml.skip',
    'hvac_dse/valid-hvac-mini-split-heat-pump-ducted-dse-0.8.xml' => 'valid-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_dse/valid-hvac-mini-split-heat-pump-ducted-dse-1.0.xml' => 'hvac_dse/valid-hvac-mini-split-heat-pump-ducted-dse-0.8.xml',
    'hvac_load_fracs/valid-hvac-air-to-air-heat-pump-1-speed-zero-cool.xml' => 'valid-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_load_fracs/valid-hvac-air-to-air-heat-pump-1-speed-zero-heat.xml' => 'valid-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_load_fracs/valid-hvac-air-to-air-heat-pump-1-speed-zero-heat-cool.xml' => 'valid-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_load_fracs/valid-hvac-air-to-air-heat-pump-2-speed-zero-cool.xml' => 'valid-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_load_fracs/valid-hvac-air-to-air-heat-pump-2-speed-zero-heat.xml' => 'valid-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_load_fracs/valid-hvac-air-to-air-heat-pump-2-speed-zero-heat-cool.xml' => 'valid-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_load_fracs/valid-hvac-air-to-air-heat-pump-var-speed-zero-cool.xml' => 'valid-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_load_fracs/valid-hvac-air-to-air-heat-pump-var-speed-zero-heat.xml' => 'valid-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_load_fracs/valid-hvac-air-to-air-heat-pump-var-speed-zero-heat-cool.xml' => 'valid-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_load_fracs/valid-hvac-boiler-elec-only-zero-heat.xml' => 'valid-hvac-boiler-elec-only.xml',
    'hvac_load_fracs/valid-hvac-boiler-gas-only-zero-heat.xml' => 'valid-hvac-boiler-gas-only.xml',
    'hvac_load_fracs/valid-hvac-central-ac-only-1-speed-zero-cool.xml' => 'valid-hvac-central-ac-only-1-speed.xml',
    'hvac_load_fracs/valid-hvac-central-ac-only-2-speed-zero-cool.xml' => 'valid-hvac-central-ac-only-2-speed.xml',
    'hvac_load_fracs/valid-hvac-central-ac-only-var-speed-zero-cool.xml' => 'valid-hvac-central-ac-only-var-speed.xml',
    'hvac_load_fracs/valid-hvac-elec-resistance-only-zero-heat.xml' => 'valid-hvac-elec-resistance-only.xml',
    'hvac_load_fracs/valid-hvac-furnace-elec-only-zero-heat.xml' => 'valid-hvac-furnace-elec-only.xml',
    'hvac_load_fracs/valid-hvac-furnace-gas-only-zero-heat.xml' => 'valid-hvac-furnace-gas-only.xml',
    'hvac_load_fracs/valid-hvac-ground-to-air-heat-pump-zero-cool.xml' => 'valid-hvac-ground-to-air-heat-pump.xml',
    'hvac_load_fracs/valid-hvac-ground-to-air-heat-pump-zero-heat.xml' => 'valid-hvac-ground-to-air-heat-pump.xml',
    'hvac_load_fracs/valid-hvac-ground-to-air-heat-pump-zero-heat-cool.xml' => 'valid-hvac-ground-to-air-heat-pump.xml',
    'hvac_load_fracs/valid-hvac-mini-split-heat-pump-ducted-zero-cool.xml' => 'valid-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_load_fracs/valid-hvac-mini-split-heat-pump-ducted-zero-heat.xml' => 'valid-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_load_fracs/valid-hvac-mini-split-heat-pump-ducted-zero-heat-cool.xml' => 'valid-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_load_fracs/valid-hvac-mini-split-heat-pump-ductless-zero-cool.xml' => 'valid-hvac-mini-split-heat-pump-ductless.xml',
    'hvac_load_fracs/valid-hvac-mini-split-heat-pump-ductless-zero-heat.xml' => 'valid-hvac-mini-split-heat-pump-ductless.xml',
    'hvac_load_fracs/valid-hvac-mini-split-heat-pump-ductless-zero-heat-cool.xml' => 'valid-hvac-mini-split-heat-pump-ductless.xml',
    'hvac_load_fracs/valid-hvac-room-ac-only-zero-cool.xml' => 'valid-hvac-room-ac-only.xml',
    'hvac_load_fracs/valid-hvac-stove-oil-only-zero-heat.xml' => 'valid-hvac-stove-oil-only.xml',
    'hvac_load_fracs/valid-hvac-wall-furnace-propane-only-zero-heat.xml' => 'valid-hvac-wall-furnace-propane-only.xml',
    'hvac_multiple/valid-hvac-air-to-air-heat-pump-1-speed-x3.xml.skip' => 'valid-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_multiple/valid-hvac-air-to-air-heat-pump-2-speed-x3.xml.skip' => 'valid-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_multiple/valid-hvac-air-to-air-heat-pump-var-speed-x3.xml.skip' => 'valid-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_multiple/valid-hvac-boiler-elec-only-x3.xml' => 'valid-hvac-boiler-elec-only.xml',
    'hvac_multiple/valid-hvac-boiler-gas-only-x3.xml' => 'valid-hvac-boiler-gas-only.xml',
    'hvac_multiple/valid-hvac-central-ac-only-1-speed-x3.xml' => 'valid-hvac-central-ac-only-1-speed.xml',
    'hvac_multiple/valid-hvac-central-ac-only-2-speed-x3.xml' => 'valid-hvac-central-ac-only-2-speed.xml',
    'hvac_multiple/valid-hvac-central-ac-only-var-speed-x3.xml' => 'valid-hvac-central-ac-only-var-speed.xml',
    'hvac_multiple/valid-hvac-elec-resistance-only-x3.xml' => 'valid-hvac-elec-resistance-only.xml',
    'hvac_multiple/valid-hvac-furnace-elec-only-x3.xml.skip' => 'valid-hvac-furnace-elec-only.xml',
    'hvac_multiple/valid-hvac-furnace-gas-only-x3.xml.skip' => 'valid-hvac-furnace-gas-only.xml',
    'hvac_multiple/valid-hvac-ground-to-air-heat-pump-x3.xml.skip' => 'valid-hvac-ground-to-air-heat-pump.xml',
    'hvac_multiple/valid-hvac-mini-split-heat-pump-ducted-x3.xml.skip' => 'valid-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_multiple/valid-hvac-mini-split-heat-pump-ductless-x3.xml.skip' => 'valid-hvac-mini-split-heat-pump-ductless.xml',
    'hvac_multiple/valid-hvac-room-ac-only-x3.xml' => 'valid-hvac-room-ac-only.xml',
    'hvac_multiple/valid-hvac-stove-oil-only-x3.xml.skip' => 'valid-hvac-stove-oil-only.xml',
    'hvac_multiple/valid-hvac-wall-furnace-propane-only-x3.xml.skip' => 'valid-hvac-wall-furnace-propane-only.xml',
    'hvac_partial/valid-50percent.xml.skip' => 'valid.xml',
    'hvac_partial/valid-hvac-air-to-air-heat-pump-1-speed-50percent.xml.skip' => 'valid-hvac-air-to-air-heat-pump-1-speed.xml',
    'hvac_partial/valid-hvac-air-to-air-heat-pump-2-speed-50percent.xml.skip' => 'valid-hvac-air-to-air-heat-pump-2-speed.xml',
    'hvac_partial/valid-hvac-air-to-air-heat-pump-var-speed-50percent.xml.skip' => 'valid-hvac-air-to-air-heat-pump-var-speed.xml',
    'hvac_partial/valid-hvac-boiler-elec-only-50percent.xml' => 'valid-hvac-boiler-elec-only.xml',
    'hvac_partial/valid-hvac-boiler-gas-only-50percent.xml' => 'valid-hvac-boiler-gas-only.xml',
    'hvac_partial/valid-hvac-central-ac-only-1-speed-50percent.xml.skip' => 'valid-hvac-central-ac-only-1-speed.xml',
    'hvac_partial/valid-hvac-central-ac-only-2-speed-50percent.xml.skip' => 'valid-hvac-central-ac-only-2-speed.xml',
    'hvac_partial/valid-hvac-central-ac-only-var-speed-50percent.xml.skip' => 'valid-hvac-central-ac-only-var-speed.xml',
    'hvac_partial/valid-hvac-elec-resistance-only-50percent.xml' => 'valid-hvac-elec-resistance-only.xml',
    'hvac_partial/valid-hvac-furnace-elec-only-50percent.xml.skip' => 'valid-hvac-furnace-elec-only.xml',
    'hvac_partial/valid-hvac-furnace-gas-central-ac-2-speed-50percent.xml.skip' => 'valid-hvac-furnace-gas-central-ac-2-speed.xml',
    'hvac_partial/valid-hvac-furnace-gas-central-ac-var-speed-50percent.xml.skip' => 'valid-hvac-furnace-gas-central-ac-var-speed.xml',
    'hvac_partial/valid-hvac-furnace-gas-only-50percent.xml.skip' => 'valid-hvac-furnace-gas-only.xml',
    'hvac_partial/valid-hvac-furnace-gas-room-ac-50percent.xml.skip' => 'valid-hvac-furnace-gas-room-ac.xml',
    'hvac_partial/valid-hvac-ground-to-air-heat-pump-50percent.xml.skip' => 'valid-hvac-ground-to-air-heat-pump.xml',
    'hvac_partial/valid-hvac-mini-split-heat-pump-ducted-50percent.xml.skip' => 'valid-hvac-mini-split-heat-pump-ducted.xml',
    'hvac_partial/valid-hvac-mini-split-heat-pump-ductless-50percent.xml.skip' => 'valid-hvac-mini-split-heat-pump-ductless.xml',
    'hvac_partial/valid-hvac-room-ac-only-50percent.xml' => 'valid-hvac-room-ac-only.xml',
    'hvac_partial/valid-hvac-stove-oil-only-50percent.xml' => 'valid-hvac-stove-oil-only.xml',
    'hvac_partial/valid-hvac-wall-furnace-propane-only-50percent.xml' => 'valid-hvac-wall-furnace-propane-only.xml',
    'water_heating_multiple/valid-dhw-tankless-electric-x3.xml' => 'valid-dhw-tankless-electric.xml',
    'water_heating_multiple/valid-dhw-tankless-gas-x3.xml' => 'valid-dhw-tankless-gas.xml',
    'water_heating_multiple/valid-dhw-tankless-oil-x3.xml' => 'valid-dhw-tankless-oil.xml',
    'water_heating_multiple/valid-dhw-tankless-propane-x3.xml' => 'valid-dhw-tankless-propane.xml'
  }

  hpxmls_files.each do |derivative, parent|
    puts "Generating #{derivative}..."

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
        HPXML.add_frame_floor(foundation: foundation, **foundation_framefloor_values)
      end
      foundations_walls_values[i].each do |foundation_wall_values|
        HPXML.add_foundation_wall(foundation: foundation, **foundation_wall_values)
      end
      foundations_slabs_values[i].each do |foundation_slab_values|
        HPXML.add_slab(foundation: foundation, **foundation_slab_values)
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

    hpxml_path = File.join(tests_dir, derivative)

    # Validate file against HPXML schema
    schemas_dir = File.absolute_path(File.join(File.dirname(__FILE__), "hpxml_schemas"))
    errors = XMLHelper.validate(hpxml_doc.to_s, File.join(schemas_dir, "HPXML.xsd"), nil)
    if errors.size > 0
      fail errors.to_s
    end

    XMLHelper.write_file(hpxml_doc, hpxml_path)
  end

  puts "Generated #{hpxmls_files.length} files."
end

def get_hpxml_file_hpxml_values(hpxml_file, hpxml_values)
  if hpxml_file == 'valid.xml'
    hpxml_values = { :xml_type => "HPXML",
                     :xml_generated_by => "Rakefile",
                     :transaction => "create",
                     :software_program_used => nil,
                     :software_program_version => nil,
                     :eri_calculation_version => "2014AEG",
                     :building_id => "MyBuilding",
                     :event_type => "proposed workscope" }
  elsif hpxml_file == 'valid-addenda-exclude-g.xml'
    hpxml_values[:eri_calculation_version] = "2014AE"
  elsif hpxml_file == 'valid-addenda-exclude-g-e.xml'
    hpxml_values[:eri_calculation_version] = "2014A"
  elsif hpxml_file == 'valid-addenda-exclude-g-e-a.xml'
    hpxml_values[:eri_calculation_version] = "2014"
  end
  return hpxml_values
end

def get_hpxml_file_site_values(hpxml_file, site_values)
  if hpxml_file == 'valid.xml'
    site_values = { :fuels => ["electricity", "natural gas"] }
  elsif hpxml_file == 'valid-hvac-none-no-fuel-access.xml'
    site_values[:fuels] = ["electricity"]
  elsif hpxml_file == 'valid-enclosure-no-natural-ventilation.xml'
    site_values[:disable_natural_ventilation] = true
  end
  return site_values
end

def get_hpxml_file_building_occupancy_values(hpxml_file, building_occupancy_values)
  if hpxml_file == 'valid-misc-number-of-occupants.xml'
    building_occupancy_values = { :number_of_residents => 5 }
  end
  return building_occupancy_values
end

def get_hpxml_file_building_construction_values(hpxml_file, building_construction_values)
  if hpxml_file == 'valid.xml'
    building_construction_values = { :number_of_conditioned_floors => 3,
                                     :number_of_conditioned_floors_above_grade => 2,
                                     :number_of_bedrooms => 4,
                                     :conditioned_floor_area => 7000,
                                     :conditioned_building_volume => 67575,
                                     :garage_present => false }
  elsif ['valid-foundation-pier-beam.xml',
         'valid-foundation-slab.xml',
         'valid-foundation-unconditioned-basement.xml',
         'valid-foundation-unvented-crawlspace.xml',
         'valid-foundation-vented-crawlspace.xml'].include? hpxml_file
    building_construction_values[:number_of_conditioned_floors] = 2
    building_construction_values[:conditioned_floor_area] = 3500
    building_construction_values[:conditioned_building_volume] = 33787.5
  elsif hpxml_file == 'invalid_files/invalid-missing-elements.xml'
    building_construction_values[:number_of_conditioned_floors] = nil
    building_construction_values[:conditioned_floor_area] = nil
  elsif ['valid-hvac-multiple.xml',
         'hvac_multiple/valid-hvac-air-to-air-heat-pump-1-speed-x3.xml.skip',
         'hvac_multiple/valid-hvac-air-to-air-heat-pump-2-speed-x3.xml.skip',
         'hvac_multiple/valid-hvac-air-to-air-heat-pump-var-speed-x3.xml.skip',
         'hvac_multiple/valid-hvac-boiler-elec-only-x3.xml',
         'hvac_multiple/valid-hvac-boiler-gas-only-x3.xml',
         'hvac_multiple/valid-hvac-central-ac-only-1-speed-x3.xml',
         'hvac_multiple/valid-hvac-central-ac-only-2-speed-x3.xml',
         'hvac_multiple/valid-hvac-central-ac-only-var-speed-x3.xml',
         'hvac_multiple/valid-hvac-elec-resistance-only-x3.xml',
         'hvac_multiple/valid-hvac-furnace-elec-only-x3.xml.skip',
         'hvac_multiple/valid-hvac-furnace-gas-only-x3.xml.skip',
         'hvac_multiple/valid-hvac-ground-to-air-heat-pump-x3.xml.skip',
         'hvac_multiple/valid-hvac-mini-split-heat-pump-ducted-x3.xml.skip',
         'hvac_multiple/valid-hvac-mini-split-heat-pump-ductless-x3.xml.skip',
         'hvac_multiple/valid-hvac-room-ac-only-x3.xml',
         'hvac_multiple/valid-hvac-stove-oil-only-x3.xml.skip',
         'hvac_multiple/valid-hvac-wall-furnace-propane-only-x3.xml.skip',
         'hvac_partial/valid-50percent.xml.skip',
         'hvac_partial/valid-hvac-air-to-air-heat-pump-1-speed-50percent.xml.skip',
         'hvac_partial/valid-hvac-air-to-air-heat-pump-2-speed-50percent.xml.skip',
         'hvac_partial/valid-hvac-air-to-air-heat-pump-var-speed-50percent.xml.skip',
         'hvac_partial/valid-hvac-boiler-elec-only-50percent.xml',
         'hvac_partial/valid-hvac-boiler-gas-only-50percent.xml',
         'hvac_partial/valid-hvac-central-ac-only-1-speed-50percent.xml.skip',
         'hvac_partial/valid-hvac-central-ac-only-2-speed-50percent.xml.skip',
         'hvac_partial/valid-hvac-central-ac-only-var-speed-50percent.xml.skip',
         'hvac_partial/valid-hvac-elec-resistance-only-50percent.xml',
         'hvac_partial/valid-hvac-furnace-elec-only-50percent.xml.skip',
         'hvac_partial/valid-hvac-furnace-gas-central-ac-2-speed-50percent.xml.skip',
         'hvac_partial/valid-hvac-furnace-gas-central-ac-var-speed-50percent.xml.skip',
         'hvac_partial/valid-hvac-furnace-gas-only-50percent.xml.skip',
         'hvac_partial/valid-hvac-furnace-gas-room-ac-50percent.xml.skip',
         'hvac_partial/valid-hvac-ground-to-air-heat-pump-50percent.xml.skip',
         'hvac_partial/valid-hvac-mini-split-heat-pump-ducted-50percent.xml.skip',
         'hvac_partial/valid-hvac-mini-split-heat-pump-ductless-50percent.xml.skip',
         'hvac_partial/valid-hvac-room-ac-only-50percent.xml',
         'hvac_partial/valid-hvac-stove-oil-only-50percent.xml',
         'hvac_partial/valid-hvac-wall-furnace-propane-only-50percent.xml'].include? hpxml_file
    building_construction_values[:load_distribution_scheme] = "UniformLoad" # TODO: Temporary
  elsif hpxml_file == 'valid-hvac-ideal-air.xml'
    building_construction_values[:use_only_ideal_air_system] = true
  elsif hpxml_file == 'valid-atticroof-conditioned.xml'
    building_construction_values[:number_of_conditioned_floors] = 4
    building_construction_values[:number_of_conditioned_floors_above_grade] = 3
    building_construction_values[:conditioned_floor_area] = 9380
    building_construction_values[:conditioned_building_volume] = 85792.5
  elsif hpxml_file == 'valid-atticroof-cathedral.xml'
    building_construction_values[:conditioned_building_volume] = 89450
  end
  return building_construction_values
end

def get_hpxml_file_climate_and_risk_zones_values(hpxml_file, climate_and_risk_zones_values)
  if hpxml_file == 'valid.xml'
    climate_and_risk_zones_values = { :iecc2006 => 7,
                                      :iecc2012 => 7,
                                      :weather_station_id => "WeatherStation",
                                      :weather_station_name => "Denver, CO",
                                      :weather_station_wmo => "725650" }
  elsif hpxml_file == 'invalid_files/invalid-bad-wmo.xml'
    climate_and_risk_zones_values[:weather_station_wmo] = "999999"
  end
  return climate_and_risk_zones_values
end

def get_hpxml_file_air_infiltration_measurement_values(hpxml_file, air_infiltration_measurement_values, building_construction_values)
  if hpxml_file == 'valid.xml'
    air_infiltration_measurement_values = { :id => "InfiltrationMeasurement",
                                            :house_pressure => 50,
                                            :unit_of_measure => "ACH",
                                            :air_leakage => 3.0 }
  elsif hpxml_file == 'valid-infiltration-ach-natural.xml'
    air_infiltration_measurement_values = { :id => "InfiltrationMeasurement",
                                            :constant_ach_natural => 0.67 }
  end
  air_infiltration_measurement_values[:infiltration_volume] = building_construction_values[:conditioned_building_volume]
  return air_infiltration_measurement_values
end

def get_hpxml_file_attics_values(hpxml_file, attics_values)
  if hpxml_file == 'valid.xml'
    attics_values = [{ :id => "Attic",
                       :attic_type => "UnventedAttic" }]
  elsif hpxml_file == 'valid-atticroof-vented.xml'
    attics_values[0][:attic_type] = "VentedAttic"
    attics_values[0][:specific_leakage_area] = 0.003
  elsif hpxml_file == 'valid-atticroof-flat.xml'
    attics_values[0][:attic_type] = "FlatRoof"
  elsif hpxml_file == 'valid-atticroof-conditioned.xml'
    attics_values[0][:attic_type] = "ConditionedAttic"
    attics_values << { :id => "AtticBehindKneewallNorth",
                       :attic_type => "UnventedAttic" }
    attics_values << { :id => "AtticBehindKneewallSouth",
                       :attic_type => "UnventedAttic" }
    attics_values << { :id => "AtticUnderRoofRidge",
                       :attic_type => "UnventedAttic" }
  elsif hpxml_file == 'valid-atticroof-cathedral.xml'
    attics_values[0][:attic_type] = "CathedralCeiling"
  end
  return attics_values
end

def get_hpxml_file_attics_roofs_values(hpxml_file, attics_roofs_values)
  if hpxml_file == 'valid.xml'
    attics_roofs_values = [[{ :id => "AtticRoofNorth",
                              :area => 1950,
                              :azimuth => 0,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :pitch => 6,
                              :radiant_barrier => false,
                              :insulation_id => "AtticRoofNorthIns",
                              :insulation_assembly_r_value => 2.3 },
                            { :id => "AtticRoofSouth",
                              :area => 1950,
                              :azimuth => 180,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :pitch => 6,
                              :radiant_barrier => false,
                              :insulation_id => "AtticRoofSouthIns",
                              :insulation_assembly_r_value => 2.3 }]]
  elsif hpxml_file == 'valid-atticroof-flat.xml'
    attics_roofs_values = [[{ :id => "AtticRoof",
                              :area => 3500,
                              :azimuth => 0,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :pitch => 0,
                              :radiant_barrier => false,
                              :insulation_id => "AtticRoofIns",
                              :insulation_assembly_r_value => 25.8 }]]
  elsif hpxml_file == 'valid-atticroof-conditioned.xml'
    attics_roofs_values = [[{ :id => "AtticRoofA",
                              :area => 885,
                              :azimuth => 0,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :pitch => 6,
                              :radiant_barrier => false,
                              :insulation_id => "AtticRoofAIns",
                              :insulation_assembly_r_value => 25.8 },
                            { :id => "AtticRoofB",
                              :area => 885,
                              :azimuth => 180,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :pitch => 6,
                              :radiant_barrier => false,
                              :insulation_id => "AtticRoofBIns",
                              :insulation_assembly_r_value => 25.8 }]]
    attics_roofs_values << [{ :id => "AtticRoofK",
                              :area => 625,
                              :azimuth => 0,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :pitch => 6,
                              :radiant_barrier => false,
                              :insulation_id => "AtticRoofKIns",
                              :insulation_assembly_r_value => 2.3 }]
    attics_roofs_values << [{ :id => "AtticRoofL",
                              :area => 625,
                              :azimuth => 180,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :pitch => 6,
                              :radiant_barrier => false,
                              :insulation_id => "AtticRoofLIns",
                              :insulation_assembly_r_value => 2.3 }]
    attics_roofs_values << [{ :id => "AtticRoofN",
                              :area => 445,
                              :azimuth => 0,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :pitch => 6,
                              :radiant_barrier => false,
                              :insulation_id => "AtticRoofNIns",
                              :insulation_assembly_r_value => 2.3 },
                            { :id => "AtticRoofO",
                              :area => 445,
                              :azimuth => 180,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :pitch => 6,
                              :radiant_barrier => false,
                              :insulation_id => "AtticRoofOIns",
                              :insulation_assembly_r_value => 2.3 }]
  elsif hpxml_file == 'valid-atticroof-cathedral.xml'
    attics_roofs_values[0][0][:insulation_assembly_r_value] = 25.8
    attics_roofs_values[0][1][:insulation_assembly_r_value] = 25.8
  end
  return attics_roofs_values
end

def get_hpxml_file_attics_floors_values(hpxml_file, attics_floors_values)
  if hpxml_file == 'valid.xml'
    attics_floors_values = [[{ :id => "AtticFloor",
                               :adjacent_to => "living space",
                               :area => 3500,
                               :insulation_id => "AtticFloorIns",
                               :insulation_assembly_r_value => 39.3 }]]
  elsif hpxml_file == 'valid-atticroof-flat.xml'
    attics_floors_values[0].delete_at(0)
  elsif hpxml_file == 'valid-atticroof-conditioned.xml'
    attics_floors_values = [[{ :id => "AtticFloorF",
                               :adjacent_to => "living space",
                               :area => 2380,
                               :insulation_id => "AtticFloorFIns",
                               :insulation_assembly_r_value => 2.1 }]]
    attics_floors_values << [{ :id => "AtticFloorG",
                               :adjacent_to => "living space",
                               :area => 560,
                               :insulation_id => "AtticFloorGIns",
                               :insulation_assembly_r_value => 39.3 }]
    attics_floors_values << [{ :id => "AtticFloorH",
                               :adjacent_to => "living space",
                               :area => 560,
                               :insulation_id => "AtticFloorHIns",
                               :insulation_assembly_r_value => 39.3 }]
    attics_floors_values << [{ :id => "AtticFloorM",
                               :adjacent_to => "living space",
                               :area => 630,
                               :insulation_id => "AtticFloorMIns",
                               :insulation_assembly_r_value => 39.3 }]
  elsif hpxml_file == 'valid-atticroof-cathedral.xml'
    attics_floors_values[0].delete_at(0)
  end
  return attics_floors_values
end

def get_hpxml_file_attics_walls_values(hpxml_file, attics_walls_values)
  if hpxml_file == 'valid.xml'
    attics_walls_values = [[{ :id => "AtticWallEast",
                              :adjacent_to => "outside",
                              :wall_type => "WoodStud",
                              :area => 312.5,
                              :azimuth => 90,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_id => "AtticWallEastIns",
                              :insulation_assembly_r_value => 4.0 },
                            { :id => "AtticWallWest",
                              :adjacent_to => "outside",
                              :wall_type => "WoodStud",
                              :area => 312.5,
                              :azimuth => 270,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_id => "AtticWallWestIns",
                              :insulation_assembly_r_value => 4.0 }]]
  elsif hpxml_file == 'valid-enclosure-multiple-walls.xml'
    attics_walls_values[0][0][:area] = 2
    attics_walls_values[0] << { :id => "AtticWallEastMedium",
                                :adjacent_to => "outside",
                                :wall_type => "WoodStud",
                                :area => 8,
                                :solar_absorptance => 0.75,
                                :emittance => 0.9,
                                :insulation_id => "AtticWallEastMediumIns",
                                :insulation_assembly_r_value => 4.0 }
    attics_walls_values[0] << { :id => "AtticWallEastLarge",
                                :adjacent_to => "outside",
                                :wall_type => "WoodStud",
                                :area => 302.5,
                                :solar_absorptance => 0.75,
                                :emittance => 0.9,
                                :insulation_id => "AtticWallEastLargeIns",
                                :insulation_assembly_r_value => 4.0 }
  elsif hpxml_file == 'valid-atticroof-flat.xml'
    attics_walls_values[0].delete_at(0)
  elsif hpxml_file == 'valid-atticroof-conditioned.xml'
    attics_walls_values = [[{ :id => "AtticWallC",
                              :adjacent_to => "outside",
                              :wall_type => "WoodStud",
                              :area => 260.25,
                              :azimuth => 90,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_id => "AtticWallCIns",
                              :insulation_assembly_r_value => 23.0 },
                            { :id => "AtticWallCOpposite",
                              :adjacent_to => "outside",
                              :wall_type => "WoodStud",
                              :area => 260.25,
                              :azimuth => 270,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_id => "AtticWallCOppositeIns",
                              :insulation_assembly_r_value => 23.0 },
                            { :id => "AtticWallD",
                              :adjacent_to => "attic - unvented",
                              :wall_type => "WoodStud",
                              :area => 280,
                              :azimuth => 0,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_id => "AtticWallDIns",
                              :insulation_assembly_r_value => 23.0 },
                            { :id => "AtticWallE",
                              :adjacent_to => "attic - unvented",
                              :wall_type => "WoodStud",
                              :area => 280,
                              :azimuth => 180,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_id => "AtticWallEIns",
                              :insulation_assembly_r_value => 23.0 }]]
    attics_walls_values << [{ :id => "AtticWallI",
                              :adjacent_to => "attic - unvented",
                              :wall_type => "WoodStud",
                              :area => 16,
                              :azimuth => 90,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_id => "AtticWallIIns",
                              :insulation_assembly_r_value => 4.0 },
                            { :id => "AtticWallIOpposite",
                              :adjacent_to => "attic - unvented",
                              :wall_type => "WoodStud",
                              :area => 16,
                              :azimuth => 270,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_id => "AtticWallIOppositeIns",
                              :insulation_assembly_r_value => 4.0 }]
    attics_walls_values << [{ :id => "AtticWallJ",
                              :adjacent_to => "attic - unvented",
                              :wall_type => "WoodStud",
                              :area => 16,
                              :azimuth => 90,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_id => "AtticWallJIns",
                              :insulation_assembly_r_value => 4.0 },
                            { :id => "AtticWallJOpposite",
                              :adjacent_to => "attic - unvented",
                              :wall_type => "WoodStud",
                              :area => 16,
                              :azimuth => 270,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_id => "AtticWallJOppositeIns",
                              :insulation_assembly_r_value => 4.0 }]
    attics_walls_values << [{ :id => "AtticWallP",
                              :adjacent_to => "attic - unvented",
                              :wall_type => "WoodStud",
                              :area => 20,
                              :azimuth => 90,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_id => "AtticWallPIns",
                              :insulation_assembly_r_value => 4.0 },
                            { :id => "AtticWallPOpposite",
                              :adjacent_to => "attic - unvented",
                              :wall_type => "WoodStud",
                              :area => 20,
                              :azimuth => 270,
                              :solar_absorptance => 0.75,
                              :emittance => 0.9,
                              :insulation_id => "AtticWallPOppositeIns",
                              :insulation_assembly_r_value => 4.0 }]
  elsif hpxml_file == 'valid-atticroof-cathedral.xml'
    attics_walls_values[0][0][:insulation_assembly_r_value] = 23.0
    attics_walls_values[0][1][:insulation_assembly_r_value] = 23.0
  end
  return attics_walls_values
end

def get_hpxml_file_foundations_values(hpxml_file, foundations_values)
  if hpxml_file == 'valid.xml'
    foundations_values = [{ :id => "Foundation",
                            :foundation_type => "ConditionedBasement" }]
  elsif ['valid-foundation-pier-beam.xml'].include? hpxml_file
    foundations_values[0][:foundation_type] = "Ambient"
  elsif ['valid-foundation-slab.xml'].include? hpxml_file
    foundations_values[0][:foundation_type] = "SlabOnGrade"
  elsif ['valid-foundation-unconditioned-basement.xml'].include? hpxml_file
    foundations_values[0][:foundation_type] = "UnconditionedBasement"
  elsif ['valid-foundation-unvented-crawlspace.xml'].include? hpxml_file
    foundations_values[0][:foundation_type] = "UnventedCrawlspace"
  elsif ['valid-foundation-vented-crawlspace.xml'].include? hpxml_file
    foundations_values[0][:foundation_type] = "VentedCrawlspace"
    foundations_values[0][:specific_leakage_area] = 0.00667
  end
  return foundations_values
end

def get_hpxml_file_foundations_walls_values(hpxml_file, foundations_walls_values)
  if hpxml_file == 'valid.xml'
    foundations_walls_values = [[{ :id => "FoundationWall",
                                   :height => 9,
                                   :area => 2160,
                                   :thickness => 8,
                                   :depth_below_grade => 7,
                                   :adjacent_to => "ground",
                                   :insulation_id => "FoundationWallIns",
                                   :insulation_assembly_r_value => 10.69 }]]
  elsif ['valid-foundation-unvented-crawlspace.xml',
         'valid-foundation-vented-crawlspace.xml'].include? hpxml_file
    foundations_walls_values[0][0][:height] = 4
    foundations_walls_values[0][0][:area] = 960
    foundations_walls_values[0][0][:depth_below_grade] = 3
  elsif ['valid-foundation-unconditioned-basement-reference.xml',
         'valid-foundation-conditioned-basement-reference.xml',
         'valid-foundation-unvented-crawlspace-reference.xml',
         'valid-foundation-vented-crawlspace-reference.xml'].include? hpxml_file
    foundations_walls_values[0][0][:insulation_assembly_r_value] = nil
  elsif ['valid-foundation-pier-beam.xml',
         'valid-foundation-slab.xml'].include? hpxml_file
    foundations_walls_values = [[]]
  end
  return foundations_walls_values
end

def get_hpxml_file_foundations_slabs_values(hpxml_file, foundations_slabs_values)
  if hpxml_file == 'valid.xml'
    foundations_slabs_values = [[{ :id => "FoundationSlab",
                                   :area => 3500,
                                   :thickness => 4,
                                   :exposed_perimeter => 240,
                                   :perimeter_insulation_depth => 0,
                                   :under_slab_insulation_width => 0,
                                   :depth_below_grade => 7,
                                   :perimeter_insulation_id => "FoundationSlabPerimeterIns",
                                   :perimeter_insulation_r_value => 0,
                                   :under_slab_insulation_id => "FoundationSlabUnderIns",
                                   :under_slab_insulation_r_value => 0,
                                   :carpet_fraction => 0,
                                   :carpet_r_value => 0 }]]
  elsif hpxml_file == 'valid-foundation-slab.xml'
    foundations_slabs_values[0][0][:under_slab_insulation_width] = 2
    foundations_slabs_values[0][0][:depth_below_grade] = 0
    foundations_slabs_values[0][0][:under_slab_insulation_r_value] = 5
    foundations_slabs_values[0][0][:carpet_fraction] = 1
    foundations_slabs_values[0][0][:carpet_r_value] = 2.5
  elsif ['valid-foundation-unvented-crawlspace.xml',
         'valid-foundation-vented-crawlspace.xml'].include? hpxml_file
    foundations_slabs_values[0][0][:thickness] = 0
    foundations_slabs_values[0][0][:depth_below_grade] = 3
    foundations_slabs_values[0][0][:carpet_r_value] = 2.5
  elsif ['valid-foundation-conditioned-basement-reference.xml',
         'valid-foundation-slab-reference.xml',
         'valid-foundation-unconditioned-basement-reference.xml',
         'valid-foundation-unvented-crawlspace-reference.xml',
         'valid-foundation-vented-crawlspace-reference.xml'].include? hpxml_file
    foundations_slabs_values[0][0][:perimeter_insulation_depth] = nil
    foundations_slabs_values[0][0][:under_slab_insulation_width] = nil
    foundations_slabs_values[0][0][:perimeter_insulation_r_value] = nil
    foundations_slabs_values[0][0][:under_slab_insulation_r_value] = nil
  elsif ['valid-foundation-pier-beam.xml'].include? hpxml_file
    foundations_slabs_values = [[]]
  end
  return foundations_slabs_values
end

def get_hpxml_file_foundations_framefloors_values(hpxml_file, foundations_framefloors_values)
  if hpxml_file == 'valid.xml'
    foundations_framefloors_values = [[]]
  elsif ['valid-foundation-pier-beam.xml',
         'valid-foundation-unconditioned-basement.xml',
         'valid-foundation-unvented-crawlspace.xml',
         'valid-foundation-vented-crawlspace.xml'].include? hpxml_file
    foundations_framefloors_values = [[{ :id => "FoundationFrameFloor",
                                         :adjacent_to => "living space",
                                         :area => 3500,
                                         :insulation_id => "FoundationFrameFloorIns",
                                         :insulation_assembly_r_value => 18.7 }]]
  elsif ['valid-foundation-pier-beam-reference.xml',
         'valid-foundation-unconditioned-basement-reference.xml',
         'valid-foundation-unvented-crawlspace-reference.xml',
         'valid-foundation-vented-crawlspace-reference.xml'].include? hpxml_file
    foundations_framefloors_values[0][0][:insulation_assembly_r_value] = nil
  end
  return foundations_framefloors_values
end

def get_hpxml_file_rim_joists_values(hpxml_file, rim_joists_values)
  if hpxml_file == 'valid.xml'
    rim_joists_values = [{ :id => "RimJoist",
                           :exterior_adjacent_to => "outside",
                           :interior_adjacent_to => "living space",
                           :area => 180,
                           :solar_absorptance => 0.75,
                           :emittance => 0.9,
                           :insulation_id => "RimJoistIns",
                           :insulation_assembly_r_value => 23.0 },
                         { :id => "RimJoist2",
                           :exterior_adjacent_to => "outside",
                           :interior_adjacent_to => "living space",
                           :area => 180,
                           :solar_absorptance => 0.75,
                           :emittance => 0.9,
                           :insulation_id => "RimJoist2Ins",
                           :insulation_assembly_r_value => 10.69 }]
  elsif ['valid-foundation-pier-beam.xml',
         'valid-foundation-slab.xml'].include? hpxml_file
    rim_joists_values.delete_at(1)
  elsif ['valid-foundation-unconditioned-basement.xml'].include? hpxml_file
    rim_joists_values[1][:interior_adjacent_to] = "basement - unconditioned"
  elsif ['valid-foundation-unvented-crawlspace.xml'].include? hpxml_file
    rim_joists_values[1][:interior_adjacent_to] = "crawlspace - unvented"
  elsif ['valid-foundation-vented-crawlspace.xml'].include? hpxml_file
    rim_joists_values[1][:interior_adjacent_to] = "crawlspace - vented"
  end
  return rim_joists_values
end

def get_hpxml_file_walls_values(hpxml_file, walls_values)
  if hpxml_file == 'valid.xml'
    walls_values = [{ :id => "Wall",
                      :exterior_adjacent_to => "outside",
                      :interior_adjacent_to => "living space",
                      :wall_type => "WoodStud",
                      :area => 3796,
                      :solar_absorptance => 0.75,
                      :emittance => 0.9,
                      :insulation_id => "WallIns",
                      :insulation_assembly_r_value => 23 }]
  elsif hpxml_file == 'valid-enclosure-multiple-walls.xml'
    walls_values[0][:id] = "agwall-small"
    walls_values[0][:area] = 10
    walls_values << { :id => "WallMedium",
                      :exterior_adjacent_to => "outside",
                      :interior_adjacent_to => "living space",
                      :wall_type => "WoodStud",
                      :area => 300,
                      :solar_absorptance => 0.75,
                      :emittance => 0.9,
                      :insulation_id => "WallMediumIns",
                      :insulation_assembly_r_value => 23 }
    walls_values << { :id => "WallLarge",
                      :exterior_adjacent_to => "outside",
                      :interior_adjacent_to => "living space",
                      :wall_type => "WoodStud",
                      :area => 3486,
                      :solar_absorptance => 0.75,
                      :emittance => 0.9,
                      :insulation_id => "WallLargeIns",
                      :insulation_assembly_r_value => 23 }
  elsif hpxml_file == 'valid-enclosure-walltype-cmu.xml'
    walls_values[0][:wall_type] = "ConcreteMasonryUnit"
    walls_values[0][:insulation_assembly_r_value] = 12
  elsif hpxml_file == 'valid-enclosure-walltype-doublestud.xml'
    walls_values[0][:wall_type] = "DoubleWoodStud"
    walls_values[0][:insulation_assembly_r_value] = 28.7
  elsif hpxml_file == 'valid-enclosure-walltype-icf.xml'
    walls_values[0][:wall_type] = "InsulatedConcreteForms"
    walls_values[0][:insulation_assembly_r_value] = 21
  elsif hpxml_file == 'valid-enclosure-walltype-log.xml'
    walls_values[0][:wall_type] = "LogWall"
    walls_values[0][:insulation_assembly_r_value] = 7.1
  elsif hpxml_file == 'valid-enclosure-walltype-sip.xml'
    walls_values[0][:wall_type] = "StructurallyInsulatedPanel"
    walls_values[0][:insulation_assembly_r_value] = 16.1
  elsif hpxml_file == 'valid-enclosure-walltype-solidconcrete.xml'
    walls_values[0][:wall_type] = "SolidConcrete"
    walls_values[0][:insulation_assembly_r_value] = 1.35
  elsif hpxml_file == 'valid-enclosure-walltype-steelstud.xml'
    walls_values[0][:wall_type] = "SteelFrame"
    walls_values[0][:insulation_assembly_r_value] = 8.1
  elsif hpxml_file == 'valid-enclosure-walltype-stone.xml'
    walls_values[0][:wall_type] = "Stone"
    walls_values[0][:insulation_assembly_r_value] = 5.4
  elsif hpxml_file == 'valid-enclosure-walltype-strawbale.xml'
    walls_values[0][:wall_type] = "StrawBale"
    walls_values[0][:insulation_assembly_r_value] = 58.8
  elsif hpxml_file == 'valid-enclosure-walltype-structuralbrick.xml'
    walls_values[0][:wall_type] = "StructuralBrick"
    walls_values[0][:insulation_assembly_r_value] = 7.9
  elsif hpxml_file == 'valid-enclosure-walltype-woodstud-reference.xml'
    walls_values[0][:insulation_assembly_r_value] = nil
  elsif hpxml_file == 'invalid_files/invalid-missing-surfaces.xml'
    walls_values[0][:area] = 3696
    walls_values << { :id => "Wall2",
                      :exterior_adjacent_to => "living space",
                      :interior_adjacent_to => "garage",
                      :wall_type => "WoodStud",
                      :area => 100,
                      :solar_absorptance => 0.75,
                      :emittance => 0.9,
                      :insulation_id => "Wall2Ins",
                      :insulation_assembly_r_value => 4 }
  end
  return walls_values
end

def get_hpxml_file_windows_values(hpxml_file, windows_values)
  if hpxml_file == 'valid.xml'
    windows_values = [{ :id => "WindowSouth",
                        :area => 240,
                        :azimuth => 180,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "Wall" },
                      { :id => "WindowNorth",
                        :area => 120,
                        :azimuth => 0,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "Wall" },
                      { :id => "WallEast",
                        :area => 120,
                        :azimuth => 90,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "Wall" },
                      { :id => "WallWest",
                        :area => 120,
                        :azimuth => 270,
                        :ufactor => 0.33,
                        :shgc => 0.45,
                        :wall_idref => "Wall" }]
  elsif hpxml_file == 'valid-enclosure-multiple-walls.xml'
    windows_values[0][:wall_idref] = "WallMedium"
    windows_values[1][:wall_idref] = "WallLarge"
    windows_values[2][:wall_idref] = "WallLarge"
    windows_values[3][:wall_idref] = "WallLarge"
  elsif hpxml_file == 'valid-enclosure-orientation-45.xml'
    windows_values[0][:azimuth] = 225
    windows_values[1][:azimuth] = 45
    windows_values[2][:azimuth] = 135
    windows_values[3][:azimuth] = 315
  elsif hpxml_file == 'valid-enclosure-overhangs.xml'
    windows_values[0][:overhangs_depth] = 2.5
    windows_values[0][:overhangs_distance_to_top_of_window] = 0
    windows_values[0][:overhangs_distance_to_bottom_of_window] = 4
    windows_values[2][:overhangs_depth] = 1.5
    windows_values[2][:overhangs_distance_to_top_of_window] = 2
    windows_values[2][:overhangs_distance_to_bottom_of_window] = 6
    windows_values[3][:overhangs_depth] = 1.5
    windows_values[3][:overhangs_distance_to_top_of_window] = 2
    windows_values[3][:overhangs_distance_to_bottom_of_window] = 7
  elsif hpxml_file == 'valid-enclosure-windows-interior-shading.xml'
    windows_values[0][:interior_shading_factor_summer] = 0.7
    windows_values[0][:interior_shading_factor_winter] = 0.85
    windows_values[1][:interior_shading_factor_summer] = 0.01
    windows_values[1][:interior_shading_factor_winter] = 0.99
    windows_values[2][:interior_shading_factor_summer] = 0.99
    windows_values[2][:interior_shading_factor_winter] = 0.01
    windows_values[3][:interior_shading_factor_summer] = 0.85
    windows_values[3][:interior_shading_factor_winter] = 0.7
  elsif hpxml_file == 'invalid_files/invalid-net-area-negative-wall.xml'
    windows_values[0][:area] = 3500
  elsif hpxml_file == 'invalid_files/invalid-unattached-window.xml'
    windows_values[0][:wall_idref] = "foobar"
  end
  return windows_values
end

def get_hpxml_file_skylights_values(hpxml_file, skylights_values)
  if hpxml_file == 'valid-enclosure-skylights.xml'
    skylights_values << { :id => "SkylightNorth",
                          :area => 15,
                          :azimuth => 0,
                          :ufactor => 0.33,
                          :shgc => 0.45,
                          :roof_idref => "AtticRoofNorth" }
    skylights_values << { :id => "SkylightSouth",
                          :area => 15,
                          :azimuth => 180,
                          :ufactor => 0.35,
                          :shgc => 0.47,
                          :roof_idref => "AtticRoofSouth" }
  elsif hpxml_file == 'invalid_files/invalid-net-area-negative-roof.xml'
    skylights_values[0][:area] = 4199
  elsif hpxml_file == 'invalid_files/invalid-unattached-skylight.xml'
    skylights_values[0][:roof_idref] = "foobar"
  end
  return skylights_values
end

def get_hpxml_file_doors_values(hpxml_file, doors_values)
  if hpxml_file == 'valid.xml'
    doors_values = [{ :id => "Door",
                      :wall_idref => "Wall",
                      :area => 80,
                      :azimuth => 270,
                      :r_value => 4.4 }]
  elsif hpxml_file == 'valid-enclosure-doors-reference.xml'
    doors_values[0][:area] = nil
    doors_values[0][:azimuth] = nil
    doors_values[0][:r_value] = nil
  elsif hpxml_file == 'valid-enclosure-multiple-walls.xml'
    doors_values[0][:wall_idref] = "WallLarge"
  elsif hpxml_file == 'valid-enclosure-orientation-45.xml'
    doors_values[0][:azimuth] = 315
  elsif hpxml_file == 'invalid_files/invalid-unattached-door.xml'
    doors_values[0][:wall_idref] = "foobar"
  end
  return doors_values
end

def get_hpxml_file_heating_systems_values(hpxml_file, heating_systems_values)
  if hpxml_file == 'valid.xml'
    heating_systems_values = [{ :id => "HeatingSystem",
                                :distribution_system_idref => "HVACDistribution",
                                :heating_system_type => "Furnace",
                                :heating_system_fuel => "natural gas",
                                :heating_capacity => 64000,
                                :heating_efficiency_afue => 0.92,
                                :fraction_heat_load_served => 1 }]
  elsif ['valid-hvac-air-to-air-heat-pump-1-speed.xml',
         'valid-hvac-air-to-air-heat-pump-2-speed.xml',
         'valid-hvac-air-to-air-heat-pump-var-speed.xml',
         'valid-hvac-central-ac-only-1-speed.xml',
         'valid-hvac-central-ac-only-2-speed.xml',
         'valid-hvac-central-ac-only-var-speed.xml',
         'valid-hvac-ground-to-air-heat-pump.xml',
         'valid-hvac-mini-split-heat-pump-ducted.xml',
         'valid-hvac-mini-split-heat-pump-ductless-no-backup.xml',
         'valid-hvac-ideal-air.xml',
         'valid-hvac-none.xml',
         'valid-hvac-room-ac-only.xml'].include? hpxml_file
    heating_systems_values = []
  elsif hpxml_file == 'valid-hvac-boiler-elec-only.xml'
    heating_systems_values[0][:heating_system_type] = "Boiler"
    heating_systems_values[0][:heating_system_fuel] = "electricity"
    heating_systems_values[0][:heating_efficiency_afue] = 1
  elsif ['valid-hvac-boiler-gas-central-ac-1-speed.xml',
         'valid-hvac-boiler-gas-only.xml'].include? hpxml_file
    heating_systems_values[0][:heating_system_type] = "Boiler"
    heating_systems_values[0][:electric_auxiliary_energy] = 200
  elsif hpxml_file == 'valid-hvac-boiler-oil-only.xml'
    heating_systems_values[0][:heating_system_type] = "Boiler"
    heating_systems_values[0][:heating_system_fuel] = "fuel oil"
  elsif hpxml_file == 'valid-hvac-boiler-propane-only.xml'
    heating_systems_values[0][:heating_system_type] = "Boiler"
    heating_systems_values[0][:heating_system_fuel] = "propane"
  elsif hpxml_file == 'valid-hvac-elec-resistance-only.xml'
    heating_systems_values[0][:distribution_system_idref] = nil
    heating_systems_values[0][:heating_system_type] = "ElectricResistance"
    heating_systems_values[0][:heating_system_fuel] = "electricity"
    heating_systems_values[0][:heating_efficiency_afue] = nil
    heating_systems_values[0][:heating_efficiency_percent] = 1
  elsif ['valid-hvac-furnace-elec-only.xml'].include? hpxml_file
    heating_systems_values[0][:heating_system_fuel] = "electricity"
    heating_systems_values[0][:heating_efficiency_afue] = 1
  elsif ['valid-hvac-furnace-gas-only.xml',
         'valid-hvac-room-ac-furnace-gas.xml'].include? hpxml_file
    heating_systems_values[0][:electric_auxiliary_energy] = 700
  elsif ['valid-hvac-furnace-gas-only-no-eae.xml',
         'valid-hvac-boiler-gas-only-no-eae.xml',
         'valid-hvac-stove-oil-only-no-eae.xml',
         'valid-hvac-wall-furnace-propane-only-no-eae.xml'].include? hpxml_file
    heating_systems_values[0][:electric_auxiliary_energy] = nil
  elsif hpxml_file == 'valid-hvac-furnace-oil-only.xml'
    heating_systems_values[0][:heating_system_fuel] = "fuel oil"
  elsif hpxml_file == 'valid-hvac-furnace-propane-only.xml'
    heating_systems_values[0][:heating_system_fuel] = "propane"
  elsif hpxml_file == 'valid-hvac-multiple.xml'
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
  elsif hpxml_file == 'valid-hvac-stove-oil-only.xml'
    heating_systems_values[0][:distribution_system_idref] = nil
    heating_systems_values[0][:heating_system_type] = "Stove"
    heating_systems_values[0][:heating_system_fuel] = "fuel oil"
    heating_systems_values[0][:heating_efficiency_afue] = nil
    heating_systems_values[0][:heating_efficiency_percent] = 0.8
    heating_systems_values[0][:electric_auxiliary_energy] = 200
  elsif hpxml_file == 'valid-hvac-wall-furnace-propane-only.xml'
    heating_systems_values[0][:distribution_system_idref] = nil
    heating_systems_values[0][:heating_system_type] = "WallFurnace"
    heating_systems_values[0][:heating_system_fuel] = "propane"
    heating_systems_values[0][:heating_efficiency_afue] = 0.8
    heating_systems_values[0][:electric_auxiliary_energy] = 200
  elsif hpxml_file == 'invalid_files/invalid-unattached-hvac.xml.skip'
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
  if hpxml_file == 'valid.xml'
    cooling_systems_values = [{ :id => "CoolingSystem",
                                :distribution_system_idref => "HVACDistribution",
                                :cooling_system_type => "central air conditioning",
                                :cooling_system_fuel => "electricity",
                                :cooling_capacity => 48000,
                                :fraction_cool_load_served => 1,
                                :cooling_efficiency_seer => 13 }]
  elsif ['valid-hvac-air-to-air-heat-pump-1-speed.xml',
         'valid-hvac-air-to-air-heat-pump-2-speed.xml',
         'valid-hvac-air-to-air-heat-pump-var-speed.xml',
         'valid-hvac-boiler-elec-only.xml',
         'valid-hvac-boiler-gas-only.xml',
         'valid-hvac-boiler-oil-only.xml',
         'valid-hvac-boiler-propane-only.xml',
         'valid-hvac-elec-resistance-only.xml',
         'valid-hvac-furnace-elec-only.xml',
         'valid-hvac-furnace-gas-only.xml',
         'valid-hvac-furnace-oil-only.xml',
         'valid-hvac-furnace-propane-only.xml',
         'valid-hvac-ground-to-air-heat-pump.xml',
         'valid-hvac-mini-split-heat-pump-ducted.xml',
         'valid-hvac-mini-split-heat-pump-ductless-no-backup.xml',
         'valid-hvac-ideal-air.xml',
         'valid-hvac-none.xml',
         'valid-hvac-stove-oil-only.xml',
         'valid-hvac-wall-furnace-propane-only.xml'].include? hpxml_file
    cooling_systems_values = []
  elsif ['valid-hvac-boiler-gas-central-ac-1-speed.xml'].include? hpxml_file
    cooling_systems_values[0][:distribution_system_idref] = "HVACDistribution2"
  elsif ['valid-hvac-furnace-gas-central-ac-2-speed.xml',
         'valid-hvac-central-ac-only-2-speed.xml'].include? hpxml_file
    cooling_systems_values[0][:cooling_efficiency_seer] = 18
  elsif ['valid-hvac-furnace-gas-central-ac-var-speed.xml',
         'valid-hvac-central-ac-only-var-speed.xml'].include? hpxml_file
    cooling_systems_values[0][:cooling_efficiency_seer] = 24
  elsif ['valid-hvac-furnace-gas-room-ac.xml',
         'valid-hvac-room-ac-furnace-gas.xml',
         'valid-hvac-room-ac-only.xml'].include? hpxml_file
    cooling_systems_values[0][:distribution_system_idref] = nil
    cooling_systems_values[0][:cooling_system_type] = "room air conditioner"
    cooling_systems_values[0][:cooling_efficiency_seer] = nil
    cooling_systems_values[0][:cooling_efficiency_eer] = 8.5
  elsif hpxml_file == 'valid-hvac-multiple.xml'
    cooling_systems_values[0][:distribution_system_idref] = "HVACDistribution4"
    cooling_systems_values[0][:fraction_cool_load_served] = 0.2
    cooling_systems_values << { :id => "CoolingSystem2",
                                :cooling_system_type => "room air conditioner",
                                :cooling_system_fuel => "electricity",
                                :cooling_capacity => 48000,
                                :fraction_cool_load_served => 0.2,
                                :cooling_efficiency_eer => 8.5 }
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
  if ['valid-hvac-air-to-air-heat-pump-1-speed.xml'].include? hpxml_file
    heat_pumps_values << { :id => "HeatPump",
                           :distribution_system_idref => "HVACDistribution",
                           :heat_pump_type => "air-to-air",
                           :heat_pump_fuel => "electricity",
                           :cooling_capacity => 48000,
                           :fraction_heat_load_served => 1,
                           :fraction_cool_load_served => 1,
                           :heating_efficiency_hspf => 7.7,
                           :cooling_efficiency_seer => 13 }
  elsif ['valid-hvac-air-to-air-heat-pump-2-speed.xml'].include? hpxml_file
    heat_pumps_values << { :id => "HeatPump",
                           :distribution_system_idref => "HVACDistribution",
                           :heat_pump_type => "air-to-air",
                           :heat_pump_fuel => "electricity",
                           :cooling_capacity => 48000,
                           :fraction_heat_load_served => 1,
                           :fraction_cool_load_served => 1,
                           :heating_efficiency_hspf => 9.3,
                           :cooling_efficiency_seer => 18 }
  elsif ['valid-hvac-air-to-air-heat-pump-var-speed.xml'].include? hpxml_file
    heat_pumps_values << { :id => "HeatPump",
                           :distribution_system_idref => "HVACDistribution",
                           :heat_pump_type => "air-to-air",
                           :heat_pump_fuel => "electricity",
                           :cooling_capacity => 48000,
                           :fraction_heat_load_served => 1,
                           :fraction_cool_load_served => 1,
                           :heating_efficiency_hspf => 10,
                           :cooling_efficiency_seer => 22 }
  elsif ['valid-hvac-ground-to-air-heat-pump.xml'].include? hpxml_file
    heat_pumps_values << { :id => "HeatPump",
                           :distribution_system_idref => "HVACDistribution",
                           :heat_pump_type => "ground-to-air",
                           :heat_pump_fuel => "electricity",
                           :cooling_capacity => 48000,
                           :fraction_heat_load_served => 1,
                           :fraction_cool_load_served => 1,
                           :heating_efficiency_cop => 3.6,
                           :cooling_efficiency_eer => 16.6 }
  elsif hpxml_file == 'valid-hvac-mini-split-heat-pump-ducted.xml'
    heat_pumps_values << { :id => "HeatPump",
                           :distribution_system_idref => "HVACDistribution",
                           :heat_pump_type => "mini-split",
                           :heat_pump_fuel => "electricity",
                           :cooling_capacity => 48000,
                           :fraction_heat_load_served => 1,
                           :fraction_cool_load_served => 1,
                           :heating_efficiency_hspf => 10,
                           :cooling_efficiency_seer => 19 }
  elsif hpxml_file == 'valid-hvac-mini-split-heat-pump-ductless.xml'
    heat_pumps_values[0][:distribution_system_idref] = nil
  elsif hpxml_file == 'valid-hvac-mini-split-heat-pump-ductless-no-backup.xml'
    heat_pumps_values[0][:backup_heating_capacity] = 0
  elsif hpxml_file == 'valid-hvac-multiple.xml'
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
  if hpxml_file == 'valid.xml'
    hvac_control_values = { :id => "HVACControl",
                            :control_type => "manual thermostat" }
  elsif ['valid-hvac-none.xml'].include? hpxml_file
    hvac_control_values = {}
  elsif hpxml_file == 'valid-hvac-programmable-thermostat.xml'
    hvac_control_values[:control_type] = "programmable thermostat"
  elsif hpxml_file == 'valid-hvac-setpoints.xml'
    hvac_control_values[:setpoint_temp_heating_season] = 60
    hvac_control_values[:setpoint_temp_cooling_season] = 80
  end
  return hvac_control_values
end

def get_hpxml_file_hvac_distributions_values(hpxml_file, hvac_distributions_values)
  if hpxml_file == 'valid.xml'
    hvac_distributions_values = [{ :id => "HVACDistribution",
                                   :distribution_system_type => "AirDistribution" }]
  elsif ['valid-hvac-boiler-elec-only.xml',
         'valid-hvac-boiler-gas-only.xml',
         'valid-hvac-boiler-oil-only.xml',
         'valid-hvac-boiler-propane-only.xml'].include? hpxml_file
    hvac_distributions_values[0][:distribution_system_type] = "HydronicDistribution"
  elsif ['valid-hvac-boiler-gas-central-ac-1-speed.xml'].include? hpxml_file
    hvac_distributions_values[0][:distribution_system_type] = "HydronicDistribution"
    hvac_distributions_values << { :id => "HVACDistribution2",
                                   :distribution_system_type => "AirDistribution" }
  elsif ['valid-hvac-none.xml',
         'valid-hvac-elec-resistance-only.xml',
         'valid-hvac-ideal-air.xml',
         'valid-hvac-mini-split-heat-pump-ductless.xml',
         'valid-hvac-room-ac-only.xml',
         'valid-hvac-stove-oil-only.xml',
         'valid-hvac-wall-furnace-propane-only.xml'].include? hpxml_file
    hvac_distributions_values = []
  elsif hpxml_file == 'valid-hvac-multiple.xml'
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
  elsif hpxml_file.include? 'hvac_dse' and hpxml_file.include? 'dse-0.8.xml'
    hvac_distributions_values[0][:distribution_system_type] = "DSE"
    hvac_distributions_values[0][:annual_heating_dse] = 0.8
    hvac_distributions_values[0][:annual_cooling_dse] = 0.8
  elsif hpxml_file.include? 'hvac_dse' and hpxml_file.include? 'dse-1.0.xml'
    hvac_distributions_values[0][:annual_heating_dse] = 1
    hvac_distributions_values[0][:annual_cooling_dse] = 1
  elsif ['hvac_multiple/valid-hvac-air-to-air-heat-pump-1-speed-x3.xml.skip',
         'hvac_multiple/valid-hvac-air-to-air-heat-pump-2-speed-x3.xml.skip',
         'hvac_multiple/valid-hvac-air-to-air-heat-pump-var-speed-x3.xml.skip',
         'hvac_multiple/valid-hvac-central-ac-only-1-speed-x3.xml',
         'hvac_multiple/valid-hvac-central-ac-only-2-speed-x3.xml',
         'hvac_multiple/valid-hvac-central-ac-only-var-speed-x3.xml',
         'hvac_multiple/valid-hvac-furnace-elec-only-x3.xml.skip',
         'hvac_multiple/valid-hvac-furnace-gas-only-x3.xml.skip',
         'hvac_multiple/valid-hvac-ground-to-air-heat-pump-x3.xml.skip',
         'hvac_multiple/valid-hvac-mini-split-heat-pump-ducted-x3.xml.skip'].include? hpxml_file
    hvac_distributions_values << { :id => "HVACDistribution2",
                                   :distribution_system_type => "AirDistribution" }
    hvac_distributions_values << { :id => "HVACDistribution3",
                                   :distribution_system_type => "AirDistribution" }
  elsif ['hvac_multiple/valid-hvac-boiler-elec-only-x3.xml',
         'hvac_multiple/valid-hvac-boiler-gas-only-x3.xml'].include? hpxml_file
    hvac_distributions_values << { :id => "HVACDistribution2",
                                   :distribution_system_type => "HydronicDistribution" }
    hvac_distributions_values << { :id => "HVACDistribution3",
                                   :distribution_system_type => "HydronicDistribution" }
  end
  return hvac_distributions_values
end

def get_hpxml_file_duct_leakage_measurements_values(hpxml_file, duct_leakage_measurements_values)
  if hpxml_file == 'valid.xml'
    duct_leakage_measurements_values = [[{ :duct_type => "supply",
                                           :duct_leakage_value => 75 },
                                         { :duct_type => "return",
                                           :duct_leakage_value => 25 }]]
  elsif ['valid-hvac-boiler-gas-central-ac-1-speed.xml'].include? hpxml_file
    duct_leakage_measurements_values[0] = []
    duct_leakage_measurements_values << [{ :duct_type => "supply",
                                           :duct_leakage_value => 75 },
                                         { :duct_type => "return",
                                           :duct_leakage_value => 25 }]
  elsif hpxml_file == 'valid-hvac-mini-split-heat-pump-ducted.xml'
    duct_leakage_measurements_values[0][0][:duct_leakage_value] = 15
    duct_leakage_measurements_values[0][1][:duct_leakage_value] = 5
  elsif hpxml_file == 'valid-hvac-multiple.xml'
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
  elsif ['hvac_multiple/valid-hvac-air-to-air-heat-pump-1-speed-x3.xml.skip',
         'hvac_multiple/valid-hvac-air-to-air-heat-pump-2-speed-x3.xml.skip',
         'hvac_multiple/valid-hvac-air-to-air-heat-pump-var-speed-x3.xml.skip',
         'hvac_multiple/valid-hvac-central-ac-only-1-speed-x3.xml',
         'hvac_multiple/valid-hvac-central-ac-only-2-speed-x3.xml',
         'hvac_multiple/valid-hvac-central-ac-only-var-speed-x3.xml',
         'hvac_multiple/valid-hvac-furnace-elec-only-x3.xml.skip',
         'hvac_multiple/valid-hvac-furnace-gas-only-x3.xml.skip',
         'hvac_multiple/valid-hvac-ground-to-air-heat-pump-x3.xml.skip',
         'hvac_multiple/valid-hvac-mini-split-heat-pump-ducted-x3.xml.skip'].include? hpxml_file
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
  if hpxml_file == 'valid.xml'
    ducts_values = [[{ :duct_type => "supply",
                       :duct_insulation_r_value => 4,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 150 },
                     { :duct_type => "return",
                       :duct_insulation_r_value => 0,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 50 }]]
  elsif hpxml_file == 'valid-foundation-conditioned-basement-reference.xml'
    ducts_values[0][0][:duct_location] = "basement - conditioned"
    ducts_values[0][1][:duct_location] = "basement - conditioned"
  elsif ['valid-foundation-unconditioned-basement.xml'].include? hpxml_file
    ducts_values[0][0][:duct_location] = "basement - unconditioned"
    ducts_values[0][1][:duct_location] = "basement - unconditioned"
  elsif ['valid-foundation-unvented-crawlspace.xml'].include? hpxml_file
    ducts_values[0][0][:duct_location] = "crawlspace - unvented"
    ducts_values[0][1][:duct_location] = "crawlspace - unvented"
  elsif ['valid-foundation-vented-crawlspace.xml'].include? hpxml_file
    ducts_values[0][0][:duct_location] = "crawlspace - vented"
    ducts_values[0][1][:duct_location] = "crawlspace - vented"
  elsif ['valid-hvac-boiler-gas-central-ac-1-speed.xml'].include? hpxml_file
    ducts_values[0] = []
    ducts_values << [{ :duct_type => "supply",
                       :duct_insulation_r_value => 4,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 150 },
                     { :duct_type => "return",
                       :duct_insulation_r_value => 0,
                       :duct_location => "attic - unvented",
                       :duct_surface_area => 50 }]
  elsif hpxml_file == 'valid-hvac-mini-split-heat-pump-ducted.xml'
    ducts_values[0][0][:duct_insulation_r_value] = 0
    ducts_values[0][0][:duct_surface_area] = 30
    ducts_values[0][1][:duct_surface_area] = 10
  elsif hpxml_file == 'valid-hvac-multiple.xml'
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
  elsif ['hvac_multiple/valid-hvac-air-to-air-heat-pump-1-speed-x3.xml.skip',
         'hvac_multiple/valid-hvac-air-to-air-heat-pump-2-speed-x3.xml.skip',
         'hvac_multiple/valid-hvac-air-to-air-heat-pump-var-speed-x3.xml.skip',
         'hvac_multiple/valid-hvac-central-ac-only-1-speed-x3.xml',
         'hvac_multiple/valid-hvac-central-ac-only-2-speed-x3.xml',
         'hvac_multiple/valid-hvac-central-ac-only-var-speed-x3.xml',
         'hvac_multiple/valid-hvac-furnace-elec-only-x3.xml.skip',
         'hvac_multiple/valid-hvac-furnace-gas-only-x3.xml.skip',
         'hvac_multiple/valid-hvac-ground-to-air-heat-pump-x3.xml.skip',
         'hvac_multiple/valid-hvac-mini-split-heat-pump-ducted-x3.xml.skip'].include? hpxml_file
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
  if hpxml_file == 'valid-mechvent-balanced.xml'
    ventilation_fans_values << { :id => "MechanicalVentilation",
                                 :fan_type => "balanced",
                                 :rated_flow_rate => 247,
                                 :hours_in_operation => 24,
                                 :fan_power => 123.5 }
  elsif ['invalid_files/invalid-unattached-cfis.xml.skip',
         'valid-mechvent-cfis.xml',
         'cfis/valid-cfis.xml',
         'cfis/valid-hvac-air-to-air-heat-pump-1-speed-cfis.xml',
         'cfis/valid-hvac-air-to-air-heat-pump-2-speed-cfis.xml',
         'cfis/valid-hvac-air-to-air-heat-pump-var-speed-cfis.xml',
         'cfis/valid-hvac-central-ac-only-1-speed-cfis.xml',
         'cfis/valid-hvac-central-ac-only-2-speed-cfis.xml',
         'cfis/valid-hvac-central-ac-only-var-speed-cfis.xml',
         'cfis/valid-hvac-furnace-elec-only-cfis.xml',
         'cfis/valid-hvac-furnace-gas-central-ac-2-speed-cfis.xml',
         'cfis/valid-hvac-furnace-gas-central-ac-var-speed-cfis.xml',
         'cfis/valid-hvac-furnace-gas-only-cfis.xml',
         'cfis/valid-hvac-furnace-gas-room-ac-cfis.xml',
         'cfis/valid-hvac-ground-to-air-heat-pump-cfis.xml',
         'cfis/valid-hvac-room-ac-furnace-gas-cfis.xml'].include? hpxml_file
    ventilation_fans_values << { :id => "MechanicalVentilation",
                                 :fan_type => "central fan integrated supply",
                                 :rated_flow_rate => 247,
                                 :hours_in_operation => 8,
                                 :fan_power => 360,
                                 :distribution_system_idref => "HVACDistribution" }
  elsif hpxml_file == 'valid-mechvent-erv.xml'
    ventilation_fans_values << { :id => "MechanicalVentilation",
                                 :fan_type => "energy recovery ventilator",
                                 :rated_flow_rate => 247,
                                 :hours_in_operation => 24,
                                 :total_recovery_efficiency => 0.48,
                                 :sensible_recovery_efficiency => 0.72,
                                 :fan_power => 123.5 }
  elsif hpxml_file == 'valid-mechvent-exhaust.xml'
    ventilation_fans_values << { :id => "MechanicalVentilation",
                                 :fan_type => "exhaust only",
                                 :rated_flow_rate => 247,
                                 :hours_in_operation => 24,
                                 :fan_power => 60 }
  elsif hpxml_file == 'valid-mechvent-hrv.xml'
    ventilation_fans_values << { :id => "MechanicalVentilation",
                                 :fan_type => "heat recovery ventilator",
                                 :rated_flow_rate => 247,
                                 :hours_in_operation => 24,
                                 :sensible_recovery_efficiency => 0.72,
                                 :fan_power => 123.5 }
  elsif hpxml_file == 'valid-mechvent-supply.xml'
    ventilation_fans_values << { :id => "MechanicalVentilation",
                                 :fan_type => "supply only",
                                 :rated_flow_rate => 247,
                                 :hours_in_operation => 24,
                                 :fan_power => 60 }
  elsif hpxml_file == 'cfis/valid-hvac-boiler-gas-central-ac-1-speed-cfis.xml'
    ventilation_fans_values << { :id => "MechanicalVentilation",
                                 :fan_type => "central fan integrated supply",
                                 :rated_flow_rate => 247,
                                 :hours_in_operation => 8,
                                 :fan_power => 360,
                                 :distribution_system_idref => "HVACDistribution2" }
  end
  return ventilation_fans_values
end

def get_hpxml_file_water_heating_system_values(hpxml_file, water_heating_systems_values)
  if hpxml_file == 'valid.xml'
    water_heating_systems_values = [{ :id => "WaterHeater",
                                      :fuel_type => "electricity",
                                      :water_heater_type => "storage water heater",
                                      :location => "living space",
                                      :tank_volume => 40,
                                      :fraction_dhw_load_served => 1,
                                      :heating_capacity => 18767,
                                      :energy_factor => 0.95 }]
  elsif hpxml_file == 'valid-dhw-location-attic.xml'
    water_heating_systems_values[0][:location] = "attic - unvented"
  elsif hpxml_file == 'valid-dhw-multiple.xml'
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
  elsif hpxml_file == 'valid-dhw-tank-gas.xml'
    water_heating_systems_values[0][:fuel_type] = "natural gas"
    water_heating_systems_values[0][:tank_volume] = 50
    water_heating_systems_values[0][:heating_capacity] = 4500
    water_heating_systems_values[0][:energy_factor] = 0.59
    water_heating_systems_values[0][:recovery_efficiency] = 0.76
  elsif hpxml_file == 'valid-dhw-tank-heat-pump.xml'
    water_heating_systems_values[0][:water_heater_type] = "heat pump water heater"
    water_heating_systems_values[0][:tank_volume] = 80
    water_heating_systems_values[0][:heating_capacity] = nil
    water_heating_systems_values[0][:energy_factor] = 2.3
  elsif hpxml_file == 'valid-dhw-tankless-electric.xml'
    water_heating_systems_values[0][:water_heater_type] = "instantaneous water heater"
    water_heating_systems_values[0][:tank_volume] = nil
    water_heating_systems_values[0][:heating_capacity] = nil
    water_heating_systems_values[0][:energy_factor] = 0.99
  elsif hpxml_file == 'valid-dhw-tankless-gas.xml'
    water_heating_systems_values[0][:fuel_type] = "natural gas"
    water_heating_systems_values[0][:water_heater_type] = "instantaneous water heater"
    water_heating_systems_values[0][:tank_volume] = nil
    water_heating_systems_values[0][:heating_capacity] = nil
    water_heating_systems_values[0][:energy_factor] = 0.82
  elsif hpxml_file == 'valid-dhw-tankless-oil.xml'
    water_heating_systems_values[0][:fuel_type] = "fuel oil"
    water_heating_systems_values[0][:water_heater_type] = "instantaneous water heater"
    water_heating_systems_values[0][:tank_volume] = nil
    water_heating_systems_values[0][:heating_capacity] = nil
    water_heating_systems_values[0][:energy_factor] = 0.82
  elsif hpxml_file == 'valid-dhw-tankless-propane.xml'
    water_heating_systems_values[0][:fuel_type] = "propane"
    water_heating_systems_values[0][:water_heater_type] = "instantaneous water heater"
    water_heating_systems_values[0][:tank_volume] = nil
    water_heating_systems_values[0][:heating_capacity] = nil
    water_heating_systems_values[0][:energy_factor] = 0.82
  elsif hpxml_file == 'valid-dhw-tank-oil.xml'
    water_heating_systems_values[0][:fuel_type] = "fuel oil"
    water_heating_systems_values[0][:tank_volume] = 50
    water_heating_systems_values[0][:heating_capacity] = 4500
    water_heating_systems_values[0][:energy_factor] = 0.59
    water_heating_systems_values[0][:recovery_efficiency] = 0.76
  elsif hpxml_file == 'valid-dhw-tank-propane.xml'
    water_heating_systems_values[0][:fuel_type] = "propane"
    water_heating_systems_values[0][:tank_volume] = 50
    water_heating_systems_values[0][:heating_capacity] = 4500
    water_heating_systems_values[0][:energy_factor] = 0.59
    water_heating_systems_values[0][:recovery_efficiency] = 0.76
  elsif hpxml_file == 'valid-dhw-uef.xml'
    water_heating_systems_values[0][:energy_factor] = nil
    water_heating_systems_values[0][:uniform_energy_factor] = 0.93
  elsif hpxml_file == 'valid-foundation-conditioned-basement-reference.xml'
    water_heating_systems_values[0][:location] = "basement - conditioned"
  elsif ['valid-foundation-unconditioned-basement.xml'].include? hpxml_file
    water_heating_systems_values[0][:location] = "basement - unconditioned"
  elsif ['valid-foundation-unvented-crawlspace.xml'].include? hpxml_file
    water_heating_systems_values[0][:location] = "crawlspace - unvented"
  elsif ['valid-foundation-vented-crawlspace.xml'].include? hpxml_file
    water_heating_systems_values[0][:location] = "crawlspace - vented"
  elsif ['valid-dhw-none.xml'].include? hpxml_file
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
  if hpxml_file == 'valid.xml'
    hot_water_distribution_values = { :id => "HotWaterDstribution",
                                      :system_type => "Standard",
                                      :standard_piping_length => 30,
                                      :pipe_r_value => 0.0 }
  elsif hpxml_file == 'valid-dhw-dwhr.xml'
    hot_water_distribution_values[:dwhr_facilities_connected] = "all"
    hot_water_distribution_values[:dwhr_equal_flow] = true
    hot_water_distribution_values[:dwhr_efficiency] = 0.55
  elsif hpxml_file == 'valid-dhw-recirc-demand.xml'
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "presence sensor demand control"
    hot_water_distribution_values[:recirculation_piping_length] = 30
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
    hot_water_distribution_values[:pipe_r_value] = 3
  elsif hpxml_file == 'valid-dhw-recirc-manual.xml'
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "manual demand control"
    hot_water_distribution_values[:recirculation_piping_length] = 30
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
    hot_water_distribution_values[:pipe_r_value] = 3
  elsif hpxml_file == 'valid-dhw-recirc-nocontrol.xml'
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "no control"
    hot_water_distribution_values[:recirculation_piping_length] = 30
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
  elsif hpxml_file == 'valid-dhw-recirc-temperature.xml'
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "temperature"
    hot_water_distribution_values[:recirculation_piping_length] = 30
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
  elsif hpxml_file == 'valid-dhw-recirc-timer.xml'
    hot_water_distribution_values[:system_type] = "Recirculation"
    hot_water_distribution_values[:recirculation_control_type] = "timer"
    hot_water_distribution_values[:recirculation_piping_length] = 30
    hot_water_distribution_values[:recirculation_branch_piping_length] = 30
    hot_water_distribution_values[:recirculation_pump_power] = 50
  elsif hpxml_file == 'valid-dhw-recirc-timer-reference.xml'
    hot_water_distribution_values[:recirculation_piping_length] = nil
  elsif hpxml_file == 'valid-dhw-standard-reference.xml'
    hot_water_distribution_values[:standard_piping_length] = nil
  elsif ['valid-dhw-none.xml'].include? hpxml_file
    hot_water_distribution_values = {}
  end
  return hot_water_distribution_values
end

def get_hpxml_file_water_fixtures_values(hpxml_file, water_fixtures_values)
  if hpxml_file == 'valid.xml'
    water_fixtures_values = [{ :id => "WaterFixture",
                               :water_fixture_type => "shower head",
                               :low_flow => true },
                             { :id => "WaterFixture2",
                               :water_fixture_type => "faucet",
                               :low_flow => false }]
  elsif hpxml_file == 'valid-dhw-low-flow-fixtures.xml'
    water_fixtures_values[1][:low_flow] = true
  elsif ['valid-dhw-none.xml'].include? hpxml_file
    water_fixtures_values = []
  end
  return water_fixtures_values
end

def get_hpxml_file_pv_system_values(hpxml_file, pv_systems_values)
  if hpxml_file == 'valid-pv-array-1axis.xml'
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "standard",
                           :array_type => "1-axis",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  elsif hpxml_file == 'valid-pv-array-1axis-backtracked.xml'
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "standard",
                           :array_type => "1-axis backtracked",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  elsif hpxml_file == 'valid-pv-array-2axis.xml'
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "standard",
                           :array_type => "2-axis",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  elsif hpxml_file == 'valid-pv-array-fixed-open-rack.xml'
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "standard",
                           :array_type => "fixed open rack",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  elsif hpxml_file == 'valid-pv-module-premium.xml'
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "premium",
                           :array_type => "fixed roof mount",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  elsif hpxml_file == 'valid-pv-module-standard.xml'
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "standard",
                           :array_type => "fixed roof mount",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  elsif hpxml_file == 'valid-pv-module-thinfilm.xml.skip'
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "thin film",
                           :array_type => "fixed roof mount",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  elsif hpxml_file == 'valid-pv-multiple.xml'
    pv_systems_values << { :id => "PVSystem",
                           :module_type => "standard",
                           :array_type => "fixed roof mount",
                           :array_azimuth => 180,
                           :array_tilt => 20,
                           :max_power_output => 4000,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
    pv_systems_values << { :id => "PVSystem2",
                           :module_type => "standard",
                           :array_type => "fixed roof mount",
                           :array_azimuth => 90,
                           :array_tilt => 20,
                           :max_power_output => 1500,
                           :inverter_efficiency => 0.96,
                           :system_losses_fraction => 0.14 }
  end
  return pv_systems_values
end

def get_hpxml_file_clothes_washer_values(hpxml_file, clothes_washer_values)
  if hpxml_file == 'valid.xml'
    clothes_washer_values = { :id => "ClothesWasher",
                              :location => "living space",
                              :modified_energy_factor => 1.2,
                              :rated_annual_kwh => 387.0,
                              :label_electric_rate => 0.127,
                              :label_gas_rate => 1.003,
                              :label_annual_gas_cost => 24.0,
                              :capacity => 3.5 }
  elsif hpxml_file == 'valid-appliances-none.xml'
    clothes_washer_values = {}
  elsif hpxml_file == 'valid-appliances-washer-imef.xml'
    clothes_washer_values[:modified_energy_factor] = nil
    clothes_washer_values[:integrated_modified_energy_factor] = 0.73
  elsif hpxml_file == 'valid-appliances-in-basement.xml'
    clothes_washer_values[:location] = "basement - conditioned"
  elsif hpxml_file == 'valid-misc-appliances-in-basement.xml'
    clothes_washer_values[:location] = "basement - conditioned"
  end
  return clothes_washer_values
end

def get_hpxml_file_clothes_dryer_values(hpxml_file, clothes_dryer_values)
  if hpxml_file == 'valid.xml'
    clothes_dryer_values = { :id => "ClothesDryer",
                             :location => "living space",
                             :fuel_type => "electricity",
                             :energy_factor => 3.01,
                             :control_type => "timer" }
  elsif hpxml_file == 'valid-appliances-none.xml'
    clothes_dryer_values = {}
  elsif hpxml_file == 'valid-appliances-dryer-cef.xml'
    clothes_dryer_values[:energy_factor] = nil
    clothes_dryer_values[:combined_energy_factor] = 2.62
    clothes_dryer_values[:control_type] = "moisture"
  elsif hpxml_file == 'valid-appliances-gas.xml'
    clothes_dryer_values[:fuel_type] = "natural gas"
    clothes_dryer_values[:energy_factor] = 2.67
    clothes_dryer_values[:control_type] = "moisture"
  elsif hpxml_file == 'valid-appliances-in-basement.xml'
    clothes_dryer_values[:location] = "basement - conditioned"
  elsif hpxml_file == 'valid-misc-appliances-in-basement.xml'
    clothes_dryer_values[:location] = "basement - conditioned"
  end
  return clothes_dryer_values
end

def get_hpxml_file_dishwasher_values(hpxml_file, dishwasher_values)
  if hpxml_file == 'valid.xml'
    dishwasher_values = { :id => "Dishwasher",
                          :rated_annual_kwh => 100,
                          :place_setting_capacity => 12 }
  elsif hpxml_file == 'valid-appliances-none.xml'
    dishwasher_values = {}
  elsif hpxml_file == 'valid-appliances-dishwasher-ef.xml'
    dishwasher_values[:rated_annual_kwh] = nil
    dishwasher_values[:energy_factor] = 0.5
    dishwasher_values[:place_setting_capacity] = 8
  end
  return dishwasher_values
end

def get_hpxml_file_refrigerator_values(hpxml_file, refrigerator_values)
  if hpxml_file == 'valid.xml'
    refrigerator_values = { :id => "Refrigerator",
                            :location => "living space",
                            :rated_annual_kwh => 609 }
  elsif hpxml_file == 'valid-appliances-none.xml'
    refrigerator_values = {}
  elsif hpxml_file == 'valid-appliances-in-basement.xml'
    refrigerator_values[:location] = "basement - conditioned"
  elsif hpxml_file == 'valid-misc-appliances-in-basement.xml'
    refrigerator_values[:location] = "basement - conditioned"
  end
  return refrigerator_values
end

def get_hpxml_file_cooking_range_values(hpxml_file, cooking_range_values)
  if hpxml_file == 'valid.xml'
    cooking_range_values = { :id => "Range",
                             :fuel_type => "electricity",
                             :is_induction => true }
  elsif hpxml_file == 'valid-appliances-none.xml'
    cooking_range_values = {}
  elsif hpxml_file == 'valid-appliances-gas.xml'
    cooking_range_values[:fuel_type] = "natural gas"
    cooking_range_values[:is_induction] = false
  end
  return cooking_range_values
end

def get_hpxml_file_oven_values(hpxml_file, oven_values)
  if hpxml_file == 'valid.xml'
    oven_values = { :id => "Oven",
                    :is_convection => true }
  elsif hpxml_file == 'valid-appliances-none.xml'
    oven_values = {}
  end
  return oven_values
end

def get_hpxml_file_lighting_values(hpxml_file, lighting_values)
  if hpxml_file == 'valid.xml'
    lighting_values = { :fraction_tier_i_interior => 0.5,
                        :fraction_tier_i_exterior => 0.5,
                        :fraction_tier_i_garage => 0.5,
                        :fraction_tier_ii_interior => 0.25,
                        :fraction_tier_ii_exterior => 0.25,
                        :fraction_tier_ii_garage => 0.25 }
  elsif hpxml_file == 'valid-misc-lighting-default.xml'
    lighting_values = { :fraction_tier_i_interior => 0.1,
                        :fraction_tier_i_exterior => 0.0,
                        :fraction_tier_i_garage => 0.0,
                        :fraction_tier_ii_interior => 0.0,
                        :fraction_tier_ii_exterior => 0.0,
                        :fraction_tier_ii_garage => 0.0 }
  elsif hpxml_file == 'valid-misc-lighting-none.xml'
    lighting_values = {}
  end
  return lighting_values
end

def get_hpxml_file_ceiling_fan_values(hpxml_file, ceiling_fans_values)
  if hpxml_file == 'valid-misc-ceiling-fans.xml'
    ceiling_fans_values << { :id => "CeilingFan",
                             :efficiency => 100,
                             :quantity => 2 }
  elsif hpxml_file == 'valid-misc-ceiling-fans-reference.xml'
    ceiling_fans_values[0][:efficiency] = nil
    ceiling_fans_values[0][:quantity] = nil
  end
  return ceiling_fans_values
end

def get_hpxml_file_plug_loads_values(hpxml_file, plug_loads_values)
  if hpxml_file == 'valid-misc-loads-detailed.xml'
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
  if hpxml_file == 'valid-misc-loads-detailed.xml'
    misc_load_schedule_values = { :weekday_fractions => "0.020, 0.020, 0.020, 0.020, 0.020, 0.034, 0.043, 0.085, 0.050, 0.030, 0.030, 0.041, 0.030, 0.025, 0.026, 0.026, 0.039, 0.042, 0.045, 0.070, 0.070, 0.073, 0.073, 0.066",
                                  :weekend_fractions => "0.020, 0.020, 0.020, 0.020, 0.020, 0.034, 0.043, 0.085, 0.050, 0.030, 0.030, 0.041, 0.030, 0.025, 0.026, 0.026, 0.039, 0.042, 0.045, 0.070, 0.070, 0.073, 0.073, 0.066",
                                  :monthly_multipliers => "1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0" }
  end
  return misc_load_schedule_values
end
