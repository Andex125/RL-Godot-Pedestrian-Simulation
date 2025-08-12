from scripts.utils.Runner import Runner
import os
import re

def get_next_run_number_by_checking_dirs(base_name="ProvaObbiettivi", base_dir="output/runs/stage"):
    if not os.path.exists(base_dir):
        os.makedirs(base_dir, exist_ok=True)
        return f"stage/{base_name}1"

    existing_numbers = []
    pattern = f"^{base_name}(\\d+)$"

    for item in os.listdir(base_dir):
        if os.path.isdir(os.path.join(base_dir, item)):
            match = re.match(pattern, item)
            if match:
                existing_numbers.append(int(match.group(1)))

    next_number = max(existing_numbers, default=0) + 1
    return f"stage/{base_name}{next_number}"

run_name = get_next_run_number_by_checking_dirs()

runner = Runner(
    config_path="scripts/configs/sensitivity_studies/net_256_128_64.yaml",
    curriculum_path="scripts/configs/objective/objective_config.yaml",
    run_name=run_name,
)
runner.run()