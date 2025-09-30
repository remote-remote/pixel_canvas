{ pkgs, lib, config, inputs, ... }:

{
  env.ERL_AFLAGS = "-kernel shell_history enabled";

  languages.elixir = {
    enable = true;
  };
}
