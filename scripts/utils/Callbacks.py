
from math import floor
from typing import Optional

import numpy as np
from pandas import Series
from stable_baselines3.common.callbacks import BaseCallback
from stable_baselines3.common.monitor import load_results


class EndTrainingOnMeanRewardReachedCallback(BaseCallback):
    """
    Callback used to stop training if the trimmed mean reward is greater than a certain threshold.
    The trimmed mean reward is calculated removing the top and bottom 10% of the values, to eliminate outliers.
    """

    def __init__(self, log_dir: str, mean_reward: float, episodes_for_mean: int):
        """
        Callback constructor
        :param log_dir: Log file to get the reward from. Must be a VecMonitor log file.
        :param mean_reward: Mean reward threshold to reach to stop training current level.
        :param episodes_for_mean: Number of episodes used to calculate the mean reward.
        """
        super().__init__()

        self.log_dir = log_dir
        self.mean_reward = mean_reward
        self.episodes_for_mean = episodes_for_mean
        self.cycle = 1

    def _on_step(self) -> bool:
        """
        Callback method to decide whether to stop or continue execution.
        :return: True to continue execution, False to stop execution
        """
        # print("Cycle: ", self.cycle)
        episodes = load_results(self.log_dir)
        if len(episodes) >= (self.episodes_for_mean * self.cycle):

            mean_reward = trimmed_mean(
                episodes['r'].iloc[self.episodes_for_mean * (self.cycle - 1) : self.episodes_for_mean * self.cycle]
            )
            self.cycle += 1

            if mean_reward > self.mean_reward:
                return False
        return True


class EndTrainingOnEarlyFailCallback(BaseCallback):
    """
    Callback to decide whether to stop or continue training on minimum mean reward reached or on early fail.
    The entire execution will stop if the model cant reach the trimmed mean reward threshold after a certain number of
    episodes. The trimmed mean reward is calculated removing the top and bottom 10% of the values, to eliminate outliers.
    """

    def __init__(self, log_dir: str, min_mean_reward: float, episodes_for_mean: int, max_cycles: int):
        """
        Callback constructor
        :param log_dir: Log file to get the reward from. Must be a VecMonitor log file.
        :param min_mean_reward: Mean reward threshold to reach to continue execution.
        :param episodes_for_mean: Number of episodes used to calculate the mean reward.
        :param max_cycles: Number of cycles after which the execution is stopped if the threshold is not reached.
        """
        super().__init__()
        self.log_dir = log_dir
        self.min_mean_reward = min_mean_reward
        self.episodes_for_mean = episodes_for_mean
        self.max_cycles = max_cycles
        self.cycle = 1
        self.no_improvement = 0

    def _on_step(self) -> bool:
        """
        Callback method to decide whether to stop or continue execution.
        :return: True to continue execution, False to stop execution
        """
        episodes = load_results(self.log_dir)
        if len(episodes) >= (self.episodes_for_mean * self.cycle):

            mean_reward = trimmed_mean(
                episodes['r'].iloc[self.episodes_for_mean * (self.cycle - 1):self.episodes_for_mean * self.cycle]
            )
            self.cycle += 1

            if mean_reward < self.min_mean_reward:
                self.no_improvement += 1
                if self.no_improvement == self.max_cycles:
                    print("Training stopped by early fail")
                    exit()

        return True


