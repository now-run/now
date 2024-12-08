from os import environ
from sys import stderr


class UnknownEnvironmentError(Exception):
    pass


class Config:
    debug = True

    def __init__(self, env_vars):
        self.env_vars = env_vars
        if 'DEBUG' in env_vars:
            self.debug = env_vars['DEBUG'].lower() in ('1', 'true', 'y')


class ProdConfig(Config):
    debug = False

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        print("prod config called", file=stderr)


class DevConfig(Config):
    debug = True

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        print("dev config called", file=stderr)


envs = {
    "prod": ProdConfig,
    "dev": DevConfig,
}

def start(env="dev"):
    try:
        config_class = envs[env]
    except KeyError:
        raise UnknownEnvironmentError(f"Unknown environment name: {env}")
    else:
        config = config_class(environ)

    print(config)


if __name__ == "__main__":
    start(environ.get("env", "dev"))
