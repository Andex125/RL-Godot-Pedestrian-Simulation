"""
Helper script per analizzare i dati di training separati per istanza.
Posiziona questo file in: scripts/utils/training_data_analysis_helper.py
"""

import pandas as pd
import re
from pathlib import Path
from typing import Dict, List
from pedpy import TrajectoryData


def extract_instance_and_collision(group_value: int) -> tuple:
    """
    Estrae instance_id e collision_group dal valore combinato.

    Args:
        group_value: Valore combinato (instance_id * 10000 + collision_group)

    Returns:
        tuple: (instance_id, collision_group)
    """
    instance_id = group_value // 10000
    collision_group = group_value % 10000
    return instance_id, collision_group


def load_training_trajectories(file_path: Path, separate_instances: bool = True) -> Dict[int, pd.DataFrame]:
    """
    Carica le traiettorie di training e le separa per istanza.

    Args:
        file_path: Percorso al file di traiettorie
        separate_instances: Se True, separa i dati per istanza

    Returns:
        Dictionary con instance_id come chiave e DataFrame come valore
    """
    # Leggi il file
    df = pd.read_csv(
        file_path,
        sep=r"\s+",
        comment="#",
        header=None,
        names=['id', 'frame', 'x', 'y', 'z', 'combined_group'],
    )

    # Estrai instance_id e collision_group
    df[['instance_id', 'collision_group']] = df['combined_group'].apply(
        lambda x: pd.Series(extract_instance_and_collision(x))
    )

    if not separate_instances:
        return {-1: df}  # Ritorna tutti i dati insieme

    # Separa per istanza
    instances = {}
    for instance_id in df['instance_id'].unique():
        instances[instance_id] = df[df['instance_id'] == instance_id].copy()

    return instances


def create_trajectory_data_per_instance(file_path: Path) -> Dict[int, TrajectoryData]:
    """
    Crea oggetti TrajectoryData per ogni istanza.

    Args:
        file_path: Percorso al file di traiettorie

    Returns:
        Dictionary con instance_id come chiave e TrajectoryData come valore
    """
    # Leggi il framerate dal file
    with open(file_path, 'r') as file:
        first_line = file.readline().strip()

    match = re.search(r'# framerate: (\d+) fps', first_line)
    if not match:
        raise Exception('fps not found in trajectory file')
    fps = int(match.group(1))

    # Carica i dati separati per istanza
    instances = load_training_trajectories(file_path, separate_instances=True)

    # Crea TrajectoryData per ogni istanza
    trajectory_data = {}
    for instance_id, df in instances.items():
        # Prepara il DataFrame nel formato richiesto da PedPy
        pedpy_df = df[['id', 'frame', 'x', 'y']].copy()
        trajectory_data[instance_id] = TrajectoryData(pedpy_df, fps)

    return trajectory_data


def print_instance_statistics(file_path: Path):
    """
    Stampa statistiche sui dati per ogni istanza.

    Args:
        file_path: Percorso al file di traiettorie
    """
    instances = load_training_trajectories(file_path)

    print(f"\n{'=' * 60}")
    print(f"Training Data Statistics: {file_path.name}")
    print(f"{'=' * 60}\n")

    for instance_id, df in instances.items():
        n_pedestrians = df['id'].nunique()
        n_frames = df['frame'].nunique()
        n_collision_groups = df['collision_group'].nunique()

        print(f"Instance {instance_id}:")
        print(f"  - Pedestrians: {n_pedestrians}")
        print(f"  - Frames: {n_frames}")
        print(f"  - Collision groups: {n_collision_groups}")
        print(f"  - Total data points: {len(df)}")
        print()


# Esempio di utilizzo
if __name__ == "__main__":
    # Path al file di traiettorie
    trajectory_file = Path("../output/runs/stage/my_run/Corridor/LevelBatch_trajectories.txt")

    # Stampa statistiche
    print_instance_statistics(trajectory_file)

    # Carica i dati per istanza
    instances = load_training_trajectories(trajectory_file)

    # Esempio: analizza solo l'istanza 0
    instance_0_df = instances[0]
    print(f"\nInstance 0 - First 10 rows:")
    print(instance_0_df.head(10))

    # Esempio: crea TrajectoryData per ogni istanza (per usare con PedPy)
    trajectory_data = create_trajectory_data_per_instance(trajectory_file)
    print(f"\nCreated TrajectoryData objects for {len(trajectory_data)} instances")
