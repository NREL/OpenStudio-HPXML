import os
import argparse
import pandas as pd
import csv

class Compare:

  def samples(self, base_folder, feature_folder, export_folder):

    def value_counts(df, file):
      value_counts = []
      with open(file, 'w', newline='') as f:

        for col in sorted(df.columns):
          if col == 'Building':
            continue

          value_count = df[col].value_counts(normalize=True)
          value_count = value_count.round(2)
          keys_to_values = dict(zip(value_count.index.values, value_count.values))
          keys_to_values = dict(sorted(keys_to_values.items(), key=lambda x: (x[1], x[0]), reverse=True))
          value_counts.append([value_count.name])
          value_counts.append(keys_to_values.keys())
          value_counts.append(keys_to_values.values())
          value_counts.append('')

        w = csv.writer(f)
        w.writerows(value_counts)

    df = pd.read_csv(os.path.join(base_folder, 'base_buildstock.csv'))
    file = os.path.join(export_folder, 'base_samples.csv')
    value_counts(df, file)

    df = pd.read_csv(os.path.join(feature_folder, 'buildstock.csv'))
    file = os.path.join(export_folder, 'feature_samples.csv')
    value_counts(df, file)


  def results(self, base_folder, feature_folder, export_folder, aggregate_by=[]):
    files = []
    for file in os.listdir(base_folder):
      if file.endswith('.csv'):
        files.append(file)

    for file in files:
      base_df = pd.read_csv(os.path.join(base_folder, file), index_col=0)
      feature_df = pd.read_csv(os.path.join(feature_folder, file), index_col=0)

      df = feature_df - base_df
      df = df.fillna('NA')
      df.to_csv(os.path.join(export_folder, file))

  def visualize(self, base_folder, feature_folder, export_folder):
    files = []
    for file in os.listdir(base_folder):
      if file.endswith('.csv'):
        files.append(file)

    for file in files:
      base_df = pd.read_csv(os.path.join(base_folder, file), index_col=0)
      feature_df = pd.read_csv(os.path.join(feature_folder, file), index_col=0)



if __name__ == '__main__':

  default_base_folder = 'workflow/tests/base_results'
  default_feature_folder = 'workflow/tests/results'
  default_export_folder = 'workflow/tests/comparisons'

  actions = [method for method in dir(Compare) if method.startswith('__') is False]

  parser = argparse.ArgumentParser()
  parser.add_argument('-b', '--base_folder', default=default_base_folder, help='TODO')
  parser.add_argument('-f', '--feature_folder', default=default_feature_folder, help='TODO')
  parser.add_argument('-a', '--actions', action='append', choices=actions, help='TODO')
  parser.add_argument('-e', '--export_folder', default=default_export_folder, help='TODO')
  args = parser.parse_args()

  if not os.path.exists(args.export_folder):
    os.makedirs(args.export_folder)

  compare = Compare()

  if args.actions == None:
    args.actions = []

  for action in args.actions:
    getattr(compare, action)(args.base_folder, args.feature_folder, args.export_folder)
