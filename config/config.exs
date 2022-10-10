import Config

config :logger, level: String.to_atom(System.get_env("LOG_LEVEL") || "info")
