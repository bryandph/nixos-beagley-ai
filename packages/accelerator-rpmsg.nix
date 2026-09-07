{
  stdenv,
  lib,
  fetchgit,
  autoreconfHook,
  pkg-config,
}:
stdenv.mkDerivation {
  pname = "beagley-ai-ti-rpmsg-char";
  version = "0.6.10";
  src = fetchgit {
    url = "https://git.ti.com/git/rpmsg/ti-rpmsg-char.git";
    rev = "057b1a249261e26d00c501b59646957160ec815b";
    hash = "sha256-UvXQptVLEquP9DfbB5x40nJJX/xQ4RDL8NbXruXVKUk=";
  };
  nativeBuildInputs = [autoreconfHook pkg-config];
  postInstall = ''
    install -Dm444 TI_RPMsg_Char_0.1.0_manifest.html "$out/share/licenses/beagley-ai-ti-rpmsg-char/manifest.html"
    install -Dm444 include/ti_rpmsg_char.h "$out/share/licenses/beagley-ai-ti-rpmsg-char/ti_rpmsg_char.h"
  '';
  meta = {
    description = "TI userspace RPMsg character-device library for the matched EdgeAI runtime";
    license = lib.licenses.bsd3;
    platforms = ["aarch64-linux"];
  };
}
