{pkgs}: let
  # A scoped attribute makes every Python package splice select CPython3.10.
  # Overriding python311 alone loses sourceVersion in Nixpkgs' splice filter.
  scoped = pkgs.extend (final: prev: {
    python310 = prev.python311.override {
      self = final.python310;
      pythonAttr = "python310";
      sourceVersion = {
        major = "3";
        minor = "10";
        patch = "21";
        suffix = "";
      };
      hash = "sha256-oNoechMulQFU7KD29H1duChFRwDeIOURNmeUDYHg2wQ=";
      noldconfigPatch = pkgs.path + "/pkgs/development/interpreters/python/cpython/3.11/no-ldconfig.patch";
      packageOverrides = packages: previous: {
        numpy = previous.numpy_1;
        # Current Nixpkgs assumes Python>=3.11 for build; bootstrap its
        # pre-3.11 TOML dependency without creating build -> tomli -> build.
        tomli = packages.toPythonModule (pkgs.stdenvNoCC.mkDerivation {
          pname = "python3.10-bootstrap-tomli";
          version = "2.0.2";
          src = pkgs.fetchurl {
            url = "https://files.pythonhosted.org/packages/35/b9/de2a5c0144d7d75a57ff355c0c24054f965b2dc3036456ae03a51ea6264b/tomli-2.0.2.tar.gz";
            sha256 = "d46d457a85337051c36524bc5349dd91b1877838e2979ac5ced3e710ed8a60ed";
          };
          inherit (previous.tomli) meta;
          buildPhase = ''
            PYTHONPATH=${packages.bootstrap.flit-core}/${final.python310.sitePackages} \
              ${final.python310.interpreter} -m flit_core.wheel
          '';
          installPhase = ''
            PYTHONPATH=${packages.bootstrap.installer}/${final.python310.sitePackages} \
              ${final.python310.interpreter} -m installer --destdir "$out" --prefix "" dist/*.whl
          '';
        });
        meson-python = previous.meson-python.overridePythonAttrs (old: {
          build-system = (old.build-system or []) ++ [packages.tomli];
          dependencies = (old.dependencies or []) ++ [packages.tomli];
        });
        pytest-asyncio = previous.pytest-asyncio.overridePythonAttrs (old: {
          dependencies = (old.dependencies or []) ++ [packages.backports-asyncio-runner];
        });
        pytest = previous.pytest.overridePythonAttrs (old: {
          dependencies = (old.dependencies or []) ++ [packages.tomli packages.exceptiongroup];
        });
        hypothesis = previous.hypothesis.overridePythonAttrs (old: {
          dependencies = (old.dependencies or []) ++ [packages.exceptiongroup];
        });
        hatchling = previous.hatchling.overridePythonAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or []) ++ [packages.tomli];
          dependencies = (old.dependencies or []) ++ [packages.tomli];
        });
        setuptools-scm = previous.setuptools-scm.overridePythonAttrs (old: {
          build-system = (old.build-system or []) ++ [packages.tomli];
          dependencies = (old.dependencies or []) ++ [packages.tomli];
        });
        build = previous.build.overridePythonAttrs (old: {dependencies = (old.dependencies or []) ++ [packages.tomli];});
      };
    };
  });
in
  scoped.python310
