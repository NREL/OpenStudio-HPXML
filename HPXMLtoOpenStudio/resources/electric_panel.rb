# frozen_string_literal: true

# TODO
class PanelLoadValues
  LOADBASED_ATTRS = [:LoadBased_CapacityW,
                     :LoadBased_CapacityA,
                     :LoadBased_ConstraintW]
  METERBASED_ATTRS = [:MeterBased_CapacityW,
                      :MeterBased_CapacityA,
                      :MeterBased_ConstraintW]
  BREAKERSPACE_ATTRS = [:BreakerSpace_HVAC,
                        :BreakerSpace_Total]
  attr_accessor(*LOADBASED_ATTRS)
  attr_accessor(*METERBASED_ATTRS)
  attr_accessor(*BREAKERSPACE_ATTRS)

  def initialize
    (LOADBASED_ATTRS + METERBASED_ATTRS + BREAKERSPACE_ATTRS).each do |attr|
      send("#{attr}=", 0.0)
    end
  end
end
