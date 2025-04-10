import functools

import elements
import embodied
import bsk_envs
import minigrid
import novgrid
import numpy as np
import gymnasium as gym
from gymnasium.envs.registration import register
from gymnasium.envs.classic_control.cartpole import CartPoleEnv


class CustomCartPoleEnv(CartPoleEnv):
    def __init__(self, length=0.5, masspole=0.1, **kwargs):
        super().__init__(**kwargs)
        self.length = length
        self.masspole = masspole
        self.total_mass = self.masspole + self.masscart  # Update total mass
        self.polemass_length = self.masspole * self.length  # Update derived property

register(
    id="CustomCartPole-v0",
    entry_point=CustomCartPoleEnv,
    max_episode_steps=200
)

env_configs = {
  'door_key_change': [
    {
      "env_id": "NovGrid-ColoredDoorKeyEnv",
      "door_color": "red",
      "correct_key_color": "red",
      "key_colors": ["red", "blue"]
    },
    {
      "env_id": "NovGrid-ColoredDoorKeyEnv",
      "door_color": "red",
      "correct_key_color": "blue",
      "key_colors": ["red", "blue"]
    }
  ],
  'custom_cart_pole': [
    {"env_id": "CustomCartPole-v0", "length": 0.5},
    {"env_id": "CustomCartPole-v0", "length": 1},
  ],
  'orbit_discovery_mu': [
    {
      "env_id": "OrbitDiscovery3DOF-v0",
      "mu": 2.463e5,
      "radius": 8000
    },
    {
      "env_id": "OrbitDiscovery3DOF-v0",
      "mu": 4.463e5,
      "radius": 8000
    },
  ],
  'orbit_discovery_radius': [
    {
      "env_id": "OrbitDiscovery3DOF-v0",
      "mu": 4.463e5,
      "radius": 8000
    },
    {
      "env_id": "OrbitDiscovery3DOF-v0",
      "mu": 4.463e5,
      "radius": 16000
    },
  ]
}


class NovGrid(embodied.Env):

  def __init__(self, env, novelty_step, obs_key='image', act_key='action', **kwargs):
    assert isinstance(env, str)
    self._env = novgrid.NoveltyEnv(
      env_configs=env_configs[env],
      novelty_step=novelty_step,
      # wrappers=[minigrid.wrappers.FlatObsWrapper],
      print_novelty_box=True
    )
    self._obs_dict = hasattr(self._env.observation_space, 'spaces')
    self._act_dict = hasattr(self._env.action_space, 'spaces')
    self._obs_key = obs_key
    self._act_key = act_key
    self._done = True
    self._info = None

  @property
  def env(self):
    return self._env

  @property
  def info(self):
    return self._info

  @functools.cached_property
  def obs_space(self):
    if self._obs_dict:
      spaces = self._flatten(self._env.observation_space.spaces)
    else:
      spaces = {self._obs_key: self._env.observation_space}
    spaces = {k: self._convert(v) for k, v in spaces.items()}
    return {
        **spaces,
        'reward': elements.Space(np.float32),
        'is_first': elements.Space(bool),
        'is_last': elements.Space(bool),
        'is_terminal': elements.Space(bool),
    }

  @functools.cached_property
  def act_space(self):
    if self._act_dict:
      spaces = self._flatten(self._env.action_space.spaces)
    else:
      spaces = {self._act_key: self._env.action_space}
    spaces = {k: self._convert(v) for k, v in spaces.items()}
    spaces['reset'] = elements.Space(bool)
    return spaces

  def step(self, action):
    if action['reset'] or self._done:
      self._done = False
      obs = self._env.reset()
      return self._obs(obs[0], 0.0, is_first=True)
    if self._act_dict:
      action = self._unflatten(action)
    else:
      action = action[self._act_key]
    obs, reward, self._done, self._info = self._env.step([action])
    return self._obs(
        obs[0], reward[0],
        is_last=bool(self._done[0]),
        is_terminal=bool(self._info[0].get('is_terminal', self._done)))

  def _obs(
      self, obs, reward, is_first=False, is_last=False, is_terminal=False):
    if not self._obs_dict:
      obs = {self._obs_key: obs}
    obs = self._flatten(obs)
    obs = {k: np.asarray(v) for k, v in obs.items()}
    obs.update(
        reward=np.float32(reward),
        is_first=is_first,
        is_last=is_last,
        is_terminal=is_terminal)
    return obs

  def render(self):
    image = self._env.render('rgb_array')
    assert image is not None
    return image

  def close(self):
    try:
      self._env.close()
    except Exception:
      pass

  def _flatten(self, nest, prefix=None):
    result = {}
    for key, value in nest.items():
      key = prefix + '/' + key if prefix else key
      if isinstance(value, gym.spaces.Dict):
        value = value.spaces
      if isinstance(value, dict):
        result.update(self._flatten(value, key))
      else:
        result[key] = value
    return result

  def _unflatten(self, flat):
    result = {}
    for key, value in flat.items():
      parts = key.split('/')
      node = result
      for part in parts[:-1]:
        if part not in node:
          node[part] = {}
        node = node[part]
      node[parts[-1]] = value
    return result

  def _convert(self, space):
    if hasattr(space, 'n'):
      return elements.Space(np.int32, (), 0, space.n)
    return elements.Space(space.dtype, space.shape, space.low, space.high)
