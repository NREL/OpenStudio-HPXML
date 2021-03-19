require 'csv'

folder = 'comparisons'
files = ['results.csv', 'results_ashrae_140.csv', 'results_hvac_sizing.csv']

dir = File.join(File.dirname(__FILE__), 'tests', folder)
unless Dir.exist?(dir)
  Dir.mkdir(dir)
end

files.each do |file|
  # load file
  master_rows = CSV.read(File.join(File.dirname(__FILE__), "tests/master/#{file}"))
  feature_rows = CSV.read(File.join(File.dirname(__FILE__), "tests/results/#{file}"))

  # get columns
  master_cols = master_rows[0]
  feature_cols = feature_rows[0]

  # get data
  master = {}
  master_rows[1..-1].each do |row|
    hpxml = row[0]
    master[hpxml] = {}
    row[1..-1].each_with_index do |field, i|
      begin
        master[hpxml][master_cols[i + 1]] = Float(field)
      rescue
      end
    end
  end

  feature = {}
  feature_rows[1..-1].each do |row|
    hpxml = row[0]
    feature[hpxml] = {}
    row[1..-1].each_with_index do |field, i|
      begin
        feature[hpxml][feature_cols[i + 1]] = Float(field)
      rescue
      end
    end
  end

  # get hpxml union
  master_hpxmls = master_rows.transpose[0][1..-1]
  feature_hpxmls = feature_rows.transpose[0][1..-1]
  hpxmls = master_hpxmls | feature_hpxmls

  # get column union
  cols = master_cols | feature_cols

  # create comparison table
  rows = [cols]
  hpxmls.each do |hpxml|
    row = [hpxml]
    cols.each do |col|
      next if col == 'HPXML'

      begin
        master_field = master[hpxml][col]
      rescue
      end

      begin
        feature_field = feature[hpxml][col]
      rescue
      end

      m = 'N/A'
      if (not master_field.nil?) && (not feature_field.nil?)
        m = "#{(feature_field - master_field).round(1)}"
      end

      row << m
    end
    rows << row
  end

  # export comparison table
  CSV.open(File.join(dir, file), 'wb') do |csv|
    rows.each do |row|
      csv << row
    end
  end
end
