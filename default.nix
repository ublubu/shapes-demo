{ mkDerivation, base, containers, either, lens, linear
, monad-extras, mtl, sdl2, shapes, stdenv, vector, zippers
}:
mkDerivation {
  pname = "shapes-demo";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    base containers either lens linear monad-extras mtl sdl2 shapes
    vector zippers
  ];
  homepage = "https://github.com/ublubu/shapes-demo";
  description = "demos for the 'shapes' package";
  license = stdenv.lib.licenses.unfree;
}
