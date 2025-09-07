import Config

config :fase, mode: nil

import_config "#{Mix.env()}.exs"
