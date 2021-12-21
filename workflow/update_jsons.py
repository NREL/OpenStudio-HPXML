import json
from os import sep
import pathlib
import subprocess


def main():
    file_root = pathlib.Path(__file__).resolve().parent.parent / 'hescore-hpxml' / 'examples'
    assert file_root.exists()
    for filename in file_root.glob('**/*.json'):
        print(filename)
        with filename.open('r') as f:
            hesd = json.load(f)
        changed_file = False
        delete_file = False
        for i, zone_roof in enumerate(hesd['building']['zone']['zone_roof']):
            if zone_roof['roof_type'] == 'vented_attic':
                hesd['building']['zone']['zone_roof'][i] = dict(
                    ('ceiling_area', v) if k == 'roof_area' else (k, v) for k, v in zone_roof.items()
                )
                changed_file = True
            elif zone_roof['roof_type'] == 'cath_ceiling':
                pass
            elif zone_roof['roof_type'] == 'cond_attic':
                delete_file = True
                break
            else:
                assert False

        if delete_file:
            subprocess.run(
                ['git', 'rm', str(filename.relative_to(file_root))],
                cwd=file_root
            )
            continue

        if changed_file:
            with filename.open('w') as f:
                json.dump(hesd, f, indent=2)


if __name__ == '__main__':
    main()
