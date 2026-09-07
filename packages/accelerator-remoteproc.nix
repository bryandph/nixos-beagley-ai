{
  writeShellApplication,
  writeText,
  python3,
  profile,
}: let
  contract = writeText "beagley-ai-${profile}-remoteproc.json" (builtins.toJSON {
    allowStop = profile == "ipc";
    cores = (import ./accelerator-profiles.nix).${profile};
    memory =
      if profile == "vision"
      then import ./accelerator-memory.nix
      else {};
  });
in
  writeShellApplication {
    name = "beagley-ai-remoteproc";
    runtimeInputs = [python3];
    text = ''exec python3 ${./accelerator-remoteproc.py} ${contract} "$@"'';
  }
