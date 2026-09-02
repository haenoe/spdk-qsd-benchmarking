{
  stdenv,
  lib,
  ftxui,
  fetchFromGitLab,
  fetchFromGitHub,
  boost,
  libaio,
  libbacktrace,
  numactl,
  openssl,
  ...
}:
let
  simple-web-server = fetchFromGitLab {
    owner = "eidheim";
    repo = "Simple-Web-Server";
    # From ./external/prepare-external.sh
    #
    # REQUIRED_TAG="v3.1.1-52-g187f798" # need master for ipv6 addr support (commit bab4b309)
    rev = "master";
    hash = "sha256-sIuZUqpK8eiPs1wIlE8hJgtynEoYpLxMaWxQGviifME=";
  };
in
stdenv.mkDerivation {
  pname = "elbencho";
  version = "3.1.7";

  src = fetchFromGitHub {
    owner = "breuner";
    repo = "elbencho";
    rev = "v3.1-7";
    hash = "sha256-TaWAgiveaCqgOcmWe/GfTGCTYAO8x+W8GVaN9Dq1hO0=";
  };

  patches = [
    ./no-externals-and-install-bash.patch
  ];

  preBuild = ''
    ln -s ${simple-web-server} external/Simple-Web-Server
  '';

  makeFlags = [ "INST_PATH=$(out)" ];

  buildInputs = [
    boost
    libbacktrace
    openssl
    ftxui
  ] ++ lib.optionals stdenv.hostPlatform.isLinux [
    libaio
    numactl
  ];
}
