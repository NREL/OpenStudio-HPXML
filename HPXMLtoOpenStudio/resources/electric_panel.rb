# frozen_string_literal: true

# TODO
module ElectricPanel
  # TODO
  def self.calculate(electric_panel, update_hpxml: true)
    panel_loads = PanelLoadValues.new

    calculate_load_based(electric_panel, panel_loads)
    calculate_breaker_spaces(electric_panel, panel_loads)

    # Assign load-based capacities to HPXML objects for output
    return unless update_hpxml

    electric_panel.clb_total_w = panel_loads.LoadBased_CapacityW.round(1)
    electric_panel.clb_total_a = panel_loads.LoadBased_CapacityA.round
    electric_panel.clb_headroom_a = panel_loads.LoadBased_HeadRoomA.round

    electric_panel.bs_total = panel_loads.BreakerSpaces_Total
    electric_panel.bs_occupied = panel_loads.BreakerSpaces_Occupied
    electric_panel.bs_headroom = panel_loads.BreakerSpaces_HeadRoom
  end

  # TODO
  def self.calculate_load_based(electric_panel, panel_loads)
    htg = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeHeating && !panel_load.addition }.map { |pl| pl.watts }.sum(0.0)
    htg_add = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeHeating && panel_load.addition }.map { |pl| pl.watts }.sum(0.0)
    clg = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeCooling && !panel_load.addition }.map { |pl| pl.watts }.sum(0.0)
    clg_add = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeCooling && panel_load.addition }.map { |pl| pl.watts }.sum(0.0)
    hw = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeWaterHeater }.map { |pl| pl.watts }.sum(0.0)
    cd = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeClothesDryer }.map { |pl| pl.watts }.sum(0.0)
    dw = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeDishwasher }.map { |pl| pl.watts }.sum(0.0)
    ov = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeRangeOven }.map { |pl| pl.watts }.sum(0.0)
    sh = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypePermanentSpaHeater }.map { |pl| pl.watts }.sum(0.0)
    sp = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypePermanentSpaPump }.map { |pl| pl.watts }.sum(0.0)
    ph = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypePoolHeater }.map { |pl| pl.watts }.sum(0.0)
    pp = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypePoolPump }.map { |pl| pl.watts }.sum(0.0)
    wp = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeWellPump }.map { |pl| pl.watts }.sum(0.0)
    ev = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeElectricVehicleCharging }.map { |pl| pl.watts }.sum(0.0)
    ltg = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeLighting }.map { |pl| pl.watts }.sum(0.0)
    kit = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeKitchen }.map { |pl| pl.watts }.sum(0.0)
    lnd = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeLaundry }.map { |pl| pl.watts }.sum(0.0)
    oth = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeOther }.map { |pl| pl.watts }.sum(0.0)

    # Part A
    all_loads = hw + cd + dw + ov + sh + sp + ph + pp + wp + ev + ltg + kit + lnd + oth
    if htg_add == 0 && clg_add == 0
      all_loads += [htg, clg].max
    elsif htg_add == 0
      all_loads += htg
    elsif clg_add == 0
      all_loads += clg
    end
    part_a = 8000.0 + (all_loads - 8000.0) * 0.4

    # Part B
    part_b = 0.0
    if htg_add > 0 && clg_add > 0
      part_b += [htg_add, clg_add].max
    elsif htg_add > 0
      part_b += htg_add
    elsif clg_add > 0
      part_b += clg_add
    end

    panel_loads.LoadBased_CapacityW = part_a + part_b
    panel_loads.LoadBased_CapacityA = panel_loads.LoadBased_CapacityW / Float(electric_panel.voltage)
    panel_loads.LoadBased_HeadRoomA = electric_panel.max_current_rating - panel_loads.LoadBased_CapacityA
  end

  # TODO
  def self.calculate_meter_based(electric_panel, peak_fuels)
    htg_add = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeHeating && panel_load.addition }.map { |pl| pl.watts }.sum(0.0)
    clg_add = electric_panel.panel_loads.select { |panel_load| panel_load.type == HPXML::ElectricPanelLoadTypeCooling && panel_load.addition }.map { |pl| pl.watts }.sum(0.0)

    new_loads = 0.0
    if htg_add > 0 && clg_add > 0
      new_loads += [htg_add, clg_add].max
    elsif htg_add > 0
      new_loads += htg_add
    elsif clg_add > 0
      new_loads += clg_add
    end

    electric_panel.panel_loads.each do |panel_load|
      next if panel_load.type == HPXML::ElectricPanelLoadTypeHeating || panel_load.type == HPXML::ElectricPanelLoadTypeCooling

      new_loads += panel_load.watts if panel_load.addition
    end
    capacity_w = new_loads + 1.25 * peak_fuels[[FT::Elec, PFT::Annual]].annual_output
    capacity_a = capacity_w / Float(electric_panel.voltage)
    headroom_a = electric_panel.max_current_rating - capacity_a
    return capacity_w, capacity_a, headroom_a
  end

  # TODO
  def self.calculate_breaker_spaces(electric_panel, panel_loads)
    total = electric_panel.total_breaker_spaces
    occupied = electric_panel.panel_loads.map { |panel_load| panel_load.breaker_spaces }.sum(0.0)

    panel_loads.BreakerSpaces_Total = total
    panel_loads.BreakerSpaces_Occupied = occupied
    panel_loads.BreakerSpaces_HeadRoom = total - occupied
  end
end

# TODO
class PanelLoadValues
  LOADBASED_ATTRS = [:LoadBased_CapacityW,
                     :LoadBased_CapacityA,
                     :LoadBased_HeadRoomA]
  BREAKERSPACE_ATTRS = [:BreakerSpaces_Occupied,
                        :BreakerSpaces_Total,
                        :BreakerSpaces_HeadRoom]
  attr_accessor(*LOADBASED_ATTRS)
  attr_accessor(*BREAKERSPACE_ATTRS)

  def initialize
    (LOADBASED_ATTRS +
     BREAKERSPACE_ATTRS).each do |attr|
      send("#{attr}=", 0.0)
    end
  end
end
