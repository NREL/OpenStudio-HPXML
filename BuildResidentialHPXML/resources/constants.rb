# frozen_string_literal: true

class Constants
  def self.Auto
    return 'auto'
  end

  def self.CoordRelative
    return 'relative'
  end

  def self.FacadeFront
    return 'front'
  end

  def self.FacadeBack
    return 'back'
  end

  def self.FacadeLeft
    return 'left'
  end

  def self.FacadeRight
    return 'right'
  end

  def self.OptionTypeLightingScheduleCalculated
    return 'Calculated Lighting Schedule'
  end

  # Numbers --------------------

  def self.NumApplyUpgradeOptions
    return 25
  end

  def self.NumApplyUpgradesCostsPerOption
    return 2
  end

  def self.PeakFlowRate
    return 500 # gal/min
  end

  def self.PeakPower
    return 100 # kWh
  end
end
