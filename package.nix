{
  lib,
  lua,
  luaLib,
  isLuaJIT,
  buildLuaPackage,
  makeWrapper,
  ldoc,
  busted,
  ljsyscall,
  version ? "0.3.0",
}:

buildLuaPackage {
  pname = "lsh";
  inherit version;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./bin
      ./lsh
      ./lsh.lua
      ./spec
      ./.busted
      # needed by ldoc
      ./config.ld
      ./README.md
    ];
  };

  outputs = [
    "out"
    "doc"
  ];

  nativeBuildInputs = [
    makeWrapper
    ldoc
  ];
  nativeCheckInputs = [ busted ];
  propagatedBuildInputs = [ ljsyscall ];

  buildPhase = ''
    runHook preBuild
    ldoc .
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    busted
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/lua/${lua.luaversion}/
    cp lsh.lua $out/share/lua/${lua.luaversion}/
    cp -r lsh $out/share/lua/${lua.luaversion}/

    mkdir -p $out/bin
    cp bin/lsh $out/bin/
    wrapProgram $out/bin/lsh \
      --argv0 lsh \
      --set LUA_PATH  "${luaLib.genLuaPathAbsStr ljsyscall};$out/share/lua/${lua.luaversion}/?.lua;;" \
      --set LUA_CPATH ";;"

    mkdir -p $doc/share/doc/lsh
    cp -r doc/* $doc/share/doc/lsh/

    runHook postInstall
  '';

  meta = {
    description = "Small Lua shell library";
    homepage = "https://github.com/tvbeat/lsh";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "lsh";
    # lsh uses the LuaJIT FFI
    broken = !isLuaJIT;
  };
}
