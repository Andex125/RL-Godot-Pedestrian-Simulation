from typing import Optional


class Level:
    """
    Class used to store level information. The level itself isn't stored in python, but the model synchronize with
    the godot env to train. This class only contains the information needed to stop training on a certain level.
    """

    def __init__(self, name: str, mean_reward: float, episodes_for_mean: int, cycles: int, mean_var: Optional[float] = None):
        """
        Level constructor.
        :param name: Level name.
        :param mean_reward: Mean reward threshold to reach to step to next level.
        :param episodes_for_mean: Episodes used to calculate mean reward.
        :param cycles: Number of cycles after which the execution is stopped if the threshold is not reached.
        :param mean_var: Maximum trimmed variance allowed to consider policy stable and pass level.
        """
        self.name = name
        self.mean_reward = mean_reward
        self.episodes_for_mean = episodes_for_mean
        self.cycles = cycles
        self.mean_var = mean_var

    def __repr__(self) -> str:
        return f"Level(name={self.name}, mean_reward={self.mean_reward}, episodes_for_mean={self.episodes_for_mean}, cycles={self.cycles}, mean_var={self.mean_var})"

