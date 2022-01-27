import csv
import json
import pathlib
import re


def main():
    here = pathlib.Path(__file__).resolve().parent
    json_schema_filename = here / '..' / '..' / '..' / 'hescore-hpxml' / 'hescorehpxml' / 'schemas' / 'hescore_json.schema.json'
    assert json_schema_filename.exists()

    with json_schema_filename.open('r') as f:
        json_schema = json.load(f)

    knee_wall_assembly_codes = json_schema['properties']['building']['properties']['zone']['properties']['zone_roof']['items']['properties']['knee_wall']['properties']['assembly_code']['enum']

    # Source ASHRAE Fundamenetals 2013, p 26.20, Table 10, Indoor Vertical Surface Film
    int_air_film_r_value = 0.68

    # Source ASHRAE Fundamentals 2013, p 26.8, Table 1, Gypsum or plaster board, 0.5 inch
    gyp_r_value = 1 / 1.1 * 0.5

    # Source https://coloradoenergy.org/procorner/stuff/r-values.htm
    # This is represents a thermal conductivity of wood of about 0.8 (Btu * in) / (h * ft^2 * °F)
    # Ranges in ASHRAE Fundamentals 2013, p 26.8, Table 1, p 26.11 for soft woods are 0.69 - 1.12
    wood_stud_r_value_per_inch = 4.38 / 3.5

    # 1/2" plywood
    # Source https://coloradoenergy.org/procorner/stuff/r-values.htm
    plywood_r_value = 0.63

    stud_spacing = 16
    wood_stud_width = 1.5

    csv_filename = here / 'lu_knee_wall_eff_rvalue.csv'
    with csv_filename.open('w') as f:
        csv_writer = csv.writer(f)
        csv_writer.writerow(['doe2code', 'U-value', 'Eff-R-value'])
        for assembly_code in knee_wall_assembly_codes:
            cav_r_value = int(re.match(r"kwwf(\d+)", assembly_code).group(1))
            assembly_r_value = 2 * int_air_film_r_value + gyp_r_value
            if cav_r_value > 0:
                # Add plywood on the back side if there's insulation
                assembly_r_value += plywood_r_value
            if cav_r_value < 11:
                # Air gap R-value if it doesn't fill the cavity
                cav_r_value += 1
            if cav_r_value == 19:
                # Compressed
                # see https://hvac-blog.acca.org/wp-content/uploads/2017/07/owens-corning-compressed-fiberglass-insulation-r-value-chart.png
                cav_r_value = 18
            wood_stud_r_value = (3.5 if cav_r_value <= 15 else 5.5) * wood_stud_r_value_per_inch
            assembly_r_value += 1 / (
                wood_stud_width / stud_spacing / wood_stud_r_value + 
                (1 - wood_stud_width / stud_spacing) / cav_r_value
            )
            assembly_u_value = 1 / assembly_r_value
            csv_writer.writerow([assembly_code, f"{assembly_u_value:.3f}", f"{assembly_r_value:.1f}"])


if __name__ == '__main__':
    main()