class EndTrainingCombinedCallback(BaseCallback):
    """
    Enhanced callback with debugging information for training analysis.
    Supports both trimmed mean reward threshold and trimmed variance (stability) threshold.
    """

    def __init__(self, log_dir: str, min_mean_reward: float, episodes_for_mean: int, max_cycles: int, max_var: Optional[float] = None):
        super().__init__()
        self.log_dir = log_dir
        self.min_mean_reward = min_mean_reward
        self.episodes_for_mean = episodes_for_mean
        self.max_cycles = max_cycles
        self.max_var = max_var
        self.cycle = 1
        self.no_improvement = 0

        # Add tracking for debugging
        self.reward_history = []
        self.var_history = []
        self.last_rewards = []

    def _on_step(self) -> bool:
        episodes = load_results(self.log_dir)
        if len(episodes) >= (self.episodes_for_mean * self.cycle):

            recent_rewards = episodes['r'].iloc[
                             self.episodes_for_mean * (self.cycle - 1):self.episodes_for_mean * self.cycle]
            mean_reward = trimmed_mean(recent_rewards)
            current_var = trimmed_variance(recent_rewards)

            self.reward_history.append(mean_reward)
            self.var_history.append(current_var)
            self.last_rewards = recent_rewards.tolist()

            print(f"\n=== CYCLE {self.cycle} ANALYSIS ===")
            print(f"Target reward: {self.min_mean_reward}")
            print(f"Current mean reward: {mean_reward:.4f}")
            if self.max_var is not None:
                print(f"Target max variance: {self.max_var}")
                print(f"Current trimmed variance: {current_var:.4f}")
            print(f"Recent rewards stats:")
            avg = 0
            for r in self.reward_history:
                avg += r
            avg /= len(self.reward_history)
            print("avg reward: {:.4f}".format(avg))
            print("max reward: {:.4f}".format(np.max(self.reward_history)))
            print(f"  - Min: {recent_rewards.min():.4f}")
            print(f"  - Max: {recent_rewards.max():.4f}")
            print(f"  - Std: {recent_rewards.std():.4f}")
            print(f"  - Trimmed Var: {current_var:.4f}")
            print(f"  - Episodes with positive reward: {(recent_rewards > 0).sum()}/{len(recent_rewards)}")
            print(
                f"  - Episodes reaching target: {(recent_rewards >= self.min_mean_reward).sum()}/{len(recent_rewards)}")
            print(f"Progress: {self.cycle}/{self.max_cycles} cycles")

            self.cycle += 1

            reward_ok = mean_reward > self.min_mean_reward
            var_ok = (self.max_var is None) or (current_var <= self.max_var)

            if reward_ok and var_ok:
                var_str = f" and var {current_var:.4f} <= {self.max_var}" if self.max_var is not None else ""
                print(f"✅ SUCCESS! Target reached: {mean_reward:.4f} > {self.min_mean_reward}{var_str}")
                return False

            self.no_improvement += 1
            if reward_ok and not var_ok:
                print(f"⚠️ Target mean reward reached ({mean_reward:.4f} > {self.min_mean_reward}), but variance too high ({current_var:.4f} > {self.max_var}). Not yet stable: {self.no_improvement}/{self.max_cycles}")
            else:
                print(f"❌ Target not reached. Failures: {self.no_improvement}/{self.max_cycles}")

            if self.no_improvement == self.max_cycles:
                print("\n" + "=" * 50)
                print("TRAINING STOPPED BY EARLY FAIL")
                print("=" * 50)
                print("Reward history:", [f"{r:.3f}" for r in self.reward_history])
                if self.max_var is not None:
                    print("Variance history:", [f"{v:.3f}" for v in self.var_history])
                avg = 0
                for r in self.reward_history:
                    avg += r
                avg /= len(self.reward_history)
                print("avg reward: {:.4f}".format(avg))
                print("max reward: {:.4f}".format(np.max(self.reward_history)))
                print("Last 10 episode rewards:", [f"{r:.3f}" for r in self.last_rewards[-10:]])
                print("Suggestions:")
                print("1. Lower target reward from", self.min_mean_reward, "to", max(0.0, self.min_mean_reward - 1.0))
                if self.max_var is not None:
                    print("2. Increase max_var from", self.max_var, "to", round(self.max_var * 1.5, 2))
                print("3. Increase max_cycles from", self.max_cycles, "to", self.max_cycles + 5)
                print("4. Check level difficulty and reward structure")
                print("5. Consider adjusting hyperparameters")
                print("=" * 50)
                exit()

        return True


def trimmed_mean(values: Series) -> float:
    # MANTIENI questa funzione come è già
    trim_range: int = floor(len(values) / 10)
    if trim_range == 0:  # Handle small datasets
        return np.mean(values)
    trimmed_values = values.sort_values().iloc[trim_range:-trim_range]
    return np.mean(trimmed_values)


def trimmed_variance(values: Series) -> float:
    """
    Calculates trimmed variance by removing top and bottom 10% outliers,
    measuring stability of learned policy.
    """
    trim_range: int = floor(len(values) / 10)
    if trim_range == 0:
        return float(np.var(values))
    trimmed_values = values.sort_values().iloc[trim_range:-trim_range]
    return float(np.var(trimmed_values))



