{ lib
, buildPythonPackage
, fetchPypi
, click
, setuptools
}:

buildPythonPackage rec {
  pname = "shiv";
  version = "0.4.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "824ff4a2278fe3f315452902050bf1751b05b1e785c522ef6285df1868125189";
  };

  nativeBuildInputs = [ click setuptools ];

  # A few more dependencies I don't want to handle right now...
  doCheck = false;

  meta = with lib; {
    description = ''
      shiv is a command line utility for building fully self contained Python zipapps as
      outlined in PEP 441, but with all their dependencies included.
    '';
    homepage = "https://github.com/linkedin/shiv";
    license = licenses.bsd2;
    maintainers = with maintainers; [ jwygoda ];
  };
}
