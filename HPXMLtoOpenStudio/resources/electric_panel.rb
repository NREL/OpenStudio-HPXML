# frozen_string_literal: true

# TODO
module ElectricPanel
  # TODO
  def self.calculate(electric_panel, update_hpxml: true)
    panel_loads = PanelLoadValues.new

    calculate_load_based(electric_panel, panel_loads)
    calculate_breaker_space(panel_loads)

    # Assign load-based capacities to HPXML objects for output
    return unless update_hpxml

    electric_panel.clb_total_w = panel_loads.LoadBased_CapacityW.round(1)
    electric_panel.clb_total_a = panel_loads.LoadBased_CapacityA.round
    electric_panel.clb_constraint_a = panel_loads.LoadBased_ConstraintA.round

    electric_panel.bs_total = panel_loads.BreakerSpace_Total
    electric_panel.bs_hvac = panel_loads.BreakerSpace_HVAC
  end

  # TODO
  def self.calculate_load_based(electric_panel, panel_loads)
    htg = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeHeating }
    clg = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeCooling }
    hw = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeWaterHeater }
    cd = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeClothesDryer }
    dw = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeDishwasher }
    ov = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeRangeOven }
    sh = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypePermanentSpaHeater }
    sp = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypePermanentSpaPump }
    ph = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypePoolHeater }
    pp = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypePoolPump }
    wp = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeWellPump }
    ev = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeElectricVehicleCharging }
    ltg = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeLighting }
    kit = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeKitchen }
    lnd = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeLaundry }
    oth = electric_panel.panel_loads.find { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeOther }

    new_hvac = 0.0
    if htg.addition && clg.addition
      new_hvac = [htg.watts, clg.watts].max
    elsif htg.addition
      new_hvac = htg.watts
    elsif clg.addition
      new_hvac = clg.watts
    end

    if new_hvac > 0
      all_loads = hw.watts + cd.watts + dw.watts + ov.watts + sh.watts + sp.watts + ph.watts + pp.watts + wp.watts + ev.watts + ltg.watts + kit.watts + lnd.watts + oth.watts
      part_a = 8000.0 + (all_loads - 8000.0) * 0.4
      part_b = new_hvac
    else
      all_loads = htg.watts + clg.watts + hw.watts + cd.watts + dw.watts + ov.watts + sh.watts + sp.watts + ph.watts + pp.watts + wp.watts + ev.watts + ltg.watts + kit.watts + lnd.watts + oth.watts
      part_a = 8000.0 + (all_loads - 8000.0) * 0.4
      part_b = 0.0
    end

    panel_loads.LoadBased_CapacityW = (part_a + part_b).round(1)
    panel_loads.LoadBased_CapacityA = panel_loads.LoadBased_CapacityW / Float(electric_panel.voltage)
    panel_loads.LoadBased_ConstraintA = electric_panel.max_current_rating - panel_loads.LoadBased_CapacityA
  end

  # TODO
  def self.calculate_meter_based(electric_panel, peak_fuels)
    new_loads = 0.0
    electric_panel.panel_loads.each do |panel_load|
      new_loads += panel_load.watts if panel_load.addition
    end
    capacity_w = (new_loads + 1.25 * peak_fuels[[FT::Elec, PFT::Annual]].annual_output).round(1)
    capacity_a = capacity_w / Float(electric_panel.voltage)
    constraint_a = electric_panel.max_current_rating - capacity_a
    return capacity_w, capacity_a, constraint_a
  end

  # TODO
  def self.calculate_breaker_space(panel_loads)
    # TODO
    panel_loads.BreakerSpace_Total = 1
    panel_loads.BreakerSpace_HVAC = 2
  end
end

# TODO
class PanelLoadValues
  LOADBASED_ATTRS = [:LoadBased_CapacityW,
                     :LoadBased_CapacityA,
                     :LoadBased_ConstraintA]
  # METERBASED_ATTRS = [:MeterBased_CapacityW,
  # :MeterBased_CapacityA,
  # :MeterBased_ConstraintA]
  BREAKERSPACE_ATTRS = [:BreakerSpace_HVAC,
                        :BreakerSpace_Total]
  attr_accessor(*LOADBASED_ATTRS)
  # attr_accessor(*METERBASED_ATTRS)
  attr_accessor(*BREAKERSPACE_ATTRS)

  def initialize
    (LOADBASED_ATTRS +
     # METERBASED_ATTRS +
     BREAKERSPACE_ATTRS).each do |attr|
      send("#{attr}=", 0.0)
    end
  end
end
