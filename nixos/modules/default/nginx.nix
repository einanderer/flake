{
  lib,
  pkgs,
  ...
}:
{
  services.nginx = {
    package = lib.mkDefault pkgs.nginxMainline;
    recommendedOptimisation = lib.mkDefault true;
    recommendedTlsSettings = lib.mkDefault true;
    recommendedGzipSettings = lib.mkDefault true;
    recommendedBrotliSettings = lib.mkDefault true;
    recommendedProxySettings = lib.mkDefault true;
    logError = "stderr info";
  };
}
