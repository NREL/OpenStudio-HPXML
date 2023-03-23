# frozen_string_literal: true

class Constants
  def self.OccupancyTypesProbabilities
    return '0.381, 0.297, 0.165, 0.157'
  end

  def self.CeilingFanWeekdayFractions
    return '0.04, 0.037, 0.037, 0.036, 0.033, 0.036, 0.043, 0.047, 0.034, 0.023, 0.024, 0.025, 0.024, 0.028, 0.031, 0.032, 0.039, 0.053, 0.063, 0.067, 0.071, 0.069, 0.059, 0.05'
  end

  def self.CeilingFanWeekendFractions
    return '0.04, 0.037, 0.037, 0.036, 0.033, 0.036, 0.043, 0.047, 0.034, 0.023, 0.024, 0.025, 0.024, 0.028, 0.031, 0.032, 0.039, 0.053, 0.063, 0.067, 0.071, 0.069, 0.059, 0.05'
  end

  def self.SinkDurationProbability
    return '0.901242, 0.076572, 0.01722, 0.003798, 0.000944, 0.000154, 4.6e-05, 2.2e-05, 2.0e-06'
  end

  def self.SinkEventsPerClusterProbs
    return '0.62458, 0.18693, 0.08011, 0.0433, 0.02178, 0.01504, 0.0083, 0.00467, 0.0057, 0.00285, 0.00181, 0.00233, 0.0013, 0.00104, 0.00026'
  end

  def self.SinkHourlyOnsetProb
    return '0.007, 0.018, 0.042, 0.062, 0.066, 0.062, 0.054, 0.05, 0.049, 0.045, 0.041, 0.043, 0.048, 0.065, 0.075, 0.069, 0.057, 0.048, 0.04, 0.027, 0.014, 0.007, 0.005, 0.005'
  end

  def self.SinkAvgSinkClustersPerHH
    return 6657
  end

  def self.SinkMinutesBetweenEventGap
    return 2
  end

  def self.SinkFlowRateMean
    return 1.14
  end

  def self.SinkFlowRateStd
    return 0.61
  end

  def self.ShowerMinutesBetweenEventGap
    return 30
  end

  def self.ShowerFlowRateMean
    return 2.25
  end

  def self.ShowerFlowRateStd
    return 0.68
  end

  def self.BathBathToShowerRatio
    return 0.078843
  end

  def self.BathDurationMean
    return 5.65
  end

  def self.BathDurationStd
    return 2.09
  end

  def self.BathFlowRateMean
    return 4.4
  end

  def self.BathFlowRateStd
    return 1.17
  end

  def self.HotWaterDishwasherFlowRateMean
    return 1.39
  end

  def self.HotWaterDishwasherFlowRateStd
    return 0.2
  end

  def self.HotWaterDishwasherMinutesBetweenEventGap
    return 10
  end

  def self.HotWaterDishwasherMonthlyMultiplier
    return '1.083, 1.056, 1.023, 0.999, 0.975, 0.944, 0.918, 0.928, 0.938, 0.984, 1.059, 1.094'
  end

  def self.HotWaterClothesWasherFlowRateMean
    return 2.2
  end

  def self.HotWaterClothesWasherFlowRateStd
    return 0.62
  end

  def self.HotWaterClothesWasherMinutesBetweenEventGap
    return 4
  end

  def self.HotWaterClothesWasherLoadSizeProbability
    return '0.682926829, 0.227642276, 0.056910569, 0.032520325'
  end

  def self.HotWaterClothesWasherMonthlyMultiplier
    return '0.968, 1.013, 0.99, 1.034, 1.019, 1.015, 1.048, 1, 1.021, 0.949, 0.945, 0.999'
  end

  def self.ClothesDryerMonthlyMultiplier
    return '1.09, 1.054, 1.044, 0.996, 0.992, 0.967, 0.931, 0.906, 0.923, 0.955, 1.035, 1.108'
  end

  def self.CookingMonthlyMultiplier
    return '1.038, 1.026, 0.976, 0.945, 0.965, 0.947, 0.939, 0.965, 0.967, 1.006, 1.098, 1.129'
  end
end
