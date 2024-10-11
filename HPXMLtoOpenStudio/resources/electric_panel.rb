# frozen_string_literal: true

# TODO
class PanelLoadValues
  LOADBASED_ATTRS = [:LoadBased_CapacityW,
                     :LoadBased_CapacityA]
  METERBASED_ATTRS = [:MeterBased_CapacityW,
                      :MeterBased_CapacityA]
  attr_accessor(*LOADBASED_ATTRS)
  attr_accessor(*METERBASED_ATTRS)

  def initialize
    (LOADBASED_ATTRS + METERBASED_ATTRS).each do |attr|
      send("#{attr}=", 0.0)
    end
  end
end
