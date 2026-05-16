{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.spotify-unfree;
in
{
  options.programs.spotify-unfree = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.anderer.workstation.gui && pkgs.stdenv.hostPlatform.isx86_64;
      description = "Unfree Spotify Client";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.spicetify =
      let
        spicePkgs = inputs.spicetify-nix.legacyPackages.x86_64-linux;
        #spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
      in
      {
        enable = false;
        enabledExtensions = with spicePkgs.extensions; [
          adblock
          hidePodcasts
          shuffle
          listPlaylistsWithSong
          playlistIntersection
          playingSource
          addToQueueTop
          history
          fullAlbumDate
          playNext
          betterGenres
          history
        ];
      };
  };
}
